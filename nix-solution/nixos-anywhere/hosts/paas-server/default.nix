# Production PaaS Server Configuration
# Full-featured server with all PaaS services enabled
{ config, pkgs, lib, hostname, username, tenant, tenantConfig, ... }:

{
  # === Host Identification ===
  networking.hostName = hostname;
  networking.domain = "paas.local"; # Change to your actual domain

  # === Network Configuration ===
  # Using DHCP by default, configure static IP if needed
  networking.useDHCP = true;

  # For static IP, uncomment and configure:
  # networking.useDHCP = false;
  # networking.interfaces.eth0 = {
  #   useDHCP = false;
  #   ipv4.addresses = [{
  #     address = "192.168.1.100";
  #     prefixLength = 24;
  #   }];
  # };
  # networking.defaultGateway = "192.168.1.1";

  # === Firewall Configuration ===
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22      # SSH
      80      # HTTP (Traefik)
      443     # HTTPS (Traefik)
      8080    # Traefik Dashboard
    ];
  };

  # === SSH Key Configuration ===
  users.users.root.openssh.authorizedKeys.keys = [
    # IMPORTANT: Add your SSH public key here
    # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... deployment@local"
  ];

  users.users.${username}.openssh.authorizedKeys.keys = [
    # IMPORTANT: Add your SSH public key here
    # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... user@local"
  ];

  # === Docker Configuration ===
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # === PaaS Services Configuration ===

  # Traefik - Reverse Proxy
  services.paas.traefik = {
    enable = true;
    # Configuration will be loaded from service module
  };

  # FIXME: Authelia module needs to be fixed before enabling
  # services.paas.authelia = {
  #   enable = true;
  #   # Secrets will be loaded from sops
  # };

  # FIXME: Vaultwarden and Homer modules need testing
  # services.paas.vaultwarden = {
  #   enable = true;
  # };

  # services.paas.homer = {
  #   enable = true;
  # };

  # Additional services (enable as needed)
  # services.paas.nextcloud.enable = true;
  # services.paas.gitlab.enable = true;
  # services.paas.jellyfin.enable = true;
  # services.paas.gitea.enable = true;

  # === Secrets Management ===
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";

    secrets = {
      # FIXME: Comment out until services are re-enabled
      # # Authelia secrets
      # "authelia/jwt_secret" = {
      #   owner = "authelia";
      #   group = "authelia";
      #   mode = "0400";
      # };
      # "authelia/session_secret" = {
      #   owner = "authelia";
      #   group = "authelia";
      #   mode = "0400";
      # };
      # "authelia/storage_encryption_key" = {
      #   owner = "authelia";
      #   group = "authelia";
      #   mode = "0400";
      # };

      # # Vaultwarden secrets
      # "vaultwarden/admin_token" = {
      #   owner = "vaultwarden";
      #   group = "vaultwarden";
      #   mode = "0400";
      # };

      # Database passwords
      # "database/postgres_password" = {
      #   owner = "postgres";
      #   group = "postgres";
      #   mode = "0400";
      # };
    };
  };

  # === Monitoring & Logging ===
  # services.prometheus.enable = true;
  # services.grafana.enable = true;
  # services.loki.enable = true;

  # === Backup Configuration ===
  # Configure backup services if needed
  # services.restic.backups = { ... };

  # === System Packages ===
  environment.systemPackages = with pkgs; [
    docker-compose
    git
    vim
    htop
  ];
}
