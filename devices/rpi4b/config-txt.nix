# Raspberry Pi firmware config.txt is managed by nixos-raspberrypi (its bootloader
# module writes it; display-vc4 enables the KMS driver the kiosk needs). Any extra
# config.txt entries for this device would be added here via the rpi flake's options.
{ ... }:
{
}
