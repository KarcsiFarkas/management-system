# common/ports.nix
# Centralized port allocation for all PaaS services
# See PORT_ALLOCATION.md for full documentation

{ lib, ... }:

{
  options.paas.ports = lib.mkOption {
    type = lib.types.attrs;
    description = "Centralized port definitions for PaaS services";
    default = {
      # Infrastructure
      traefik = {
        http = 80;
        https = 443;
        dashboard = 8080;
      };

      traefik-wsl = {
        http = 8090;  # Non-conflicting for WSL
        https = 8443;
        dashboard = 9080;
      };

      # Core Services
      homer = 8088;
      authelia = 9091;

      # Storage & Sync
      nextcloud = 8081;
      seafile = 8082;

      # Development
      gitlab = {
        http = 8083;
        ssh = 2222;
      };
      gitea = 3000;

      # Media Services
      jellyfin = {
        http = 8096;
        https = 8920;
      };
      immich = 2283;
      navidrome = 4533;

      # Automation
      radarr = 7878;
      sonarr = 8989;
      qbittorrent = {
        web = 8084;
        bt = 6881;
      };

      # Management
      vaultwarden = 8085;
      vikunja = 3456;
      fireflyiii = 8086;
      freshrss = 8087;

      # Communication
      syncthing = {
        web = 8384;
        sync = 22000;
        discovery = 21027;
      };
    };
  };

  options.paas.useWslPorts = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Use WSL-compatible ports (avoids system ports 80, 443, 8080)";
  };
}
