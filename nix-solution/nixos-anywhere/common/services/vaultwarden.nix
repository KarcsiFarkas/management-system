{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.paas.vaultwarden;
in
{
  options.services.paas.vaultwarden = {
    enable = mkEnableOption "Vaultwarden (Bitwarden) server";
    port = mkOption { type = types.port; default = 8222; };
    domain = mkOption { type = types.str; default = "http://localhost:${toString cfg.port}"; };
  };

  config = mkIf cfg.enable {
    services.vaultwarden = {
      enable = true;
      config = {
        DOMAIN = cfg.domain;
        SIGNUPS_ALLOWED = true;
        ROCKET_PORT = cfg.port;
        ROCKET_ADDRESS = "127.0.0.1";
      };
    };
  };
}
