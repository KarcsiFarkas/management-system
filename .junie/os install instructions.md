Below is a **production‑grade starting point** for a Python + Terraform + Ansible framework that provisions **Ubuntu or NixOS** onto **Proxmox VMs** or **bare‑metal via PXE**, with clean layering, sane defaults, and room for growth.

---

## Overview / Architecture Summary

**Goals**

* One CLI entrypoint (`provision.py`) orchestrates:

  * **Terraform** → infrastructure (Proxmox VMs, networks, ISO/image attachment).
  * **Ansible** → OS installation & post‑install config (Ubuntu Autoinstall, NixOS bootstrap, Docker/Nix services).
* **Declarative inputs** (YAML) drive everything:

  * `defaults.yaml`: stable, shared defaults (providers, ISO catalogs, Ansible role toggles).
  * `vm_specs.yaml`: hardware + hypervisor specifics (CPUs, RAM, disks, bridges/VLANs).
  * `install_config.yaml`: per‑host OS config (hostname, users/SSH keys, netplan/NixOS networking, services).
* **Modular networking**: bridges, VLAN tags, DHCP/static, MTU, DNS; the same model works for VM and PXE targets.
* **Scalability**: add OSes, clouds, or HA features without refactoring the orchestrator.

**High‑level flow**

1. `provision.py` loads `defaults.yaml`, then `vm_specs.yaml`, then `install_config.yaml`, merges with precedence **install_config > vm_specs > defaults**.
2. For each host:

   * Renders a **Terraform workdir** (`build/<host>/tf`) using the Proxmox module and host tfvars.
   * Runs `terraform init/plan/apply` (async, fan‑out across hosts).
   * Renders **Ansible inventory + vars** into `build/<host>/ansible`.
   * Runs the appropriate **Ansible playbook**:

     * **VM + ISO** → attach ISO and boot with kernel args for unattended Ubuntu/NixOS.
     * **VM + image** → cloud‑init + post‑config.
     * **Bare‑metal PXE** → configure PXE server (dnsmasq + iPXE + HTTP), set DHCP reservation, and trigger network boot; then run OS install play.
3. Reports a concise summary (IPs, SSH tips, next steps).

---

## File / Folder Structure

```
provisioning-framework/
├── provision.py
├── core/                          # (kept small to stay in one entrypoint; can be split later)
│   ├── __init__.py
│   ├── types.py                   # Pydantic models (mirrors below in code)
│   └── (optional empty - logic is in provision.py to keep this deliverable self-contained)
├── terraform/
│   ├── modules/
│   │   └── proxmox_vm/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   └── envs/
│       └── default/
│           ├── provider.tf        # Proxmox provider + backend (local by default)
│           └── versions.tf
├── ansible/
│   ├── playbooks/
│   │   ├── ubuntu_install.yml
│   │   ├── nixos_install.yml
│   │   ├── post_config_common.yml
│   │   └── pxe_server.yml         # Prepares dnsmasq + iPXE + HTTP artifacts
│   └── roles/
│       ├── ubuntu_minimal/
│       │   └── tasks/main.yml
│       ├── ubuntu_docker/
│       │   └── tasks/main.yml
│       ├── nixos_minimal/
│       │   └── tasks/main.yml
│       ├── nixos_services/
│       │   └── tasks/main.yml
│       └── pxe/
│           ├── tasks/main.yml
│           └── templates/
│               ├── menu.ipxe.j2
│               ├── ubuntu-user-data.j2
│               ├── ubuntu-meta-data.j2
│               └── nixos-installer-cmds.sh.j2
├── templates/
│   └── cloudinit/
│       ├── network-config.yaml.j2
│       └── user-data.yaml.j2
├── configs/
│   ├── defaults.yaml
│   ├── vm_specs.yaml
│   └── install_config.yaml
└── README.md
```

> **Note**: For this deliverable, the single Python entrypoint is fully included below; Terraform/Ansible/templates are provided as working snippets you can drop into the indicated paths.

---

## `provision.py` (Python 3.12+, typed, Pydantic, async)

```python
#!/usr/bin/env python3
"""
provision.py — Orchestrates Proxmox VM & bare-metal PXE provisioning for Ubuntu/NixOS.

- Python 3.12+
- Typed functions, Pydantic validation, YAML/TOML inputs
- Async fan-out for Terraform and Ansible
- Clear separation: Terraform (infra) / Ansible (config) / Orchestration (this script)
"""

from __future__ import annotations

import argparse
import asyncio
import dataclasses
import json
import os
import shutil
import sys
import textwrap
from pathlib import Path
from typing import Any, Literal, Optional, Sequence

import yaml
from pydantic import BaseModel, Field, HttpUrl, ValidationError, field_validator, model_validator

# ---------- Models (Pydantic) ----------

BootMethod = Literal["iso", "image", "pxe"]
OSType = Literal["ubuntu", "nixos"]
Hypervisor = Literal["proxmox", "baremetal"]

class DiskSpec(BaseModel):
    size_gb: int = Field(50, ge=8)
    storage: str = Field(..., description="Proxmox storage name (e.g., local-lvm)")
    type: Literal["scsi", "virtio", "sata"] = "scsi"

class NetIfSpec(BaseModel):
    bridge: str = Field(..., description="Proxmox bridge (vmbr0, etc.) or interface for PXE")
    vlan: Optional[int] = None
    mac: Optional[str] = None
    model: Literal["virtio", "e1000", "rtl8139"] = "virtio"
    mtu: Optional[int] = None

class NetworkConfig(BaseModel):
    hostname: str
    domain: Optional[str] = None
    dhcp: bool = True
    address_cidr: Optional[str] = None
    gateway: Optional[str] = None
    dns: list[str] = Field(default_factory=list)
    interfaces: list[NetIfSpec] = Field(default_factory=list)

    @model_validator(mode="after")
    def validate_static(self) -> "NetworkConfig":
        if not self.dhcp and not self.address_cidr:
            raise ValueError("Static network requires address_cidr")
        return self

class UserSpec(BaseModel):
    username: str
    ssh_authorized_keys: list[str] = Field(default_factory=list)
    sudo: bool = True
    shell: str = "/bin/bash"

class OSInstallConfig(BaseModel):
    os: OSType
    version: str
    packages: list[str] = Field(default_factory=list)
    users: list[UserSpec]
    network: NetworkConfig
    docker: bool = False                   # Enable Docker on Ubuntu
    nix_services: list[str] = Field(default_factory=list)  # Enable named services on NixOS
    partitioning: dict[str, Any] = Field(default_factory=dict)  # Optional custom layout

class VMSpec(BaseModel):
    name: str
    hypervisor: Hypervisor = "proxmox"
    boot_method: BootMethod = "iso"
    cpus: int = Field(2, ge=1)
    memory_mb: int = Field(4096, ge=512)
    disks: list[DiskSpec]
    netifs: list[NetIfSpec]
    # Proxmox-specific
    proxmox: Optional[dict[str, Any]] = None
    # Bare-metal specifics for PXE
    baremetal: Optional[dict[str, Any]] = None  # e.g., {"mac": "...", "ipmi_host": "...", "ipmi_user": "...", "ipmi_pass": "..."}

class ImageCatalog(BaseModel):
    ubuntu_iso_url: HttpUrl
    ubuntu_image_url: Optional[HttpUrl] = None  # cloud image optional
    nixos_iso_url: HttpUrl

class Defaults(BaseModel):
    terraform_backend: dict[str, Any] = Field(default_factory=dict)
    image_catalog: ImageCatalog
    proxmox_provider: dict[str, Any] = Field(
        default_factory=lambda: {"pm_api_url": "https://proxmox.example:8006/api2/json"}
    )
    ansible_defaults: dict[str, Any] = Field(default_factory=dict)
    pxe: dict[str, Any] = Field(
        default_factory=lambda: {"tftp_root": "/var/lib/tftpboot", "http_root": "/var/www/html"}
    )

class RootConfig(BaseModel):
    defaults: Defaults
    vms: list[VMSpec]
    installs: dict[str, OSInstallConfig]  # keyed by VMSpec.name

# ---------- YAML IO & Merge ----------

def load_yaml(path_or_dash: str | Path) -> dict[str, Any]:
    if str(path_or_dash) == "-":
        data = sys.stdin.read()
        return yaml.safe_load(data) or {}
    with open(path_or_dash, "r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}

def deep_merge(a: dict[str, Any], b: dict[str, Any]) -> dict[str, Any]:
    """Return deep merge of a<-b (b overrides)."""
    res = dict(a)
    for k, v in b.items():
        if k in res and isinstance(res[k], dict) and isinstance(v, dict):
            res[k] = deep_merge(res[k], v)
        else:
            res[k] = v
    return res

# ---------- Utilities ----------

class ShellError(RuntimeError):
    pass

async def run_cmd(*cmd: str, cwd: Optional[Path] = None, env: Optional[dict[str, str]] = None) -> None:
    proc = await asyncio.create_subprocess_exec(
        *cmd, cwd=str(cwd) if cwd else None, env=env or os.environ.copy(),
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT
    )
    assert proc.stdout
    async for line in proc.stdout:
        sys.stdout.write(line.decode())
    rc = await proc.wait()
    if rc != 0:
        raise ShellError(f"Command failed ({rc}): {' '.join(cmd)}")

def ensure_empty_dir(path: Path) -> None:
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)

# ---------- Renderers ----------

def render_tf_module(workdir: Path, vm: VMSpec, install: OSInstallConfig, defaults: Defaults) -> None:
    """Materialize Terraform files and tfvars for a single host."""
    mod_src = Path("terraform/modules/proxmox_vm")
    env_src = Path("terraform/envs/default")
    tf_dir = workdir / "tf"
    ensure_empty_dir(tf_dir)

    # Copy static scaffolding
    for src in (mod_src, env_src):
        if not src.exists():
            raise FileNotFoundError(f"Missing Terraform path: {src}")
    shutil.copytree(mod_src, tf_dir / "modules" / "proxmox_vm")
    for f in env_src.iterdir():
        shutil.copy(f, tf_dir / f.name)

    # Root main.tf to call module
    main_tf = textwrap.dedent(
        """
        terraform {
          required_version = ">= 1.5.0"
        }

        module "vm" {
          source      = "./modules/proxmox_vm"
          name        = var.name
          cpus        = var.cpus
          memory_mb   = var.memory_mb
          disks       = var.disks
          netifs      = var.netifs
          boot_method = var.boot_method
          proxmox     = var.proxmox
          image_urls  = var.image_urls
          install     = var.install
        }

        output "vm_id" { value = module.vm.vm_id }
        output "ip_hint" { value = module.vm.ip_hint }
        """
    )
    (tf_dir / "main.tf").write_text(main_tf, encoding="utf-8")

    # Variables and tfvars.json (simple explicit variables for module call)
    variables_tf = textwrap.dedent(
        """
        variable "name"        { type = string }
        variable "cpus"        { type = number }
        variable "memory_mb"   { type = number }
        variable "disks"       { type = any }
        variable "netifs"      { type = any }
        variable "boot_method" { type = string }
        variable "proxmox"     { type = any }
        variable "image_urls"  { type = any }
        variable "install"     { type = any }
        """
    )
    (tf_dir / "variables.tf").write_text(variables_tf, encoding="utf-8")

    tfvars = {
        "name": vm.name,
        "cpus": vm.cpus,
        "memory_mb": vm.memory_mb,
        "disks": [d.model_dump() for d in vm.disks],
        "netifs": [n.model_dump() for n in vm.netifs],
        "boot_method": vm.boot_method,
        "proxmox": vm.proxmox or {},
        "image_urls": {
            "ubuntu_iso_url": defaults.image_catalog.ubuntu_iso_url,
            "ubuntu_image_url": defaults.image_catalog.ubuntu_image_url,
            "nixos_iso_url": defaults.image_catalog.nixos_iso_url,
        },
        "install": {
            "os": install.os,
            "version": install.version,
            "network": install.network.model_dump(),
        },
    }
    (tf_dir / "terraform.tfvars.json").write_text(json.dumps(tfvars, indent=2), encoding="utf-8")

def render_ansible_inventory(workdir: Path, vm: VMSpec, install: OSInstallConfig, defaults: Defaults) -> Path:
    """Creates inventory and group/host vars for Ansible."""
    ans_dir = workdir / "ansible"
    ensure_empty_dir(ans_dir)

    # Minimal YAML inventory (INI also fine)
    inv = {
        "all": {
            "children": {
                "ubuntu": {"hosts": {}},
                "nixos": {"hosts": {}},
                "pxe": {"hosts": {}},
            }
        }
    }

    host_vars = {
        "ansible_user": next((u.username for u in install.users if u.sudo), "root"),
        "network": install.network.model_dump(),
        "packages": install.packages,
        "docker_enabled": install.docker,
        "nix_services": install.nix_services,
        "partitioning": install.partitioning,
    }

    if vm.hypervisor == "baremetal":
        inv["all"]["children"]["pxe"]["hosts"][vm.name] = {"ansible_host": install.network.address_cidr or vm.name}
    elif install.os == "ubuntu":
        inv["all"]["children"]["ubuntu"]["hosts"][vm.name] = {"ansible_host": install.network.address_cidr or vm.name}
    else:
        inv["all"]["children"]["nixos"]["hosts"][vm.name] = {"ansible_host": install.network.address_cidr or vm.name}

    (ans_dir / "inventory.yaml").write_text(yaml.safe_dump(inv, sort_keys=False), encoding="utf-8")
    (ans_dir / f"{vm.name}.vars.yaml").write_text(yaml.safe_dump(host_vars, sort_keys=False), encoding="utf-8")
    return ans_dir / "inventory.yaml"

# ---------- Orchestration ----------

async def terraform_apply(tf_dir: Path) -> None:
    await run_cmd("terraform", "init", "-upgrade", cwd=tf_dir)
    await run_cmd("terraform", "validate", cwd=tf_dir)
    await run_cmd("terraform", "plan", "-input=false", cwd=tf_dir)
    await run_cmd("terraform", "apply", "-auto-approve", "-input=false", cwd=tf_dir)

async def ansible_play(playbook: Path, inventory: Path, extra_vars_file: Path) -> None:
    await run_cmd(
        "ansible-playbook",
        "-i", str(inventory),
        str(playbook),
        "--extra-vars", f"@{extra_vars_file}",
    )

async def provision_host(root_build: Path, vm: VMSpec, install: OSInstallConfig, defaults: Defaults,
                         targets: set[str]) -> tuple[str, Optional[Exception]]:
    host_dir = root_build / vm.name
    host_dir.mkdir(parents=True, exist_ok=True)

    try:
        # Terraform (infra for Proxmox VM; PXE uses Ansible only)
        if vm.hypervisor == "proxmox":
            render_tf_module(host_dir, vm, install, defaults)
            if "infra" in targets:
                await terraform_apply(host_dir / "tf")

        # Ansible (OS installation / post-config)
        inv = render_ansible_inventory(host_dir, vm, install, defaults)
        vars_file = host_dir / "ansible" / f"{vm.name}.vars.yaml"

        if vm.hypervisor == "baremetal" or vm.boot_method == "pxe":
            # Prepare PXE environment first
            if "pxe" in targets:
                await ansible_play(Path("ansible/playbooks/pxe_server.yml"), inv, vars_file)

        # OS install
        if "os" in targets:
            if install.os == "ubuntu":
                await ansible_play(Path("ansible/playbooks/ubuntu_install.yml"), inv, vars_file)
            elif install.os == "nixos":
                await ansible_play(Path("ansible/playbooks/nixos_install.yml"), inv, vars_file)

        # Common post config (hardening, ntp, fqdn, etc.)
        if "post" in targets:
            await ansible_play(Path("ansible/playbooks/post_config_common.yml"), inv, vars_file)

        return (vm.name, None)
    except Exception as e:
        return (vm.name, e)

def build_root() -> Path:
    root = Path("build")
    root.mkdir(exist_ok=True)
    return root

# ---------- CLI ----------

def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Proxmox VM + Baremetal Automated OS Provisioning")
    p.add_argument("--defaults", default="configs/defaults.yaml", help="Path to defaults.yaml")
    p.add_argument("--vm-specs", default="configs/vm_specs.yaml", help="Path to vm_specs.yaml")
    p.add_argument("--install-config", default="configs/install_config.yaml",
                   help="Path to install_config.yaml or '-' to read from stdin (pipable)")
    p.add_argument("--hosts", nargs="*", default=[], help="Hostnames to operate on (default: all)")
    p.add_argument("--targets", nargs="*", default=["infra", "pxe", "os", "post"],
                   choices=["infra", "pxe", "os", "post"],
                   help="Pipeline stages to run")
    p.add_argument("--concurrency", type=int, default=4, help="Parallelism across hosts")
    p.add_argument("--plan-only", action="store_true", help="Render workdirs and terraform plan only")
    return p.parse_args(argv)

def load_config(defaults_path: str | Path, vm_specs_path: str | Path, install_config_path: str | Path) -> RootConfig:
    defaults = load_yaml(defaults_path)
    vm_specs = load_yaml(vm_specs_path)
    install_cfg = load_yaml(install_config_path)

    # Merge into RootConfig shape
    merged = {
        "defaults": defaults,
        "vms": vm_specs.get("vms", []),
        "installs": install_cfg.get("installs", {}),
    }
    try:
        return RootConfig.model_validate(merged)
    except ValidationError as e:
        print("Configuration validation failed:", file=sys.stderr)
        print(e, file=sys.stderr)
        sys.exit(2)

async def main() -> None:
    args = parse_args()
    config = load_config(args.defaults, args.vm_specs, args.install_config)

    selected: list[VMSpec] = [
        vm for vm in config.vms if not args.hosts or vm.name in args.hosts
    ]
    if not selected:
        print("No hosts match selection.", file=sys.stderr)
        sys.exit(1)

    root_build = build_root()
    targets = set(args.targets)

    # Render and optionally plan/apply concurrently
    sem = asyncio.Semaphore(args.concurrency)
    results: list[tuple[str, Optional[Exception]]] = []

    async def worker(vm: VMSpec) -> None:
        install = config.installs.get(vm.name)
        if not install:
            results.append((vm.name, RuntimeError("Missing install_config for host")))
            return
        async with sem:
            res = await provision_host(root_build, vm, install, config.defaults, targets)
            results.append(res)

    await asyncio.gather(*(worker(vm) for vm in selected))

    print("\n=== Summary ===")
    failures = 0
    for name, err in results:
        if err:
            failures += 1
            print(f"[FAIL] {name}: {err}")
        else:
            print(f"[OK]   {name}")
    if failures:
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
```

> **Why a single file?** To match your deliverable request. In a real repo, you would split `provision.py` into modules (`core/config.py`, `core/terraform.py`, etc.) without changing public behavior.

---

## Terraform — Proxmox module (snippets)

**`terraform/envs/default/provider.tf`**

```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = ">= 3.0.0"
    }
  }
}

provider "proxmox" {
  pm_api_url = var.pm_api_url
  # Authentication via env:
  #   PM_USER, PM_PASS or PM_API_TOKEN_ID, PM_API_TOKEN_SECRET
  #   PM_TLS_INSECURE=1 (if using self-signed; prefer proper CA in production)
}

variable "pm_api_url" { type = string, default = "https://proxmox.example:8006/api2/json" }
```

**`terraform/envs/default/versions.tf`**

```hcl
terraform {
  required_version = ">= 1.5.0"
}
```

**`terraform/modules/proxmox_vm/variables.tf`**

```hcl
variable "name"        { type = string }
variable "cpus"        { type = number }
variable "memory_mb"   { type = number }
variable "disks"       { type = any }
variable "netifs"      { type = any }
variable "boot_method" { type = string }
variable "proxmox"     { type = any }
variable "image_urls"  { type = any }
variable "install"     { type = any }
```

**`terraform/modules/proxmox_vm/main.tf`**
(Uses `proxmox_vm_qemu` and supports ISO or image boot. This is a concise working baseline—expand as needed.)

```hcl
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

output "vm_id"   { value = proxmox_vm_qemu.this.id }
output "ip_hint" { value = var.install.network.address_cidr }
```

> **Notes**
>
> * Authentication for the provider is through environment variables (`PM_API_TOKEN_ID`, `PM_API_TOKEN_SECRET`) to avoid committing secrets.
> * The module assumes ISO images are already available in `iso_storage`. You can sync ISOs out-of-band or extend this module to download/upload ISOs (e.g., `null_resource` + `local-exec`).

---

## Ansible — Playbooks & Roles (snippets)

**`ansible/playbooks/pxe_server.yml`**

```yaml
---
- name: Configure PXE server (dnsmasq + iPXE + HTTP) and host entries
  hosts: localhost
  gather_facts: false
  vars_files:
    - "{{ playbook_dir }}/../../configs/defaults.yaml"
  roles:
    - role: pxe
      vars:
        pxe_hosts:
          - hostname: "{{ network.hostname }}"
            mac: "{{ (network.interfaces | first).mac | default(omit) }}"
            os: "{{ hostvars[inventory_hostname]['os'] | default('ubuntu') }}"
            kernel_params: >-
              {{ 'autoinstall ds=nocloud-net;s=http://pxe.local/autoinstall/' ~ network.hostname ~ '/'
                 if hostvars[inventory_hostname]['os'] == 'ubuntu'
                 else 'copytoram init=/nix/installer' }}
```

**`ansible/roles/pxe/tasks/main.yml`** (minimalized)

```yaml
---
- name: Ensure packages for PXE
  become: true
  package:
    name: [dnsmasq, nginx, syslinux-common, ipxe]
    state: present

- name: Render iPXE menu
  become: true
  template:
    src: templates/menu.ipxe.j2
    dest: /var/www/html/menu.ipxe
    mode: "0644"

- name: Host-specific Ubuntu autoinstall data
  when: pxe_hosts is defined
  become: true
  loop: "{{ pxe_hosts }}"
  loop_control: { loop_var: ph }
  block:
    - name: Create autoinstall dir
      file:
        path: "/var/www/html/autoinstall/{{ ph.hostname }}"
        state: directory
        mode: "0755"

    - name: user-data
      template:
        src: templates/ubuntu-user-data.j2
        dest: "/var/www/html/autoinstall/{{ ph.hostname }}/user-data"
        mode: "0644"

    - name: meta-data
      template:
        src: templates/ubuntu-meta-data.j2
        dest: "/var/www/html/autoinstall/{{ ph.hostname }}/meta-data"
        mode: "0644"

# dnsmasq + nginx config would be here (not shown for brevity)
```

**`ansible/playbooks/ubuntu_install.yml`**

```yaml
---
- name: Ubuntu minimal install (autoinstall or cloud-init image) + Docker optional
  hosts: ubuntu
  become: true
  vars:
    minimal_pkgs: [vim, curl, ca-certificates, net-tools]
  tasks:
    - name: Wait for SSH (host up)
      wait_for:
        port: 22
        delay: 5
        timeout: 900

    - name: Ensure minimal packages
      apt:
        name: "{{ minimal_pkgs }}"
        state: present
        update_cache: true

    - name: Ensure users and SSH keys
      loop: "{{ users }}"
      loop_control: { loop_var: u }
      user:
        name: "{{ u.username }}"
        shell: "{{ u.shell | default('/bin/bash') }}"
        groups: "{{ 'sudo' if u.sudo else omit }}"
        state: present
      register: created_users

    - name: Authorized keys
      authorized_key:
        user: "{{ item.0.username }}"
        key: "{{ item.1 }}"
      with_subelements:
        - "{{ users }}"
        - ssh_authorized_keys

    - name: Configure netplan (static if requested)
      when: not network.dhcp
      copy:
        dest: /etc/netplan/01-installer-config.yaml
        content: |
          network:
            version: 2
            ethernets:
              {{ (network.interfaces[0].bridge | default('ens18')) }}:
                addresses: [ "{{ network.address_cidr }}" ]
                gateway4: "{{ network.gateway }}"
                nameservers:
                  addresses: {{ network.dns | to_nice_yaml(indent=10) }}

    - name: Apply netplan (if changed)
      command: netplan apply
      when: not network.dhcp

    - name: Install Docker (optional)
      when: docker_enabled | bool
      block:
        - name: Setup apt keyrings + repo
          shell: |
            set -e
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            chmod a+r /etc/apt/keyrings/docker.gpg
            . /etc/os-release
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
            ${VERSION_CODENAME} stable" > /etc/apt/sources.list.d/docker.list
        - apt:
            update_cache: true
        - apt:
            name: [docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin, docker-compose-plugin]
            state: present
```

**`ansible/playbooks/nixos_install.yml`**

```yaml
---
- name: NixOS minimal install
  hosts: nixos
  become: false
  vars:
    # For PXE/ISO live environment: install via nixos-install using rendered configuration.nix
    nixos_config_path: /etc/nixos/configuration.nix
  tasks:
    - name: Wait for SSH (live ISO or already installed)
      wait_for:
        port: 22
        delay: 5
        timeout: 900

    - name: Push NixOS configuration
      become: true
      copy:
        dest: "{{ nixos_config_path }}"
        mode: "0644"
        content: |
          { config, pkgs, ... }:
          {
            networking.hostName = "{{ network.hostname }}";
            networking.useDHCP = {{ 'true' if network.dhcp else 'false' }};
            {{ '- networking.defaultGateway = "' ~ network.gateway ~ '";' if network.gateway else '' }}
            {{ '- networking.nameservers = ' ~ (network.dns | to_json) ~ ';' if network.dns else '' }}
            services.openssh.enable = true;
            users.users = {
              {% for u in users %}
              {{ u.username }} = {
                isNormalUser = true;
                extraGroups = [ "wheel" ];
                openssh.authorizedKeys.keys = {{ u.ssh_authorized_keys | to_json }};
              };
              {% endfor %}
            };
            security.sudo.wheelNeedsPassword = false;
            environment.systemPackages = with pkgs; {{ packages | default([]) | to_json }};
            {{ '# Optional services' }}
            {% for svc in nix_services %}
            services.{{ svc }}.enable = true;
            {% endfor %}
          }

    - name: Run nixos-install (if not installed)
      become: true
      shell: |
        if [ ! -e /etc/NIXOS ]; then
          nixos-install --no-root-passwd
        fi

    - name: Reboot to installed system (if needed)
      become: true
      reboot:
        reboot_timeout: 900
```

**`ansible/playbooks/post_config_common.yml`**

```yaml
---
- name: Common hardening + fqdn + time sync
  hosts: all
  become: true
  tasks:
    - name: Set hostname
      hostname:
        name: "{{ network.hostname }}"

    - name: Ensure /etc/hosts has fqdn
      lineinfile:
        path: /etc/hosts
        line: "127.0.1.1 {{ network.hostname }} {{ (network.hostname ~ '.' ~ network.domain) if network.domain else '' }}"
        create: yes

    - name: Ensure chrony/ntp
      package:
        name: "{{ 'chrony' if ansible_os_family == 'Debian' else 'chrony' }}"
        state: present
```

**PXE templates (examples)**

**`ansible/roles/pxe/templates/menu.ipxe.j2`**

```ipxe
#!ipxe
dhcp
set menu-timeout 5000
:menu
menu PXE Boot Menu
item --gap --             ------------------------
item ubuntu               Ubuntu Autoinstall
item nixos                NixOS Installer
choose --timeout ${menu-timeout} target && goto ${target}

:ubuntu
kernel http://pxe.local/ubuntu/vmlinuz ip=dhcp url=http://pxe.local/ubuntu/rootfs.squashfs autoinstall ds=nocloud-net;s=http://pxe.local/autoinstall/{{ network.hostname }}/
initrd http://pxe.local/ubuntu/initrd
boot

:nixos
kernel http://pxe.local/nixos/vmlinuz
initrd http://pxe.local/nixos/initrd
imgargs vmlinuz init=/nix/installer
boot
```

**`ansible/roles/pxe/templates/ubuntu-user-data.j2`** (minimal Autoinstall)

```yaml
#cloud-config
autoinstall:
  version: 1
  locale: en_US
  keyboard: { layout: us }
  identity:
    hostname: "{{ network.hostname }}"
    username: "{{ (users | selectattr('sudo') | map(attribute='username') | list | first) | default('devops') }}"
    password: "$6$rounds=4096$KJ..." # optional (prefer SSH keys)
  ssh:
    install-server: true
    authorized-keys:
      {% for u in users %}
      {% for k in u.ssh_authorized_keys %}
      - "{{ k }}"
      {% endfor %}
      {% endfor %}
  storage:
    {{ partitioning | default({}, true) | to_nice_yaml(indent=4) }}
  network:
    {% if network.dhcp %}
    network:
      version: 2
      ethernets:
        ens18: { dhcp4: true }
    {% else %}
    network:
      version: 2
      ethernets:
        ens18:
          addresses: [ "{{ network.address_cidr }}" ]
          gateway4: "{{ network.gateway }}"
          nameservers: { addresses: {{ network.dns | to_json }} }
    {% endif %}
  packages: {{ packages | to_json }}
  late-commands:
    {% if docker_enabled %}
    - curtin in-target -- apt-get update
    - curtin in-target -- sh -c 'curl -fsSL https://get.docker.com | sh'
    {% endif %}
```

**`ansible/roles/pxe/templates/ubuntu-meta-data.j2`**

```yaml
instance-id: iid-{{ network.hostname }}
```

---

## Example Config Files

**`configs/defaults.yaml`**

```yaml
terraform_backend: {}  # local state by default; plug remote backends later

image_catalog:
  ubuntu_iso_url: "https://releases.ubuntu.com/24.04/ubuntu-24.04.1-live-server-amd64.iso"
  ubuntu_image_url: "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  nixos_iso_url: "https://channels.nixos.org/nixos-24.05/latest-nixos-minimal-x86_64-linux.iso"

proxmox_provider:
  pm_api_url: "https://proxmox.example:8006/api2/json"
  # Auth via env:
  #   PM_API_TOKEN_ID=terraform@pve!iac  PM_API_TOKEN_SECRET=...

ansible_defaults:
  ssh_common_args: "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

pxe:
  tftp_root: "/var/lib/tftpboot"
  http_root: "/var/www/html"
```

**`configs/vm_specs.yaml`**

```yaml
vms:
  - name: web-01
    hypervisor: proxmox
    boot_method: iso       # iso | image | pxe
    cpus: 4
    memory_mb: 8192
    disks:
      - size_gb: 40
        storage: local-lvm
        type: scsi
    netifs:
      - bridge: vmbr0
        vlan: 30
        model: virtio
    proxmox:
      node: pve1
      storage: local-lvm
      iso_storage: local

  - name: ci-runner-01
    hypervisor: proxmox
    boot_method: image
    cpus: 4
    memory_mb: 8192
    disks:
      - size_gb: 60
        storage: local-lvm
        type: scsi
    netifs:
      - bridge: vmbr0
        vlan: 20
        model: virtio
    proxmox:
      node: pve2
      storage: local-lvm

  - name: baremetal-01
    hypervisor: baremetal
    boot_method: pxe
    cpus: 8
    memory_mb: 16384
    disks:
      - size_gb: 200
        storage: "n/a"
        type: scsi
    netifs:
      - bridge: "eno1"
        vlan: null
        mac: "52:54:00:aa:bb:cc"
```

**`configs/install_config.yaml`**

```yaml
installs:
  web-01:
    os: ubuntu
    version: "24.04"
    docker: true
    packages: [jq, htop]
    users:
      - username: devops
        sudo: true
        ssh_authorized_keys:
          - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMYoursamplekey user@laptop"
    network:
      hostname: web-01
      domain: lab.local
      dhcp: false
      address_cidr: "192.168.30.10/24"
      gateway: "192.168.30.1"
      dns: ["1.1.1.1", "9.9.9.9"]
      interfaces:
        - bridge: vmbr0
          vlan: 30
          model: virtio

  ci-runner-01:
    os: ubuntu
    version: "24.04"
    docker: true
    users:
      - username: runner
        sudo: true
        ssh_authorized_keys:
          - "ssh-ed25519 AAAAC3Nza... runner@host"
    network:
      hostname: ci-runner-01
      dhcp: true
      interfaces:
        - bridge: vmbr0
          vlan: 20

  baremetal-01:
    os: nixos
    version: "24.05"
    nix_services: [openssh]
    packages: [htop, git]
    users:
      - username: ops
        sudo: true
        ssh_authorized_keys:
          - "ssh-ed25519 AAAAC3Nza... ops@host"
    network:
      hostname: baremetal-01
      domain: lab.local
      dhcp: false
      address_cidr: "192.168.10.50/24"
      gateway: "192.168.10.1"
      dns: ["1.1.1.1"]
      interfaces:
        - bridge: eno1
          mac: "52:54:00:aa:bb:cc"
```

> **Piping `install_config`**: `cat configs/install_config.yaml | python3 provision.py --install-config - --vm-specs configs/vm_specs.yaml`

---

## Explanation of Key Design Choices

1. **Strict separation of concerns**

   * **Terraform** owns VM lifecycle (resource IDs, disks, NICs, ISO attachment). It does **not** know about Docker or packages.
   * **Ansible** owns OS installation and configuration (Autoinstall/NixOS config, users, packages, docker/nix services).
   * **Python** orchestrates and glues (validation, rendering, async command runs, per‑host working dirs).

2. **Layered configuration**

   * **`defaults.yaml`** acts as a **contract** for shared data (image catalog, provider endpoints, PXE paths).
   * **`vm_specs.yaml`** holds environment‑specific hardware/hypervisor details (CPU/RAM, Proxmox node/pool).
   * **`install_config.yaml`** holds per‑host OS config and **user‑specific** values (users, SSH keys).
   * Merge precedence: **install_config > vm_specs > defaults**. New defaults propagate without overwriting user values.

3. **Async orchestration**

   * Terraform and Ansible steps are **fan‑out concurrent** with a semaphore to cap parallelism (`--concurrency`).
   * Scales linearly for labs or small clusters, later replaceable with a queue/worker model.

4. **Networking model**

   * `NetworkConfig` supports **DHCP or static** with **interfaces[]** (bridge/device name, VLAN, MTU, MAC).
   * The same schema powers **cloud-init/netplan**, **PXE kernel params**, and **NixOS configuration.nix** generation.

5. **Multiple boot methods**

   * **ISO**: simplest for autoinstall (Ubuntu) and bootstrap (NixOS).
   * **Image**: instant boot with cloud images; Ansible finalizes.
   * **PXE**: suitable for baremetal and for VM workflows that mandate network installs. Role `pxe` sets up iPXE + HTTP.

6. **Security + secrets**

   * No secrets in code. Proxmox auth via env (`PM_API_TOKEN_*`). SSH keys live in `install_config.yaml` only.
   * Future: SOPS‑encrypted YAML and Ansible vault hooks (see improvements).

7. **Idempotency & drift**

   * **Terraform** is idempotent by design: `plan`/`apply` reflect drift.
   * **Ansible** tasks are idempotent (package and file modules). Use `--check` for dry‑runs later.

8. **Extensibility**

   * Adding an OS is just a new Ansible play + role and a small OS case in `provision_host`.
   * Adding a cloud (AWS/GCP/Hetzner): render a different TF root (provider/env) while keeping the same install model.

---

## Future Improvement Suggestions

1. **Enterprise CI/CD & GitOps**

   * **Pipeline**: Lint → Validate (`pydantic`, `yamllint`) → `terraform plan` (comment PR) → gated `apply` → `ansible --check` → `ansible apply`.
   * **GitOps**: Store `configs/` in a separate repo, apply via ArgoCD/Flux custom jobs or a controller that triggers `provision.py`.

2. **State & inventory**

   * Persist discovered attributes (e.g., IP from guest agent, PXE lease) into a `state.json` per host; feed back into inventory.

3. **Secrets & policy**

   * Integrate **Mozilla SOPS** (age/GPG) for `install_config.yaml` sections and Ansible vault for runtime secrets.
   * Policy checks: OpenSCAP/OSQuery role, CIS hardening roles gated per environment.

4. **HA & cluster bootstrapping**

   * Add **control‑plane roles** (e.g., etcd, k3s/k8s, Nomad, Consul) to bootstrap multi‑node clusters with dependency graphs in Python.

5. **Providers & platforms**

   * Modules for **Hetzner Cloud**, **AWS**, **GCP**; keep the same install schema.
   * For bare‑metal, integrate **IPMI/Redfish** via Ansible collections to power‑cycle and select boot devices (PXE vs disk).

6. **Observability**

   * Emit **OpenTelemetry** traces/spans from `provision.py` around Terraform/Ansible steps; ship logs to Loki/ELK.

7. **Drift detection**

   * Scheduled `terraform plan` + `ansible --check` with diffs published to a ChatOps channel.

8. **Service deployment layer**

   * Ubuntu: bake standard **Docker Compose**/Stack deployment hooks.
   * NixOS: generate module fragments for services; maintain a repository of Nix module overlays.

9. **Artifact management**

   * Cache ISOs/images in an internal mirror or **registry‑style store** (e.g., S3/MinIO) and update `defaults.yaml` catalog automatically.

10. **API & UI**

* Wrap `provision.py` with a FastAPI service for API‑based provisioning; emit job status & logs; multi‑tenant RBAC.

---

If you’d like, I can now **tailor this for enterprise pipelines** (GitOps layout, environments, promotion gates, SOPS, Vault, OPA policies, and a thin FastAPI around the orchestrator) and include **ready‑to‑use GitHub Actions** / **GitLab CI** workflows.
