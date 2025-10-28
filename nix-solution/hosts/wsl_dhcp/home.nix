# nix-solution/hosts/wsl_dhcp/home.nix
{ config, pkgs, inputs, hostname, username, ... }:

{
  # Import reusable Home Manager modules
  imports = [
    ../../modules/home-manager/common.nix
    # ../../modules/home-manager/shell/zsh.nix # Example
  ];

  # == User Specific Settings for 'username' on 'wsl_dhcp' ==

  home.username = username;
  home.homeDirectory = "/home/${username}";

  # User-specific packages for this host
  home.packages = with pkgs; [
    # Add packages you want for this user on this host
  ];

  # Configure programs managed by Home Manager
  programs.git = {
    enable = true;
    userName = "Your Name";
    userEmail = "your.email@example.com";
  };

  programs.bash.enable = true; # Or zsh, fish, etc.

  # Link dotfiles (example)
  # home.file.".config/example/config.toml".source = ./dotfiles/example.toml;

  # State version for Home Manager
  home.stateVersion = "24.11";
}
