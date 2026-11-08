{
  description = "lost - nixos configuration flake for thinkpad t16 gen 1 (alder lake i7-1260p + mx550)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # antigravity CLI flake input so agy compiles directly into the system closure
    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, lanzaboote, antigravity-nix, impermanence, ... }@inputs: {
    nixosConfigurations = {
      lost = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        # THE CRITICAL INJECTION: passes `inputs` to configuration.nix & other modules
        specialArgs = { inherit inputs; };

        modules = [
          lanzaboote.nixosModules.lanzaboote
          impermanence.nixosModules.impermanence
          ./nixos/configuration.nix
        ];
      };

      # so you can run `nixos-rebuild switch --flake .` without appending #lost
      default = self.nixosConfigurations.lost;
    };
  };
}
