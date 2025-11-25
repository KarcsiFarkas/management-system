# Minimal NixOS WSL configuration - DNS fix only
{ config, lib, pkgs, inputs, hostname, username, ... }:

{
  imports = [
    inputs.nixos-wsl.nixosModules.wsl
    ./hardware-configuration.nix
  ];

  # --- WSL integration ---
  wsl.enable = true;

  # Disable WSL's automatic DNS management
  wsl.wslConf = {
    network = {
      hostname = hostname;
      generateResolvConf = false;  # Prevent WSL from managing /etc/resolv.conf
    };
    interop.appendWindowsPath = false;
  };

  # --- Bootloader (WSL specific) ---
  boot.isContainer = true;
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  swapDevices = [ ];

  # --- Host basics ---
  networking.hostName = hostname;
  networking.domain = "wsl.local";
  time.timeZone = "Europe/Budapest";

  # --- DNS Configuration (Critical for WSL) ---
  # Disable systemd-resolved to prevent conflicts with static DNS
  services.resolved.enable = false;

  # Force static DNS configuration
  networking.nameservers = [ "8.8.8.8" "1.1.1.1" ];

  # Explicitly manage /etc/resolv.conf to prevent WSL from recreating symlink
  environment.etc."resolv.conf".text = ''
    # Static DNS configuration managed by NixOS
    nameserver 8.8.8.8
    nameserver 1.1.1.1
  '';

  # --- User definition ---
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
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
  system.stateVersion = "25.05";
}
