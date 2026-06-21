# PrinterOS

A modular, declarative **NixOS** that turns a single-board computer into a
Bambu-Lab-class 3D-printing appliance — with its own beautifully minimal management
UI. First target: **Raspberry Pi 4B** + **FLSUN Q5** (delta). Built to scale to many
boards and many printers.

> **Standards & principles live in [`CLAUDE.md`](./CLAUDE.md).** Read it before contributing.

## Core idea

**Devices and printers are orthogonal.** Every device image bundles *all* printer
profiles and picks the connected one at boot. Adding a printer or a device is a
drop-in — neither touches the other.

```
devices/   the SBC hardware (build-time)      printers/   printer profiles (runtime-selected)
  rpi4b/                                         flsun-q5/
modules/printeros/   the application: stack, detection, UI, firmware, OTA
ui/        the SvelteKit management UI (calm, minimal, light/dark)
firmware/  Klipper Kconfig fragments per board (built by CI)
```

## CI/CD

Conventional-commit messages on `main` drive **semantic versioning**
(`feat`→minor, `fix`→patch, `feat!`→major). Each release attaches build artifacts:
the **FLSUN Q5 firmware** (`Robin_nano.bin` / `Robin_nano35.bin`) today, NixOS SD
images/closures as those jobs come online. Devices pull releases **over the air**
(`printeros.ota`), managed from the UI.

## FLSUN Q5 firmware (one-time bootstrap)

The Q5's MKS Robin Nano v1.2 is SD-flashed, so the first Klipper flash is physical:

1. Grab `Robin_nano.bin` **and** `Robin_nano35.bin` from the latest
   [release](https://github.com/Thomasbehan/PrinterOS/releases) (CI builds them).
2. Copy **both** to the printer's SD card (the bootloader uses whichever name it wants).
3. Power-cycle the printer to flash. **Supervise:** confirm thermistors read room
   temperature before any heating; keep a hand on the power during the first home.

After bootstrap, the board self-identifies and future flashes go over USB from the UI.

## Build (on a Nix host / CI)

```sh
nix build .#images.rpi4b      # flashable SD image
nix flake check               # evaluate + checks
nix fmt                       # format
```

## Status

Phase 1 — foundation + firmware/release pipeline. The Nix image build and the UI app
are scaffolded and being iterated to green in CI. See `CLAUDE.md` §10 for the roadmap.
