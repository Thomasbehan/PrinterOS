# The printeros application layer. Defines the `printeros.*` options namespace and
# imports every sub-module. The PRINTER INTERFACE (the Liskov contract every printer
# must satisfy) lives here as a submodule type — concrete printers inject themselves
# into `printeros.printers.<name>` and are interchangeable by construction.
{ lib, ... }:
let
  printerType = lib.types.submodule ({ name, ... }: {
    options = {
      enable = lib.mkEnableOption "this printer profile";

      displayName = lib.mkOption {
        type = lib.types.str;
        default = name;
        description = "Human-facing name shown in the UI.";
      };

      kinematics = lib.mkOption {
        type = lib.types.enum [ "delta" "cartesian" "corexy" ];
        description = "Motion system. Drives UI presentation (e.g. delta → circular view).";
      };

      mcuMatch = lib.mkOption {
        type = lib.types.str;
        example = "usb-1a86_USB_Serial-*";
        description = ''
          Glob matched against /dev/serial/by-id/* to auto-detect this printer at boot.
          The printer-detect service uses this to choose the active profile.
        '';
      };

      baseConfig = lib.mkOption {
        type = lib.types.path;
        description = ''
          Seed Klipper printer.cfg (read-only base). Live calibration (SAVE_CONFIG)
          is written to a separate writable include, so this stays declarative.
        '';
      };

      macros = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Optional macros.cfg included after the base config.";
      };

      firmware = lib.mkOption {
        default = null;
        description = "Firmware build/flash metadata for the UI-gated flasher (null if N/A).";
        type = lib.types.nullOr (lib.types.submodule {
          options = {
            board = lib.mkOption {
              type = lib.types.str;
              example = "mks-robin-nano-v1.2";
              description = "Control board identifier.";
            };
            configFile = lib.mkOption {
              type = lib.types.path;
              description = "Klipper Kconfig fragment used to build this board's firmware.";
            };
            binNames = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Filenames the patched binary is published as for SD-card flashing.";
            };
          };
        });
      };
    };
  });
in
{
  imports = [
    ./printer-stack.nix
    ./detection/device-detect.nix
    ./detection/printer-detect.nix
    ./detection/capability-detect.nix
    ./firmware/flash.nix
    ./ui/serve.nix
    ./display/kiosk.nix
    ./camera/crowsnest.nix
    ./remote.nix
    ./ota.nix
  ];

  options.printeros.printers = lib.mkOption {
    type = lib.types.attrsOf printerType;
    default = { };
    description = ''
      Registry of every printer profile in this image. All are installed; the active
      one is chosen at boot by printer-detect. This is the Open/Closed seam — new
      printers register here without touching any core module.
    '';
  };
}
