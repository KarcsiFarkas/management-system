{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.paas.radarr;
in
{
  options.services.paas.radarr = {
    enable = mkEnableOption "Radarr (Movie Manager)";
  };

  config = mkIf cfg.enable {
    services.radarr = {
      enable = true;
      openFirewall = true; # Opens default port 7878
    };
  };
}

