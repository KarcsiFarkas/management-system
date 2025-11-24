# BTRFS disk layout with subvolumes
# Provides snapshots, compression, and flexible storage
# Ideal for systems requiring snapshots and advanced features
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

            # Swap partition
            swap = {
              size = "8G";
              content = {
                type = "swap";
                resumeDevice = true;
              };
            };

            # BTRFS partition
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ]; # Force overwrite

                subvolumes = {
                  # Root subvolume
                  "@" = {
                    mountpoint = "/";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "space_cache=v2"
                    ];
                  };

                  # Home subvolume
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };

                  # Nix store subvolume (no CoW for better performance)
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "nodatacow"
                    ];
                  };

                  # Var subvolume (logs, databases)
                  "@var" = {
                    mountpoint = "/var";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };

                  # Docker/container storage (no CoW)
                  "@docker" = {
                    mountpoint = "/var/lib/docker";
                    mountOptions = [
                      "noatime"
                      "nodatacow"
                    ];
                  };

                  # Snapshots directory
                  "@snapshots" = {
                    mountpoint = "/.snapshots";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                };
              };
            };
          };
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

  # BTRFS specific configuration
  boot.supportedFilesystems = [ "btrfs" ];

  # Swap configuration
  swapDevices = [
    { device = "/dev/disk/by-partlabel/disk-main-swap"; }
  ];

  # BTRFS scrub service (data integrity check)
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  # Automatic snapshots with snapper (optional, commented out by default)
  # services.snapper = {
  #   configs = {
  #     home = {
  #       subvolume = "/home";
  #       extraConfig = ''
  #         TIMELINE_CREATE=yes
  #         TIMELINE_CLEANUP=yes
  #       '';
  #     };
  #   };
  # };
}
