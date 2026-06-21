# Flashing & first-boot testing (Raspberry Pi 4B)

This is the on-hardware bring-up loop. The image is a CI/release artifact — you never
build it locally.

## 1. Get the image

From the latest [release](https://github.com/Thomasbehan/PrinterOS/releases) download
`nixos-image-rpi4-uboot.img.zst` and `SHA256SUMS.txt`, then verify:

```sh
sha256sum -c SHA256SUMS.txt        # or on Windows: check the hash matches
```

## 2. Flash the SD card

The image is zstd-compressed. Raspberry Pi Imager / balenaEtcher don't read `.zst`
directly, so decompress first:

```sh
# Windows: winget install zstd  (or 7-Zip with the zstd plugin)
zstd -d nixos-image-rpi4-uboot.img.zst      # → nixos-image-rpi4-uboot.img
```

Flash `…​.img` with **Raspberry Pi Imager → Use custom image** to the Pi's SD card.

## 3. Boot

- Put the card in the Pi 4B, connect **Ethernet** (Wi-Fi/secrets aren't wired yet),
  plug in the **Q5 over USB**, power on.
- Find it: `ping printeros.local` (mDNS) or check your router's DHCP leases.

### Wi-Fi (optional — Ethernet is the default path)

NetworkManager is enabled, so set Wi-Fi at runtime over SSH (no rebuild):

```sh
nmcli device wifi connect "<SSID>" password "<PASSWORD>"
```

## 4. Log in (first-boot creds — change these)

```sh
ssh printeros@printeros.local      # password: printeros
```

## 5. Verify the stack came up

```sh
cat /run/printeros/caps.env                       # DEVICE / PRINTER / DISPLAY / CAMERA
systemctl status printeros-printer-detect          # should have picked flsun-q5
systemctl status klipper moonraker caddy
ls -l /var/lib/printeros/klipper/printer.cfg       # assembled config, [mcu] serial rewritten
```

Open **`http://printeros.local/`** for the dashboard, **`/fluidd`** for full controls.

## 6. First-print SAFETY (delta)

1. Before heating anything, confirm in the UI that **nozzle + bed read room
   temperature**. If a thermistor reads wrong, Klipper will already have shut down
   ("ADC out of range") — fix the config, don't force it.
2. First `G28` home: keep a hand on the power. If a tower drives *away* from its
   endstop, cut power and invert that `dir_pin` in the profile.
3. Then calibrate: `DELTA_CALIBRATE`, `PID_CALIBRATE` (hotend + bed), probe `z_offset`.
   `SAVE_CONFIG` persists these to a writable include (the Nix base stays declarative).

## 7. Known gaps to watch on first boot (report logs)

These are untested-on-hardware and the most likely first-boot issues:

- **Klipper ↔ Moonraker socket** — Moonraker expects Klipper's API socket at
  `/run/klipper/api.sock`; confirm `moonraker` connects (UI shows temps).
- **printer-detect** — confirm it matched `usb-1a86_USB_Serial-*` and wrote the serial.
- **Kiosk** — only starts if a display is detected (`DISPLAY=1`); headless is fine.

If something's off, grab logs and hand them back:

```sh
journalctl -u printeros-printer-detect -u klipper -u moonraker -u caddy --no-pager -n 200
```

## 8. Updating (OTA)

Once booted, updates are a flake switch (no reflash):

```sh
sudo nixos-rebuild switch --flake github:Thomasbehan/PrinterOS#rpi4b --refresh
```
(Or trigger it from the UI / `printeros-ota@<tag>` once that flow is wired.)
