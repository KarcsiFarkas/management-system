{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.paas.sonarr;
in
{
  options.services.paas.sonarr = {
    enable = mkEnableOption "Sonarr (TV Show Manager)";
  };

  config = mkIf cfg.enable {
    services.sonarr = {
      enable = true;
      openFirewall = true; # Opens default port 8989
    };
  };
}

