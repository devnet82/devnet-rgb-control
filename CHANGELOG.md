# Changelog

## v8.8 — physically verified standalone release

Based on the physically verified v8.7 runtime and then fully retested as the standalone v8.8 package.

Changes:

- adds a complete standalone installer, rollback and safe uninstaller
- adds beginner-friendly hardware/software/install documentation
- preserves and hashes protected OpenLinkHub fan/profile files during install
- automatically detects the Commander serial from the matching OpenLinkHub profile pair instead of hard-coding one machine's serial
- uses portable systemd `%h` paths instead of `/home/dave` in service files
- generates the desktop launcher with the installing user's home directory
- normalises active runtime/client/service version strings to v8.8
- adds `--version` reporting for the main Devnet commands/helpers
- moves motherboard, GPU and RAM matching to config-driven values in the dashboard/Doctor/validator
- fixes dashboard temperature-range labels to show the intended bands clearly
- keeps the proven v8.7 Commander whole-device write-first + refresh behaviour
- keeps the proven GPU-hotspot-only temperature source
- adds automated package version-consistency checks
- adds fake-HOME install/backup/rollback/uninstall QA
- includes a safe OpenLinkHub ordering repair for the known `After=default.target` cycle issue

No OpenLinkHub fan curve is supplied or rewritten by the normal installer.

Physical acceptance completed successfully on the reference CachyOS system:

- standalone install/upgrade from v8.7
- RGB Doctor v8.8
- protected OpenLinkHub file hash verification
- dashboard/version checks
- reboot/autostart
- normal shutdown
- cold power-on
- motherboard, GPU, both RAM modules and Commander RGB operation
- fan behaviour remained under OpenLinkHub

Rollback restoration and uninstall were additionally tested in the automated fake-HOME package QA. Live rollback was not deliberately performed after the good hardware acceptance test.

## v8.7 — physically verified baseline

v8.7 was captured from the working installation after passing installation, RGB Doctor, reboot, dashboard/version checks, normal shutdown, cold power-on and physical RGB/fan verification on the reference hardware.

Its runtime behaviour was the baseline for v8.8.
