terraform {
  required_version = ">= 1.3"
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "~> 2.9"
    }
  }
}

# Proxmox Telmate provider configuration
# Authentication is recommended via environment variables:
#   PM_API_URL            = "https://pve:8006/api2/json"
#   PM_API_TOKEN_ID       = "user@pve!token-name"
#   PM_API_TOKEN_SECRET   = "<secret>"
#   PM_TLS_INSECURE       = "true" | "false"
# You may also pass pm_api_url/pm_tls_insecure via variables; secrets should remain in env.
provider "proxmox" {
  # Prefer env vars; allow override via variables for pm_api_url/tls policy
  pm_api_url     = coalesce(var.pm_api_url, var.proxmox_endpoint)
  pm_tls_insecure = var.pm_tls_insecure
}