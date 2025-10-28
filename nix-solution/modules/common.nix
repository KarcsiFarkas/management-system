{ config, pkgs, lib, ... }:

let
  devPkgs = with pkgs; [
    curl wget jq
    unzip zip
    git
    neovim nano
    htop btop tree bat fd ripgrep fzf tmux zellij vifm zoxide fastfetch
    mosh
  ];
in
{
  # Single assignment
  environment.systemPackages = devPkgs;

  programs.mosh.enable = true;
  networking.firewall.allowedUDPPortRanges = lib.mkAfter [
    { from = 60000; to = 61000; }
  ];

  services.openssh.enable = lib.mkDefault true;

  nix.settings = {
    experimental-features = lib.mkDefault [ "nix-command" "flakes" ];
  };

  # Removed: programs.fzf.enable / programs.zoxide.enable (Home-Manager only)
}
