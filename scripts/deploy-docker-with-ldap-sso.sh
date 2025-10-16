#!/usr/bin/env bash
set -euo pipefail # Exit on error, unset variable, or pipe failure

# Strategy 1: Global Password via Centralized Identity (LDAP)
# This script implements the LDAP/Authelia SSO strategy as described in the password guideline

# Check for required arguments
if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <username> <global_username> <global_password>"
  echo "Example: $0 alice admin mySecurePassword123"
  echo ""
  echo "This script implements Strategy 1: Global Password via Centralized Identity (LDAP)"
  echo "- Sets up LLDAP as the identity provider"
  echo "- Configures Authelia as the SSO provider"
  echo "- Creates the initial admin user with the provided global password"
  exit 1
fi

USERNAME=$1
GLOBAL_USERNAME=$2
GLOBAL_PASSWORD=$3

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE}" )" &> /dev/null && pwd )
PROJECT_ROOT=$(realpath "$SCRIPT_DIR/..")

echo "==> Strategy 1: Deploying with LDAP/Authelia SSO"
echo "==> Profile: $USERNAME"
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

# Force enable LLDAP and Authelia for SSO strategy
if [[ ! " ${enabled_services[*]} " =~ " lldap " ]]; then
  enabled_services+=("lldap")
  echo "--> Force-enabled LLDAP for SSO strategy"
fi

if [[ ! " ${enabled_services[*]} " =~ " authelia " ]]; then
  enabled_services+=("authelia")
  echo "--> Force-enabled Authelia for SSO strategy"
fi

echo "--> Preparing environment for Docker Compose with LDAP SSO"
# Combine both config files and add LDAP-specific variables
cat "$SERVICES_ENV" "$CONFIG_ENV" > "$PROJECT_ROOT/docker-compose-solution/.env"

# Add LDAP/Authelia specific environment variables
cat >> "$PROJECT_ROOT/docker-compose-solution/.env" << EOF

# LDAP/Authelia SSO Configuration (Strategy 1)
SERVICE_LLDAP_ENABLED=true
SERVICE_AUTHELIA_ENABLED=true
LLDAP_ADMIN_USERNAME=${GLOBAL_USERNAME}
LLDAP_ADMIN_PASSWORD=${GLOBAL_PASSWORD}
LLDAP_JWT_SECRET=$(openssl rand -base64 32)
AUTHELIA_JWT_SECRET=$(openssl rand -base64 32)
AUTHELIA_SESSION_SECRET=$(openssl rand -base64 32)
AUTHELIA_STORAGE_ENCRYPTION_KEY=$(openssl rand -base64 32)
EOF

echo "--> Creating external Docker network if it doesn't exist"
docker network inspect traefik_net >/dev/null 2>&1 || docker network create traefik_net

echo "--> Step 1: Deploying core services (LLDAP and Authelia) first"
cd "$PROJECT_ROOT/docker-compose-solution"

# Deploy LLDAP and Authelia first
docker-compose --profile lldap --profile authelia --profile traefik up -d

echo "--> Step 2: Health check - waiting for LLDAP to be ready"
# Wait for LLDAP to be healthy (up to 60 seconds)
for i in {1..60}; do
  if curl -s http://localhost:17170/health >/dev/null 2>&1; then
    echo "--> LLDAP is ready"
    break
  fi
  if [[ $i -eq 60 ]]; then
    echo "Error: LLDAP failed to start within 60 seconds"
    exit 1
  fi
  echo "--> Waiting for LLDAP... ($i/60)"
  sleep 1
done

echo "--> Step 3: Creating initial admin user in LLDAP"
# Hash the password for LLDAP
HASHED_PASSWORD=$(python3 -c "
import bcrypt
password = '$GLOBAL_PASSWORD'.encode('utf-8')
hashed = bcrypt.hashpw(password, bcrypt.gensalt())
print(hashed.decode('utf-8'))
")

# Create the initial admin user via LLDAP API
LLDAP_TOKEN=$(curl -s -X POST http://localhost:17170/auth/simple/login \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"admin\", \"password\": \"changeme\"}" | \
  python3 -c "import sys, json; print(json.load(sys.stdin)['token'])" 2>/dev/null || echo "")

if [[ -n "$LLDAP_TOKEN" ]]; then
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
        \"email\": \"$GLOBAL_USERNAME@\${DOMAIN:-example.local}\",
        \"display_name\": \"$GLOBAL_USERNAME\",
        \"password\": \"$GLOBAL_PASSWORD\"
      }" || true
  fi
  
  echo "--> Successfully created/updated admin user in LLDAP"
else
  echo "Warning: Could not authenticate with LLDAP to create user. Using default configuration."
fi

echo "--> Step 4: Waiting for Authelia to be ready"
# Wait for Authelia to be healthy
for i in {1..30}; do
  if curl -s http://localhost:9091/api/health >/dev/null 2>&1; then
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

echo "--> Step 5: Deploying remaining services"
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

echo ""
echo "==> LDAP/Authelia SSO Deployment Complete!"
echo "==> Global Login Credentials:"
echo "    Username: $GLOBAL_USERNAME"
echo "    Password: $GLOBAL_PASSWORD"
echo ""
echo "==> Service Access:"
echo "    - LLDAP Admin: https://ldap.\${DOMAIN}"
echo "    - Authelia: https://auth.\${DOMAIN}"
echo "    - All other services will use SSO authentication"
echo ""
echo "==> Note: Services that don't support LDAP (like Vaultwarden) will be"
echo "    protected by Authelia forward auth, requiring the global login first."