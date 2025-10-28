{
  description = "Declarative PaaS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # home-manager.url = "github:nix-community/home-manager";
    # home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # sops-nix.url = "github:Mic92/sops-nix";
    # sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs,... }@inputs: {
    nixosConfigurations.server1 = { userConfig ? {} }: nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { 
        inherit inputs userConfig; # Pass flake inputs and user config to modules
      };
      modules = [
        ./hosts/server1/default.nix
        ./modules/common.nix
        # Import all service modules
        ./modules/services/traefik.nix
        ./modules/services/nextcloud.nix
        ./modules/services/jellyfin.nix
        ./modules/services/gitlab.nix
        ./modules/services/gitea.nix
        ./modules/services/vaultwarden.nix
        ./modules/services/immich.nix
        ./modules/services/syncthing.nix
        ./modules/services/seafile.nix
        ./modules/services/sonarr.nix
        ./modules/services/radarr.nix
        ./modules/services/qbittorrent.nix
        ./modules/services/navidrome.nix
        ./modules/services/freshrss.nix
        ./modules/services/vikunja.nix
        ./modules/services/firefly-iii.nix
        ./modules/services/homer.nix
        ./modules/services/lldap.nix
        ./modules/services/authelia.nix
      ];
    };
  };
}
