# nix-solution/hosts/wsl/default.nix
{ config
, lib
, pkgs
, inputs
, hostname
, username
, modulesPath # <<< Add modulesPath here
, ... }:
let
  # --- Configuration ---
  baseDomain = "wsl.local"; # !!! CHANGE THIS to your desired domain !!!
in
{
  imports = [
    # --- Core WSL & Hardware Config ---
    inputs.nixos-wsl.nixosModules.wsl
    ./hardware-configuration.nix

    # --- Secrets Management ---
    inputs.sops-nix.nixosModules.sops
    ../../secrets # Assuming secrets config is in nix-solution/secrets/default.nix

    # --- Import Service Wrapper Modules ---
    ../../modules/nixos/services/authelia.nix
    ../../modules/nixos/services/firefly-iii.nix
    ../../modules/nixos/services/freshrss.nix
    ../../modules/nixos/services/gitea.nix
    # ../../modules/nixos/services/gitlab.nix
    ../../modules/nixos/services/homer.nix
    ../../modules/nixos/services/immich.nix
    # ../../modules/nixos/services/jellyfin.nix # Redundant
    ../../modules/nixos/services/navidrome.nix
    ../../modules/nixos/services/nextcloud.nix
    ../../modules/nixos/services/qbittorrent.nix
    ../../modules/nixos/services/radarr.nix
    ../../modules/nixos/services/seafile.nix
    ../../modules/nixos/services/sonarr.nix
    ../../modules/nixos/services/syncthing.nix
    ../../modules/nixos/services/traefik.nix
    ../../modules/nixos/services/vaultwarden.nix
    ../../modules/nixos/services/vikunja.nix

    # --- Conditionally Import OFFICIAL Modules Based on Wrappers ---
#    (lib.mkIf config.services.paas.authelia.enable (modulesPath + "/services/security/authelia.nix")) # Official Module
  ];

  # --- WSL integration ---
  wsl.enable = true;
  wsl.graphics = false; # Fix

  # --- Bootloader (WSL specific) ---
  boot.isContainer = true;
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  swapDevices = [ ];

  # --- Host basics ---
  networking.hostName = hostname;
  networking.domain = baseDomain; # Set domain globally
  time.timeZone = "Europe/Budapest";

  # --- User definition ---
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ]; # Add groups needed
    home = "/home/${username}";
  };

  # --- Systemd, DBus ---
  services.dbus.enable = true;

  # --- Nix Settings ---
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    warn-dirty = false;
  };
  documentation.enable = false;

  # === SOPS Configuration (adjust paths and keys as needed) ===
  sops.age.keyFile = "/etc/sops/age/keys.txt"; # Or ~/.config/sops/age/keys.txt
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ]; # Example
  # sops.gnupg.home = "/path/to/.gnupg"; # If using GPG

  sops.secrets."authelia/jwt_secret" = { mode = "0440"; group = config.services.authelia.group; };
  sops.secrets."authelia/session_secret" = { mode = "0440"; group = config.services.authelia.group; };
  sops.secrets."authelia/storage_key" = { mode = "0440"; group = config.services.authelia.group; };
  sops.secrets."authelia/ldap_password" = { mode = "0440"; group = config.services.authelia.group; };
  # Add other secrets here (e.g., database passwords if needed by modules)
  # sops.secrets."nextcloud/admin_password" = { mode = "0440"; group = config.services.nextcloud.group; };

  # === Enable Core Dependencies ===
  services.postgresql.enable = true; # For Gitea, Nextcloud, Immich, Vikunja, Firefly, Freshrss
  services.redis.servers."".enable = true; # For Authelia
  services.phpfpm.pools.nextcloud.enable = true; # For Nextcloud (Assuming Nextcloud pool name)
  services.phpfpm.pools.freshrss.enable = true; # For Freshrss
  services.phpfpm.pools."firefly-iii".enable = true; # For Firefly III
  services.nginx.enable = true; # For Nextcloud, Freshrss, Firefly-iii proxies
  # services.mariadb.enable = true; # For Seafile (Uncomment if using Seafile)

  # === Configure Jellyfin Directly ===
  services.jellyfin = {
    enable = true;
    openFirewall = true; # Opens 8096 TCP
  };

  # === Enable PaaS Services via Wrappers ===
  services.paas.traefik = {
    enable = true;
    domain = baseDomain;
    # acmeEmail = "your-email@example.com"; # Optional: for Let's Encrypt
  };

  services.paas.authelia = {
    enable = true;
    domain = "auth.${baseDomain}";
    sessionDomain = baseDomain;
    # Pass secret paths managed by sops-nix
    jwtSecretFile = config.sops.secrets."authelia/jwt_secret".path;
    sessionSecretFile = config.sops.secrets."authelia/session_secret".path;
    storageEncryptionKeyFile = config.sops.secrets."authelia/storage_key".path;
    ldapPasswordFile = config.sops.secrets."authelia/ldap_password".path;
  };

  services.paas.homer = {
    enable = true;
    port = 8088; # Keep default or change
  };

  services.paas.immich = { enable = true; };
  services.paas.navidrome = { enable = true; };

  services.paas.nextcloud = {
    enable = true;
    domain = "nextcloud.${baseDomain}";
    port = 9001; # Custom internal port
    # adminPassFile = config.sops.secrets."nextcloud/admin_password".path; # Example secret
  };

  services.paas.qbittorrent = { enable = true; };
  services.paas.radarr = { enable = true; };
  services.paas.sonarr = { enable = true; };
  services.paas.syncthing = { user = username; }; # Enable for the main user

  services.paas.vaultwarden = {
    enable = true;
    domain = "https://vaultwarden.${baseDomain}"; # Must include https://
    port = 8222; # Custom internal port
  };
  services.paas.firefly-iii = { enable = true; port = 8084; };
  services.paas.freshrss = { enable = true; port = 8083; };
  services.paas.gitea = { enable = true; };
  # services.paas.seafile = { enable = true; domain = "seafile.${baseDomain}"; }; # Uncomment if using MariaDB and Seafile
  services.paas.vikunja = { enable = true; };


  # === Generate Traefik Dynamic Config Based on Enabled Services ===
  services.traefik.dynamicConfigOptions = {
    http = {
      routers = lib.mkMerge [
        # --- Service Routers ---
        (lib.mkIf config.services.paas.authelia.enable {
          authelia = {
            rule = "Host(`${config.services.paas.authelia.domain}`)";
            service = "authelia";
            entryPoints = [ "web" "websecure" ]; # Add TLS later
          };
        })
        (lib.mkIf config.services.paas.homer.enable {
          homer = {
            rule = "Host(`dashboard.${baseDomain}`)"; # Or just Host(`${baseDomain}`)
            service = "homer";
            entryPoints = [ "web" "websecure" ];
          };
        })
        (lib.mkIf config.services.paas.immich.enable {
          immich = {
            rule = "Host(`immich.${baseDomain}`)";
            service = "immich";
            entryPoints = [ "web" "websecure" ];
          };
        })
        (lib.mkIf config.services.jellyfin.enable { # Direct check
          jellyfin = {
            rule = "Host(`jellyfin.${baseDomain}`)";
            service = "jellyfin";
            entryPoints = [ "web" "websecure" ];
          };
        })
        (lib.mkIf config.services.paas.navidrome.enable {
          navidrome = {
            rule = "Host(`navidrome.${baseDomain}`)";
            service = "navidrome";
            entryPoints = [ "web" "websecure" ];
          };
        })
        (lib.mkIf config.services.paas.nextcloud.enable {
          nextcloud = {
            rule = "Host(`${config.services.paas.nextcloud.domain}`)";
            service = "nextcloud";
            entryPoints = [ "web" "websecure" ];
            # middlewares = [ "authelia" ]; # Reference middleware by name
          };
        })
        (lib.mkIf config.services.paas.qbittorrent.enable {
          qbittorrent = {
            rule = "Host(`qbittorrent.${baseDomain}`)";
            service = "qbittorrent";
            entryPoints = [ "web" "websecure" ];
          };
        })
        (lib.mkIf config.services.paas.radarr.enable {
          radarr = {
            rule = "Host(`radarr.${baseDomain}`)";
            service = "radarr";
            entryPoints = [ "web" "websecure" ];
          };
        })
        # (lib.mkIf config.services.paas.seafile.enable { ... })
        (lib.mkIf config.services.paas.sonarr.enable {
          sonarr = {
            rule = "Host(`sonarr.${baseDomain}`)";
            service = "sonarr";
            entryPoints = [ "web" "websecure" ];
          };
        })
        (lib.mkIf config.services.paas.syncthing.user != null { # Check if syncthing is enabled for *a* user
          syncthing = {
            rule = "Host(`syncthing.${baseDomain}`)";
            service = "syncthing";
            entryPoints = [ "web" "websecure" ];
          };
        })
        (lib.mkIf config.services.paas.vaultwarden.enable {
          vaultwarden = {
            rule = "Host(`${lib.strings.removePrefix "https://" config.services.paas.vaultwarden.domain}`)";
            service = "vaultwarden";
            entryPoints = [ "web" "websecure" ];
          };
        })
        (lib.mkIf config.services.paas.firefly-iii.enable {
          firefly-iii = {
            rule = "Host(`firefly.${baseDomain}`)";
            service = "firefly-iii";
            entryPoints = [ "web" "websecure" ];
          };
        })
        (lib.mkIf config.services.paas.freshrss.enable {
          freshrss = {
            rule = "Host(`freshrss.${baseDomain}`)";
            service = "freshrss";
            entryPoints = [ "web" "websecure" ];
          };
        })
        (lib.mkIf config.services.paas.gitea.enable {
          gitea = {
            rule = "Host(`gitea.${baseDomain}`)";
            service = "gitea";
            entryPoints = [ "web" "websecure" ];
          };
        })
        (lib.mkIf config.services.paas.vikunja.enable {
          vikunja = {
            rule = "Host(`vikunja.${baseDomain}`)";
            service = "vikunja";
            entryPoints = [ "web" "websecure" ];
          };
        })

        # --- Traefik Dashboard Router ---
         (lib.mkIf config.services.traefik.staticConfigOptions.api.dashboard {
           dashboard = {
             rule = "Host(`traefik.${baseDomain}`)";
             service = "api@internal";
             entryPoints = [ "traefik-dash" ]; # Use dedicated port
             # middlewares = [ "auth" ]; # Example BasicAuth middleware name
           };
         })
      ]; # End routers

      services = lib.mkMerge [
        # --- Service Definitions ---
        (lib.mkIf config.services.paas.authelia.enable {
          authelia.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString config.services.authelia.settings.server.port}"; }];
        })
        (lib.mkIf config.services.paas.homer.enable {
          homer.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString config.services.homer.port}"; }];
        })
        (lib.mkIf config.services.paas.immich.enable {
          # Corrected: Need to get port from official immich module options if paas wrapper doesn't define it
          immich.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString config.services.immich.port}"; }]; # Assumes official module has 'port'
        })
        (lib.mkIf config.services.jellyfin.enable {
          jellyfin.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString config.services.jellyfin.port}"; }];
        })
        (lib.mkIf config.services.paas.navidrome.enable {
          navidrome.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString config.services.navidrome.settings.Port}"; }];
        })
        (lib.mkIf config.services.paas.nextcloud.enable {
          nextcloud.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString config.services.paas.nextcloud.port}"; }];
        })
         (lib.mkIf config.services.paas.qbittorrent.enable {
           qbittorrent.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString config.services.qbittorrent.webuiPort}"; }];
         })
         (lib.mkIf config.services.paas.radarr.enable {
           radarr.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString config.services.radarr.port}"; }];
         })
        # (lib.mkIf config.services.paas.seafile.enable { ... })
         (lib.mkIf config.services.paas.sonarr.enable {
           sonarr.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString config.services.sonarr.port}"; }];
         })
         (lib.mkIf config.services.paas.syncthing.user != null {
           syncthing.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString config.services.syncthing.guiAddressPort}"; }];
         })
        (lib.mkIf config.services.paas.vaultwarden.enable {
          vaultwarden.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}"; }];
        })
        (lib.mkIf config.services.paas.firefly-iii.enable {
           firefly-iii.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString config.services.paas.firefly-iii.port}"; }];
         })
         (lib.mkIf config.services.paas.freshrss.enable {
           freshrss.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString config.services.paas.freshrss.port}"; }];
         })
         (lib.mkIf config.services.paas.gitea.enable {
           gitea.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString config.services.gitea.settings.http.port}"; }];
         })
         (lib.mkIf config.services.paas.vikunja.enable {
           vikunja.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString config.services.vikunja.port}"; }];
         })
      ]; # End services

      middlewares = lib.mkMerge [
        # --- Authelia Middleware ---
        (lib.mkIf config.services.paas.authelia.enable {
          authelia = { # Define the middleware named 'authelia'
            forwardAuth = {
              address = "http://127.0.0.1:${toString config.services.authelia.settings.server.port}/api/verify?rd=https://${config.services.paas.authelia.domain}";
              trustForwardHeader = true;
              authResponseHeaders = [ "Remote-User" "Remote-Groups" "Remote-Name" "Remote-Email" ];
            };
          };
        })
        # --- Basic Auth for Traefik Dashboard (Example) ---
        # (lib.mkIf config.services.traefik.staticConfigOptions.api.dashboard {
        #   auth = { # Define the middleware named 'auth'
        #     basicAuth.usersFile = config.sops.secrets."traefik/dashboard_auth".path;
        #   };
        # })
      ]; # End middlewares

    }; # End http
  }; # End dynamicConfigOptions

  # --- Firewall ---
  networking.firewall.enable = true;

  # --- State Version ---
  system.stateVersion = "25.05";
}