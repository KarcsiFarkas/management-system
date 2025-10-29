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
#    ../../modules/nixos/services/gitlab.nix
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
  ];

  # --- WSL integration ---
  wsl.enable = true;
#  wsl.graphics = false; # <-- THIS IS THE FIX. Disables the part trying to set hardware.graphics.

  # --- Bootloader ---
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
    extraGroups = [ "wheel" "docker" ];
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

  # --- Enable Core Dependencies ---
  services.postgresql.enable = true;
  # === FIX: Changed services.redis.enable to new syntax ===
  services.redis.servers."".enable = true;
  #services.nginx.enable = true;
  services.phpfpm.enable = true;
  # services.mariadb.enable = true; # Needed for Seafile

  # === FIX: Configure Jellyfin Directly (Standard Port) ===
  services.jellyfin = {
    enable = true;
    port = 8096;
    openFirewall = true;
  };

  # --- Enable All Services ---
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
  services.paas.syncthing.user = username;
  services.paas.firefly-iii.enable = true;
  services.paas.freshrss.enable = true;
  services.paas.gitea.enable = true;
  #services.paas.gitlab.enable = false; # WARNING: Very resource heavy
  services.paas.seafile.enable = true;
  services.paas.vikunja.enable = true;

  # --- Firewall ---
  networking.firewall.enable = true;

  system.stateVersion = "25.05";
}

