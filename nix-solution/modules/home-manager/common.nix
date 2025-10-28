# nix-solution/modules/home-manager/common.nix
{ config, pkgs, ... }:

{
  # Settings common to your user across different machines
  home.packages = with pkgs; [
    htop
    curl
    wget
    git
    neofetch
    fastfetch
  ];

  programs.starship = {
    enable = true;
    # settings = { ... }; # Add starship config if needed
  };

  programs.git = {
    enable = true;
    # userName = "Your Name";
    # userEmail = "your.email@example.com";
    # Configure these per-host in home.nix if different across machines
  };

  programs.bash.enable = true; # Or zsh, fish, etc.

  # Enable useful programs that were removed from system-level common.nix
  programs.fzf.enable = true;
  programs.zoxide.enable = true;

  # Common aliases, environment variables, etc.
  home.sessionVariables = {
    EDITOR = "vim";
  };
}
