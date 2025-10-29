{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.paas.nextcloud;
in
{
  options.services.paas.nextcloud = {
    enable = mkEnableOption "Nextcloud (File Sync)";
    port = mkOption { type = types.port; default = 9001; };
    domain = mkOption { type = types.str; default = "nextcloud.example.com"; };
  };

  config = mkIf cfg.enable {
    # Nextcloud needs Nginx+PHP and a database
    services.traefik.enable = true;
    services.phpfpm.enable = true;
    services.postgresql = {
      enable = true;
      initialScript = pkgs.writeText "nextcloud-db-init" ''
        CREATE DATABASE nextcloud;
        CREATE USER nextcloud WITH PASSWORD 'nextcloud';
        GRANT ALL PRIVILEGES ON DATABASE nextcloud TO nextcloud;
      '';
    };

    services.nextcloud = {
      enable = true;
      package = pkgs.nextcloud29; # Use latest
      hostName = cfg.domain;
      nginx.listen = [{ port = cfg.port; }]; # Listen on a non-standard port

      # Use postgresql
      database = {
        createLocally = false;
        type = "pgsql";
        host = "localhost";
        user = "nextcloud";
        password = "nextcloud"; # WARNING: Insecure
        name = "nextcloud";
      };

      config = {
        adminuser = "admin";
        adminpass = "admin"; # WARNING: Insecure
        # Use 'trusted_proxies' if behind Traefik
        # "trusted_proxies" = [ "127.0.0.1" "::1" ];
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
