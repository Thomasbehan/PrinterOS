# Device identity + runtime device detection. Each device module declares its
# identity statically; this service confirms it at boot from /proc/device-tree/model
# and records it for everything downstream. "Build the union, run the subset."
{ config, lib, pkgs, ... }:
let
  cfg = config.printeros.device;
in
{
  options.printeros.device = {
    id = lib.mkOption {
      type = lib.types.str;
      example = "rpi4b";
      description = "Stable device identifier set by the device module.";
    };
    model = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Expected /proc/device-tree/model string (for a runtime sanity check).";
    };
  };

  config = {
    systemd.tmpfiles.rules = [ "d /run/printeros 0755 root root -" ];

    systemd.services.printeros-device-detect = {
      description = "PrinterOS: detect device model and seed capability env";
      wantedBy = [ "multi-user.target" ];
      before = [ "printeros-printer-detect.service" ];
      serviceConfig.Type = "oneshot";
      serviceConfig.RemainAfterExit = true;
      script = ''
        model="$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo unknown)"
        echo "DEVICE=${cfg.id}" > /run/printeros/caps.env
        echo "DEVICE_MODEL=$model" >> /run/printeros/caps.env
        ${pkgs.util-linux}/bin/logger -t printeros "device: ${cfg.id} ($model)"
      '';
    };
  };
}
