# Raspberry Pi 4 Model B — build-time hardware support. One image per device family;
# this module owns ONLY hardware concerns, never anything printer-specific.
{ inputs, lib, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
    ./config-txt.nix
  ];

  # Pi 4 boots via the firmware/generic extlinux path provided by the sd-image module.
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  # Quiet, fast boots; the dwc2 USB stack the Pi 4 uses for device serial.
  boot.kernelParams = [ "console=tty1" ];

  # Runtime device identity for printeros device-detect.
  printeros.device = {
    id = "rpi4b";
    model = "Raspberry Pi 4 Model B";
  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
