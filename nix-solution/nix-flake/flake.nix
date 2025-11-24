# nix-solution/flake.nix
{
  description = "Declarative PaaS Configuration";

  # Define dependencies (inputs)
  inputs = {
    # Nixpkgs (stable or unstable)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05"; # Match stateVersion

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05"; # Match nixpkgs
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets (Optional but recommended)
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # WSL Support
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Define what your flake provides (outputs)
  outputs = { self, nixpkgs, home-manager, sops-nix, nixos-wsl, ... }@inputs:
  let
    # Define supported systems
    supportedSystems = [ "x86_64-linux" "aarch64-linux" ];

    # Helper function to generate NixOS configurations for each system
    forAllSystems = function: nixpkgs.lib.genAttrs supportedSystems (system: function system);

    # Shared modules applied to all hosts
    commonModules = [
      # Base NixOS module with common system settings
      ./modules/nixos/base.nix
    ];

    # Home Manager system defaults (used for WSL userland)
    hmSystem = "x86_64-linux";
    hmPkgs = nixpkgs.legacyPackages.${hmSystem};

    # Build NixOS system configurations
    nixosSystem = { system, hostname, username ? "nixuser", extraModules ? [], ... }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs hostname username; }; # Pass inputs and custom args down
        modules = commonModules ++ [
          # === Home Manager Integration ===
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # Specify the user configuration file
            home-manager.users.${username} = import ./hosts/${hostname}/home.nix;

            # Pass specialArgs to Home Manager modules too
            home-manager.extraSpecialArgs = { inherit inputs hostname username; };
          }

          # === Secrets Integration (Optional) ===
          sops-nix.nixosModules.sops
          ./secrets # Import secrets configuration

          # === Host Specific Configuration ===
          ./hosts/${hostname}/default.nix

        ] ++ extraModules;
      };

    # Helper: compose a host from its ./hosts/<name>/default.nix
    mkHost = hostPath: system:
      let
        pathStr = toString hostPath;
        parts = nixpkgs.lib.splitString "/" pathStr;
        hostname = builtins.elemAt parts ((builtins.length parts) - 2);
        varsPath = builtins.dirOf hostPath + "/variables.nix";
        vars = if builtins.pathExists varsPath then import varsPath else {};

        # Default username logic
        defaultUsername = if (hostname == "wsl" || hostname == "wsl-minimal") then "wsluser" else "nixuser";
        username = vars.username or defaultUsername;
      in
      nixosSystem {
        inherit system hostname username;
      };

  in
  {
    # === NixOS Configurations ===
    nixosConfigurations = {
      # Your full WSL instance
      wsl = mkHost ./hosts/wsl/default.nix "x86_64-linux";

      # Your NEW minimal WSL instance
      wsl-minimal = mkHost ./hosts/wsl-minimal/default.nix "x86_64-linux";

      # test = mkHost ./hosts/test/default.nix "x86_64-linux";
    };

    # === Dev Shells Output ===
#    devShells = forAllSystems (system:
#      let pkgs = nixpkgs.legacyPackages.${system};
#      in {
#        default = pkgs.mkShell {
#          packages = with pkgs; [
#            python311
#            python311Packages.pip
#            terraform
#            ansible
#            ansible-lint
#          ];
#        };
#      });
  };
}
