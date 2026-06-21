# PrinterOS

A modular, declarative **NixOS** operating system that turns a single-board computer into a
Bambu-Lab-class 3D-printing appliance. First target: **Raspberry Pi 4B** driving an
**FLSUN Q5** (delta) printer. Designed from day one to grow into a fleet of many boards
and many printers.

> This file is the contract for anyone (human or agent) building in this repo. Read it
> fully before writing code. When a change contradicts something here, update this file in
> the same commit — the doc and the code never drift.

---

## 1. Product goals (the "why")

1. **Bambu-level experience** — fast, quiet, high-quality prints (Klipper input shaping +
   pressure advance), live camera + timelapse, remote monitoring, frictionless control.
2. **Our own management interface** — a bespoke, *beautifully minimal* web UI (calm
   Scandinavian aesthetic, light + dark). It is the primary UI in the browser **and** the
   on-device touchscreen (kiosk). It replaces KlipperScreen.
3. **Truly modular** — devices and printers are independent axes. Any printer runs on any
   device. Adding either is a drop-in, never a core edit.
4. **Self-configuring** — the OS ships *everything* and decides what to run at boot by
   detecting the connected printer and attached peripherals. No screen? Everything else
   still works.

---

## 2. Architecture principles (SOLID + DRY, translated to Nix)

Nix is functional, not OOP — these principles are honored as Nix idioms, not classes.

| Principle | How it must show up in this repo |
|---|---|
| **Single Responsibility** | One `.nix` module per concern. No god-modules. A file does one thing and names itself after it. |
| **Open/Closed** | New printers/devices are added by **adding a file** under `printers/` or `devices/`. Core modules are never edited to onboard hardware. |
| **Liskov** | Every printer satisfies the `mkPrinter` interface; every device satisfies `mkDevice`. Same option shape → fully interchangeable. |
| **Interface Segregation** | Capabilities (`display`, `camera`, `probe`, `firmware`) are small, focused modules. A consumer imports only what it needs. |
| **Dependency Inversion** | High-level modules (`printer-stack`, `ui`) depend on the **option interfaces**, never on Q5/Pi specifics. Concretes are injected via config. |
| **DRY** | Shared defaults live in `_common.nix`. A printer/device file contains **only its deltas** from common. |

**The golden rule:** the two axes — **device** (the SBC hardware) and **printer** (the
machine) — are orthogonal and never coupled in source. They are combined at *runtime* by
detection.

---

## 3. Repository layout

```
flake.nix                      # outputs: nixosConfigurations.<device> = device + ALL printers + stack
flake.lock
CLAUDE.md                      # this file
docs/                          # ARCHITECTURE.md, decisions, runbooks

devices/                       # build-time hardware (the SBC). One image per device family.
  _common.nix                  # DRY base shared by every device
  rpi4b/{default.nix, config-txt.nix}
  _template/                   # copy → new device

printers/                      # pure runtime profiles. Bundled into every image.
  _common.nix                  # DRY base shared by every printer
  flsun-q5/{profile.nix, printer.cfg, macros.cfg}
  _template/                   # copy → new printer

modules/printeros/             # the application: everything that makes it "PrinterOS"
  default.nix                  # the `printeros.*` options namespace (umbrella)
  printer-stack.nix            # Klipper + Moonraker + web (the ABSTRACT stack)
  detection/
    device-detect.nix          # /proc/device-tree/model → device quirks at boot
    printer-detect.nix         # /dev/serial/by-id → active printer (runtime registry)
    capability-detect.nix      # display / camera present?
  firmware/flash.nix           # UI-gated firmware build + flash service (see §7)
  display/kiosk.nix            # Chromium+cage kiosk → loads OUR ui (replaces KlipperScreen)
  camera/crowsnest.nix         # gated on /dev/video*
  ui/serve.nix                 # Caddy serves the built UI + reverse-proxies Moonraker
  remote.nix                   # mDNS (avahi) + Tailscale/Obico

ui/                            # the SvelteKit app — "the OS of dreams to use"
  src/  static/

lib/
  mkDevice.nix                 # device interface (Liskov contract)
  mkPrinter.nix                # printer interface (Liskov contract)

secrets/                       # sops-nix encrypted (wifi psk, tokens). Never plaintext secrets.
```

**Naming:** every option this project defines lives under the `printeros.*` namespace
(e.g. `printeros.printers.<name>`, `printeros.ui.enable`). Never pollute the top level.

---

## 4. Runtime detection model (build static → run adaptive)

NixOS is static at build time. We bridge to runtime with a detection layer; **build the
union, run the subset.**

- **Everything is in the image.** All printer configs, the UI, camera + display stacks are
  always *present*. Detection only gates which **services start**.
- `printeros-detect.service` runs early at boot, probes hardware, writes
  `/run/printeros/caps.env` (e.g. `DEVICE=rpi4b PRINTER=flsun-q5 DISPLAY=1 CAMERA=1`).
- Optional services gate on it via systemd `ConditionPathExists=` / `ExecCondition=`, and
  **udev rules** start/stop camera + display services on hotplug.
- **Graceful degradation is a hard requirement.** No display → kiosk simply does not start;
  everything else is unaffected. No camera → no streamer; UI hides the tile. Never let a
  missing peripheral break core printing.

Two detectors:
1. **Printer** — scan `/dev/serial/by-id/*`. Each printer profile registers a match pattern
   (a flashed Klipper MCU enumerates as `usb-Klipper_<mcu>_<serial>`). Match → select that
   profile's `printer.cfg` and start the matching Klipper instance. Multiple boards → multiple
   instances.
2. **Capability** — display via `/sys/class/drm/*` (DSI panel / HDMI `status=connected` /
   SPI touch), camera via `/dev/video*`.

---

## 5. Klipper / Moonraker rules (NixOS gotchas — do not relearn these the hard way)

- **Klipper config must stay writable.** Calibration (`SAVE_CONFIG`: delta endstops, PID,
  resonance) *must* persist. A read-only store path breaks the printer. Seed a base
  `printer.cfg` from Nix into a writable location and let Klipper autosave to a writable
  include. Use the klipper module's `mutableConfig` pattern. **Never** point Klipper at a
  `/nix/store` path it must write to.
- **Moonraker's `update_manager` is OFF (or inform-only).** Versions are owned by
  `nixos-rebuild`/flake updates. Leaving Moonraker's updater on fights Nix and corrupts state.
- **Updates = `git pull && nixos-rebuild switch`** (later `deploy-rs`/colmena for the fleet).
- Delta specifics: the Q5's stock effector probe is kept (it's better than a BLTouch on a
  delta). `DELTA_CALIBRATE` + mesh live in macros.

---

## 6. The management UI (`ui/`)

- **Stack:** SvelteKit (static adapter), served by Caddy. Tiny, fast on a Pi. Talks to
  Moonraker via **JSON-RPC over WebSocket** (live state) + REST (actions). Moonraker does the
  work; the UI is pure presentation.
- **One app, two targets:** the same build serves the browser *and* runs fullscreen in a
  `cage` (Wayland) + Chromium kiosk on the touchscreen. DRY — one codebase, one design.
- **Fluidd** is kept hidden at `/fluidd` as a power-user fallback. Mainsail/KlipperScreen are
  **not** used.
- **Design language — calm minimal / Scandinavian. Non-negotiable invariants:**
  - **Light + dark**, driven by a single semantic token set (`--ground`, `--surface`,
    `--text`, `--accent`, `--heat`…). Both themes derive from one source of truth. Follows
    the OS by default with a persisted manual toggle.
  - The **delta circle** is the signature motif (round build plate, three towers at 120°) —
    not a rectangular/linear print view. Spend boldness here; keep everything else quiet.
  - Soft neutral grounds, **one** cool accent; warm amber reserved *only* for thermal data
    (color carries meaning). Generous whitespace, rounded cards, large calm type.
  - **Monospace for live numerics** (temps, %, layers); light-weight system sans for display.
  - Respect `prefers-reduced-motion`; one orchestrated motion (the ring filling), not scattered effects.
- **Copy:** active voice, sentence case, name things by what the user controls. A button's
  verb is consistent through its flow ("Pause" → "Paused"). Errors say what broke and how to fix it.

---

## 7. Firmware flashing (UI-gated, over the network)

Flashing is a first-class feature exposed in the management UI, **not** a manual SSH chore.

- **Bootstrap (once, manual):** the MKS Robin Nano on the Q5 is an SD-card-flashed board, so
  the *first* Klipper flash is done by copying the built `.bin` to the printer's SD card.
  After that, install a USB bootloader (**Katapult/CanBoot**) so all future flashes go over
  USB.
- **Steady state (UI-gated, networked):** the UI's "Firmware" flow detects the connected
  board, builds the correct Klipper binary for it, and flashes over USB — no SD card, no SSH.
- **Board auto-detection:** the MCU family is identifiable
  - after flashing: from `/dev/serial/by-id` (`...stm32f103xe...` vs `...stm32f407xx...`),
  - in DFU/bootloader mode: from the USB DFU device descriptor / chip ID.
  The detected board selects the right Klipper build config + pin map automatically.

> **Q5 board assumption:** the FLSUN Q5 ships (almost always) with an **MKS Robin Nano v1.2
> (STM32F103VET6)**; some late batches use **v3 (STM32F407)**. Confirm per unit via silkscreen
> or `lsusb`/`/dev/serial/by-id`. Default the build to v1.2 until detection says otherwise.

### Flashing safety (why a wrong guess is recoverable, not catastrophic)

- **SD-card flashing never touches the bootloader** (it's in a protected region and is what
  reads the card). A wrong binary is either rejected or fails to run — **reflash the correct
  `.bin` and power-cycle to recover.** True bricking needs SWD/DFU bootloader erase, which we
  never do.
- **Confirm the board rev before the first flash** (silkscreen is definitive). This removes the
  guess entirely; do not rely on defaulting if the unit can be opened.
- **Klipper fails safe, not silent.** The MCU binary only carries chip + clock + comms; the pin
  map / heaters / thermistors live in host `printer.cfg`. A wrong clock → Klipper measures real
  MCU frequency and **refuses to start**. A wrong thermistor pin → **"ADC out of range" shutdown
  on connect**; mandatory `min_temp`/`max_temp` + `verify_heater` mean it will not heat a sensor
  it can't read.
- **First power-on is always supervised:** confirm nozzle + bed thermistors read ambient
  **before** any home/heat. No filament loaded. Stop and fix config if anything reads wrong.

---

## 8. Coding standards

- **Flakes only.** All inputs pinned in `flake.lock`. No channels, no impure references.
- **Formatting:** `nixpkgs-fmt` (or `alejandra`, pick one and enforce). Code must be formatted
  before commit.
- **`flake check` must pass.** Add `checks` for `nix flake check`, `nixos-rebuild build`
  (`.#rpi4b`), `nix fmt --check`, and `ui` build/lint.
- **Options over hardcoding.** Anything a device/printer might vary is a typed option with a
  `description` and sensible `default`. Use submodule types for the printer/device interfaces.
- **No secrets in the store.** Wi-Fi PSK, tokens, etc. go through **sops-nix**. CI/agents
  never commit plaintext secrets.
- **Small, focused modules.** If a file does two things, split it.
- **Comments match the surrounding code's density.** Explain *why*, not *what*.

---

## 9. Workflow & verification

- **Branch, don't commit to default.** Commit/push only when the user asks.
- **Commit messages** end with the project's co-author trailer.
- **Definition of done for any change:**
  1. `nix fmt` clean, `nix flake check` green.
  2. `nixos-rebuild build .#rpi4b` succeeds.
  3. If it touches the UI: `ui` builds and the change was viewed rendered (light **and** dark).
  4. If it touches printing/detection: state in the PR exactly what was tested on hardware vs.
     only built. Never claim hardware-verified if it was only built.
- **Report faithfully.** If something is untested or a step was skipped, say so.

---

## 10. Roadmap (current phase tracked in docs/ARCHITECTURE.md)

0. **Bootable base** — flake skeleton, NixOS on Pi4 (headless, SSH, Wi-Fi).
1. **Core printing** — `printer-stack` + Q5 profile, flash Klipper, delta calibration, web control.
2. **Detection + peripherals** — capability detection, kiosk UI on touch, camera, graceful degradation.
3. **Multi-printer ready** — printer auto-detection registry + `_template/`.
4. **Bambu polish** — timelapse, Spoolman, Obico/remote, tuning macros, firmware-flash UI.
5. **Fleet** — `deploy-rs`/colmena for many boards.
