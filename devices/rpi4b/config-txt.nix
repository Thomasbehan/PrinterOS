# Pi firmware config.txt knobs. Kept separate so display/UART tweaks are obvious and
# reviewable — exactly the settings that, done wrong, break a screen.
{ ... }:
{
  # Enable the DSI/HDMI KMS stack so an attached touchscreen lights up for the kiosk.
  hardware.raspberry-pi."4".fkms-3d.enable = true;

  # USB serial to the printer board works out of the box on the Pi 4's USB-A ports;
  # no GPIO UART needed for the Q5 (it uses its onboard CH340 over USB).
}
