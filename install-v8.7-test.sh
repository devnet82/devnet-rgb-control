#!/usr/bin/env bash
set -eEuo pipefail

VERSION="8.7"
HOME_DIR="${DEVNET_HOME:-$HOME}"
BIN="$HOME_DIR/.local/bin"
USER_UNITS="$HOME_DIR/.config/systemd/user"
APPS="$HOME_DIR/.local/share/applications"
TEST_STATE="$HOME_DIR/.config/devnet-rgb-test"
BACKUP_ROOT="$HOME_DIR/.config/devnet-rgb-backups"
VENV="$HOME_DIR/.local/share/devnet-rgb/venv"
OLH="$HOME_DIR/OpenLinkHub"
SERIAL="410230319ac184aa2576ea061091005f"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$BACKUP_ROOT/pre-v8.7-test-$STAMP"
STAGE="${TMPDIR:-/tmp}/devnet-rgb-v8.7-stage-$STAMP"
PROTECTED="$BACKUP/openlinkhub-protected.sha256"
MANIFEST="$BACKUP/manifest.txt"
STATE_FILE="$TEST_STATE/current-backup"

say(){ printf '\n=== %s ===\n' "$*"; }
fail(){ printf '\n[STOP] %s\nNothing further will be changed.\n' "$*" >&2; exit 1; }

required_cmds=(systemctl python3 tar sha256sum sed grep cp rm find)
for c in "${required_cmds[@]}"; do command -v "$c" >/dev/null 2>&1 || fail "$c is required"; done
[[ -x "$VENV/bin/python" ]] || fail "Existing Devnet RGB Python environment was not found: $VENV/bin/python"
[[ -x /usr/bin/openrgb ]] || fail "OpenRGB was not found at /usr/bin/openrgb"
[[ -d "$OLH" ]] || fail "OpenLinkHub working directory was not found: $OLH"

OWNED_REL=(
  ".local/bin/devnet-rgb-master"
  ".local/bin/devnet-rgb-control-app"
  ".local/bin/devnet-rgb-control"
  ".local/bin/devnet-rgb-doctor"
  ".local/bin/devnet-rgb-doctor-v86.py"
  ".local/bin/devnet-openrgb-wait-i2c.py"
  ".local/bin/devnet-openrgb-validate-6742.py"
  ".local/bin/devnet-gpu-hotspot"
  ".config/systemd/user/devnet-rgb-master.service"
  ".config/systemd/user/devnet-openrgb-server.service"
  ".config/systemd/user/devnet-rgb-control-app.service"
  ".local/share/applications/devnet-rgb-control.desktop"
)

MINIMUM=(
  "$BIN/devnet-rgb-master"
  "$BIN/devnet-rgb-control-app"
  "$BIN/devnet-rgb-control"
  "$BIN/devnet-rgb-doctor"
  "$BIN/devnet-gpu-hotspot"
  "$USER_UNITS/devnet-rgb-master.service"
  "$USER_UNITS/devnet-openrgb-server.service"
  "$USER_UNITS/devnet-rgb-control-app.service"
)
for p in "${MINIMUM[@]}"; do [[ -e "$p" ]] || fail "Required working v8.6 file is missing: $p"; done

say "Preflight: checking the working v8.6 installation"
for u in devnet-rgb-master.service devnet-openrgb-server.service devnet-rgb-control-app.service OpenLinkHub.service; do
  if systemctl --user is-active --quiet "$u"; then echo "[PASS] $u active"; else fail "$u is not active; keep v8.6 working before testing v8.7"; fi
done

if [[ -x "$BIN/devnet-rgb-doctor" ]]; then
  "$BIN/devnet-rgb-doctor" || fail "Current RGB Doctor found a problem. v8.7 test has not started."
fi

say "Protecting OpenLinkHub fan/profile files"
mkdir -p "$BACKUP" "$TEST_STATE" "$STAGE"
PROTECTED_FILES=(
  "$OLH/config.json"
  "$OLH/database/profiles/$SERIAL.json"
  "$OLH/database/profiles/$SERIAL-temp.json"
  "$OLH/database/temperatures/CPU.json"
  "$OLH/database/temperatures/GPU.json"
  "$OLH/database/temperatures/GPU-Hotspot.json"
)
: > "$PROTECTED"
for p in "${PROTECTED_FILES[@]}"; do
  [[ -f "$p" ]] || fail "Protected OpenLinkHub file missing: $p"
  sha256sum "$p" >> "$PROTECTED"
done
"$VENV/bin/python" - "$OLH" "$SERIAL" <<'PY'
import json,sys
from pathlib import Path
root=Path(sys.argv[1]); serial=sys.argv[2]
cfg=json.loads((root/'config.json').read_text())
if cfg.get('manual') is not False: raise SystemExit(f"OpenLinkHub manual must be false, found {cfg.get('manual')!r}")
w={'0':'CPU','1':'CPU','2':'CPU','3':'GPU-Hotspot','4':'GPU-Hotspot'}
for suffix in ('','-temp'):
    p=root/'database/profiles'/f'{serial}{suffix}.json'; d=json.loads(p.read_text())
    if d.get('SpeedProfiles') != w: raise SystemExit(f"Unexpected fan mapping in {p.name}: {d.get('SpeedProfiles')}")
print('[PASS] manual=false')
print('[PASS] Fan 1-3=CPU / Fan 4-5=GPU-Hotspot')
PY

say "Backing up the exact working Devnet RGB application"
: > "$MANIFEST"
for rel in "${OWNED_REL[@]}"; do [[ -e "$HOME_DIR/$rel" ]] && printf '%s\n' "$rel" >> "$MANIFEST"; done
[[ -s "$MANIFEST" ]] || fail "No Devnet RGB files were found to back up"
tar -czf "$BACKUP/devnet-rgb-v8.6-working-files.tar.gz" -C "$HOME_DIR" -T "$MANIFEST"
for u in devnet-rgb-master.service devnet-openrgb-server.service devnet-rgb-control-app.service; do
  printf '%s=%s\n' "$u" "$(systemctl --user is-enabled "$u" 2>/dev/null || true)" >> "$BACKUP/unit-enable-state.txt"
done
printf '%s\n' "$BACKUP" > "$STATE_FILE"
echo "[PASS] Recovery backup: $BACKUP"

say "Creating a staged v8.7 copy from the files actually working on this PC"
while IFS= read -r rel; do
  mkdir -p "$STAGE/$(dirname "$rel")"
  cp -a "$HOME_DIR/$rel" "$STAGE/$rel"
done < "$MANIFEST"

# The v8.6 Doctor gets a correctly versioned filename in v8.7.
if [[ -f "$STAGE/.local/bin/devnet-rgb-doctor-v86.py" ]]; then
  mv "$STAGE/.local/bin/devnet-rgb-doctor-v86.py" "$STAGE/.local/bin/devnet-rgb-doctor-v87.py"
fi

"$VENV/bin/python" - "$STAGE" <<'PY'
import re,sys
from pathlib import Path
root=Path(sys.argv[1])
text_suffixes={'.py','.service','.desktop',''}
for p in root.rglob('*'):
    if not p.is_file(): continue
    try: s=p.read_text()
    except UnicodeDecodeError: continue
    old=s
    s=re.sub(r'(?i)\bv8(?:\.\d+){1,2}\b','v8.7',s)
    s=s.replace('devnet-rgb-doctor-v86.py','devnet-rgb-doctor-v87.py')
    if s!=old: p.write_text(s)
PY

# Ensure executable scripts remain executable after staging edits.
find "$STAGE/.local/bin" -maxdepth 1 -type f -name 'devnet-*' -exec chmod +x {} + 2>/dev/null || true

say "Static checks before touching the working installation"
for p in "$STAGE/.local/bin/devnet-rgb-master" "$STAGE/.local/bin/devnet-rgb-control-app" "$STAGE/.local/bin/devnet-openrgb-wait-i2c.py" "$STAGE/.local/bin/devnet-openrgb-validate-6742.py" "$STAGE/.local/bin/devnet-rgb-doctor-v87.py"; do
  [[ -f "$p" ]] || continue
  "$VENV/bin/python" -m py_compile "$p"
  echo "[PASS] Python compile: $(basename "$p")"
done
for p in "$STAGE/.local/bin/devnet-rgb-control" "$STAGE/.local/bin/devnet-rgb-doctor"; do
  [[ -f "$p" ]] || continue
  bash -n "$p"
  echo "[PASS] shell syntax: $(basename "$p")"
done

# Version consistency on user-facing/runtime files.
VERSION_FILES=(
 "$STAGE/.local/bin/devnet-rgb-master"
 "$STAGE/.local/bin/devnet-rgb-control-app"
 "$STAGE/.config/systemd/user/devnet-rgb-master.service"
)
for p in "${VERSION_FILES[@]}"; do
  [[ -f "$p" ]] || continue
  grep -qi 'v8\.7' "$p" || fail "v8.7 version string missing from staged $(basename "$p")"
  if grep -Eqi '\bv8\.(0|1|2|3|4|5|6)(\.[0-9]+)?\b' "$p"; then fail "Old v8.x application version remains in staged $(basename "$p")"; fi
done

rollback_internal(){
  trap - ERR
  set +e
  echo
  echo "!!! v8.7 installation failed — restoring the saved v8.6 application !!!"
  systemctl --user stop devnet-rgb-control-app.service devnet-rgb-master.service devnet-openrgb-server.service >/dev/null 2>&1 || true
  while IFS= read -r rel; do rm -rf "$HOME_DIR/$rel"; done < "$MANIFEST"
  tar -xzf "$BACKUP/devnet-rgb-v8.6-working-files.tar.gz" -C "$HOME_DIR"
  systemctl --user daemon-reload
  systemctl --user enable devnet-openrgb-server.service devnet-rgb-master.service devnet-rgb-control-app.service >/dev/null 2>&1 || true
  systemctl --user start devnet-openrgb-server.service >/dev/null 2>&1 || true
  systemctl --user start OpenLinkHub.service >/dev/null 2>&1 || true
  systemctl --user start devnet-rgb-master.service >/dev/null 2>&1 || true
  systemctl --user start devnet-rgb-control-app.service >/dev/null 2>&1 || true
  echo "v8.6 files restored from $BACKUP"
}
trap rollback_internal ERR

say "Controlled uninstall of the old Devnet RGB application files"
systemctl --user stop devnet-rgb-control-app.service devnet-rgb-master.service devnet-openrgb-server.service
while IFS= read -r rel; do rm -rf "$HOME_DIR/$rel"; done < "$MANIFEST"
systemctl --user daemon-reload
# OpenRGB and OpenLinkHub packages/data are deliberately not removed.
echo "[PASS] old Devnet RGB application files removed"
echo "[PASS] OpenRGB package left installed"
echo "[PASS] OpenLinkHub installation/profile data left installed"

say "Installing staged Devnet RGB Control v8.7"
while IFS= read -r rel; do
  src="$STAGE/$rel"
  # Doctor source was renamed from v86 to v87.
  if [[ "$rel" == ".local/bin/devnet-rgb-doctor-v86.py" ]]; then src="$STAGE/.local/bin/devnet-rgb-doctor-v87.py"; rel=".local/bin/devnet-rgb-doctor-v87.py"; fi
  [[ -e "$src" ]] || continue
  mkdir -p "$HOME_DIR/$(dirname "$rel")"
  cp -a "$src" "$HOME_DIR/$rel"
done < "$MANIFEST"
chmod +x "$BIN"/devnet-* 2>/dev/null || true
systemctl --user daemon-reload
systemctl --user enable devnet-openrgb-server.service devnet-rgb-master.service devnet-rgb-control-app.service >/dev/null
systemctl --user start devnet-openrgb-server.service
systemctl --user start OpenLinkHub.service
systemctl --user start devnet-rgb-master.service
systemctl --user start devnet-rgb-control-app.service
sleep 3

say "Checking v8.7 services"
for u in devnet-openrgb-server.service OpenLinkHub.service devnet-rgb-master.service devnet-rgb-control-app.service; do
  systemctl --user is-active --quiet "$u" || { systemctl --user status "$u" --no-pager -l || true; false; }
  echo "[PASS] $u active"
done

if [[ -x "$BIN/devnet-rgb-doctor" ]]; then "$BIN/devnet-rgb-doctor"; fi

say "Confirming fan/profile files were not changed"
sha256sum -c "$PROTECTED"

echo "[PASS] protected OpenLinkHub files unchanged"

say "Capturing the installed v8.7 test state"
CAPTURE="$HOME_DIR/Downloads/devnet-rgb-control-v8.7-captured-$STAMP.tar.gz"
CAP_LIST="$BACKUP/v8.7-capture-manifest.txt"
: > "$CAP_LIST"
for rel in "${OWNED_REL[@]}"; do
  [[ "$rel" == ".local/bin/devnet-rgb-doctor-v86.py" ]] && rel=".local/bin/devnet-rgb-doctor-v87.py"
  [[ -e "$HOME_DIR/$rel" ]] && printf '%s\n' "$rel" >> "$CAP_LIST"
done
tar -czf "$CAPTURE" -C "$HOME_DIR" -T "$CAP_LIST"
sha256sum "$CAPTURE" | tee "$CAPTURE.sha256"

trap - ERR
rm -rf "$STAGE"

echo
echo "============================================================"
echo " DEVNET RGB CONTROL v8.7 TEST INSTALL COMPLETED"
echo "============================================================"
echo "Recovery backup: $BACKUP"
echo "Captured v8.7 files: $CAPTURE"
echo
echo "NEXT STEP: reboot the PC normally."
echo "After logging back in, run:"
echo "  cd ~/Downloads/devnet-rgb-control-test"
echo "  ./verify-after-reboot.sh"
echo
echo "If anything looks wrong, run:"
echo "  ./rollback-to-v8.6.sh"
