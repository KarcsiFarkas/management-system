locals {
  node          = try(var.proxmox.node, "pve")
  pool          = try(var.proxmox.pool, null)
  storage       = try(var.proxmox.storage, "local-lvm")
  iso_storage   = try(var.proxmox.iso_storage, "local")
  bridge        = try(var.netifs[0].bridge, "vmbr0")
  vlan          = try(var.netifs[0].vlan, null)
  nic_model     = try(var.netifs[0].model, "virtio")
  scsihw        = try(var.proxmox.scsihw, "virtio-scsi-pci")
  boot_method   = var.boot_method
  ubuntu_iso    = var.image_urls.ubuntu_iso_url
  ubuntu_image  = try(var.image_urls.ubuntu_image_url, null)
  nixos_iso     = var.image_urls.nixos_iso_url
  os_type       = var.install.os
}

resource "proxmox_vm_qemu" "this" {
  name        = var.name
  target_node = local.node
  pool        = local.pool
  agent       = 1
  cores       = var.cpus
  memory      = var.memory_mb
  scsihw      = local.scsihw
  onboot      = true

  dynamic "disk" {
    for_each = var.disks
    content {
      type    = disk.value.type
      storage = disk.value.storage
      size    = format("%dG", disk.value.size_gb)
      backup  = 0
    }
  }

  network {
    bridge = local.bridge
    model  = local.nic_model
    tag    = local.vlan
  }

  # Boot method selection
  # ISO boot with autoinstall (Ubuntu/NixOS)
  cdrom         = local.boot_method == "iso" ? "${local.iso_storage}:iso/${local.os_type == "ubuntu" ? basename(local.ubuntu_iso) : basename(local.nixos_iso)}" : null
  boot          = "order=scsi0;ide2;net0"
  bootdisk      = "scsi0"

  # Optional clone from cloud image/template (if you maintain one)
  clone         = local.boot_method == "image" && local.ubuntu_image != null ? basename(local.ubuntu_image) : null

  lifecycle {
    ignore_changes = [
      # allow cloud-init/user-data rotation outside of TF
      # additional mutable attributes can be added here
    ]
  }
}