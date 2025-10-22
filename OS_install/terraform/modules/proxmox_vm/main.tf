# terraform {
#   required_version = ">= 1.0"
#   required_providers {
#     proxmox = {
#       source  = "bpg/proxmox"
#       version = "~> 0.50"
#     }
#     random = {
#       source  = "hashicorp/random"
#       version = "~> 3.6"
#     }
#     null = {
#       source  = "hashicorp/null"
#       version = "~> 3.2"
#     }
#   }
# }

# Generate random password for VM
resource "random_password" "vm_password" {
  length  = 20
  special = true
  override_special = "!@#$%^&*()-_=+[]{}|;:,.<>?"
}

# Cloud-init user-data snippet for QEMU agent installation
resource "proxmox_virtual_environment_file" "cloud_init_user_data" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.vm_node

  source_raw {
    data = <<-EOF
      #cloud-config
      hostname: ${var.vm_name}
      manage_etc_hosts: true

      # Critical: Install and enable QEMU guest agent
      packages:
        - qemu-guest-agent
        - cloud-init

      package_update: true
      package_upgrade: false

      # Ensure qemu-agent starts immediately
      runcmd:
        - systemctl daemon-reload
        - systemctl enable qemu-guest-agent
        - systemctl start qemu-guest-agent
        - echo "QEMU Guest Agent started" > /tmp/qemu-agent-status

      # Fix cloud-init to not wait indefinitely
      datasource_list: [ NoCloud, ConfigDrive ]

      # Set timezone
      timezone: UTC

      # Enable SSH
      ssh_pwauth: true
      disable_root: false

      # Final message
      final_message: "Cloud-init completed after $UPTIME seconds"
    EOF

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

  scsi_hardware = "virtio-scsi-single"  # <-- ADD THIS LINE
  # Clone from template VM 9000
  clone {
    vm_id        = 9000
    full         = true
    datastore_id = var.vm_storage
    retries      = 3
  }

  # Agent configuration - reduced timeout to fail faster
  agent {
    enabled = true
    timeout = "5m"   # String format is correct for agent timeout
    trim    = true
    type    = "virtio"
  }

  # CPU configuration
  cpu {
    cores   = var.vm_cpus
    sockets = 1
    type    = "host"  # Better performance than qemu64
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

  # Cloud-init initialization
  initialization {
    type         = "nocloud"  # More reliable
    datastore_id = var.vm_storage
    interface    = "ide2"

    # DNS configuration
    dns {
      servers = var.vm_dns
    }

    # IP configuration - support both DHCP and static
    ip_config {
      ipv4 {
        address = var.vm_ip == "dhcp" ? "dhcp" : var.vm_ip
        gateway = var.vm_ip == "dhcp" ? null : (var.vm_gateway != "" ? var.vm_gateway : null)
      }
    }

    # User account configuration
# User account configuration
    user_account {
      username = var.vm_username
      password = random_password.vm_password.result
      keys     = var.ssh_key != "" ? [var.ssh_key] : []
    }

    # Attach custom user-data for QEMU agent
    user_data_file_id = proxmox_virtual_environment_file.cloud_init_user_data.id
  }

  # VGA configuration - use serial for cloud-init logs
  vga {
    type   = "serial0"
    memory = 16
  }

  # Serial device for console access and debugging
  serial_device {}

  # Boot configuration
  on_boot = true
  started = true

  # Stop VM on terraform destroy
  stop_on_destroy = true

  # Reduced timeouts to fail faster (in seconds)
  timeout_create      = 600   # 10 minutes
  timeout_clone       = 600   # 10 minutes
  timeout_start_vm    = 300   # 5 minutes
  timeout_shutdown_vm = 180   # 3 minutes
  timeout_stop_vm     = 120   # 2 minutes

  # Lifecycle management
  lifecycle {
    ignore_changes = [
      started,
      ipv4_addresses,
      ipv6_addresses,
      network_interface_names,
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