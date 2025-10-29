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

  config = mkIf cfg.enable {
    services.nginx.enable = true;

    services.nginx.virtualHosts."_" = {
      listen = [{ port = cfg.port; }];
      root = "${pkgs.homer}/share/homer";

      locations."/assets/config.yml" = {
        alias = cfg.configFile;
        extraConfig = ''
          add_header Cache-Control "no-store"; # Don't cache config
        '';
      };
    };

    # This module needs its default config file
    # Place homer-default.yml in the same directory
    environment.etc."homer-default.yml" = {
      source = ./homer-default.yml;
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
    environment.systemPackages = [ pkgs.homer ];
  };
}

