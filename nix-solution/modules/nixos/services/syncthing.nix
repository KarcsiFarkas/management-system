{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.paas.syncthing;
in
{
  options.services.paas.syncthing = {
    user = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "User to run Syncthing for.";
    };
  };

  config = mkIf (cfg.user != null) {
    # This configures Syncthing for a specific user, not as a system service
    services.syncthing = {
      enable = true;
      user = cfg.user;
      dataDir = "/home/${cfg.user}/.local/share/syncthing";
      configDir = "/home/${cfg.user}/.config/syncthing";
      guiAddress = "0.0.0.0:8384"; # Listen on all interfaces
    };

    networking.firewall.allowedTCPPorts = [ 8384 22000 ];
    networking.firewall.allowedUDPPorts = [ 21027 ];
  };
}

