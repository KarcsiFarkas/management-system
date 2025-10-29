# nix-solution/hosts/wsl-minimal/home.nix
{ config, pkgs, inputs, hostname, username, ... }:

{
  # Import reusable Home Manager modules
  imports = [
    ../../modules/home-manager/common.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  # No host-specific packages
  home.packages = [ ];

  # Host-specific git config
  programs.git = {
    enable = true;
    userName = "WSL Minimal User";
    userEmail = "wsl-minimal@example.com";
  };

  programs.bash.enable = true;

  home.stateVersion = "25.05";
}
