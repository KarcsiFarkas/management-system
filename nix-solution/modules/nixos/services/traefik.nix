

# nix-solution/modules/nixos/services/traefik.nix
{ config, lib, pkgs, ... }:

with lib;
let
  # This 'cfg' refers to your custom options under services.paas.traefik
  cfg = config.services.paas.traefik;
in
{
  options.services.paas.traefik = {
    enable = mkEnableOption "Traefik reverse proxy"; #
    # Add any custom options *you* want here, e.g., domain, email
    # These are NOT official options, just for your wrapper's logic
    domain = mkOption { type = types.str; default = "wsl.local"; description = "Base domain for Traefik routing."; };
    acmeEmail = mkOption { type = types.nullOr types.str; default = null; description = "Email for Let's Encrypt."; };
  };

  # This config block uses the *official* services.traefik options
  config = mkIf cfg.enable {
    services.traefik = {
      enable = true; # Enable the actual Traefik service
      staticConfigOptions = {
        # === Official Entrypoints ===
        entryPoints = {
          web = {
            address = ":80"; #
            # Example: Redirect HTTP to HTTPS (uncomment if using TLS)
            # http.redirections.entryPoint = {
            #   to = "websecure";
            #   scheme = "https";
            # };
          };
          websecure = {
            address = ":443"; #
          };
          traefik-dash = { # Renamed for clarity
            address = ":8080"; #
          };
        };

        # === Official API & Dashboard ===
        api = {
          dashboard = true; #
          insecure = true; # Set to false and configure auth for security
        };

        # === Official Providers ===
        providers = {
          # Watch for dynamic config files
          file = {
            directory = "/etc/traefik/dynamic"; # Standard directory
            watch = true; #
          };
          docker = { # Example: Enable Docker provider if needed
            exposedByDefault = false; #
            # network = "traefik_net"; # If using Docker networking with NixOS
          };
        };

        # === Official Certificate Resolvers (Example for Let's Encrypt) ===
        # certificatesResolvers.letsencrypt = lib.mkIf (cfg.acmeEmail != null) {
        #   acme = {
        #     email = cfg.acmeEmail;
        #     storage = "/var/lib/traefik/acme/acme.json";
        #     httpChallenge.entryPoint = "web";
        #   };
        # };

        # === Official Logging ===
        log.level = "INFO"; # Or "DEBUG", "ERROR"

      };
      # === Generate Dynamic Config Files ===
      dynamicConfigOptions = {
        http.routers = lib.mkMerge [
          # --- Service Routers ---
          (lib.mkIf (isPaaSEnabled "nextcloud") {
            nextcloud = {
              rule = "Host(`${getPaaSDomain "nextcloud"}`)";
              service = "nextcloud";
              entryPoints = [ "web" "websecure" ];
            };
          })
          (lib.mkIf (isPaaSEnabled "vaultwarden") {
            vaultwarden = {
              rule = "Host(`${lib.strings.removePrefix "https://" (lib.strings.removePrefix "http://" (getPaaSDomain "vaultwarden"))}`)";
              service = "vaultwarden";
              entryPoints = [ "web" "websecure" ];
            };
          })
          (lib.mkIf (isPaaSEnabled "gitea") {
            gitea = {
              rule = "Host(`gitea.${baseDomain}`)";
              service = "gitea";
              entryPoints = [ "web" "websecure" ];
            };
          })
          (lib.mkIf config.services.jellyfin.enable {
            jellyfin = {
              rule = "Host(`jellyfin.${baseDomain}`)";
              service = "jellyfin";
              entryPoints = [ "web" "websecure" ];
            };
          })
          (lib.mkIf (isPaaSEnabled "homer") {
            homer = {
              rule = "Host(`homer.${baseDomain}`)";
              service = "homer";
              entryPoints = [ "web" "websecure" ];
            };
          })
          (lib.mkIf (isPaaSEnabled "immich") {
            immich = {
              rule = "Host(`immich.${baseDomain}`)";
              service = "immich";
              entryPoints = [ "web" "websecure" ];
            };
          })
          (lib.mkIf (isPaaSEnabled "navidrome") {
            navidrome = {
              rule = "Host(`navidrome.${baseDomain}`)";
              service = "navidrome";
              entryPoints = [ "web" "websecure" ];
            };
          })
          (lib.mkIf (isPaaSEnabled "authelia") {
            authelia = {
              rule = "Host(`authelia.${baseDomain}`)";
              service = "authelia";
              entryPoints = [ "web" "websecure" ];
            };
          })
          (lib.mkIf (isPaaSEnabled "vikunja") {
            vikunja = {
              rule = "Host(`vikunja.${baseDomain}`)";
              service = "vikunja";
              entryPoints = [ "web" "websecure" ];
            };
          })
          (lib.mkIf (isPaaSEnabled "firefly-iii") {
            firefly-iii = {
              rule = "Host(`firefly.${baseDomain}`)";
              service = "firefly-iii";
              entryPoints = [ "web" "websecure" ];
            };
          })
          (lib.mkIf (isPaaSEnabled "freshrss") {
            freshrss = {
              rule = "Host(`freshrss.${baseDomain}`)";
              service = "freshrss";
              entryPoints = [ "web" "websecure" ];
            };
          })
          (lib.mkIf (isPaaSEnabled "qbittorrent") {
            qbittorrent = {
              rule = "Host(`qbittorrent.${baseDomain}`)";
              service = "qbittorrent";
              entryPoints = [ "web" "websecure" ];
            };
          })
          (lib.mkIf (isPaaSEnabled "radarr") {
            radarr = {
              rule = "Host(`radarr.${baseDomain}`)";
              service = "radarr";
              entryPoints = [ "web" "websecure" ];
            };
          })
          (lib.mkIf (isPaaSEnabled "sonarr") {
            sonarr = {
              rule = "Host(`sonarr.${baseDomain}`)";
              service = "sonarr";
              entryPoints = [ "web" "websecure" ];
            };
          })
          (lib.mkIf (isPaaSEnabled "seafile") {
            seafile = {
              rule = "Host(`seafile.${baseDomain}`)";
              service = "seafile";
              entryPoints = [ "web" "websecure" ];
            };
          })
          # --- Traefik Dashboard Router ---
          (lib.mkIf config.services.traefik.staticConfigOptions.api.dashboard {
            dashboard = {
              rule = "Host(`traefik.${baseDomain}`)";
              service = "api@internal";
              entryPoints = [ "traefik" ];
            };
          })
        ];

        http.services = lib.mkMerge [
          # --- Service Definitions ---
          (lib.mkIf (isPaaSEnabled "nextcloud") {
            nextcloud.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString (getPaaSPort "nextcloud")}"; }];
          })
          (lib.mkIf (isPaaSEnabled "vaultwarden") {
            vaultwarden.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString (getPaaSPort "vaultwarden")}"; }];
          })
          (lib.mkIf (isPaaSEnabled "gitea") {
            gitea.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString config.services.gitea.settings.server.HTTP_PORT}"; }];
          })
          (lib.mkIf config.services.jellyfin.enable {
            jellyfin.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString config.services.jellyfin.port}"; }];
          })
          (lib.mkIf (isPaaSEnabled "homer") {
            homer.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString (getPaaSPort "homer")}"; }];
          })
          (lib.mkIf (isPaaSEnabled "immich") {
            immich.loadBalancer.servers = [{ url = "http://127.0.0.1:2283"; }];
          })
          (lib.mkIf (isPaaSEnabled "navidrome") {
            navidrome.loadBalancer.servers = [{ url = "http://127.0.0.1:4533"; }];
          })
          (lib.mkIf (isPaaSEnabled "authelia") {
            authelia.loadBalancer.servers = [{ url = "http://127.0.0.1:9091"; }];
          })
          (lib.mkIf (isPaaSEnabled "vikunja") {
            vikunja.loadBalancer.servers = [{ url = "http://127.0.0.1:3456"; }];
          })
          (lib.mkIf (isPaaSEnabled "firefly-iii") {
            firefly-iii.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString (getPaaSPort "firefly-iii")}"; }];
          })
          (lib.mkIf (isPaaSEnabled "freshrss") {
            freshrss.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString (getPaaSPort "freshrss")}"; }];
          })
          (lib.mkIf (isPaaSEnabled "qbittorrent") {
            qbittorrent.loadBalancer.servers = [{ url = "http://127.0.0.1:8080"; }];
          })
          (lib.mkIf (isPaaSEnabled "radarr") {
            radarr.loadBalancer.servers = [{ url = "http://127.0.0.1:7878"; }];
          })
          (lib.mkIf (isPaaSEnabled "sonarr") {
            sonarr.loadBalancer.servers = [{ url = "http://127.0.0.1:8989"; }];
          })
          (lib.mkIf (isPaaSEnabled "seafile") {
            seafile.loadBalancer.servers = [{ url = "http://127.0.0.1:8000"; }];
          })
        ];

        # Optional: Add middleware (e.g., for Authelia) later
        # http.middlewares = { ... };
      };
    };

    # Create the dynamic configuration directory
    systemd.tmpfiles.rules = [
      "d /etc/traefik/dynamic 0750 traefik traefik -"
      "d /var/lib/traefik/acme 0700 traefik traefik -" # For ACME storage
    ];

    # Open firewall ports
    networking.firewall.allowedTCPPorts = [ 80 443 8080 ];
  };
}
