# On-device touchscreen kiosk: the SAME web UI, fullscreen in a Wayland cage +
# Chromium. Replaces KlipperScreen. Starts ONLY when a display is detected, so a
# headless box is unaffected (graceful degradation).
{ config, lib, pkgs, ... }:
{
  config = lib.mkIf config.printeros.ui.enable {
    systemd.services.printeros-kiosk = {
      description = "PrinterOS touchscreen kiosk";
      after = [ "printeros-capability-detect.service" "caddy.service" ];
      # Gate on a detected display; udev restarts capability-detect on hotplug.
      unitConfig.ConditionPathExists = "/run/printeros/caps.env";
      serviceConfig = {
        User = "printeros";
        # Only proceed if capability-detect found a display.
        ExecCondition = "${pkgs.bash}/bin/bash -c 'grep -qx DISPLAY=1 /run/printeros/caps.env'";
        ExecStart = "${pkgs.cage}/bin/cage -s -- ${pkgs.chromium}/bin/chromium "
          + "--kiosk --noerrdialogs --disable-infobars --app=http://localhost";
        Restart = "always";
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
