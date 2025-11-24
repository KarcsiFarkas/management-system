# Template host configuration
# Copy this directory to create a new host configuration
{ config, pkgs, lib, hostname, username, tenant, tenantConfig, ... }:

{
  # === Host Identification ===
  networking.hostName = hostname;
  networking.domain = lib.mkDefault "example.com";

  # === Hardware Configuration ===
  # This file will be generated on the target machine
  # After first deployment, run: nixos-generate-config --no-filesystems --root /
  # imports = [
  #   ./hardware-configuration.nix
  # ];

  # === Network Configuration ===
  # Option 1: DHCP (default)
  networking.useDHCP = lib.mkDefault true;

  # Option 2: Static IP (uncomment and configure)
  # networking.useDHCP = false;
  # networking.interfaces.eth0 = {
  #   useDHCP = false;
  #   ipv4.addresses = [{
  #     address = "192.168.1.100";
  #     prefixLength = 24;
  #   }];
  # };
  # networking.defaultGateway = "192.168.1.1";
  # networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

  # === Firewall Configuration ===
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22    # SSH (required for deployment)
      # 80    # HTTP (Traefik)
      # 443   # HTTPS (Traefik)
      # 8080  # Traefik Dashboard
    ];
    allowedUDPPorts = [ ];
  };

  # === SSH Key Configuration ===
  # IMPORTANT: Replace with your actual SSH public key
  users.users.root.openssh.authorizedKeys.keys = [
    # Add your SSH public key here
    # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... user@machine"
  ];

  users.users.${username}.openssh.authorizedKeys.keys = [
    # Add your SSH public key here
    # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... user@machine"
  ];

  # === Services Configuration ===
  # Enable services based on tenant configuration or manually

  # Example: Enable Traefik reverse proxy
  # services.paas.traefik = {
  #   enable = true;
  #   domain = config.networking.domain;
  # };

  # Example: Enable Vaultwarden password manager
  # services.paas.vaultwarden = {
  #   enable = true;
  #   domain = "vault.${config.networking.domain}";
  # };

  # Example: Enable Authelia SSO
  # services.paas.authelia = {
  #   enable = true;
  #   domain = "auth.${config.networking.domain}";
  # };

  # === Docker Configuration ===
  virtualisation.docker = {
    enable = lib.mkDefault false;
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

    # Key file location (provided by nixos-anywhere)
    age.keyFile = lib.mkDefault "/var/lib/sops-nix/key.txt";

    # Define secrets
    secrets = {
      # Example secret
      # "example_secret" = {
      #   owner = username;
      #   group = "users";
      #   mode = "0400";
      # };
    };
  };

  # === System Packages ===
  environment.systemPackages = with pkgs; [
    # Add host-specific packages here
  ];

  # === Tenant Configuration Overrides ===
  # If tenant configuration exists, it will be merged here automatically
  # via the flake.nix configuration
}
