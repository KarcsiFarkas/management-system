variable "vm_name" {
  description = "Name of the VM"
  type        = string
}

variable "vm_node" {
  description = "Proxmox node name"
  type        = string
}

variable "vm_storage" {
  description = "Storage pool for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "vm_bridge" {
  description = "Network bridge"
  type        = string
  default     = "vmbr0"
}

variable "vm_vlan" {
  description = "VLAN ID (null for no VLAN)"
  type        = number
  default     = null
}

variable "vm_cpus" {
  description = "Number of CPU cores"
  type        = number
  default     = 2

  validation {
    condition     = var.vm_cpus >= 1 && var.vm_cpus <= 128
    error_message = "CPU cores must be between 1 and 128"
  }
}

variable "vm_memory" {
  description = "Memory in MB"
  type        = number
  default     = 4096

  validation {
    condition     = var.vm_memory >= 512
    error_message = "Memory must be at least 512 MB"
  }
}

variable "vm_disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.vm_disk_size >= 8
    error_message = "Disk size must be at least 8 GB"
  }
}

variable "vm_ip" {
  description = "IP address with CIDR (e.g., '192.168.1.10/24') or 'dhcp'"
  type        = string
  default     = "dhcp"
}

variable "vm_gateway" {
  description = "Default gateway IP address"
  type        = string
  default     = ""
}

variable "vm_dns" {
  description = "List of DNS servers"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "ssh_key" {
  description = "SSH public key for ubuntu user"
  type        = string
  default     = ""
  sensitive   = true
}

variable "vm_username" {
  description = "The username for the default cloud-init user."
  type        = string
  default     = "test"
}

variable "ubuntu_template" {
  description = "VM ID of the Ubuntu Cloud-Init template to clone"
  type        = number
  default     = 9000
}