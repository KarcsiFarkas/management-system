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
#  wsl.graphics = false; # <-- THIS IS THE FIX. Disables the part trying to set hardware.graphics.

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


#{ config
#, lib
#, pkgs
#, inputs
#, hostname
#, username
#, ... }:
#
#{
#  imports = [
#    inputs.nixos-wsl.nixosModules.wsl
#    ./hardware-configuration.nix
#  ];
#
#  # === Complete hardware.graphics compatibility shim ===
#  # The nixos-wsl module uses hardware.graphics (newer NixOS),
#  # but we're on NixOS 24.05 which uses hardware.opengl
#  options.hardware.graphics = lib.mkOption {
#    type = lib.types.submodule {
#      options = {
#        enable = lib.mkOption {
#          type = lib.types.bool;
#          default = false;
#        };
#        enable32Bit = lib.mkOption {
#          type = lib.types.bool;
#          default = false;
#        };
#        extraPackages = lib.mkOption {
#          type = lib.types.listOf lib.types.package;
#          default = [];
#        };
#        extraPackages32 = lib.mkOption {
#          type = lib.types.listOf lib.types.package;
#          default = [];
#        };
#      };
#    };
#    default = {};
#    description = "Compatibility shim for hardware.graphics -> hardware.opengl";
#  };
#
#  config = {
#    # Map all hardware.graphics options to hardware.opengl
#    hardware.opengl = {
#      enable = lib.mkDefault config.hardware.graphics.enable;
#      driSupport = lib.mkDefault config.hardware.graphics.enable;
#      driSupport32Bit = lib.mkDefault config.hardware.graphics.enable32Bit;
#      extraPackages = lib.mkDefault config.hardware.graphics.extraPackages;
#      extraPackages32 = lib.mkDefault config.hardware.graphics.extraPackages32;
#    };
#
#    wsl = {
#      enable = true;
#      defaultUser = username;
#      startMenuLaunchers = false;
#    };
#
#    boot.isContainer = true;
#    boot.loader.systemd-boot.enable = lib.mkForce false;
#    boot.loader.grub.enable = lib.mkForce false;
#    boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
#    swapDevices = [ ];
#
#    networking.hostName = hostname;
#    time.timeZone = "Europe/Budapest";
#
#    users.users.${username} = {
#      isNormalUser = true;
#      extraGroups = [ "wheel" "docker" ];
#      home = "/home/${username}";
#    };
#
#    services.dbus.enable = true;
#
#    nix.settings = {
#      experimental-features = [ "nix-command" "flakes" ];
#      warn-dirty = false;
#    };
#    documentation.enable = false;
#
#    networking.firewall.enable = true;
#
#    system.stateVersion = "25.05";
#  };
#}
