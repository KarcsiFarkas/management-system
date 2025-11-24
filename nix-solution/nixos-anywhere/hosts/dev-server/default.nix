# Development Server Configuration
# Lightweight development/testing server
{ config, pkgs, lib, hostname, username, tenant, tenantConfig, ... }:

{
  # === Host Identification ===
  networking.hostName = hostname;
  networking.domain = lib.mkDefault "dev.local";

  # === Network Configuration ===
  networking.useDHCP = lib.mkDefault true;

  # === Firewall Configuration ===
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22    # SSH (required for deployment)
      80    # HTTP (Traefik)
      443   # HTTPS (Traefik)
      8080  # Traefik Dashboard
    ];
    allowedUDPPorts = [ ];
  };

  # === SSH Key Configuration ===
  users.users.root.openssh.authorizedKeys.keys = [
    # Add your SSH public key here
    # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... user@machine"
  ];

  users.users.${username}.openssh.authorizedKeys.keys = [
    # Add your SSH public key here
    # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... user@machine"
  ];

  # === Services Configuration ===
  # Minimal set of services for development

  # Traefik - Reverse Proxy (disabled by default for dev)
  # services.paas.traefik = {
  #   enable = true;
  #   domain = config.networking.domain;
  # };

  # === Docker Configuration ===
  virtualisation.docker = {
    enable = lib.mkDefault true;
    enableOnBoot = lib.mkDefault true;

    # Prune old containers and images
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # === Secrets Management (sops-nix) ===
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = lib.mkDefault "/var/lib/sops-nix/key.txt";

    # Define secrets as needed
    secrets = { };
  };

  # === System Packages ===
  environment.systemPackages = with pkgs; [
    git
    vim
    htop
    tmux
    docker-compose
  ];

  # === Tenant Configuration Overrides ===
  # If tenant configuration exists, it will be merged here automatically
  # via the flake.nix configuration
}
