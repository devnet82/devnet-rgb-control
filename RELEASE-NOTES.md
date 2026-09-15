# Devnet RGB Control v8.8 Release Notes

## Release status

Devnet RGB Control v8.8 is the first standalone release prepared from the physically verified v8.7 runtime and then fully revalidated as v8.8 on the reference CachyOS system.

## What changed from v8.7

v8.8 keeps the proven RGB runtime behaviour while making the package suitable for a standalone release:

- portable user paths instead of `/home/dave`
- Commander serial auto-detection from the matching OpenLinkHub profile pair
- config-driven motherboard/GPU/RAM validation
- complete install, rollback and uninstall flows
- private Python environment with `openrgb-python==0.3.6`
- package-wide v8.8 version consistency
- beginner installation and recovery documentation
- protected OpenLinkHub hash checks before/after installation
- safe repair helper for the known OpenLinkHub `After=default.target` ordering problem

## Preserved behaviour

- AMD GPU hotspot/junction is the only temperature source
- colour bands remain:
  - <50°C blue `#99C1F1`
  - 50–59°C green `#57E389`
  - 60–69°C yellow `#FFFF00`
  - 70–79°C orange `#FF8000`
  - 80°C+ red `#FF0000`
- Commander remains isolated on OpenRGB SDK port 6743
- local motherboard/GPU/RAM remain on OpenRGB SDK port 6742
- Commander whole-device write-first + refresh behaviour is retained
- RGB switches off during normal master shutdown
- OpenLinkHub remains responsible for fan speeds
- `manual=false` is required
- Fan 1–3 = CPU
- Fan 4–5 = GPU-Hotspot

## Physical verification

Passed on the reference machine:

- standalone install over the verified v8.7 installation
- RGB Doctor v8.8
- protected OpenLinkHub hash checks
- Commander serial detection
- OpenRGB 6742 controller validation
- Commander 6743 5-zone / 40-LED validation
- dashboard and version checks
- reboot and automatic startup
- normal shutdown
- cold power-on
- motherboard RGB
- GPU RGB
- both Corsair RGB DDR5 modules
- Commander Core XT RGB
- fan behaviour remained correct under OpenLinkHub

Reference software during physical verification:

- CachyOS / Arch-based Linux
- Python 3.14.7
- systemd 261
- OpenRGB 1.0
- `openrgb-python==0.3.6`

## Automated QA

GitHub Actions package QA passed on Ubuntu 24.04 / Python 3.12.3 and covered:

- Bash syntax
- Python compilation
- version consistency
- fake-HOME standalone install
- protected OpenLinkHub state unchanged
- Commander serial auto-detection fixture
- upgrade backup creation
- rollback restoration
- reinstall
- safe uninstall

Rollback restoration was not deliberately performed on the successful live v8.8 hardware install; rollback correctness is covered by the automated fake-HOME test.

## Hardware scope

This release is intentionally hardware-specific. It should not be presented as a generic RGB controller.

Tested target hardware:

- Gigabyte X870 EAGLE WIFI7
- PowerColor Red Devil RX 9070 XT
- 2 × Corsair Vengeance RGB DDR5
- Corsair Commander Core XT
- AMD GPU hotspot/junction hwmon sensor
- motherboard-attached A-RGB devices on the reference PC

See `README.md` for the full software and hardware requirements, install, verification, rollback and uninstall instructions.
