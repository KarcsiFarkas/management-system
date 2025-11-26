# nixos-anywhere deployment configuration
# Integrates with tenant configurations from ms-config repository
{
  description = "NixOS-Anywhere PaaS Deployment Configuration";

  inputs = {
    # Using nixos-unstable for latest features and compatibility with nixos-anywhere
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Disko for declarative disk partitioning
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets management with sops-nix
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home Manager for user environment (optional)
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # WSL Support for local testing
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Yazi file manager (bleeding edge)
    yazi = {
      url = "github:sxyazi/yazi";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Cachix configuration for faster builds
  nixConfig = {
    extra-substituters = [ "https://yazi.cachix.org" ];
    extra-trusted-public-keys = [ "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k=" ];
  };

  outputs = { self, nixpkgs, disko, sops-nix, home-manager, nixos-wsl, yazi, ... }@inputs:
    let
      # Supported systems
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];

      # Helper to generate system-specific outputs
      forAllSystems = function: nixpkgs.lib.genAttrs supportedSystems (system: function system);

      # Common modules applied to all hosts
      commonModules = [
        # Base system configuration
        ./common/base.nix

        # Security hardening
        ./common/security.nix

        # Network configuration utilities
        ./common/networking.nix

        # User management utilities
        ./common/users.nix
      ];

      # Tenant configuration loader
      # Reads tenant-specific configuration from ms-config repository
      loadTenantConfig = tenantName: hostName:
        let
          tenantConfigPath = ../../../ms-config/tenants/${tenantName}/${hostName};
          hasConfig = builtins.pathExists tenantConfigPath;
        in
        if hasConfig then
          import tenantConfigPath
        else
          { }; # Return empty attrset if no tenant config exists

      # Host builder function
      # Creates a NixOS configuration for a specific host with tenant integration
      mkHost = {
        hostname,
        system ? "x86_64-linux",
        tenant ? "default",
        diskLayout ? "standard-gpt",
        username ? "nixuser",
        extraModules ? []
      }: nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit inputs hostname username tenant;
          tenantConfig = loadTenantConfig tenant hostname;
        };

        modules = commonModules ++ [
          # === Disko Integration ===
          disko.nixosModules.disko
          ./disk-configs/${diskLayout}.nix

          # === Secrets Integration ===
          sops-nix.nixosModules.sops
          ./secrets

          # === Home Manager Integration (Optional) ===
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs hostname username; };

            # Import user home configuration if it exists
            home-manager.users.${username} = { ... }: {
              # Set home-manager state version (must match system.stateVersion)
              home.stateVersion = "24.11";

              imports = nixpkgs.lib.optional
                (builtins.pathExists ./hosts/${hostname}/home.nix)
                ./hosts/${hostname}/home.nix;
            };
          }

          # === Service Modules (from existing nix-solution) ===
          # Import service modules to make them available
          # Only import modules that are known to work correctly
          ../nix-flake/modules/nixos/services/traefik.nix
          ../nix-flake/modules/nixos/services/jellyfin.nix
          ../nix-flake/modules/nixos/services/syncthing.nix

          # === Local Service Modules (Fixed/New) ===
          ./common/services/vaultwarden.nix
          ./common/services/gitea.nix
          ./common/services/homepage-dashboard.nix
          ./common/services/authentik.nix

          # FIXME: These modules have configuration errors and need to be fixed:
          # - authelia: No upstream NixOS module
          # - nextcloud, gitlab, immich, seafile: Config option issues
          # - firefly-iii, freshrss: Config option issues
          # - vikunja, navidrome: Needs testing
          # - qbittorrent, radarr, sonarr: Needs testing

          # Uncomment after fixing:
          # ../nix-flake/modules/nixos/services/homer.nix
          # ../nix-flake/modules/nixos/services/vikunja.nix
          # ../nix-flake/modules/nixos/services/navidrome.nix
          # ../nix-flake/modules/nixos/services/qbittorrent.nix
          # ../nix-flake/modules/nixos/services/radarr.nix
          # ../nix-flake/modules/nixos/services/sonarr.nix
          # ../nix-flake/modules/nixos/services/authelia.nix
          # ../nix-flake/modules/nixos/services/nextcloud.nix
          # ../nix-flake/modules/nixos/services/gitlab.nix
          # ../nix-flake/modules/nixos/services/immich.nix
          # ../nix-flake/modules/nixos/services/seafile.nix
          # ../nix-flake/modules/nixos/services/firefly-iii.nix
          # ../nix-flake/modules/nixos/services/freshrss.nix

          # === Host Specific Configuration ===
          ./hosts/${hostname}/default.nix

        ] ++ extraModules;
      };

      # Tenant-aware host builder
      # Automatically loads tenant configuration from ms-config
      mkTenantHost = { hostname, tenant, ... }@args:
        mkHost (args // {
          extraModules = args.extraModules or [] ++ [
            # Tenant-specific overrides
            ({ config, lib, tenantConfig, ... }: {
              # Apply tenant configuration overrides
              imports = lib.optional
                (tenantConfig != {} && tenantConfig ? imports)
                tenantConfig.imports or [];

              # Merge tenant configuration options
              config = lib.mkMerge [
                (lib.optionalAttrs (tenantConfig != {} && tenantConfig ? config)
                  tenantConfig.config or {})
              ];
            })
          ];
        });
    in
    {
      # === NixOS Configurations ===
      nixosConfigurations = {
        # Template configuration (for creating new hosts)
        template = mkHost {
          hostname = "template";
          system = "x86_64-linux";
          diskLayout = "standard-gpt";
          username = "nixuser";
        };

        # Example production PaaS server
        paas-server = mkTenantHost {
          hostname = "paas-server";
          tenant = "production";
          system = "x86_64-linux";
          diskLayout = "standard-gpt-lvm";
          username = "paasadmin";
        };

        # Example development server
        dev-server = mkTenantHost {
          hostname = "dev-server";
          tenant = "development";
          system = "x86_64-linux";
          diskLayout = "standard-gpt";
          username = "devadmin";
        };

        # Example testing/staging server
        staging-server = mkTenantHost {
          hostname = "staging-server";
          tenant = "staging";
          system = "x86_64-linux";
          diskLayout = "standard-gpt";
          username = "stagingadmin";
        };

        # ARM64 example (for ARM-based cloud providers or Raspberry Pi)
        arm-server = mkTenantHost {
          hostname = "arm-server";
          tenant = "production";
          system = "aarch64-linux";
          diskLayout = "standard-gpt";
          username = "armadmin";
        };

        # WSL PaaS server (for local testing on NixOS WSL)
        wsl-paas = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs;
            hostname = "wsl-paas";
            username = "nixos";
          };
          modules = commonModules ++ [
            # No disko for WSL
            # sops-nix still useful
            sops-nix.nixosModules.sops
            ./secrets

            # Service modules
            ../nix-flake/modules/nixos/services/traefik.nix
            ../nix-flake/modules/nixos/services/jellyfin.nix
            # ../nix-flake/modules/nixos/services/homer.nix # Replaced

            # Local Service Modules
            ./common/services/vaultwarden.nix
            ./common/services/gitea.nix
            ./common/services/homepage-dashboard.nix
            ./common/services/authentik.nix

            # WSL-specific configuration
            ./hosts/wsl-paas/default.nix
          ];
        };

        # NixOS VM 01 - Testing nixos-anywhere deployment
        # Tenant: nix (nix.karcsilab.duckdns.org)
        # Services: Gitea
        nixos-vm-01 = mkTenantHost {
          hostname = "nixos-vm-01";
          tenant = "nix";
          system = "x86_64-linux";
          diskLayout = "standard-mbr";
          username = "nixadmin";
        };
      };

      # === Development Shells ===
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            name = "nixos-anywhere-deployment";

            buildInputs = with pkgs; [
              # Deployment tools
              nixos-anywhere

              # Secret management
              sops
              age
              ssh-to-age

              # Utilities
              git
              openssh
              jq
              yq

              # Debugging
              nix-tree
              nixos-rebuild
            ];

            shellHook = ''
              echo "=========================================="
              echo "  NixOS-Anywhere Deployment Environment  "
              echo "=========================================="
              echo ""
              echo "Available commands:"
              echo "  - nixos-anywhere: Deploy NixOS remotely"
              echo "  - sops: Manage encrypted secrets"
              echo "  - age: Encryption tool"
              echo ""
              echo "Quick deployment:"
              echo "  nix run github:nix-community/nixos-anywhere -- \\"
              echo "    --flake .#hostname \\"
              echo "    --target-host root@IP_ADDRESS"
              echo ""
              echo "Tenant-specific deployment script:"
              echo "  ./scripts/deploy-tenant.sh TENANT_NAME HOST_NAME IP_ADDRESS"
              echo ""
            '';
          };
        });

      # === Deployment Scripts Output ===
      # Makes deployment scripts accessible via 'nix run .#deploy'
      apps = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          deploy = {
            type = "app";
            program = "${./scripts/deploy.sh}";
            meta = {
              description = "Deploy NixOS configuration to remote hosts using nixos-anywhere";
            };
          };

          deploy-tenant = {
            type = "app";
            program = "${./scripts/deploy-tenant.sh}";
            meta = {
              description = "Deploy tenant-specific NixOS configuration from ms-config repository";
            };
          };
        });

      # === Formatter ===
      formatter = forAllSystems (system:
        nixpkgs.legacyPackages.${system}.nixpkgs-fmt
      );
    };
}
