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

# Call the proxmox_vm module
module "paas_vm" {
  source = "./modules/proxmox_vm"

  # Pass variables from root to module
  vm_name      = var.vm_name
  vm_node      = var.vm_node
  vm_storage   = var.vm_storage
  vm_bridge    = var.vm_bridge
  vm_vlan      = var.vm_vlan
  vm_cpus      = var.vm_cpus
  vm_memory    = var.vm_memory
  vm_disk_size = var.vm_disk_size
  vm_ip        = var.vm_ip
  vm_gateway   = var.vm_gateway
  vm_dns       = var.vm_dns
  ssh_key      = var.ssh_key
  vm_username  = var.vm_username
}