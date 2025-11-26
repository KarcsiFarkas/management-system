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
        host = "/run/postgresql"; # Use socket
        user = "gitea";
        name = "gitea";
        createDatabase = false; # We do it manually via postgresql service
      };
      
      settings.server = {
        DOMAIN = "localhost";
        HTTP_PORT = 3000;
        HTTP_ADDR = "127.0.0.1";
      };
    };
  };
}
