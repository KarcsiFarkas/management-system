{ config, lib, pkgs, userConfig, ... }:

with lib;

let
  cfg = config.services.custom.lldap;
in
{
  options.services.custom.lldap = {
    enable = mkEnableOption "the custom LLDAP authentication service";
  };

  config = mkIf (userConfig.SERVICE_LLDAP_ENABLED or "false" == "true") {
    services.lldap = {
      enable = true;
      
      settings = {
        # LDAP configuration
        ldap_host = "0.0.0.0";
        ldap_port = 3890;
        
        # HTTP configuration for web interface
        http_host = "127.0.0.1";
        http_port = 17170;
        
        # Base DN configuration from user config
        ldap_base_dn = userConfig.LDAP_BASE_DN or "dc=example,dc=local";
        
        # Database configuration - use SQLite by default
        database_url = "sqlite:///var/lib/lldap/users.db";
        
        # JWT secret for session management
        jwt_secret_file = pkgs.writeText "lldap-jwt-secret" (userConfig.LLDAP_JWT_SECRET or "changeme-jwt-secret");
        
        # LDAP user password
        ldap_user_pass_file = pkgs.writeText "lldap-user-pass" (userConfig.LLDAP_ADMIN_PASSWORD or "changeme");
        
        # Additional LDAP configuration
        ldap_user_dn = "admin";
        ldap_user_email = userConfig.ADMIN_EMAIL or "admin@${userConfig.DOMAIN or "example.local"}";
        
        # Enable TLS for LDAP connections
        ldaps_options = {
          enabled = false; # Disable LDAPS since we're behind reverse proxy
        };
      };
    };

    # Create LLDAP data directory
    systemd.tmpfiles.rules = [
      "d /var/lib/lldap 0750 lldap lldap -"
    ];

    # Open firewall ports
    networking.firewall.allowedTCPPorts = [ 3890 17170 ];

    # Create Traefik dynamic configuration for LLDAP web interface
    environment.etc."traefik/dynamic/lldap.yml".text = mkIf (userConfig.SERVICE_TRAEFIK_ENABLED or "false" == "true") ''
      http:
        routers:
          lldap:
            rule: "Host(`${userConfig.LLDAP_HOSTNAME or "ldap.${userConfig.DOMAIN or "example.local"}"}`)"
            entryPoints:
              - websecure
            service: lldap
            tls:
              certResolver: letsencrypt
        
        services:
          lldap:
            loadBalancer:
              servers:
                - url: "http://127.0.0.1:17170"
    '';

    # Configure LDAP integration for other services
    # This creates a common LDAP configuration that other services can use
    environment.etc."ldap/ldap.conf".text = ''
      # LDAP client configuration for system integration
      BASE ${userConfig.LDAP_BASE_DN or "dc=example,dc=local"}
      URI ldap://localhost:3890
      
      # TLS configuration
      TLS_REQCERT never
      
      # Bind configuration
      BINDDN cn=admin,ou=people,${userConfig.LDAP_BASE_DN or "dc=example,dc=local"}
    '';

    # Create systemd service to initialize LLDAP with default groups and users
    systemd.services.lldap-init = {
      description = "Initialize LLDAP with default configuration";
      after = [ "lldap.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "lldap-init" ''
          # Wait for LLDAP to be ready
          sleep 10
          
          # Create default groups using LLDAP API
          ${pkgs.curl}/bin/curl -X POST http://localhost:17170/api/groups \
            -H "Content-Type: application/json" \
            -d '{"display_name": "nextcloud_users", "creation_date": "2024-01-01T00:00:00Z"}' || true
          
          ${pkgs.curl}/bin/curl -X POST http://localhost:17170/api/groups \
            -H "Content-Type: application/json" \
            -d '{"display_name": "jellyfin_users", "creation_date": "2024-01-01T00:00:00Z"}' || true
          
          ${pkgs.curl}/bin/curl -X POST http://localhost:17170/api/groups \
            -H "Content-Type: application/json" \
            -d '{"display_name": "admin_users", "creation_date": "2024-01-01T00:00:00Z"}' || true
        '';
      };
    };

    # Configure PAM for LDAP authentication (optional)
    security.pam.services = mkIf (userConfig.ENABLE_LDAP_PAM or "false" == "true") {
      login.makeHomeDir = true;
      sshd.makeHomeDir = true;
    };

    # Install LDAP utilities for administration
    environment.systemPackages = with pkgs; [
      openldap
      ldapvi
    ];

    # Create helper script for LDAP operations
    environment.etc."lldap/admin-tools.sh".source = pkgs.writeShellScript "lldap-admin" ''
      #!/bin/bash
      # LLDAP Administration Helper Script
      
      LDAP_HOST="localhost:3890"
      BASE_DN="${userConfig.LDAP_BASE_DN or "dc=example,dc=local"}"
      BIND_DN="cn=admin,ou=people,$BASE_DN"
      
      case "$1" in
        "search")
          ${pkgs.openldap}/bin/ldapsearch -x -H ldap://$LDAP_HOST -D "$BIND_DN" -W -b "$BASE_DN" "$2"
          ;;
        "add-user")
          echo "Adding user $2..."
          # This would typically integrate with LLDAP's API
          ${pkgs.curl}/bin/curl -X POST http://localhost:17170/api/users \
            -H "Content-Type: application/json" \
            -d "{\"user_id\": \"$2\", \"email\": \"$2@${userConfig.DOMAIN or "example.local"}\", \"display_name\": \"$2\"}"
          ;;
        *)
          echo "Usage: $0 {search|add-user} [args...]"
          echo "  search <filter>  - Search LDAP directory"
          echo "  add-user <name>  - Add a new user"
          ;;
      esac
    '';
  };
}