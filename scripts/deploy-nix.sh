#!/usr/bin/env bash
set -euo pipefail # Exit on error, unset variable, or pipe failure

# Check for required arguments
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <username> <target_host>"
  echo "Example: $0 alice root@192.168.1.100"
  exit 1
fi

USERNAME=$1
TARGET_HOST=$2
HOSTNAME="server1" # The name of the configuration in flake.nix

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

echo "--> Deploying NixOS configuration to $TARGET_HOST"
# Deploy the system, passing the user config as an argument
nixos-rebuild switch \
  --flake "$PROJECT_ROOT/nix-solution#${HOSTNAME}" \
  --target-host "$TARGET_HOST" \
  --use-remote-sudo \
  --arg userConfig "$nix_args_str"

echo "--> NixOS deployment complete."
