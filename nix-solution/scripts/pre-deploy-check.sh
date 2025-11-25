#!/usr/bin/env bash
# Pre-deployment environment check for NixOS WSL
# Run this before deploying to catch common issues

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track overall status
CHECKS_PASSED=0
CHECKS_FAILED=0

echo "=== NixOS WSL Pre-Deployment Check ==="
echo ""

# Helper functions
check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((CHECKS_PASSED++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((CHECKS_FAILED++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check 1: Running on NixOS
echo "Checking system..."
if grep -q "ID=nixos" /etc/os-release 2>/dev/null; then
    check_pass "Running on NixOS"
else
    check_fail "Not running on NixOS (current: $(grep ^ID= /etc/os-release 2>/dev/null || echo 'unknown'))"
fi

# Check 2: Running with sufficient privileges
if [ "$EUID" -eq 0 ]; then
    check_pass "Running as root (via sudo)"
elif groups | grep -q wheel; then
    check_pass "User is in wheel group (can use sudo)"
else
    check_fail "Not running as root and user not in wheel group"
fi

# Check 3: Repository path exists
REPO_PATH="${1:-/mnt/thesis-szakdoga/management-system}"
if [ -d "$REPO_PATH" ]; then
    check_pass "Repository found at: $REPO_PATH"
else
    check_fail "Repository not found at: $REPO_PATH"
    check_warn "  Specify path as argument: $0 /path/to/repo"
fi

# Check 4: Flake directory exists
FLAKE_DIR="$REPO_PATH/nix-solution/nixos-anywhere"
if [ -d "$FLAKE_DIR" ]; then
    check_pass "Flake directory exists: $FLAKE_DIR"
else
    check_fail "Flake directory not found: $FLAKE_DIR"
fi

# Check 5: flake.nix exists
if [ -f "$FLAKE_DIR/flake.nix" ]; then
    check_pass "flake.nix found"
else
    check_fail "flake.nix not found in $FLAKE_DIR"
fi

# Check 6: Git is installed
if command -v git &> /dev/null; then
    check_pass "Git is installed ($(git --version))"
else
    check_fail "Git is not installed"
fi

# Check 7: Nix flakes are available
if command -v nix &> /dev/null; then
    check_pass "Nix is installed"

    # Check if flakes are enabled
    if nix flake --version &> /dev/null; then
        check_pass "Nix flakes are enabled"
    else
        check_fail "Nix flakes are not enabled"
        check_warn "  Add to /etc/nixos/configuration.nix: nix.settings.experimental-features = [ \"nix-command\" \"flakes\" ];"
    fi
else
    check_fail "Nix is not installed"
fi

# Check 8: Git safe directory configured (for root)
if [ "$EUID" -eq 0 ] || sudo -n true 2>/dev/null; then
    SAFE_DIRS=$(sudo git config --global --get-all safe.directory 2>/dev/null || echo "")
    if echo "$SAFE_DIRS" | grep -q "$REPO_PATH\|^\*$"; then
        check_pass "Git safe.directory configured for root"
    else
        check_fail "Git safe.directory NOT configured for root"
        check_warn "  Run: sudo git config --global --add safe.directory $REPO_PATH"
        check_warn "  Or:  sudo git config --global --add safe.directory '*'"
    fi
fi

# Check 9: Git repository is accessible
if [ -d "$REPO_PATH/.git" ]; then
    if sudo git -C "$REPO_PATH" status &> /dev/null; then
        check_pass "Git repository is accessible as root"
    else
        check_fail "Cannot access Git repository as root"
        check_warn "  This is likely the Git ownership issue"
    fi
else
    check_warn "Not a Git repository (no .git directory)"
fi

# Check 10: Service modules exist
SERVICE_MODULES="$REPO_PATH/nix-solution/nix-flake/modules/nixos/services"
if [ -d "$SERVICE_MODULES" ]; then
    MODULE_COUNT=$(find "$SERVICE_MODULES" -name "*.nix" -type f | wc -l)
    check_pass "Service modules found: $MODULE_COUNT modules"
else
    check_fail "Service modules directory not found: $SERVICE_MODULES"
fi

# Check 11: wsl-paas host config exists
WSL_CONFIG="$FLAKE_DIR/hosts/wsl-paas/default.nix"
if [ -f "$WSL_CONFIG" ]; then
    check_pass "wsl-paas configuration found"
else
    check_fail "wsl-paas configuration not found: $WSL_CONFIG"
fi

# Check 12: Disk space
AVAILABLE_SPACE=$(df -BG "$FLAKE_DIR" | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -gt 10 ]; then
    check_pass "Sufficient disk space: ${AVAILABLE_SPACE}GB available"
elif [ "$AVAILABLE_SPACE" -gt 5 ]; then
    check_warn "Low disk space: ${AVAILABLE_SPACE}GB available (consider cleanup)"
else
    check_fail "Insufficient disk space: ${AVAILABLE_SPACE}GB available (need at least 5GB)"
fi

# Check 13: Network connectivity
if ping -c 1 -W 2 cache.nixos.org &> /dev/null; then
    check_pass "Network connectivity to cache.nixos.org"
else
    check_warn "Cannot reach cache.nixos.org (builds may be slower)"
fi

# Summary
echo ""
echo "=== Summary ==="
echo -e "Passed: ${GREEN}${CHECKS_PASSED}${NC}"
echo -e "Failed: ${RED}${CHECKS_FAILED}${NC}"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Ready to deploy.${NC}"
    echo ""
    echo "Run deployment with:"
    echo "  cd $FLAKE_DIR"
    echo "  sudo nixos-rebuild switch --flake .#wsl-paas"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Fix the issues above before deploying.${NC}"
    echo ""
    echo "Common fixes:"
    echo "1. Git ownership: sudo git config --global --add safe.directory '$REPO_PATH'"
    echo "2. Enable flakes: Add to /etc/nixos/configuration.nix:"
    echo "   nix.settings.experimental-features = [ \"nix-command\" \"flakes\" ];"
    echo "3. Install dependencies: nix-shell -p git nix"
    echo ""
    exit 1
fi
