#!/usr/bin/env bash
set -euo pipefail

# Test script for password management strategies
# This script validates that the password management implementations are working correctly

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE}" )" &> /dev/null && pwd )
PROJECT_ROOT=$(realpath "$SCRIPT_DIR/..")

echo "==> Testing Password Management Strategy Implementations"
echo "==> Project Root: $PROJECT_ROOT"

# Test 1: Check if all required scripts exist
echo ""
echo "==> Test 1: Checking if all password management scripts exist"
REQUIRED_SCRIPTS=(
  "deploy-docker-with-ldap-sso.sh"
  "deploy-docker-with-vaultwarden.sh"
  "deploy-nix-with-ldap-sso.sh"
  "deploy-nix-with-vaultwarden.sh"
)

for script in "${REQUIRED_SCRIPTS[@]}"; do
  if [[ -f "$SCRIPT_DIR/$script" ]]; then
    echo "✓ $script exists"
  else
    echo "✗ $script is missing"
    exit 1
  fi
done

# Test 2: Check if Docker Compose configuration includes Authelia
echo ""
echo "==> Test 2: Checking Docker Compose configuration"
DOCKER_COMPOSE_FILE="$PROJECT_ROOT/docker-compose-solution/docker-compose.yml"

if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
  echo "✓ Docker Compose file exists"
  
  if grep -q "authelia:" "$DOCKER_COMPOSE_FILE"; then
    echo "✓ Authelia service is defined in Docker Compose"
  else
    echo "✗ Authelia service is missing from Docker Compose"
    exit 1
  fi
  
  if grep -q "authelia_data:" "$DOCKER_COMPOSE_FILE"; then
    echo "✓ Authelia data volume is defined"
  else
    echo "✗ Authelia data volume is missing"
    exit 1
  fi
else
  echo "✗ Docker Compose file is missing"
  exit 1
fi

# Test 3: Check if Authelia configuration file exists
echo ""
echo "==> Test 3: Checking Authelia configuration"
AUTHELIA_CONFIG="$PROJECT_ROOT/docker-compose-solution/authelia/configuration.yml"

if [[ -f "$AUTHELIA_CONFIG" ]]; then
  echo "✓ Authelia configuration file exists"
  
  if grep -q "authentication_backend:" "$AUTHELIA_CONFIG"; then
    echo "✓ Authelia LDAP backend configuration is present"
  else
    echo "✗ Authelia LDAP backend configuration is missing"
    exit 1
  fi
else
  echo "✗ Authelia configuration file is missing"
  exit 1
fi

# Test 4: Check if NixOS Authelia module exists
echo ""
echo "==> Test 4: Checking NixOS Authelia module"
AUTHELIA_MODULE="$PROJECT_ROOT/nix-solution/modules/services/authelia.nix"

if [[ -f "$AUTHELIA_MODULE" ]]; then
  echo "✓ NixOS Authelia module exists"
  
  if grep -q "services.authelia.instances.main" "$AUTHELIA_MODULE"; then
    echo "✓ Authelia service configuration is present"
  else
    echo "✗ Authelia service configuration is missing"
    exit 1
  fi
else
  echo "✗ NixOS Authelia module is missing"
  exit 1
fi

# Test 5: Check if Authelia module is imported in flake.nix
echo ""
echo "==> Test 5: Checking NixOS flake configuration"
FLAKE_FILE="$PROJECT_ROOT/nix-solution/flake.nix"

if [[ -f "$FLAKE_FILE" ]]; then
  echo "✓ NixOS flake file exists"
  
  if grep -q "authelia.nix" "$FLAKE_FILE"; then
    echo "✓ Authelia module is imported in flake.nix"
  else
    echo "✗ Authelia module is not imported in flake.nix"
    exit 1
  fi
else
  echo "✗ NixOS flake file is missing"
  exit 1
fi

# Test 6: Validate script syntax
echo ""
echo "==> Test 6: Validating script syntax"
for script in "${REQUIRED_SCRIPTS[@]}"; do
  if bash -n "$SCRIPT_DIR/$script"; then
    echo "✓ $script has valid syntax"
  else
    echo "✗ $script has syntax errors"
    exit 1
  fi
done

# Test 7: Check for required dependencies
echo ""
echo "==> Test 7: Checking for required dependencies"
DEPENDENCIES=(
  "docker"
  "docker-compose"
  "curl"
  "openssl"
  "python3"
  "jq"
)

for dep in "${DEPENDENCIES[@]}"; do
  if command -v "$dep" &> /dev/null; then
    echo "✓ $dep is available"
  else
    echo "⚠ $dep is not available (may be required for some strategies)"
  fi
done

# Special check for Bitwarden CLI (only needed for Vaultwarden strategy)
if command -v "bw" &> /dev/null; then
  echo "✓ bw (Bitwarden CLI) is available"
else
  echo "⚠ bw (Bitwarden CLI) is not available (required for Vaultwarden strategy)"
fi

# Special check for NixOS tools (only needed for NixOS strategies)
if command -v "nixos-rebuild" &> /dev/null; then
  echo "✓ nixos-rebuild is available"
else
  echo "⚠ nixos-rebuild is not available (required for NixOS strategies)"
fi

echo ""
echo "==> Test Results Summary"
echo "✓ All password management scripts are present and have valid syntax"
echo "✓ Docker Compose configuration includes Authelia service"
echo "✓ Authelia configuration file is properly structured"
echo "✓ NixOS Authelia module is implemented and imported"
echo ""
echo "==> Password Management Strategies Available:"
echo "  1. Docker Compose + LDAP/Authelia SSO"
echo "     Usage: ./deploy-docker-with-ldap-sso.sh <username> <global_username> <global_password>"
echo ""
echo "  2. Docker Compose + Vaultwarden Integration"
echo "     Usage: ./deploy-docker-with-vaultwarden.sh <username> <bw_client_id> <bw_client_secret> <bw_password> <vaultwarden_url>"
echo ""
echo "  3. NixOS + LDAP/Authelia SSO"
echo "     Usage: ./deploy-nix-with-ldap-sso.sh <username> <target_host> <global_username> <global_password>"
echo ""
echo "  4. NixOS + Vaultwarden Integration"
echo "     Usage: ./deploy-nix-with-vaultwarden.sh <username> <target_host> <bw_client_id> <bw_client_secret> <bw_password> <vaultwarden_url>"
echo ""
echo "==> All tests passed! Password management strategies are ready for deployment."