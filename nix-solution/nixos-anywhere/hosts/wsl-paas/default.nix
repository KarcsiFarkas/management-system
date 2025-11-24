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
      network = {
        hostname = "wsl-paas";
        generateResolvConf = true;  # Let WSL manage DNS
      };
      interop.appendWindowsPath = false;
    };
  };

  # Fallback DNS configuration if WSL doesn't generate resolv.conf
  networking.nameservers = lib.mkDefault [ "8.8.8.8" "1.1.1.1" ];

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
    # Infrastructure - Using WSL-friendly ports to avoid conflicts
    traefik = {
      enable = true;
      domain = "wsl-paas.local";  # Or use 172.26.159.132.nip.io for wildcard DNS

      # WSL-specific ports (avoid system ports 80, 443, 8080)
      ports = {
        http = 8090;      # Instead of 80 (often used by system)
        https = 8443;     # Instead of 443
        dashboard = 9080; # Instead of 8080 (often used by system)
      };
    };

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
      8090  # Traefik HTTP (WSL-specific)
      8443  # Traefik HTTPS (WSL-specific)
      9080  # Traefik dashboard (WSL-specific)
      8088  # Homer
      8096  # Jellyfin HTTP
      8920  # Jellyfin HTTPS
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
