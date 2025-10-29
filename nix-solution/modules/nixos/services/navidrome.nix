{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.paas.navidrome;
in
{
  options.services.paas.navidrome = {
    enable = mkEnableOption "Navidrome (Music Server)";
  };

  config = mkIf cfg.enable {
    services.navidrome = {
      enable = true;
      settings = {
        MusicFolder = "/var/lib/navidrome/music"; # Example path
        ScanSchedule = "1h";
        Port = 4533; # Default port
      };
    };

    # Create the music folder
    systemd.tmpfiles.rules = [
      "d /var/lib/navidrome/music 0755 navidrome navidrome -"
    ];

    networking.firewall.allowedTCPPorts = [ 4533 ];
  };
}

