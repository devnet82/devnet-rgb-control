#!/usr/bin/env bash
set -euo pipefail

VERSION="8.8"
HOME_DIR="${DEVNET_HOME:-$HOME}"
TEST_MODE="${DEVNET_TEST_MODE:-0}"
BACKUP_ROOT="$HOME_DIR/.config/devnet-rgb-backups"
LAST_BACKUP="$BACKUP_ROOT/last-v${VERSION}-backup"
BACKUP=""
QUIET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --backup) BACKUP="${2:-}"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$BACKUP" ]] || { [[ -f "$LAST_BACKUP" ]] && BACKUP="$(cat "$LAST_BACKUP")"; }
[[ -n "$BACKUP" && -d "$BACKUP" ]] || { echo "ERROR: no v8.8 recovery backup found" >&2; exit 1; }
[[ -f "$BACKUP/home-files.tar.gz" ]] || { echo "ERROR: backup archive missing: $BACKUP/home-files.tar.gz" >&2; exit 1; }

BIN="$HOME_DIR/.local/bin"
UNITS="$HOME_DIR/.config/systemd/user"
APP_DIR="$HOME_DIR/.local/share/applications"
CFG_DIR="$HOME_DIR/.config/devnet-rgb-master"
VENV="$HOME_DIR/.local/share/devnet-rgb/venv"

if [[ "$TEST_MODE" != "1" ]]; then
  systemctl --user stop devnet-rgb-control-app.service devnet-rgb-master.service devnet-openrgb-server.service 2>/dev/null || true
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
rm -rf "$CFG_DIR" "$VENV"

tar -xzf "$BACKUP/home-files.tar.gz" -C "$HOME_DIR"

if [[ "$TEST_MODE" != "1" ]]; then
  systemctl --user daemon-reload
  for u in devnet-openrgb-server.service devnet-rgb-master.service devnet-rgb-control-app.service; do
    if [[ -f "$UNITS/$u" ]]; then systemctl --user enable "$u" >/dev/null 2>&1 || true; fi
  done
  [[ -f "$UNITS/devnet-openrgb-server.service" ]] && systemctl --user start devnet-openrgb-server.service || true
  [[ -f "$UNITS/devnet-rgb-master.service" ]] && systemctl --user start devnet-rgb-master.service || true
  [[ -f "$UNITS/devnet-rgb-control-app.service" ]] && systemctl --user start devnet-rgb-control-app.service || true
fi

if [[ -f "$BACKUP/openlinkhub-protected.sha256" ]]; then
  sha256sum -c "$BACKUP/openlinkhub-protected.sha256" >/dev/null || {
    echo "WARNING: protected OpenLinkHub files no longer match the pre-install hashes." >&2
  }
fi

if [[ $QUIET -eq 0 ]]; then
  echo "Rollback complete."
  echo "Restored backup: $BACKUP"
  echo "OpenRGB and OpenLinkHub installations/profile data were not removed."
fi
