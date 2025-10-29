{ config, lib, pkgs, modulesPath, ... }: # <-- 'modulesPath' is required here

with lib;
let
  cfg = config.services.paas.authelia; # This is the user-facing option
in
{
  # 1. Define the user-facing option
  options.services.paas.authelia = {
    enable = mkEnableOption "Authelia SSO/2FA Server";
    # You can add more options here later for settings, secrets, etc.
  };

  # 2. Configure the system if the option is enabled
  config = mkIf cfg.enable {

    # === THIS IS THE FIX ===
    # Import the actual NixOS module for Authelia.
    # This makes `services.authelia.enable` and other options available.
    imports = [
      (modulesPath + "/services/security/authelia.nix") # <-- Use 'modulesPath' directly
    ];
    # =======================

    # Now we can safely enable and configure the real service
    services.authelia.enable = true;

    # Enable Redis, a common dependency for Authelia sessions
    services.redis.enable = true;

    # Open default Authelia port
    networking.firewall.allowedTCPPorts = [ 9091 ];

    # Add authelia user to traefik group so Traefik can read secrets
    # (This assumes traefik is enabled on the same host)
    users.users.authelia.extraGroups = [ config.services.traefik.group ];

    # Create directories
    systemd.tmpfiles.rules = [
      "d /var/lib/authelia 0750 authelia authelia -"
    ];

    # Note: All specific 'services.authelia.settings' and 'environment.etc'
    # are correctly defined in your 'hosts/wsl/default.nix' file.
  };
}

