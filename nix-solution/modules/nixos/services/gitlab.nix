{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.paas.gitlab;
in
{
  options.services.paas.gitlab = {
    enable = mkEnableOption "GitLab (Code Platform)";
    port = mkOption { type = types.port; default = 8082; };
    domain = mkOption { type = types.str; default = "gitlab.example.com"; };
  };

  config = mkIf cfg.enable {
    warnings = [ "GitLab is extremely resource-intensive and may not run well in WSL." ];

    services.postgresql.enable = true;
    services.redis.enable = true;

    services.gitlab = {
      enable = true;
      host = cfg.domain; # Must set this
      port = cfg.port;
      # Uses postgresql and redis by default if they are enabled
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}

