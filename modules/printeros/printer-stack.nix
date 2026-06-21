# The abstract printing stack: Klipper + Moonraker. Depends only on the printer
# INTERFACE, never on Q5 specifics (Dependency Inversion). The concrete printer is
# injected at boot by printer-detect, which assembles /var/lib/printeros/klipper.
#
# Status: Phase-1 scaffold. Service wiring is intended-correct but will be iterated
# to green in CI (image builds run there). Key decisions are locked:
#   * mutableConfig — Klipper's SAVE_CONFIG must be able to persist calibration.
#   * Moonraker update_manager is OFF — Nix owns versions, not Moonraker.
{ config, lib, pkgs, ... }:
let
  cfg = config.printeros.printerStack;
in
{
  options.printeros.printerStack.enable =
    lib.mkEnableOption "the Klipper + Moonraker printing stack";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.klipper pkgs.moonraker ];

    # Klipper runs against the writable config dir prepared by printer-detect, so
    # SAVE_CONFIG can write back. We manage the unit directly (rather than
    # services.klipper) precisely because the active config is chosen at runtime.
    systemd.services.klipper = {
      description = "Klipper 3D printer firmware host";
      wantedBy = [ "multi-user.target" ];
      after = [ "printeros-printer-detect.service" ];
      requires = [ "printeros-printer-detect.service" ];
      # Only run once a printer config has actually been assembled.
      unitConfig.ConditionPathExists = "/var/lib/printeros/klipper/printer.cfg";
      serviceConfig = {
        User = "printeros";
        ExecStart = "${pkgs.klipper}/bin/klippy "
          + "/var/lib/printeros/klipper/printer.cfg "
          + "-l /var/lib/printeros/klipper/klippy.log "
          + "-a /run/klipper/api.sock";
        Restart = "always";
        RuntimeDirectory = "klipper";
      };
    };

    services.moonraker = {
      enable = true;
      user = "printeros";
      address = "127.0.0.1"; # exposed only via the Caddy reverse proxy (see ui/serve.nix)
      settings = {
        authorization = {
          trusted_clients = [ "127.0.0.1" "10.0.0.0/8" "192.168.0.0/16" "FE80::/10" ];
          cors_domains = [ "*.local" ];
        };
        # Nix owns versions — keep Moonraker from trying to self-update.
        update_manager.enable_auto_refresh = false;
      };
    };
  };
}
