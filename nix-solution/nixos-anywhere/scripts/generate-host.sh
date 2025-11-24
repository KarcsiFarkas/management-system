#!/usr/bin/env bash
# Generate a new host configuration from template

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }

show_usage() {
    cat << EOF
Usage: $0 <hostname>

Generate a new host configuration from template

ARGUMENTS:
    hostname        Name for the new host configuration

EXAMPLE:
    $0 my-new-server
EOF
}

if [[ $# -ne 1 ]]; then
    show_usage
    exit 1
fi

HOSTNAME="$1"
NEW_HOST_DIR="$PROJECT_ROOT/hosts/$HOSTNAME"

if [[ -d "$NEW_HOST_DIR" ]]; then
    log_warning "Host configuration '$HOSTNAME' already exists"
    read -p "Overwrite? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    rm -rf "$NEW_HOST_DIR"
fi

log_info "Creating new host configuration: $HOSTNAME"

# Copy template
cp -r "$PROJECT_ROOT/hosts/template" "$NEW_HOST_DIR"

# Update hostname in files
sed -i "s/template/$HOSTNAME/g" "$NEW_HOST_DIR/variables.nix"

log_success "Host configuration created at: $NEW_HOST_DIR"
log_info "Next steps:"
log_info "  1. Edit $NEW_HOST_DIR/variables.nix"
log_info "  2. Edit $NEW_HOST_DIR/default.nix"
log_info "  3. Add SSH keys to default.nix"
log_info "  4. Add configuration to flake.nix"
