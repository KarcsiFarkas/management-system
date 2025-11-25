{
  username = "nixos";  # Fixed: actual user is 'nixos' not 'wsluser'
  networking = {
    mode = "static";
    interface = "eth0";
    ipv4 = {
      address = "192.168.1.60";
      prefixLength = 24;
      gateway = "192.168.1.1";
      nameservers = [ "8.8.8.8" "1.1.1.1" ];
    };
  };
}
