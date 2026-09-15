#!/usr/bin/env python3
import json, subprocess, sys, urllib.request
from pathlib import Path

APP_VERSION="8.8"
H=Path.home(); FAIL=0; WARN=0
CFG_PATH=H/".config/devnet-rgb-master/config.json"

if "--version" in sys.argv:
    print(f"Devnet RGB Doctor v{APP_VERSION}")
    raise SystemExit(0)

def mark(kind,msg):
    global FAIL,WARN
    print(f"[{kind}] {msg}")
    if kind=="FAIL": FAIL+=1
    elif kind=="WARN": WARN+=1

def cmd(args):
    return subprocess.run(args,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)

print(f"=== Devnet RGB Doctor v{APP_VERSION} ===")
print("READ-ONLY: no RGB writes, no rescans, no fan-control changes.")

try:
    cfg=json.loads(CFG_PATH.read_text())
    mark("PASS" if str(cfg.get("app_version"))==APP_VERSION else "FAIL",f"config app_version={cfg.get('app_version')!r}")
    serial=str(cfg.get("commander_serial","")).strip()
    mobo=str(cfg.get("motherboard","")).lower()
    gpu=str(cfg.get("gpu_rgb_device","")).lower()
    ram=str(cfg.get("ram_rgb_device","Corsair Vengeance RGB DDR5")).lower()
    ram_count=int(cfg.get("ram_count",2))
except Exception as e:
    cfg={}; serial=""; mobo=gpu=""; ram="corsair vengeance rgb ddr5"; ram_count=2
    mark("FAIL",f"RGB config read: {e}")

for s in ("devnet-openrgb-server.service","devnet-rgb-master.service","OpenLinkHub.service","devnet-rgb-control-app.service"):
    p=cmd(["systemctl","--user","is-active",s]); mark("PASS" if p.returncode==0 else "FAIL",f"{s}: {p.stdout.strip() or 'inactive'}")

after=cmd(["systemctl","--user","show","OpenLinkHub.service","-p","After","--value"]).stdout.split()
mark("FAIL" if "default.target" in after else "PASS","OpenLinkHub has no After=default.target ordering edge")

i2c=cmd([str(H/".local/share/devnet-rgb/venv/bin/python"),str(H/".local/bin/devnet-openrgb-wait-i2c.py"),"--once"])
mark("PASS" if i2c.returncode==0 else "FAIL","I2C readiness: "+(i2c.stdout.strip().splitlines()[-1] if i2c.stdout.strip() else i2c.stderr.strip()))

helper=H/".local/bin/devnet-gpu-hotspot"
try:
    t=float(subprocess.check_output([str(helper)],text=True,timeout=4).strip()); mark("PASS" if 0<t<200 else "FAIL",f"GPU hotspot: {t:.1f}C")
except Exception as e:
    t=0; mark("FAIL",f"GPU hotspot helper: {e}")

root=H/"OpenLinkHub"
try:
    olh=json.loads((root/"config.json").read_text()); mark("PASS" if olh.get("manual") is False else "FAIL",f"OpenLinkHub manual={olh.get('manual')!r}")
    wanted={"0":"CPU","1":"CPU","2":"CPU","3":"GPU-Hotspot","4":"GPU-Hotspot"}
    if not serial:
        mark("FAIL","Commander serial missing from Devnet config")
    else:
        for suffix in ("","-temp"):
            p=root/"database/profiles"/f"{serial}{suffix}.json"; d=json.loads(p.read_text())
            mark("PASS" if d.get("SpeedProfiles")==wanted else "FAIL",f"{p.name} Fan1-3=CPU / Fan4-5=GPU-Hotspot")
    hp=json.loads((root/"database/temperatures/GPU-Hotspot.json").read_text())
    mark("PASS" if hp.get("sensor")==7 and str(hp.get("device","")).endswith("/.local/bin/devnet-gpu-hotspot") else "FAIL",f"GPU-Hotspot sensor={hp.get('sensor')} device={hp.get('device')!r}")
except Exception as e:
    mark("FAIL",f"OpenLinkHub profile read: {e}")

try:
    from openrgb import OpenRGBClient
    c=OpenRGBClient("127.0.0.1",6742,f"Devnet Doctor v{APP_VERSION}",protocol_version=1); names=[d.name for d in c.devices]; c.disconnect(); low=[n.lower() for n in names]
    mark("PASS" if len(names)>=ram_count+2 else "FAIL",f"6742 controllers={len(names)}: {names}")
    mark("PASS" if sum(ram in n for n in low)==ram_count else "FAIL",f"6742 has {ram_count} expected RAM module(s)")
    mark("PASS" if any(mobo in n or n in mobo for n in low) else "FAIL","6742 motherboard present")
    mark("PASS" if any(gpu in n or n in gpu for n in low) else "FAIL","6742 GPU RGB present")
    mark("PASS" if not any("commander" in n and "core" in n for n in low) else "FAIL","Commander remains isolated from 6742")
except Exception as e:
    mark("FAIL",f"6742 SDK: {type(e).__name__}: {e}")

try:
    from openrgb import OpenRGBClient
    c=OpenRGBClient("127.0.0.1",6743,f"Devnet Doctor v{APP_VERSION} hub")
    d=next((x for x in c.devices if "commander" in x.name.lower() and "core" in x.name.lower()),None)
    if d is None: mark("FAIL","Commander missing on 6743")
    else:
        mark("PASS",f"6743 Commander zones={len(d.zones)} LEDs={len(d.leds)}")
        mark("PASS" if len(d.zones)==5 and len(d.leds)==40 else "FAIL","Commander expected 5-zone / 40-LED layout")
    c.disconnect()
except Exception as e:
    mark("FAIL",f"6743 SDK: {type(e).__name__}: {e}")

try:
    with urllib.request.urlopen(f"http://127.0.0.1:27003/api/devices/{serial}",timeout=5) as r: obj=json.loads(r.read().decode())
    dev=((obj.get("device") or {}).get("devices") or {}); got={str(i):(dev.get(str(i)) or {}).get("profile") for i in range(5)}
    wanted={"0":"CPU","1":"CPU","2":"CPU","3":"GPU-Hotspot","4":"GPU-Hotspot"}
    mark("PASS" if got==wanted else "FAIL",f"live fan profiles: {got}")
    r4=int((dev.get("3") or {}).get("rpm") or 0); r5=int((dev.get("4") or {}).get("rpm") or 0)
    if t>=56:
        mark("PASS" if r4>0 else "FAIL",f"Fan 4 at hotspot {t:.1f}C: {r4} RPM")
        mark("PASS" if r5>0 else "FAIL",f"Fan 5 at hotspot {t:.1f}C: {r5} RPM")
    else:
        mark("PASS",f"Hotspot {t:.1f}C <56C; Fan4/Fan5 zero-RPM permitted ({r4}/{r5} RPM)")
except Exception as e:
    mark("FAIL",f"OpenLinkHub live fan API: {e}")

print("--- Result ---")
print("DIAGNOSTIC PASSED" if FAIL==0 else f"DIAGNOSTIC FAILED: {FAIL} failure(s), {WARN} warning(s)")
raise SystemExit(0 if FAIL==0 else 1)
