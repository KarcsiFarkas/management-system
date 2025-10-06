#!/usr/bin/env bash
set -euo pipefail # Exit on error, unset variable, or pipe failure

# Check for required argument
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <username>"
  echo "Example: $0 alice"
  exit 1
fi

USERNAME=$1
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE}" )" &> /dev/null && pwd )
PROJECT_ROOT=$(realpath "$SCRIPT_DIR/..")

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

echo "--> Preparing environment for Docker Compose"
# Combine both config files for Docker Compose environment
cat "$SERVICES_ENV" "$CONFIG_ENV" > "$PROJECT_ROOT/docker-compose-solution/.env"

echo "--> Creating external Docker network if it doesn't exist"
docker network inspect traefik_net >/dev/null 2>&1 || docker network create traefik_net

echo "--> Deploying services via Docker Compose"
cd "$PROJECT_ROOT/docker-compose-solution"

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

# Deploy using the master docker-compose.yml with selected profiles
docker-compose "${profile_args[@]}" up -d

echo "--> Docker Compose deployment initiated."
