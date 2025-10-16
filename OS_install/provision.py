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