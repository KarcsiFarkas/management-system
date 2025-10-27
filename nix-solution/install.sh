#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

success() {
  echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║                                                                       ║${NC}"
  echo -e "${GREEN}║                    NixOS Installation Successful!                     ║${NC}"
  echo -e "${GREEN}║                                                                       ║${NC}"
  echo -e "${GREEN}║       Please reboot your system for the changes to take effect.       ║${NC}"
  echo -e "${GREEN}║                                                                       ║${NC}"
  echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
}

info() { echo -e "\n${GREEN}$1${NC}"; }
warn() { echo -e "${YELLOW}$1${NC}"; }
error() { echo -e "${RED}Error: $1${NC}" >&2; }

# If in the live environment then start the live-install.sh script (if present)
if [ -d "/iso" ] || [ "$(findmnt -o FSTYPE -n / || true)" = "tmpfs" ]; then
  if [ -x "./live-install.sh" ]; then
    sudo ./live-install.sh
    exit 0
  fi
fi

# Check if running as root. If root, script will exit.
if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  echo "This script should not be executed as root! Exiting..."
  exit 1
fi

# Check if using NixOS. If not using NixOS, script will exit.
if [[ ! -f /etc/os-release ]] || [[ ! "$(grep -i nixos </etc/os-release || true)" ]]; then
  echo "This installation script only works on NixOS! Download an iso at https://nixos.org/download/"
  echo "You can either use this script in the live environment or booted into a system."
  exit 1
fi

currentUser=$(logname 2>/dev/null || echo "$USER")

list_hosts() {
  local hosts=()
  for host_dir in ./hosts/*/; do
    if [ -d "$host_dir" ]; then
      host_name=$(basename "$host_dir")
      hosts+=("$host_name")
    fi
  done
  printf '%s\n' "${hosts[@]}"
}

# Update networking.hostName in the host's default.nix if present
update_hostname_in_default() {
  local host_name="$1"
  local file="./hosts/$host_name/default.nix"
  if [ -f "$file" ]; then
    # Replace the value of networking.hostName = "...";
    if grep -q "networking.hostName" "$file"; then
      sed -i -E "s#(networking\.hostName\s*=\s*")([^"]*)(";)#\\1$host_name\\3#" "$file"
    else
      # Insert a hostname line if not present (after the opening attr set)
      awk -v hn="$host_name" 'NR==1{print;print "  networking.hostName = \"" hn "\";";next}1' "$file" >"$file.tmp" && mv "$file.tmp" "$file"
    fi
  fi
}

create_new_host() {
  local new_name="$1"
  local template="$2"

  if [ -z "$new_name" ]; then
    error "Host name cannot be empty"
    return 1
  fi

  if [ -d "./hosts/$new_name" ]; then
    error "Host '$new_name' already exists"
    return 1
  fi

  if [ ! -d "./hosts/$template" ]; then
    error "Template host '$template' does not exist"
    return 1
  fi

  info "Creating new host '$new_name' from template '$template'..."
  cp -r "./hosts/$template" "./hosts/$new_name" || {
    error "Failed to copy template"
    return 1
  }

  # Remove old hardware config if present
  rm -f "./hosts/$new_name/hardware-configuration.nix"

  # Update hostname in the new host's default.nix if it exists
  update_hostname_in_default "$new_name"

  echo "Host '$new_name' created successfully."
  return 0
}

# Update flake.nix to point nixosConfigurations.<host> to ./hosts/<host>/default.nix
# and ensure the attribute name matches the selected host.
update_flake_for_host() {
  local host_name="$1"
  local flake_file="flake.nix"

  if [ ! -f "$flake_file" ]; then
    error "flake.nix not found in $(pwd)"
    return 1
  fi

  # Detect current host attribute under nixosConfigurations (first occurrence)
  local current_attr
  current_attr=$(grep -Po 'nixosConfigurations\.[A-Za-z0-9_-]+' "$flake_file" | head -n1 | cut -d'.' -f2 || true)
  if [ -z "$current_attr" ]; then
    warn "Could not detect current nixosConfigurations attribute; leaving as-is"
  else
    # Rename attribute
    sed -i -E "s#(nixosConfigurations\.)${current_attr}(\s*=)#\\1${host_name}\\2#" "$flake_file"
    # Replace host path reference in modules list
    sed -i -E "s#\./hosts/${current_attr}/default\.nix#./hosts/${host_name}/default.nix#g" "$flake_file"
  fi

  # If the host path entry is missing, ensure it exists in modules list.
  if ! grep -q "./hosts/${host_name}/default.nix" "$flake_file"; then
    # Insert after the line with 'modules = ['
    awk -v line="        ./hosts/${host_name}/default.nix" '
      /modules\s*=\s*\[/ { print; print line; next } { print }
    ' "$flake_file" >"$flake_file.tmp" && mv "$flake_file.tmp" "$flake_file"
  fi
}

# Remove module imports for non-selected hosts from flake.nix
prune_other_host_imports() {
  local keep_host="$1"
  local flake_file="flake.nix"
  [ -f "$flake_file" ] || return 0
  for d in ./hosts/*/; do
    local name
    name=$(basename "$d")
    if [ "$name" != "$keep_host" ]; then
      # Delete lines that import the other host's default.nix
      sed -i "\#\./hosts/${name}/default\.nix#d" "$flake_file" || true
    fi
  done
}

# If variables.nix exists, set username to current user
update_username_in_variables() {
  local host_name="$1"
  local file="./hosts/$host_name/variables.nix"
  if [ -f "$file" ]; then
    info "Updating username in variables.nix to '$currentUser'"
    sed -i -E "s#(username\s*=\s*")([^"]*)(";)#\1${currentUser}\3#" "$file" || true
  fi
}

remove_other_hosts() {
  local keep_host="$1"
  for d in ./hosts/*/; do
    local name
    name=$(basename "$d")
    if [ "$name" != "$keep_host" ]; then
      info "Removing host directory: $name"
      rm -rf "$d"
    fi
  done
}

# MAIN
info "NixOS Configuration Host Selection"

available_hosts=($(list_hosts))

if [ ${#available_hosts[@]} -eq 0 ]; then
  error "No hosts found in hosts directory"
  exit 1
fi

echo -e "\nAvailable hosts:"
for i in "${!available_hosts[@]}"; do
  echo "  $((i + 1))) ${available_hosts[$i]}"
done

echo "  n) Create new host"

selected_host=""
while true; do
  read -rp "Select host to use [Default: 1]: " host_choice
  host_choice=${host_choice:-1}

  if [[ "$host_choice" == "n" || "$host_choice" == "N" ]]; then
    read -rp "Enter name for new host: " new_host_name

    if [[ ! "$new_host_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      error "Invalid host name. Use only letters, numbers, hyphens, and underscores."
      continue
    fi

    echo "Select template host:"
    for i in "${!available_hosts[@]}"; do
      echo "  $((i + 1))) ${available_hosts[$i]}"
    done

    read -rp "Template choice [Default: 1]: " template_choice
    template_choice=${template_choice:-1}

    if [[ "$template_choice" =~ ^[0-9]+$ ]] && [ "$template_choice" -ge 1 ] && [ "$template_choice" -le ${#available_hosts[@]} ]; then
      template_host="${available_hosts[$((template_choice - 1))]}"

      if create_new_host "$new_host_name" "$template_host"; then
        selected_host="$new_host_name"
        update_flake_for_host "$selected_host"
        break
      fi
    else
      error "Invalid template choice"
    fi

  elif [[ "$host_choice" =~ ^[0-9]+$ ]] && [ "$host_choice" -ge 1 ] && [ "$host_choice" -le ${#available_hosts[@]} ]; then
    selected_host="${available_hosts[$((host_choice - 1))]}"
    update_flake_for_host "$selected_host"
    break
  else
    error "Invalid choice. Please try again."
  fi

done

info "Using host: $selected_host"

# Update hostname in host default.nix
update_hostname_in_default "$selected_host"

# Generate Hardware Configuration
info "Generating hardware configuration..."
if [ -f "/etc/nixos/hardware-configuration.nix" ]; then
  sudo cp "/etc/nixos/hardware-configuration.nix" "./hosts/$selected_host/hardware-configuration.nix"
else
  sudo nixos-generate-config --show-hardware-config | sudo tee "./hosts/$selected_host/hardware-configuration.nix" >/dev/null
fi

# Remove other hosts to keep tree minimal, and simplify module imports implicitly
remove_other_hosts "$selected_host"

# Stage changes if repo is a git repo
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  sudo git -C . add "hosts/$selected_host/*" 2>/dev/null || true
  sudo git -C . add "flake.nix" 2>/dev/null || true
fi

# Build the new configuration
info "Building NixOS configuration for host: $selected_host"
sudo nixos-rebuild boot --flake ".#$selected_host" || {
  error "nixos-rebuild failed"
  exit 1
}

success
