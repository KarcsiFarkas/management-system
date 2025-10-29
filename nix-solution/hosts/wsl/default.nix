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
    ../../modules/nixos/services/homer.nix
    ../../modules/nixos/services/immich.nix
    ../../modules/nixos/services/navidrome.nix
    ../../modules/nixos/services/nextcloud.nix
    ../../modules/nixos/services/qbittorrent.nix
    ../../modules/nixos/services/radarr.nix
    ../../modules/nixos/services/sonarr.nix
    ../../modules/nixos/services/syncthing.nix
    ../../modules/nixos/services/traefik.nix
    ../../modules/nixos/services/vaultwarden.nix
    ../../modules/nixos/services/firefly-iii.nix
    ../../modules/nixos/services/freshrss.nix
    ../../modules/nixos/services/gitea.nix
    ../../modules/nixos/services/gitlab.nix
    ../../modules/nixos/services/seafile.nix
    ../../modules/nixos/services/vikunja.nix
    # Note: jellyfin.nix is NOT imported, it's configured directly below
  ];

  # --- WSL integration ---
  wsl.enable = true;
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
    extraGroups = [ "wheel" ];
    home = "/home/${username}"; # Explicitly set home directory
  };

  # --- Systemd, DBus ---
  services.dbus.enable = true;

  # --- Nix Settings ---
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    warn-dirty = false;
  };

  # --- Enable Core Dependencies ---
  # Many services need a database and/or redis
  services.postgresql.enable = true;
  services.redis.enable = true;

  # --- Enable Services ---
  # These options come from the `mkEnableOption` in each module
  services.paas.traefik.enable = true;
  services.paas.vaultwarden.enable = true;
  services.paas.authelia.enable = true;
  services.paas.homer.enable = true;
  services.paas.immich.enable = true;
  services.paas.navidrome.enable = true;
  services.paas.nextcloud.enable = true;
  services.paas.qbittorrent.enable = true;
  services.paas.radarr.enable = true;
  services.paas.sonarr.enable = true;
  services.paas.syncthing.enable = true;
  services.paas.firefly-iii.enable = true;
  services.paas.freshrss.enable = true;
  services.paas.gitea.enable = true;
  services.paas.gitlab.enable = true; # WARNING: Very resource heavy
  services.paas.seafile.enable = true;
  services.paas.vikunja.enable = true;

  # === FIX: Configure Jellyfin Directly ===
  # This ensures Jellyfin uses its standard port (8096)
  # and does NOT conflict with Traefik on port 80.
  services.jellyfin = {
    enable = true;
    port = 8096; # Explicitly set default port
    openFirewall = true;
  };

  # --- Firewall ---
  # Allow all enabled service ports.
  # The modules themselves add their ports to `networking.firewall.allowedTCPPorts`.
  networking.firewall.enable = true;

  system.stateVersion = "25.05"; # Match your flake.nix
}
