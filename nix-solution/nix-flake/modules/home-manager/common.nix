# nix-solution/modules/home-manager-example/common.nix
{ config, pkgs, lib, ... }:

let
  inherit (lib) mkDefault mkIf mkMerge;
  isLinux = pkgs.stdenv.isLinux;
  isDarwin = pkgs.stdenv.isDarwin;
  isWSL = isLinux && builtins.getEnv "WSL_DISTRO_NAME" != "";
in
{
  # Settings common to your user across different machines
  home.packages = with pkgs; [
    htop
    curl
    wget
    git
    neofetch
    fastfetch
    helix
    zoxide
    fzf
    unzip
    starship
    yazi
    bat
    atuin
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
    EDITOR = mkDefault "hx";
    VISUAL = mkDefault "hx";
    PAGER = mkDefault "less -FRSX";
    LANG = mkDefault "en_US.UTF-8";
    NO_AT_BRIDGE = mkDefault "1";
  };

  home.shellAliases = mkMerge [
    (mkIf isDarwin {
      o = "open";
    })
    (mkIf isLinux {
      o = "xdg-open";
    })
  ];

  programs.bash.shellAliases = mkIf isWSL {
    open = "xdg-open";
    o = "xdg-open";
    winopen = "explorer.exe .";
    clip = "clip.exe";
  };
}
