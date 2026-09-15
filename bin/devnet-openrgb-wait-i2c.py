#!/usr/bin/env python3
import argparse, os, time, sys
from pathlib import Path

APP_VERSION="8.8"
if "--version" in sys.argv:
    print(f"Devnet RGB Control v{APP_VERSION} I2C readiness helper")
    raise SystemExit(0)

ap=argparse.ArgumentParser()
ap.add_argument("--timeout",type=float,default=120)
ap.add_argument("--once",action="store_true")
args=ap.parse_args()
sysroot=Path(os.getenv("DEVNET_I2C_SYS_ROOT","/sys/class/i2c-dev"))
devroot=Path(os.getenv("DEVNET_DEV_ROOT","/dev"))

def scan():
    rows=[]; piix=[]; amd=[]
    if not sysroot.exists():
        return rows,piix,amd
    for d in sorted(sysroot.glob("i2c-*")):
        try:name=(d/"name").read_text().strip()
        except Exception:continue
        node=devroot/d.name; ok=False; err=""
        if node.exists():
            try:
                fd=os.open(node,os.O_RDWR|os.O_CLOEXEC); os.close(fd); ok=True
            except OSError as e:
                err=f"{e.__class__.__name__}:{e.errno}"
        rows.append((d.name,name,node,ok,err))
        low=name.lower()
        if ok and "piix4" in low: piix.append((d.name,name))
        if ok and "amdgpu" in low: amd.append((d.name,name))
    return rows,piix,amd

deadline=time.monotonic()+(0 if args.once else args.timeout)
last_print=0.0
while True:
    rows,piix,amd=scan()
    if piix:
        print("[PASS] usable PIIX4 I2C: "+", ".join(f"{n} ({name})" for n,name in piix),flush=True)
        if amd: print("[PASS] usable AMDGPU I2C: "+", ".join(n for n,_ in amd[:4]),flush=True)
        else: print("[INFO] no openable AMDGPU-named I2C bus yet; PIIX4 gate is satisfied",flush=True)
        raise SystemExit(0)
    now=time.monotonic()
    if args.once or now>=deadline:
        print("ERROR: no openable PIIX4 I2C node is available to this user",flush=True)
        for n,name,node,ok,err in rows:
            if "piix4" in name.lower():
                print(f"  {n}: {name} node={node} openable={ok} {err}",flush=True)
        raise SystemExit(1)
    if now-last_print>=5:
        seen=[f"{n}:{'open' if ok else err or 'not-open'}" for n,name,node,ok,err in rows if "piix4" in name.lower()]
        print("Waiting for usable PIIX4 I2C access... "+(", ".join(seen) if seen else "no PIIX4 adapter enumerated yet"),flush=True)
        last_print=now
    time.sleep(1)
