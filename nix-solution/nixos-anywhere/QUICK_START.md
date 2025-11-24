# NixOS-Anywhere Quick Start Guide

A rapid deployment guide for getting started with nixos-anywhere in your thesis project.

## 🚀 30-Second Overview

```bash
cd /home/kari/thesis-szakdoga/management-system/nix-solution/nixos-anywhere

# 1. Enter dev environment
nix develop

# 2. Setup secrets
age-keygen -o ~/.config/sops/age/keys.txt
cp secrets/secrets.yaml.example secrets/secrets.yaml
sops -e -i secrets/secrets.yaml

# 3. Deploy
./scripts/deploy.sh paas-server 192.168.1.100
```

## 📁 What Was Created

```
nixos-anywhere/
├── flake.nix                    # Main configuration with tenant support
├── common/                      # Shared modules (base, security, networking, users)
├── disk-configs/                # 3 disk layouts (GPT, LVM, BTRFS)
├── hosts/                       # Host configurations
│   ├── template/                # Template for new hosts
│   ├── paas-server/             # Production example
│   ├── dev-server/              # Development example
│   └── staging-server/          # Staging example
├── secrets/                     # sops-nix secret management
└── scripts/                     # Deployment automation
    ├── deploy.sh                # Standard deployment
    ├── deploy-tenant.sh         # Tenant-aware deployment
    └── generate-host.sh         # Create new host config
```

## ⚡ Quick Deployment Steps

### 1. Initial Setup (One-time)

```bash
# Generate encryption key
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt

# View public key and update secrets/.sops.yaml
cat ~/.config/sops/age/keys.txt | grep "public key:"

# Edit .sops.yaml with your public key
nano secrets/.sops.yaml

# Create and encrypt secrets
cp secrets/secrets.yaml.example secrets/secrets.yaml
# Replace all REPLACE_WITH_ACTUAL_* values
nano secrets/secrets.yaml
sops -e -i secrets/secrets.yaml
```

### 2. Generate SSH Key for Deployment

```bash
ssh-keygen -t ed25519 -C "nixos-deployment" -f ~/.ssh/id_ed25519_nixos
cat ~/.ssh/id_ed25519_nixos.pub  # Copy this
```

### 3. Create New Host

```bash
# Option A: Use generator
./scripts/generate-host.sh my-server

# Option B: Copy template manually
cp -r hosts/template hosts/my-server

# Edit configuration
nano hosts/my-server/variables.nix
nano hosts/my-server/default.nix
# Add your SSH public key to default.nix
```

### 4. Add to Flake

Edit `flake.nix`:

```nix
nixosConfigurations = {
  # Add after existing configs
  my-server = mkTenantHost {
    hostname = "my-server";
    tenant = "production";           # Links to ms-config/tenants/production/
    system = "x86_64-linux";
    diskLayout = "standard-gpt";     # or "standard-gpt-lvm" or "btrfs-subvolumes"
    username = "admin";
  };
};
```

### 5. Deploy!

```bash
# Standard deployment
./scripts/deploy.sh my-server 192.168.1.100

# With tenant integration
./scripts/deploy-tenant.sh production my-server 192.168.1.100

# With debug output
./scripts/deploy.sh --debug my-server 192.168.1.100

# With custom SSH key
./scripts/deploy.sh -k ~/.ssh/id_ed25519_nixos my-server 192.168.1.100
```

## 🎯 Common Use Cases

### Deploy Production PaaS Server

```bash
# 1. Use existing paas-server configuration
nano hosts/paas-server/default.nix  # Add SSH keys

# 2. Deploy
./scripts/deploy-tenant.sh production paas-server 192.168.1.100
```

### Deploy with Specific Services

```bash
./scripts/deploy-tenant.sh \
  --services "traefik,vaultwarden,nextcloud,jellyfin" \
  production media-server 192.168.1.101
```

### Deploy Development Server

```bash
./scripts/deploy-tenant.sh development dev-server 192.168.1.200
```

### Deploy with Static IP

Edit `hosts/my-server/variables.nix`:

```nix
{
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

## 🔧 Available Disk Layouts

### Standard GPT (Simple)
```nix
diskLayout = "standard-gpt";
```
- 512MB EFI boot
- Rest: ext4 root

### LVM (Flexible)
```nix
diskLayout = "standard-gpt-lvm";
```
- 512MB EFI
- 50GB root, 50GB home, 30GB var
- 8GB swap, 50GB docker
- Free space for expansion

### BTRFS (Advanced)
```nix
diskLayout = "btrfs-subvolumes";
```
- BTRFS with compression
- Subvolumes: root, home, nix, var, docker
- Snapshot support

## 🔐 Secret Management Quick Reference

```bash
# Edit secrets (auto-decrypt/encrypt)
sops secrets/secrets.yaml

# View secrets (read-only)
sops -d secrets/secrets.yaml

# Generate strong password
openssl rand -base64 32

# Generate UUID
uuidgen

# Generate htpasswd hash
htpasswd -nb admin password
```

## 🐛 Quick Troubleshooting

### Can't Connect to Target

```bash
# Test SSH manually
ssh -v root@192.168.1.100

# Check if SSH key is loaded
ssh-add -l
```

### Flake Error

```bash
# Check syntax
nix flake check

# Show available configs
nix flake show
```

### Wrong Disk Device

```bash
# Check device name on target
ssh root@target "lsblk"

# Override in deployment
./scripts/deploy.sh --disk-device /dev/nvme0n1 hostname ip
```

### Secret Won't Decrypt

```bash
# Verify age key exists
cat ~/.config/sops/age/keys.txt

# Test decryption
sops -d secrets/secrets.yaml
```

## 🔗 Tenant Integration

This configuration automatically loads tenant-specific settings from:

```
ms-config/tenants/
├── production/
│   └── paas-server/
│       ├── default.nix      # Overrides
│       └── services.nix     # Service configs
├── staging/
└── development/
```

Create tenant config:

```bash
mkdir -p ../../../ms-config/tenants/production/my-server

cat > ../../../ms-config/tenants/production/my-server/default.nix << 'EOF'
{ ... }:
{
  networking.domain = "prod.example.com";
  services.paas.traefik.enable = true;
  services.paas.vaultwarden.enable = true;
}
EOF
```

## 📚 Service Module Reference

All services from `../nix-flake/modules/nixos/services/` are available:

```nix
# In hosts/my-server/default.nix
services.paas = {
  # Infrastructure
  traefik.enable = true;
  authelia.enable = true;
  homer.enable = true;

  # Storage
  nextcloud.enable = true;
  seafile.enable = true;

  # Development
  gitlab.enable = true;
  gitea.enable = true;

  # Media
  jellyfin.enable = true;
  immich.enable = true;

  # Management
  vaultwarden.enable = true;
  vikunja.enable = true;
  firefly-iii.enable = true;

  # Automation
  radarr.enable = true;
  sonarr.enable = true;
};
```

## 🎓 Learning Resources

- **Full Documentation**: See [README.md](README.md)
- **Secrets Guide**: See [secrets/README.md](secrets/README.md)
- **nixos-anywhere Docs**: https://nix-community.github.io/nixos-anywhere/
- **Disko Examples**: https://github.com/nix-community/disko
- **sops-nix Guide**: https://github.com/Mic92/sops-nix

## 📝 Next Steps

1. ✅ Customize host configurations
2. ✅ Set up proper secrets
3. ✅ Configure tenant-specific settings
4. ✅ Deploy to test environment first
5. ✅ Verify services are running
6. ✅ Set up monitoring
7. ✅ Configure backups
8. ✅ Deploy to production

## 💡 Pro Tips

- **Test in dev first**: Always test changes in `dev-server` before `paas-server`
- **Use static IPs for production**: Configure in `variables.nix`
- **Enable monitoring**: Add Prometheus + Grafana for production
- **Set up backups**: Configure Restic for automated backups
- **Use LVM for production**: Easier to resize partitions later
- **Keep secrets updated**: Rotate secrets regularly
- **Document changes**: Update tenant configs in ms-config

---

**Ready to deploy?** Start with the paas-server example:

```bash
cd /home/kari/thesis-szakdoga/management-system/nix-solution/nixos-anywhere
nix develop
./scripts/deploy.sh --help
```

---

**Need help?** Check [README.md](README.md) for comprehensive documentation.
