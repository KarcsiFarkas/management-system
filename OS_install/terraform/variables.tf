# Root-level variables that provision.py will populate via terraform.tfvars.json

# New Telmate provider inputs (with backward-compatibility alias)
variable "pm_api_url" {
  description = "Proxmox VE API endpoint URL (Telmate provider)"
  type        = string
  default     = null
}

# Backwards-compatibility for old configs; used as fallback if pm_api_url is null
variable "proxmox_endpoint" {
  description = "[Deprecated] Proxmox VE API endpoint URL (legacy)"
  type        = string
  default     = null
}

variable "pm_tls_insecure" {
  description = "Allow self-signed TLS certificates for Proxmox API"
  type        = bool
  default     = true
}

variable "vm_name" {
  description = "Name of the VM to create"
  type        = string
}

variable "vm_node" {
  description = "Proxmox node name where VM will be created"
  type        = string
}

variable "vm_storage" {
  description = "Storage pool for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "vm_bridge" {
  description = "Network bridge to attach VM to"
  type        = string
  default     = "vmbr0"
}

variable "vm_vlan" {
  description = "VLAN ID (null for no VLAN tagging)"
  type        = number
  default     = null
}

variable "vm_cpus" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "vm_memory" {
  description = "Memory size in MB"
  type        = number
  default     = 4096
}

variable "vm_disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 20
}

variable "vm_ip" {
  description = "IP address with CIDR notation (e.g., '192.168.1.10/24') or 'dhcp'"
  type        = string
  default     = "dhcp"
}

variable "vm_gateway" {
  description = "Default gateway IP address (required for static IP)"
  type        = string
  default     = ""
}

variable "vm_dns" {
  description = "List of DNS server IP addresses"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "ssh_key" {
  description = "SSH public key for default user authentication"
  type        = string
  default     = ""
  sensitive   = true
}

variable "vm_username" {
  description = "The username for the default cloud-init user (Ubuntu module)."
  type        = string
  default     = "ubuntu"
}

variable "proxmox_ssh_private_key_path" {
  description = "Absolute path to the SSH private key used by the Proxmox provider for SSH operations"
  type        = string
}

# Ubuntu module specific
variable "ubuntu_template" {
  description = "Template VMID to clone for Ubuntu cloud-init base (e.g., 9000)"
  type        = number
  default     = 9000
}

# NixOS module specific
variable "nixos_template" {
  description = "Template VMID to clone for NixOS base (e.g., 8000)"
  type        = number
  default     = 8000
}
