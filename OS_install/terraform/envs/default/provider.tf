terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = ">= 3.0.0"
    }
  }
}

provider "proxmox" {
  pm_api_url = var.pm_api_url
  # Authentication via env:
  #   PM_USER, PM_PASS or PM_API_TOKEN_ID, PM_API_TOKEN_SECRET
  #   PM_TLS_INSECURE=1 (if using self-signed; prefer proper CA in production)
}

variable "pm_api_url" { type = string, default = "https://proxmox.example:8006/api2/json" }