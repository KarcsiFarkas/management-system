#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# ========= Colors / Loggers =========
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[0;33m'; NC='\033[0m'
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }
success() {
  echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║                    NixOS Installation Successful!                     ║${NC}"
  echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
}

# ========= Pin working dir / template =========
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
mkdir -p ./hosts

# Preferred template location
TEMPLATE_DIR="${SCRIPT_DIR}/hosts/_default"
if [[ ! -d "$TEMPLATE_DIR" ]]; then
  if [[ -d "${SCRIPT_DIR}/hosts/template" ]]; then
    TEMPLATE_DIR="${SCRIPT_DIR}/hosts/template"
    warn "Using hosts/template as fallback template (prefer hosts/_default)."
  else
    err "No template dir found. Create hosts/_default/ with default.nix & variables.nix."
    exit 1
  fi
fi

# Fix the common typo: defalut.nix -> default.nix
shopt -s nullglob
for f in hosts/*/defalut.nix; do mv "$f" "${f%defalut.nix}default.nix"; done
shopt -u nullglob

# ========= Preconditions =========
if [[ ${EUID:-$(id -u)} -eq 0 ]]; then err "Do not run as root."; exit 1; fi
if [[ ! -f /etc/os-release ]] || ! grep -qi nixos </etc/os-release; then
  err "This installer only works on NixOS."; exit 1
fi
currentUser="$(logname 2>/dev/null || echo "${USER:-nixuser}")"

# ========= Flags =========
NON_INTERACTIVE=0
PRUNE=0
CHOSEN_HOST=""
NEW_USERNAME=""
INVENTORY=""
ONLY_FROM_INV=""   # If set, scaffold only this host from inventory

usage() {
  cat <<EOF
Usage: ./install.sh [options]
  --host NAME        Host to select. If it doesn't exist and --username is given, it will be created from template.
  --username USER    Username for a newly created host (required to create).
  --inventory FILE   Optional YAML inventory to scaffold hosts (no overwrites, unique usernames).
  --only NAME        With --inventory, scaffold only the named host from the file.
  --prune            Remove all other hosts after selection (opt-in).
  --non-interactive  Run without prompts; auto-select first host if --host not provided.
  -h, --help         Show help.
EOF
}

trim() { sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) CHOSEN_HOST="$(printf '%s' "${2:-}" | trim)"; shift 2;;
    --username) NEW_USERNAME="$(printf '%s' "${2:-}" | trim)"; shift 2;;
    --inventory) INVENTORY="$(printf '%s' "${2:-}" | trim)"; shift 2;;
    --only) ONLY_FROM_INV="$(printf '%s' "${2:-}" | trim)"; shift 2;;
    --prune) PRUNE=1; shift;;
    --non-interactive) NON_INTERACTIVE=1; shift;;
    -h|--help) usage; exit 0;;
    *) err "Unknown option: $1"; usage; exit 2;;
  esac
done

# ========= Helpers =========
mktemp_write() { local dest="$1"; shift; [ "${1:-}" = "--" ] && shift || { err "mktemp_write: missing --"; return 2; }; local t; t="$(mktemp)"; "$@" >"$t"; mv "$t" "$dest"; }

list_hosts() {
  shopt -s nullglob
  local d n; for d in ./hosts/*/; do
    n="${d%/}"; n="${n##*/}"
    [[ "$n" =~ ^(_default|template)$ ]] && continue
    printf '%s\n' "$n"
  done
  shopt -u nullglob
}

username_in_use() {
  local user="$1"
  shopt -s nullglob
  local f
  for f in ./hosts/*/variables.nix; do
    [[ "$f" =~ hosts/_default/|hosts/template/ ]] && continue
    local existing
    existing="$(sed -nE 's/^[[:space:]]*username[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/p' "$f" | head -n1 || true)"
    [[ "$existing" == "$user" ]] && { shopt -u nullglob; return 0; }
  done
  shopt -u nullglob
  return 1
}

hosts_using_username() {
  local user="$1"; shopt -s nullglob; local out="" f h
  for f in ./hosts/*/variables.nix; do
    [[ "$f" =~ hosts/_default/|hosts/template/ ]] && continue
    local existing
    existing="$(sed -nE 's/^[[:space:]]*username[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/p' "$f" | head -n1 || true)"
    [[ "$existing" == "$user" ]] && { h="${f#./hosts/}"; h="${h%/variables.nix}"; out="${out:+$out, }$h"; }
  done
  shopt -u nullglob
  echo "$out"
}

create_host_from_template() {
  local HOST_NAME="${1:-}" USER_NAME="${2:-}" PATH_DIR="./hosts/${1:-}"
  [[ -n "$HOST_NAME" ]] || { err "create_host_from_template: host name required"; exit 1; }
  [[ -n "$USER_NAME" ]] || { err "create_host_from_template: username required"; exit 1; }
  [[ -e "$PATH_DIR" ]] && { err "Host '$HOST_NAME' already exists at: $PATH_DIR"; exit 1; }
  if username_in_use "$USER_NAME"; then err "Username '$USER_NAME' already used by: $(hosts_using_username "$USER_NAME")"; exit 1; fi

  info "Copying template '${TEMPLATE_DIR##*/}' -> hosts/$HOST_NAME"
  cp -a "$TEMPLATE_DIR" "$PATH_DIR"
  rm -f "$PATH_DIR/hardware-configuration.nix" || true

  # username -> variables.nix
  local VFILE="$PATH_DIR/variables.nix"; [[ -f "$VFILE" ]] || { err "Template missing variables.nix"; exit 1; }
  mktemp_write "$VFILE" -- sed -E 's#(^[[:space:]]*username[[:space:]]*=[[:space:]]*")[^"]*(";\s*$)#\1'"$USER_NAME"'\2#' "$VFILE"

  # hostname -> default.nix
  local DFILE="$PATH_DIR/default.nix"; [[ -f "$DFILE" ]] || { err "Template missing default.nix"; exit 1; }
  if grep -qE '^[[:space:]]*networking\.hostName[[:space:]]*=' "$DFILE"; then
    mktemp_write "$DFILE" -- sed -E 's#(^[[:space:]]*networking\.hostName[[:space:]]*=[[:space:]]*")[^"]*(";\s*$)#\1'"$HOST_NAME"'\2#' "$DFILE"
  else
    mktemp_write "$DFILE" -- awk -v hn="$HOST_NAME" '
      BEGIN{ ins=0 }
      ins==0 && $0 ~ /^{[[:space:]]*$/ { print; print "  networking.hostName = \"" hn "\";"; ins=1; next }
      { print }
      END{ if(ins==0){ print "  networking.hostName = \"" hn "\";"; print "}" } }' "$DFILE"
  fi
}

# Wire nixosConfigurations.<host> into flake.nix
ensure_flake_config_for_host() {
  local HOST_NAME="${1:-}" FLAKE="flake.nix"
  [[ -n "$HOST_NAME" ]] || { err "ensure_flake_config_for_host: host required"; return 2; }
  [[ -f "$FLAKE" ]] || { warn "No flake.nix found; skipping flake wiring."; return 0; }

  # already present?
  if grep -Eq "nixosConfigurations\\.[[:space:]]*${HOST_NAME}[[:space:]]*=" "$FLAKE"; then
    info "flake.nix already exposes nixosConfigurations.${HOST_NAME} (mkHost or explicit)."
    return 0
  fi

  # prefer mkHost helper if present
  if grep -qE 'mkHost[[:space:]]*=' "$FLAKE"; then
    info "Adding nixosConfigurations.${HOST_NAME} via mkHost"
    local tmp; tmp="$(mktemp)"
    awk -v H="$HOST_NAME" '
      BEGIN{ inN=0; done=0 }
      /nixosConfigurations[[:space:]]*=/ { inN=1 }
      inN==1 && /\{/ && done==0 { print; print "      " H " = mkHost ./hosts/" H "/default.nix \"x86_64-linux\";"; next }
      /\};/ && inN==1 && done==0 { print; inN=0; done=1; next }
      { print }
    ' "$FLAKE" > "$tmp" && mv "$tmp" "$FLAKE"
    return 0
  fi

  # fallback: insert a full nixosSystem stanza
  info "Adding full nixosConfigurations.${HOST_NAME} stanza"
  local tmp; tmp="$(mktemp)"
  awk -v H="$HOST_NAME" '
    BEGIN{ inN=0; done=0 }
    /nixosConfigurations[[:space:]]*=/ { inN=1 }
    inN==1 && /\{/ && done==0 {
      print
      print "      " H " = nixpkgs.lib.nixosSystem {"
      print "        system = \"x86_64-linux\";"
      print "        specialArgs = { inherit inputs; };"
      print "        modules = [ ./hosts/" H "/default.nix ];"
      print "      };"
      next
    }
    /\};/ && inN==1 && done==0 { print; inN=0; done=1; next }
    { print }
  ' "$FLAKE" > "$tmp" && mv "$tmp" "$FLAKE"
}

# Optional prune (opt-in)
prune_other_hosts() {
  local keep="$1"; shopt -s nullglob dotglob
  for d in ./hosts/*/ ; do
    local name="${d%/}"; name="${name##*/}"
    [[ "$name" =~ ^(_default|template)$ ]] && continue
    [[ "$name" == "$keep" ]] && continue
    info "Removing host directory: $name"
    rm -rf -- "$d"
  done
  shopt -u nullglob dotglob
}

# Sanitize WSL hardware-configuration (empty device => null)
sanitize_wsl_hardware_config() {
  local host="$1"
  local f="./hosts/$host/hardware-configuration.nix"
  [[ -f "$f" ]] || return 0

  # Apply only on WSL
  if [[ -e /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
    # Always append overrides; they are harmless if mounts are absent
    cat >>"$f" <<'EOF'

# --- Appended by install.sh sanitize_wsl_hardware_config ---
fileSystems."/mnt/wslg/distro".device = lib.mkForce null;
fileSystems."/tmp/.X11-unix".device   = lib.mkForce null;
# --- end sanitize ---
EOF
    info "Sanitized WSL hardware-configuration.nix (forced empty device -> null)"
  fi
}

# Scaffold from inventory YAML
scaffold_from_inventory() {
  local inv="$1" only="$2"
  if ! command -v yq >/dev/null 2>&1; then err "yq is required to read $inv"; exit 2; fi
  if [[ -n "$only" ]]; then
    info "Scaffolding hosts from inventory: $inv (only: $only)"
  else
    info "Scaffolding hosts from inventory: $inv"
  fi

  local count name username mode iface ip prefix gw
  count="$(yq '. | length' "$inv")"

  for i in $(seq 0 $((count-1))); do
    name="$(yq -r ".[$i].name" "$inv")"
    [[ -n "$only" && "$name" != "$only" ]] && continue

    username="$(yq -r ".[$i].username" "$inv")"
    mode="$(yq -r ".[$i].net.mode // .[$i].mode // \"static\"" "$inv")"
    iface="$(yq -r ".[$i].net.interface // .[$i].interface // \"eth0\"" "$inv")"
    ip="$(yq -r ".[$i].net.ipv4.address // .[$i].ipv4.address // \"192.168.1.50\"" "$inv")"
    prefix="$(yq -r ".[$i].net.ipv4.prefixLength // .[$i].ipv4.prefixLength // 24" "$inv")"
    gw="$(yq -r ".[$i].net.ipv4.gateway // .[$i].ipv4.gateway // \"192.168.1.1\"" "$inv")"

    # Build Nix-safe nameserver list (quoted)
    local nix_ns=""; while IFS= read -r ns; do
      [[ -n "$ns" && "$ns" != "null" ]] && nix_ns="${nix_ns} \"${ns}\""
    done < <(yq -r ".[$i].net.ipv4.nameservers // .[$i].ipv4.nameservers | .[]? // empty" "$inv")

    [[ -e "./hosts/$name" ]] && { err "Inventory host '$name' already exists; refusing to overwrite."; exit 1; }
    [[ -z "$username" || "$username" == "null" ]] && { err "Inventory host '$name' missing 'username'."; exit 1; }
    if username_in_use "$username"; then
      err "Username '$username' already used by: $(hosts_using_username "$username")"
      exit 1
    fi

    # Create and set hostname/username
    create_host_from_template "$name" "$username"

    # Write variables.nix based on mode
    cat > "./hosts/$name/variables.nix" <<EOF
{
  username = "${username}";
  networking = {
    mode = "${mode}";
    interface = "${iface}";
    ipv4 = {
      address = "${ip}";
      prefixLength = ${prefix};
      gateway = "${gw}";
      nameservers = [${nix_ns} ];
    };
  };
}
EOF

    info "Scaffolded host from inventory: $name (mode=${mode}, iface=${iface})"
  done
}

# ========= MAIN =========
info "NixOS Configuration Host Selection"

# 0) Optional inventory (possibly limited to --only)
[[ -n "$INVENTORY" ]] && scaffold_from_inventory "$INVENTORY" "$ONLY_FROM_INV"

# 1) Create-if-missing (non-interactive)
selected_host=""
if [[ -n "$CHOSEN_HOST" && -n "$NEW_USERNAME" && ! -d "./hosts/$CHOSEN_HOST" ]]; then
  create_host_from_template "$CHOSEN_HOST" "$NEW_USERNAME"
  selected_host="$CHOSEN_HOST"
fi

# 2) List hosts
mapfile -t available_hosts < <(list_hosts)
if [[ ${#available_hosts[@]} -eq 0 ]]; then
  err "No hosts found"; exit 1
fi

# 3) Select host
if [[ -z "$selected_host" ]]; then
  if [[ -n "$CHOSEN_HOST" ]]; then
    # Verify chosen host exists among available
    found=0
    for h in "${available_hosts[@]}"; do [[ "$h" == "$CHOSEN_HOST" ]] && found=1; done
    if [[ $found -eq 0 ]]; then
      err "Host '$CHOSEN_HOST' not found"
      info "Available: ${available_hosts[*]}"
      exit 1
    fi
    selected_host="$CHOSEN_HOST"
  elif [[ $NON_INTERACTIVE -eq 1 ]]; then
    selected_host="${available_hosts[0]}"; info "Non-interactive: using '$selected_host'"
  else
    echo -e "\nAvailable hosts:"
    for i in "${!available_hosts[@]}"; do echo "  $((i+1))) ${available_hosts[$i]}"; done
    read -rp "Select host [Default: 1]: " c; c=${c:-1}
    if [[ "$c" =~ ^[0-9]+$ ]] && (( c>=1 && c<=${#available_hosts[@]} )); then
      selected_host="${available_hosts[$((c-1))]}"
    else
      err "Bad choice"; exit 1
    fi
  fi
fi
info "Using host: $selected_host"

# 4) Hardware configuration (suppress noisy WSL btrfs errors)
info "Generating hardware configuration..."
if [[ -f "/etc/nixos/hardware-configuration.nix" ]]; then
  sudo cp "/etc/nixos/hardware-configuration.nix" "./hosts/$selected_host/hardware-configuration.nix" 2>/dev/null || true
else
  sudo nixos-generate-config --show-hardware-config 2> >(grep -v 'not a btrfs filesystem' >&2) \
    | sudo tee "./hosts/$selected_host/hardware-configuration.nix" >/dev/null
fi

# 4b) WSL sanitization (empty device -> null)
sanitize_wsl_hardware_config "$selected_host"

# 5) Ensure flake has nixosConfigurations.<host>
ensure_flake_config_for_host "$selected_host"

# 6) Prune (only if requested)
if [[ $PRUNE -eq 1 ]]; then prune_other_hosts "$selected_host"; else info "Not pruning other hosts (default)"; fi

# 7) Stage changes if a git repo
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  sudo git -C . add "hosts/$selected_host" "flake.nix" 2>/dev/null || true
fi

# 8) Build
info "Building NixOS configuration for host: $selected_host"
if ! sudo nixos-rebuild boot --flake ".#$selected_host" --no-write-lock-file; then
  err "nixos-rebuild failed"; exit 1
fi

success
