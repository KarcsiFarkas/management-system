{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.paas.qbittorrent;
in
{
  options.services.paas.qbittorrent = {
    enable = mkEnableOption "qBittorrent (Web UI)";
  };

  config = mkIf cfg.enable {
    services.qbittorrent = {
      enable = true;
      webuiPort = 8081; # Default is 8080, but that conflicts with Traefik dashboard
      openFirewall = true;
    };
    # Port is already opened by openFirewall = true
  };
}

