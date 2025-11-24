# Local Testing Guide for nixos-anywhere

This guide shows how to test your nixos-anywhere configurations locally before deploying to real hardware.

## Quick Testing Matrix

| Method | Speed | Coverage | Best For |
|--------|-------|----------|----------|
| Flake Check | ⚡ Fast (10s) | Syntax only | Quick validation |
| Build Test | 🚀 Medium (1-5min) | Build verification | Config testing |
| VM Deploy | 🐢 Slow (10-30min) | Full deployment | Complete testing |
| NixOS Rebuild | ⚡ Fast (1-2min) | Live testing | If on NixOS |

---

## Method 1: Flake Validation (Quickest)

**Time: ~10 seconds**
**Tests: Syntax, imports, basic structure**

```bash
cd /home/kari/thesis-szakdoga/management-system/nix-solution/nixos-anywhere

# Check flake syntax and structure
nix flake check --no-write-lock-file

# Show available configurations
nix flake show

# Check specific host exists
nix flake show | grep paas-server
```

**What this catches:**
- Syntax errors
- Missing imports
- Broken module paths
- Invalid Nix expressions

**What this DOESN'T catch:**
- Runtime issues
- Service configuration errors
- Disk partitioning problems

---

## Method 2: Build Configuration (Recommended for Quick Validation)

**Time: 1-5 minutes**
**Tests: Full configuration build without deployment**

```bash
cd /home/kari/thesis-szakdoga/management-system/nix-solution/nixos-anywhere

# Build template configuration
nix build .#nixosConfigurations.template.config.system.build.toplevel

# Build paas-server configuration
nix build .#nixosConfigurations.paas-server.config.system.build.toplevel

# Build with detailed error output
nix build .#nixosConfigurations.paas-server.config.system.build.toplevel \
    --show-trace \
    --verbose

# Check what services would be enabled
nix eval .#nixosConfigurations.paas-server.config.services.paas --apply builtins.attrNames

# Verify disk configuration builds
nix build .#nixosConfigurations.template.config.disko.devices
```

**What this catches:**
- All syntax errors
- Module conflicts
- Package availability
- Service configuration errors
- Most configuration issues

**What this DOESN'T catch:**
- Disk partitioning in practice
- Network configuration in real environment
- Service runtime issues
- Hardware-specific problems

**Example output if successful:**
```
/nix/store/xxxxx-nixos-system-template-24.11.git.xxxxx
```

---

## Method 3: VM Testing (Most Comprehensive)

**Time: 10-30 minutes**
**Tests: Full deployment in isolated VM**

### 3A: Simple VM Test (No nixos-anywhere)

Test the configuration in a local NixOS VM:

```bash
cd /home/kari/thesis-szakdoga/management-system/nix-solution/nixos-anywhere

# Create a VM configuration
nix run .#nixosConfigurations.template.config.system.build.vm

# Or build VM image
nix build .#nixosConfigurations.template.config.system.build.vmWithBootLoader

# Run the VM
./result/bin/run-*-vm
```

**Limitations:**
- Doesn't test disko (disk partitioning)
- Doesn't test nixos-anywhere deployment
- Simplified environment

### 3B: Full nixos-anywhere VM Test (Recommended)

Test the complete deployment process using the script I created:

```bash
cd /home/kari/thesis-szakdoga/management-system/nix-solution/nixos-anywhere

# Install QEMU if not already installed (on NixOS WSL)
nix-env -iA nixpkgs.qemu_kvm

# 1. Create and start a test VM
./scripts/test-local-vm.sh start template 20G

# 2. Manually boot the VM and set root password
#    (The VM will open a console - follow NixOS installer prompts)

# 3. Deploy your configuration to the VM
./scripts/test-local-vm.sh deploy template

# 4. SSH into the deployed system
ssh -p 2222 root@localhost

# 5. Stop the VM when done
./scripts/test-local-vm.sh stop template

# 6. Clean up all VM files
./scripts/test-local-vm.sh cleanup template
```

**What this tests:**
- Full nixos-anywhere deployment process
- Disko disk partitioning
- Service activation
- Network configuration
- Secret management
- Everything except real hardware

---

## Method 4: Test on NixOS WSL (If You're Already Running NixOS)

**Time: 1-2 minutes**
**Tests: Live configuration on your current system**

If your NixOS WSL is running, you can test parts of the configuration:

```bash
cd /home/kari/thesis-szakdoga/management-system/nix-solution/nixos-anywhere

# Test specific modules
sudo nixos-rebuild test --flake .#wsl

# Just build without activating
sudo nixos-rebuild build --flake .#wsl

# Dry run to see what would change
sudo nixos-rebuild dry-run --flake .#wsl

# Build VM from WSL config
nix build .#nixosConfigurations.wsl.config.system.build.vm
```

**⚠️ Warning:** Only use this if you have a WSL configuration defined in your flake!

---

## Method 5: Test Individual Components

Test specific parts of your configuration in isolation:

### Test Disk Configuration

```bash
# Check disko configuration syntax
nix eval .#nixosConfigurations.template.config.disko.devices --json | jq

# Simulate disk partitioning (doesn't actually partition)
nix run github:nix-community/disko -- --mode dryRun \
    --flake .#template
```

### Test Service Modules

```bash
# Check if Traefik module loads
nix eval .#nixosConfigurations.paas-server.config.services.paas.traefik --json

# Verify service dependencies
nix eval .#nixosConfigurations.paas-server.config.systemd.services --apply 'x: builtins.attrNames x' | grep traefik

# Test if secrets are properly configured
nix eval .#nixosConfigurations.paas-server.config.sops --json
```

### Test Secrets

```bash
cd /home/kari/thesis-szakdoga/management-system/nix-solution/nixos-anywhere

# Verify sops can decrypt your secrets
sops -d secrets/secrets.yaml

# Check age key exists
test -f ~/.config/sops/age/keys.txt && echo "Age key found" || echo "Age key missing"

# Verify .sops.yaml is valid
cat secrets/.sops.yaml
```

---

## Recommended Testing Workflow

### For Quick Changes (Config Tweaks)

```bash
# 1. Quick syntax check
nix flake check --no-write-lock-file

# 2. Build to verify no errors
nix build .#nixosConfigurations.template.config.system.build.toplevel

# Time: ~1-2 minutes
```

### For Service Changes (New Services, Module Updates)

```bash
# 1. Syntax check
nix flake check --no-write-lock-file

# 2. Build configuration
nix build .#nixosConfigurations.paas-server.config.system.build.toplevel --show-trace

# 3. Verify services
nix eval .#nixosConfigurations.paas-server.config.services.paas --apply builtins.attrNames

# Time: ~3-5 minutes
```

### For Major Changes (Disk layouts, Network, Secrets)

```bash
# 1. Full build test
nix build .#nixosConfigurations.template.config.system.build.toplevel --show-trace

# 2. VM deployment test
./scripts/test-local-vm.sh start template 20G
# ... follow VM deployment steps ...

# Time: ~20-30 minutes
```

### Before Production Deployment

```bash
# 1. Syntax check
nix flake check

# 2. Build test
nix build .#nixosConfigurations.paas-server.config.system.build.toplevel

# 3. VM test deployment
./scripts/test-local-vm.sh start paas-server 50G
./scripts/test-local-vm.sh deploy paas-server

# 4. Verify services in VM
ssh -p 2222 root@localhost "systemctl status traefik"

# 5. Test from staging first
./scripts/deploy-tenant.sh staging staging-server 192.168.1.200

# 6. Deploy to production
./scripts/deploy-tenant.sh production paas-server 192.168.1.100

# Time: ~1 hour (but saves hours of debugging in production)
```

---

## Common Test Scenarios

### Scenario 1: Testing a New Host Configuration

```bash
# Create new host
./scripts/generate-host.sh my-test-server

# Test build
nix build .#nixosConfigurations.my-test-server.config.system.build.toplevel

# Test in VM
./scripts/test-local-vm.sh start my-test-server 20G
./scripts/test-local-vm.sh deploy my-test-server
```

### Scenario 2: Testing Service Enablement

```bash
# Enable a service in hosts/template/default.nix
# services.paas.jellyfin.enable = true;

# Build to verify
nix build .#nixosConfigurations.template.config.system.build.toplevel

# Check service is actually enabled
nix eval .#nixosConfigurations.template.config.services.jellyfin.enable
# Should output: true

# Verify service file exists
nix build .#nixosConfigurations.template.config.system.build.toplevel
ls -la result/etc/systemd/system/ | grep jellyfin
```

### Scenario 3: Testing Disk Layouts

```bash
# Test standard GPT
nix build .#nixosConfigurations.template.config.disko.devices
cat result | jq '.disk'

# Test LVM layout
nix build .#nixosConfigurations.paas-server.config.disko.devices
cat result | jq '.disk'

# Dry run disko
nix run github:nix-community/disko -- --mode dryRun --flake .#template
```

### Scenario 4: Testing Tenant Integration

```bash
# Create tenant config
mkdir -p ../../../ms-config/tenants/test/template
cat > ../../../ms-config/tenants/test/template/default.nix << 'EOF'
{ ... }: {
  networking.domain = "test.local";
  services.paas.traefik.enable = true;
}
EOF

# Build with tenant config
nix build .#nixosConfigurations.template.config.system.build.toplevel

# Verify tenant settings applied
nix eval .#nixosConfigurations.template.config.networking.domain
# Should output: "test.local"
```

---

## Troubleshooting Test Failures

### Build Fails with "does not exist"

```bash
# Check the exact error path
nix build .#nixosConfigurations.template.config.system.build.toplevel --show-trace

# Verify all imports exist
find . -name "*.nix" -exec nix-instantiate --parse {} \; > /dev/null
```

### VM Won't Start

```bash
# Check QEMU is installed
qemu-system-x86_64 --version

# Install if missing
nix-env -iA nixpkgs.qemu_kvm

# Check VM directory
ls -la .vm-test/
```

### Secrets Won't Decrypt

```bash
# Verify age key exists
cat ~/.config/sops/age/keys.txt

# Test decryption manually
sops -d secrets/secrets.yaml

# Check .sops.yaml has correct public key
grep public secrets/.sops.yaml
```

### Service Module Not Found

```bash
# Verify module file exists
ls -la ../nix-flake/modules/nixos/services/

# Check flake imports the module
grep "modules/nixos/services" flake.nix

# Test module loads
nix eval .#nixosConfigurations.template.config.services.paas --json
```

---

## CI/CD Integration (Future)

For automated testing in CI/CD:

```yaml
# .github/workflows/test-nixos.yml
name: Test NixOS Configurations

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: cachix/install-nix-action@v20

      - name: Check flake
        run: nix flake check

      - name: Build all configurations
        run: |
          nix build .#nixosConfigurations.template.config.system.build.toplevel
          nix build .#nixosConfigurations.paas-server.config.system.build.toplevel
          nix build .#nixosConfigurations.dev-server.config.system.build.toplevel
```

---

## Summary

**Quick validation:**
```bash
nix flake check && nix build .#nixosConfigurations.template.config.system.build.toplevel
```

**Full testing:**
```bash
./scripts/test-local-vm.sh start template 20G
./scripts/test-local-vm.sh deploy template
```

**Ready for production when:**
- ✅ `nix flake check` passes
- ✅ `nix build` succeeds for all hosts
- ✅ VM deployment test completes
- ✅ Services start in VM
- ✅ Staging deployment successful

---

**Next Steps:**
1. Run quick validation now
2. Set up VM testing environment
3. Test your configuration before first deployment
4. Keep this guide handy for future changes
