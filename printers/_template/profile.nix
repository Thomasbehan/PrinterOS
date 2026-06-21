# TEMPLATE — copy this directory to printers/<your-printer>/ and fill in.
# Register it in flake.nix `printerProfiles`. Touch nothing else (Open/Closed).
{ ... }:
{
  printeros.printers.CHANGEME = {
    enable = true;
    displayName = "Change Me";
    kinematics = "cartesian";              # delta | cartesian | corexy
    mcuMatch = "usb-Klipper_*";            # glob vs /dev/serial/by-id/*
    baseConfig = ./printer.cfg;            # create alongside this file
    # macros = ./macros.cfg;               # optional
    # firmware = { board = "..."; configFile = ../../firmware/<board>.config; binNames = [ ]; };
  };
}
