# Raspberry Pi 4 Model B — build-time hardware. Hardware support (prebuilt kernel,
# firmware, bootloader, config.txt, VideoCore KMS for the kiosk display) all comes
# from nixos-raspberrypi's modules, so nothing here compiles a kernel.
{ nixos-raspberrypi, ... }:
{
  imports = [
    nixos-raspberrypi.nixosModules.raspberry-pi-4.base
    nixos-raspberrypi.nixosModules.raspberry-pi-4.display-vc4
    ./config-txt.nix
  ];

  # Runtime device identity for printeros device-detect.
  printeros.device = {
    id = "rpi4b";
    model = "Raspberry Pi 4 Model B";
  };
}
