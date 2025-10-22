variable "name" { type = string }
variable "node" { type = string }
variable "storage" { type = string }
variable "bridge" { type = string }
variable "vlan" {
  type    = number
  default = null
}
variable "cpus" { type = number }
variable "memory_mb" { type = number }
variable "disk_size_gb" { type = number }
variable "ip_cidr" { type = string }
variable "gateway" { type = string }
variable "dns" { type = list(string) }
variable "ssh_key" { type = string }
