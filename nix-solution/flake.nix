# nix-solution/flake.nix
{
  description = "Declarative PaaS Configuration";

  # Define dependencies (inputs)
  inputs = {
    # Nixpkgs (stable or unstable)
    # Use a specific branch, e.g., nixos-23.11 or nixos-unstable
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05"; # Make sure this matches your system.stateVersion

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs"; # Ensure HM uses the same nixpkgs
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

    # Add other inputs if needed (e.g., hardware specific flakes)
    # hardware.url = "github:NixOS/nixos-hardware";
  };

  # Define what your flake provides (outputs)
  outputs = { self, nixpkgs, home-manager, sops-nix, nixos-wsl, ... }@inputs:
  let
    # Define supported systems
    supportedSystems = [ "x86_64-linux" "aarch64-linux" ]; # Add others if needed

    # Helper function to generate NixOS configurations for each system
    forAllSystems = function: nixpkgs.lib.genAttrs supportedSystems (system: function system);

    # Shared modules applied to all hosts (except WSL module which is host-specific)
    commonModules = [
      # Base NixOS module with common system settings
      ./modules/nixos/base.nix

      # Service modules (uncomment as needed, configure per-host)
      # ./modules/nixos/services/traefik.nix
      # ./modules/nixos/services/jellyfin.nix # Configure in host file instead
      # ./modules/nixos/services/vaultwarden.nix
      # ./modules/nixos/services/authelia.nix
      # ./modules/nixos/services/homer.nix
      # ./modules/nixos/services/immich.nix
      # ./modules/nixos/services/lldap.nix
      # ./modules/nixos/services/nextcloud.nix
    ];

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
          # This now imports hardware-config AND the WSL module if needed
          ./hosts/${hostname}/default.nix

          # === Include any extra modules passed ===
        ] ++ extraModules;
      };

    # Helper: compose a host from its ./hosts/<name>/default.nix
    mkHost = hostPath: system:
      let
        pathStr = toString hostPath;
        parts = nixpkgs.lib.splitString "/" pathStr;
        hostname = builtins.elemAt parts ((builtins.length parts) - 2);

        # Try to read username from variables.nix if it exists
        varsPath = builtins.dirOf hostPath + "/variables.nix";
        vars = if builtins.pathExists varsPath then import varsPath else {};

        # Default username logic: use vars.username if present, otherwise nixuser,
        # but specifically default to wsluser for the 'wsl' host.
        defaultUsername = if hostname == "wsl" then "wsluser" else "nixuser";
        username = vars.username or defaultUsername;
      in
      nixosSystem {
        inherit system hostname username;
      };

  in
  {
    # === NixOS Configurations ===
    nixosConfigurations = {
      wsl = mkHost ./hosts/wsl/default.nix "x86_64-linux";
      # test = mkHost ./hosts/test/default.nix "x86_64-linux";
      # server1 = nixosSystem { system = "x86_64-linux"; hostname = "server1"; username = "karcsi"; };
    };

    # === Dev Shells Output ===
    devShells = forAllSystems (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = pkgs.mkShell {
          packages = with pkgs; [
            # Adjust Python version if needed based on your nixpkgs branch
            python311
            python311Packages.pip
            terraform
            ansible
            ansible-lint
            # just # Uncomment if you use 'just'
          ];
        };
      });

    # === Home Manager Configurations (Standalone - Optional) ===
    # homeConfigurations = { ... };

    # === Overlays (Optional) ===
    # overlays.default = import ./overlays { inherit inputs; };

    # === Packages (Optional) ===
    # packages = forAllSystems (system: import ./pkgs { pkgs = nixpkgs.legacyPackages.${system}; });
  };
}