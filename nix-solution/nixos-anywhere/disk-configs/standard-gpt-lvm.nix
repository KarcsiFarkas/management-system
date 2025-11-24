# GPT disk layout with LVM
# Provides flexibility for resizing partitions and snapshots
# Ideal for production servers
{ lib, ... }:

{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = lib.mkDefault "/dev/sda";

        content = {
          type = "gpt";

          partitions = {
            # EFI System Partition
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

            # Boot partition (separate from ESP for flexibility)
            boot = {
              size = "1G";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/boot/grub";
                mountOptions = [ "defaults" ];
              };
            };

            # LVM Physical Volume
            lvm = {
              size = "100%";
              content = {
                type = "lvm_pv";
                vg = "system";
              };
            };
          };
        };
      };
    };

    # LVM Volume Group
    lvm_vg = {
      system = {
        type = "lvm_vg";

        lvs = {
          # Root logical volume
          root = {
            size = "50G";
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

          # Home logical volume
          home = {
            size = "50G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/home";
              mountOptions = [
                "defaults"
                "noatime"
              ];
            };
          };

          # Var logical volume (logs, databases)
          var = {
            size = "30G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/var";
              mountOptions = [
                "defaults"
                "noatime"
              ];
            };
          };

          # Swap logical volume
          swap = {
            size = "8G";
            content = {
              type = "swap";
              resumeDevice = true;
            };
          };

          # Docker/container storage
          docker = {
            size = "50G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/var/lib/docker";
              mountOptions = [
                "defaults"
                "noatime"
              ];
            };
          };

          # Remaining space for future expansion
          # Comment this out to leave free space in VG
          # data = {
          #   size = "100%FREE";
          #   content = {
          #     type = "filesystem";
          #     format = "ext4";
          #     mountpoint = "/data";
          #   };
          # };
        };
      };
    };
  };

  # Boot loader configuration
  boot.loader = {
    grub = {
      enable = true;
      efiSupport = true;
      device = "nodev";
    };
    efi.canTouchEfiVariables = true;
  };

  # LVM configuration
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  services.lvm.enable = true;

  # Swap configuration
  swapDevices = [
    { device = "/dev/system/swap"; }
  ];
}
