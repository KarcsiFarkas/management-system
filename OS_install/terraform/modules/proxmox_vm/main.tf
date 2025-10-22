# Note: Provider configuration is in the root module
# This module uses the bpg/proxmox provider

resource "proxmox_virtual_environment_vm" "ubuntu_server" {
  name      = var.name
  node_name = var.node
  
  # Clone from template
  clone {
    vm_id = 9000  # ubuntu-2404-cloud-template
  }

  # CPU and Memory
  cpu {
    cores = var.cpus
  }
  
  memory {
    dedicated = var.memory_mb
  }

  # Agent
  agent {
    enabled = true
  }

  # Disk configuration
  disk {
    datastore_id = var.storage
    interface    = "scsi0"
    size         = var.disk_size_gb
  }

  # Network configuration
  network_device {
    bridge = var.bridge
    model  = "virtio"
    vlan_id = var.vlan
  }

  # Cloud-init configuration
  initialization {
    ip_config {
      ipv4 {
        address = var.ip_cidr
        gateway = var.gateway
      }
    }
    
    dns {
      servers = var.dns
    }
    
    user_account {
      username = "ubuntu"
      keys     = [var.ssh_key]
    }
  }

  lifecycle {
    ignore_changes = [network_device]
  }
}