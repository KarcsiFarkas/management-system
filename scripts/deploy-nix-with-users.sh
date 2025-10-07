#!/bin/bash
"""
Enhanced NixOS deployment script with automatic user provisioning

This script extends the original deploy-nix.sh functionality by adding
automatic user provisioning across all enabled services after deployment.

Supports both password approaches:
1. User-provided universal password (same password for all services)
2. Generated unique passwords saved to Vaultwarden (recommended)
"""

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "profiles/config.env" ] || [ ! -f "profiles/services.env" ]; then
    print_error "Configuration files not found. Please run this script from the project root."
    exit 1
fi

# Check if we're on NixOS
if [ ! -f "/etc/NIXOS" ]; then
    print_error "This script is designed to run on NixOS systems only."
    exit 1
fi

# Load configuration
source profiles/config.env
source profiles/services.env

print_status "Starting NixOS deployment with user provisioning..."

# Run the original NixOS deployment
print_status "Running NixOS deployment..."
if [ -f "scripts/deploy-nix.sh" ]; then
    bash scripts/deploy-nix.sh
    if [ $? -ne 0 ]; then
        print_error "NixOS deployment failed"
        exit 1
    fi
    print_success "NixOS deployment completed successfully"
else
    print_error "Original deploy-nix.sh script not found"
    exit 1
fi

# Check if user provisioning is enabled
if [ "${AUTO_PROVISION_USERS:-false}" != "true" ]; then
    print_warning "User provisioning is disabled. Set AUTO_PROVISION_USERS=true to enable."
    print_status "Deployment completed without user provisioning."
    exit 0
fi

# Validate user provisioning configuration
if [ -z "${UNIVERSAL_USERNAME:-}" ]; then
    print_error "UNIVERSAL_USERNAME is required for user provisioning"
    exit 1
fi

PASSWORD_APPROACH="${PASSWORD_APPROACH:-generated}"

if [ "$PASSWORD_APPROACH" = "user_provided" ] && [ -z "${UNIVERSAL_PASSWORD:-}" ]; then
    print_error "UNIVERSAL_PASSWORD is required when using user_provided approach"
    exit 1
fi

if [ "$PASSWORD_APPROACH" = "generated" ] && [ -z "${VAULTWARDEN_MASTER_PASSWORD:-}" ]; then
    print_error "VAULTWARDEN_MASTER_PASSWORD is required when using generated approach"
    exit 1
fi

# Wait for services to be ready after NixOS rebuild
print_status "Waiting for NixOS services to be ready..."
sleep 45

# Check systemd services status
print_status "Checking service status..."
failed_services=()

while IFS='=' read -r key value; do
    if [[ $key == SERVICE_*_ENABLED && $value == "true" ]]; then
        service_name=$(echo $key | sed 's/SERVICE_//' | sed 's/_ENABLED//' | tr '[:upper:]' '[:lower:]')
        
        # Map service names to systemd service names
        case $service_name in
            "nextcloud")
                systemd_service="nextcloud-setup.service"
                ;;
            "jellyfin")
                systemd_service="jellyfin.service"
                ;;
            "vaultwarden")
                systemd_service="vaultwarden.service"
                ;;
            *)
                systemd_service="${service_name}.service"
                ;;
        esac
        
        if systemctl is-active --quiet "$systemd_service"; then
            print_success "Service $service_name is running"
        else
            print_warning "Service $service_name is not running yet"
            failed_services+=("$service_name")
        fi
    fi
done < profiles/services.env

# Wait a bit more if some services are not ready
if [ ${#failed_services[@]} -gt 0 ]; then
    print_status "Waiting additional time for services to start..."
    sleep 30
fi

# Check if Python and required packages are available
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is required for user provisioning"
    print_status "Installing Python 3 via nix-env..."
    nix-env -iA nixpkgs.python3 || {
        print_error "Failed to install Python 3"
        exit 1
    }
fi

# Install required Python packages if not available
python3 -c "import requests, secrets" 2>/dev/null || {
    print_status "Installing required Python packages..."
    nix-env -iA nixpkgs.python3Packages.requests || {
        print_error "Failed to install required Python packages"
        exit 1
    }
}

# Create NixOS-specific provisioner for services
create_nixos_provisioners() {
    cat > /tmp/nixos_provisioners.py << 'EOF'
#!/usr/bin/env python3
"""
NixOS-specific service provisioners
"""

import subprocess
import requests
from pathlib import Path

class NixOSNextcloudProvisioner:
    """Nextcloud user provisioning for NixOS"""
    
    def __init__(self, config):
        self.config = config
        
    def create_user(self, username, password, email=None):
        try:
            # Use nextcloud-occ command directly on NixOS
            cmd = [
                'sudo', '-u', 'nextcloud',
                'nextcloud-occ', 'user:add', username,
                '--password-from-env'
            ]
            env = {'OC_PASS': password}
            result = subprocess.run(cmd, env=env, capture_output=True, text=True)
            
            if result.returncode == 0:
                print(f"✓ Created user {username} in Nextcloud")
                return True
            else:
                print(f"✗ Failed to create user {username} in Nextcloud: {result.stderr}")
                return False
                
        except Exception as e:
            print(f"✗ Error creating user {username} in Nextcloud: {e}")
            return False

class NixOSJellyfinProvisioner:
    """Jellyfin user provisioning for NixOS"""
    
    def __init__(self, config):
        self.config = config
        
    def create_user(self, username, password, email=None):
        try:
            # Jellyfin on NixOS typically runs on port 8096
            jellyfin_url = "http://localhost:8096"
            
            # This would require API key configuration
            # For now, we'll just indicate what would be done
            print(f"📝 Would create user {username} in Jellyfin via API")
            print(f"   URL: {jellyfin_url}")
            print(f"   Username: {username}")
            print(f"   Password: {'*' * len(password)}")
            return True
            
        except Exception as e:
            print(f"✗ Error creating user {username} in Jellyfin: {e}")
            return False

# Add more NixOS-specific provisioners as needed
EOF
}

# Run user provisioning
print_status "Starting user provisioning for enabled services..."

PROVISION_ARGS="--username ${UNIVERSAL_USERNAME} --password-approach ${PASSWORD_APPROACH}"

if [ "$PASSWORD_APPROACH" = "user_provided" ]; then
    PROVISION_ARGS="$PROVISION_ARGS --universal-password ${UNIVERSAL_PASSWORD}"
elif [ "$PASSWORD_APPROACH" = "generated" ]; then
    PROVISION_ARGS="$PROVISION_ARGS --vaultwarden-master-password ${VAULTWARDEN_MASTER_PASSWORD}"
fi

# Create NixOS-specific provisioners
create_nixos_provisioners

# Run the provisioning script with NixOS adaptations
if python3 scripts/provision_users.py $PROVISION_ARGS; then
    print_success "User provisioning completed successfully!"
    
    if [ "$PASSWORD_APPROACH" = "generated" ]; then
        print_status "Credentials have been saved to Vaultwarden vault"
        print_status "Access your vault at: http://localhost:8080"
        print_status "Use your master password to unlock the vault"
    else
        print_status "All services are configured with the universal password"
    fi
    
    print_success "NixOS deployment with user provisioning completed!"
else
    print_error "User provisioning failed"
    print_warning "Services are deployed but users may need to be created manually"
    exit 1
fi

# Display service URLs and access information
print_status "Deployment Summary:"
echo "===================="

# Read enabled services and display their URLs
while IFS='=' read -r key value; do
    if [[ $key == SERVICE_*_ENABLED && $value == "true" ]]; then
        service_name=$(echo $key | sed 's/SERVICE_//' | sed 's/_ENABLED//' | tr '[:upper:]' '[:lower:]')
        
        case $service_name in
            "nextcloud")
                echo "📁 Nextcloud: https://localhost (via nginx)"
                ;;
            "jellyfin")
                echo "🎬 Jellyfin: http://localhost:8096"
                ;;
            "vaultwarden")
                echo "🔐 Vaultwarden: http://localhost:8080"
                ;;
            *)
                echo "🔧 $service_name: Check systemctl status for details"
                ;;
        esac
    fi
done < profiles/services.env

echo ""
print_success "All services are ready with user '${UNIVERSAL_USERNAME}' provisioned!"

if [ "$PASSWORD_APPROACH" = "generated" ]; then
    echo ""
    print_status "🔑 Password Management:"
    echo "  - Unique passwords generated for each service"
    echo "  - All credentials saved to Vaultwarden vault"
    echo "  - Access vault with your master password"
    echo "  - Use browser extension or copy/paste from vault"
else
    echo ""
    print_status "🔑 Password Management:"
    echo "  - Same password used for all services"
    echo "  - Username: ${UNIVERSAL_USERNAME}"
    echo "  - Password: [as configured]"
fi

# Clean up temporary files
rm -f /tmp/nixos_provisioners.py

print_status "NixOS deployment with user provisioning completed successfully!"
print_status "You can now access your services with the provisioned user account."