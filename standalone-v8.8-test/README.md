# Devnet RGB Control v8.8 — standalone test package

Devnet RGB Control keeps the tested RGB devices synchronised to the AMD GPU hotspot temperature while **OpenLinkHub remains responsible for fan speeds**.

> **Status:** v8.8 is a test build derived from the physically verified v8.7 installation. v8.7 passed install, Doctor, reboot, normal shutdown, cold power-on and physical RGB/fan checks on the reference PC. v8.8 adds standalone packaging, portable user paths, automatic Commander serial detection and version cleanup, so it must be physically tested before publication.

## What it controls

RGB only:

- Gigabyte X870 EAGLE WIFI7 motherboard RGB
- PowerColor Red Devil RX 9070 XT RGB
- 2 × Corsair Vengeance RGB DDR5 modules
- Corsair Commander Core XT RGB, exposed by OpenLinkHub on OpenRGB SDK port 6743
- motherboard-connected A-RGB devices follow the motherboard output

Default GPU-hotspot colours:

| GPU hotspot | Colour |
| --- | --- |
| below 50°C | Blue `#99C1F1` |
| 50–59°C | Green `#57E389` |
| 60–69°C | Yellow `#FFFF00` |
| 70–79°C | Orange `#FF8000` |
| 80°C and above | Red `#FF0000` |

The dashboard can edit these colours and apply a temporary manual colour.

## Fan control is protected

This package does **not** create or change OpenLinkHub fan curves. The installer requires the existing OpenLinkHub fan setup to already be correct and hashes the protected files before and after installation.

Required mapping:

- Fan 1–3 → `CPU`
- Fan 4–5 → `GPU-Hotspot`
- `OpenLinkHub/config.json` → `manual=false`
- `GPU-Hotspot.json` → sensor `7`, using `~/.local/bin/devnet-gpu-hotspot`

The reference fan curve remains owned by OpenLinkHub and is not part of the Devnet install payload.

## Hardware requirements

This test release is intentionally strict. It is not yet advertised as a generic RGB controller.

Required/test target:

- AMD GPU exposing a Linux `Junction`, `Hotspot` or `Hot Spot` hwmon sensor
- Gigabyte X870 EAGLE WIFI7
- PowerColor Red Devil RX 9070 XT
- exactly 2 × Corsair Vengeance RGB DDR5 RGB modules
- Corsair Commander Core XT with the tested 5-zone / 40-LED OpenRGB layout
- working SMBus/I2C access for the logged-in user

Reference system also has an Arctic Liquid Freezer III A-RGB and Lian Li light bar connected to motherboard A-RGB headers.

## Software requirements

Required:

- Linux with systemd user services
- Bash
- Python 3 with `venv` support
- OpenRGB available at `/usr/bin/openrgb`
- OpenLinkHub installed at `~/OpenLinkHub/OpenLinkHub`
- OpenLinkHub user service named `OpenLinkHub.service`
- `xdg-open`
- working user access to the required `/dev/i2c-*` devices
- internet access on a fresh install so the installer can install `openrgb-python==0.3.6` into its private Python environment

Tested reference software:

- CachyOS / Arch-based Linux
- Python 3.14.7
- systemd 261
- OpenRGB 1.0
- `openrgb-python==0.3.6`

## Before installing

Do **not** uninstall OpenRGB or OpenLinkHub. Do not delete your OpenLinkHub profiles.

The installer performs read-only checks first. It will stop if the required fan profiles are wrong, if `manual=false` is not set, if the GPU-hotspot external sensor is not configured, or if it cannot identify exactly one matching Commander profile pair.

If OpenLinkHub has the known invalid `After=default.target` ordering edge, the installer stops before changing Devnet RGB. Run the included repair script first. It backs up any unit file it changes and does not touch fan JSON.

## Install / upgrade

1. Extract the package.
2. Open **Konsole** in the extracted folder.
3. Make the scripts runnable:

```bash
chmod +x *.sh
```

4. Install:

```bash
./install.sh
```

If the installer specifically reports the OpenLinkHub ordering problem, run:

```bash
./repair-openlinkhub-ordering.sh
./install.sh
```

The installer automatically:

- validates the package before touching the working installation
- validates the existing protected OpenLinkHub fan/profile state
- detects the Commander serial from the correct profile pair
- creates an exact recovery backup of the previous Devnet RGB files
- preserves existing RGB band colours during upgrade
- creates/reuses the private Python environment
- installs only Devnet-owned app files and user services
- starts the services
- runs the read-only RGB Doctor
- confirms protected OpenLinkHub hashes are unchanged
- checks v8.8 version consistency
- automatically attempts rollback if installation fails after changes begin

## Reboot test

After a successful install, reboot normally. Then return to the package folder and run:

```bash
./verify-after-reboot.sh
```

After that passes, physically check the RGB and fans, then do one normal shutdown, leave the PC off briefly, and perform a cold power-on.

## Open the dashboard

From the application menu choose **Devnet RGB Control**, or run:

```bash
devnet-rgb-control
```

The dashboard is local only at `127.0.0.1:8765`.

## Run the Doctor

```bash
devnet-rgb-doctor
```

The Doctor is read-only. It does not write RGB, rescan hardware or alter fan control.

## Roll back

The installer records its most recent recovery backup. To restore the installation that existed immediately before v8.8:

```bash
./rollback.sh
```

The rollback does not uninstall OpenRGB or OpenLinkHub and does not intentionally modify OpenLinkHub fan/profile JSON.

## Uninstall

```bash
./uninstall.sh
```

The uninstaller removes Devnet RGB app files, its private Python environment and its three Devnet user services. It preserves the RGB configuration, recovery backups, OpenRGB, OpenLinkHub and OpenLinkHub profile/temperature JSON.

## Files installed

Main files:

- `~/.local/bin/devnet-rgb-master`
- `~/.local/bin/devnet-rgb-control-app`
- `~/.local/bin/devnet-rgb-control`
- `~/.local/bin/devnet-rgb-doctor`
- `~/.local/bin/devnet-rgb-doctor-v88.py`
- `~/.local/bin/devnet-openrgb-wait-i2c.py`
- `~/.local/bin/devnet-openrgb-validate-6742.py`
- `~/.local/bin/devnet-gpu-hotspot`
- `~/.config/devnet-rgb-master/config.json`
- `~/.config/systemd/user/devnet-openrgb-server.service`
- `~/.config/systemd/user/devnet-rgb-master.service`
- `~/.config/systemd/user/devnet-rgb-control-app.service`
- `~/.local/share/applications/devnet-rgb-control.desktop`
- `~/.local/share/devnet-rgb/venv/`

## Testing status

### Physically verified baseline: v8.7

Verified on the reference hardware:

- protected upgrade from v8.6
- RGB Doctor
- dashboard
- reboot/autostart
- normal shutdown
- cold power-on
- motherboard/GPU/RAM/Commander RGB operation
- fan behaviour remained under OpenLinkHub

### v8.8

Before public release v8.8 must pass:

- syntax/compile QA
- version-consistency QA
- fake-HOME install
- fake upgrade backup and rollback
- fake uninstall
- real install over the verified v8.7 system
- Doctor v8.8
- reboot/autostart
- dashboard
- shutdown and cold power-on
- physical RGB/fan check

Do not describe v8.8 as physically verified until those real-hardware checks are complete.
