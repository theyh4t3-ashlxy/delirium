{
  description = "lost - nixos configuration flake for thinkpad t16 gen 1 (alder lake i7-1260p + mx550)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, lanzaboote, ... }@inputs: {
    nixosConfigurations = {
      lost = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          lanzaboote.nixosModules.lanzaboote
          ./nixos/configuration.nix
        ];
      };
      default = self.nixosConfigurations.lost;
    };
  };
}
