{
  username = "CHANGEME";

  networking = {
    mode = "dhcp"; # "static" or "dhcp"

    # Only used when mode = "static"
    interface = "eth0";
    ipv4 = {
      address = "192.168.1.50";
      prefixLength = 24;
      gateway = "192.168.1.1";
      nameservers = [ "1.1.1.1" "8.8.8.8" ];
    };
    # ipv6 optional:
    # ipv6 = {
    #   address = "fd00::50";
    #   prefixLength = 64;
    #   gateway = "fd00::1";
    #   nameservers = [ "2606:4700:4700::1111" ];
    # };
  };
}
