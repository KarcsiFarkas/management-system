# nix-solution/modules/nixos/services/jellyfin.nix
#
# Custom PaaS wrapper for the official NixOS Jellyfin service module.
# Jellyfin is a free software media system for managing and streaming media.
#
# Upstream module: nixos/modules/services/misc/jellyfin.nix
# Documentation: https://jellyfin.org/docs/
#
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.paas.jellyfin;
in
{
  options.services.paas.jellyfin = {
    enable = mkEnableOption "Jellyfin media server";

    port = mkOption {
      type = types.port;
      default = 8096;
      description = lib.mdDoc ''
        Port that Jellyfin web interface will listen on.
      '';
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/jellyfin";
      description = lib.mdDoc ''
        Directory where Jellyfin stores its data.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = lib.mdDoc ''
        Whether to open firewall ports for Jellyfin.
        Opens port 8096 (web interface) and 8920 (HTTPS).
      '';
    };
  };

  config = mkIf cfg.enable {
    # Enable the official Jellyfin service
    services.jellyfin = {
      enable = true;
      dataDir = cfg.dataDir;
      openFirewall = cfg.openFirewall;
    };

    # Enable hardware acceleration support
    # Use hardware.opengl for NixOS 24.05, hardware.graphics for 24.11+
    hardware.opengl.enable = mkDefault true;

    # Ensure Jellyfin user has access to hardware acceleration
    users.users.jellyfin = {
      extraGroups = mkAfter [ "video" "render" ];
    };

    # Open firewall ports if requested
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [
      cfg.port  # Web interface
      8920      # HTTPS
    ];
  };
}
