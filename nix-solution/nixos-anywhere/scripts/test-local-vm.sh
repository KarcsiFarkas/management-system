#!/usr/bin/env bash
# Test nixos-anywhere deployment on a local QEMU VM
# Usage: ./scripts/test-local-vm.sh <hostname> [disk-size]

set -euo pipefail

HOSTNAME="${1:-template}"
DISK_SIZE="${2:-20G}"
VM_PORT="${3:-2222}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VM_DIR="$PROJECT_ROOT/.vm-test"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Check dependencies
check_dependencies() {
    local missing_deps=()

    for cmd in qemu-system-x86_64 qemu-img nix; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Install on NixOS WSL: nix-env -iA nixpkgs.qemu"
        exit 1
    fi
}

# Create VM disk and start VM
create_vm() {
    mkdir -p "$VM_DIR"

    local disk_path="$VM_DIR/${HOSTNAME}.qcow2"
    local pid_file="$VM_DIR/${HOSTNAME}.pid"

    # Check if VM is already running
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        log_warn "VM already running (PID: $(cat "$pid_file"))"
        log_info "Connect with: ssh -p $VM_PORT root@localhost"
        return 0
    fi

    # Create disk if it doesn't exist
    if [ ! -f "$disk_path" ]; then
        log_info "Creating virtual disk: $disk_path ($DISK_SIZE)"
        qemu-img create -f qcow2 "$disk_path" "$DISK_SIZE"
    else
        log_warn "Using existing disk: $disk_path"
    fi

    # Generate SSH key if needed
    local ssh_key="$VM_DIR/id_ed25519_vm"
    if [ ! -f "$ssh_key" ]; then
        log_info "Generating SSH key for VM access"
        ssh-keygen -t ed25519 -f "$ssh_key" -N "" -C "nixos-vm-test"
    fi

    # Download NixOS ISO if needed
    local iso_path="$VM_DIR/nixos-minimal.iso"
    if [ ! -f "$iso_path" ]; then
        log_info "Downloading NixOS minimal ISO..."
        curl -L "https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso" \
            -o "$iso_path"
    fi

    log_info "Starting QEMU VM..."
    log_info "  - Hostname: $HOSTNAME"
    log_info "  - SSH port: $VM_PORT (localhost:$VM_PORT -> VM:22)"
    log_info "  - Disk: $disk_path"
    log_info "  - Memory: 2GB"

    # Start VM in background
    qemu-system-x86_64 \
        -enable-kvm \
        -m 2048 \
        -smp 2 \
        -drive file="$disk_path",format=qcow2 \
        -cdrom "$iso_path" \
        -boot d \
        -net nic -net user,hostfwd=tcp::${VM_PORT}-:22 \
        -nographic \
        -daemonize \
        -pidfile "$pid_file"

    log_info "VM started in background (PID: $(cat "$pid_file"))"
    log_info ""
    log_warn "Boot the VM manually and set root password, then run:"
    log_info "  ./scripts/test-local-vm.sh deploy $HOSTNAME"
}

# Deploy to the running VM
deploy_to_vm() {
    log_info "Deploying $HOSTNAME to VM on localhost:$VM_PORT"

    # Wait for SSH to be available
    log_info "Waiting for SSH to be available..."
    for i in {1..30}; do
        if ssh -p "$VM_PORT" -o StrictHostKeyChecking=no -o ConnectTimeout=2 \
            root@localhost "echo 'SSH ready'" &>/dev/null; then
            log_info "SSH connection established"
            break
        fi

        if [ "$i" -eq 30 ]; then
            log_error "SSH not available after 60 seconds"
            log_info "Check VM console with: ./scripts/test-local-vm.sh console $HOSTNAME"
            exit 1
        fi

        sleep 2
    done

    # Run nixos-anywhere
    log_info "Running nixos-anywhere deployment..."
    cd "$PROJECT_ROOT"

    nix run github:nix-community/nixos-anywhere -- \
        --flake ".#$HOSTNAME" \
        --target-host "root@localhost" \
        --build-on-remote \
        --extra-files "$PROJECT_ROOT/secrets" \
        --ssh-option "Port=$VM_PORT" \
        --debug

    if [ $? -eq 0 ]; then
        log_info "✅ Deployment successful!"
        log_info "Connect to deployed system: ssh -p $VM_PORT root@localhost"
    else
        log_error "❌ Deployment failed"
        exit 1
    fi
}

# Connect to VM console
connect_console() {
    local pid_file="$VM_DIR/${HOSTNAME}.pid"

    if [ ! -f "$pid_file" ] || ! kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        log_error "VM not running"
        exit 1
    fi

    log_info "Connecting to VM console (Ctrl+A, X to exit)"
    # Note: Console connection requires starting QEMU without -daemonize
    log_warn "Console mode not available for daemonized VM"
    log_info "Use SSH instead: ssh -p $VM_PORT root@localhost"
}

# Stop VM
stop_vm() {
    local pid_file="$VM_DIR/${HOSTNAME}.pid"

    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        local pid=$(cat "$pid_file")
        log_info "Stopping VM (PID: $pid)"
        kill "$pid"
        rm -f "$pid_file"
        log_info "VM stopped"
    else
        log_warn "VM not running"
    fi
}

# Clean up VM files
cleanup_vm() {
    log_warn "This will delete all VM test files"
    read -p "Are you sure? (yes/no): " confirm

    if [ "$confirm" = "yes" ]; then
        stop_vm
        log_info "Removing $VM_DIR"
        rm -rf "$VM_DIR"
        log_info "Cleanup complete"
    else
        log_info "Cleanup cancelled"
    fi
}

# Main
main() {
    check_dependencies

    local command="${1:-start}"

    case "$command" in
        start)
            create_vm
            ;;
        deploy)
            deploy_to_vm
            ;;
        console)
            connect_console
            ;;
        stop)
            stop_vm
            ;;
        cleanup)
            cleanup_vm
            ;;
        *)
            echo "Usage: $0 {start|deploy|console|stop|cleanup} [hostname] [disk-size]"
            echo ""
            echo "Commands:"
            echo "  start    - Create and start VM"
            echo "  deploy   - Deploy NixOS config to running VM"
            echo "  console  - Connect to VM console"
            echo "  stop     - Stop running VM"
            echo "  cleanup  - Delete all VM files"
            echo ""
            echo "Examples:"
            echo "  $0 start template 20G      # Create VM with 20GB disk"
            echo "  $0 deploy template         # Deploy to VM"
            echo "  $0 stop template           # Stop VM"
            exit 1
            ;;
    esac
}

main "$@"
