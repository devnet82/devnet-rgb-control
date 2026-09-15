#!/usr/bin/env bash
set -euo pipefail
HOME_DIR="${DEVNET_HOME:-$HOME}"
BIN="$HOME_DIR/.local/bin"
STATE="$HOME_DIR/.config/devnet-rgb-test/current-backup"
[[ -f "$STATE" ]] || { echo "No v8.7 test backup pointer found."; exit 1; }
BACKUP="$(cat "$STATE")"
PROTECTED="$BACKUP/openlinkhub-protected.sha256"

echo "=== Devnet RGB Control v8.7 post-reboot verification ==="
FAIL=0
check_service(){
  local u="$1"
  if systemctl --user is-active --quiet "$u"; then echo "[PASS] $u active"; else echo "[FAIL] $u not active"; FAIL=$((FAIL+1)); fi
}
for u in devnet-openrgb-server.service OpenLinkHub.service devnet-rgb-master.service devnet-rgb-control-app.service; do check_service "$u"; done

echo
if [[ -x "$BIN/devnet-rgb-doctor" ]]; then
  if "$BIN/devnet-rgb-doctor"; then echo "[PASS] RGB Doctor"; else echo "[FAIL] RGB Doctor"; FAIL=$((FAIL+1)); fi
else
  echo "[FAIL] devnet-rgb-doctor missing"; FAIL=$((FAIL+1))
fi

echo
if grep -qi 'v8\.7' "$BIN/devnet-rgb-master"; then echo "[PASS] RGB master reports v8.7 internally"; else echo "[FAIL] RGB master v8.7 string missing"; FAIL=$((FAIL+1)); fi
if grep -qi 'v8\.7' "$BIN/devnet-rgb-control-app"; then echo "[PASS] Dashboard source reports v8.7"; else echo "[FAIL] Dashboard v8.7 string missing"; FAIL=$((FAIL+1)); fi
if grep -qi 'v8\.7' "$HOME_DIR/.config/systemd/user/devnet-rgb-master.service"; then echo "[PASS] RGB master service description v8.7"; else echo "[FAIL] service v8.7 string missing"; FAIL=$((FAIL+1)); fi

echo
if [[ -f "$PROTECTED" ]]; then
  if sha256sum -c "$PROTECTED"; then echo "[PASS] OpenLinkHub protected fan/profile files unchanged"; else echo "[FAIL] protected fan/profile files changed"; FAIL=$((FAIL+1)); fi
else
  echo "[FAIL] protected-file hash list missing"; FAIL=$((FAIL+1))
fi

echo
if command -v python3 >/dev/null 2>&1; then
  python3 - <<'PY' || true
import urllib.request
try:
    with urllib.request.urlopen('http://127.0.0.1:8765/',timeout=4) as r:
        text=r.read().decode('utf-8','replace')
    print('[PASS] Dashboard HTTP reachable')
    print('[PASS] Dashboard page contains v8.7' if 'v8.7' in text.lower() else '[WARN] Dashboard reachable but v8.7 text not found in rendered page')
except Exception as e:
    print('[FAIL] Dashboard HTTP check:',e)
PY
fi

echo
journalctl --user -u devnet-rgb-master.service -b --no-pager | grep -Ei 'Devnet RGB master v8\.7|GPU Hotspot|Motherboard=OK|GPU RGB=OK|RAM [12]=OK|Commander RGB' | tail -30 || true

echo
if (( FAIL > 0 )); then
  echo "POST-REBOOT VERIFICATION FAILED: $FAIL check(s) failed."
  echo "Run ./rollback-to-v8.6.sh if the physical RGB/fan behaviour is also wrong."
  exit 1
fi

echo "AUTOMATED POST-REBOOT CHECKS PASSED."
echo "Now physically check RGB, fan behaviour, shutdown, and a fresh power-on."
