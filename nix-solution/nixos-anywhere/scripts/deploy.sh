#!/usr/bin/env bash
# Main deployment script for nixos-anywhere
# Deploys a NixOS configuration to a remote machine

set -euo pipefail

# === Script Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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
Usage: $0 [OPTIONS] <hostname> <target-ip>

Deploy NixOS configuration using nixos-anywhere

ARGUMENTS:
    hostname        NixOS configuration name (from flake.nix)
    target-ip       Target machine IP address or hostname

OPTIONS:
    -u, --user USER         SSH user (default: root)
    -k, --ssh-key PATH      Path to SSH private key
    -p, --ssh-port PORT     SSH port (default: 22)
    -d, --debug             Enable debug output
    -y, --yes               Run non-interactively (skip confirmation)
    --no-reboot             Don't reboot after installation
    --no-kexec              Skip kexec phase
    --disk-device DEVICE    Override disk device (default: /dev/sda)
    -h, --help              Show this help message

EXAMPLES:
    # Basic deployment
    $0 paas-server 192.168.1.100

    # Deployment with custom SSH key
    $0 -k ~/.ssh/deployment_key paas-server 192.168.1.100

    # Deployment with debug output
    $0 --debug staging-server 10.0.0.50

    # Deployment without rebooting
    $0 --no-reboot dev-server 192.168.1.200

EOF
}

# === Argument Parsing ===
SSH_USER="root"
SSH_KEY=""
SSH_PORT="22"
DEBUG=false
ASSUME_YES=false
NO_REBOOT=false
NO_KEXEC=false
DISK_DEVICE=""
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
        -p|--ssh-port)
            SSH_PORT="$2"
            shift 2
            ;;
        -d|--debug)
            DEBUG=true
            shift
            ;;
        -y|--yes)
            ASSUME_YES=true
            shift
            ;;
        --no-reboot)
            NO_REBOOT=true
            shift
            ;;
        --no-kexec)
            NO_KEXEC=true
            shift
            ;;
        --disk-device)
            DISK_DEVICE="$2"
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
            if [[ -z "$HOSTNAME" ]]; then
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
if [[ -z "$HOSTNAME" ]] || [[ -z "$TARGET_IP" ]]; then
    log_error "Missing required arguments"
    show_usage
    exit 1
fi

# === Pre-deployment Checks ===
log_info "Starting deployment of '$HOSTNAME' to $TARGET_IP"

# Check if configuration exists
if ! nix flake show "$PROJECT_ROOT#nixosConfigurations.$HOSTNAME" &>/dev/null; then
    log_error "Configuration '$HOSTNAME' not found in flake"
    log_info "Available configurations:"
    nix flake show "$PROJECT_ROOT" 2>/dev/null | grep "nixosConfigurations" -A 10 || true
    exit 1
fi

# Check SSH connectivity
log_info "Checking SSH connectivity to $TARGET_IP..."
SSH_OPTS="-p $SSH_PORT -o ConnectTimeout=10 -o StrictHostKeyChecking=no"
if [[ -n "$SSH_KEY" ]]; then
    SSH_OPTS="$SSH_OPTS -i $SSH_KEY"
fi

if ! ssh $SSH_OPTS "$SSH_USER@$TARGET_IP" "echo 'SSH connection successful'" &>/dev/null; then
    log_error "Cannot connect to $TARGET_IP via SSH"
    log_info "Please ensure:"
    log_info "  1. The target machine is reachable"
    log_info "  2. SSH is enabled and running"
    log_info "  3. Your SSH key is authorized"
    exit 1
fi

log_success "SSH connectivity verified"

# Check if nixos-anywhere is available
if ! command -v nixos-anywhere &>/dev/null; then
    log_warning "nixos-anywhere not found in PATH"
    log_info "Using: nix run github:nix-community/nixos-anywhere"
    NIXOS_ANYWHERE="nix run github:nix-community/nixos-anywhere --"
else
    NIXOS_ANYWHERE="nixos-anywhere"
fi

# === Build nixos-anywhere Command ===
DEPLOY_CMD=("$NIXOS_ANYWHERE")
DEPLOY_CMD+=("--flake" "$PROJECT_ROOT#$HOSTNAME")
DEPLOY_CMD+=("--target-host" "$SSH_USER@$TARGET_IP")

# Add optional flags
if [[ "$DEBUG" == true ]]; then
    DEPLOY_CMD+=("--debug")
fi

if [[ "$NO_REBOOT" == true ]]; then
    DEPLOY_CMD+=("--no-reboot")
fi

if [[ "$NO_KEXEC" == true ]]; then
    DEPLOY_CMD+=("--no-kexec")
fi

if [[ -n "$SSH_KEY" ]]; then
    DEPLOY_CMD+=("--ssh-option" "IdentityFile=$SSH_KEY")
fi

if [[ -n "$DISK_DEVICE" ]]; then
    log_info "Overriding disk device to $DISK_DEVICE"
    DEPLOY_CMD+=("--disk-device" "$DISK_DEVICE")
fi

# === Confirm Deployment ===
log_warning "This will:"
log_warning "  1. Partition and format disks on the target machine"
log_warning "  2. Install NixOS with configuration: $HOSTNAME"
log_warning "  3. Copy secrets and configuration"
if [[ "$NO_REBOOT" != true ]]; then
    log_warning "  4. Reboot the target machine"
fi
echo ""
if [[ "$ASSUME_YES" == true ]]; then
    log_info "--yes provided; skipping confirmation prompt"
else
    read -p "$(echo -e "${YELLOW}Do you want to continue? [y/N]${NC} ")" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Deployment cancelled"
        exit 0
    fi
fi

# === Execute Deployment ===
log_info "Starting nixos-anywhere deployment..."
log_info "Command: ${DEPLOY_CMD[*]}"
echo ""

if "${DEPLOY_CMD[@]}"; then
    log_success "Deployment completed successfully!"
    echo ""
    log_info "Next steps:"
    log_info "  1. SSH into the machine: ssh $SSH_USER@$TARGET_IP"
    log_info "  2. Verify services are running"
    log_info "  3. Update DNS records if needed"
    if [[ "$NO_REBOOT" != true ]]; then
        log_info "  4. The machine should reboot automatically"
    fi
else
    log_error "Deployment failed!"
    log_info "Check the output above for error details"
    exit 1
fi
