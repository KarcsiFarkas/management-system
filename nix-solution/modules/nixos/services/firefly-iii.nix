{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.paas.firefly-iii;
in
{
  options.services.paas.firefly-iii = {
    enable = mkEnableOption "Firefly III (Finance)";
    port = mkOption { type = types.port; default = 8084; };
  };

  config = mkIf cfg.enable {
    # Firefly III needs Nginx+PHP and a database
    services.traefik.enable = true;
    services.phpfpm.enable = true;
    services.postgresql = {
      enable = true;
      initialScript = pkgs.writeText "firefly-iii-db-init" ''
        CREATE DATABASE firefly;
        CREATE USER firefly WITH PASSWORD 'firefly';
        GRANT ALL PRIVILEGES ON DATABASE firefly TO firefly;
      '';
    };

    services.firefly-iii = {
      enable = true;
      virtualHost = {
        enable = true;
        listen = [{ port = cfg.port; }];
        # serverName = "firefly.your.domain"; # Set in host config
      };
      database = {
        type = "pgsql";
        host = "localhost";
        user = "firefly";
        password = "firefly"; # WARNING: Insecure
        name = "firefly";
      };
      # appUrl = "https://firefly.your.domain"; # Set in host config
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}

