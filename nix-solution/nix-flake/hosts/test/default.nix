{ config, pkgs, lib, ... }:
let
  vars = import ./variables.nix;  # { username, networking = { ... } }
  isStatic = (vars.networking.mode or "static") == "static";
  iface    = vars.networking.interface or "eth0";
in
{
  # NOTE: This is a golden template and should not be imported directly in flake.nix.
  # The install script will copy this folder to hosts/<name>/ and then adjust vars.

  imports = [
    ./hardware-configuration.nix
  ];

  # The installer sets this to the new host folder name.
  networking.hostName = "test";

  users.users.${vars.username} = {
    isNormalUser = true;
    extraGroups  = [ "wheel" ];
    createHome   = true;
    home         = "/home/${vars.username}";
  };

  # Keep DHCP off globally; drive via interface-level toggle below.
  networking.useDHCP = lib.mkDefault false;

  # DHCP on interface only if mode == "dhcp"
  networking.interfaces.${iface}.useDHCP = !isStatic;

  # Static IPv4 path (defaults come from variables.nix)
  networking = lib.mkIf isStatic {
    interfaces.${iface}.ipv4.addresses = [
      { address = vars.networking.ipv4.address; prefixLength = vars.networking.ipv4.prefixLength; }
    ];
    defaultGateway = vars.networking.ipv4.gateway;
    nameservers    = vars.networking.ipv4.nameservers or [ "1.1.1.1" "8.8.8.8" ];
  };

  # Add any other host-agnostic bits here; host-specific deltas belong in variables.nix.
}
