#!/usr/bin/env bash
# check-port-conflicts.sh
# Checks for port conflicts before NixOS deployment
# Usage: ./scripts/check-port-conflicts.sh <hostname> [target-host]

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
TARGET_HOST="${2:-localhost}"
CONFLICTS_FOUND=0

usage() {
    cat << EOF
Usage: $0 <hostname> [target-host]

Check for port conflicts before deployment.

Arguments:
    hostname      NixOS configuration name (e.g., wsl-paas, paas-server)
    target-host   Target system to check (default: localhost)
                  Can be: localhost, user@ip, or ssh alias

Examples:
    $0 wsl-paas                    # Check localhost
    $0 wsl-paas nixos@172.26.159.132  # Check remote system
    $0 paas-server root@192.168.1.100 # Check production server

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

# Get ports that will be used by the configuration
get_config_ports() {
    local hostname=$1

    log_info "Analyzing configuration for: $hostname"

    # Extract port assignments from the flake configuration
    # This is a simplified version - could be enhanced to parse Nix output

    case "$hostname" in
        wsl-paas|*-wsl*)
            echo "8090 8443 9080 8088 8096 8920"  # WSL ports
            ;;
        *)
            echo "80 443 8080 8088 8096 8920"  # Standard ports
            ;;
    esac
}

# Check if ports are in use on target system
check_ports_on_target() {
    local target=$1
    shift
    local ports=("$@")

    log_info "Checking ports on target: $target"

    local check_cmd="sudo ss -tulpn | grep LISTEN"
    local port_output

    if [ "$target" = "localhost" ]; then
        port_output=$(eval "$check_cmd" 2>/dev/null || true)
    else
        port_output=$(ssh "$target" "$check_cmd" 2>/dev/null || true)
    fi

    for port in "${ports[@]}"; do
        if echo "$port_output" | grep -q ":${port} "; then
            local process=$(echo "$port_output" | grep ":${port} " | awk '{print $7}' | head -1)
            log_error "Port $port is already in use by: ${process:-unknown}"
            CONFLICTS_FOUND=$((CONFLICTS_FOUND + 1))
        else
            log_success "Port $port is available"
        fi
    done
}

# Get recommended ports for the configuration
get_recommendations() {
    local hostname=$1

    echo ""
    log_info "Recommendations for $hostname:"
    echo ""

    case "$hostname" in
        wsl-paas|*-wsl*)
            cat << EOF
WSL Configuration detected. Using non-conflicting ports:

  Traefik HTTP:      8090  (instead of 80)
  Traefik HTTPS:     8443  (instead of 443)
  Traefik Dashboard: 9080  (instead of 8080)
  Homer:             8088
  Jellyfin HTTP:     8096
  Jellyfin HTTPS:    8920

Access services at:
  - http://172.26.159.132:9080  (Traefik Dashboard)
  - http://172.26.159.132:8088  (Homer)
  - http://172.26.159.132:8096  (Jellyfin)
EOF
            ;;
        *)
            cat << EOF
Production Configuration detected. Using standard ports:

  Traefik HTTP:      80
  Traefik HTTPS:     443
  Traefik Dashboard: 8080
  Homer:             8088
  Jellyfin HTTP:     8096
  Jellyfin HTTPS:    8920

Make sure these ports are not used by system services!
EOF
            ;;
    esac
}

# Find processes using conflicted ports
show_port_users() {
    local target=$1

    echo ""
    log_info "Current port usage on $target:"
    echo ""

    local cmd="sudo ss -tulpn | grep LISTEN | awk '{print \$5, \$7}' | column -t"

    if [ "$target" = "localhost" ]; then
        eval "$cmd" 2>/dev/null || log_warning "Could not retrieve port information"
    else
        ssh "$target" "$cmd" 2>/dev/null || log_warning "Could not retrieve port information"
    fi
}

# Main
main() {
    if [ -z "$HOSTNAME" ]; then
        usage
    fi

    echo "======================================"
    echo "  PaaS Port Conflict Checker"
    echo "======================================"
    echo ""

    log_info "Configuration: $HOSTNAME"
    log_info "Target system: $TARGET_HOST"
    echo ""

    # Get ports from configuration
    read -ra CONFIG_PORTS <<< "$(get_config_ports "$HOSTNAME")"

    log_info "Ports to be used: ${CONFIG_PORTS[*]}"
    echo ""

    # Check ports
    check_ports_on_target "$TARGET_HOST" "${CONFIG_PORTS[@]}"

    echo ""
    echo "======================================"

    if [ $CONFLICTS_FOUND -eq 0 ]; then
        log_success "No port conflicts detected! Safe to deploy."
        get_recommendations "$HOSTNAME"
        exit 0
    else
        log_error "Found $CONFLICTS_FOUND port conflict(s)!"
        echo ""
        show_port_users "$TARGET_HOST"
        get_recommendations "$HOSTNAME"
        echo ""
        log_warning "Fix conflicts before deployment:"
        echo "  1. Stop services using conflicted ports"
        echo "  2. Run: ./scripts/fix-port-conflicts.sh $HOSTNAME"
        echo "  3. Or manually edit: hosts/$HOSTNAME/default.nix"
        echo ""
        exit 1
    fi
}

main "$@"
