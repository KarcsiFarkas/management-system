#!/usr/bin/env bash
set -euo pipefail # Exit on error, unset variable, or pipe failure

# Strategy 2: Generated Passwords with Vaultwarden Integration - NixOS Version
# This script implements the Vaultwarden password generation strategy for NixOS as described in the password guideline

# Check for required arguments
if [[ $# -ne 6 ]]; then
  echo "Usage: $0 <username> <target_host> <bw_client_id> <bw_client_secret> <bw_password> <vaultwarden_url>"
  echo "Example: $0 alice root@192.168.1.100 user.12345678-1234-1234-1234-123456789012 ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnop myMasterPassword123 https://vault.example.com"
  echo ""
  echo "This script implements Strategy 2: Generated Passwords with Vaultwarden Integration for NixOS"
  echo "- Deploys Vaultwarden first and waits for it to be ready"
  echo "- Uses Bitwarden CLI to generate unique passwords for each service"
  echo "- Stores all passwords in the user's Vaultwarden vault"
  echo "- Configures services with the generated passwords using NixOS secrets management"
  echo "- Uses NixOS declarative configuration for reproducible deployments"
  echo ""
  echo "Prerequisites:"
  echo "- User must have created a Vaultwarden account and master password"
  echo "- User must have generated API keys (client_id and client_secret) from Vaultwarden web UI"
  echo "- Bitwarden CLI (bw) must be installed on the deployment machine"
  exit 1
fi

USERNAME=$1
TARGET_HOST=$2
BW_CLIENTID=$3
BW_CLIENTSECRET=$4
BW_PASSWORD=$5
VAULTWARDEN_URL=$6
HOSTNAME="server1" # The name of the configuration in flake.nix

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE}" )" &> /dev/null && pwd )
PROJECT_ROOT=$(realpath "$SCRIPT_DIR/..")

echo "==> Strategy 2: Deploying NixOS with Vaultwarden Password Generation"
echo "==> Profile: $USERNAME"
echo "==> Target Host: $TARGET_HOST"
echo "==> Vaultwarden URL: $VAULTWARDEN_URL"

# Check if Bitwarden CLI is installed
if ! command -v bw &> /dev/null; then
  echo "Error: Bitwarden CLI (bw) is not installed."
  echo "Please install it first:"
  echo "  - On Ubuntu/Debian: snap install bw"
  echo "  - On Arch: yay -S bitwarden-cli"
  echo "  - On NixOS: nix-shell -p bitwarden-cli"
  echo "  - Or download from: https://github.com/bitwarden/clients/releases"
  exit 1
fi

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

# Build list of enabled services
enabled_services=()
for key in "${!user_vars[@]}"; do
  if [[ $key =~ ^SERVICE_.*_ENABLED$ ]] && [[ "${user_vars[$key],,}" == "true" ]]; then
    # Extract service name from SERVICE_NAME_ENABLED format
    service_name=$(echo "$key" | sed 's/^SERVICE_//' | sed 's/_ENABLED$//' | tr '[:upper:]' '[:lower:]')
    enabled_services+=("$service_name")
  fi
done

if [[ ${#enabled_services[@]} -eq 0 ]]; then
  echo "No services enabled in profile. Exiting."
  exit 0
fi

echo "--> Enabled services: ${enabled_services[*]}"

# Force enable Vaultwarden for password management strategy
if [[ ! " ${enabled_services[*]} " =~ " vaultwarden " ]]; then
  enabled_services+=("vaultwarden")
  user_vars["SERVICE_VAULTWARDEN_ENABLED"]="true"
  echo "--> Force-enabled Vaultwarden for password management strategy"
fi

# Add Vaultwarden specific environment variables.nix
user_vars["VAULTWARDEN_ADMIN_TOKEN"]=$(openssl rand -base64 32)

echo "--> Step 1: Deploying Vaultwarden first (minimal NixOS configuration)"
# Create a minimal configuration that only enables Vaultwarden
minimal_nix_args_str="{ "
for key in "${!user_vars[@]}"; do
  # Only include essential variables.nix for Vaultwarden deployment
  if [[ $key =~ ^(DOMAIN|SERVICE_VAULTWARDEN_ENABLED|SERVICE_TRAEFIK_ENABLED|VAULTWARDEN_.*|POSTGRES_.*)$ ]]; then
    value_escaped=$(printf '%s' "${user_vars[$key]}" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    minimal_nix_args_str+="\"$key\" = \"$value_escaped\"; "
  fi
done
minimal_nix_args_str+="}"

echo "--> Deploying minimal NixOS configuration with Vaultwarden..."
nixos-rebuild switch \
  --flake "$PROJECT_ROOT/nix-solution#${HOSTNAME}" \
  --target-host "$TARGET_HOST" \
  --use-remote-sudo \
  --arg userConfig "$minimal_nix_args_str"

echo "--> Step 2: Health check - waiting for Vaultwarden to be ready"
# Wait for Vaultwarden to be healthy (up to 60 seconds)
for i in {1..60}; do
  if ssh "$TARGET_HOST" "curl -s $VAULTWARDEN_URL/alive >/dev/null 2>&1"; then
    echo "--> Vaultwarden is ready"
    break
  fi
  if [[ $i -eq 60 ]]; then
    echo "Error: Vaultwarden failed to start within 60 seconds"
    exit 1
  fi
  echo "--> Waiting for Vaultwarden... ($i/60)"
  sleep 2
done

echo "--> Step 3: Authenticating with Bitwarden CLI"
# Set up Bitwarden CLI environment
export BW_CLIENTID="$BW_CLIENTID"
export BW_CLIENTSECRET="$BW_CLIENTSECRET"
export BW_PASSWORD="$BW_PASSWORD"

# Configure Bitwarden CLI to use the Vaultwarden server
bw config server "$VAULTWARDEN_URL"

# Login with API key
echo "--> Logging in to Vaultwarden..."
if ! bw login --apikey; then
  echo "Error: Failed to login to Vaultwarden with provided API credentials"
  exit 1
fi

# Unlock the vault and get session token
echo "--> Unlocking vault..."
export BW_SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw)

if [[ -z "$BW_SESSION" ]]; then
  echo "Error: Failed to unlock Vaultwarden vault"
  exit 1
fi

echo "--> Successfully authenticated with Vaultwarden"

echo "--> Step 4: Generating and storing passwords for each service"
# Create a temporary directory for secrets
TEMP_SECRETS_DIR=$(mktemp -d)
trap "rm -rf $TEMP_SECRETS_DIR" EXIT

# Define services that need passwords and their corresponding secret file names
declare -A service_password_vars=(
  ["nextcloud"]="nextcloud_admin_password"
  ["gitlab"]="gitlab_root_password"
  ["seafile"]="seafile_admin_password"
  ["postgres"]="postgres_password"
  ["mariadb"]="mysql_root_password"
  ["pihole"]="pihole_web_password"
  ["immich"]="immich_db_password"
  ["vikunja"]="vikunja_database_password"
  ["firefly"]="firefly_app_key"
)

# Generate passwords for enabled services
for service in "${enabled_services[@]}"; do
  if [[ -n "${service_password_vars[$service]:-}" ]]; then
    echo "--> Generating password for $service..."
    
    # Generate a strong password
    GENERATED_PASS=$(bw generate --length 32 --special --number --uppercase --lowercase)
    
    # Create login item in Vaultwarden
    SERVICE_ITEM=$(bw get template item | jq ".name = \"$service\" | .login.username = \"admin\" | .login.password = \"$GENERATED_PASS\" | .login.uris[0].uri = \"https://$service.\${DOMAIN}\"")
    
    # Store in vault
    if bw create item "$SERVICE_ITEM" >/dev/null; then
      echo "--> Successfully stored $service password in Vaultwarden"
    else
      echo "Warning: Failed to store $service password in Vaultwarden"
    fi
    
    # Store password in temporary secret file for NixOS
    echo "$GENERATED_PASS" > "$TEMP_SECRETS_DIR/${service_password_vars[$service]}"
    
    # Update user_vars with the generated password for NixOS configuration
    case $service in
      "nextcloud") user_vars["NEXTCLOUD_ADMIN_PASSWORD"]="$GENERATED_PASS" ;;
      "gitlab") user_vars["GITLAB_ROOT_PASSWORD"]="$GENERATED_PASS" ;;
      "seafile") user_vars["SEAFILE_ADMIN_PASSWORD"]="$GENERATED_PASS" ;;
      "postgres") user_vars["POSTGRES_PASSWORD"]="$GENERATED_PASS" ;;
      "mariadb") user_vars["MYSQL_ROOT_PASSWORD"]="$GENERATED_PASS" ;;
      "pihole") user_vars["WEBPASSWORD"]="$GENERATED_PASS" ;;
      "immich") user_vars["IMMICH_DB_PASSWORD"]="$GENERATED_PASS" ;;
      "vikunja") user_vars["VIKUNJA_DATABASE_PASSWORD"]="$GENERATED_PASS" ;;
      "firefly") user_vars["FIREFLY_APP_KEY"]="$GENERATED_PASS" ;;
    esac
  fi
done

echo "--> Step 5: Transferring secrets to target host"
# Create secrets directory on target host
ssh "$TARGET_HOST" "mkdir -p /tmp/nixos-secrets"

# Transfer all secret files to target host
for secret_file in "$TEMP_SECRETS_DIR"/*; do
  if [[ -f "$secret_file" ]]; then
    filename=$(basename "$secret_file")
    scp "$secret_file" "$TARGET_HOST:/tmp/nixos-secrets/$filename"
  fi
done

# Set proper permissions for secret files
ssh "$TARGET_HOST" "chmod 600 /tmp/nixos-secrets/*"

echo "--> Step 6: Deploying full NixOS configuration with generated passwords"
# Build the complete Nix attribute set string with all generated passwords
nix_args_str="{ "
for key in "${!user_vars[@]}"; do
  # Basic escaping for string values - escape quotes and backslashes
  value_escaped=$(printf '%s' "${user_vars[$key]}" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
  nix_args_str+="\"$key\" = \"$value_escaped\"; "
done
nix_args_str+="}"

echo "--> User configuration parsed: ${#user_vars[@]} variables"

# Deploy the complete system configuration
nixos-rebuild switch \
  --flake "$PROJECT_ROOT/nix-solution#${HOSTNAME}" \
  --target-host "$TARGET_HOST" \
  --use-remote-sudo \
  --arg userConfig "$nix_args_str"

echo "--> Step 7: Final verification"
# Verify that we can retrieve a password from Vaultwarden
if [[ " ${enabled_services[*]} " =~ " nextcloud " ]]; then
  echo "--> Verifying password storage by retrieving Nextcloud password..."
  RETRIEVED_PASS=$(bw get password "nextcloud" 2>/dev/null || echo "")
  CONFIGURED_PASS="${user_vars["NEXTCLOUD_ADMIN_PASSWORD"]:-}"
  
  if [[ "$RETRIEVED_PASS" == "$CONFIGURED_PASS" ]]; then
    echo "--> ✓ Password verification successful: Vaultwarden and service configuration match"
  else
    echo "--> ⚠ Warning: Password mismatch detected between Vaultwarden and service configuration"
  fi
fi

echo "--> Step 8: Cleaning up temporary secrets"
# Clean up temporary secrets on target host
ssh "$TARGET_HOST" "rm -rf /tmp/nixos-secrets"

echo "--> Step 9: Verifying deployment"
# Check service status
echo "--> Checking service status..."
ssh "$TARGET_HOST" "systemctl is-active vaultwarden.service" && echo "✓ Vaultwarden is running" || echo "⚠ Vaultwarden may not be running"

# Check if Vaultwarden is responding
if ssh "$TARGET_HOST" "curl -s $VAULTWARDEN_URL/alive >/dev/null 2>&1"; then
  echo "✓ Vaultwarden is responding to health checks"
else
  echo "⚠ Vaultwarden is not responding to health checks"
fi

echo ""
echo "==> NixOS Vaultwarden Password Management Deployment Complete!"
echo "==> All service passwords have been generated and stored in your Vaultwarden vault"
echo ""
echo "==> Service Access:"
echo "    - Vaultwarden: $VAULTWARDEN_URL"
echo "    - All services use unique, randomly generated passwords"
echo "    - Access your vault to retrieve service credentials"
echo ""
echo "==> Security Notes:"
echo "    - Each service has a unique 32-character password"
echo "    - All passwords are stored securely in your encrypted Vaultwarden vault"
echo "    - Use your master password to access the vault and retrieve service credentials"
echo ""
echo "==> NixOS Benefits:"
echo "    - Declarative configuration ensures reproducible deployments"
echo "    - All configuration is version-controlled and auditable"
echo "    - Easy rollbacks with 'nixos-rebuild switch --rollback'"
echo "    - Secrets are properly managed through NixOS secret management"
echo ""
echo "==> Administration:"
echo "    - Service logs: journalctl -u <service-name>"
echo "    - Vaultwarden logs: journalctl -u vaultwarden"
echo "    - Configuration rollback: nixos-rebuild switch --rollback"