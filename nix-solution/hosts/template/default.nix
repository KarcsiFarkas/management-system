{ config, pkgs, lib, ... }:
let
  vars = import ./variables.nix;
  isStatic = vars.networking.mode or "dhcp" == "static";
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  # Hostname must match the directory if you like that convention
  # (when you create a real host, set this to the host name)
  networking.hostName = "template";

  # Username per host
  users.users.${vars.username} = {
    isNormalUser = true;
    extraGroups  = [ "wheel" ];
    createHome   = true;
    home         = "/home/${vars.username}";
  };

  # Network mode toggle (static vs DHCP) driven by variables.nix.nix
  networking.useDHCP = lib.mkDefault false;

  # DHCP path
  networking.interfaces.${vars.networking.interface or "eth0"}.useDHCP =
    lib.mkDefault (!isStatic);

  # Static path
  networking = lib.mkIf isStatic {
    interfaces.${vars.networking.interface}.ipv4.addresses = [
      { address = vars.networking.ipv4.address; prefixLength = vars.networking.ipv4.prefixLength; }
    ];
    defaultGateway = vars.networking.ipv4.gateway;
    nameservers    = vars.networking.ipv4.nameservers;

    # Optional IPv6:
    # interfaces.${vars.networking.interface}.ipv6.addresses = [
    #   { address = vars.networking.ipv6.address; prefixLength = vars.networking.ipv6.prefixLength; }
    # ];
    # defaultGateway6 = vars.networking.ipv6.gateway;
    # nameservers = (vars.networking.ipv6.nameservers or []);
  };

  # WSL-specific toggles can live only in the real WSL host, but shown here for reference:
  # virtualisation.wsl.enable = true;
  # services.getty.autologinUser = lib.mkDefault vars.username;
}
