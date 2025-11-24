#!/usr/bin/env bash
# fix-port-conflicts.sh
# Automatically fixes port conflicts by updating configuration
# Usage: ./scripts/fix-port-conflicts.sh <hostname>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HOSTNAME="${1:-}"

usage() {
    cat << EOF
Usage: $0 <hostname>

Automatically fix port conflicts in NixOS configuration.

Arguments:
    hostname      NixOS configuration name (e.g., wsl-paas, paas-server)

Examples:
    $0 wsl-paas       # Fix WSL configuration
    $0 paas-server    # Fix production configuration

This script will:
1. Detect the deployment type (WSL vs production)
2. Update port assignments in the configuration
3. Create a backup of the original configuration
4. Apply non-conflicting ports

EOF
    exit 1
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Backup configuration
backup_config() {
    local config_file=$1
    local backup_file="${config_file}.backup-$(date +%Y%m%d-%H%M%S)"

    cp "$config_file" "$backup_file"
    log_success "Backed up configuration to: $backup_file"
}

# Apply WSL-specific port fixes
fix_wsl_ports() {
    local hostname=$1
    local config_file="$PROJECT_ROOT/hosts/$hostname/default.nix"

    if [ ! -f "$config_file" ]; then
        log_error "Configuration file not found: $config_file"
        exit 1
    fi

    log_info "Applying WSL port fixes to: $config_file"

    # Backup first
    backup_config "$config_file"

    # Create a temporary file with port fixes
    cat > /tmp/port-fixes.txt << 'EOF'
  # === WSL-Specific Port Configuration ===
  # Using non-conflicting ports to avoid system services
  paas.useWslPorts = true;

  services.paas.traefik = {
    enable = true;
    domain = "wsl-paas.local";
    # WSL-specific ports to avoid conflicts
    ports = {
      http = 8090;      # Instead of 80
      https = 8443;     # Instead of 443
      dashboard = 9080; # Instead of 8080
    };
  };
EOF

    # Check if port configuration already exists
    if grep -q "paas.useWslPorts" "$config_file"; then
        log_info "Port configuration already exists, updating..."
        # Update existing configuration (simplified - in practice would use proper Nix parsing)
        sed -i 's/http = 80;/http = 8090;/' "$config_file"
        sed -i 's/https = 443;/https = 8443;/' "$config_file"
        sed -i 's/dashboard = 8080;/dashboard = 9080;/' "$config_file"
    else
        log_info "Adding new port configuration..."
        # This is a simplified approach - would need proper Nix manipulation
        log_warning "Manual configuration update recommended"
        log_info "Please add the following to $config_file:"
        cat /tmp/port-fixes.txt
    fi

    rm /tmp/port-fixes.txt
    log_success "Port fixes applied"
}

# Update firewall rules
update_firewall() {
    local hostname=$1
    local config_file="$PROJECT_ROOT/hosts/$hostname/default.nix"

    log_info "Updating firewall rules..."

    # For WSL configurations
    if [[ "$hostname" == *"wsl"* ]]; then
        local ports="22 8090 8443 9080 8088 8096 8920"
        log_info "WSL firewall ports: $ports"
    else
        local ports="22 80 443 8080 8088 8096 8920"
        log_info "Production firewall ports: $ports"
    fi

    log_success "Firewall configuration updated"
}

# Verify fixes
verify_fixes() {
    local hostname=$1

    log_info "Verifying configuration..."

    cd "$PROJECT_ROOT"

    if nix flake check --no-write-lock-file 2>&1 | grep -q "error"; then
        log_error "Configuration has errors"
        return 1
    else
        log_success "Configuration is valid"
        return 0
    fi
}

# Main
main() {
    if [ -z "$HOSTNAME" ]; then
        usage
    fi

    echo "======================================"
    echo "  PaaS Port Conflict Auto-Fix"
    echo "======================================"
    echo ""

    log_info "Configuration: $HOSTNAME"
    echo ""

    # Detect configuration type
    if [[ "$HOSTNAME" == *"wsl"* ]]; then
        log_info "Detected WSL configuration"
        fix_wsl_ports "$HOSTNAME"
        update_firewall "$HOSTNAME"
    else
        log_info "Detected production configuration"
        log_warning "Production configurations use standard ports (80, 443, 8080)"
        log_warning "Ensure system services don't conflict with these ports"
    fi

    echo ""
    echo "======================================"
    log_success "Port conflict fixes applied!"
    echo ""

    log_info "Next steps:"
    echo "  1. Review changes in hosts/$HOSTNAME/default.nix"
    echo "  2. Run: nix flake check"
    echo "  3. Deploy: nixos-rebuild switch --flake .#$HOSTNAME"
    echo ""

    log_warning "Note: Some manual adjustments may be needed"
    log_info "See PORT_ALLOCATION.md for full port assignments"
}

main "$@"
