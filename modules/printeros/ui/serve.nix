# Serves the PrinterOS management UI and reverse-proxies Moonraker, so the browser
# and the on-device kiosk hit one origin. Fluidd is kept hidden at /fluidd as a
# power-user fallback (Mainsail/KlipperScreen are not used).
{ config, lib, pkgs, ... }:
let
  cfg = config.printeros.ui;
in
{
  options.printeros.ui = {
    enable = lib.mkEnableOption "the PrinterOS web UI";
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Built SvelteKit static app (ui/). Null until the UI package lands.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = true;
      virtualHosts.":80".extraConfig = ''
        # The UI (static). Falls back to a holding page until the package is wired.
        ${lib.optionalString (cfg.package != null) "root * ${cfg.package}"}
        ${lib.optionalString (cfg.package != null) "file_server"}

        # Live state + actions.
        handle_path /api/* {
          reverse_proxy 127.0.0.1:7125
        }
        handle /websocket {
          reverse_proxy 127.0.0.1:7125
        }

        # Power-user fallback.
        handle_path /fluidd/* {
          root * ${pkgs.fluidd}
          file_server
        }
      '';
    };
  };
}
