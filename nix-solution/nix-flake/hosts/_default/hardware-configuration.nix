# hosts/_default/hardware-configuration.nix
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Kernel/module defaults; harmless on most targets
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "virtio_pci" "virtio_scsi" "hv_vmbus" "hv_storvsc" "hv_netvsc" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # Root filesystem — adjust to your disk layout on real machines
  # On WSL this isn't used to boot, but NixOS still needs a declarative FS.
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # No swap by default; override per host if needed
  swapDevices = lib.mkDefault [ ];

  # ---------------- WSL / WSLg sanitization ----------------
  # WSL sometimes emits mounts with device = "" which violates the type
  # (must be null or non-empty string). Force them to null if they appear.
  fileSystems."/mnt/wslg/distro".device = lib.mkForce null;
  fileSystems."/tmp/.X11-unix".device   = lib.mkForce null;
}
