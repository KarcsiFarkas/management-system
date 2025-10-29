{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.paas.homer;
in
{
  options.services.paas.homer = {
    enable = mkEnableOption "Homer static dashboard";
    port = mkOption { type = types.port; default = 8088; };
    configFile = mkOption { type = types.path; default = ./homer-default.yml; };
  };

  # Create a default config file next to this module
  environment.etc."homer-default.yml" = {
    source = ./homer-default.yml; # Assumes homer-default.yml is in the same directory
  };

  config = mkIf cfg.enable {
    # Enable Nginx to serve the static files
    services.nginx.enable = true;

    services.nginx.virtualHosts."_" = {
      listen = [{ port = cfg.port; }];
      # === FIX: Changed pkgs.homer-dashboard to pkgs.homer ===
      root = "${pkgs.homer}/share/homer";

      locations."/assets/config.yml" = {
        alias = cfg.configFile;
        extraConfig = ''
          add_header Cache-Control "no-store"; # Don't cache config
        '';
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
    # === FIX: Changed pkgs.homer-dashboard to pkgs.homer ===
    environment.systemPackages = [ pkgs.homer ];
  };
}

