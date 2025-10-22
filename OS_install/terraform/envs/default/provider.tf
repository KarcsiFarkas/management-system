terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.60.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = var.proxmox_insecure
  
  
  # SSH configuration for advanced operations (VM disk import, snippets, etc.)
  ssh {
    agent    = true
    username = var.proxmox_ssh_username
  }
}

# Proxmox connection variables
# These can be sourced from environment variables:
# - PROXMOX_VE_ENDPOINT
# - PROXMOX_VE_API_TOKEN
# - PROXMOX_VE_INSECURE
# - PROXMOX_VE_SSH_USERNAME

variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox API endpoint URL"
  default     = ""  # Source from PROXMOX_VE_ENDPOINT env var
}


variable "proxmox_insecure" {
  type        = bool
  description = "Skip TLS verification (not recommended for production)"
  default     = true
}

variable "proxmox_ssh_username" {
  type        = string
  description = "SSH username for Proxmox node access"
  default     = "root"
}