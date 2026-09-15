#!/usr/bin/env bash
set -euo pipefail

VERSION="8.8"
BIN="$HOME/.local/bin"
CFG="$HOME/.config/devnet-rgb-master/config.json"

echo "=== Devnet RGB Control v8.8 post-reboot verification ==="
for u in devnet-openrgb-server.service OpenLinkHub.service devnet-rgb-master.service devnet-rgb-control-app.service; do
  systemctl --user is-active --quiet "$u" || { echo "[FAIL] $u is not active"; exit 1; }
  echo "[PASS] $u active"
done

echo
"$BIN/devnet-rgb-doctor"
echo "[PASS] RGB Doctor"

echo
"$BIN/devnet-rgb-control" --version | grep -qx 'Devnet RGB Control v8.8'
"$HOME/.local/share/devnet-rgb/venv/bin/python" "$BIN/devnet-rgb-master" --version | grep -qx 'Devnet RGB Control v8.8 master'
"$HOME/.local/share/devnet-rgb/venv/bin/python" "$BIN/devnet-rgb-control-app" --version | grep -qx 'Devnet RGB Control v8.8 dashboard'
"$BIN/devnet-rgb-doctor" --version | grep -qx 'Devnet RGB Doctor v8.8'
python3 - "$CFG" <<'PY'
import json,sys
cfg=json.load(open(sys.argv[1]))
assert cfg.get("app_version")=="8.8"
assert cfg.get("commander_serial")
PY
echo "[PASS] v8.8 version/config consistency"

python3 - <<'PY'
import urllib.request
with urllib.request.urlopen("http://127.0.0.1:8765/",timeout=5) as r:
    body=r.read().decode("utf-8","replace")
assert "v8.8" in body
PY
echo "[PASS] Dashboard HTTP reachable and contains v8.8"

echo
journalctl --user -u devnet-rgb-master.service -b --no-pager -n 15

echo
echo "AUTOMATED POST-REBOOT CHECKS PASSED."
echo "Now physically check RGB, fan behaviour, shutdown, and a fresh power-on."
