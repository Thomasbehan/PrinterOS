# OTA updates, UI-managed. PrinterOS versions are whole NixOS closures, so an OTA
# is "switch to a newer flake ref" — atomic, with rollback for free. The UI shows
# available releases and triggers the switch; this module provides the mechanism.
{ config, lib, pkgs, ... }:
let
  cfg = config.printeros.ota;
in
{
  options.printeros.ota = {
    enable = lib.mkEnableOption "over-the-air system updates" // { default = true; };
    flakeRef = lib.mkOption {
      type = lib.types.str;
      default = "github:Thomasbehan/PrinterOS";
      description = "Flake reference updates are pulled from.";
    };
    attribute = lib.mkOption {
      type = lib.types.str;
      default = "rpi4b";
      description = "nixosConfigurations attribute to switch to (the device id).";
    };
  };

  config = lib.mkIf cfg.enable {
    # Triggered on demand by the UI (via a Moonraker/systemd hook), never on a timer
    # mid-print. A release tag can be passed as the instance name: printeros-ota@v1.2.3.
    systemd.services."printeros-ota@" = {
      description = "PrinterOS OTA update to %i";
      serviceConfig.Type = "oneshot";
      path = [ pkgs.nixos-rebuild pkgs.git pkgs.nix ];
      script = ''
        set -eu
        ref="${cfg.flakeRef}"
        tag="%i"
        [ -n "$tag" ] && [ "$tag" != "latest" ] && ref="$ref?ref=$tag"
        echo "Switching to $ref#${cfg.attribute}"
        nixos-rebuild switch --flake "$ref#${cfg.attribute}" --refresh
      '';
    };
  };
}
