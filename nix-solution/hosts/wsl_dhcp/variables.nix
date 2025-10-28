{
  username = "wsluser_dhcp";
  networking = {
    mode = "dhcp";
    interface = "eth0";
    ipv4 = {
      address = "192.168.1.50";
      prefixLength = 24;
      gateway = "192.168.1.1";
      nameservers = [ ];
    };
  };
}
