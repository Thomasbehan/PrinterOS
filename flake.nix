{
  description = "PrinterOS — modular, declarative NixOS for 3D printers (Bambu-level, fleet-ready)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { self, nixpkgs, nixos-hardware, ... }@inputs:
    let
      inherit (nixpkgs) lib;

      # Every printer profile bundled into EVERY device image. The active one is
      # selected at boot by detection — printers and devices are orthogonal axes,
      # never coupled here. Add a printer = add a line.
      printerProfiles = [
        ./printers/flsun-q5/profile.nix
      ];

      # mkSystem composes a DEVICE (build-time hardware) with the FULL printer set
      # (runtime-selected) plus the printeros application layer. Building an image
      # never asks which printer — that is the whole point.
      mkSystem = { device, system ? "aarch64-linux" }:
        lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./modules/printeros        # the printeros.* application (imports all sub-modules)
            ./devices/_common.nix
            ./printers/_common.nix
            device
          ] ++ printerProfiles;
        };
    in
    {
      nixosConfigurations.rpi4b = mkSystem { device = ./devices/rpi4b; };

      # Flashable SD image. Built by CI on an aarch64 runner: `nix build .#sd-image`.
      packages.aarch64-linux.sd-image =
        self.nixosConfigurations.rpi4b.config.system.build.sdImage;
      packages.aarch64-linux.default = self.packages.aarch64-linux.sd-image;

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
      formatter.aarch64-linux = nixpkgs.legacyPackages.aarch64-linux.nixpkgs-fmt;
    };
}
