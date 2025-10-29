{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.paas.traefik;
in
{
  options.services.paas.traefik = {
    enable = mkEnableOption "Traefik reverse proxy";
  };

  config = mkIf cfg.enable {
    services.traefik = {
      enable = true;
      staticConfigOptions = {
        # === Entrypoints ===
        entryPoints = {
          web = {
            address = ":80";
            # Optional: Redirect all HTTP to HTTPS
            # http.redirections.entryPoint.to = "websecure";
            # http.redirections.entryPoint.scheme = "https";
          };
          websecure = {
            address = ":443";
          };
          # Traefik dashboard
          traefik = {
            address = ":8080";
          };
        };

        # === Dashboard ===
        api = {
          dashboard = true;
          insecure = true; # Access dashboard on port 8080 (localhost only by default)
        };

        # === Providers ===
        providers = {
          # Watch for dynamic config files in this directory
          file = {
            directory = "/etc/traefik/dynamic";
            watch = true;
          };
          # Enable docker provider if you plan to use it (optional)
          # docker = {
          #   exposedByDefault = false;
          # };
        };
      };
    };

    # Create the dynamic configuration directory
    systemd.tmpfiles.rules = [
      "d /etc/traefik/dynamic 0750 traefik traefik -"
    ];

    # Open firewall ports
    networking.firewall.allowedTCPPorts = [ 80 443 8080 ];
  };
}
