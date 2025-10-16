{ config, lib, pkgs, userConfig, ... }:

with lib;

let
  cfg = config.services.custom.nextcloud;
  mediaRoot = userConfig.MEDIA_ROOT or "/srv/media";
in
{
  options.services.custom.nextcloud = {
    enable = mkEnableOption "the custom Nextcloud service";
  };

  config = mkIf (userConfig.SERVICE_NEXTCLOUD_ENABLED or "false" == "true") {
    services.nextcloud = {
      enable = true;
      package = pkgs.nextcloud28;
      
      hostName = userConfig.NEXTCLOUD_HOSTNAME or "nextcloud.${userConfig.DOMAIN or "example.local"}";
      
      # Use HTTPS behind reverse proxy
      https = true;
      
      # Database configuration - automatically use PostgreSQL
      database.createLocally = false;
      config = {
        dbtype = "pgsql";
        dbname = "nextcloud";
        dbhost = "localhost";
        dbport = 5432;
        dbuser = userConfig.POSTGRES_USER or "paas_user";
        dbpassFile = pkgs.writeText "nextcloud-db-pass" (userConfig.POSTGRES_PASSWORD or "changeme");
        
        adminuser = userConfig.NEXTCLOUD_ADMIN_USER or "admin";
        adminpassFile = pkgs.writeText "nextcloud-admin-pass" (userConfig.NEXTCLOUD_ADMIN_PASSWORD or "changeme");
        
        overwriteProtocol = "https";
        trustedProxies = [ "127.0.0.1" "::1" ];
      };
      
      # Configure data directory with shared media access
      home = "/var/lib/nextcloud";
      datadir = "/var/lib/nextcloud/data";
      
      # Enable additional apps
      extraApps = with config.services.nextcloud.package.packages; {
        inherit contacts calendar tasks;
      };
      
      # Additional configuration
      extraOptions = {
        "memcache.local" = "\\OC\\Memcache\\APCu";
        "default_phone_region" = "US";
        "maintenance_window_start" = 1;
      };
    };

    # Enable PostgreSQL if not already enabled
    services.postgresql = {
      enable = true;
      ensureDatabases = [ "nextcloud" ];
      ensureUsers = [
        {
          name = userConfig.POSTGRES_USER or "paas_user";
          ensurePermissions = {
            "DATABASE nextcloud" = "ALL PRIVILEGES";
          };
        }
      ];
    };

    # Create shared media directories and set permissions
    systemd.tmpfiles.rules = [
      "d ${mediaRoot} 0755 nextcloud nextcloud -"
      "d ${mediaRoot}/nextcloud 0755 nextcloud nextcloud -"
      "d ${mediaRoot}/shared 0755 nextcloud nextcloud -"
    ];

    # Add nextcloud user to media group for shared access
    users.users.nextcloud.extraGroups = [ "media" ];
    users.groups.media = {};

    # Create Traefik dynamic configuration for Nextcloud
    environment.etc."traefik/dynamic/nextcloud.yml".text = mkIf (userConfig.SERVICE_TRAEFIK_ENABLED or "false" == "true") ''
      http:
        routers:
          nextcloud:
            rule: "Host(`${userConfig.NEXTCLOUD_HOSTNAME or "nextcloud.${userConfig.DOMAIN or "example.local"}"}`)"
            entryPoints:
              - websecure
            service: nextcloud
            tls:
              certResolver: letsencrypt
            middlewares:
              - nextcloud-caldav
        
        services:
          nextcloud:
            loadBalancer:
              servers:
                - url: "http://127.0.0.1:80"
        
        middlewares:
          nextcloud-caldav:
            redirectRegex:
              permanent: true
              regex: "^https://(.*)/.well-known/(card|cal)dav"
              replacement: "https://''${1}/remote.php/dav/"
    '';

    # Open firewall for Nextcloud
    networking.firewall.allowedTCPPorts = [ 80 ];

    # Ensure proper file permissions for shared media
    systemd.services.nextcloud-setup.serviceConfig.ExecStartPost = [
      "${pkgs.coreutils}/bin/chown -R nextcloud:media ${mediaRoot}/nextcloud"
      "${pkgs.coreutils}/bin/chmod -R 775 ${mediaRoot}/nextcloud"
    ];
  };
}