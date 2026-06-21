# Peripheral capability detection. Records whether a display and/or camera are
# present so optional services start ONLY when their hardware exists. Graceful
# degradation is a hard requirement: a missing screen never breaks core printing.
{ pkgs, ... }:
{
  # Re-detect on hotplug so plugging a screen/camera in lights up the right service.
  services.udev.extraRules = ''
    SUBSYSTEM=="drm", ACTION=="change", RUN+="${pkgs.systemd}/bin/systemctl restart printeros-capability-detect.service"
    SUBSYSTEM=="video4linux", ACTION=="add", RUN+="${pkgs.systemd}/bin/systemctl start printeros-camera.service"
    SUBSYSTEM=="video4linux", ACTION=="remove", RUN+="${pkgs.systemd}/bin/systemctl stop printeros-camera.service"
  '';

  systemd.services.printeros-capability-detect = {
    description = "PrinterOS: detect display and camera";
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    serviceConfig.RemainAfterExit = true;
    script = ''
      display=0; camera=0
      # Any connected DRM output (DSI panel or HDMI marked "connected").
      for s in /sys/class/drm/*/status; do
        [ -e "$s" ] && grep -qx connected "$s" && display=1
      done
      [ -e /dev/video0 ] && camera=1
      echo "DISPLAY=$display" >> /run/printeros/caps.env
      echo "CAMERA=$camera" >> /run/printeros/caps.env
      ${pkgs.util-linux}/bin/logger -t printeros "capabilities: display=$display camera=$camera"
    '';
  };
}
