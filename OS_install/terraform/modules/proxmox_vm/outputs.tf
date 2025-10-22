output "vm_id" {
  value = proxmox_virtual_environment_vm.ubuntu_server.id
}

output "ip_address" {
  value = var.ip_cidr == "dhcp" ? "" : split("/", var.ip_cidr)[0]
}