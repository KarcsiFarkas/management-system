{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.paas.authentik;
in
{
  options.services.paas.authentik = {
    enable = mkEnableOption "Authentik Identity Provider";
    port = mkOption { type = types.port; default = 9000; };
    domain = mkOption { type = types.str; default = "auth.localhost"; };
  };

  config = mkIf cfg.enable {
    # FIXME: Authentik is not available as a native NixOS service
    # This module is currently disabled until we implement a Docker-based solution
    # or Authentik is added to nixpkgs with a proper service module

    # NOTE: For now, users should deploy Authentik via Docker Compose
    # See: management-system/docker-compose-solution/authelia/ for SSO alternative

    # Placeholder warning
    warnings = [
      "services.paas.authentik is not fully implemented yet. Use Docker Compose for Authentik deployment."
    ];

    # FUTURE IMPLEMENTATION: Docker-based Authentik deployment
    # virtualisation.docker.enable = true;
    # systemd.services.authentik-docker = {
    #   description = "Authentik Identity Provider (Docker)";
    #   after = [ "docker.service" ];
    #   requires = [ "docker.service" ];
    #   wantedBy = [ "multi-user.target" ];
    #   serviceConfig = {
    #     Type = "oneshot";
    #     RemainAfterExit = true;
    #   };
    #   script = ''
    #     ${pkgs.docker-compose}/bin/docker-compose -f /etc/authentik/docker-compose.yml up -d
    #   '';
    # };

    # Open firewall ports
    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
