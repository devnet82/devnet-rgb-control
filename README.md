# Devnet RGB Control v8.8

Devnet RGB Control keeps the tested RGB devices synchronised to the AMD GPU hotspot temperature while **OpenLinkHub remains responsible for fan speeds**.

> **Release status:** v8.8 has passed automated package QA and full real-hardware acceptance on the reference CachyOS PC: install/upgrade, RGB Doctor, dashboard/version checks, reboot/autostart, normal shutdown, cold power-on, physical RGB checks and fan-behaviour checks.

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

This release is intentionally strict. It is not advertised as a generic RGB controller.

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

Physically tested reference software:

- CachyOS / Arch-based Linux
- Python 3.14.7
- systemd 261
- OpenRGB 1.0
- `openrgb-python==0.3.6`

Automated package QA also passed on Ubuntu 24.04 / Python 3.12.3 using the fake-HOME test harness.

## Before installing

Do **not** uninstall OpenRGB or OpenLinkHub. Do not delete your OpenLinkHub profiles.

The installer performs read-only checks first. It stops if the required fan profiles are wrong, if `manual=false` is not set, if the GPU-hotspot external sensor is not configured, or if it cannot identify exactly one matching Commander profile pair.

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

## Reboot verification

After a successful install, reboot normally. Then return to the package folder and run:

```bash
./verify-after-reboot.sh
```

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

Rollback restoration is covered by automated fake-HOME QA. It was not deliberately run against the good real-hardware v8.8 installation because the live acceptance test succeeded.

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

## Verification status

### v8.8 — physically verified release

Passed on the reference hardware:

- standalone install over the verified v8.7 system
- RGB Doctor v8.8
- protected OpenLinkHub hash checks
- Commander serial auto-detection
- motherboard/GPU/2×RAM/Commander detection
- dashboard and v8.8 version checks
- reboot/autostart
- normal shutdown
- cold power-on
- physical RGB operation
- fan behaviour remained under OpenLinkHub

Automated QA additionally covers syntax/compile checks, version consistency, fake-HOME standalone install, upgrade backup creation, rollback restoration and safe uninstall.

See `RELEASE-NOTES.md` and `CHANGELOG.md` for release details.
