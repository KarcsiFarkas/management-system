{
  description = "Declarative PaaS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs = { self, nixpkgs, ... }@inputs:
  let
    # Shared modules applied to all hosts
    commonModules = [
          ./modules/common.nix

          # Service modules (toggle per host via options)
          ./modules/services/traefik.nix
          ./modules/services/jellyfin.nix
          ./modules/services/vaultwarden.nix
          ./modules/services/authelia.nix
          ./modules/services/homer.nix
          ./modules/services/immich.nix

    #      ./modules/services/nextcloud.nix
    #      ./modules/services/gitlab.nix
    #      ./modules/services/gitea.nix
    #      ./modules/services/syncthing.nix
    #      ./modules/services/seafile.nix
    #      ./modules/services/sonarr.nix
    #      ./modules/services/radarr.nix
    #      ./modules/services/qbittorrent.nix
    #      ./modules/services/navidrome.nix
    #      ./modules/services/freshrss.nix
    #      ./modules/services/vikunja.nix
    #      ./modules/services/firefly-iii.nix
    #      ./modules/services/homer.nix
    #      ./modules/services/lldap.nix
        ];


    # Helper: compose a host from its ./hosts/<name>/default.nix
    mkHost = hostPath: system:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = commonModules ++ [ hostPath ];
      };
  in
  {
    # Append concrete hosts here (installer may edit this set)
    nixosConfigurations = {
      wsl = mkHost ./hosts/wsl/default.nix "x86_64-linux";
      # wsl = mkHost ./hosts/wsl/default.nix "x86_64-linux";
      # test = mkHost ./hosts/test/default.nix "x86_64-linux";
    };
  };
}
