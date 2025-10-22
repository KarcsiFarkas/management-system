# Outputs
output "vm_id" {
  description = "Proxmox VM ID"
  value       = proxmox_virtual_environment_vm.ubuntu_server.vm_id
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
  value       = "ssh ubuntu@${local.vm_ip_address}"
}