#!/usr/bin/env bash
set -euo pipefail # Exit on error, unset variable, or pipe failure

# Strategy 2: Generated Passwords with Vaultwarden Integration
# This script implements the Vaultwarden password generation strategy as described in the password guideline

# Check for required arguments
if [[ $# -ne 5 ]]; then
  echo "Usage: $0 <username> <bw_client_id> <bw_client_secret> <bw_password> <vaultwarden_url>"
  echo "Example: $0 alice user.12345678-1234-1234-1234-123456789012 ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnop myMasterPassword123 https://vault.example.com"
  echo ""
  echo "This script implements Strategy 2: Generated Passwords with Vaultwarden Integration"
  echo "- Deploys Vaultwarden first and waits for it to be ready"
  echo "- Uses Bitwarden CLI to generate unique passwords for each service"
  echo "- Stores all passwords in the user's Vaultwarden vault"
  echo "- Configures services with the generated passwords"
  echo ""
  echo "Prerequisites:"
  echo "- User must have created a Vaultwarden account and master password"
  echo "- User must have generated API keys (client_id and client_secret) from Vaultwarden web UI"
  echo "- Bitwarden CLI (bw) must be installed on the system"
  exit 1
fi

USERNAME=$1
BW_CLIENTID=$2
BW_CLIENTSECRET=$3
BW_PASSWORD=$4
VAULTWARDEN_URL=$5

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE}" )" &> /dev/null && pwd )
PROJECT_ROOT=$(realpath "$SCRIPT_DIR/..")

echo "==> Strategy 2: Deploying with Vaultwarden Password Generation"
echo "==> Profile: $USERNAME"
echo "==> Vaultwarden URL: $VAULTWARDEN_URL"

# Check if Bitwarden CLI is installed
if ! command -v bw &> /dev/null; then
  echo "Error: Bitwarden CLI (bw) is not installed."
  echo "Please install it first:"
  echo "  - On Ubuntu/Debian: snap install bw"
  echo "  - On Arch: yay -S bitwarden-cli"
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
# Parse services.env to determine which services are enabled
declare -A services_enabled
while IFS='=' read -r key value; do
  # Skip comments and empty lines
  [[ $key =~ ^[[:space:]]*# ]] && continue
  [[ -z $key ]] && continue

  # Remove any whitespace and quotes
  key=$(echo "$key" | tr -d '[:space:]')
  value=$(echo "$value" | tr -d '[:space:]"'"'"'')

  if [[ $key =~ ^SERVICE_.*_ENABLED$ ]]; then
    services_enabled["$key"]="$value"
  fi
done < "$SERVICES_ENV"

# Build list of enabled services for profiles
enabled_services=()
for service_key in "${!services_enabled[@]}"; do
  if [[ "${services_enabled[$service_key],,}" == "true" ]]; then
    # Extract service name from SERVICE_NAME_ENABLED format
    service_name=$(echo "$service_key" | sed 's/^SERVICE_//' | sed 's/_ENABLED$//' | tr '[:upper:]' '[:lower:]')
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
  echo "--> Force-enabled Vaultwarden for password management strategy"
fi

echo "--> Preparing environment for Docker Compose"
# Combine both config files
cat "$SERVICES_ENV" "$CONFIG_ENV" > "$PROJECT_ROOT/docker-compose-solution/.env"

# Add Vaultwarden specific environment variables.nix
cat >> "$PROJECT_ROOT/docker-compose-solution/.env" << EOF

# Vaultwarden Password Management Configuration (Strategy 2)
SERVICE_VAULTWARDEN_ENABLED=true
VAULTWARDEN_ADMIN_TOKEN=$(openssl rand -base64 32)
EOF

echo "--> Creating external Docker network if it doesn't exist"
docker network inspect traefik_net >/dev/null 2>&1 || docker network create traefik_net

echo "--> Step 1: Deploying Vaultwarden first"
cd "$PROJECT_ROOT/docker-compose-solution"

# Deploy only Vaultwarden and Traefik first
docker-compose --profile vaultwarden --profile traefik --profile postgres up -d

echo "--> Step 2: Health check - waiting for Vaultwarden to be ready"
# Wait for Vaultwarden to be healthy (up to 60 seconds)
for i in {1..60}; do
  if curl -s "$VAULTWARDEN_URL/alive" >/dev/null 2>&1; then
    echo "--> Vaultwarden is ready"
    break
  fi
  if [[ $i -eq 60 ]]; then
    echo "Error: Vaultwarden failed to start within 60 seconds"
    exit 1
  fi
  echo "--> Waiting for Vaultwarden... ($i/60)"
  sleep 1
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
# Create a temporary file to store generated passwords for service configuration
TEMP_PASSWORDS_FILE=$(mktemp)
trap "rm -f $TEMP_PASSWORDS_FILE" EXIT

# Define services that need passwords and their corresponding environment variable names
declare -A service_password_vars=(
  ["nextcloud"]="NEXTCLOUD_ADMIN_PASSWORD"
  ["gitlab"]="GITLAB_ROOT_PASSWORD"
  ["seafile"]="SEAFILE_ADMIN_PASSWORD"
  ["postgres"]="POSTGRES_PASSWORD"
  ["mariadb"]="MYSQL_ROOT_PASSWORD"
  ["pihole"]="WEBPASSWORD"
  ["immich"]="IMMICH_DB_PASSWORD"
  ["vikunja"]="VIKUNJA_DATABASE_PASSWORD"
  ["firefly"]="FIREFLY_APP_KEY"
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
      
      # Store password for service configuration
      echo "${service_password_vars[$service]}=$GENERATED_PASS" >> "$TEMP_PASSWORDS_FILE"
    else
      echo "Warning: Failed to store $service password in Vaultwarden"
      # Generate a fallback password for service configuration
      echo "${service_password_vars[$service]}=$GENERATED_PASS" >> "$TEMP_PASSWORDS_FILE"
    fi
  fi
done

echo "--> Step 5: Configuring services with generated passwords"
# Append generated passwords to .env.old file
cat "$TEMP_PASSWORDS_FILE" >> "$PROJECT_ROOT/docker-compose-solution/.env"

echo "--> Step 6: Deploying remaining services"
# Build profile arguments for docker-compose
profile_args=()
for service in "${enabled_services[@]}"; do
  profile_args+=(--profile "$service")
done

# Always include traefik as it's the reverse proxy for all services
if [[ ! " ${enabled_services[*]} " =~ " traefik " ]]; then
  profile_args+=(--profile "traefik")
fi

echo "--> Using profiles: ${profile_args[*]}"

# Deploy all services
docker-compose "${profile_args[@]}" up -d

echo "--> Step 7: Final verification"
# Verify that we can retrieve a password from Vaultwarden
if [[ " ${enabled_services[*]} " =~ " nextcloud " ]]; then
  echo "--> Verifying password storage by retrieving Nextcloud password..."
  RETRIEVED_PASS=$(bw get password "nextcloud" 2>/dev/null || echo "")
  CONFIGURED_PASS=$(grep "NEXTCLOUD_ADMIN_PASSWORD=" "$PROJECT_ROOT/docker-compose-solution/.env" | cut -d'=' -f2)
  
  if [[ "$RETRIEVED_PASS" == "$CONFIGURED_PASS" ]]; then
    echo "--> ✓ Password verification successful: Vaultwarden and service configuration match"
  else
    echo "--> ⚠ Warning: Password mismatch detected between Vaultwarden and service configuration"
  fi
fi

echo ""
echo "==> Vaultwarden Password Management Deployment Complete!"
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