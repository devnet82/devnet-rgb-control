#!/usr/bin/env bash
set -euo pipefail
HOME_DIR="${DEVNET_HOME:-$HOME}"
STATE="$HOME_DIR/.config/devnet-rgb-test/current-backup"
[[ -f "$STATE" ]] || { echo "No v8.7 test backup pointer found: $STATE"; exit 1; }
BACKUP="$(cat "$STATE")"
MANIFEST="$BACKUP/manifest.txt"
ARCHIVE="$BACKUP/devnet-rgb-v8.6-working-files.tar.gz"
[[ -f "$MANIFEST" && -f "$ARCHIVE" ]] || { echo "Backup is incomplete: $BACKUP"; exit 1; }

echo "=== Devnet RGB v8.7 test rollback -> known-good v8.6 ==="
echo "Backup: $BACKUP"
echo
systemctl --user stop devnet-rgb-control-app.service devnet-rgb-master.service devnet-openrgb-server.service >/dev/null 2>&1 || true

# Remove the v8.7 files represented by the original manifest, plus the renamed v8.7 Doctor source.
while IFS= read -r rel; do rm -rf "$HOME_DIR/$rel"; done < "$MANIFEST"
rm -f "$HOME_DIR/.local/bin/devnet-rgb-doctor-v87.py"

tar -xzf "$ARCHIVE" -C "$HOME_DIR"
systemctl --user daemon-reload
systemctl --user enable devnet-openrgb-server.service devnet-rgb-master.service devnet-rgb-control-app.service >/dev/null 2>&1 || true
systemctl --user start devnet-openrgb-server.service
systemctl --user start OpenLinkHub.service
systemctl --user start devnet-rgb-master.service
systemctl --user start devnet-rgb-control-app.service
sleep 3

echo
for u in devnet-openrgb-server.service OpenLinkHub.service devnet-rgb-master.service devnet-rgb-control-app.service; do
  printf '%-36s ' "$u"
  systemctl --user is-active "$u" || true
done

echo
if [[ -x "$HOME_DIR/.local/bin/devnet-rgb-doctor" ]]; then
  "$HOME_DIR/.local/bin/devnet-rgb-doctor" || true
fi

echo
echo "Rollback complete. The exact Devnet RGB application files captured before the v8.7 test have been restored."
echo "OpenRGB and OpenLinkHub were not uninstalled."
echo "The backup has been kept at: $BACKUP"
