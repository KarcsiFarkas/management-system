#!/usr/bin/env bash
# Tenant-aware deployment script
# Integrates with ms-config repository for tenant-specific configurations

set -euo pipefail

# === Script Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MS_CONFIG_ROOT="$(cd "$PROJECT_ROOT/../../../ms-config" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# === Functions ===
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] <tenant> <hostname> <target-ip>

Deploy NixOS with tenant-specific configuration

ARGUMENTS:
    tenant          Tenant identifier (from ms-config/tenants/)
    hostname        Host configuration name
    target-ip       Target machine IP address or hostname

OPTIONS:
    -u, --user USER         SSH user (default: root)
    -k, --ssh-key PATH      Path to SSH private key
    -d, --debug             Enable debug output
    --services "svc1,svc2"  Comma-separated list of services to enable
    -h, --help              Show this help message

EXAMPLES:
    # Deploy production tenant configuration
    $0 production paas-server 192.168.1.100

    # Deploy with specific services
    $0 --services "traefik,vaultwarden,nextcloud" staging app-server 10.0.0.50

    # Deploy with custom SSH key
    $0 -k ~/.ssh/deploy_key development dev-server 192.168.1.200

EOF
}

# === Argument Parsing ===
SSH_USER="root"
SSH_KEY=""
DEBUG=false
SERVICES=""
TENANT=""
HOSTNAME=""
TARGET_IP=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--user)
            SSH_USER="$2"
            shift 2
            ;;
        -k|--ssh-key)
            SSH_KEY="$2"
            shift 2
            ;;
        -d|--debug)
            DEBUG=true
            shift
            ;;
        --services)
            SERVICES="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            if [[ -z "$TENANT" ]]; then
                TENANT="$1"
            elif [[ -z "$HOSTNAME" ]]; then
                HOSTNAME="$1"
            elif [[ -z "$TARGET_IP" ]]; then
                TARGET_IP="$1"
            else
                log_error "Too many arguments"
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$TENANT" ]] || [[ -z "$HOSTNAME" ]] || [[ -z "$TARGET_IP" ]]; then
    log_error "Missing required arguments"
    show_usage
    exit 1
fi

# === Tenant Configuration Checks ===
log_info "Deploying tenant '$TENANT' configuration '$HOSTNAME' to $TARGET_IP"

TENANT_DIR="$MS_CONFIG_ROOT/tenants/$TENANT"

if [[ ! -d "$TENANT_DIR" ]]; then
    log_error "Tenant directory not found: $TENANT_DIR"
    log_info "Available tenants:"
    ls -1 "$MS_CONFIG_ROOT/tenants/" 2>/dev/null || log_warning "No tenants found"
    exit 1
fi

log_info "Tenant directory: $TENANT_DIR"

# Check for tenant-specific host configuration
TENANT_HOST_CONFIG="$TENANT_DIR/$HOSTNAME"
if [[ -d "$TENANT_HOST_CONFIG" ]]; then
    log_success "Found tenant-specific configuration for $HOSTNAME"
else
    log_warning "No tenant-specific configuration found for $HOSTNAME"
    log_info "Using default host configuration"
fi

# === Generate or Update Tenant Configuration ===
if [[ -n "$SERVICES" ]]; then
    log_info "Updating tenant configuration with services: $SERVICES"

    # Create tenant configuration if it doesn't exist
    mkdir -p "$TENANT_HOST_CONFIG"

    # Generate services configuration
    cat > "$TENANT_HOST_CONFIG/services.nix" << EOF
# Auto-generated services configuration
# Tenant: $TENANT
# Host: $HOSTNAME
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

{ config, lib, ... }:

{
  # Enable specified services
EOF

    IFS=',' read -ra SVC_ARRAY <<< "$SERVICES"
    for service in "${SVC_ARRAY[@]}"; do
        service=$(echo "$service" | xargs) # Trim whitespace
        echo "  services.paas.$service.enable = true;" >> "$TENANT_HOST_CONFIG/services.nix"
    done

    cat >> "$TENANT_HOST_CONFIG/services.nix" << EOF
}
EOF

    log_success "Generated services configuration"
fi

# === Build Deployment Command ===
DEPLOY_SCRIPT="$SCRIPT_DIR/deploy.sh"
DEPLOY_CMD=("$DEPLOY_SCRIPT")

# Add SSH options
DEPLOY_CMD+=("-u" "$SSH_USER")
if [[ -n "$SSH_KEY" ]]; then
    DEPLOY_CMD+=("-k" "$SSH_KEY")
fi

# Add debug flag
if [[ "$DEBUG" == true ]]; then
    DEPLOY_CMD+=("--debug")
fi

# Add hostname and target
DEPLOY_CMD+=("$HOSTNAME" "$TARGET_IP")

# === Display Deployment Summary ===
echo ""
log_info "=== Deployment Summary ==="
log_info "  Tenant:              $TENANT"
log_info "  Hostname:            $HOSTNAME"
log_info "  Target IP:           $TARGET_IP"
log_info "  SSH User:            $SSH_USER"
log_info "  Tenant Config Dir:   $TENANT_DIR"
if [[ -n "$SERVICES" ]]; then
    log_info "  Enabled Services:    $SERVICES"
fi
echo ""

# === Confirm Deployment ===
read -p "$(echo -e "${YELLOW}Proceed with deployment? [y/N]${NC} ")" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Deployment cancelled"
    exit 0
fi

# === Execute Deployment ===
log_info "Executing deployment..."
echo ""

if "${DEPLOY_CMD[@]}"; then
    log_success "Tenant deployment completed successfully!"
    echo ""
    log_info "Tenant '$TENANT' has been deployed to $HOSTNAME at $TARGET_IP"
    log_info "Next steps:"
    log_info "  1. Verify services: ssh $SSH_USER@$TARGET_IP 'systemctl status'"
    log_info "  2. Check logs: ssh $SSH_USER@$TARGET_IP 'journalctl -xe'"
    log_info "  3. Update DNS records for $HOSTNAME.$TENANT.yourdomain.com"
else
    log_error "Tenant deployment failed!"
    exit 1
fi
