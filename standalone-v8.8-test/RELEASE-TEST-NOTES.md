# Devnet RGB Control v8.8 test notes

## Why v8.8 instead of publishing v8.7 directly

The uploaded v8.7 release-source capture is the authoritative physically-tested baseline. Inspection found release-portability/version issues that must change before a proper standalone package can be published:

- the captured dashboard user service and desktop launcher contain `/home/dave`
- the captured dashboard and Doctor contain the reference Commander serial directly
- the captured master still uses historical OpenRGB client labels `v7.4` and `v7.1`
- the public package needs installer/uninstaller/rollback/dependency handling and full version-consistency QA

Those are code/package changes, so the next build is v8.8 rather than silently changing the already-verified v8.7 release state.

## Behaviour deliberately preserved from v8.7

- AMD GPU hotspot/junction is the temperature source
- exact default colour thresholds and RGB values
- hysteresis behaviour
- persistent OpenRGB 6742 connection for motherboard/GPU/RAM
- Commander on isolated OpenRGB SDK port 6743
- Commander whole-device write first, short lead, local-device writes, one short Commander refresh
- RGB off on normal master shutdown
- OpenRGB 6742 waits for usable PIIX4 I2C
- 6742 must expose the expected motherboard/GPU/RAM set and must not expose Commander
- OpenLinkHub retains fan-speed ownership
- `manual=false`
- Fan 1–3 CPU / Fan 4–5 GPU-Hotspot profile mapping
- dashboard manual colour and editable temperature colours
- read-only Doctor

## v8.8 changes that require physical retest

- portable service paths
- config-driven device validation
- Commander serial discovery/migration
- standalone install/backup/rollback/uninstall path
- dashboard range-label correction
- version normalisation

## Required real-hardware acceptance test

1. Confirm current v8.7 is working before upgrade.
2. Run `./install.sh` from v8.8.
3. Installer must pass Doctor and protected-file hash checks.
4. Confirm dashboard opens and reports v8.8.
5. Confirm RGB changes with GPU hotspot temperature.
6. Confirm fan behaviour is unchanged and still owned by OpenLinkHub.
7. Reboot.
8. Run `./verify-after-reboot.sh`.
9. Physically inspect motherboard, GPU, both RAM modules and Commander RGB.
10. Shut down normally and confirm controlled RGB-off behaviour.
11. Leave PC off briefly, then cold power-on.
12. Confirm RGB and fans initialise correctly.
13. Test `./rollback.sh` only if needed; do not deliberately roll back a good install merely to create a test result unless a separate rollback test is desired.

## Publish gate

Do not create a public v8.8 release until the real-hardware acceptance test has passed and the user approves the exact tested build.
