{
  username = "nixuser";

  networking = {
    mode = "static";          # or "dhcp"
    interface = "eth0";
    ipv4 = {
      address = "192.168.1.50";
      prefixLength = 24;
      gateway = "192.168.1.1";
      nameservers = [ "1.1.1.1" "8.8.8.8" ];
    };
  };
}
