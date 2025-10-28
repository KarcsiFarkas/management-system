# nix-solution/modules/nixos/base.nix
{ config, pkgs, lib, inputs, ... }:

{
  # Basic system settings common across hosts
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  time.timeZone = lib.mkDefault "UTC";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  # Basic networking (if common) - host-specific NICs go in hardware-config
  networking.networkmanager.enable = lib.mkDefault false;
  # networking.domain = "your.domain"; # Set your domain if applicable

  # Define users common to all systems (can be overridden in host config)
  users.users.root.initialHashedPassword = lib.mkDefault "*"; # Lock root account by default
  # users.users.<your_common_username> = {
  #   isNormalUser = true;
  #   extraGroups = [ "wheel" "networkmanager" ];
  #   # Consider setting initialPasswordFile or initialHashedPassword
  # };

  # Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = lib.mkDefault true;
  # Add garbage collection, trusted users, etc.
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
    neovim nano vim
    htop btop tree bat fd ripgrep fzf tmux zellij vifm zoxide fastfetch
    mosh
  ];

  # Enable useful programs
  programs.mosh.enable = true;
  programs.zsh.enable = lib.mkDefault true; # Enable zsh globally if desired

  # Basic security
  security.rtkit.enable = true; # For pipewire/pulseaudio
  # services.firewall.enable = true; # Basic firewall (configure ports per host/service)

  # SSH configuration
  services.openssh.enable = lib.mkDefault true;

  # Firewall configuration for mosh
  networking.firewall.allowedUDPPortRanges = lib.mkAfter [
    { from = 60000; to = 61000; }
  ];
}
