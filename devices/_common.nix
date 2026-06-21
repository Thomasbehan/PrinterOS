# DRY base shared by EVERY device (any SBC). Hardware-family specifics live in the
# per-device module; this holds the things every PrinterOS box wants.
{ lib, ... }:
{
  # Reproducible, flake-driven. No channels.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "root" "printeros" ];

  networking.networkmanager.enable = lib.mkDefault true;

  # The operator account. Real auth/keys come via sops-nix (secrets/), never here.
  users.users.printeros = {
    isNormalUser = true;
    extraGroups = [ "wheel" "dialout" "video" ];
    description = "PrinterOS operator";
  };

  services.openssh.enable = true;
  time.timeZone = lib.mkDefault "Europe/London";
  system.stateVersion = lib.mkDefault "25.05";
}
