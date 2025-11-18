# Generate a random fallback password for the default cloud-init user
resource "random_password" "vm_password" {
  length           = 20
  special          = true
  override_special = "!@#$%^&*()-_=+[]{}|;:,.<>?"
}

locals {
  is_dhcp          = var.vm_ip == "dhcp"
  nameserver_value = length(var.vm_dns) > 0 ? join(" ", var.vm_dns) : null
  ipconfig0_value  = local.is_dhcp ? "dhcp" : format("ip=%s%s", var.vm_ip, var.vm_gateway != "" ? format(",gw=%s", var.vm_gateway) : "")
  vm_ip_address    = local.is_dhcp ? try(proxmox_vm_qemu.ubuntu_server.default_ipv4_address, "dhcp-pending") : split("/", var.vm_ip)[0]
  vlan_tag         = var.vm_vlan == null ? 0 : var.vm_vlan
}

resource "proxmox_vm_qemu" "ubuntu_server" {
  name        = var.vm_name
  target_node = var.vm_node
  desc        = "Managed by Terraform - PaaS VM"
  tags        = "terraform,paas,ubuntu"

  clone      = tostring(var.ubuntu_template)
  full_clone = true
  onboot     = true
  agent      = 1
  scsihw     = "virtio-scsi-single"
  sockets    = 1
  cores      = var.vm_cpus
  cpu        = "host"
  numa       = false
  memory     = var.vm_memory

  network {
    model    = "virtio"
    bridge   = var.vm_bridge
    tag      = local.vlan_tag
    firewall = false
  }

  os_type                 = "cloud-init"
  cloudinit_cdrom_storage = var.vm_storage
  ciuser                  = var.vm_username
  cipassword              = random_password.vm_password.result
  sshkeys                 = var.ssh_key
  nameserver              = local.nameserver_value
  ipconfig0               = local.ipconfig0_value

  vga {
    type = "serial0"
  }

  serial {
    id   = 0
    type = "socket"
  }
}
