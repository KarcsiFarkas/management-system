{ config, lib, pkgs, ... }:
let cfg = config.services.traefik;
in
{
  options.services.traefik.enable = lib.mkEnableOption "Traefik reverse proxy";

  config = lib.mkIf cfg.enable {
    services.traefik = {
      enable = true;
      staticConfigOptions = {
        entryPoints.web.address = ":80";
        # entryPoints.websecure.address = ":443";
      };
    };
    networking.firewall.allowedTCPPorts = lib.mkAfter [ 80 ];
    # networking.firewall.allowedTCPPorts = lib.mkAfter [ 80 443 ];
  };
}






#{ config, lib, pkgs, userConfig, ... }:
#
#with lib;
#
#let
#  cfg = config.services.custom.traefik;
#in
#{
#  options.services.custom.traefik = {
#    enable = mkEnableOption "the custom Traefik reverse proxy service";
#  };
#
#  config = mkIf (userConfig.SERVICE_TRAEFIK_ENABLED or "false" == "true") {
#    services.traefik = {
#      enable = true;
#
#      # Static configuration
#      staticConfigOptions = {
#        api = {
#          dashboard = true;
#          insecure = false;
#        };
#
#        entryPoints = {
#          web = {
#            address = ":80";
#            http.redirections.entrypoint = {
#              to = "websecure";
#              scheme = "https";
#            };
#          };
#          websecure = {
#            address = ":443";
#          };
#        };
#
#        providers = {
#          file = {
#            directory = "/etc/traefik/dynamic";
#            watch = true;
#          };
#        };
#
#        certificatesResolvers = {
#          letsencrypt = {
#            acme = {
#              email = userConfig.TRAEFIK_ACME_EMAIL or "admin@${userConfig.DOMAIN or "example.local"}";
#              storage = "/var/lib/traefik/acme.json";
#              httpChallenge = {
#                entryPoint = "web";
#              };
#            };
#          };
#        };
#      };
#    };
#
#    # Create dynamic configuration directory
#    systemd.tmpfiles.rules = [
#      "d /etc/traefik/dynamic 0755 traefik traefik -"
#      "f /var/lib/traefik/acme.json 0600 traefik traefik -"
#    ];
#
#    # Open firewall ports
#    networking.firewall.allowedTCPPorts = [ 80 443 8080 ];
#
#    # Create Traefik dashboard configuration
#    environment.etc."traefik/dynamic/dashboard.yml".text = ''
#      http:
#        routers:
#          traefik-dashboard:
#            rule: "Host(`traefik.${userConfig.DOMAIN or "example.local"}`)"
#            entryPoints:
#              - websecure
#            service: api@internal
#            tls:
#              certResolver: letsencrypt
#    '';
#  };
#}