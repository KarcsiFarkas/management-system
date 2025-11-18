# Generate random password for VM
resource "random_password" "vm_password" {
  length           = 20
  special          = true
  override_special = "!@#$%^&*()-_=+[]{}|;:,.<>?"
}

# Pre-encode the DNS list for the template
locals {
  vm_dns_json = jsonencode(var.vm_dns)
  is_dhcp     = var.vm_ip == "dhcp"
}

# Cloud-init user-data snippet for QEMU agent installation
resource "proxmox_virtual_environment_file" "cloud_init_user_data" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.vm_node

  source_raw {
    data = templatefile("${path.module}/templates/cloud-init.tftpl", {
      vm_name     = var.vm_name
      vm_username = var.vm_username
      ssh_key     = var.ssh_key
      vm_ip       = var.vm_ip
      vm_gateway  = var.vm_gateway
      vm_dns_json = local.vm_dns_json
      is_dhcp     = local.is_dhcp
    })

    file_name = "cloud-init-${var.vm_name}.yaml"
  }
}

# Main VM resource
resource "proxmox_virtual_environment_vm" "ubuntu_server" {
  name        = var.vm_name
  description = "Managed by Terraform - PaaS VM"
  tags        = ["terraform", "paas", "ubuntu"]

  node_name = var.vm_node
  vm_id     = null

  scsi_hardware = "virtio-scsi-single"

  clone {
    vm_id        = var.ubuntu_template
    full         = true
    datastore_id = var.vm_storage
    retries      = 3
  }

  agent {
    enabled = true
    timeout = "5m"
    trim    = true
    type    = "virtio"
  }

  cpu {
    cores   = var.vm_cpus
    sockets = 1
    type    = "host"
    numa    = false
  }

  memory {
    dedicated = var.vm_memory
  }

  disk {
    datastore_id = var.vm_storage
    interface    = "scsi0"
    size         = var.vm_disk_size
    file_format  = "raw"
    cache        = "writethrough"
    discard      = "on"
    ssd          = true
    iothread     = true
  }

  network_device {
    bridge   = var.vm_bridge
    vlan_id  = var.vm_vlan
    model    = "virtio"
    firewall = false
  }

  initialization {
    type         = "nocloud"
    datastore_id = var.vm_storage
    interface    = "ide2"

    dynamic "ip_config" {
      for_each = local.is_dhcp ? [1] : []
      content {
        ipv4 {
          address = "dhcp"
        }
      }
    }

    dynamic "ip_config" {
      for_each = local.is_dhcp ? [] : [1]
      content {
        ipv4 {
          address = var.vm_ip
          gateway = var.vm_gateway
        }
      }
    }

    dns {
      servers = var.vm_dns
    }

    user_account {
      username = var.vm_username
      password = ""
      keys     = [var.ssh_key]
    }

    user_data_file_id = proxmox_virtual_environment_file.cloud_init_user_data.id
  }

  vga {
    type   = "serial0"
    memory = 16
  }

  serial_device {}

  on_boot = true
  started = true

  stop_on_destroy = true

  timeout_create      = 600
  timeout_clone       = 600
  timeout_start_vm    = 300
  timeout_shutdown_vm = 180
  timeout_stop_vm     = 120

  lifecycle {
    ignore_changes = [
      started,
    ]
  }

  depends_on = [
    proxmox_virtual_environment_file.cloud_init_user_data
  ]
}

locals {
  vm_ip_address = var.vm_ip == "dhcp" ? (
    length(proxmox_virtual_environment_vm.ubuntu_server.ipv4_addresses) > 1 ?
    proxmox_virtual_environment_vm.ubuntu_server.ipv4_addresses[1][0] : "dhcp-pending"
  ) : split("/", var.vm_ip)[0]
}
