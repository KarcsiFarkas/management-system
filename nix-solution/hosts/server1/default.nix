{ inputs, pkgs,... }: {
  imports = [];

  networking.hostName = "server1"; # Define your hostname.

  system.stateVersion = "24.05"; # Set to the version you are installing.
}