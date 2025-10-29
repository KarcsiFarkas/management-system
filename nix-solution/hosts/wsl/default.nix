# nix-solution/hosts/wsl/default.nix
{ config
, lib
, pkgs
, inputs # Make sure inputs are passed via specialArgs from flake.nix
, hostname # Passed via specialArgs
, username # Passed via specialArgs
, ... }:

{
  imports = [
    # Import the nixos-wsl module HERE specifically for this host
    inputs.nixos-wsl.nixosModules.wsl

    # Import hardware config generated for WSL (should be minimal)
    ./hardware-configuration.nix

    # You can still import specific service modules if needed for WSL
    # E.g., ../../modules/nixos/services/tailscale.nix
  ];

  # --- WSL integration ---
  wsl.enable = true;
  # Optional: Enable WSL utilities like wslview
  wsl.utilities.enable = true;
  # Optional: Enable systemd integration if needed (requires specific WSL setup)
  # wsl.nativeSystemd = true;

  # Treat environment as container-like (no early boot responsibilities)
  boot.isContainer = true;

  # === Absolutely no bootloaders/EFI in WSL ===
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.grub.enable         = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # === No Linux swap in WSL; Windows manages it via .wslconfig ===
  swapDevices = [ ];

  # --- Host basics ---
  networking.hostName = hostname; # Set from specialArgs
  time.timeZone = "Europe/Budapest"; # Or your preferred timezone

  # --- User definition ---
  # Define the primary user for WSL. Home Manager will configure their environment.
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # 'wheel' for sudo access
    # Ensure initial password is set for the first login, or use SSH keys.
    # It's recommended to set the password manually after first boot: `passwd your_username`
    # initialPassword = "yourpassword"; # Less secure
    # Or use a hashed password (generate with mkpasswd -m sha-512)
    # initialHashedPassword = "$6$yourhashhere...";
  };

  # --- Systemd, DBus, cron ---
  # Enable D-Bus for inter-process communication (needed by many apps)
  services.dbus.enable = true;
  # Enable cron if you need scheduled tasks (systemd timers are often preferred)
  # services.cron.enable = true;

  # --- System Packages specific to WSL ---
  # Keep this minimal; prefer user packages via Home Manager
  environment.systemPackages = with pkgs; [
    git curl htop ripgrep
    # Add essentials needed system-wide in WSL
  ];

  # --- Nix Settings ---
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    # Suppress the "Git tree is dirty" warning during rebuilds if desired
    warn-dirty = false;
  };

  # Optional: Disable documentation build on WSL to save space/time
  documentation.enable = false;

  # Set the state version - MAKE SURE this matches your nixpkgs branch (e.g., 23.11)
  system.stateVersion = "25.05";
}