# WSL PaaS Configuration
# For testing PaaS services locally on NixOS WSL
{ config, lib, pkgs, inputs, username, ... }:

{
  imports = [
    # WSL-specific module
    inputs.nixos-wsl.nixosModules.wsl
  ];

  # === System Configuration ===
  system.stateVersion = "24.11";
  networking.hostName = "wsl-paas";

  # WSL IP address (update if it changes)
  # Current IP: 172.26.159.132

  # === WSL Configuration ===
  wsl = {
    enable = true;
    defaultUser = username;
    startMenuLaunchers = true;

    # Note: nativeSystemd is now always enabled (deprecated option removed)

    # WSL integration
    wslConf = {
      network.hostname = "wsl-paas";
      interop.appendWindowsPath = false;
    };
  };

  # === User Configuration ===
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "networkmanager" ];
    shell = lib.mkForce pkgs.zsh;  # Override default bash from common/users.nix
  };

  # WSL-specific: Don't require password for sudo (override common/users.nix)
  security.sudo.wheelNeedsPassword = lib.mkForce false;

  # === Enable PaaS Services ===
  services.paas = {
    # Infrastructure
    traefik.enable = true;
    traefik.domain = "wsl-paas.local";  # Or use 172.26.159.132.nip.io for wildcard DNS

    # Authentication & Management
    # authelia.enable = true;  # Uncomment when module is fixed
    homer.enable = true;
    # vaultwarden.enable = true;  # Uncomment when module is fixed

    # Storage & Collaboration
    # nextcloud.enable = true;  # Uncomment when module is fixed

    # Media Services
    jellyfin.enable = true;

    # Development
    # gitea.enable = true;  # Uncomment as needed
  };

  # === Docker Support ===
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  # === Firewall ===
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22    # SSH
      80    # HTTP
      443   # HTTPS
      8080  # Traefik dashboard
      8088  # Homer
      8096  # Jellyfin
    ];
  };

  # === System Packages ===
  environment.systemPackages = with pkgs; [
    # Essential tools
    vim
    git
    curl
    wget
    htop

    # Docker tools
    docker-compose

    # Network tools
    dig
    netcat
    tcpdump
  ];

  # === Nix Configuration ===
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [ "root" username ];
    };
  };

  # === Enable common services ===
  programs.zsh.enable = true;
  services.openssh.enable = true;
}
