terraform {
  required_version = ">= 1.3"

  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "~> 2.9"
    }
  }
}

# Telmate Proxmox provider (Proxmox VE 8)
# Recommended auth via environment variables:
#   PM_API_URL            = "https://192.168.1.111:8006/api2/json"
#   PM_API_TOKEN_ID       = "karcsi@pam!api-token"
#   PM_API_TOKEN_SECRET   = "9c29fcac-7b0c-4cd8-83c5-8e66fce5e26c"
#   PM_TLS_INSECURE       = "true"
# Optionally pass pm_api_url/pm_tls_insecure via variables; secrets must remain in env.
provider "proxmox" {
  pm_api_url      = coalesce(var.pm_api_url, var.proxmox_endpoint)
  pm_tls_insecure = var.pm_tls_insecure
}

# Variables for provider configuration
variable "pm_api_url" {
  description = "Proxmox VE API endpoint (Telmate)"
  type        = string
  default     = null
}

variable "proxmox_endpoint" {
  description = "[Deprecated] Proxmox VE API endpoint (legacy)"
  type        = string
  default     = null
}

variable "pm_tls_insecure" {
  description = "Allow self-signed TLS on Proxmox API"
  type        = bool
  default     = true
}