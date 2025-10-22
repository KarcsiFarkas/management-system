terraform {
  required_version = ">= 1.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.50"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = true  # Set to false in production with valid certs

  # Authentication via API token (recommended)
  # Set these via environment variables:
  # export PROXMOX_VE_API_TOKEN="user@realm!tokenid=secret"
  # OR via terraform.tfvars (not recommended for secrets)

  # Enable for debugging
  # api_token = var.proxmox_api_token  # Only if passing explicitly

  ssh {
    agent    = true
    username = "root"
  }
}

# Variables for provider configuration
variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint"
  type        = string
  default     = "https://192.168.1.111:8006/api2/json"
}

# Uncomment if passing token directly (not recommended)
# variable "proxmox_api_token" {
#   description = "Proxmox API token"
#   type        = string
#   sensitive   = true
# }