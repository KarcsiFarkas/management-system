# modules/common.nix
# This file contains base configuration shared across all hosts.
{ config, pkgs,... }:
{
  # Set your time zone.
  time.timeZone = "Europe/Budapest";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Basic packages available system-wide
  environment.systemPackages = with pkgs; [
    vim
    git
    wget
  ];

  # Enable the OpenSSH server.
  services.openssh.enable = true;
}