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
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = true

  ssh {
    agent       = false
    username    = "root"
    private_key = file(var.proxmox_ssh_private_key_path)
  }
}

variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint"
  type        = string
  default     = "https://192.168.1.111:8006/api2/json"
}
