{ config, lib, pkgs, ... }:

let
  vars  = import ./variables.nix;
  user  = vars.username or "nixuser";
  net   = vars.networking or { };
  mode  = net.mode or "static";
  iface = net.interface or "eth0";
  ipv4  = net.ipv4 or {
    address      = "192.168.1.50";
    prefixLength = 24;
    gateway      = "192.168.1.1";
    nameservers  = [ "1.1.1.1" "8.8.8.8" ];
  };

  isStatic = (mode == "static");
  isDhcp   = (mode == "dhcp");
in
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = lib.mkDefault "templated-host";

  users.users.${user} = {
    isNormalUser = true;
    extraGroups  = [ "wheel" "networkmanager" ];
    shell        = pkgs.bashInteractive;
  };

  # Stay explicit: no global DHCP; flip per iface
  networking.networkmanager.enable = false;
  networking.useDHCP = false;

  # ---- Consolidate dynamic interface into ONE assignment ----
  networking.interfaces.${iface} = lib.mkMerge [
    { useDHCP = isDhcp; }
    (lib.mkIf isStatic {
      ipv4.addresses = [
        { address = ipv4.address; prefixLength = ipv4.prefixLength; }
      ];
    })
  ];

  # Static-only globals
  networking.defaultGateway = lib.mkIf isStatic ipv4.gateway;
  networking.nameservers    = lib.mkIf isStatic ipv4.nameservers;

  time.timeZone      = lib.mkDefault "UTC";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

#  # Service toggles (off by default)
#  services.traefik.enable     = lib.mkDefault false;
#  services.jellyfin.enable    = lib.mkDefault false;
#  services.vaultwarden.enable = lib.mkDefault false;
#  services.authelia.enable    = lib.mkDefault false;

  system.stateVersion = lib.mkDefault "24.11";
}
