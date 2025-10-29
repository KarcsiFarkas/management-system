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
    ../../modules/nixos/services/authelia.nix
    ../../modules/nixos/services/firefly-iii.nix
    ../../modules/nixos/services/freshrss.nix
    ../../modules/nixos/services/gitea.nix
    # ../../modules/nixos/services/gitlab.nix
    ../../modules/nixos/services/homer.nix
    ../../modules/nixos/services/immich.nix
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
    # Note: jellyfin.nix is NOT imported, it's configured directly below
  ];

  # --- WSL integration ---
  wsl.enable = true;
  wsl.graphics = false; # <-- THIS IS THE FIX. Disables the part trying to set hardware.graphics.
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
  services.phpfpm.enable = true;
  services.mariadb.enable = true; # Needed for Seafile

  # === FIX: Configure Jellyfin Directly (Standard Port) ===
  services.jellyfin = {
    enable = true;
    port = 8096; # Explicitly set default port
    openFirewall = true;
  };

  # --- Enable All Services ---
  services.paas.traefik.enable = true;
  services.paas.vaultwarden.enable = true;
#  services.paas.authelia.enable = true;
  services.paas.homer.enable = true;
  services.paas.immich.enable = true;
  services.paas.navidrome.enable = true;
  services.paas.nextcloud.enable = true;
  services.paas.qbittorrent.enable = true;
  services.paas.radarr.enable = true;
  services.paas.sonarr.enable = true;
  services.paas.syncthing.user = username; # Set the user for syncthing
  services.paas.firefly-iii.enable = true;
  services.paas.freshrss.enable = true;
  services.paas.gitea.enable = true;
  # services.paas.gitlab.enable = false; # WARNING: Extremely resource heavy
  services.paas.seafile.enable = true;
  services.paas.vikunja.enable = true;

  # === Authelia Configuration ===
  # Moved from the module file to the host file
  services.authelia.settings = {
    server.port = 9091;
    server.host = "0.0.0.0";
    log.level = "debug";

    # Use filesystem for session storage (simpler for WSL)
    session.storage = "filesystem";
    session.path = "/var/lib/authelia/session";

    # Placeholder: You MUST replace these with real secrets, preferably via sops-nix
    jwt_secret = "CHANGE_ME_INSECURE_SECRET_!!!!!!!!!!!!";
    session.secret = "CHANGE_ME_INSECURE_SECRET_!!!!!!!!!!!";

    # Use a file-based backend for users
    authentication_backend.file = {
      path = "/etc/authelia/users_database.yml";
      password = {
        algorithm = "argon2id";
        iterations = 1;
        salt_length = 16;
        key_length = 32;
        memory = 1024;
        parallelism = 8;
      };
    };

    # Deny all access by default
    access_control = {
      default_policy = "deny";
      rules = [
        # Add rules here to allow access, e.g.:
        # { domain = [ "vaultwarden.your.domain" ]; policy = "two_factor"; }
      ];
    };
  };

  # Create a default user database for Authelia
  # You MUST generate a real password hash using:
  # authelia hash-password 'your-strong-password'
  environment.etc."authelia/users_database.yml".text = ''
    users:
      ${username}: # Use the username from specialArgs
        displayname: "WSL User"
        # PASTE YOUR HASH HERE
        password: "$argon2id$v=19$m=65536,t=3,p=4$YOUR_SALT_HERE$YOUR_HASH_HERE"
        email: user@example.com
        groups:
          - admins
  '';


  # --- Firewall ---
  # Enable the firewall. All modules will add their own ports.
  networking.firewall.enable = true;

  system.stateVersion = "25.05"; # Match your flake.nix
}

