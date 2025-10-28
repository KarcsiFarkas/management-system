{
  # The installer updates this to the requested username after copying the folder.
  username = "test";

  networking = {
    # Default: static. The installer can change to "dhcp" if you pass such overrides later.
    mode = "static";
    interface = "eth0";
    ipv4 = {
      address = "192.168.1.50";
      prefixLength = 24;
      gateway = "192.168.1.1";
      nameservers = [ "1.1.1.1" "8.8.8.8" ];
    };
  };
}
