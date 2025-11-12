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
#   PM_API_URL            = "https://192.168.1.111:8006/api2/json"
#   PM_API_TOKEN_ID       = "karcsi@pam!api-token"
#   PM_API_TOKEN_SECRET   = "9c29fcac-7b0c-4cd8-83c5-8e66fce5e26c"
#   PM_TLS_INSECURE       = "true"
# You may also pass pm_api_url/pm_tls_insecure via variables; secrets should remain in env.
provider "proxmox" {
  # Prefer env vars; allow override via variables for pm_api_url/tls policy
  pm_api_url     = "https://192.168.1.111:8006/api2/json"
  pm_api_token_id = "karcsi@pam!api-token"
  pm_api_token_secret = "9c29fcac-7b0c-4cd8-83c5-8e66fce5e26c"
  pm_tls_insecure = "true"
}