# Secrets configuration module
# Integrates sops-nix for encrypted secret management
{ config, lib, ... }:

{
  # === sops-nix Configuration ===
  # This module sets up secret management for all hosts

  # Default sops file location
  sops.defaultSopsFile = lib.mkDefault ./secrets.yaml;

  # Age key file location (will be created by nixos-anywhere)
  # This key is used to decrypt secrets
  sops.age.keyFile = lib.mkDefault "/var/lib/sops-nix/key.txt";

  # Ensure the key file directory exists with correct permissions
  systemd.tmpfiles.rules = [
    "d /var/lib/sops-nix 0750 root root -"
    "f /var/lib/sops-nix/key.txt 0600 root root -"
  ];

  # === Common Secrets ===
  # These can be overridden per-host as needed
  # Actual secrets are defined in hosts/<hostname>/default.nix
}
