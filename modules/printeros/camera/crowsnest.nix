# Camera streaming for live monitoring + timelapse. Starts only when a /dev/video*
# device exists (udev in capability-detect starts/stops printeros-camera on hotplug).
{ config, lib, pkgs, ... }:
{
  config = lib.mkIf config.printeros.ui.enable {
    systemd.services.printeros-camera = {
      description = "PrinterOS camera (MJPEG/WebRTC streamer)";
      # Started by udev when a camera appears; not wanted-by a target so absence is silent.
      unitConfig.ConditionPathExists = "/dev/video0";
      serviceConfig = {
        User = "printeros";
        # ustreamer is light enough for the Pi 4; Moonraker exposes it to the UI.
        ExecStart = "${pkgs.ustreamer}/bin/ustreamer "
          + "--device=/dev/video0 --resolution=1280x720 --format=MJPEG "
          + "--host=127.0.0.1 --port=8080";
        Restart = "always";
      };
    };
  };
}
