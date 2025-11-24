{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.paas.seafile;
in
{
  options.services.paas.seafile = {
    enable = mkEnableOption "Seafile (File Sync)";
    domain = mkOption { type = types.str; default = "seafile.example.com"; };
  };

  config = mkIf cfg.enable {
    # Seafile needs MariaDB (MySQL)
    services.mariadb.enable = true;

    services.seafile = {
      enable = true;
      seafile.domain = cfg.domain;
      # Seafile module will configure nginx and create databases
    };

    networking.firewall.allowedTCPPorts = [ 80 443 8000 8082 ]; # Default Seafile ports
  };
}

