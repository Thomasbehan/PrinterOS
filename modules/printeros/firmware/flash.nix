# UI-gated firmware flashing. The management UI exposes a "Firmware" flow; this
# module backs it. Flow per the CLAUDE.md model:
#   1. Bootstrap (once, manual): the released Robin_nano*.bin goes on the printer's
#      SD card. This installs Klipper (+ Katapult later) — SD bootloaders are not
#      network-flashable, so this step is physical by nature.
#   2. Steady state: detect the connected board and flash over USB via Katapult.
#
# Status: scaffold. The over-USB path lands once Katapult is bootstrapped.
{ config, lib, pkgs, ... }:
let
  cfg = config.printeros.firmware;
in
{
  options.printeros.firmware = {
    enable = lib.mkEnableOption "UI-gated firmware management" // { default = true; };
    releaseRepo = lib.mkOption {
      type = lib.types.str;
      default = "Thomasbehan/PrinterOS";
      description = "GitHub repo whose releases carry the built firmware binaries.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Helper invoked by the UI/Moonraker to fetch the released bin for the active
    # printer's board and stage it for SD-card or USB flashing.
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "printeros-fetch-firmware" ''
        set -eu
        repo="${cfg.releaseRepo}"
        out="''${1:-/var/lib/printeros/firmware}"
        mkdir -p "$out"
        echo "Fetching latest firmware assets from $repo into $out ..."
        # TODO: resolve the active board from /run/printeros/caps.env and pull the
        # matching asset(s). For the Q5 these are Robin_nano.bin / Robin_nano35.bin.
        ${pkgs.curl}/bin/curl -fsSL \
          "https://api.github.com/repos/$repo/releases/latest" \
          | ${pkgs.jq}/bin/jq -r '.assets[].browser_download_url' \
          | grep -Ei 'Robin_nano' \
          | while read -r url; do ${pkgs.curl}/bin/curl -fsSL -O --output-dir "$out" "$url"; done
        echo "Done. Copy *.bin to the printer SD card, then power-cycle to flash."
      '')
    ];
  };
}
