{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.paas.vikunja;
in
{
  options.services.paas.vikunja = {
    enable = mkEnableOption "Vikunja (To-Do App)";
  };

  config = mkIf cfg.enable {
    # Vikunja needs a database
    services.postgresql = {
      enable = true;
      initialScript = pkgs.writeText "vikunja-db-init" ''
        CREATE DATABASE vikunja;
        CREATE USER vikunja WITH PASSWORD 'vikunja';
        GRANT ALL PRIVILEGES ON DATABASE vikunja TO vikunja;
      '';
    };

    services.vikunja = {
      enable = true;
      database = {
        type = "postgres";
        host = "localhost";
        user = "vikunja";
        password = "vikunja"; # WARNING: Insecure
        database = "vikunja";
      };
      # Listen on localhost, let Traefik handle it
      listen = "127.0.0.1:3456";
    };

    # No firewall port needed if only Traefik accesses it
  };
}

