{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.paas.authentik;
in
{
  options.services.paas.authentik = {
    enable = mkEnableOption "Authentik Identity Provider";
    port = mkOption { type = types.port; default = 9000; };
    domain = mkOption { type = types.str; default = "auth.localhost"; };
  };

  config = mkIf cfg.enable {
    # Authentik needs Redis and Postgres
    services.redis.servers.authentik = {
      enable = true;
      port = 6379;
    };

    services.postgresql = {
      enable = true;
      ensureDatabases = [ "authentik" ];
      ensureUsers = [{
        name = "authentik";
        ensureDBOwnership = true;
      }];
    };

    services.authentik = {
      enable = true;
      # The official module creates the user/group
      # It also handles the systemd service
      
      settings = {
        email = {
          host = "localhost";
          port = 25;
          use_tls = false;
          use_ssl = false;
          from = "authentik@localhost";
        };
        disable_startup_analytics = true;
        avatars = "gravatar";
      };

      # Environment file is required for secrets (Secret Key, DB password, etc.)
      # For this WSL setup, we will create a generated one if it doesn't exist
      # WARNING: In production, use sops-nix!
      environmentFile = "/var/lib/authentik/authentik-env";
    };

    # Create a default environment file if it doesn't exist
    systemd.services.authentik-setup-env = {
      description = "Generate Authentik Environment File";
      before = [ "authentik-server.service" "authentik-worker.service" ];
      requiredBy = [ "authentik-server.service" "authentik-worker.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script = ''
        mkdir -p /var/lib/authentik
        ENV_FILE="/var/lib/authentik/authentik-env"
        
        if [ ! -f "$ENV_FILE" ]; then
          echo "Generating Authentik environment file..."
          # Generate a random secret key
          SECRET_KEY=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 50)
          
          cat > "$ENV_FILE" <<EOF
        AUTHENTIK_SECRET_KEY=$SECRET_KEY
        AUTHENTIK_ERROR_REPORTING__ENABLED=false
        AUTHENTIK_POSTGRESQL__HOST=/run/postgresql
        AUTHENTIK_POSTGRESQL__NAME=authentik
        AUTHENTIK_POSTGRESQL__USER=authentik
        AUTHENTIK_POSTGRESQL__PASSWORD=
        AUTHENTIK_REDIS__HOST=127.0.0.1
        AUTHENTIK_REDIS__PORT=6379
        AUTHENTIK_REDIS__DB=0
        EOF
          chmod 600 "$ENV_FILE"
          chown authentik:authentik "$ENV_FILE"
        fi
      '';
    };

    # Open firewall ports
    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
