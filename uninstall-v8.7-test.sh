#!/usr/bin/env bash
set -euo pipefail
HOME_DIR="${DEVNET_HOME:-$HOME}"
BIN="$HOME_DIR/.local/bin"
UNITS="$HOME_DIR/.config/systemd/user"
APPS="$HOME_DIR/.local/share/applications"

echo "=== Remove Devnet RGB Control v8.7 test application ==="
echo "This keeps OpenRGB, OpenLinkHub, fan/profile data, the Devnet Python environment, configs and recovery backups."
echo

systemctl --user disable --now devnet-rgb-control-app.service devnet-rgb-master.service devnet-openrgb-server.service >/dev/null 2>&1 || true

rm -f \
  "$BIN/devnet-rgb-master" \
  "$BIN/devnet-rgb-control-app" \
  "$BIN/devnet-rgb-control" \
  "$BIN/devnet-rgb-doctor" \
  "$BIN/devnet-rgb-doctor-v87.py" \
  "$BIN/devnet-openrgb-wait-i2c.py" \
  "$BIN/devnet-openrgb-validate-6742.py" \
  "$BIN/devnet-gpu-hotspot" \
  "$UNITS/devnet-rgb-master.service" \
  "$UNITS/devnet-openrgb-server.service" \
  "$UNITS/devnet-rgb-control-app.service" \
  "$APPS/devnet-rgb-control.desktop"

DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
[[ -n "$DESKTOP_DIR" ]] || DESKTOP_DIR="$HOME_DIR/Desktop"
rm -f "$DESKTOP_DIR/Devnet RGB Control.desktop" "$DESKTOP_DIR/Devnet-RGB-Control.desktop"

systemctl --user daemon-reload

echo "[PASS] Devnet RGB v8.7 test application files removed."
echo "[PASS] OpenRGB was NOT uninstalled."
echo "[PASS] OpenLinkHub was NOT uninstalled."
echo "[PASS] OpenLinkHub fan/profile files were NOT intentionally changed."
echo

echo "To return to the known-good v8.6 application, run:"
echo "  ./rollback-to-v8.6.sh"
