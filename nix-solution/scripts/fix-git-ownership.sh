#!/usr/bin/env bash
# Fix Git ownership issues for nixos-rebuild on NixOS WSL
# Run this script with sudo on your NixOS WSL instance

set -euo pipefail

echo "=== NixOS WSL Git Ownership Fix ==="
echo ""

# Detect the repository path
REPO_PATH="${1:-/mnt/thesis-szakdoga/management-system}"

if [ ! -d "$REPO_PATH" ]; then
    echo "ERROR: Repository not found at: $REPO_PATH"
    echo "Usage: sudo $0 [REPO_PATH]"
    echo "Example: sudo $0 /mnt/thesis-szakdoga/management-system"
    exit 1
fi

echo "Repository path: $REPO_PATH"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run with sudo"
    echo "Usage: sudo $0"
    exit 1
fi

# Add safe directories for root user
echo "Adding Git safe directories for root user..."
git config --global --add safe.directory "$REPO_PATH"
git config --global --add safe.directory "$REPO_PATH/.git"
git config --global --add safe.directory '*'

# Verify configuration
echo ""
echo "Current safe directories for root:"
git config --global --get-all safe.directory || echo "None configured"

echo ""
echo "=== Fix applied successfully! ==="
echo ""
echo "You can now run:"
echo "  cd $REPO_PATH/nix-solution/nixos-anywhere"
echo "  sudo nixos-rebuild switch --flake .#wsl-paas"
echo ""
