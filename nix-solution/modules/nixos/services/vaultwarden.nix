{ config, lib, pkgs, ... }:
let cfg = config.services.vaultwarden;
in
{
  options.services.vaultwarden = {
    enable = lib.mkEnableOption "Vaultwarden (Bitwarden) server";
    domain = lib.mkOption {
      type = lib.types.str; default = "";
      description = "External domain (for links in emails, etc.).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.vaultwarden = {
      enable = true;
      config = {
        DOMAIN = lib.mkIf (cfg.domain != "") cfg.domain;
        SIGNUPS_ALLOWED = true;
        ROCKET_PORT = 8222;
      };
    };
    networking.firewall.allowedTCPPorts = lib.mkAfter [ 8222 ];
  };
}


#{ config, lib, pkgs, userConfig, ... }:
#
#with lib;
#
#let
#  cfg = config.services.custom.vaultwarden;
#  domain = userConfig.DOMAIN or "example.local";
#  hostName = userConfig.VAULTWARDEN_HOSTNAME or "vault.${domain}";
#  enableAuthelia = (userConfig.SERVICE_AUTHELIA_ENABLED or false);
#  autheliaMiddleware = if enableAuthelia then ''
#            middlewares:
#              - authelia@file
#  '' else "";
#  signupsAllowed =
#    if builtins.hasAttr "VAULTWARDEN_SIGNUPS_ALLOWED" userConfig then
#      toString (userConfig.VAULTWARDEN_SIGNUPS_ALLOWED)
#    else "false";
#  adminTokenFile = pkgs.writeText "vaultwarden-admin-token" (userConfig.VAULTWARDEN_ADMIN_TOKEN or "changeme-admin-token");
#  rocketPort = 8222; # HTTP port for the main app
#  wsPort = 3012;     # WebSocket notifications port (Vaultwarden default)
#  listenAddr = "127.0.0.1";
#  routerYaml = ''
#      http:
#        routers:
#          vaultwarden:
#            rule: "Host(`${hostName}`)"
#            entryPoints:
#              - websecure
#            service: vaultwarden
#            tls:
#              certResolver: letsencrypt
#${autheliaMiddleware}
#          vaultwarden-websocket:
#            rule: "Host(`${hostName}`) && Path(`/notifications/hub`)"
#            entryPoints:
#              - websecure
#            service: vaultwarden-websocket
#            tls:
#              certResolver: letsencrypt
#${autheliaMiddleware}
#        services:
#          vaultwarden:
#            loadBalancer:
#              servers:
#                - url: "http://${listenAddr}:${toString rocketPort}"
#          vaultwarden-websocket:
#            loadBalancer:
#              servers:
#                - url: "http://${listenAddr}:${toString wsPort}"
#  '';
#
#in
#{
#  options.services.custom.vaultwarden = {
#    enable = mkEnableOption "the custom Vaultwarden password manager service";
#  };
#
#  config = mkIf (userConfig.SERVICE_VAULTWARDEN_ENABLED or "false" == "true") {
#    services.vaultwarden = {
#      enable = true;
#      dbBackend = "sqlite"; # lightweight default
#      config = {
#        DOMAIN = "https://${hostName}";
#        ROCKET_ADDRESS = listenAddr;
#        ROCKET_PORT = toString rocketPort;
#        WEBSOCKET_ENABLED = "true";
#        WEBSOCKET_ADDRESS = listenAddr;
#        WEBSOCKET_PORT = toString wsPort;
#        SIGNUPS_ALLOWED = signupsAllowed;
#        ADMIN_TOKEN_FILE = adminTokenFile;
#        # Attachments/data locations (defaults are fine, but keep explicit)
#        DATA_FOLDER = "/var/lib/bitwarden_rs";
#        ICON_CACHE_TTL = "2592000"; # 30 days
#        # SMTP (optional) – will apply only if provided in userConfig
#      } // optionalAttrs (builtins.hasAttr "SMTP_HOST" userConfig) {
#        SMTP_HOST = userConfig.SMTP_HOST;
#        SMTP_FROM = userConfig.SMTP_FROM or "vault@${domain}";
#        SMTP_PORT = toString (userConfig.SMTP_PORT or 587);
#        SMTP_SECURITY = userConfig.SMTP_SECURITY or "starttls";
#        SMTP_USERNAME = userConfig.SMTP_USERNAME or "";
#        SMTP_PASSWORD = userConfig.SMTP_PASSWORD or "";
#      };
#    };
#
#    # Ensure state dir exists with proper perms (service also handles it, but be explicit)
#    systemd.tmpfiles.rules = [
#      "d /var/lib/bitwarden_rs 0750 vaultwarden vaultwarden -"
#    ];
#
#    # No public port exposure; served via Traefik only
#    networking.firewall.allowedTCPPorts = mkAfter [ ];
#
#    # Traefik dynamic configuration (if enabled)
#    environment.etc."traefik/dynamic/vaultwarden.yml".text = mkIf ((userConfig.SERVICE_TRAEFIK_ENABLED or "false") == "true") routerYaml;
#
#    # Helpful admin commands
#    environment.etc."vaultwarden/admin-tools.sh".source = pkgs.writeShellScript "vw-admin" ''
#      #!/usr/bin/env bash
#      set -euo pipefail
#      BASE_URL="https://${hostName}"
#      echo "Vaultwarden base URL: $BASE_URL"
#      echo "Admin panel: $BASE_URL/admin"
#      echo "Note: Admin token is stored in ${adminTokenFile} on the system."
#    '';
#  };
#}
