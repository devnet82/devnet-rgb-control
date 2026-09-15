#!/usr/bin/env bash
set -euo pipefail

VERSION="8.8"
HOME_DIR="${DEVNET_HOME:-$HOME}"
TEST_MODE="${DEVNET_TEST_MODE:-0}"
BIN="$HOME_DIR/.local/bin"
UNITS="$HOME_DIR/.config/systemd/user"
APP_DIR="$HOME_DIR/.local/share/applications"
CFG_DIR="$HOME_DIR/.config/devnet-rgb-master"
VENV="$HOME_DIR/.local/share/devnet-rgb/venv"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME_DIR/.config/devnet-rgb-backups/uninstall-v${VERSION}-$STAMP"

[[ "$TEST_MODE" == "1" || ${EUID:-$(id -u)} -ne 0 ]] || { echo "ERROR: run as your normal desktop user, not with sudo." >&2; exit 1; }

mkdir -p "$BACKUP"
if [[ -d "$CFG_DIR" ]]; then
  tar -czf "$BACKUP/devnet-rgb-config.tar.gz" -C "$HOME_DIR" .config/devnet-rgb-master
  echo "[PASS] Preserved RGB configuration backup: $BACKUP/devnet-rgb-config.tar.gz"
fi

if [[ "$TEST_MODE" != "1" ]]; then
  systemctl --user disable --now devnet-rgb-control-app.service devnet-rgb-master.service devnet-openrgb-server.service >/dev/null 2>&1 || true
fi

rm -f \
  "$BIN/devnet-rgb-master" \
  "$BIN/devnet-rgb-control-app" \
  "$BIN/devnet-rgb-control" \
  "$BIN/devnet-rgb-doctor" \
  "$BIN/devnet-rgb-doctor-v88.py" \
  "$BIN/devnet-openrgb-wait-i2c.py" \
  "$BIN/devnet-openrgb-validate-6742.py" \
  "$BIN/devnet-gpu-hotspot" \
  "$UNITS/devnet-openrgb-server.service" \
  "$UNITS/devnet-rgb-master.service" \
  "$UNITS/devnet-rgb-control-app.service" \
  "$APP_DIR/devnet-rgb-control.desktop"
rm -rf "$VENV"

if [[ "$TEST_MODE" != "1" ]]; then systemctl --user daemon-reload; fi

echo
echo "Devnet RGB Control v8.8 removed."
echo "Your RGB config was preserved at: $CFG_DIR"
echo "OpenRGB was NOT removed."
echo "OpenLinkHub was NOT removed."
echo "OpenLinkHub fan profiles, temperature profiles and configuration were NOT changed or removed."
echo "Recovery backups remain under: $HOME_DIR/.config/devnet-rgb-backups"
