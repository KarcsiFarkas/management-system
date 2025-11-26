{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.paas.homepage-dashboard;
in
{
  options.services.paas.homepage-dashboard = {
    enable = mkEnableOption "Homepage Dashboard";
    port = mkOption { type = types.port; default = 8082; };
  };

  config = mkIf cfg.enable {
    services.homepage-dashboard = {
      enable = true;
      listenPort = cfg.port;
      openFirewall = true;
    };
  };
}
