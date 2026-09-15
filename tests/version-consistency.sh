#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED="8.8"

[[ "$(tr -d '[:space:]' < "$ROOT/VERSION")" == "$EXPECTED" ]]
grep -q '"app_version": "8.8"' "$ROOT/config/config.json"

FILES=(
  bin/devnet-rgb-master
  bin/devnet-rgb-control-app
  bin/devnet-rgb-control
  bin/devnet-rgb-doctor-v88.py
  bin/devnet-openrgb-wait-i2c.py
  bin/devnet-openrgb-validate-6742.py
  bin/devnet-gpu-hotspot
  systemd/devnet-openrgb-server.service
  systemd/devnet-rgb-master.service
  systemd/devnet-rgb-control-app.service
  desktop/devnet-rgb-control.desktop.in
)

for rel in "${FILES[@]}"; do
  f="$ROOT/$rel"
  [[ -f "$f" ]] || { echo "[FAIL] missing $rel"; exit 1; }
  grep -q '8\.8' "$f" || { echo "[FAIL] v8.8 string missing from $rel"; exit 1; }
  if grep -Eq 'Devnet[^\n]*v(7\.|8\.[0-7])' "$f"; then
    echo "[FAIL] stale Devnet application version found in $rel"
    grep -En 'Devnet[^\n]*v(7\.|8\.[0-7])' "$f" || true
    exit 1
  fi
done

echo "[PASS] Devnet RGB Control runtime/package version strings are consistently v8.8"
