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

    # --- NO service modules are imported ---
  ];

  # --- WSL integration ---
  wsl.enable = true;
  wsl.graphics = false; # <-- THIS IS THE FIX. Disables the part trying to set hardware.graphics.

  # --- Bootloader ---
  boot.isContainer = true;
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  swapDevices = [ ];

  # --- Host basics ---
  networking.hostName = hostname; # "wsl-minimal"
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

  # --- Firewall ---
  networking.firewall.enable = true;

  # --- State Version ---
  system.stateVersion = "25.05"; # Match your flake.nix and home.nix
}

