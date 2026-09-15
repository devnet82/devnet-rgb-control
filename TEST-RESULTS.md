# Devnet RGB Control v8.7 — Physical Test Results

Status: **PASS on the developer's real hardware**

Date: 15 September 2026

Authoritative captured build supplied after successful test:

`devnet-rgb-control-v8.7-captured-20260915-031638.tar.gz`

SHA256 produced on the test machine at capture time:

`073751e158c7be41b41d05e7a7e44e124aa347cd2016086b766939569ccf65a6`

## Test sequence completed

- Started from known-good Devnet RGB Control v8.6.
- Pre-install RGB Doctor v8.6 passed.
- Recovery backup of the working v8.6 application was created.
- Protected OpenLinkHub configuration/profile files were hashed before installation.
- Staged v8.7 Python files compiled successfully.
- Staged shell wrappers passed shell syntax checks.
- Only Devnet-owned RGB application files were removed.
- OpenRGB remained installed.
- OpenLinkHub remained installed.
- v8.7 application files were installed.
- `devnet-openrgb-server.service` started successfully.
- `OpenLinkHub.service` started successfully.
- `devnet-rgb-master.service` started successfully.
- `devnet-rgb-control-app.service` started successfully.
- RGB Doctor v8.7 passed immediately after installation.
- Protected OpenLinkHub fan/profile files were byte-for-byte unchanged after installation.
- System reboot completed successfully.
- All four services started automatically after reboot.
- RGB Doctor v8.7 passed after reboot.
- RGB master reports v8.7 internally.
- Dashboard source reports v8.7.
- systemd RGB master service description reports v8.7.
- Dashboard HTTP endpoint was reachable after reboot.
- Dashboard page contained v8.7.
- Full normal shutdown completed successfully.
- Cold power-on after shutdown completed successfully.
- User physically confirmed RGB and fan behaviour were correct after cold start.

## Hardware confirmed during the test

- Gigabyte X870 EAGLE WIFI7
- PowerColor Red Devil RX 9070 XT
- 2 × Corsair Vengeance RGB DDR5
- Corsair Commander Core XT
- Arctic Liquid Freezer III A-RGB connected via motherboard ARGB
- Lian Li RGB light bar connected via motherboard ARGB

OpenRGB controller validation on port 6742 confirmed:

- 2 × Corsair Vengeance RGB DDR5
- PowerColor Red Devil RX9070XT
- X870 EAGLE WIFI7
- Commander Core XT remained isolated from port 6742

Commander validation on port 6743 confirmed:

- 5 zones
- 40 LEDs

## Fan control confirmed

OpenLinkHub remained `manual=false`.

Live fan mapping remained:

- Fan 1 = CPU
- Fan 2 = CPU
- Fan 3 = CPU
- Fan 4 = GPU-Hotspot
- Fan 5 = GPU-Hotspot

Protected fan/profile files remained unchanged:

- `OpenLinkHub/config.json`
- `database/profiles/410230319ac184aa2576ea061091005f.json`
- `database/profiles/410230319ac184aa2576ea061091005f-temp.json`
- `database/temperatures/CPU.json`
- `database/temperatures/GPU.json`
- `database/temperatures/GPU-Hotspot.json`

## Release status

This proves the captured v8.7 runtime state on the developer's real machine. It does **not** by itself prove a future fresh-machine standalone installer. The standalone public package must still be built from this captured state and then tested separately before public release.
