# NixOS Shared Scripts

This directory contains scripts that are useful for **both** NixOS implementations:
- `nix-flake/` - Original declarative configuration
- `nixos-anywhere/` - Remote deployment configuration

## Scripts Overview

### 📊 status.sh
**Universal service status reporting tool**

```bash
./status.sh
```

**What it does:**
- Detects system IP and constructs nip.io domain automatically
- Shows status of all PaaS services (Traefik, Jellyfin, Homer, etc.)
- Displays correct URLs with proper ports (8090 for WSL, 80 for standard)
- Lists network configuration and firewall status
- Shows quick access URLs for all active services

**Features:**
- ✅ Auto-detects WSL vs standard deployment
- ✅ Color-coded output (active, inactive, not-installed)
- ✅ Port conflict detection
- ✅ Works with both implementations

**Usage:**
```bash
# From nix-flake
cd /home/kari/thesis-szakdoga/management-system/nix-solution/nix-flake
./status.sh

# From nixos-anywhere
cd /home/kari/thesis-szakdoga/management-system/nix-solution/nixos-anywhere
./status.sh

# Or from common location
cd /home/kari/thesis-szakdoga/management-system/nix-solution/scripts
./status.sh
```

---

### 🔐 generate_secrets.sh
**Secret generation and sops-nix configuration**

```bash
./generate_secrets.sh
```

**What it does:**
- Generates age keys for sops-nix encryption
- Creates .sops.yaml configuration
- Initializes encrypted secret files for services
- Sets up proper file permissions

**Usage:**
```bash
# Generate secrets for nix-flake
cd /home/kari/thesis-szakdoga/management-system/nix-solution/nix-flake
./generate_secrets.sh

# Generate secrets for nixos-anywhere
cd /home/kari/thesis-szakdoga/management-system/nix-solution/nixos-anywhere
./generate_secrets.sh
```

**Generated files:**
- `.sops.yaml` - Sops configuration
- `secrets/age.key` - Age private key
- Various `secrets/*/secret.yaml` files

---

### 🔧 fix-git-ownership.sh
**Fix Git repository ownership issues in WSL**

```bash
./fix-git-ownership.sh
```

**What it does:**
- Adds safe.directory entries to git config
- Fixes "repository not owned by current user" errors
- Handles cross-WSL mount ownership issues

**When to use:**
- After mounting repositories from different WSL distros
- When switching between root and user operations
- When Git refuses operations due to ownership

**Usage:**
```bash
./fix-git-ownership.sh /path/to/repo
```

---

### ✅ pre-deploy-check.sh
**Pre-deployment validation and checks**

```bash
./pre-deploy-check.sh <hostname>
```

**What it does:**
- Validates flake syntax
- Checks for common configuration errors
- Verifies required files exist
- Tests network connectivity
- Validates hostname configuration

**Usage:**
```bash
./pre-deploy-check.sh wsl-paas
./pre-deploy-check.sh paas-server
```

**Exit codes:**
- `0` - All checks passed, safe to deploy
- `1` - Checks failed, fix errors before deploying

---

### 🧪 test-zsh-config.sh
**Automated zsh configuration testing**

```bash
./test-zsh-config.sh
```

**What it does:**
- Verifies zsh is installed and configured
- Tests shell tool integrations (zoxide, atuin, yazi)
- Validates environment variables
- Checks aliases and functions
- Tests completions and syntax highlighting

**Tests performed:**
- ✅ Zsh installation
- ✅ Completions enabled
- ✅ Autosuggestions working
- ✅ Syntax highlighting active
- ✅ Zoxide integration
- ✅ Atuin integration
- ✅ Yazi wrapper function
- ✅ Starship prompt
- ✅ All aliases defined

**Usage:**
```bash
# Run automated tests
./test-zsh-config.sh

# Example output:
# ✓ Zsh is installed
# ✓ Completions enabled
# ✓ Zoxide available
# ✓ Atuin available
# ✓ All tests passed!
```

---

## Directory Structure

```
nix-solution/
├── scripts/                    # ← Shared scripts (this directory)
│   ├── status.sh               # Service status reporting
│   ├── generate_secrets.sh     # Secret generation
│   ├── fix-git-ownership.sh    # Git ownership fixes
│   ├── pre-deploy-check.sh     # Pre-deployment validation
│   ├── test-zsh-config.sh      # Zsh configuration testing
│   └── README.md               # This file
│
├── nix-flake/                  # Original implementation
│   ├── status.sh → ../scripts/status.sh
│   ├── generate_secrets.sh → ../scripts/generate_secrets.sh
│   └── ...
│
└── nixos-anywhere/             # Remote deployment implementation
    ├── status.sh → ../scripts/status.sh
    ├── generate_secrets.sh → ../scripts/generate_secrets.sh
    ├── fix-git-ownership.sh → ../scripts/fix-git-ownership.sh
    ├── pre-deploy-check.sh → ../scripts/pre-deploy-check.sh
    ├── test-zsh-config.sh → ../scripts/test-zsh-config.sh
    └── ...
```

## How Symlinks Work

Both implementations have **symlinks** pointing to the shared scripts:

```bash
# In nix-flake/
status.sh → ../scripts/status.sh

# In nixos-anywhere/
status.sh → ../scripts/status.sh
```

**Benefits:**
- ✅ Single source of truth - edit once, works everywhere
- ✅ Consistent behavior across implementations
- ✅ Easy maintenance - no duplicate code
- ✅ Automatic updates - change propagates to both implementations

## Adding New Scripts

To add a new shared script:

1. **Create in scripts/ directory:**
   ```bash
   cd /home/kari/thesis-szakdoga/management-system/nix-solution/scripts
   sudo nano new-script.sh
   sudo chmod +x new-script.sh
   ```

2. **Create symlinks in both implementations:**
   ```bash
   cd /home/kari/thesis-szakdoga/management-system/nix-solution
   sudo ln -sf ../scripts/new-script.sh nix-flake/new-script.sh
   sudo ln -sf ../scripts/new-script.sh nixos-anywhere/new-script.sh
   ```

3. **Update this README** with script documentation

## Script Requirements

All scripts in this directory should:
- ✅ Be implementation-agnostic (work with both nix-flake and nixos-anywhere)
- ✅ Have proper shebang (`#!/usr/bin/env bash` or `#!/usr/bin/env nix-shell`)
- ✅ Be executable (`chmod +x`)
- ✅ Include clear usage instructions
- ✅ Use relative paths when possible
- ✅ Handle errors gracefully
- ✅ Provide helpful output

## Best Practices

### Script Portability
```bash
# ✅ Good - Works from any directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ❌ Bad - Assumes current directory
cd ../flake.nix
```

### Error Handling
```bash
# ✅ Good
set -euo pipefail  # Exit on error, undefined vars, pipe failures

# ❌ Bad
# No error handling
```

### User-Friendly Output
```bash
# ✅ Good
echo -e "${GREEN}✓${NC} Service is running"
echo -e "${RED}✗${NC} Service failed"

# ❌ Bad
echo "service ok"
echo "service fail"
```

## Testing Scripts

Before committing changes:

```bash
# Test from nix-flake
cd /home/kari/thesis-szakdoga/management-system/nix-solution/nix-flake
./status.sh

# Test from nixos-anywhere
cd /home/kari/thesis-szakdoga/management-system/nix-solution/nixos-anywhere
./status.sh

# Test from common location
cd /home/kari/thesis-szakdoga/management-system/nix-solution/scripts
./status.sh
```

All three should produce consistent results!

## Troubleshooting

### Symlink not found
```bash
# Check if symlink exists
ls -la nix-flake/status.sh

# Recreate symlink
sudo ln -sf ../scripts/status.sh nix-flake/status.sh
```

### Permission denied
```bash
# Make script executable
sudo chmod +x scripts/status.sh

# Or all scripts
sudo chmod +x scripts/*.sh
```

### Script not working from implementation directory
```bash
# Scripts use relative paths, should work from:
cd nix-flake && ./status.sh        # ✅ Works
cd nixos-anywhere && ./status.sh   # ✅ Works
cd scripts && ./status.sh          # ✅ Works

# But may not work from:
/path/to/random/dir && ./status.sh # ❌ May fail
```

---

**Maintained by:** NixOS PaaS Team
**Last Updated:** 2025-11-25
**Version:** 1.0.0
