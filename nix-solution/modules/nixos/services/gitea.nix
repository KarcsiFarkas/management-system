{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.paas.gitea;
in
{
  options.services.paas.gitea = {
    enable = mkEnableOption "Gitea (Git Server)";
  };

  config = mkIf cfg.enable {
    # Gitea needs a database
    services.postgresql = {
      enable = true;
      initialScript = pkgs.writeText "gitea-db-init" ''
        CREATE DATABASE gitea;
        CREATE USER gitea WITH PASSWORD 'gitea';
        GRANT ALL PRIVILEGES ON DATABASE gitea TO gitea;
      '';
    };

    services.gitea = {
      enable = true;
      database = {
        type = "postgres";
        host = "localhost";
        user = "gitea";
        password = "gitea"; # WARNING: Insecure
        name = "gitea";
      };
      # Listen on localhost, let Traefik handle external access
      http = {
        domain = "localhost"; # Internal domain
        port = 3000; # Default port
        listenAddr = "127.0.0.1";
      };
      # settings.server.ROOT_URL = "https://gitea.your.domain"; # Set in host config
    };

    # No firewall port needed if only Traefik accesses it
  };
}

