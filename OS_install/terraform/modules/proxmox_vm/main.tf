# terraform { ... }

# Generate random password for VM
resource "random_password" "vm_password" {
  length  = 20
  special = true
  override_special = "!@#$%^&*()-_=+[]{}|;:,.<>?"
}

# Pre-encode the DNS list for the template
locals {
  vm_dns_json = jsonencode(var.vm_dns)
}

# Cloud-init user-data snippet for QEMU agent installation
resource "proxmox_virtual_environment_file" "cloud_init_user_data" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.vm_node

  source_raw {
    # Render the template file, passing in our variables
    data = templatefile("${path.module}/templates/cloud-init.tftpl", {
      vm_name     = var.vm_name
      vm_username = var.vm_username
      ssh_key     = var.ssh_key
      vm_ip       = var.vm_ip
      vm_gateway  = var.vm_gateway
      vm_dns_json = local.vm_dns_json
      is_dhcp     = var.vm_ip == "dhcp"
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
  vm_id     = null  # Auto-assign VM ID

  scsi_hardware = "virtio-scsi-single"  # Fix for iothread warning

  # Clone from template VM 9000
  clone {
    vm_id        = 9000
    full         = true
    datastore_id = var.vm_storage
    retries      = 3
  }

  # Agent configuration
  agent {
    enabled = true
    timeout = "5m"
    trim    = true
    type    = "virtio"
  }

  # CPU configuration
  cpu {
    cores   = var.vm_cpus
    sockets = 1
    type    = "host"
    numa    = false
  }

  # Memory configuration
  memory {
    dedicated = var.vm_memory
  }

  # Disk configuration
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

  # Network configuration
  network_device {
    bridge   = var.vm_bridge
    vlan_id  = var.vm_vlan
    model    = "virtio"
    firewall = false
  }

  #
  # --- THIS IS THE CRITICAL FIX ---
  # This block must be empty except for these lines.
  #
  initialization {
    type         = "nocloud"
    datastore_id = var.vm_storage
    interface    = "ide2"

    # This tells Proxmox to use your custom template.
    user_data_file_id = proxmox_virtual_environment_file.cloud_init_user_data.id
  }

  # VGA configuration
  vga {
    type   = "serial0"
    memory = 16
  }

  # Serial device for console access
  serial_device {}

  # Boot configuration
  on_boot = true
  started = true

  # Stop VM on terraform destroy
  stop_on_destroy = true

  # Timeouts
  timeout_create      = 600
  timeout_clone       = 600
  timeout_start_vm    = 300
  timeout_shutdown_vm = 180
  timeout_stop_vm     = 120

  # Lifecycle management
  lifecycle {
    ignore_changes = [
      started,
    ]
  }

  depends_on = [
    proxmox_virtual_environment_file.cloud_init_user_data
  ]
}

# Extract IP address for output
locals {
  vm_ip_address = var.vm_ip == "dhcp" ? (
    length(proxmox_virtual_environment_vm.ubuntu_server.ipv4_addresses) > 1 ?
    proxmox_virtual_environment_vm.ubuntu_server.ipv4_addresses[1][0] : "dhcp-pending"
  ) : split("/", var.vm_ip)[0]
}