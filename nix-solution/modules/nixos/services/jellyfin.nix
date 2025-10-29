{ config, lib, pkgs, ... }:
let cfg = config.services.jellyfin;
in
{
  config = lib.mkIf cfg.enable {
    users.groups.jellyfin = { };
    users.users.jellyfin = {
      isSystemUser = true;
      group = "jellyfin";
      extraGroups = lib.mkAfter [ "video" "render" ];
    };

    # Use hardware.opengl for NixOS 24.05
    hardware.opengl.enable = lib.mkDefault true;
    networking.firewall.allowedTCPPorts = lib.mkAfter [ 8096 8920 ];
  };
}
