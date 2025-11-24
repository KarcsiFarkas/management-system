# Host-specific variables
# These variables are used by the flake to configure the host
{
  # Username for the main user account
  username = "nixuser";

  # Tenant identifier (used to load tenant-specific configuration)
  tenant = "default";

  # Disk layout to use (see disk-configs/ directory)
  diskLayout = "standard-gpt";

  # System architecture
  system = "x86_64-linux";

  # Network configuration
  networking = {
    # Interface name (check with 'ip link' on target machine)
    interface = "eth0";

    # Network mode: "dhcp" or "static"
    mode = "dhcp";

    # Static IP configuration (only used if mode = "static")
    ipv4 = {
      address = "192.168.1.100";
      prefixLength = 24;
      gateway = "192.168.1.1";
      nameservers = [ "1.1.1.1" "8.8.8.8" ];
    };
  };
}
