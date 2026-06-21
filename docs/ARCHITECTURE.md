# Architecture

See [`../CLAUDE.md`](../CLAUDE.md) for the full standards. This is the quick map.

## The two axes

| Axis | Folder | Bound when | Notes |
|---|---|---|---|
| **Device** (SBC hardware) | `devices/` | build time | One image per family (bootloader/firmware differ). `device-detect` applies model quirks at boot. |
| **Printer** (the machine) | `printers/` | **runtime** | Every image bundles all profiles; `printer-detect` selects the live one. |

They never couple in source. `flake.nix` composes one device with the whole printer set.

## Boot-time flow

```
printeros-device-detect      → writes DEVICE/DEVICE_MODEL to /run/printeros/caps.env
printeros-printer-detect      → scans /dev/serial/by-id vs each printer's mcuMatch,
                                assembles /var/lib/printeros/klipper, sets [mcu] serial
printeros-capability-detect   → DISPLAY=? CAMERA=? (udev re-runs on hotplug)
klipper / moonraker           → start against the assembled config
caddy (ui/serve)              → serves the UI + proxies Moonraker
printeros-kiosk               → starts ONLY if DISPLAY=1 (else silently skipped)
printeros-camera              → starts ONLY if /dev/video0 exists
```

## Non-negotiable invariants

- **Graceful degradation.** A missing screen/camera never breaks printing.
- **Klipper config stays writable.** `SAVE_CONFIG` calibration persists in `saved.cfg`;
  the Nix-seeded base is never written to.
- **Nix owns versions.** Moonraker's update manager is off; updates are OTA closures.
- **Open/Closed.** New printers/devices are added files, never core edits.

## Firmware & OTA

- Firmware binaries are **CI build artifacts** attached to semantic releases
  (`.github/workflows/release.yml` + `firmware/*.config`, grep-asserted for correctness).
- OTA = switch to a newer flake ref (`printeros.ota`), atomic with rollback, UI-triggered,
  never mid-print.
