# NixOS-Anywhere Deployment Configuration

Comprehensive, production-ready NixOS deployment system using nixos-anywhere with tenant-aware configuration management, integrated secret management, and automated deployment workflows.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Directory Structure](#directory-structure)
- [Configuration Guide](#configuration-guide)
- [Deployment Workflows](#deployment-workflows)
- [Tenant Integration](#tenant-integration)
- [Secret Management](#secret-management)
- [Troubleshooting](#troubleshooting)
- [Advanced Topics](#advanced-topics)

---

## Overview

This deployment system provides:

- **Declarative Infrastructure**: Complete system configuration defined in Nix
- **Automated Deployment**: One-command remote installation with nixos-anywhere
- **Disk Management**: Automated partitioning with disko (GPT, LVM, BTRFS support)
- **Secret Management**: Encrypted secrets with sops-nix
- **Tenant Awareness**: Integration with ms-config for multi-tenant deployments
- **Service Modules**: Reuses existing PaaS service modules
- **Production Ready**: Security hardening, monitoring, and backup support

---

## Features

### Core Features

- ✅ **nixos-anywhere Integration**: Remote, unattended NixOS installation
- ✅ **Disko Disk Layouts**: Multiple disk configuration templates (GPT, LVM, BTRFS)
- ✅ **sops-nix Secrets**: Encrypted secret management with age
- ✅ **Tenant Configuration**: Automatic loading of tenant-specific settings from ms-config
- ✅ **Service Modules**: 18+ integrated PaaS services (Traefik, Vaultwarden, Nextcloud, etc.)
- ✅ **Security Hardening**: CIS-compliant security configuration
- ✅ **Development Shell**: Pre-configured environment with all deployment tools

### Disk Layouts

Three pre-configured disk layouts:

1. **standard-gpt**: Simple GPT with EFI boot + ext4 root
2. **standard-gpt-lvm**: LVM for flexible partition management
3. **btrfs-subvolumes**: BTRFS with subvolumes and compression

### Integrated Services

All services from `../nix-flake/modules/nixos/services/`:

- **Infrastructure**: Traefik, Authelia, Homer
- **Storage**: Nextcloud, Seafile, Syncthing
- **Development**: GitLab, Gitea
- **Media**: Jellyfin, Navidrome, Immich
- **Management**: Vaultwarden, Vikunja, Firefly-III, FreshRSS
- **Automation**: Radarr, Sonarr, qBittorrent

---

## Prerequisites

### On Your Local Machine

```bash
# Required: Nix with flakes enabled
# Check installation
nix --version

# Verify flakes are enabled
nix flake show github:NixOS/nixpkgs

# Optional: Install nixos-anywhere globally
nix-env -iA nixpkgs.nixos-anywhere
```

### On Target Machine

- **Network Access**: Reachable via SSH (no WiFi support)
- **RAM**: At least 1 GB (for kexec)
- **Disk**: Sufficient storage for your configuration
- **OS**: Any Linux with SSH enabled (or NixOS installer)

### Secret Management Tools

```bash
# Enter development shell (includes all tools)
cd nixos-anywhere
nix develop

# Or install individually
nix-shell -p sops age ssh-to-age
```

---

## Quick Start

### 1. Clone and Setup

```bash
cd /home/kari/thesis-szakdoga/management-system/nix-solution/nixos-anywhere

# Enter development shell
nix develop
```

### 2. Configure Secrets

```bash
# Generate age key
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt

# View your public key
cat ~/.config/sops/age/keys.txt | grep "public key:"

# Update .sops.yaml with your public key
nano secrets/.sops.yaml

# Create and encrypt secrets
cp secrets/secrets.yaml.example secrets/secrets.yaml
# Edit secrets.yaml and replace all REPLACE_WITH_ACTUAL_* values
nano secrets/secrets.yaml

# Encrypt
sops -e -i secrets/secrets.yaml
```

### 3. Generate SSH Key for Deployment

```bash
# Generate deployment key
ssh-keygen -t ed25519 -C "nixos-deployment" -f ~/.ssh/id_ed25519_nixos

# View public key (you'll add this to host configuration)
cat ~/.ssh/id_ed25519_nixos.pub
```

### 4. Create Host Configuration

```bash
# Generate from template
./scripts/generate-host.sh my-server

# Edit configuration
nano hosts/my-server/variables.nix
nano hosts/my-server/default.nix

# Add your SSH public key to default.nix
```

### 5. Add to Flake

Edit `flake.nix` and add your host:

```nix
nixosConfigurations = {
  # ... existing configurations ...

  my-server = mkTenantHost {
    hostname = "my-server";
    tenant = "production";
    system = "x86_64-linux";
    diskLayout = "standard-gpt";
    username = "admin";
  };
};
```

### 6. Deploy

```bash
# Test flake configuration
nix flake check

# Deploy
./scripts/deploy.sh my-server 192.168.1.100

# Or with tenant awareness
./scripts/deploy-tenant.sh production my-server 192.168.1.100
```

---

## Directory Structure

```
nixos-anywhere/
├── flake.nix                       # Main flake configuration
├── flake.lock                      # Locked dependencies
├── README.md                       # This file
│
├── common/                         # Shared modules
│   ├── base.nix                    # Base system configuration
│   ├── security.nix                # Security hardening
│   ├── networking.nix              # Network configuration
│   └── users.nix                   # User management
│
├── disk-configs/                   # Disko disk layouts
│   ├── standard-gpt.nix            # Simple GPT + EFI
│   ├── standard-gpt-lvm.nix        # LVM layout
│   └── btrfs-subvolumes.nix        # BTRFS with subvolumes
│
├── hosts/                          # Host-specific configurations
│   ├── template/                   # Template for new hosts
│   │   ├── default.nix             # Host configuration
│   │   └── variables.nix           # Host variables
│   ├── paas-server/                # Example production server
│   │   └── default.nix
│   ├── dev-server/                 # Example dev server
│   └── staging-server/             # Example staging server
│
├── secrets/                        # Secret management
│   ├── default.nix                 # Secrets module
│   ├── .sops.yaml                  # sops configuration
│   ├── secrets.yaml                # Encrypted secrets (git)
│   ├── secrets.yaml.example        # Unencrypted template
│   └── README.md                   # Secrets documentation
│
└── scripts/                        # Deployment scripts
    ├── deploy.sh                   # Main deployment script
    ├── deploy-tenant.sh            # Tenant-aware deployment
    └── generate-host.sh            # Generate host from template
```

---

## Configuration Guide

### Creating a New Host

#### Option 1: Using the Generator Script

```bash
# Generate from template
./scripts/generate-host.sh production-server

# Edit variables
nano hosts/production-server/variables.nix
```

#### Option 2: Manual Creation

```bash
# Copy template
cp -r hosts/template hosts/production-server

# Edit configuration files
nano hosts/production-server/default.nix
nano hosts/production-server/variables.nix
```

### Host Configuration Files

#### variables.nix

Defines host-specific variables:

```nix
{
  username = "admin";
  tenant = "production";
  diskLayout = "standard-gpt-lvm";
  system = "x86_64-linux";

  networking = {
    interface = "eth0";
    mode = "static";
    ipv4 = {
      address = "192.168.1.100";
      prefixLength = 24;
      gateway = "192.168.1.1";
      nameservers = [ "1.1.1.1" "8.8.8.8" ];
    };
  };
}
```

#### default.nix

Main host configuration:

```nix
{ config, pkgs, lib, hostname, username, ... }:

{
  networking.hostName = hostname;
  networking.domain = "example.com";

  # SSH keys
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3Nza... user@local"
  ];

  # Enable services
  services.paas.traefik.enable = true;
  services.paas.vaultwarden.enable = true;
  services.paas.nextcloud.enable = true;

  # Firewall
  networking.firewall.allowedTCPPorts = [ 22 80 443 ];
}
```

### Disk Configuration

Choose one of the pre-defined layouts or create custom:

#### Standard GPT (Simplest)

```nix
diskLayout = "standard-gpt";
```

Partitions:
- 512MB EFI boot
- Remaining space: ext4 root

#### LVM (Flexible)

```nix
diskLayout = "standard-gpt-lvm";
```

Partitions:
- 512MB EFI boot
- 1GB /boot/grub
- LVM PV with:
  - 50GB root
  - 50GB home
  - 30GB var
  - 8GB swap
  - 50GB docker
  - Remaining space free for expansion

#### BTRFS (Advanced Features)

```nix
diskLayout = "btrfs-subvolumes";
```

Subvolumes:
- @ (root) - compressed
- @home - compressed
- @nix - no CoW for performance
- @var - compressed
- @docker - no CoW
- @snapshots - for backups

### Adding Services

Services are enabled in `hosts/<hostname>/default.nix`:

```nix
# Core infrastructure
services.paas.traefik.enable = true;
services.paas.authelia.enable = true;

# Applications
services.paas.nextcloud.enable = true;
services.paas.gitlab.enable = true;
services.paas.jellyfin.enable = true;
services.paas.vaultwarden.enable = true;

# Management
services.paas.homer.enable = true;
services.paas.vikunja.enable = true;
```

---

## Deployment Workflows

### Standard Deployment

```bash
# Basic deployment
./scripts/deploy.sh hostname 192.168.1.100

# With custom SSH key
./scripts/deploy.sh -k ~/.ssh/deploy_key hostname 192.168.1.100

# With debug output
./scripts/deploy.sh --debug hostname 192.168.1.100

# Without reboot (for testing)
./scripts/deploy.sh --no-reboot hostname 192.168.1.100
```

### Tenant-Aware Deployment

Integrates with `ms-config` repository for tenant-specific configuration:

```bash
# Deploy with tenant configuration
./scripts/deploy-tenant.sh production paas-server 192.168.1.100

# Deploy with specific services
./scripts/deploy-tenant.sh \
  --services "traefik,vaultwarden,nextcloud" \
  staging app-server 10.0.0.50

# Deploy to development environment
./scripts/deploy-tenant.sh development dev-server 192.168.1.200
```

### Multi-Host Deployment

Deploy to multiple hosts in parallel:

```bash
# Create deployment script
cat > deploy-all.sh << 'EOF'
#!/bin/bash
./scripts/deploy.sh server1 192.168.1.101 &
./scripts/deploy.sh server2 192.168.1.102 &
./scripts/deploy.sh server3 192.168.1.103 &
wait
EOF

chmod +x deploy-all.sh
./deploy-all.sh
```

### Post-Deployment Updates

After initial deployment, update the system:

```bash
# SSH into the machine
ssh admin@192.168.1.100

# Update system (pull latest flake)
sudo nixos-rebuild switch --flake /etc/nixos --update-input nixpkgs

# Or from local machine
nixos-rebuild switch \
  --flake .#hostname \
  --target-host admin@192.168.1.100
```

---

## Tenant Integration

This configuration integrates with the `ms-config` repository for multi-tenant deployments.

### Tenant Structure

```
ms-config/
└── tenants/
    ├── production/
    │   ├── paas-server/
    │   │   ├── default.nix      # Tenant overrides
    │   │   └── services.nix     # Service configuration
    │   └── backup-server/
    ├── staging/
    │   └── app-server/
    └── development/
        └── dev-server/
```

### Tenant Configuration Files

#### Tenant Override (default.nix)

```nix
# ms-config/tenants/production/paas-server/default.nix
{ config, lib, ... }:

{
  # Production-specific overrides
  networking.domain = "prod.example.com";

  # Production security
  security.sudo.wheelNeedsPassword = true;

  # Production monitoring
  services.prometheus.enable = true;
  services.grafana.enable = true;
}
```

#### Service Configuration (services.nix)

```nix
# ms-config/tenants/production/paas-server/services.nix
{ ... }:

{
  # Enable production services
  services.paas.traefik.enable = true;
  services.paas.authelia.enable = true;
  services.paas.nextcloud.enable = true;
  services.paas.gitlab.enable = true;
  services.paas.vaultwarden.enable = true;
}
```

### How Tenant Configuration Works

1. Flake reads tenant from `variables.nix` or deployment script
2. Looks for config at `ms-config/tenants/${tenant}/${hostname}/`
3. If found, merges tenant config with host config
4. Tenant config can override any settings

### Creating Tenant Configurations

```bash
# Create new tenant
mkdir -p ../../../ms-config/tenants/new-tenant

# Create host-specific configuration
mkdir -p ../../../ms-config/tenants/new-tenant/server1

# Add configuration
cat > ../../../ms-config/tenants/new-tenant/server1/default.nix << 'EOF'
{ config, lib, ... }:

{
  # Tenant-specific configuration
  networking.domain = "new-tenant.example.com";
}
EOF
```

---

## Secret Management

Comprehensive secret management using sops-nix with age encryption.

### Setup Secrets

See [secrets/README.md](secrets/README.md) for detailed documentation.

```bash
# 1. Generate age key
age-keygen -o ~/.config/sops/age/keys.txt

# 2. Update .sops.yaml with public key
nano secrets/.sops.yaml

# 3. Create secrets file from template
cp secrets/secrets.yaml.example secrets/secrets.yaml

# 4. Generate strong secrets
# For passwords
openssl rand -base64 32

# For UUIDs
uuidgen

# For hex secrets
openssl rand -hex 32

# 5. Edit and encrypt
sops secrets/secrets.yaml
```

### Using Secrets in Configuration

```nix
{ config, ... }:

{
  # Define secret
  sops.secrets."vaultwarden/admin_token" = {
    owner = "vaultwarden";
    group = "vaultwarden";
    mode = "0400";
  };

  # Use secret in service configuration
  services.vaultwarden = {
    enable = true;
    environmentFile = config.sops.secrets."vaultwarden/admin_token".path;
  };
}
```

### Secret Rotation

```bash
# 1. Edit secrets
sops secrets/secrets.yaml

# 2. Update affected systems
nixos-rebuild switch \
  --flake .#hostname \
  --target-host root@target-ip

# 3. Restart affected services
ssh root@target-ip "systemctl restart vaultwarden"
```

---

## Troubleshooting

### Common Issues

#### 1. SSH Connection Failed

```bash
# Check connectivity
ping 192.168.1.100

# Test SSH manually
ssh -v root@192.168.1.100

# Check SSH key
ssh-add -l
```

#### 2. Flake Configuration Error

```bash
# Check flake syntax
nix flake check

# Show available configurations
nix flake show

# Build without deploying
nix build .#nixosConfigurations.hostname.config.system.build.toplevel
```

#### 3. Disk Configuration Failed

```bash
# Check disk device name on target
ssh root@target-ip "lsblk"

# Override device in deployment
./scripts/deploy.sh --disk-device /dev/nvme0n1 hostname target-ip
```

#### 4. Secret Decryption Failed

```bash
# Verify age key exists
cat ~/.config/sops/age/keys.txt

# Test decryption locally
sops -d secrets/secrets.yaml

# Check key on target
ssh root@target-ip "cat /var/lib/sops-nix/key.txt"
```

#### 5. Service Won't Start

```bash
# Check service status
ssh root@target-ip "systemctl status service-name"

# View logs
ssh root@target-ip "journalctl -u service-name -n 50"

# Check configuration
ssh root@target-ip "nixos-option services.paas.service-name"
```

### Debugging

#### Enable Debug Mode

```bash
# Full debug output
./scripts/deploy.sh --debug hostname target-ip

# Show Nix build logs
nix build .#nixosConfigurations.hostname.config.system.build.toplevel --print-build-logs
```

#### Check Generated Configuration

```bash
# Build configuration locally
nix build .#nixosConfigurations.hostname.config.system.build.toplevel

# Inspect result
ls -la result/
```

#### Remote Debugging

```bash
# SSH into machine
ssh root@target-ip

# Check system configuration
nixos-option system.build.toplevel

# List generations
nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback if needed
nixos-rebuild switch --rollback
```

---

## Advanced Topics

### Custom Disk Layouts

Create custom disk configuration:

```nix
# disk-configs/custom.nix
{ ... }:

{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            # Your custom partitions
          };
        };
      };
    };
  };
}
```

### Multiple Disk Systems

```nix
disko.devices = {
  disk = {
    ssd = {
      device = "/dev/sda";
      # SSD for OS and databases
    };
    hdd = {
      device = "/dev/sdb";
      # HDD for bulk storage
    };
  };
};
```

### Encrypted Root with LUKS

```nix
root = {
  size = "100%";
  content = {
    type = "luks";
    name = "crypted";
    settings = {
      keyFile = "/tmp/secret.key";
    };
    content = {
      type = "filesystem";
      format = "ext4";
      mountpoint = "/";
    };
  };
};
```

### Custom Service Modules

Add custom service modules to your configuration:

```bash
# Create custom module
mkdir -p modules/custom-service

cat > modules/custom-service/default.nix << 'EOF'
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.custom.myservice;
in {
  options.services.custom.myservice = {
    enable = mkEnableOption "My Custom Service";
    # Add options
  };

  config = mkIf cfg.enable {
    # Service configuration
  };
}
EOF

# Import in flake.nix
modules = commonModules ++ [
  ./modules/custom-service
  # ...
];
```

### Monitoring and Metrics

Enable Prometheus and Grafana:

```nix
{ config, ... }:

{
  services.prometheus = {
    enable = true;
    exporters = {
      node.enable = true;
    };
  };

  services.grafana = {
    enable = true;
    settings = {
      server.http_addr = "0.0.0.0";
      server.http_port = 3000;
    };
  };
}
```

### Automated Backups

Configure Restic backups:

```nix
{ config, ... }:

{
  services.restic.backups = {
    daily = {
      paths = [ "/home" "/var/lib" ];
      repository = "sftp:backup@backup-server:/backups/${config.networking.hostName}";
      passwordFile = config.sops.secrets."backup/restic_password".path;
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };
  };
}
```

---

## References

### Official Documentation

- **nixos-anywhere**: https://nix-community.github.io/nixos-anywhere/
- **disko**: https://github.com/nix-community/disko
- **sops-nix**: https://github.com/Mic92/sops-nix
- **NixOS Manual**: https://nixos.org/manual/nixos/stable/

### Related Project Documentation

- [Main Project README](../../../README.md)
- [Secrets Management Guide](secrets/README.md)
- [Service Modules](../nix-flake/modules/nixos/services/)
- [ms-config Repository](../../../ms-config/)

### Community Resources

- **NixOS Discourse**: https://discourse.nixos.org/
- **NixOS Wiki**: https://wiki.nixos.org/
- **GitHub Discussions**: https://github.com/nix-community/nixos-anywhere/discussions

---

## License

Part of the thesis-szakdoga project. See main project LICENSE for details.

---

## Contributing

This is part of an academic thesis project. For questions or suggestions, please create an issue in the main repository.

---

**Last Updated**: 2025-11-19
**Version**: 1.0.0
