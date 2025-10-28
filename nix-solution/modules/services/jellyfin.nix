{ config, lib, pkgs, ... }:
let cfg = config.services.jellyfin;
in
{
  options.services.jellyfin.enable = lib.mkEnableOption "Jellyfin media server";

  config = lib.mkIf cfg.enable {
    services.jellyfin.enable = true;

    users.groups.jellyfin = { };
    users.users.jellyfin = {
      isSystemUser = true;
      group = "jellyfin";
      extraGroups = lib.mkAfter [ "video" "render" ];
    };

    hardware.opengl.enable = lib.mkDefault true;
    networking.firewall.allowedTCPPorts = lib.mkAfter [ 8096 8920 ];
  };
}




#{ config, lib, pkgs, userConfig, ... }:
#
#with lib;
#
#let
#  cfg = config.services.custom.jellyfin;
#  mediaRoot = userConfig.MEDIA_ROOT or "/srv/media";
#in
#{
#  options.services.custom.jellyfin = {
#    enable = mkEnableOption "the custom Jellyfin media server service";
#  };
#
#  config = mkIf (userConfig.SERVICE_JELLYFIN_ENABLED or "false" == "true") {
#    services.jellyfin = {
#      enable = true;
#      openFirewall = mkDefault true;
#
#      # Use custom user for better permission management
#      user = "jellyfin";
#      group = "media";
#    };
#
#    # Ensure media group exists and jellyfin user is part of it
#    users.groups.media = {};
#    users.users.jellyfin = {
#      extraGroups = [ "media" "nextcloud" ];
#      description = "Jellyfin media server user";
#    };
#
#    # Create media directory structure
#    systemd.tmpfiles.rules = [
#      "d ${mediaRoot} 0755 root media -"
#      "d ${mediaRoot}/movies 0775 root media -"
#      "d ${mediaRoot}/tv 0775 root media -"
#      "d ${mediaRoot}/music 0775 root media -"
#      "d ${mediaRoot}/books 0775 root media -"
#      "d ${mediaRoot}/photos 0775 root media -"
#      # Shared directory for content from Nextcloud/other services
#      "d ${mediaRoot}/shared 0775 root media -"
#    ];
#
#    # Configure Jellyfin to use shared media directories
#    systemd.services.jellyfin.serviceConfig = {
#      # Bind mount shared media directories
#      BindReadOnlyPaths = [
#        "${mediaRoot}/movies:/var/lib/jellyfin/movies"
#        "${mediaRoot}/tv:/var/lib/jellyfin/tv"
#        "${mediaRoot}/music:/var/lib/jellyfin/music"
#        "${mediaRoot}/books:/var/lib/jellyfin/books"
#        "${mediaRoot}/photos:/var/lib/jellyfin/photos"
#        "${mediaRoot}/shared:/var/lib/jellyfin/shared"
#      ];
#
#      # Additional security and performance settings
#      PrivateNetwork = false;
#      PrivateUsers = false;
#      ProtectHome = true;
#      ProtectSystem = "strict";
#      ReadWritePaths = [ "/var/lib/jellyfin" "/var/cache/jellyfin" ];
#    };
#
#    # Create Traefik dynamic configuration for Jellyfin
#    environment.etc."traefik/dynamic/jellyfin.yml".text = mkIf (userConfig.SERVICE_TRAEFIK_ENABLED or "false" == "true") ''
#      http:
#        routers:
#          jellyfin:
#            rule: "Host(`${userConfig.JELLYFIN_HOSTNAME or "jellyfin.${userConfig.DOMAIN or "example.local"}"}`)"
#            entryPoints:
#              - websecure
#            service: jellyfin
#            tls:
#              certResolver: letsencrypt
#
#        services:
#          jellyfin:
#            loadBalancer:
#              servers:
#                - url: "http://127.0.0.1:8096"
#    '';
#
#    # Configure hardware acceleration if available
#    hardware.opengl = {
#      enable = true;
#      driSupport = true;
#      driSupport32Bit = true;
#    };
#
#    # Add jellyfin user to video group for hardware acceleration
#    users.users.jellyfin.extraGroups = mkAfter [ "video" "render" ];
#
#    # Systemd service to set up proper permissions after media directories are created
#    systemd.services.jellyfin-media-permissions = {
#      description = "Set up Jellyfin media permissions";
#      wantedBy = [ "multi-user.target" ];
#      after = [ "local-fs.target" ];
#      serviceConfig = {
#        Type = "oneshot";
#        RemainAfterExit = true;
#        ExecStart = pkgs.writeShellScript "jellyfin-permissions" ''
#          # Ensure jellyfin can read media files created by other services
#          ${pkgs.coreutils}/bin/chmod -R g+r ${mediaRoot}
#          ${pkgs.findutils}/bin/find ${mediaRoot} -type d -exec ${pkgs.coreutils}/bin/chmod g+x {} \;
#
#          # Set ACLs if available for better permission management
#          if command -v setfacl >/dev/null 2>&1; then
#            ${pkgs.acl}/bin/setfacl -R -m g:media:rx ${mediaRoot}
#            ${pkgs.acl}/bin/setfacl -R -d -m g:media:rx ${mediaRoot}
#          fi
#        '';
#      };
#    };
#
#    # Enable ACL support for better permission management
#    boot.supportedFilesystems = [ "ext4" ];
#
#    # Optional: Configure automatic media scanning
#    systemd.services.jellyfin-media-scan = {
#      description = "Jellyfin media library scan";
#      serviceConfig = {
#        Type = "oneshot";
#        User = "jellyfin";
#        Group = "media";
#        ExecStart = "${pkgs.curl}/bin/curl -X POST http://localhost:8096/Library/Refresh";
#      };
#    };
#
#    systemd.timers.jellyfin-media-scan = {
#      description = "Jellyfin media library scan timer";
#      wantedBy = [ "timers.target" ];
#      timerConfig = {
#        OnCalendar = "hourly";
#        Persistent = true;
#        RandomizedDelaySec = "10m";
#      };
#    };
#  };
#}