# nix-solution/secrets/default.nix
{ config, pkgs, lib, ... }:

{
  # Example: Define which secrets files exist and their format
  # Uncomment and configure as needed when setting up sops-nix
  
  # sops.secrets."nextcloud/admin_password" = {
  #   # format = "yaml"; # or json, dotenv, binary
  #   # owner = config.users.users.nextcloud.name; # Optional: set owner
  #   # group = config.users.groups.nextcloud.name; # Optional: set group
  #   # Needed by the nextcloud module if using adminpassFile
  # };
  
  # sops.secrets."traefik/cloudflare_api_key" = {
  #   # Needed by traefik for DNS challenge
  # };
  
  # Add entries for all your encrypted files
  # sops.secrets."my-service/api-token" = {};

  # Optionally specify the master key file location if not default
  # sops.keyFile = "/path/to/host/private/key";

  # Age specific settings
  # sops.age.keyFile = "/var/lib/sops/key.txt";
  # sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  
  # For now, this is a placeholder configuration
  # To use sops-nix:
  # 1. Generate GPG or age keys
  # 2. Create .sops.yaml in repo root with public keys
  # 3. Create encrypted secret files (e.g., secrets/nextcloud/admin_password.txt)
  # 4. Encrypt them using: sops secrets/nextcloud/admin_password.txt
  # 5. Uncomment and configure the secrets above
  # 6. Reference secrets in your modules using: config.sops.secrets."<secret_name>".path
}
