# nix-solution/hosts/*/home.nix
{ config, pkgs, inputs, hostname, username, ... }:

{
  # Import reusable Home Manager modules
  imports = [
    ../../modules/home-manager/common.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  home.packages = with pkgs; [ ];

  programs.git = {
    enable = true;
    settings = {
      user.name = "Your Name";
      user.email = "your.email@example.com";
    };
  };

  programs.bash.enable = true;

  home.stateVersion = "24.11";
}
