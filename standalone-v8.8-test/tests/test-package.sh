#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
HOME_FAKE="$TMP/home"
OLH="$HOME_FAKE/OpenLinkHub"
SERIAL="TESTCOMMANDER123"
mkdir -p "$OLH/database/profiles" "$OLH/database/temperatures" "$HOME_FAKE/.local/bin"

cat > "$OLH/config.json" <<'JSON'
{"manual": false}
JSON
cat > "$OLH/database/profiles/$SERIAL.json" <<'JSON'
{"SpeedProfiles":{"0":"CPU","1":"CPU","2":"CPU","3":"GPU-Hotspot","4":"GPU-Hotspot"}}
JSON
cp "$OLH/database/profiles/$SERIAL.json" "$OLH/database/profiles/$SERIAL-temp.json"
cat > "$OLH/database/temperatures/CPU.json" <<'JSON'
{}
JSON
cat > "$OLH/database/temperatures/GPU.json" <<'JSON'
{}
JSON
cat > "$OLH/database/temperatures/GPU-Hotspot.json" <<JSON
{"sensor":7,"device":"$HOME_FAKE/.local/bin/devnet-gpu-hotspot"}
JSON

bash -n "$ROOT/install.sh" "$ROOT/uninstall.sh" "$ROOT/rollback.sh" "$ROOT/repair-openlinkhub-ordering.sh" "$ROOT/verify-after-reboot.sh"
python3 -m py_compile \
  "$ROOT/bin/devnet-rgb-master" \
  "$ROOT/bin/devnet-rgb-control-app" \
  "$ROOT/bin/devnet-rgb-doctor-v88.py" \
  "$ROOT/bin/devnet-openrgb-wait-i2c.py" \
  "$ROOT/bin/devnet-openrgb-validate-6742.py" \
  "$ROOT/bin/devnet-gpu-hotspot"
bash "$ROOT/tests/version-consistency.sh"

DEVNET_TEST_MODE=1 DEVNET_HOME="$HOME_FAKE" bash "$ROOT/install.sh"

[[ -f "$HOME_FAKE/.local/bin/devnet-rgb-master" ]]
[[ -f "$HOME_FAKE/.local/bin/devnet-rgb-control-app" ]]
[[ -f "$HOME_FAKE/.config/systemd/user/devnet-rgb-master.service" ]]
[[ -f "$HOME_FAKE/.config/devnet-rgb-master/config.json" ]]
[[ -f "$HOME_FAKE/.local/share/applications/devnet-rgb-control.desktop" ]]

python3 - "$HOME_FAKE/.config/devnet-rgb-master/config.json" "$SERIAL" <<'PY'
import json,sys
cfg=json.load(open(sys.argv[1]))
assert cfg["app_version"]=="8.8"
assert cfg["commander_serial"]==sys.argv[2]
assert cfg["bands"][0]["rgb"]==[153,193,241]
PY

grep -q "$HOME_FAKE/.local/bin/devnet-rgb-control" "$HOME_FAKE/.local/share/applications/devnet-rgb-control.desktop"

python3 - "$OLH" <<'PY'
import json,sys
from pathlib import Path
r=Path(sys.argv[1])
assert json.loads((r/"config.json").read_text())["manual"] is False
wanted={"0":"CPU","1":"CPU","2":"CPU","3":"GPU-Hotspot","4":"GPU-Hotspot"}
for p in (r/"database/profiles").glob("*.json"):
    assert json.loads(p.read_text())["SpeedProfiles"]==wanted
PY

# Test rollback restores a prior file exactly.
echo 'OLD-VERSION-SENTINEL' > "$HOME_FAKE/.local/bin/devnet-rgb-control"
sleep 1
DEVNET_TEST_MODE=1 DEVNET_HOME="$HOME_FAKE" bash "$ROOT/install.sh"
BACKUP="$(cat "$HOME_FAKE/.config/devnet-rgb-backups/last-v8.8-backup")"
DEVNET_TEST_MODE=1 DEVNET_HOME="$HOME_FAKE" bash "$ROOT/rollback.sh" --backup "$BACKUP"
grep -qx 'OLD-VERSION-SENTINEL' "$HOME_FAKE/.local/bin/devnet-rgb-control"

# Reinstall and test uninstaller leaves OpenLinkHub and config data intact.
sleep 1
DEVNET_TEST_MODE=1 DEVNET_HOME="$HOME_FAKE" bash "$ROOT/install.sh"
DEVNET_TEST_MODE=1 DEVNET_HOME="$HOME_FAKE" bash "$ROOT/uninstall.sh"
[[ ! -e "$HOME_FAKE/.local/bin/devnet-rgb-master" ]]
[[ -f "$HOME_FAKE/.config/devnet-rgb-master/config.json" ]]
[[ -f "$OLH/config.json" ]]
[[ -f "$OLH/database/profiles/$SERIAL.json" ]]

echo "[PASS] fake-HOME install, upgrade backup, rollback and uninstall tests passed"
