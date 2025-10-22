# Proxmox provider configuration
# Authentication is done via PROXMOX_VE_API_TOKEN environment variable

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = true  # Set to false if you have valid SSL certificates

  # API token authentication (recommended)
  # Set environment variable: export PROXMOX_VE_API_TOKEN="user@pve!tokenid=secret"
  # The token is automatically picked up from the environment

  # Optional: SSH configuration for certain operations
  ssh {
    agent    = true
    username = "root"
  }

  # Optional: Timeout configurations
  timeout = 600  # 10 minutes for API operations
}