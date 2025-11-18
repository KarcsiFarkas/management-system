# Outputs
output "vm_id" {
  description = "Proxmox VM ID"
  value       = proxmox_vm_qemu.ubuntu_server.vmid
}

output "vm_ip" {
  description = "VM IP Address"
  value       = local.vm_ip_address
}

output "vm_password" {
  description = "VM ubuntu user password"
  value       = random_password.vm_password.result
  sensitive   = true
}

output "ssh_command" {
  description = "SSH command to connect to VM"
  value       = "ssh ${var.vm_username}@${local.vm_ip_address}"
}
