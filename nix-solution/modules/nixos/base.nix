# nix-solution/modules/nixos/base.nix
{ config, pkgs, lib, inputs, ... }:

{
  # Basic system settings common across hosts
  # Bootloader settings are commented out or use mkDefault false to allow overrides
  # boot.loader.systemd-boot.enable = lib.mkDefault true;
  # boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
  boot.loader.grub.enable = lib.mkDefault false; # Default to false, can be enabled per-host if needed

  time.timeZone = lib.mkDefault "UTC"; # Default timezone, override per-host
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  # Basic networking (if common) - NetworkManager disabled by default
  networking.networkmanager.enable = lib.mkDefault false; # Enable per-host if needed
  # networking.domain = "your.domain"; # Set your domain if applicable

  # Define root user common settings
  users.users.root.initialHashedPassword = lib.mkDefault "*"; # Lock root account by default

  # Nix settings
  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = lib.mkDefault true;
  # Add garbage collection settings
  nix.gc = {
    automatic = lib.mkDefault true;
    dates = lib.mkDefault "weekly";
    options = lib.mkDefault "--delete-older-than 30d";
  };

  # Common system packages (minimal base)
  environment.systemPackages = with pkgs; [
    curl wget jq
    unzip zip
    git
    neovim nano vim # Basic editors
    htop btop tree bat fd ripgrep fzf tmux zellij vifm zoxide fastfetch # Common CLI tools
    mosh # For Mosh SSH alternative
  ];

  # Enable useful programs globally
  programs.mosh.enable = true;
  programs.zsh.enable = lib.mkDefault true; # Default to zsh

  # Basic security settings
  security.rtkit.enable = true; # For pipewire/pulseaudio real-time scheduling
  # services.firewall.enable = lib.mkDefault false; # Firewall disabled by default, enable per-host

  # SSH configuration
  services.openssh = {
    enable = lib.mkDefault true; # Enable SSH server by default
    # settings.PermitRootLogin = "no"; # Good practice to disable root login
    # settings.PasswordAuthentication = false; # Recommended to use SSH keys only
  };

  # Firewall configuration for mosh UDP ports (only relevant if firewall is enabled)
  networking.firewall.allowedUDPPortRanges = lib.mkAfter [ # mkAfter ensures this is added late
    { from = 60000; to = 61000; } # Mosh ports
  ];
}