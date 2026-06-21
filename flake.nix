{
  description = "PrinterOS — modular, declarative NixOS for 3D printers (Bambu-level, fleet-ready)";

  inputs = {
    # Purpose-built Raspberry Pi support: prebuilt kernel + firmware via the cachix
    # cache below (no local kernel compile, no interactive oldconfig). Pins nixpkgs
    # to nixos-25.11; we follow it so cache hits line up.
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
  };

  # Lets CI (`nix build --accept-flake-config`) and the Pi itself pull the prebuilt
  # Raspberry Pi closures instead of building them.
  nixConfig = {
    extra-substituters = [ "https://nixos-raspberrypi.cachix.org" ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  outputs = { self, nixpkgs, nixos-raspberrypi, ... }@inputs:
    let
      # Every printer profile, bundled into EVERY device image; the active one is
      # selected at boot by detection. Devices and printers stay orthogonal.
      printerProfiles = [
        ./printers/flsun-q5/profile.nix
      ];

      # Compose a DEVICE (build-time hardware) with the FULL printer set + the
      # printeros application layer. Uses the rpi flake's nixosSystem so the device
      # pulls prebuilt kernel/firmware from its cache.
      mkSystem = { device }:
        nixos-raspberrypi.lib.nixosSystem {
          specialArgs = inputs // { inherit inputs; };
          modules = [
            nixos-raspberrypi.nixosModules.sd-image
            nixos-raspberrypi.nixosModules.trusted-nix-caches
            ./modules/printeros
            ./devices/_common.nix
            ./printers/_common.nix
            device
          ] ++ printerProfiles;
        };
    in
    {
      nixosConfigurations.rpi4b = mkSystem { device = ./devices/rpi4b; };

      # Flashable SD image. Built by CI on an aarch64 runner:
      #   nix build .#sd-image --accept-flake-config
      packages.aarch64-linux.sd-image =
        self.nixosConfigurations.rpi4b.config.system.build.sdImage;
      packages.aarch64-linux.default = self.packages.aarch64-linux.sd-image;

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
      formatter.aarch64-linux = nixpkgs.legacyPackages.aarch64-linux.nixpkgs-fmt;
    };
}
