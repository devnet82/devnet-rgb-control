#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="8.8"
PKG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${DEVNET_HOME:-$HOME}"
TEST_MODE="${DEVNET_TEST_MODE:-0}"
BIN="$HOME_DIR/.local/bin"
UNITS="$HOME_DIR/.config/systemd/user"
CFG_DIR="$HOME_DIR/.config/devnet-rgb-master"
APP_DIR="$HOME_DIR/.local/share/applications"
VENV="$HOME_DIR/.local/share/devnet-rgb/venv"
OLH="$HOME_DIR/OpenLinkHub"
BACKUP_ROOT="$HOME_DIR/.config/devnet-rgb-backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$BACKUP_ROOT/pre-v${VERSION}-$STAMP"
LAST_BACKUP="$BACKUP_ROOT/last-v${VERSION}-backup"
PROTECTED_SUMS="$BACKUP/openlinkhub-protected.sha256"
DESTRUCTIVE=0

say(){ printf '\n=== %s ===\n' "$*"; }
pass(){ printf '[PASS] %s\n' "$*"; }
fail(){ printf '\nERROR: %s\n' "$*" >&2; exit 1; }

on_error(){
  rc=$?
  if [[ $DESTRUCTIVE -eq 1 && -d "$BACKUP" ]]; then
    echo
    echo "Install failed after changes began. Attempting automatic rollback..." >&2
    DEVNET_HOME="$HOME_DIR" DEVNET_TEST_MODE="$TEST_MODE" "$PKG_DIR/rollback.sh" --backup "$BACKUP" --quiet || true
  fi
  exit "$rc"
}
trap on_error ERR

[[ "$TEST_MODE" == "1" || ${EUID:-$(id -u)} -ne 0 ]] || fail "Run this as your normal desktop user, not with sudo."

for c in bash python3 grep sed sha256sum tar find sort; do
  command -v "$c" >/dev/null 2>&1 || fail "$c is required"
done

[[ -f "$PKG_DIR/VERSION" ]] || fail "VERSION file missing from package"
[[ "$(tr -d '[:space:]' < "$PKG_DIR/VERSION")" == "$VERSION" ]] || fail "Package VERSION is not $VERSION"
[[ -f "$PKG_DIR/requirements.txt" ]] || fail "requirements.txt missing"

say "Preflight"
if [[ "$TEST_MODE" != "1" ]]; then
  command -v systemctl >/dev/null 2>&1 || fail "systemctl is required"
  command -v openrgb >/dev/null 2>&1 || fail "OpenRGB is not installed. Install OpenRGB first."
  command -v xdg-open >/dev/null 2>&1 || fail "xdg-open is required for the dashboard launcher."
  [[ -x "$OLH/OpenLinkHub" ]] || fail "OpenLinkHub was not found at $OLH/OpenLinkHub"
  systemctl --user cat OpenLinkHub.service >/dev/null 2>&1 || fail "OpenLinkHub.service is not installed as a user service."
  after="$(systemctl --user show OpenLinkHub.service -p After --value)"
  if grep -qw default.target <<<"$after"; then
    fail "OpenLinkHub still has After=default.target. Run ./repair-openlinkhub-ordering.sh first, then rerun this installer."
  fi
  pass "OpenLinkHub ordering is compatible"
fi

[[ -f "$OLH/config.json" ]] || fail "OpenLinkHub config missing: $OLH/config.json"
[[ -d "$OLH/database/profiles" ]] || fail "OpenLinkHub profile directory missing"
[[ -f "$OLH/database/temperatures/GPU-Hotspot.json" ]] || fail "GPU-Hotspot.json is missing"

say "Checking protected OpenLinkHub fan configuration and finding Commander serial"
SERIAL="$(python3 - "$OLH" "$HOME_DIR" <<'PY'
import json, sys
from pathlib import Path
root=Path(sys.argv[1]); home=Path(sys.argv[2])
wanted={"0":"CPU","1":"CPU","2":"CPU","3":"GPU-Hotspot","4":"GPU-Hotspot"}
cfg=json.loads((root/"config.json").read_text())
if cfg.get("manual") is not False:
    raise SystemExit("ERROR: OpenLinkHub config.json must have manual=false")
profiles=root/"database/profiles"
matches=[]
for p in profiles.glob("*.json"):
    if p.name.endswith("-temp.json"):
        continue
    serial=p.stem
    tp=profiles/f"{serial}-temp.json"
    if not tp.exists():
        continue
    try:
        a=json.loads(p.read_text()); b=json.loads(tp.read_text())
    except Exception:
        continue
    if a.get("SpeedProfiles")==wanted and b.get("SpeedProfiles")==wanted:
        matches.append(serial)
if len(matches)!=1:
    raise SystemExit(f"ERROR: expected exactly one Commander profile pair with Fan1-3=CPU/Fan4-5=GPU-Hotspot, found {len(matches)}: {matches}")
hp=json.loads((root/"database/temperatures/GPU-Hotspot.json").read_text())
if hp.get("sensor") != 7:
    raise SystemExit(f"ERROR: GPU-Hotspot sensor must be 7, got {hp.get('sensor')!r}")
expected=str(home/".local/bin/devnet-gpu-hotspot")
if str(hp.get("device","")) != expected:
    raise SystemExit(f"ERROR: GPU-Hotspot device must be {expected}, got {hp.get('device')!r}")
print(matches[0])
PY
)" || fail "OpenLinkHub fan/profile preflight failed"
pass "Commander serial detected: $SERIAL"
pass "manual=false and protected fan mappings are correct"

PROTECTED=(
  "$OLH/config.json"
  "$OLH/database/profiles/$SERIAL.json"
  "$OLH/database/profiles/$SERIAL-temp.json"
  "$OLH/database/temperatures/CPU.json"
  "$OLH/database/temperatures/GPU.json"
  "$OLH/database/temperatures/GPU-Hotspot.json"
)
for p in "${PROTECTED[@]}"; do [[ -f "$p" ]] || fail "Protected OpenLinkHub file missing: $p"; done

say "Static package checks before touching the current installation"
python3 -m py_compile \
  "$PKG_DIR/bin/devnet-rgb-master" \
  "$PKG_DIR/bin/devnet-rgb-control-app" \
  "$PKG_DIR/bin/devnet-rgb-doctor-v88.py" \
  "$PKG_DIR/bin/devnet-openrgb-wait-i2c.py" \
  "$PKG_DIR/bin/devnet-openrgb-validate-6742.py" \
  "$PKG_DIR/bin/devnet-gpu-hotspot"
for s in install.sh uninstall.sh rollback.sh repair-openlinkhub-ordering.sh bin/devnet-rgb-control bin/devnet-rgb-doctor; do
  bash -n "$PKG_DIR/$s"
done
"$PKG_DIR/tests/version-consistency.sh"
pass "Python, shell and version-consistency checks passed"

say "Creating recovery backup"
mkdir -p "$BACKUP" "$BACKUP_ROOT"
sha256sum "${PROTECTED[@]}" > "$PROTECTED_SUMS"

BACKUP_ITEMS=()
for rel in \
  .local/bin/devnet-rgb-master \
  .local/bin/devnet-rgb-control-app \
  .local/bin/devnet-rgb-control \
  .local/bin/devnet-rgb-doctor \
  .local/bin/devnet-rgb-doctor-v86.py \
  .local/bin/devnet-rgb-doctor-v87.py \
  .local/bin/devnet-rgb-doctor-v88.py \
  .local/bin/devnet-openrgb-wait-i2c.py \
  .local/bin/devnet-openrgb-validate-6742.py \
  .local/bin/devnet-gpu-hotspot \
  .config/systemd/user/devnet-openrgb-server.service \
  .config/systemd/user/devnet-rgb-master.service \
  .config/systemd/user/devnet-rgb-control-app.service \
  .local/share/applications/devnet-rgb-control.desktop \
  .config/devnet-rgb-master \
  .local/share/devnet-rgb/venv; do
  [[ -e "$HOME_DIR/$rel" ]] && BACKUP_ITEMS+=("$rel")
done
if [[ ${#BACKUP_ITEMS[@]} -gt 0 ]]; then
  tar -czf "$BACKUP/home-files.tar.gz" -C "$HOME_DIR" "${BACKUP_ITEMS[@]}"
else
  tar -czf "$BACKUP/home-files.tar.gz" --files-from /dev/null
fi
printf '%s\n' "$SERIAL" > "$BACKUP/commander-serial.txt"
printf '%s\n' "$BACKUP" > "$LAST_BACKUP"
pass "Recovery backup: $BACKUP"

say "Preparing v8.8 configuration"
mkdir -p "$BACKUP/stage"
python3 - "$PKG_DIR/config/config.json" "$CFG_DIR/config.json" "$BACKUP/stage/config.json" "$SERIAL" <<'PY'
import json, sys
from pathlib import Path
src,old,out,serial=map(Path,sys.argv[1:4])+[None] if False else (Path(sys.argv[1]),Path(sys.argv[2]),Path(sys.argv[3]),sys.argv[4])
new=json.loads(src.read_text())
if old.exists():
    try:
        prev=json.loads(old.read_text())
        for key in ("bands","poll_seconds","hysteresis_c","retry_seconds","local_sdk_host","local_sdk_port","hub_sdk_host","hub_sdk_port","motherboard","gpu_rgb_device","ram_rgb_device","ram_count"):
            if key in prev: new[key]=prev[key]
    except Exception:
        pass
new["version"]=6
new["app_version"]="8.8"
new["commander_serial"]=serial
out.write_text(json.dumps(new,indent=2)+"\n")
PY
pass "Existing RGB colours/settings preserved where available; Commander serial set to $SERIAL"

say "Preparing Python environment"
if [[ "$TEST_MODE" == "1" ]]; then
  mkdir -p "$VENV/bin"
  ln -sf "$(command -v python3)" "$VENV/bin/python"
  pass "Test mode: created fake venv Python link"
elif [[ -x "$VENV/bin/python" ]] && "$VENV/bin/python" - <<'PY' >/dev/null 2>&1
import importlib.metadata
assert importlib.metadata.version("openrgb-python") == "0.3.6"
import openrgb
PY
then
  pass "Existing Devnet Python environment already has openrgb-python 0.3.6"
else
  TMP_VENV="$HOME_DIR/.local/share/devnet-rgb/venv-v8.8-new-$STAMP"
  rm -rf "$TMP_VENV"
  python3 -m venv "$TMP_VENV"
  "$TMP_VENV/bin/python" -m pip install --upgrade pip
  "$TMP_VENV/bin/python" -m pip install -r "$PKG_DIR/requirements.txt"
  "$TMP_VENV/bin/python" - <<'PY'
import importlib.metadata, openrgb
assert importlib.metadata.version("openrgb-python") == "0.3.6"
PY
  rm -rf "$VENV"
  mv "$TMP_VENV" "$VENV"
  pass "Created Devnet Python environment with openrgb-python 0.3.6"
fi

DESTRUCTIVE=1

if [[ "$TEST_MODE" != "1" ]]; then
  say "Stopping only Devnet RGB services"
  systemctl --user stop devnet-rgb-control-app.service devnet-rgb-master.service devnet-openrgb-server.service 2>/dev/null || true
fi

say "Installing Devnet RGB Control v8.8"
mkdir -p "$BIN" "$UNITS" "$CFG_DIR" "$APP_DIR"
install -m 0755 "$PKG_DIR/bin/devnet-rgb-master" "$BIN/devnet-rgb-master"
install -m 0755 "$PKG_DIR/bin/devnet-rgb-control-app" "$BIN/devnet-rgb-control-app"
install -m 0755 "$PKG_DIR/bin/devnet-rgb-control" "$BIN/devnet-rgb-control"
install -m 0755 "$PKG_DIR/bin/devnet-rgb-doctor" "$BIN/devnet-rgb-doctor"
install -m 0755 "$PKG_DIR/bin/devnet-rgb-doctor-v88.py" "$BIN/devnet-rgb-doctor-v88.py"
install -m 0755 "$PKG_DIR/bin/devnet-openrgb-wait-i2c.py" "$BIN/devnet-openrgb-wait-i2c.py"
install -m 0755 "$PKG_DIR/bin/devnet-openrgb-validate-6742.py" "$BIN/devnet-openrgb-validate-6742.py"
install -m 0755 "$PKG_DIR/bin/devnet-gpu-hotspot" "$BIN/devnet-gpu-hotspot"
rm -f "$BIN/devnet-rgb-doctor-v86.py" "$BIN/devnet-rgb-doctor-v87.py"
install -m 0644 "$PKG_DIR/systemd/devnet-openrgb-server.service" "$UNITS/devnet-openrgb-server.service"
install -m 0644 "$PKG_DIR/systemd/devnet-rgb-master.service" "$UNITS/devnet-rgb-master.service"
install -m 0644 "$PKG_DIR/systemd/devnet-rgb-control-app.service" "$UNITS/devnet-rgb-control-app.service"
install -m 0644 "$BACKUP/stage/config.json" "$CFG_DIR/config.json"
[[ -f "$CFG_DIR/manual_override.json" ]] || printf '{\n  "enabled": false\n}\n' > "$CFG_DIR/manual_override.json"
sed "s|__HOME__|$HOME_DIR|g" "$PKG_DIR/desktop/devnet-rgb-control.desktop.in" > "$APP_DIR/devnet-rgb-control.desktop"
chmod 0644 "$APP_DIR/devnet-rgb-control.desktop"

if [[ "$TEST_MODE" != "1" ]]; then
  systemctl --user daemon-reload
  systemctl --user enable devnet-openrgb-server.service devnet-rgb-master.service devnet-rgb-control-app.service >/dev/null
  systemctl --user reset-failed devnet-openrgb-server.service devnet-rgb-master.service devnet-rgb-control-app.service || true
  systemctl --user start devnet-openrgb-server.service
  systemctl --user start devnet-rgb-master.service
  systemctl --user start devnet-rgb-control-app.service

  say "Runtime checks"
  for u in devnet-openrgb-server.service OpenLinkHub.service devnet-rgb-master.service devnet-rgb-control-app.service; do
    systemctl --user is-active --quiet "$u" || fail "$u did not become active"
    pass "$u active"
  done
  "$BIN/devnet-rgb-doctor"
  pass "RGB Doctor v8.8"
fi

say "Confirming protected OpenLinkHub files were not changed"
sha256sum -c "$PROTECTED_SUMS"
pass "Protected OpenLinkHub fan/profile files unchanged"

say "Installed version checks"
[[ "$($BIN/devnet-rgb-control --version)" == "Devnet RGB Control v8.8" ]] || fail "Control launcher version mismatch"
"$VENV/bin/python" "$BIN/devnet-rgb-master" --version | grep -qx 'Devnet RGB Control v8.8 master'
"$VENV/bin/python" "$BIN/devnet-rgb-control-app" --version | grep -qx 'Devnet RGB Control v8.8 dashboard'
"$BIN/devnet-rgb-doctor" --version | grep -qx 'Devnet RGB Doctor v8.8'
pass "Installed app reports v8.8 consistently"

DESTRUCTIVE=0
trap - ERR

echo
echo "============================================================"
echo " DEVNET RGB CONTROL v8.8 INSTALL COMPLETED"
echo "============================================================"
echo "Recovery backup: $BACKUP"
if [[ "$TEST_MODE" == "1" ]]; then
  echo "TEST MODE completed; no real systemd services were changed."
else
  echo "Next: reboot normally, then run ./verify-after-reboot.sh"
fi
