# Standard GPT disk layout with EFI boot
# Simple, reliable configuration for most use cases
# Single disk with EFI boot partition and root filesystem
{ lib, ... }:

{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        # Device will be determined at deployment time
        # Common values: /dev/sda, /dev/nvme0n1, /dev/vda
        device = lib.mkDefault "/dev/sda";

        content = {
          type = "gpt";

          partitions = {
            # EFI System Partition (ESP)
            ESP = {
              type = "EF00";
              size = "512M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "defaults"
                  "umask=0077"
                ];
              };
            };

            # Root partition (ext4)
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                mountOptions = [
                  "defaults"
                  "noatime"
                ];
              };
            };
          };
        };
      };
    };
  };

  # Boot loader configuration for GPT + EFI
  boot.loader = {
    grub = {
      enable = true;
      efiSupport = true;
      device = "nodev";
    };
    efi.canTouchEfiVariables = true;
  };

  # File system configuration
  fileSystems."/" = {
    fsType = "ext4";
    options = [ "noatime" "nodiratime" "discard" ];
  };

  fileSystems."/boot" = {
    fsType = "vfat";
    options = [ "umask=0077" ];
  };
}
