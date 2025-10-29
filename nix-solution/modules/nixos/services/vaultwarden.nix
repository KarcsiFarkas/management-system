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
      };
      # By default, vaultwarden listens on 127.0.0.1 (localhost)
      # This is GOOD for Traefik, as Traefik will handle external access.
    };

    # No firewall port needed if only Traefik accesses it via localhost
    # networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
