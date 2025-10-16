output "vm_id"   { value = proxmox_vm_qemu.this.id }
output "ip_hint" { value = var.install.network.address_cidr }