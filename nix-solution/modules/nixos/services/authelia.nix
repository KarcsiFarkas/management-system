# nix-solution/modules/nixos/services/authelia.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.authelia-main; # Using a custom namespace for clarity
in
{
  options.services.authelia-main = {
    enable = mkEnableOption "Authelia SSO/2FA Server";

    settings = mkOption {
      type = types.attrs;
      default = {};
      description = "Authelia configuration settings attribute set. See https://www.authelia.com/configuration/ for details.";
      example = literalExpression ''
        {
          jwt_secret = "/run/secrets/authelia_jwt_secret";
          session = {
            secret = "/run/secrets/authelia_session_secret";
            redis = {
              host = "localhost"; # Assuming Redis is running locally
              port = 6379;
            };
          };
          authentication_backend = {
            file = {
              path = "/var/lib/authelia/users_database.yml";
              password = {
                algorithm = "argon2id";
                # ... other password settings
              };
            };
            # OR LDAP config if using LLDAP
            # ldap = { ... };
          };
          notifier = {
            # Optional SMTP settings for password resets etc.
            # smtp = { ... };
          };
          # Define access control rules, default policy, etc.
          access_control = {
            default_policy = "deny";
            rules = [
              # Allow access for specific domains/users
              { domain = [ "*.your.domain" ]; policy = "two_factor"; }
            ];
          };
        }
      '';
    };

    secrets = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Attribute set mapping secret names (e.g., 'authelia_jwt_secret') to their plain text values. Used with sops-nix.";
      example = literalExpression ''
        {
          authelia_jwt_secret = "your-long-random-jwt-secret";
          authelia_session_secret = "your-long-random-session-secret";
          # authelia_ldap_password = "your-ldap-bind-password";
        }
      '';
    };

    usersFileContent = mkOption {
      type = types.nullOr types.lines;
      default = null;
      description = "Content for the file-based user database (/var/lib/authelia/users_database.yml).";
      example = ''
        users:
          testuser:
            displayname: "Test User"
            # Generate hash using: authelia hash-password 'yourpassword'
            password: "$argon2id$v=19$m=65536,t=3,p=4$yourHasheDsaLt$yoUrH4sH"
            email: test.user@example.com
            groups:
              - admins
              - dev
      '';
    };
  };

  config = mkIf cfg.enable {

    # === Authelia Service Configuration ===
    services.authelia.instances.main = {
      enable = true;
      # Pass the settings directly from the module option
      settings = cfg.settings;
    };

    # === Secrets Management via sops-nix ===
    # Define the secrets needed by Authelia
    sops.secrets = builtins.mapAttrs
      (name: value: {
        # Path where the secret file will be created
        path = "/run/secrets/${name}";
        # Ensure Authelia can read it
        owner = config.services.authelia.instances.main.user;
        group = config.services.authelia.instances.main.group;
        mode = "0440";
      })
      cfg.secrets; # Use the secrets defined in the module option

    # === Users Database File ===
    environment.etc."authelia/users_database.yml" = lib.mkIf (cfg.usersFileContent != null) {
      text = cfg.usersFileContent;
      mode = "0440";
      user = config.services.authelia.instances.main.user;
      group = config.services.authelia.instances.main.group;
    };

    # Ensure the config links the generated users file if file auth is used
    # This might require adjusting the cfg.settings example/usage slightly
    # E.g., ensure settings.authentication_backend.file.path points to /etc/authelia/users_database.yml

    # === Required Dependencies (Example: Redis for sessions) ===
    # Enable Redis if it's configured in settings.session.redis
    services.redis.servers."".enable = lib.mkIf (cfg.settings ? "session" && cfg.settings.session ? "redis") true;

    # === Data Directory ===
    systemd.tmpfiles.rules = [
      # Authelia's state dir (includes file DB if path is relative)
      "d /var/lib/authelia-main 0750 ${config.services.authelia.instances.main.user} ${config.services.authelia.instances.main.group} -"
    ];

    # === Firewall ===
    networking.firewall.allowedTCPPorts = [
      # Default Authelia port
      (cfg.settings.server.port or 9091)
    ];

  };
}
