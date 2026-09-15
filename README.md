# Devnet RGB Control v8.7 — PRIVATE TEST BUILD

**Do not make this repository public.** This is a test/recovery repository for David's currently working Devnet RGB Control v8.6 installation.

The purpose of this test is to prove that the current working installation can be backed up, removed, reinstalled as v8.7, rebooted, checked, and rolled back without changing OpenLinkHub fan control.

## What this test protects

The test scripts do **not** uninstall OpenRGB or OpenLinkHub. They do **not** intentionally change the OpenLinkHub fan curves or fan assignments.

Expected fan configuration:

- Fan 1–3 = CPU
- Fan 4–5 = AMD GPU hotspot/junction temperature
- 55°C and below = 0%
- 56–59°C = 35%
- 60–69°C = 45%
- 70–79°C = 60%
- 80°C and above = 100%
- OpenLinkHub `manual=false`

The installer makes a byte-for-byte backup of the current Devnet RGB application files before it removes anything. It also hashes the protected OpenLinkHub configuration files before and after the test.

## Hardware this build was developed and tested for

This is **tested hardware**, not a claim that every RGB device is supported:

- Gigabyte X870 EAGLE WIFI7 motherboard
- PowerColor Red Devil RX 9070 XT
- Corsair Commander Core XT
- 2 × Corsair Vengeance RGB DDR5 modules
- Arctic Liquid Freezer III A-RGB connected to motherboard ARGB
- Lian Li RGB light bar connected to motherboard ARGB

## Software required

- CachyOS / Arch-based Linux with systemd user services
- KDE Plasma / Wayland is the primary tested desktop
- OpenRGB installed as `/usr/bin/openrgb`
- OpenLinkHub already installed and working
- Python 3
- Existing Devnet RGB Python environment at `~/.local/share/devnet-rgb/venv`
- `openrgb-python` already available inside that Devnet environment
- `git` for the easiest download method

## Before starting

Your current **v8.6 must be working**. Do not manually uninstall it first. The test installer performs the controlled uninstall itself **after** making the recovery backup.

Open **Konsole** and copy/paste these commands one line at a time:

```bash
cd ~/Downloads

git clone https://github.com/devnet82/devnet-rgb-control-test.git

cd devnet-rgb-control-test

chmod +x *.sh

./install-v8.7-test.sh
```

Because this is a private repository, GitHub may ask you to authenticate when cloning. If cloning is inconvenient, open this repository in your browser, use **Code → Download ZIP**, extract it, open Konsole in the extracted folder, then run:

```bash
chmod +x *.sh
./install-v8.7-test.sh
```

## What the installer does

1. Runs preflight checks against the working installation.
2. Runs the current RGB Doctor before making changes.
3. Creates a complete recovery backup of the Devnet-owned application files.
4. Records hashes of the OpenLinkHub fan/profile files.
5. Creates a staged v8.7 copy from the **actual files currently working on this PC**.
6. Updates visible/internal application version strings to **v8.7**.
7. Syntax-checks the staged Python and shell files.
8. Stops only the Devnet RGB application services.
9. Removes the old Devnet RGB application files/units being replaced.
10. Leaves OpenLinkHub installed and leaves its fan/profile files alone.
11. Installs the staged v8.7 files.
12. Starts the services and runs RGB Doctor.
13. Verifies OpenLinkHub's protected files are byte-for-byte unchanged.
14. Creates a captured v8.7 archive in `~/Downloads` for final packaging/review.

## After the installer succeeds

Reboot normally.

After logging back in, open Konsole and run:

```bash
cd ~/Downloads/devnet-rgb-control-test
./verify-after-reboot.sh
```

Then check the actual hardware:

- RGB starts automatically.
- Dashboard says **v8.7**.
- Motherboard/AIO/Lian Li lighting follows GPU hotspot colour.
- RX 9070 XT lighting follows GPU hotspot colour.
- Both Corsair RAM modules follow GPU hotspot colour.
- Commander Core XT fan RGB follows GPU hotspot colour.
- Fan 1–3 still follow CPU.
- Fan 4–5 still follow GPU hotspot.
- Below 56°C, Fan 4–5 are allowed to be zero RPM.
- Shutdown completes normally and lighting turns off correctly.
- A fresh power-on starts everything correctly.

## If anything is wrong

Do **not** start manually editing systemd/OpenLinkHub files.

Run:

```bash
cd ~/Downloads/devnet-rgb-control-test
./rollback-to-v8.6.sh
```

That restores the exact Devnet application files captured before the test.

## Uninstalling only the v8.7 test app

If you intentionally want to remove the v8.7 test files while keeping OpenRGB, OpenLinkHub, the Python environment, backups and fan profiles:

```bash
./uninstall-v8.7-test.sh
```

Normally, use `rollback-to-v8.6.sh` instead, because it returns the PC to the known-good v8.6 setup.

## Important

This private test build is **not the public release**. After the physical reboot/shutdown test passes, upload the generated `devnet-rgb-control-v8.7-captured-*.tar.gz` file back into the ChatGPT conversation. That captured archive becomes the authoritative source for the cleaned, standalone public package.
