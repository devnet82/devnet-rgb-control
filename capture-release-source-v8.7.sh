#!/usr/bin/env bash
set -euo pipefail

VERSION="8.7"
HOME_DIR="${DEVNET_HOME:-$HOME}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="$HOME_DIR/Downloads/devnet-rgb-control-v8.7-release-source-$STAMP"
ARCHIVE="$OUT_DIR.tar.gz"
VENV="$HOME_DIR/.local/share/devnet-rgb/venv"
BIN="$HOME_DIR/.local/bin"
UNITS="$HOME_DIR/.config/systemd/user"
CFG_DIR="$HOME_DIR/.config/devnet-rgb-master"
APP_DIR="$HOME_DIR/.local/share/applications"

say(){ printf '\n=== %s ===\n' "$*"; }
fail(){ printf '\nERROR: %s\n' "$*" >&2; exit 1; }

for c in tar sha256sum systemctl python3 grep sed; do
  command -v "$c" >/dev/null 2>&1 || fail "$c is required"
done

[[ -x "$VENV/bin/python" ]] || fail "Devnet RGB Python environment missing: $VENV/bin/python"
[[ -f "$CFG_DIR/config.json" ]] || fail "Required live RGB config missing: $CFG_DIR/config.json"

say "Checking that the physically-tested v8.7 install is still active"
for u in devnet-openrgb-server.service OpenLinkHub.service devnet-rgb-master.service devnet-rgb-control-app.service; do
  systemctl --user is-active --quiet "$u" || fail "$u is not active"
  echo "[PASS] $u active"
done

if [[ -x "$BIN/devnet-rgb-doctor" ]]; then
  "$BIN/devnet-rgb-doctor" || fail "RGB Doctor did not pass. Release capture stopped."
fi

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/payload/.local/bin" \
         "$OUT_DIR/payload/.config/systemd/user" \
         "$OUT_DIR/payload/.config/devnet-rgb-master" \
         "$OUT_DIR/payload/.local/share/applications" \
         "$OUT_DIR/diagnostics"

say "Capturing the exact working v8.7 application files"
FILES=(
  "$BIN/devnet-rgb-master"
  "$BIN/devnet-rgb-control-app"
  "$BIN/devnet-rgb-control"
  "$BIN/devnet-rgb-doctor"
  "$BIN/devnet-rgb-doctor-v87.py"
  "$BIN/devnet-openrgb-wait-i2c.py"
  "$BIN/devnet-openrgb-validate-6742.py"
  "$BIN/devnet-gpu-hotspot"
  "$UNITS/devnet-rgb-master.service"
  "$UNITS/devnet-openrgb-server.service"
  "$UNITS/devnet-rgb-control-app.service"
  "$APP_DIR/devnet-rgb-control.desktop"
  "$CFG_DIR/config.json"
)

for src in "${FILES[@]}"; do
  [[ -e "$src" ]] || fail "Required release file missing: $src"
  rel="${src#$HOME_DIR/}"
  mkdir -p "$OUT_DIR/payload/$(dirname "$rel")"
  cp -a "$src" "$OUT_DIR/payload/$rel"
  echo "[PASS] $rel"
done

# Capture manual override only as diagnostic state; it is not part of the install payload.
if [[ -f "$CFG_DIR/manual_override.json" ]]; then
  cp -a "$CFG_DIR/manual_override.json" "$OUT_DIR/diagnostics/manual_override-at-capture.json"
fi

say "Capturing dependency and service information"
"$VENV/bin/python" --version > "$OUT_DIR/diagnostics/python-version.txt" 2>&1 || true
"$VENV/bin/python" -m pip freeze > "$OUT_DIR/diagnostics/python-pip-freeze.txt" 2>&1 || true
/usr/bin/openrgb --version > "$OUT_DIR/diagnostics/openrgb-version.txt" 2>&1 || true
systemctl --version > "$OUT_DIR/diagnostics/systemd-version.txt" 2>&1 || true
systemctl --user cat OpenLinkHub.service > "$OUT_DIR/diagnostics/OpenLinkHub-effective-unit.txt" 2>&1 || true
systemctl --user show OpenLinkHub.service -p FragmentPath -p DropInPaths -p After -p Before -p Wants -p Requires > "$OUT_DIR/diagnostics/OpenLinkHub-ordering.txt" 2>&1 || true
systemctl --user status devnet-openrgb-server.service devnet-rgb-master.service devnet-rgb-control-app.service OpenLinkHub.service --no-pager -l > "$OUT_DIR/diagnostics/service-status.txt" 2>&1 || true
journalctl --user -u devnet-rgb-master.service -b --no-pager -n 120 > "$OUT_DIR/diagnostics/rgb-master-current-boot.log" 2>&1 || true

say "Static syntax checks"
for p in \
  "$OUT_DIR/payload/.local/bin/devnet-rgb-master" \
  "$OUT_DIR/payload/.local/bin/devnet-rgb-control-app" \
  "$OUT_DIR/payload/.local/bin/devnet-rgb-doctor-v87.py" \
  "$OUT_DIR/payload/.local/bin/devnet-openrgb-wait-i2c.py" \
  "$OUT_DIR/payload/.local/bin/devnet-openrgb-validate-6742.py"; do
  "$VENV/bin/python" -m py_compile "$p"
  echo "[PASS] Python compile: $(basename "$p")"
done

for p in "$OUT_DIR/payload/.local/bin/devnet-rgb-control" "$OUT_DIR/payload/.local/bin/devnet-rgb-doctor"; do
  bash -n "$p"
  echo "[PASS] shell syntax: $(basename "$p")"
done

say "Version consistency checks"
CHECK_FILES=(
  "$OUT_DIR/payload/.local/bin/devnet-rgb-master"
  "$OUT_DIR/payload/.local/bin/devnet-rgb-control-app"
  "$OUT_DIR/payload/.config/systemd/user/devnet-rgb-master.service"
)
for p in "${CHECK_FILES[@]}"; do
  grep -qi 'v8\.7' "$p" || fail "v8.7 version string missing from $(basename "$p")"
  if grep -Eqi '\bv8\.(0|1|2|3|4|5|6)(\.[0-9]+)?\b' "$p"; then
    fail "Old v8.x application version remains in $(basename "$p")"
  fi
  echo "[PASS] $(basename "$p") reports v8.7"
done

echo "8.7" > "$OUT_DIR/VERSION"
cat > "$OUT_DIR/CAPTURE-NOTES.txt" <<'EOF'
Devnet RGB Control v8.7 release-source capture.

This capture was produced from the installation that passed:
- install/upgrade test
- RGB Doctor v8.7
- reboot test
- dashboard/version checks
- normal shutdown
- cold power-on
- physical RGB/fan verification

The payload contains Devnet-owned application files plus the active RGB config.json required by a fresh install.
OpenLinkHub fan/profile JSON is deliberately NOT included as install payload; those files remain user/system state and must not be overwritten by the public installer.
Diagnostics are included for dependency/ordering analysis only.
EOF

say "Creating manifest and archive"
(
  cd "$OUT_DIR"
  find payload -type f -print0 | sort -z | xargs -0 sha256sum > PAYLOAD-SHA256SUMS.txt
)
tar -czf "$ARCHIVE" -C "$(dirname "$OUT_DIR")" "$(basename "$OUT_DIR")"
sha256sum "$ARCHIVE" | tee "$ARCHIVE.sha256"

echo
echo "============================================================"
echo " DEVNET RGB CONTROL v8.7 RELEASE-SOURCE CAPTURE COMPLETE"
echo "============================================================"
echo "Archive: $ARCHIVE"
echo "SHA256:  $ARCHIVE.sha256"
echo
echo "Upload the .tar.gz file into the ChatGPT conversation."
echo "This script was read-only apart from creating files in ~/Downloads."
