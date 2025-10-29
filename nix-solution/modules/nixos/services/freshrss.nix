{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.paas.freshrss;
in
{
  options.services.paas.freshrss = {
    enable = mkEnableOption "FreshRSS (Feed Reader)";
    port = mkOption { type = types.port; default = 8083; };
  };

  config = mkIf cfg.enable {
    # FreshRSS needs Nginx+PHP and a database
    services.traefik.enable = true;
    services.phpfpm.enable = true;
    services.postgresql = {
      enable = true;
      initialScript = pkgs.writeText "freshrss-db-init" ''
        CREATE DATABASE freshrss;
        CREATE USER freshrss WITH PASSWORD 'freshrss';
        GRANT ALL PRIVILEGES ON DATABASE freshrss TO freshrss;
      '';
    };

    services.freshrss = {
      enable = true;
      virtualHost = {
        enable = true;
        listen = [{ port = cfg.port; }];
        # serverName = "rss.your.domain"; # Set in host config
      };
      database = {
        type = "pgsql";
        host = "localhost";
        user = "freshrss";
        password = "freshrss"; # WARNING: Insecure
        name = "freshrss";
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}

