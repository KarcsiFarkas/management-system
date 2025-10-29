# nix-solution/modules/nixos/services/homer.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.homer-dashboard; # Use a different namespace to avoid conflict if a real module exists
in
{
  # Define options for customization
  options.services.homer-dashboard = {
    enable = mkEnableOption "Homer static dashboard served via Nginx";

    port = mkOption {
      type = types.port;
      default = 8088; # Choose a default port for Homer
      description = "Port Nginx listens on for Homer.";
    };

    hostName = mkOption {
      type = types.str;
      default = "_"; # Listen on all hostnames by default
      description = "Hostname Nginx uses for the Homer virtual host.";
    };

    # Option to specify the configuration file content directly or via path
    configFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to Homer's config.yml file.
        If null, a default config pointing to /var/lib/homer/assets will be used.
        The content of this file will be copied to /var/lib/homer/assets/config.yml.
      '';
    };
  };

  # Configure Nginx when Homer is enabled
  config = mkIf cfg.enable {

    # Ensure nginx is enabled
    services.nginx.enable = true;

    # Define the virtual host for Homer
    services.nginx.virtualHosts.${cfg.hostName} = {
      listen = [{ port = cfg.port; }];
      root = "${pkgs.homer}/share/homer"; # Serve static files from the package

      # Ensure config.yml can be served
      locations."/assets/config.yml" = {
        alias = "/var/lib/homer/assets/config.yml";
        # Add headers to prevent caching if needed
        extraConfig = ''
          add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0";
          expires off;
          pragma no-cache;
        '';
      };

      # Optional: Add basic auth or other security via extraConfig if needed
    };

    # Prepare the config directory and file
    systemd.tmpfiles.rules = [
      "d /var/lib/homer/assets 0755 root root -"
      # Use a link or copy depending on whether configFile is set
      "L+ /var/lib/homer/assets/config.yml - - - - ${if cfg.configFile != null then cfg.configFile else "/etc/homer-default-config.yml"}"
    ];

    # Create a default config file if none is provided
    # Note: This is a basic example; you'll want to customize this.
    environment.etc."homer-default-config.yml" = lib.mkIf (cfg.configFile == null) {
      text = ''
        ---
        # Homepage configuration
        # See https://fontawesome.com/v5/search for icons options

        title: "Homer Dashboard"
        subtitle: "NixOS"
        # documentTitle: "Welcome" # Customize the browser tab title

        # Optional theme customization
        theme: default # 'default' or one of the themes available in '/assets/themes/'

        # Optional custom background
        # background: https://example.com/background.jpg

        # Optional message
        message:
          # url: https://b4bz.io
          # style: "is-dark" # Available styles: is-primary, is-link, is-info, is-success, is-warning, is-danger, is-white, is-light, is-dark, is-black, is-text
          title: "Welcome!"
          # content: ""

        # Optional navbar
        # Supports external links, internal links, icons, targets, and badges
        navbar:
          - name: "NixOS"
            icon: "fab fa-nixos" # Assuming Font Awesome class; adjust if needed
            url: "https://nixos.org"

        # Services configuration example
        services:
          - name: "Applications"
            icon: "fas fa-cloud"
            items:
              - name: "Jellyfin"
                icon: "fas fa-film"
                # Assuming Jellyfin is running on 8096
                url: "http://${config.networking.hostName}:8096"
              - name: "Vaultwarden"
                icon: "fas fa-shield-alt"
                # Assuming Vaultwarden is exposed via Traefik at vault.yourdomain
                url: "http://${config.networking.hostName}:8222" # Adjust if behind Traefik
              # Add other services here
      '';
    };
    # Point configFile to the default if none provided
    # Needs to happen at evaluation time, tmpfiles rule handles runtime linking/copying.
    # We actually let the systemd-tmpfiles rule use the default path directly if cfg.configFile is null.

    # Open the firewall port for Homer
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    # Install the Homer package (for the static assets)
    environment.systemPackages = [ pkgs.homer ];

  };
}
