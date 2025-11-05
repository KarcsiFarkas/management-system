# nix-solution/modules/nixos/services/authelia.nix
{ config, lib, pkgs, modulesPath, ... }:

with lib;
let
  cfg = config.services.paas.authelia;
in
{
  options.services.paas.authelia = {
    enable = mkEnableOption "Authelia SSO/2FA Server";
    domain = mkOption { type = types.str; default = "auth.wsl.local"; };
    sessionDomain = mkOption { type = types.str; default = "wsl.local"; };
    # Define paths for secrets
    jwtSecretFile = mkOption { type = types.path; description = "Path to JWT secret file"; };
    sessionSecretFile = mkOption { type = types.path; description = "Path to session secret file"; };
    storageEncryptionKeyFile = mkOption { type = types.path; description = "Path to storage encryption key file"; };
    ldapPasswordFile = mkOption { type = types.path; description = "Path to LDAP bind password file"; };
  };

  # Config block evaluated *if* services.paas.authelia.enable = true;
  config = mkIf cfg.enable {
    # *** NO imports = [ ... ]; line here ***

    # === Configure Official Authelia Options ===
    services.authelia = {
      enable = true; # Enable the actual service
      settings = {
        server = { host = "0.0.0.0"; port = 9091; };
        log.level = "info";
        jwt_secret_file = cfg.jwtSecretFile;
        default_redirection_url = "https://${cfg.sessionDomain}";
        totp.issuer = "MyPaaS";
        authentication_backend.ldap = {
          url = "ldap://localhost:3890"; # Assuming LLDAP
          base_dn = "dc=example,dc=local"; # Adjust
          username_attribute = "uid";
          additional_users_dn = "ou=people";
          users_filter = "(&({username_attribute}={input})(objectClass=person))";
          user = "cn=admin,ou=people,dc=example,dc=local"; # Adjust
          password_file = cfg.ldapPasswordFile;
        };
        access_control = {
          default_policy = "deny";
          rules = [
            { domain = cfg.domain; policy = "bypass"; }
            { domain = "*.${cfg.sessionDomain}"; policy = "one_factor"; }
          ];
        };
        session = {
          name = "authelia_session";
          domain = cfg.sessionDomain;
          secret_file = cfg.sessionSecretFile;
          expiration = "1h";
          inactivity = "5m";
        };
        storage = {
          encryption_key_file = cfg.storageEncryptionKeyFile;
          local.path = "/var/lib/authelia/db.sqlite3";
        };
        notifier.filesystem.filename = "/var/lib/authelia/notification.txt";
      };
      # user = "authelia"; # Use default user/group unless needed
      # group = "authelia";
    };

    # === Dependencies & Setup ===
    services.redis.servers."".enable = true;
    systemd.tmpfiles.rules = [ "d /var/lib/authelia 0750 authelia authelia -" ];
    networking.firewall.allowedTCPPorts = [ 9091 ];
    # Ensure authelia user exists for tmpfiles rule (official module does this)
    users.users.authelia = {
       isSystemUser = true;
       group = "authelia";
    };
    users.groups.authelia = {};
    # Add authelia user to traefik group if traefik is enabled
    users.users.authelia.extraGroups = lib.mkIf config.services.traefik.enable [ config.services.traefik.group ];
  };
}