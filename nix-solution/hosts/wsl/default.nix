{ config
, lib
, pkgs
, inputs
, hostname
, username
, ... }:

{
  imports = [
    # --- Core WSL & Hardware Config ---
    inputs.nixos-wsl.nixosModules.wsl
    ./hardware-configuration.nix

    # --- Import ALL Service Modules ---
#    ../../modules/nixos/services/authelia.nix
#    ../../modules/nixos/services/firefly-iii.nix
#    ../../modules/nixos/services/freshrss.nix
#    ../../modules/nixos/services/gitea.nix
    # ../../modules/nixos/services/gitlab.nix
    ../../modules/nixos/services/homer.nix
#    ../../modules/nixos/services/immich.nix
    ../../modules/nixos/services/navidrome.nix
#    ../../modules/nixos/services/nextcloud.nix
    ../../modules/nixos/services/qbittorrent.nix
    ../../modules/nixos/services/radarr.nix
#    ../../modules/nixos/services/seafile.nix
    ../../modules/nixos/services/sonarr.nix
    ../../modules/nixos/services/syncthing.nix
    ../../modules/nixos/services/traefik.nix
    ../../modules/nixos/services/vaultwarden.nix
#    ../../modules/nixos/services/vikunja.nix
    # Note: jellyfin is configured directly below using official module
  ];

  # --- WSL integration ---
  wsl.enable = true;
#  wsl.graphics = false; # <-- THIS IS THE FIX. Disables the part trying to set hardware.graphics.
  boot.isContainer = true;
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  swapDevices = [ ];

  # --- Host basics ---
  networking.hostName = hostname;
  time.timeZone = "Europe/Budapest";

  # --- User definition ---
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ]; # Add docker group if using docker
    home = "/home/${username}"; # Explicitly set home directory
  };

  # --- Systemd, DBus ---
  services.dbus.enable = true;

  # --- Nix Settings ---
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    warn-dirty = false;
  };
  documentation.enable = false; # Save space on WSL

  # --- Enable Core Dependencies ---
  # Many services need a database and/or redis
  services.postgresql.enable = true;
  services.redis.enable = true;
  services.nginx.enable = true;
#  services.phpfpm.enable = true;
#  services.mariadb.enable = true; # Needed for Seafile

  # === Configure Jellyfin Using Official Module ===
  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };

  # --- Enable All Services ---
  services.paas.traefik.enable = true;
  services.paas.vaultwarden.enable = true;
#  services.paas.authelia.enable = true;
  services.paas.homer.enable = true;
#  services.paas.immich.enable = true;
  services.paas.navidrome.enable = true;
#  services.paas.nextcloud.enable = true;
  services.paas.qbittorrent.enable = true;
  services.paas.radarr.enable = true;
  services.paas.sonarr.enable = true;
  services.paas.syncthing.user = username; # Set the user for syncthing
#  services.paas.firefly-iii.enable = true;
#  services.paas.freshrss.enable = true;
#  services.paas.gitea.enable = true;
  # services.paas.gitlab.enable = false; # WARNING: Extremely resource heavy
#  services.paas.seafile.enable = true;
#  services.paas.vikunja.enable = true;

#  # === Authelia Configuration ===
#  # Basic configuration for Authelia - customize as needed
#  services.authelia.instances.settings = {
#    theme = "light";
#
##    server.address = "tcp://:9091/";
#
##    log.level = "info";
#
#    # IMPORTANT: These are insecure placeholders. Replace with real secrets!
#    # Use sops-nix or another secret management solution in production
##    jwt_secret = "INSECURE_JWT_SECRET_CHANGE_ME_PLEASE_!!!!!!!!!!!!!!!!!!";
##    default_redirection_url = "http://localhost:8088"; # Homer dashboard
#
#    totp.issuer = "authelia.com";
#
##    authentication_backend.file = {
##      path = "/var/lib/authelia/users_database.yml";
##      password = {
##        algorithm = "argon2id";
##        iterations = 1;
##        salt_length = 16;
##        parallelism = 8;
##        memory = 1024;
##        key_length = 32;
##      };
##    };
#
##    access_control = {
##      default_policy = "bypass"; # Allow all by default for initial setup
##      rules = [];
##    };
#
#    session = {
#      name = "authelia_session";
#      secret = "INSECURE_SESSION_SECRET_CHANGE_ME_PLEASE_!!!!!!!!!!!!";
#      expiration = "1h";
#      inactivity = "5m";
#      domain = "localhost"; # Change to your domain
#
#      redis = {
#        host = "127.0.0.1";
#        port = 6379;
#      };
#    };
#
#    storage.local.path = "/var/lib/authelia/db.sqlite3";
#
##    notifier.filesystem.filename = "/var/lib/authelia/notification.txt";
#  };

  services.authelia.instances = {
    main = {
      enable = true;
      secrets.storageEncryptionKeyFile = "/etc/authelia/storageEncryptionKeyFile";
      secrets.jwtSecretFile = "/etc/authelia/jwtSecretFile";
      settings = {
        theme = "light";
        default_2fa_method = "totp";
        log.level = "debug";
        server.disable_healthcheck = true;
      };
    };
    preprod = {
      enable = false;
      secrets.storageEncryptionKeyFile = "/mnt/pre-prod/authelia/storageEncryptionKeyFile";
      secrets.jwtSecretFile = "/mnt/pre-prod/jwtSecretFile";
      settings = {
        theme = "dark";
        default_2fa_method = "webauthn";
        server.host = "0.0.0.0";
      };
    };
    test.enable = true;
    test.secrets.manual = true;
    test.settings.theme = "grey";
    test.settings.server.disable_healthcheck = true;
    test.settingsFiles = [ "/mnt/test/authelia" "/mnt/test-authelia.conf" ];
    };


  # Create a test user for Authelia
  # Generate password hash with: nix-shell -p authelia --run "authelia crypto hash generate argon2 --password 'yourpassword'"
  environment.etc."authelia/users_database.yml".text = ''
    users:
      admin:
        displayname: "Administrator"
        password: "$argon2id$v=19$m=65536,t=3,p=4$BpLnfgDsc2WD8F2q$o/vzA4myCqZZ36bUGsDY//8mKUYNZZaR0t1MFFSs+iM"
        email: admin@localhost
        groups:
          - admins
  '';

  # --- Firewall ---
  # Enable the firewall. All modules will add their own ports.
  networking.firewall.enable = true;


  system.stateVersion = "25.05"; # Match your flake.nix
}

