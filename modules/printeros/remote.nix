# Friendly local access + optional secure remote. mDNS gives http://<host>.local
# out of the box; Tailscale (opt-in) gives encrypted remote access without port
# forwarding — closer to the "monitor from anywhere" Bambu feel.
{ config, lib, ... }:
let
  cfg = config.printeros.remote;
in
{
  options.printeros.remote = {
    mdns = lib.mkEnableOption "mDNS / .local discovery" // { default = true; };
    tailscale = lib.mkEnableOption "Tailscale secure remote access";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.mdns {
      services.avahi = {
        enable = true;
        publish.enable = true;
        publish.addresses = true;
        nssmdns4 = true;
      };
    })
    (lib.mkIf cfg.tailscale {
      services.tailscale.enable = true;
    })
  ];
}
