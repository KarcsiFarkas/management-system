{ config, lib, pkgs, modulesPath, ... }:

with lib;
let
  cfg = config.services.paas.authelia;
in
{
  options.services.paas.authelia = {
    enable = mkEnableOption "Authelia SSO/2FA Server";
  };

  config = mkIf cfg.enable {
    # Import the real Authelia module
    imports = [ (modulesPath + "/services/security/authelia.nix") ];

    # Enable the real service
    services.authelia.enable = true;

    # === FIX: Changed services.redis.enable to new syntax ===
    services.redis.servers."".enable = true; # Authelia needs a session database
    networking.firewall.allowedTCPPorts = [ 9091 ]; # Default Authelia port

    users.users.authelia.extraGroups = [ config.services.traefik.group ];
  };
}

