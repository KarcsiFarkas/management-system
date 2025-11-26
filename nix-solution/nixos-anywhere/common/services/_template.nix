# Template for adding new PaaS services
# Copy this file to 'service-name.nix' and replace 'myservice' with your service name.

{ config, lib, pkgs, ... }:

with lib;
let
  # REPLACE 'myservice' with your service name
  cfg = config.services.paas.myservice;
in
{
  options.services.paas.myservice = {
    enable = mkEnableOption "My Service Description";

    port = mkOption {
      type = types.port;
      default = 1234; # REPLACE with default port
      description = "Internal port that the service listens on";
    };

    domain = mkOption {
      type = types.str;
      default = "myservice.localhost"; # Default domain (often overridden by host config)
      description = "Public domain for the service";
    };

    # Add extra custom options here if needed (e.g. dataDir, user, etc.)
  };

  config = mkIf cfg.enable {
    # ==========================================================================
    # OPTION 1: Native NixOS Service (Preferred)
    # Use this if an upstream module exists in Nixpkgs
    # ==========================================================================
    /*
    services.myservice = {
      enable = true;
      port = cfg.port;
      # dataDir = "/var/lib/myservice";
    };
    */

    # ==========================================================================
    # OPTION 2: Docker/OCI Container
    # Use this if no native module exists or you need a specific version
    # ==========================================================================
    /*
    virtualisation.oci-containers.containers.myservice = {
      image = "myservice/image:latest";
      ports = [ "127.0.0.1:${toString cfg.port}:80" ]; # Expose only to localhost for Traefik
      volumes = [
        "/var/lib/myservice/data:/data"
        "/var/lib/myservice/config:/config"
      ];
      environment = {
        TZ = config.time.timeZone;
      };
    };
    
    # Ensure data directories exist
    systemd.tmpfiles.rules = [
      "d /var/lib/myservice/data 0750 root root -"
      "d /var/lib/myservice/config 0750 root root -"
    ];
    */

    # ==========================================================================
    # Common Configuration (Firewall, Backups, etc.)
    # ==========================================================================

    # Open Firewall Port
    # Only needed if you want direct access (bypassing Traefik) or for LAN discovery.
    # If using Traefik reverse proxy, keep this commented out or restricted to localhost.
    # networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
