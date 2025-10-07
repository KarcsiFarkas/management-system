#!/bin/bash
"""
Enhanced Docker deployment script with automatic user provisioning

This script extends the original deploy-docker.sh functionality by adding
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

# Load configuration
source profiles/config.env
source profiles/services.env

print_status "Starting Docker deployment with user provisioning..."

# Run the original Docker deployment
print_status "Running Docker deployment..."
if [ -f "scripts/deploy-docker.sh" ]; then
    bash scripts/deploy-docker.sh
    if [ $? -ne 0 ]; then
        print_error "Docker deployment failed"
        exit 1
    fi
    print_success "Docker deployment completed successfully"
else
    print_error "Original deploy-docker.sh script not found"
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

# Wait for services to be ready
print_status "Waiting for services to be ready..."
sleep 30

# Check if Python and required packages are available
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is required for user provisioning"
    exit 1
fi

# Install required Python packages if not available
python3 -c "import requests, secrets" 2>/dev/null || {
    print_status "Installing required Python packages..."
    pip3 install requests || {
        print_error "Failed to install required Python packages"
        exit 1
    }
}

# Run user provisioning
print_status "Starting user provisioning for enabled services..."

PROVISION_ARGS="--username ${UNIVERSAL_USERNAME} --password-approach ${PASSWORD_APPROACH}"

if [ "$PASSWORD_APPROACH" = "user_provided" ]; then
    PROVISION_ARGS="$PROVISION_ARGS --universal-password ${UNIVERSAL_PASSWORD}"
elif [ "$PASSWORD_APPROACH" = "generated" ]; then
    PROVISION_ARGS="$PROVISION_ARGS --vaultwarden-master-password ${VAULTWARDEN_MASTER_PASSWORD}"
fi

# Run the provisioning script
if python3 scripts/provision_users.py $PROVISION_ARGS; then
    print_success "User provisioning completed successfully!"
    
    if [ "$PASSWORD_APPROACH" = "generated" ]; then
        print_status "Credentials have been saved to Vaultwarden vault"
        print_status "Access your vault at: http://localhost:${VAULTWARDEN_PORT:-8080}"
        print_status "Use your master password to unlock the vault"
    else
        print_status "All services are configured with the universal password"
    fi
    
    print_success "Docker deployment with user provisioning completed!"
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
                echo "📁 Nextcloud: http://localhost:${NEXTCLOUD_PORT:-8080}"
                ;;
            "gitlab")
                echo "🦊 GitLab: http://localhost:${GITLAB_PORT:-8081}"
                ;;
            "jellyfin")
                echo "🎬 Jellyfin: http://localhost:${JELLYFIN_PORT:-8096}"
                ;;
            "vaultwarden")
                echo "🔐 Vaultwarden: http://localhost:${VAULTWARDEN_PORT:-8080}"
                ;;
            *)
                echo "🔧 $service_name: Check docker-compose logs for port information"
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