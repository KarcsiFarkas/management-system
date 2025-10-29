{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.paas.immich;
in
{
  options.services.paas.immich = {
    enable = mkEnableOption "Immich photo service";
  };

  config = mkIf cfg.enable {
    # Immich needs a database and redis
    services.postgresql = {
      enable = true;
      initialScript = pkgs.writeText "immich-db-init" ''
        CREATE DATABASE immich;
        CREATE USER immich WITH PASSWORD 'immich';
        GRANT ALL PRIVILEGES ON DATABASE immich TO immich;
      '';
    };
    services.redis.enable = true;

    services.immich = {
      enable = true;
      database.type = "postgresql";
      database.host = "localhost";
      database.user = "immich";
      database.password = "immich"; # WARNING: Insecure
      database.database = "immich";
      redis.host = "localhost";
    };

    # Open the default Immich web port
    networking.firewall.allowedTCPPorts = [ 2283 ];
  };
}

