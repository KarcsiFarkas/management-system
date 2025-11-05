# nix-solution/modules/nixos/services/homer.nix
{ config, lib, pkgs, ... }:

with lib;
let
  # This 'cfg' refers to your custom options under services.paas.homer
  cfg = config.services.paas.homer;
in
{
  options.services.paas.homer = {
    enable = mkEnableOption "Homer static dashboard"; #
    port = mkOption { type = types.port; default = 8088; description = "Port Homer will listen on."; }; #
    configFile = mkOption { type = types.path; default = ./homer-default.yml; description = "Path to Homer's config.yml."; }; #
    # Add custom options if needed
  };

  # This config block uses the *official* services.homer options
  config = mkIf cfg.enable {
    # Enable the *official* Homer service
    services.homer = {
      enable = true;
      # === Configure Official Homer Options ===
      port = cfg.port; # Use the port from your options
      configFile = cfg.configFile; # Use the config file from your options
      # You can add more official options here if needed, like 'host'
      # host = "127.0.0.1"; # Example: Listen only on localhost if behind Traefik
    };

    # Firewall - The official module handles this if needed, but explicit is fine too.
    networking.firewall.allowedTCPPorts = [ cfg.port ]; #

    # Ensure the config file exists (optional, NixOS module might handle it)
    environment.etc."homer-config.yml" = { source = cfg.configFile; };
  };
}