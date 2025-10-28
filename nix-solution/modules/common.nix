# modules/common.nix
# This file contains base configuration shared across all hosts.
{ config, pkgs, lib, userConfig ? {}, ... }:
let
  inherit (lib) mkIf mkDefault;
  cfgUser = userConfig.username or "nixuser";
  cfgNet = userConfig.network or {};
  netEnabled = (cfgNet.enable or false) || (cfgNet.address or "") != "";
  iface = cfgNet.interface or "ens18"; # Default interface; override via userConfig.network.interface
in
{
  # Set your time zone.
  time.timeZone = mkDefault "Europe/Budapest";

  # Select internationalisation properties.
  i18n.defaultLocale = mkDefault "en_US.UTF-8";

  # Basic packages available system-wide
  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    mosh
  ];

  # Enable the OpenSSH server.
  services.openssh.enable = true;

  # Enable Mosh and open its UDP port range for roaming SSH-like sessions
  programs.mosh.enable = true;
  networking.firewall.allowedUDPPortRanges = [ { from = 60000; to = 61000; } ];

  # --- Defaults driven by userConfig ---
  users.users."${cfgUser}" = {
    isNormalUser = true;
    description = "Default tenant user";
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.bashInteractive;
  };

  # Optionally set a static IPv4 configuration when provided
  networking = mkIf netEnabled {
    useDHCP = false;
    interfaces = {
      ${iface} = {
        ipv4.addresses = mkIf ((cfgNet.address or "") != "" && (cfgNet.prefixLength or null) != null) [
          {
            address = cfgNet.address;
            prefixLength = cfgNet.prefixLength;
          }
        ];
      };
    };
    defaultGateway = mkIf ((cfgNet.gateway or "") != "") cfgNet.gateway;
    nameservers = mkIf ((cfgNet.nameservers or []) != []) cfgNet.nameservers;
  };
}