# Root-level outputs that expose module outputs to provision.py

output "vm_id" {
  description = "Proxmox VM ID"
  value       = module.paas_vm.vm_id
}

output "vm_name" {
  description = "VM name"
  value       = var.vm_name
}

output "vm_ip" {
  description = "VM IP address"
  value       = module.paas_vm.vm_ip
}

output "vm_password" {
  description = "Generated password for ubuntu user"
  value       = module.paas_vm.vm_password
  sensitive   = true
}

output "ssh_command" {
  description = "SSH command to connect to VM"
  value       = module.paas_vm.ssh_command
}

# Output all details for Ansible to consume
output "ansible_host_vars" {
  description = "Variables for Ansible inventory"
  value = {
    ansible_host     = module.paas_vm.vm_ip
    ansible_user     = "ubuntu"
    vm_id            = module.paas_vm.vm_id
    vm_name          = var.vm_name
  }
  sensitive = false
}