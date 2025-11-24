# Network configuration utilities and defaults
# Provides flexible networking setup for both static and DHCP configurations
{ config, pkgs, lib, hostname, ... }:

{
  # === Network Manager ===
  # Disabled by default for servers, prefer manual configuration
  networking.networkmanager.enable = lib.mkDefault false;

  # === Hostname Configuration ===
  networking.hostName = lib.mkDefault hostname;

  # === DNS Configuration ===
  networking.nameservers = lib.mkDefault [
    "1.1.1.1"      # Cloudflare primary
    "1.0.0.1"      # Cloudflare secondary
    "8.8.8.8"      # Google primary
    "8.8.4.4"      # Google secondary
  ];

  # === Network Interface Configuration ===
  # By default, use DHCP on all interfaces
  # Override per-host for static IP configuration
  networking.useDHCP = lib.mkDefault true;

  # === IPv6 Configuration ===
  networking.enableIPv6 = lib.mkDefault true;

  # === Hosts File ===
  networking.hosts = {
    "127.0.0.1" = [ "localhost" ];
    "::1" = [ "localhost" "ip6-localhost" "ip6-loopback" ];
  };

  # === Firewall Ports (Common Services) ===
  # These are disabled by default, enable per-host as needed
  # networking.firewall.allowedTCPPorts = [
  #   22    # SSH (enabled by default in security.nix)
  #   80    # HTTP (Traefik)
  #   443   # HTTPS (Traefik)
  #   8080  # Traefik Dashboard
  # ];

  # === Network Bridge Support ===
  # Useful for Docker, LXC, VMs
  # Disabled by default, enable per-host if needed
  # networking.bridges = {
  #   "br0" = {
  #     interfaces = [ "eth0" ];
  #   };
  # };

  # === DHCP Client Configuration ===
  networking.dhcpcd = {
    enable = lib.mkDefault true;
    # Wait for network before considering boot complete
    wait = "background";
    extraConfig = ''
      # Disable IPv6 router solicitation
      noipv6rs

      # Request hostname from DHCP server
      hostname

      # Timeout for DHCP requests
      timeout 30
    '';
  };

  # === Static IP Helper Function ===
  # To use static IP, import this in your host configuration:
  #
  # networking.interfaces.eth0 = {
  #   useDHCP = false;
  #   ipv4.addresses = [{
  #     address = "192.168.1.100";
  #     prefixLength = 24;
  #   }];
  # };
  # networking.defaultGateway = "192.168.1.1";
  # networking.nameservers = [ "8.8.8.8" "1.1.1.1" ];

  # === Network Time Protocol ===
  services.timesyncd = {
    enable = lib.mkDefault true;
    servers = [
      "0.nixos.pool.ntp.org"
      "1.nixos.pool.ntp.org"
      "2.nixos.pool.ntp.org"
      "3.nixos.pool.ntp.org"
    ];
  };

  # === mDNS (Avahi) ===
  # Useful for local network discovery
  services.avahi = {
    enable = lib.mkDefault false;
    nssmdns4 = lib.mkDefault false;
    publish = {
      enable = lib.mkDefault false;
      addresses = lib.mkDefault false;
      domain = lib.mkDefault false;
      hinfo = lib.mkDefault false;
      userServices = lib.mkDefault false;
      workstation = lib.mkDefault false;
    };
  };

  # === Network Optimization ===
  boot.kernel.sysctl = {
    # TCP tuning for better network performance
    "net.core.rmem_max" = lib.mkDefault 134217728;
    "net.core.wmem_max" = lib.mkDefault 134217728;
    "net.ipv4.tcp_rmem" = lib.mkDefault "4096 87380 67108864";
    "net.ipv4.tcp_wmem" = lib.mkDefault "4096 65536 67108864";

    # Increase max connections
    "net.core.somaxconn" = lib.mkDefault 4096;
    "net.ipv4.tcp_max_syn_backlog" = lib.mkDefault 8192;

    # Enable TCP Fast Open
    "net.ipv4.tcp_fastopen" = lib.mkDefault 3;

    # TCP congestion control (BBR for better performance)
    "net.core.default_qdisc" = lib.mkDefault "fq";
    "net.ipv4.tcp_congestion_control" = lib.mkDefault "bbr";

    # Reuse TIME_WAIT connections
    "net.ipv4.tcp_tw_reuse" = lib.mkDefault 1;

    # Network buffer sizes
    "net.core.netdev_max_backlog" = lib.mkDefault 16384;
  };

  # === Wireless Support ===
  # Disabled by default for servers
  # Note: nixos-anywhere does not support WiFi networks
  networking.wireless.enable = lib.mkDefault false;

  # === Proxy Configuration ===
  # networking.proxy = {
  #   default = lib.mkDefault null;
  #   noProxy = lib.mkDefault "127.0.0.1,localhost,internal.domain";
  # };

  # === Network Utilities ===
  environment.systemPackages = with pkgs; [
    # Network debugging
    bind        # dig, nslookup
    inetutils   # telnet, ftp, etc.
    mtr         # traceroute + ping
    socat       # Socket cat
    netcat-gnu  # Network connections

    # Monitoring
    iftop       # Network bandwidth monitoring
    nethogs     # Per-process bandwidth monitoring
    iperf3      # Network performance testing

    # Tools
    ethtool     # Ethernet configuration
    bridge-utils # Bridge management
    wireguard-tools # VPN tools
  ];
}
