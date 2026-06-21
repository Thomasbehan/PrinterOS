# FLSUN Q5 — concrete printer profile. Self-registers into the printer registry.
# This is the ONLY file (plus printer.cfg / macros.cfg) needed to support the Q5;
# no core module is edited. Copy printers/_template to add another printer.
{ ... }:
{
  printeros.printers.flsun-q5 = {
    enable = true;
    displayName = "FLSUN Q5";
    kinematics = "delta";

    # Onboard CH340 on the Robin Nano v1.2 — stable id whether running stock
    # firmware or Klipper, since Klipper lives on the STM32 behind the CH340.
    mcuMatch = "usb-1a86_USB_Serial-*";

    baseConfig = ./printer.cfg;
    macros = ./macros.cfg;

    firmware = {
      board = "mks-robin-nano-v1.2";
      configFile = ../../firmware/flsun-q5-robin-nano-v12.config;
      binNames = [ "Robin_nano.bin" "Robin_nano35.bin" ];
    };
  };
}
