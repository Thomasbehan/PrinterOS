# Serves the PrinterOS management UI and reverse-proxies Moonraker, so the browser
# and the on-device kiosk hit one origin. Fluidd is kept at /fluidd as a power-user
# fallback (Mainsail/KlipperScreen are not used).
#
# v1 ships the UI as a reproducible static bundle (ui/static) built with a plain
# runCommand — no npm-in-Nix hash dance. The SvelteKit migration (buildNpmPackage)
# is a tracked follow-up; the design tokens and Moonraker client carry straight over.
{ config, lib, pkgs, ... }:
let
  cfg = config.printeros.ui;
  defaultUi = pkgs.runCommand "printeros-ui" { } ''
    mkdir -p $out
    cp -r ${../../../ui/static}/. $out/
  '';
in
{
  options.printeros.ui = {
    enable = lib.mkEnableOption "the PrinterOS web UI";
    package = lib.mkOption {
      type = lib.types.package;
      default = defaultUi;
      defaultText = lib.literalExpression "the static ui/ bundle";
      description = "Built UI served at the root. Swap for the SvelteKit package later.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = true;
      virtualHosts.":80".extraConfig = ''
        encode zstd gzip

        # Live state + actions → Moonraker.
        handle_path /api/* {
          reverse_proxy 127.0.0.1:7125
        }
        @ws path /websocket
        handle @ws {
          reverse_proxy 127.0.0.1:7125
        }

        # Power-user fallback (full Moonraker UI).
        handle_path /fluidd/* {
          root * ${pkgs.fluidd}
          try_files {path} /index.html
          file_server
        }

        # The PrinterOS UI (default).
        handle {
          root * ${cfg.package}
          try_files {path} /index.html
          file_server
        }
      '';
    };
  };
}
