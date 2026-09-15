#!/usr/bin/env python3
import argparse, json, os, sys, time
from pathlib import Path

APP_VERSION="8.8"
if "--version" in sys.argv:
    print(f"Devnet RGB Control v{APP_VERSION} OpenRGB 6742 validator")
    raise SystemExit(0)

ap=argparse.ArgumentParser()
ap.add_argument("--timeout",type=float,default=150)
ap.add_argument("--once",action="store_true")
args=ap.parse_args()

CFG_PATH=Path.home()/".config/devnet-rgb-master/config.json"

def load_expected():
    cfg=json.loads(CFG_PATH.read_text())
    return (
        str(cfg["motherboard"]).lower(),
        str(cfg["gpu_rgb_device"]).lower(),
        str(cfg.get("ram_rgb_device","Corsair Vengeance RGB DDR5")).lower(),
        int(cfg.get("ram_count",2)),
    )

def read_names():
    fake=os.getenv("DEVNET_FAKE_SDK_6742")
    if fake is not None:
        return [x for x in fake.split("|") if x]
    from openrgb import OpenRGBClient
    c=None
    try:
        c=OpenRGBClient("127.0.0.1",6742,"Devnet RGB v8.8 startup validator",protocol_version=1)
        return [d.name for d in c.devices]
    finally:
        if c is not None:
            try:c.disconnect()
            except Exception:pass

def check(names):
    mb_wanted,gpu_wanted,ram_wanted,ram_count=load_expected()
    low=[n.lower() for n in names]
    ram=sum(ram_wanted in n for n in low)
    mb=any(mb_wanted in n or n in mb_wanted for n in low)
    gpu=any(gpu_wanted in n or n in gpu_wanted for n in low)
    commander=any("commander" in n and "core" in n for n in low)
    return ram==ram_count and mb and gpu and not commander

deadline=time.monotonic()+(0 if args.once else args.timeout)
last=[]; last_err=""
while True:
    try:
        last=read_names(); last_err=""
        if check(last):
            print("[PASS] 6742 controllers healthy:",flush=True)
            for n in last: print("  "+n,flush=True)
            raise SystemExit(0)
    except SystemExit:
        raise
    except Exception as e:
        last_err=f"{type(e).__name__}: {e}"
    if args.once or time.monotonic()>=deadline:
        print("ERROR: 6742 did not expose the expected controller set",flush=True)
        print("  last controllers="+repr(last),flush=True)
        if last_err: print("  last SDK error="+last_err,flush=True)
        raise SystemExit(1)
    time.sleep(1)
