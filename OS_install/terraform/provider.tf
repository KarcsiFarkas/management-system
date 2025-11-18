terraform {
  required_version = ">= 1.3"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.50"
    }
  }
}

# Proxmox provider configuration (bpg fork)
# Secrets (API token) are supplied via the PROXMOX_VE_API_TOKEN env var.
provider "proxmox" {
  endpoint = coalesce(var.pm_api_url, var.proxmox_endpoint)
  insecure = var.pm_tls_insecure

  ssh {
    agent       = false
    username    = "root"
    private_key = file(var.proxmox_ssh_private_key_path)
  }
}
