# DRY base shared by EVERY device (any SBC). Hardware-family specifics live in the
# per-device module; this holds the things every PrinterOS box wants.
{ lib, ... }:
{
  # Reproducible, flake-driven. No channels.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "root" "printeros" ];

  networking.networkmanager.enable = lib.mkDefault true;

  # The operator account. CHANGE THIS — initialPassword is for first-boot testing
  # only; real auth/keys come via sops-nix (secrets/). Lets you SSH in over Ethernet
  # on first boot (user: printeros / pass: printeros) to bring the Pi up.
  users.users.printeros = {
    isNormalUser = true;
    extraGroups = [ "wheel" "dialout" "video" ];
    description = "PrinterOS operator";
    initialPassword = lib.mkDefault "printeros";
  };
  security.sudo.wheelNeedsPassword = lib.mkDefault false;

  services.openssh.enable = true;
  time.timeZone = lib.mkDefault "Europe/London";
  system.stateVersion = lib.mkDefault "25.05";
}
