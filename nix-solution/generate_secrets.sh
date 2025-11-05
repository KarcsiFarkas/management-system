#!/usr/bin/env bash
set -euo pipefail

# Ensure we are in the nix-solution directory
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
if [[ "$(basename "$SCRIPT_DIR")" != "nix-solution" ]]; then
  echo "ERROR: Please run this script from the 'nix-solution' directory."
  exit 1
fi

# Check for sops
if ! command -v sops &> /dev/null; then
  echo "ERROR: sops command not found. Install it (nix-shell -p sops)."
  exit 1
fi

echo "--- Generating and Encrypting Secrets ---"

# --- Authelia Secrets ---
echo "Generating Authelia secrets..."
mkdir -p secrets/authelia
AUTHELIA_SECRETS=(
  "jwt_secret"
  "session_secret"
  "storage_key"
)
for secret_name in "${AUTHELIA_SECRETS[@]}"; do
  if [[ -f "secrets/authelia/${secret_name}" ]]; then
    echo "Skipping secrets/authelia/${secret_name} (already exists)."
    continue
  fi
  echo "Generating secrets/authelia/${secret_name}..."
  openssl rand -base64 32 > "secrets/authelia/${secret_name}.unencrypted"
  sops --encrypt --in-place "secrets/authelia/${secret_name}.unencrypted"
  mv "secrets/authelia/${secret_name}.unencrypted" "secrets/authelia/${secret_name}"
done

# LDAP Password (Manual input recommended for security)
LDAP_PASS_FILE="secrets/authelia/ldap_password"
if [[ -f "$LDAP_PASS_FILE" ]]; then
  echo "Skipping ${LDAP_PASS_FILE} (already exists)."
else
  read -sp "Enter password for LLDAP admin bind user: " ldap_pass
  echo # newline
  if [[ -z "$ldap_pass" ]]; then
    echo "WARN: No LLDAP password entered. Skipping encryption."
  else
    echo "$ldap_pass" > "${LDAP_PASS_FILE}.unencrypted"
    echo "Encrypting ${LDAP_PASS_FILE}..."
    sops --encrypt --in-place "${LDAP_PASS_FILE}.unencrypted"
    mv "${LDAP_PASS_FILE}.unencrypted" "$LDAP_PASS_FILE"
    echo "Created and encrypted ${LDAP_PASS_FILE}"
  fi
fi

# --- Traefik Dashboard Auth (Example) ---
# TRAEFIK_AUTH_FILE="secrets/traefik/dashboard_auth"
# if [[ -f "$TRAEFIK_AUTH_FILE" ]]; then
#   echo "Skipping ${TRAEFIK_AUTH_FILE} (already exists)."
# else
#   read -p "Enter username for Traefik dashboard: " dash_user
#   read -sp "Enter password for Traefik dashboard: " dash_pass
#   echo # newline
#   if [[ -z "$dash_user" || -z "$dash_pass" ]]; then
#     echo "WARN: No username or password entered for Traefik dashboard. Skipping."
#   else
#     if ! command -v mkpasswd &> /dev/null; then
#       echo "WARN: mkpasswd (from whois package) not found. Cannot create htpasswd entry."
#     else
#       mkdir -p secrets/traefik
#       echo "${dash_user}:$(mkpasswd -m sha-512 "$dash_pass")" > "${TRAEFIK_AUTH_FILE}.unencrypted"
#       echo "Encrypting ${TRAEFIK_AUTH_FILE}..."
#       sops --encrypt --in-place "${TRAEFIK_AUTH_FILE}.unencrypted"
#       mv "${TRAEFIK_AUTH_FILE}.unencrypted" "$TRAFIK_AUTH_FILE"
#       echo "Created and encrypted ${TRAFIK_AUTH_FILE}"
#     fi
#   fi
# fi

# --- Add other secrets as needed ---
# echo "Generating Nextcloud admin password..."
# NEXTCLOUD_PASS_FILE="secrets/nextcloud/admin_password"
# ... similar logic ...


echo "--- Secret Generation Complete ---"
echo "Ensure your .sops.yaml is configured and the host has the necessary private key."
# Optional: Clean up unencrypted files if desired
# find secrets/ -name '*.unencrypted' -delete