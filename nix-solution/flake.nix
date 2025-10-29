# nix-solution/flake.nix
{
  description = "Declarative PaaS Configuration";

  # Define dependencies (inputs)
  inputs = {
    # Nixpkgs (stable or unstable)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; # Or nixos-24.11, etc.

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

    # Import your custom library/helpers if you create one (optional)
    # lib = import ./lib { inherit inputs; };

    # Shared modules applied to all hosts
    commonModules = [
      # Base NixOS module with common system settings
      ./modules/nixos/base.nix

#      # Service modules (toggle per host via options)
#      ./modules/nixos/services/traefik.nix
#      ./modules/nixos/services/jellyfin.nix
#      ./modules/nixos/services/vaultwarden.nix
#      ./modules/nixos/services/authelia.nix
#      ./modules/nixos/services/homer.nix
#      ./modules/nixos/services/immich.nix

      # Additional service modules (uncomment as needed)
      # ./modules/nixos/services/nextcloud.nix
      # ./modules/nixos/services/gitlab.nix
      # ./modules/nixos/services/gitea.nix
      # ./modules/nixos/services/syncthing.nix
      # ./modules/nixos/services/seafile.nix
      # ./modules/nixos/services/sonarr.nix
      # ./modules/nixos/services/radarr.nix
      # ./modules/nixos/services/qbittorrent.nix
      # ./modules/nixos/services/navidrome.nix
      # ./modules/nixos/services/freshrss.nix
      # ./modules/nixos/services/vikunja.nix
      # ./modules/nixos/services/firefly-iii.nix
      # ./modules/nixos/services/lldap.nix
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
          ./hosts/${hostname}/default.nix # Includes hardware-configuration.nix

          # === Include any extra modules passed ===
        ] ++ extraModules;
      };

    # Helper: compose a host from its ./hosts/<name>/default.nix (legacy compatibility)
    mkHost = hostPath: system:
      let
        # Extract hostname from path
        pathStr = toString hostPath;
        parts = nixpkgs.lib.splitString "/" pathStr;
        hostname = builtins.elemAt parts ((builtins.length parts) - 2);

        # Try to read username from variables.nix if it exists
        varsPath = builtins.dirOf hostPath + "/variables.nix";
        vars = if builtins.pathExists varsPath then import varsPath else {};
        username = vars.username or "nixuser";
      in
      nixosSystem {
        inherit system hostname username;
      };
  in
  {
    # === NixOS Configurations ===
    # Define each of your machines here
    nixosConfigurations = {
      # --- Existing hosts (using mkHost for compatibility) ---
      wsl = mkHost ./hosts/wsl/default.nix "x86_64-linux";
      # test = mkHost ./hosts/test/default.nix "x86_64-linux";

      # --- Example of direct nixosSystem usage ---
      # server1 = nixosSystem {
      #   system = "x86_64-linux";
      #   hostname = "server1";
      #   username = "karcsi";
      #   # extraModules = [ ./path/to/extra/module.nix ]; # Optional
      # };

      # --- Laptop Example (Add this if you have another machine) ---
      # mylaptop = nixosSystem {
      #   system = "x86_64-linux";
      #   hostname = "mylaptop";
      #   username = "karcsi";
      #   # If your laptop needs specific hardware quirks
      #   # extraModules = [ inputs.hardware.nixosModules.lenovo-thinkpad-x1-carbon-gen9 ];
      # };
    };

    # === Home Manager Configurations (Standalone - Optional) ===
    # You can define standalone HM configs if you don't manage the full OS
    # homeConfigurations = {
    #   "karcsi@server1" = home-manager.lib.homeManagerConfiguration {
    #     pkgs = nixpkgs.legacyPackages.x86_64-linux; # System specific
    #     extraSpecialArgs = { inherit inputs; hostname = "server1"; username = "karcsi"; };
    #     modules = [ ./hosts/server1/home.nix ];
    #   };
    # };

    # === Overlays (Optional) ===
    # overlays.default = import ./overlays { inherit inputs; };

    # === Packages (Optional) ===
    # packages = forAllSystems (system: import ./pkgs { pkgs = nixpkgs.legacyPackages.${system}; });

    # === Dev Shells (Optional) ===
    # devShells = forAllSystems (system: import ./shells { pkgs = nixpkgs.legacyPackages.${system}; });
  };
}
