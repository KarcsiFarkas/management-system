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

HOSTNAME=$(get_hostname_or_ip)
CURRENT_USER=$(whoami)
NIXOS_VERSION=$(nixos-version 2>/dev/null || echo "unknown")

echo -e "${BOLD}System Information:${NC}"
echo -e "  Hostname:     ${GREEN}$HOSTNAME${NC}"
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
  TRAEFIK_HTTP=$(check_port_listening 80 && echo "80" || echo "")
  TRAEFIK_HTTPS=$(check_port_listening 443 && echo "443" || echo "")
  TRAEFIK_DASH=$(check_port_listening 8080 && echo "8080" || echo "")

  TRAEFIK_PORTS="HTTP:${TRAEFIK_HTTP:-off} HTTPS:${TRAEFIK_HTTPS:-off} Dashboard:${TRAEFIK_DASH:-off}"
  TRAEFIK_URL="http://${HOSTNAME}:${TRAEFIK_DASH:-8080}/dashboard/"

  print_service "Traefik" "$TRAEFIK_STATUS" "$TRAEFIK_PORTS" "$TRAEFIK_URL" "Reverse proxy & SSL termination"
else
  print_service "Traefik" "not-installed" "" "" ""
fi

# ========= Authentication & SSO =========
print_section "Authentication & Single Sign-On"

AUTHELIA_STATUS=$(get_service_status "authelia-main")
if [[ "$AUTHELIA_STATUS" != "not-installed" ]]; then
  AUTHELIA_PORT=$(check_port_listening 9091 && echo "9091" || echo "")
  AUTHELIA_URL="http://${HOSTNAME}:${AUTHELIA_PORT:-9091}"
  print_service "Authelia" "$AUTHELIA_STATUS" "${AUTHELIA_PORT:-9091}" "$AUTHELIA_URL" "2FA & SSO authentication"
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
  JELLYFIN_URL="http://${HOSTNAME}:${JELLYFIN_HTTP:-8096}"
  print_service "Jellyfin" "$JELLYFIN_STATUS" "HTTP:${JELLYFIN_HTTP:-8096} HTTPS:${JELLYFIN_HTTPS:-8920}" "$JELLYFIN_URL" "Media streaming server"
else
  print_service "Jellyfin" "not-installed" "" "" ""
fi

NAVIDROME_STATUS=$(get_service_status "navidrome")
if [[ "$NAVIDROME_STATUS" != "not-installed" ]]; then
  NAVIDROME_PORT=$(check_port_listening 4533 && echo "4533" || echo "")
  NAVIDROME_URL="http://${HOSTNAME}:${NAVIDROME_PORT:-4533}"
  print_service "Navidrome" "$NAVIDROME_STATUS" "${NAVIDROME_PORT:-4533}" "$NAVIDROME_URL" "Music streaming server"
else
  print_service "Navidrome" "not-installed" "" "" ""
fi

# ========= Cloud Storage & Sync =========
print_section "Cloud Storage & File Sync"

NEXTCLOUD_STATUS=$(get_service_status "phpfpm-nextcloud")
if [[ "$NEXTCLOUD_STATUS" != "not-installed" ]]; then
  NEXTCLOUD_PORT=$(check_port_listening 80 && echo "80" || echo "")
  NEXTCLOUD_URL="http://${HOSTNAME}:${NEXTCLOUD_PORT:-80}"
  print_service "Nextcloud" "$NEXTCLOUD_STATUS" "${NEXTCLOUD_PORT:-80}" "$NEXTCLOUD_URL" "File sync & collaboration"
else
  print_service "Nextcloud" "not-installed" "" "" ""
fi

SEAFILE_STATUS=$(get_service_status "seafile")
if [[ "$SEAFILE_STATUS" != "not-installed" ]]; then
  SEAFILE_PORT=$(check_port_listening 8000 && echo "8000" || echo "")
  SEAFILE_URL="http://${HOSTNAME}:${SEAFILE_PORT:-8000}"
  print_service "Seafile" "$SEAFILE_STATUS" "${SEAFILE_PORT:-8000}" "$SEAFILE_URL" "File sync & sharing"
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
  VAULTWARDEN_URL="http://${HOSTNAME}:${VAULTWARDEN_HTTP:-8222}"
  print_service "Vaultwarden" "$VAULTWARDEN_STATUS" "HTTP:${VAULTWARDEN_HTTP:-8222} WS:${VAULTWARDEN_WS:-3012}" "$VAULTWARDEN_URL" "Bitwarden-compatible password manager"
else
  print_service "Vaultwarden" "not-installed" "" "" ""
fi

# ========= Development & Git =========
print_section "Development & Version Control"

GITEA_STATUS=$(get_service_status "gitea")
if [[ "$GITEA_STATUS" != "not-installed" ]]; then
  GITEA_HTTP=$(check_port_listening 3000 && echo "3000" || echo "")
  GITEA_SSH=$(check_port_listening 2222 && echo "2222" || echo "")
  GITEA_URL="http://${HOSTNAME}:${GITEA_HTTP:-3000}"
  print_service "Gitea" "$GITEA_STATUS" "HTTP:${GITEA_HTTP:-3000} SSH:${GITEA_SSH:-2222}" "$GITEA_URL" "Self-hosted Git service"
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
  SONARR_URL="http://${HOSTNAME}:${SONARR_PORT:-8989}"
  print_service "Sonarr" "$SONARR_STATUS" "${SONARR_PORT:-8989}" "$SONARR_URL" "TV show management"
else
  print_service "Sonarr" "not-installed" "" "" ""
fi

RADARR_STATUS=$(get_service_status "radarr")
if [[ "$RADARR_STATUS" != "not-installed" ]]; then
  RADARR_PORT=$(check_port_listening 7878 && echo "7878" || echo "")
  RADARR_URL="http://${HOSTNAME}:${RADARR_PORT:-7878}"
  print_service "Radarr" "$RADARR_STATUS" "${RADARR_PORT:-7878}" "$RADARR_URL" "Movie management"
else
  print_service "Radarr" "not-installed" "" "" ""
fi

QBITTORRENT_STATUS=$(get_service_status "qbittorrent")
if [[ "$QBITTORRENT_STATUS" != "not-installed" ]]; then
  QBITTORRENT_PORT=$(check_port_listening 8080 && echo "8080" || echo "")
  QBITTORRENT_URL="http://${HOSTNAME}:${QBITTORRENT_PORT:-8080}"
  print_service "qBittorrent" "$QBITTORRENT_STATUS" "${QBITTORRENT_PORT:-8080}" "$QBITTORRENT_URL" "BitTorrent client"
else
  print_service "qBittorrent" "not-installed" "" "" ""
fi

# ========= Productivity & Organization =========
print_section "Productivity & Organization"

VIKUNJA_STATUS=$(get_service_status "vikunja")
if [[ "$VIKUNJA_STATUS" != "not-installed" ]]; then
  VIKUNJA_PORT=$(check_port_listening 3456 && echo "3456" || echo "")
  VIKUNJA_URL="http://${HOSTNAME}:${VIKUNJA_PORT:-3456}"
  print_service "Vikunja" "$VIKUNJA_STATUS" "${VIKUNJA_PORT:-3456}" "$VIKUNJA_URL" "Todo & project management"
else
  print_service "Vikunja" "not-installed" "" "" ""
fi

FRESHRSS_STATUS=$(get_service_status "freshrss")
if [[ "$FRESHRSS_STATUS" != "not-installed" ]]; then
  FRESHRSS_PORT=$(check_port_listening 80 && echo "80" || echo "")
  FRESHRSS_URL="http://${HOSTNAME}:${FRESHRSS_PORT:-80}/freshrss"
  print_service "FreshRSS" "$FRESHRSS_STATUS" "${FRESHRSS_PORT:-80}" "$FRESHRSS_URL" "RSS feed aggregator"
else
  print_service "FreshRSS" "not-installed" "" "" ""
fi

FIREFLY_STATUS=$(get_service_status "firefly-iii")
if [[ "$FIREFLY_STATUS" != "not-installed" ]]; then
  FIREFLY_PORT=$(check_port_listening 8080 && echo "8080" || echo "")
  FIREFLY_URL="http://${HOSTNAME}:${FIREFLY_PORT:-8080}"
  print_service "Firefly III" "$FIREFLY_STATUS" "${FIREFLY_PORT:-8080}" "$FIREFLY_URL" "Personal finance manager"
else
  print_service "Firefly III" "not-installed" "" "" ""
fi

# ========= Dashboard =========
print_section "Dashboard & Monitoring"

HOMER_STATUS=$(get_service_status "homer")
if [[ "$HOMER_STATUS" != "not-installed" ]]; then
  HOMER_PORT=$(check_port_listening 8080 && echo "8080" || echo "")
  HOMER_URL="http://${HOSTNAME}:${HOMER_PORT:-8080}"
  print_service "Homer" "$HOMER_STATUS" "${HOMER_PORT:-8080}" "$HOMER_URL" "Application dashboard"
else
  print_service "Homer" "not-installed" "" "" ""
fi

IMMICH_STATUS=$(get_service_status "immich")
if [[ "$IMMICH_STATUS" != "not-installed" ]]; then
  IMMICH_PORT=$(check_port_listening 2283 && echo "2283" || echo "")
  IMMICH_URL="http://${HOSTNAME}:${IMMICH_PORT:-2283}"
  print_service "Immich" "$IMMICH_STATUS" "${IMMICH_PORT:-2283}" "$IMMICH_URL" "Photo & video backup"
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

# Collect all active web services
declare -A WEB_SERVICES
[[ "$TRAEFIK_STATUS" == "active" ]] && WEB_SERVICES["Traefik Dashboard"]="http://${HOSTNAME}:8080/dashboard/"
[[ "$JELLYFIN_STATUS" == "active" ]] && WEB_SERVICES["Jellyfin"]="http://${HOSTNAME}:8096"
[[ "$VAULTWARDEN_STATUS" == "active" ]] && WEB_SERVICES["Vaultwarden"]="http://${HOSTNAME}:8222"
[[ "$NEXTCLOUD_STATUS" == "active" ]] && WEB_SERVICES["Nextcloud"]="http://${HOSTNAME}"
[[ "$AUTHELIA_STATUS" == "active" ]] && WEB_SERVICES["Authelia"]="http://${HOSTNAME}:9091"
[[ "$LLDAP_STATUS" == "active" ]] && WEB_SERVICES["LLDAP"]="http://${HOSTNAME}:17170"

if [[ ${#WEB_SERVICES[@]} -gt 0 ]]; then
  echo -e "${BOLD}Active Web Interfaces:${NC}"
  for service in "${!WEB_SERVICES[@]}"; do
    echo -e "  ${CYAN}${service}:${NC} ${WEB_SERVICES[$service]}"
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