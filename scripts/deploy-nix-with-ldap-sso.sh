#!/usr/bin/env bash
set -euo pipefail # Exit on error, unset variable, or pipe failure

# Strategy 1: Global Password via Centralized Identity (LDAP) - NixOS Version
# This script implements the LDAP/Authelia SSO strategy for NixOS as described in the password guideline

# Check for required arguments
if [[ $# -ne 4 ]]; then
  echo "Usage: $0 <username> <target_host> <global_username> <global_password>"
  echo "Example: $0 alice root@192.168.1.100 admin mySecurePassword123"
  echo ""
  echo "This script implements Strategy 1: Global Password via Centralized Identity (LDAP) for NixOS"
  echo "- Sets up LLDAP as the identity provider"
  echo "- Configures Authelia as the SSO provider"
  echo "- Creates the initial admin user with the provided global password"
  echo "- Uses NixOS declarative configuration for reproducible deployments"
  exit 1
fi

USERNAME=$1
TARGET_HOST=$2
GLOBAL_USERNAME=$3
GLOBAL_PASSWORD=$4
HOSTNAME="server1" # The name of the configuration in flake.nix

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE}" )" &> /dev/null && pwd )
PROJECT_ROOT=$(realpath "$SCRIPT_DIR/..")

echo "==> Strategy 1: Deploying NixOS with LDAP/Authelia SSO"
echo "==> Profile: $USERNAME"
echo "==> Target Host: $TARGET_HOST"
echo "==> Global Admin User: $GLOBAL_USERNAME"

echo "--> Checking out profile for user: $USERNAME"
(cd "$PROJECT_ROOT/profiles" && git checkout "$USERNAME")

# Check if required profile files exist
SERVICES_ENV="$PROJECT_ROOT/profiles/services.env"
CONFIG_ENV="$PROJECT_ROOT/profiles/config.env"

if [[ ! -f "$SERVICES_ENV" ]]; then
  echo "Error: services.env not found in user profile"
  exit 1
fi

if [[ ! -f "$CONFIG_ENV" ]]; then
  echo "Error: config.env not found in user profile"
  exit 1
fi

echo "--> Parsing user profile configuration"
# Parse both services.env and config.env into a combined associative array
declare -A user_vars

# Function to parse env file and add to user_vars
parse_env_file() {
  local file="$1"
  while IFS='=' read -r key value; do
    # Skip comments and empty lines
    [[ $key =~ ^[[:space:]]*# ]] && continue
    [[ -z $key ]] && continue

    # Remove any whitespace
    key=$(echo "$key" | tr -d '[:space:]')
    # Remove quotes from value but preserve internal spaces
    value=$(echo "$value" | sed 's/^[[:space:]]*"//' | sed 's/"[[:space:]]*$//' | sed "s/^[[:space:]]*'//" | sed "s/'[[:space:]]*$//")

    user_vars["$key"]="$value"
  done < "$file"
}

# Parse both configuration files
parse_env_file "$SERVICES_ENV"
parse_env_file "$CONFIG_ENV"

# Force enable LLDAP and Authelia for SSO strategy
user_vars["SERVICE_LLDAP_ENABLED"]="true"
user_vars["SERVICE_AUTHELIA_ENABLED"]="true"

echo "--> Force-enabled LLDAP and Authelia for SSO strategy"

# Generate secure secrets for LDAP/Authelia configuration
user_vars["LLDAP_ADMIN_USERNAME"]="$GLOBAL_USERNAME"
user_vars["LLDAP_ADMIN_PASSWORD"]="$GLOBAL_PASSWORD"
user_vars["LLDAP_JWT_SECRET"]=$(openssl rand -base64 32)
user_vars["AUTHELIA_JWT_SECRET"]=$(openssl rand -base64 32)
user_vars["AUTHELIA_SESSION_SECRET"]=$(openssl rand -base64 32)
user_vars["AUTHELIA_STORAGE_ENCRYPTION_KEY"]=$(openssl rand -base64 32)

echo "--> Generated secure secrets for LDAP/Authelia configuration"

echo "--> Building Nix attribute set from user configuration"
# Build the Nix attribute set string
nix_args_str="{ "
for key in "${!user_vars[@]}"; do
  # Basic escaping for string values - escape quotes and backslashes
  value_escaped=$(printf '%s' "${user_vars[$key]}" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
  nix_args_str+="\"$key\" = \"$value_escaped\"; "
done
nix_args_str+="}"

echo "--> User configuration parsed: ${#user_vars[@]} variables"

echo "--> Creating temporary secrets directory on target host"
# Create a temporary directory for secrets on the target host
ssh "$TARGET_HOST" "mkdir -p /tmp/nixos-secrets"

# Create secret files for sensitive data (following NixOS best practices)
echo "--> Writing secrets to target host"
ssh "$TARGET_HOST" "echo '$GLOBAL_PASSWORD' > /tmp/nixos-secrets/lldap_admin_password"
ssh "$TARGET_HOST" "echo '${user_vars["LLDAP_JWT_SECRET"]}' > /tmp/nixos-secrets/lldap_jwt_secret"
ssh "$TARGET_HOST" "echo '${user_vars["AUTHELIA_JWT_SECRET"]}' > /tmp/nixos-secrets/authelia_jwt_secret"
ssh "$TARGET_HOST" "echo '${user_vars["AUTHELIA_SESSION_SECRET"]}' > /tmp/nixos-secrets/authelia_session_secret"
ssh "$TARGET_HOST" "echo '${user_vars["AUTHELIA_STORAGE_ENCRYPTION_KEY"]}' > /tmp/nixos-secrets/authelia_storage_key"

# Set proper permissions for secret files
ssh "$TARGET_HOST" "chmod 600 /tmp/nixos-secrets/*"

echo "--> Step 1: Deploying NixOS configuration to $TARGET_HOST"
# Deploy the system, passing the user config as an argument
nixos-rebuild switch \
  --flake "$PROJECT_ROOT/nix-solution#${HOSTNAME}" \
  --target-host "$TARGET_HOST" \
  --use-remote-sudo \
  --arg userConfig "$nix_args_str"

echo "--> Step 2: Waiting for services to be ready"
# Wait for LLDAP to be ready
echo "--> Waiting for LLDAP to start..."
for i in {1..60}; do
  if ssh "$TARGET_HOST" "curl -s http://localhost:17170/health >/dev/null 2>&1"; then
    echo "--> LLDAP is ready"
    break
  fi
  if [[ $i -eq 60 ]]; then
    echo "Warning: LLDAP may not be fully ready, but continuing..."
    break
  fi
  echo "--> Waiting for LLDAP... ($i/60)"
  sleep 2
done

# Wait for Authelia to be ready
echo "--> Waiting for Authelia to start..."
for i in {1..30}; do
  if ssh "$TARGET_HOST" "curl -s http://localhost:9091/api/health >/dev/null 2>&1"; then
    echo "--> Authelia is ready"
    break
  fi
  if [[ $i -eq 30 ]]; then
    echo "Warning: Authelia may not be fully ready, but continuing..."
    break
  fi
  echo "--> Waiting for Authelia... ($i/30)"
  sleep 2
done

echo "--> Step 3: Creating initial admin user in LLDAP"
# Create the initial admin user via LLDAP API
LLDAP_CREATE_USER_SCRIPT=$(cat << 'EOF'
#!/bin/bash
set -e

GLOBAL_USERNAME="$1"
GLOBAL_PASSWORD="$2"

# Try to authenticate with default admin credentials first
LLDAP_TOKEN=$(curl -s -X POST http://localhost:17170/auth/simple/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "changeme"}' | \
  python3 -c "import sys, json; print(json.load(sys.stdin)['token'])" 2>/dev/null || echo "")

if [[ -n "$LLDAP_TOKEN" ]]; then
  echo "Successfully authenticated with LLDAP"
  
  # Update admin password
  curl -s -X PUT http://localhost:17170/api/user/admin \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $LLDAP_TOKEN" \
    -d "{\"password\": \"$GLOBAL_PASSWORD\"}" || true
    
  # Create additional user if different from admin
  if [[ "$GLOBAL_USERNAME" != "admin" ]]; then
    curl -s -X POST http://localhost:17170/api/users \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $LLDAP_TOKEN" \
      -d "{
        \"user_id\": \"$GLOBAL_USERNAME\",
        \"email\": \"$GLOBAL_USERNAME@example.local\",
        \"display_name\": \"$GLOBAL_USERNAME\",
        \"password\": \"$GLOBAL_PASSWORD\"
      }" || true
  fi
  
  echo "Successfully created/updated admin user in LLDAP"
else
  echo "Warning: Could not authenticate with LLDAP to create user. Using default configuration."
fi
EOF
)

# Execute the user creation script on the target host
ssh "$TARGET_HOST" "bash -s -- '$GLOBAL_USERNAME' '$GLOBAL_PASSWORD'" <<< "$LLDAP_CREATE_USER_SCRIPT"

echo "--> Step 4: Cleaning up temporary secrets"
# Clean up temporary secrets
ssh "$TARGET_HOST" "rm -rf /tmp/nixos-secrets"

echo "--> Step 5: Verifying deployment"
# Check service status
echo "--> Checking service status..."
ssh "$TARGET_HOST" "systemctl is-active lldap.service" && echo "✓ LLDAP is running" || echo "⚠ LLDAP may not be running"
ssh "$TARGET_HOST" "systemctl is-active authelia-main.service" && echo "✓ Authelia is running" || echo "⚠ Authelia may not be running"

# Check if services are responding
if ssh "$TARGET_HOST" "curl -s http://localhost:17170/health >/dev/null 2>&1"; then
  echo "✓ LLDAP is responding to health checks"
else
  echo "⚠ LLDAP is not responding to health checks"
fi

if ssh "$TARGET_HOST" "curl -s http://localhost:9091/api/health >/dev/null 2>&1"; then
  echo "✓ Authelia is responding to health checks"
else
  echo "⚠ Authelia is not responding to health checks"
fi

echo ""
echo "==> NixOS LDAP/Authelia SSO Deployment Complete!"
echo "==> Global Login Credentials:"
echo "    Username: $GLOBAL_USERNAME"
echo "    Password: $GLOBAL_PASSWORD"
echo ""
echo "==> Service Access:"
echo "    - LLDAP Admin: https://ldap.\${DOMAIN}"
echo "    - Authelia: https://auth.\${DOMAIN}"
echo "    - All other services will use SSO authentication"
echo ""
echo "==> Administration:"
echo "    - LLDAP tools: /etc/lldap/admin-tools.sh"
echo "    - Authelia tools: /etc/authelia/admin-tools.sh"
echo "    - Service logs: journalctl -u <service-name>"
echo ""
echo "==> Note: Services that don't support LDAP (like Vaultwarden) will be"
echo "    protected by Authelia forward auth, requiring the global login first."
echo ""
echo "==> NixOS Benefits:"
echo "    - Declarative configuration ensures reproducible deployments"
echo "    - All configuration is version-controlled and auditable"
echo "    - Easy rollbacks with 'nixos-rebuild switch --rollback'"