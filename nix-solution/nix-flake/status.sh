#!/usr/bin/env bash
set -Eeuo pipefail

# ========= Colors =========
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[0;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

# ========= Helper Functions =========
print_header() {
  echo -e "\n${BOLD}${BLUE}╔════════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${BLUE}║${NC}  $1"
  echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════════════════════════╝${NC}"
}

print_section() {
  echo -e "\n${BOLD}${CYAN}▼ $1${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_service() {
  local name="$1" status="$2" port="$3" url="$4" notes="${5:-}"
  local status_icon status_color

  if [[ "$status" == "active" ]]; then
    status_icon="●"
    status_color="${GREEN}"
  elif [[ "$status" == "inactive" ]]; then
    status_icon="○"
    status_color="${YELLOW}"
  else
    status_icon="✗"
    status_color="${RED}"
  fi

  echo -e "${status_color}${status_icon}${NC} ${BOLD}${name}${NC}"
  echo -e "   Status: ${status_color}${status}${NC}"
  [[ -n "$port" ]] && echo -e "   Port:   ${MAGENTA}${port}${NC}"
  [[ -n "$url" ]] && echo -e "   URL:    ${CYAN}${url}${NC}"
  [[ -n "$notes" ]] && echo -e "   Notes:  ${notes}"
  echo
}

get_service_status() {
  local service="$1"
  if systemctl is-active --quiet "$service" 2>/dev/null; then
    echo "active"
  elif systemctl list-unit-files "$service.service" 2>/dev/null | grep -q "$service"; then
    echo "inactive"
  else
    echo "not-installed"
  fi
}

get_hostname_or_ip() {
  # Try to get hostname, fallback to IP
  local hostname=$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo "localhost")
  if [[ "$hostname" == "localhost" ]] || [[ "$hostname" =~ ^localhost ]]; then
    # Try to get actual IP
    local ip=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n1)
    echo "${ip:-localhost}"
  else
    echo "$hostname"
  fi
}

check_port_listening() {
  local port="$1"
  ss -tlnH "sport = :$port" 2>/dev/null | grep -q ":$port" && return 0 || return 1
}

# ========= Main Report =========
clear
print_header "NixOS PaaS Installation Status Report"

# --- Get IP address and construct nip.io domain ---
HOST_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n1)
BASE_DOMAIN=$(nixos-option networking.domain 2>/dev/null | grep -oP '(?<=").*(?=")' | head -n1 || echo "${HOST_IP}.nip.io")
HOSTNAME=$(get_hostname_or_ip)
CURRENT_USER=$(whoami)
NIXOS_VERSION=$(nixos-version 2>/dev/null || echo "unknown")

echo -e "${BOLD}System Information:${NC}"
echo -e "  Hostname:     ${GREEN}$HOSTNAME${NC}"
echo -e "  Base Domain:  ${GREEN}$BASE_DOMAIN${NC}"
echo -e "  User:         ${GREEN}$CURRENT_USER${NC}"
echo -e "  NixOS:        ${GREEN}$NIXOS_VERSION${NC}"
echo -e "  Date:         ${GREEN}$(date '+%Y-%m-%d %H:%M:%S')${NC}"

# ========= Core Services =========
print_section "Core Services"

# SSH
SSH_STATUS=$(get_service_status "sshd")
SSH_PORT=$(ss -tlnH sport = :22 2>/dev/null | grep -oP ':\K\d+' | head -n1 || echo "22")
print_service "OpenSSH" "$SSH_STATUS" "$SSH_PORT" "ssh://${HOSTNAME}:${SSH_PORT}" "Remote shell access"

# Mosh
MOSH_STATUS=$(get_service_status "mosh")
if command -v mosh >/dev/null 2>&1; then
  print_service "Mosh" "available" "60000-61000 (UDP)" "mosh ${HOSTNAME}" "Mobile shell (UDP ports)"
else
  print_service "Mosh" "not-installed" "" "" ""
fi

# ========= Reverse Proxy =========
print_section "Reverse Proxy & Load Balancer"

TRAEFIK_STATUS=$(get_service_status "traefik")
if [[ "$TRAEFIK_STATUS" != "not-installed" ]]; then
  # Check both standard and WSL-specific ports
  TRAEFIK_HTTP=$(check_port_listening 8090 && echo "8090" || check_port_listening 80 && echo "80" || echo "")
  TRAEFIK_HTTPS=$(check_port_listening 8443 && echo "8443" || check_port_listening 443 && echo "443" || echo "")
  TRAEFIK_DASH=$(check_port_listening 9080 && echo "9080" || check_port_listening 8080 && echo "8080" || echo "")

  TRAEFIK_PORTS="HTTP:${TRAEFIK_HTTP:-off} HTTPS:${TRAEFIK_HTTPS:-off} Dashboard:${TRAEFIK_DASH:-off}"
  TRAEFIK_URL="http://traefik.${BASE_DOMAIN}:${TRAEFIK_DASH}/dashboard/"

  print_service "Traefik" "$TRAEFIK_STATUS" "$TRAEFIK_PORTS" "$TRAEFIK_URL" "Reverse proxy & SSL termination"
else
  print_service "Traefik" "not-installed" "" "" ""
fi

# ========= Authentication & SSO =========
print_section "Authentication & Single Sign-On"

AUTHELIA_STATUS=$(get_service_status "authelia")
if [[ "$AUTHELIA_STATUS" != "not-installed" ]]; then
  AUTHELIA_PORT=$(check_port_listening 9091 && echo "9091" || echo "")
  AUTHELIA_URL="http://authelia.${BASE_DOMAIN}"
  print_service "Authelia" "$AUTHELIA_STATUS" "Internal:${AUTHELIA_PORT:-9091}" "$AUTHELIA_URL" "2FA & SSO authentication"
else
  print_service "Authelia" "not-installed" "" "" ""
fi

LLDAP_STATUS=$(get_service_status "lldap")
if [[ "$LLDAP_STATUS" != "not-installed" ]]; then
  LLDAP_HTTP=$(check_port_listening 17170 && echo "17170" || echo "")
  LLDAP_LDAP=$(check_port_listening 3890 && echo "3890" || echo "")
  LLDAP_URL="http://${HOSTNAME}:${LLDAP_HTTP:-17170}"
  print_service "LLDAP" "$LLDAP_STATUS" "HTTP:${LLDAP_HTTP:-17170} LDAP:${LLDAP_LDAP:-3890}" "$LLDAP_URL" "Lightweight LDAP server"
else
  print_service "LLDAP" "not-installed" "" "" ""
fi

# ========= Media Services =========
print_section "Media & Entertainment"

JELLYFIN_STATUS=$(get_service_status "jellyfin")
if [[ "$JELLYFIN_STATUS" != "not-installed" ]]; then
  JELLYFIN_HTTP=$(check_port_listening 8096 && echo "8096" || echo "")
  JELLYFIN_HTTPS=$(check_port_listening 8920 && echo "8920" || echo "")
  JELLYFIN_URL="http://jellyfin.${BASE_DOMAIN}"
  print_service "Jellyfin" "$JELLYFIN_STATUS" "Internal:${JELLYFIN_HTTP:-8096}" "$JELLYFIN_URL" "Media streaming server"
else
  print_service "Jellyfin" "not-installed" "" "" ""
fi

NAVIDROME_STATUS=$(get_service_status "navidrome")
if [[ "$NAVIDROME_STATUS" != "not-installed" ]]; then
  NAVIDROME_PORT=$(check_port_listening 4533 && echo "4533" || echo "")
  NAVIDROME_URL="http://navidrome.${BASE_DOMAIN}"
  print_service "Navidrome" "$NAVIDROME_STATUS" "Internal:${NAVIDROME_PORT:-4533}" "$NAVIDROME_URL" "Music streaming server"
else
  print_service "Navidrome" "not-installed" "" "" ""
fi

# ========= Cloud Storage & Sync =========
print_section "Cloud Storage & File Sync"

NEXTCLOUD_STATUS=$(get_service_status "phpfpm-nextcloud")
if [[ "$NEXTCLOUD_STATUS" != "not-installed" ]]; then
  NEXTCLOUD_PORT=$(check_port_listening 9001 && echo "9001" || echo "")
  NEXTCLOUD_URL="http://nextcloud.${BASE_DOMAIN}"
  print_service "Nextcloud" "$NEXTCLOUD_STATUS" "Internal:${NEXTCLOUD_PORT:-9001}" "$NEXTCLOUD_URL" "File sync & collaboration"
else
  print_service "Nextcloud" "not-installed" "" "" ""
fi

SEAFILE_STATUS=$(get_service_status "seafile")
if [[ "$SEAFILE_STATUS" != "not-installed" ]]; then
  SEAFILE_PORT=$(check_port_listening 8000 && echo "8000" || echo "")
  SEAFILE_URL="http://seafile.${BASE_DOMAIN}"
  print_service "Seafile" "$SEAFILE_STATUS" "Internal:${SEAFILE_PORT:-8000}" "$SEAFILE_URL" "File sync & sharing"
else
  print_service "Seafile" "not-installed" "" "" ""
fi

SYNCTHING_STATUS=$(get_service_status "syncthing")
if [[ "$SYNCTHING_STATUS" != "not-installed" ]]; then
  SYNCTHING_UI=$(check_port_listening 8384 && echo "8384" || echo "")
  SYNCTHING_SYNC=$(check_port_listening 22000 && echo "22000" || echo "")
  SYNCTHING_URL="http://${HOSTNAME}:${SYNCTHING_UI:-8384}"
  print_service "Syncthing" "$SYNCTHING_STATUS" "UI:${SYNCTHING_UI:-8384} Sync:${SYNCTHING_SYNC:-22000}" "$SYNCTHING_URL" "P2P file synchronization"
else
  print_service "Syncthing" "not-installed" "" "" ""
fi

# ========= Password & Secret Management =========
print_section "Password & Secret Management"

VAULTWARDEN_STATUS=$(get_service_status "vaultwarden")
if [[ "$VAULTWARDEN_STATUS" != "not-installed" ]]; then
  VAULTWARDEN_HTTP=$(check_port_listening 8222 && echo "8222" || echo "")
  VAULTWARDEN_WS=$(check_port_listening 3012 && echo "3012" || echo "")
  VAULTWARDEN_URL="http://vaultwarden.${BASE_DOMAIN}"
  print_service "Vaultwarden" "$VAULTWARDEN_STATUS" "Internal:${VAULTWARDEN_HTTP:-8222}" "$VAULTWARDEN_URL" "Bitwarden-compatible password manager"
else
  print_service "Vaultwarden" "not-installed" "" "" ""
fi

# ========= Development & Git =========
print_section "Development & Version Control"

GITEA_STATUS=$(get_service_status "gitea")
if [[ "$GITEA_STATUS" != "not-installed" ]]; then
  GITEA_HTTP=$(check_port_listening 3000 && echo "3000" || echo "")
  GITEA_SSH=$(check_port_listening 2222 && echo "2222" || echo "")
  GITEA_URL="http://gitea.${BASE_DOMAIN}"
  print_service "Gitea" "$GITEA_STATUS" "Internal:${GITEA_HTTP:-3000} SSH:${GITEA_SSH:-2222}" "$GITEA_URL" "Self-hosted Git service"
else
  print_service "Gitea" "not-installed" "" "" ""
fi

GITLAB_STATUS=$(get_service_status "gitlab")
if [[ "$GITLAB_STATUS" != "not-installed" ]]; then
  GITLAB_PORT=$(check_port_listening 8080 && echo "8080" || echo "")
  GITLAB_URL="http://${HOSTNAME}:${GITLAB_PORT:-8080}"
  print_service "GitLab" "$GITLAB_STATUS" "${GITLAB_PORT:-8080}" "$GITLAB_URL" "Complete DevOps platform"
else
  print_service "GitLab" "not-installed" "" "" ""
fi

# ========= Download & Media Management =========
print_section "Download & Media Management"

SONARR_STATUS=$(get_service_status "sonarr")
if [[ "$SONARR_STATUS" != "not-installed" ]]; then
  SONARR_PORT=$(check_port_listening 8989 && echo "8989" || echo "")
  SONARR_URL="http://sonarr.${BASE_DOMAIN}"
  print_service "Sonarr" "$SONARR_STATUS" "Internal:${SONARR_PORT:-8989}" "$SONARR_URL" "TV show management"
else
  print_service "Sonarr" "not-installed" "" "" ""
fi

RADARR_STATUS=$(get_service_status "radarr")
if [[ "$RADARR_STATUS" != "not-installed" ]]; then
  RADARR_PORT=$(check_port_listening 7878 && echo "7878" || echo "")
  RADARR_URL="http://radarr.${BASE_DOMAIN}"
  print_service "Radarr" "$RADARR_STATUS" "Internal:${RADARR_PORT:-7878}" "$RADARR_URL" "Movie management"
else
  print_service "Radarr" "not-installed" "" "" ""
fi

QBITTORRENT_STATUS=$(get_service_status "qbittorrent")
if [[ "$QBITTORRENT_STATUS" != "not-installed" ]]; then
  QBITTORRENT_PORT=$(check_port_listening 8080 && echo "8080" || echo "")
  QBITTORRENT_URL="http://qbittorrent.${BASE_DOMAIN}"
  print_service "qBittorrent" "$QBITTORRENT_STATUS" "Internal:${QBITTORRENT_PORT:-8080}" "$QBITTORRENT_URL" "BitTorrent client"
else
  print_service "qBittorrent" "not-installed" "" "" ""
fi

# ========= Productivity & Organization =========
print_section "Productivity & Organization"

VIKUNJA_STATUS=$(get_service_status "vikunja")
if [[ "$VIKUNJA_STATUS" != "not-installed" ]]; then
  VIKUNJA_PORT=$(check_port_listening 3456 && echo "3456" || echo "")
  VIKUNJA_URL="http://vikunja.${BASE_DOMAIN}"
  print_service "Vikunja" "$VIKUNJA_STATUS" "Internal:${VIKUNJA_PORT:-3456}" "$VIKUNJA_URL" "Todo & project management"
else
  print_service "Vikunja" "not-installed" "" "" ""
fi

FRESHRSS_STATUS=$(get_service_status "freshrss")
if [[ "$FRESHRSS_STATUS" != "not-installed" ]]; then
  FRESHRSS_PORT=$(check_port_listening 8083 && echo "8083" || echo "")
  FRESHRSS_URL="http://freshrss.${BASE_DOMAIN}"
  print_service "FreshRSS" "$FRESHRSS_STATUS" "Internal:${FRESHRSS_PORT:-8083}" "$FRESHRSS_URL" "RSS feed aggregator"
else
  print_service "FreshRSS" "not-installed" "" "" ""
fi

FIREFLY_STATUS=$(get_service_status "firefly-iii")
if [[ "$FIREFLY_STATUS" != "not-installed" ]]; then
  FIREFLY_PORT=$(check_port_listening 8084 && echo "8084" || echo "")
  FIREFLY_URL="http://firefly.${BASE_DOMAIN}"
  print_service "Firefly III" "$FIREFLY_STATUS" "Internal:${FIREFLY_PORT:-8084}" "$FIREFLY_URL" "Personal finance manager"
else
  print_service "Firefly III" "not-installed" "" "" ""
fi

# ========= Dashboard =========
print_section "Dashboard & Monitoring"

HOMER_STATUS=$(get_service_status "nginx")
if [[ "$HOMER_STATUS" != "not-installed" ]] && check_port_listening 8088; then
  HOMER_PORT="8088"
  HOMER_URL="http://homer.${BASE_DOMAIN}"
  print_service "Homer" "$HOMER_STATUS" "Internal:${HOMER_PORT}" "$HOMER_URL" "Application dashboard (via nginx)"
else
  print_service "Homer" "not-installed" "" "" ""
fi

IMMICH_STATUS=$(get_service_status "immich")
if [[ "$IMMICH_STATUS" != "not-installed" ]]; then
  IMMICH_PORT=$(check_port_listening 2283 && echo "2283" || echo "")
  IMMICH_URL="http://immich.${BASE_DOMAIN}"
  print_service "Immich" "$IMMICH_STATUS" "Internal:${IMMICH_PORT:-2283}" "$IMMICH_URL" "Photo & video backup"
else
  print_service "Immich" "not-installed" "" "" ""
fi

# ========= Database Services =========
print_section "Database Services"

POSTGRES_STATUS=$(get_service_status "postgresql")
if [[ "$POSTGRES_STATUS" != "not-installed" ]]; then
  POSTGRES_PORT=$(check_port_listening 5432 && echo "5432" || echo "")
  print_service "PostgreSQL" "$POSTGRES_STATUS" "${POSTGRES_PORT:-5432}" "postgresql://${HOSTNAME}:${POSTGRES_PORT:-5432}" "Relational database"
else
  print_service "PostgreSQL" "not-installed" "" "" ""
fi

REDIS_STATUS=$(get_service_status "redis")
if [[ "$REDIS_STATUS" != "not-installed" ]]; then
  REDIS_PORT=$(check_port_listening 6379 && echo "6379" || echo "")
  print_service "Redis" "$REDIS_STATUS" "${REDIS_PORT:-6379}" "redis://${HOSTNAME}:${REDIS_PORT:-6379}" "In-memory data store"
else
  print_service "Redis" "not-installed" "" "" ""
fi

# ========= Network Information =========
print_section "Network Configuration"

echo -e "${BOLD}Network Interfaces:${NC}"
ip -4 addr show | grep -E '^[0-9]+:|inet ' | while read line; do
  if [[ "$line" =~ ^[0-9]+: ]]; then
    iface=$(echo "$line" | awk '{print $2}' | tr -d ':')
    echo -e "  ${CYAN}${iface}${NC}"
  elif [[ "$line" =~ inet ]]; then
    ip=$(echo "$line" | awk '{print $2}')
    echo -e "    ${GREEN}${ip}${NC}"
  fi
done

echo -e "\n${BOLD}Open Ports:${NC}"
ss -tlnH | awk '{print $4}' | grep -oP ':\K\d+$' | sort -n | uniq | while read port; do
  echo -e "  ${MAGENTA}${port}${NC}"
done

# ========= Firewall Status =========
print_section "Firewall Configuration"

if systemctl is-active --quiet firewall 2>/dev/null; then
  echo -e "${GREEN}● Firewall: active${NC}"
elif command -v iptables >/dev/null 2>&1; then
  if iptables -L -n 2>/dev/null | grep -q "Chain INPUT"; then
    echo -e "${GREEN}● Firewall: active (iptables)${NC}"
  else
    echo -e "${YELLOW}○ Firewall: inactive${NC}"
  fi
else
  echo -e "${YELLOW}○ Firewall: not configured${NC}"
fi

# Check NixOS firewall config
if [[ -f /etc/nixos/configuration.nix ]] || [[ -d /etc/nixos ]]; then
  echo -e "\n${BOLD}Allowed Ports (from NixOS config):${NC}"
  # This is a rough estimate - actual ports depend on the evaluated config
  nixos-option networking.firewall.allowedTCPPorts 2>/dev/null | grep -v "^warning:" || echo "  (check flake configuration)"
fi

# ========= Quick Access URLs =========
print_section "Quick Access URLs"

cat <<EOF
${BOLD}Common Services:${NC}
  ${CYAN}SSH:${NC}          ssh ${CURRENT_USER}@${HOSTNAME}
  ${CYAN}Mosh:${NC}         mosh ${CURRENT_USER}@${HOSTNAME}

EOF

# Collect all active web services USING TRAEFIK DOMAINS
declare -A WEB_SERVICES
# Use detected Traefik dashboard port (9080 for WSL, 8080 for standard)
[[ "$TRAEFIK_STATUS" == "active" ]] && WEB_SERVICES["Traefik Dashboard"]="http://traefik.${BASE_DOMAIN}:${TRAEFIK_DASH}/dashboard/"
# Services accessed through Traefik HTTP port (8090 for WSL, 80 for standard)
[[ "$JELLYFIN_STATUS" == "active" ]] && WEB_SERVICES["Jellyfin"]="http://jellyfin.${BASE_DOMAIN}:${TRAEFIK_HTTP}"
[[ "$VAULTWARDEN_STATUS" == "active" ]] && WEB_SERVICES["Vaultwarden"]="http://vaultwarden.${BASE_DOMAIN}:${TRAEFIK_HTTP}"
[[ "$NEXTCLOUD_STATUS" == "active" ]] && WEB_SERVICES["Nextcloud"]="http://nextcloud.${BASE_DOMAIN}:${TRAEFIK_HTTP}"
[[ "$AUTHELIA_STATUS" == "active" ]] && WEB_SERVICES["Authelia"]="http://authelia.${BASE_DOMAIN}:${TRAEFIK_HTTP}"
[[ "$NAVIDROME_STATUS" == "active" ]] && WEB_SERVICES["Navidrome"]="http://navidrome.${BASE_DOMAIN}:${TRAEFIK_HTTP}"
[[ "$SEAFILE_STATUS" == "active" ]] && WEB_SERVICES["Seafile"]="http://seafile.${BASE_DOMAIN}:${TRAEFIK_HTTP}"
[[ "$GITEA_STATUS" == "active" ]] && WEB_SERVICES["Gitea"]="http://gitea.${BASE_DOMAIN}:${TRAEFIK_HTTP}"
[[ "$SONARR_STATUS" == "active" ]] && WEB_SERVICES["Sonarr"]="http://sonarr.${BASE_DOMAIN}:${TRAEFIK_HTTP}"
[[ "$RADARR_STATUS" == "active" ]] && WEB_SERVICES["Radarr"]="http://radarr.${BASE_DOMAIN}:${TRAEFIK_HTTP}"
[[ "$QBITTORRENT_STATUS" == "active" ]] && WEB_SERVICES["qBittorrent"]="http://qbittorrent.${BASE_DOMAIN}:${TRAEFIK_HTTP}"
[[ "$VIKUNJA_STATUS" == "active" ]] && WEB_SERVICES["Vikunja"]="http://vikunja.${BASE_DOMAIN}:${TRAEFIK_HTTP}"
[[ "$FRESHRSS_STATUS" == "active" ]] && WEB_SERVICES["FreshRSS"]="http://freshrss.${BASE_DOMAIN}:${TRAEFIK_HTTP}"
[[ "$FIREFLY_STATUS" == "active" ]] && WEB_SERVICES["Firefly III"]="http://firefly.${BASE_DOMAIN}:${TRAEFIK_HTTP}"
[[ "$HOMER_STATUS" == "active" ]] && WEB_SERVICES["Homer"]="http://homer.${BASE_DOMAIN}:${TRAEFIK_HTTP}"
[[ "$IMMICH_STATUS" == "active" ]] && WEB_SERVICES["Immich"]="http://immich.${BASE_DOMAIN}:${TRAEFIK_HTTP}"
# Services with direct access (not through Traefik)
[[ "$LLDAP_STATUS" == "active" ]] && WEB_SERVICES["LLDAP"]="http://${HOSTNAME}:17170"
[[ "$SYNCTHING_STATUS" == "active" ]] && WEB_SERVICES["Syncthing"]="http://${HOSTNAME}:8384"

if [[ ${#WEB_SERVICES[@]} -gt 0 ]]; then
  echo -e "${BOLD}Active Web Interfaces (via Traefik):${NC}"
  # Sort keys for consistent output
  mapfile -t sorted_keys < <(printf "%s\n" "${!WEB_SERVICES[@]}" | sort)
  for service in "${sorted_keys[@]}"; do
    # Simple alignment
    printf "  %-20s %s\n" "${CYAN}${service}:${NC}" "${WEB_SERVICES[$service]}"
  done
fi

# ========= Footer =========
print_header "Installation Complete!"

echo -e "${BOLD}Next Steps:${NC}"
echo -e "  1. Configure your services via their web interfaces"
echo -e "  2. Set up SSL certificates with Traefik (if enabled)"
echo -e "  3. Configure backups for important data"
echo -e "  4. Review firewall rules and security settings"
echo -e "  5. Set up monitoring and alerting (optional)"

echo -e "\n${BOLD}Useful Commands:${NC}"
echo -e "  ${CYAN}systemctl status <service>${NC}  - Check service status"
echo -e "  ${CYAN}journalctl -u <service>${NC}     - View service logs"
echo -e "  ${CYAN}nixos-rebuild switch --flake .#<host>${NC} - Apply configuration changes"
echo -e "  ${CYAN}$0${NC}                          - Run this status report again"

echo -e "\n${GREEN}${BOLD}Your NixOS PaaS is ready!${NC}\n"