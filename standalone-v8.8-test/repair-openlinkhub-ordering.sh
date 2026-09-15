#!/usr/bin/env bash
set -euo pipefail

VERSION="8.8"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.config/devnet-rgb-backups/openlinkhub-ordering-v${VERSION}-$STAMP"

say(){ printf '\n=== %s ===\n' "$*"; }
fail(){ printf '\nERROR: %s\n' "$*" >&2; exit 1; }

[[ ${EUID:-$(id -u)} -ne 0 ]] || fail "Run this as your normal desktop user, not with sudo."
command -v systemctl >/dev/null || fail "systemctl is required"
command -v python3 >/dev/null || fail "python3 is required"

if ! systemctl --user cat OpenLinkHub.service >/dev/null 2>&1; then
  fail "OpenLinkHub.service is not installed as a user service."
fi

mapfile -t PATHS < <(systemctl --user show OpenLinkHub.service -p FragmentPath -p DropInPaths --value | tr ' ' '\n' | sed '/^$/d' | sort -u)
[[ ${#PATHS[@]} -gt 0 ]] || fail "Could not find the OpenLinkHub user-service files."

mkdir -p "$BACKUP"
changed=0

for p in "${PATHS[@]}"; do
  [[ -f "$p" ]] || continue
  if grep -Eq '^[[:space:]]*After=.*default\.target' "$p"; then
    cp -a "$p" "$BACKUP/$(basename "$p")"
    python3 - "$p" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
out=[]
for line in p.read_text().splitlines():
    if line.lstrip().startswith("After="):
        prefix, value=line.split("=",1)
        tokens=[x for x in value.split() if x != "default.target"]
        if tokens:
            line=prefix+"="+" ".join(tokens)
        else:
            line="# Devnet RGB v8.8 removed invalid After=default.target"
    out.append(line)
p.write_text("\n".join(out)+"\n")
PY
    echo "[PASS] Removed default.target ordering edge from $p"
    changed=1
  fi
done

if [[ $changed -eq 0 ]]; then
  echo "[PASS] OpenLinkHub has no file containing After=default.target; nothing changed."
else
  systemctl --user daemon-reload
fi

after="$(systemctl --user show OpenLinkHub.service -p After --value)"
if grep -qw default.target <<<"$after"; then
  fail "The effective OpenLinkHub service still has After=default.target. Restore files from $BACKUP if needed and inspect the unit manually."
fi

echo "[PASS] Effective OpenLinkHub ordering no longer contains After=default.target"
echo "Backup (only if a file changed): $BACKUP"
echo "Fan profiles and OpenLinkHub JSON were not edited."
