{ config, lib, pkgs, userConfig, ... }:

with lib;

let
  cfg = config.services.custom.authelia;
in
{
  options.services.custom.authelia = {
    enable = mkEnableOption "the custom Authelia SSO service";
  };

  config = mkIf (userConfig.SERVICE_AUTHELIA_ENABLED or "false" == "true") {
    services.authelia.instances.main = {
      enable = true;
      
      settings = {
        # Server configuration
        server = {
          host = "127.0.0.1";
          port = 9091;
        };

        # Logging configuration
        log = {
          level = "info";
        };

        # JWT secret for token validation
        jwt_secret = userConfig.AUTHELIA_JWT_SECRET or "changeme-jwt-secret";

        # Default redirection URL
        default_redirection_url = "https://${userConfig.DOMAIN or "example.local"}";

        # TOTP configuration
        totp = {
          issuer = "authelia.com";
        };

        # Authentication backend - LDAP
        authentication_backend = {
          ldap = {
            implementation = "custom";
            url = "ldap://127.0.0.1:3890";
            timeout = "5s";
            start_tls = false;
            tls = {
              skip_verify = false;
              minimum_version = "TLS1.2";
            };
            base_dn = userConfig.LDAP_BASE_DN or "dc=example,dc=local";
            username_attribute = "uid";
            additional_users_dn = "ou=people";
            users_filter = "(&({username_attribute}={input})(objectClass=person))";
            additional_groups_dn = "ou=groups";
            groups_filter = "(member={dn})";
            group_name_attribute = "cn";
            mail_attribute = "mail";
            display_name_attribute = "displayName";
            user = "cn=admin,ou=people,${userConfig.LDAP_BASE_DN or "dc=example,dc=local"}";
            password = userConfig.LLDAP_ADMIN_PASSWORD or "changeme";
          };
        };

        # Access control configuration
        access_control = {
          default_policy = "deny";
          rules = [
            {
              domain = "auth.${userConfig.DOMAIN or "example.local"}";
              policy = "bypass";
            }
            {
              domain = "*.${userConfig.DOMAIN or "example.local"}";
              policy = "one_factor";
            }
          ];
        };

        # Session configuration
        session = {
          name = "authelia_session";
          domain = userConfig.DOMAIN or "example.local";
          same_site = "lax";
          secret = userConfig.AUTHELIA_SESSION_SECRET or "changeme-session-secret";
          expiration = "1h";
          inactivity = "5m";
          remember_me_duration = "1M";
        };

        # Regulation configuration
        regulation = {
          max_retries = 3;
          find_time = "120s";
          ban_time = "300s";
        };

        # Storage configuration
        storage = {
          encryption_key = userConfig.AUTHELIA_STORAGE_ENCRYPTION_KEY or "changeme-storage-key";
          local = {
            path = "/var/lib/authelia-main/db.sqlite3";
          };
        };

        # Notification configuration
        notifier = {
          disable_startup_check = false;
          filesystem = {
            filename = "/var/lib/authelia-main/notification.txt";
          };
        };
      };
    };

    # Create Authelia data directory
    systemd.tmpfiles.rules = [
      "d /var/lib/authelia-main 0750 authelia authelia -"
    ];

    # Open firewall port
    networking.firewall.allowedTCPPorts = [ 9091 ];

    # Create Traefik dynamic configuration for Authelia
    environment.etc."traefik/dynamic/authelia.yml".text = mkIf (userConfig.SERVICE_TRAEFIK_ENABLED or "false" == "true") ''
      http:
        routers:
          authelia:
            rule: "Host(`${userConfig.AUTHELIA_HOSTNAME or "auth.${userConfig.DOMAIN or "example.local"}"}`)"
            entryPoints:
              - websecure
            service: authelia
            tls:
              certResolver: letsencrypt
        
        services:
          authelia:
            loadBalancer:
              servers:
                - url: "http://127.0.0.1:9091"
        
        middlewares:
          authelia:
            forwardAuth:
              address: "http://127.0.0.1:9091/api/verify?rd=https://auth.${userConfig.DOMAIN or "example.local"}"
              trustForwardHeader: true
              authResponseHeaders:
                - "Remote-User"
                - "Remote-Groups" 
                - "Remote-Name"
                - "Remote-Email"
    '';

    # Create systemd service to wait for LLDAP before starting Authelia
    systemd.services.authelia-main = {
      after = [ "lldap.service" ];
      wants = [ "lldap.service" ];
      serviceConfig = {
        # Add a pre-start script to wait for LLDAP
        ExecStartPre = pkgs.writeShellScript "wait-for-lldap" ''
          echo "Waiting for LLDAP to be ready..."
          for i in {1..30}; do
            if ${pkgs.curl}/bin/curl -s http://localhost:17170/health >/dev/null 2>&1; then
              echo "LLDAP is ready"
              exit 0
            fi
            echo "Waiting for LLDAP... ($i/30)"
            sleep 2
          done
          echo "Warning: LLDAP may not be ready, but starting Authelia anyway"
          exit 0
        '';
      };
    };

    # Install utilities for Authelia administration
    environment.systemPackages = with pkgs; [
      authelia
    ];

    # Create helper script for Authelia operations
    environment.etc."authelia/admin-tools.sh".source = pkgs.writeShellScript "authelia-admin" ''
      #!/bin/bash
      # Authelia Administration Helper Script
      
      AUTHELIA_URL="http://localhost:9091"
      
      case "$1" in
        "status")
          echo "Checking Authelia status..."
          ${pkgs.curl}/bin/curl -s "$AUTHELIA_URL/api/health" | ${pkgs.jq}/bin/jq .
          ;;
        "users")
          echo "This would show LDAP users (requires LDAP tools)"
          /etc/lldap/admin-tools.sh search "(objectClass=person)"
          ;;
        "config")
          echo "Authelia configuration location: /var/lib/authelia-main/"
          echo "Logs: journalctl -u authelia-main"
          ;;
        *)
          echo "Usage: $0 {status|users|config}"
          echo "  status  - Check Authelia health status"
          echo "  users   - List LDAP users"
          echo "  config  - Show configuration info"
          ;;
      esac
    '';
  };
}