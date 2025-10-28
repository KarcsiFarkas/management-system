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
import contextlib
import json
import os
import secrets
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Literal, Optional, Sequence

import yaml
from pydantic import BaseModel, Field, HttpUrl, ValidationError, model_validator

# --- Global Constants ---
PROJECT_ROOT = Path(__file__).resolve().parents[2]  # thesis-szakdoga/
TENANTS_DIR = PROJECT_ROOT / "ms-config" / "tenants"

try:
    import fcntl  # type: ignore
except Exception:
    fcntl = None

DEBUG = bool(int(os.environ.get("ORCH_DEBUG", "0") or "0"))

# ---------- Models ----------

BootMethod = Literal["iso", "image", "pxe"]
OSType = Literal["ubuntu", "nixos"]
Hypervisor = Literal["proxmox", "baremetal"]

class DiskSpec(BaseModel):
    size_gb: int = Field(50, ge=8)
    storage: str
    type: Literal["scsi", "virtio", "sata"] = "scsi"

class NetIfSpec(BaseModel):
    bridge: str
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
    docker: bool = False
    nix_services: list[str] = Field(default_factory=list)
    partitioning: dict[str, Any] = Field(default_factory=dict)

class VMSpec(BaseModel):
    name: str
    tenant: str = "default"
    hypervisor: Hypervisor = "proxmox"
    boot_method: BootMethod = "iso"
    cpus: int = Field(2, ge=1)
    memory_mb: int = Field(4096, ge=512)
    disks: list[DiskSpec]
    netifs: list[NetIfSpec]
    proxmox: Optional[dict[str, Any]] = None
    baremetal: Optional[dict[str, Any]] = None

class ImageCatalog(BaseModel):
    ubuntu_iso_url: HttpUrl
    ubuntu_image_url: Optional[HttpUrl] = None
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
    installs: dict[str, OSInstallConfig]

# ---------- Tenant Key & Password Management -

# ---------- Tenant Key Management ----------

def ensure_ssh_keypair(tenant_name: str) -> Path:
    """Ensures that an ed25519 SSH keypair exists for the given tenant."""
    tenant_dir = TENANTS_DIR / tenant_name
    tenant_dir.mkdir(parents=True, exist_ok=True)
    priv_key = tenant_dir / "id_ed25519"
    pub_key = tenant_dir / "id_ed25519.pub"

    if not pub_key.exists() or not priv_key.exists():
        print(f"🔐 Generating new SSH keypair for tenant '{tenant_name}'...")
        subprocess.run(
            ["ssh-keygen", "-t", "ed25519", "-N", "", "-f", str(priv_key)],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    else:
        print(f"🔑 Reusing existing SSH keypair for tenant '{tenant_name}'")

    return pub_key

def ensure_tenant_password(tenant_name: str) -> str:
    """Generate or reuse a persistent password for a tenant."""
    tenant_dir = TENANTS_DIR / tenant_name
    tenant_dir.mkdir(parents=True, exist_ok=True)
    pw_file = tenant_dir / "password.txt"

    if pw_file.exists():
        return pw_file.read_text().strip()

    password = secrets.token_urlsafe(12)
    pw_file.write_text(password)
    print(f"🔐 Generated tenant password for '{tenant_name}': {password}")
    return password
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

class ShellError(RuntimeError): pass

async def run_cmd(*cmd: str, cwd: Optional[Path] = None, env: Optional[dict[str, str]] = None) -> None:
    if DEBUG:
        here = str(cwd) if cwd else os.getcwd()
        print(f"🐞 [{here}] >> {' '.join(cmd)}")
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

def ensure_clean_dir(path: Path, *, clean: bool = True) -> None:
    if path.exists():
        if path.is_dir():
            if clean:
                shutil.rmtree(path, ignore_errors=True)
                path.mkdir(parents=True, exist_ok=True)
        else:
            path.unlink(missing_ok=True)
            path.mkdir(parents=True, exist_ok=True)
    else:
        path.mkdir(parents=True, exist_ok=True)

@contextlib.asynccontextmanager
async def filelock(lock_path: Path):
    """
    Simple flock-based async context manager (Unix).
    Ensures only one worker manipulates a host build directory at a time.
    """
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    if fcntl is None:
        # Fallback: no-op lock if fcntl is unavailable (not recommended on multi-runner systems)
        yield
        return

    with open(lock_path, "w") as fh:
        fcntl.flock(fh, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(fh, fcntl.LOCK_UN)

# ---------- Renderers ----------

def render_tf_module(workdir: Path, vm: VMSpec, install: OSInstallConfig, defaults: Defaults, username_override: Optional[str] = None) -> None:
    """Render Terraform files + tfvars with tenant SSH key and fallback password."""
    mod_src = Path("terraform/modules/proxmox_vm")
    root_tf_src = Path("terraform")
    tf_dir = workdir / "tf"
    ensure_empty_dir(tf_dir)

    # Copy module directory and root files
    shutil.copytree(mod_src, tf_dir / "modules" / "proxmox_vm")
    for fname in ("main.tf", "variables.nix.tf", "provider.tf", "outputs.tf"):
        shutil.copy(root_tf_src / fname, tf_dir / fname)

    node = (vm.proxmox or {}).get("node", "pve")
    storage = (vm.proxmox or {}).get("storage", "local-lvm")
    bridge = vm.netifs[0].bridge if vm.netifs else "vmbr0"
    vlan = vm.netifs[0].vlan if vm.netifs else None
    disk_size = vm.disks[0].size_gb if vm.disks else 20

    ip = install.network.address_cidr if not install.network.dhcp else "dhcp"
    gateway = install.network.gateway if not install.network.dhcp else ""
    dns = install.network.dns or ["1.1.1.1", "9.9.9.9"]

    tenant_name = getattr(vm, "tenant", "default")
    pub_key_path = ensure_ssh_keypair(tenant_name)
    ssh_key = pub_key_path.read_text().strip()
    tenant_password = ensure_tenant_password(tenant_name)

    endpoint = str(defaults.proxmox_provider.get("pm_api_url", "")).strip()
    if not endpoint:
        endpoint = os.environ.get("PROXMOX_VE_ENDPOINT", "")
    if not endpoint:
        raise RuntimeError("Missing Proxmox API endpoint.")

    vm_user = username_override or (install.users[0].username if install.users else "ubuntu")

    tfvars = {
        "proxmox_endpoint": endpoint,
        "vm_name": vm.name,
        "vm_node": node,
        "vm_storage": storage,
        "vm_bridge": bridge,
        "vm_vlan": vlan,
        "vm_cpus": vm.cpus,
        "vm_memory": vm.memory_mb,
        "vm_disk_size": disk_size,
        "vm_ip": ip,
        "vm_gateway": gateway,
        "vm_dns": dns,
        "ssh_key": ssh_key,
        "vm_username": vm_user,
        "vm_password": tenant_password,
    }

    (tf_dir / "terraform.tfvars.json").write_text(json.dumps(tfvars, indent=2), encoding="utf-8")

    if DEBUG:
        print("📝 Generated terraform.tfvars.json:")
        print(json.dumps(tfvars, indent=2))

# ---------- Ansible Renderer ----------

def render_ansible_inventory(workdir: Path, vm: VMSpec, install: OSInstallConfig, defaults: Defaults, username_override: Optional[str] = None) -> Path:
    ans_dir = workdir / "ansible"
    ensure_clean_dir(ans_dir, clean=True)

    tenant_name = getattr(vm, "tenant", "default")
    pub_key_path = ensure_ssh_keypair(tenant_name)
    pub_key = pub_key_path.read_text().strip()
    tenant_password = ensure_tenant_password(tenant_name)

    if install.users:
        for user in install.users:
            if not user.ssh_authorized_keys:
                user.ssh_authorized_keys.append(pub_key)
    else:
        install.users = [UserSpec(username="ubuntu", sudo=True, ssh_authorized_keys=[pub_key])]

    ans_user = username_override or (install.users[0].username if install.users else "ubuntu")

    inv = {"all": {"children": {"ubuntu": {"hosts": {vm.name: {"ansible_host": install.network.address_cidr.split('/')[0]}}}}}}
    host_vars = {
        "ansible_user": ans_user,
        "ansible_password": tenant_password,
        "network": install.network.model_dump(),
        "packages": install.packages,
        "docker_enabled": install.docker,
        "nix_services": install.nix_services,
        "partitioning": install.partitioning,
        "users": [u.model_dump() for u in install.users],
    }

    ssh_args = (defaults.ansible_defaults or {}).get("ssh_common_args")
    if ssh_args:
        host_vars["ansible_ssh_common_args"] = ssh_args

    (ans_dir / "inventory.yaml").write_text(yaml.safe_dump(inv, sort_keys=False), encoding="utf-8")
    (ans_dir / f"{vm.name}.vars.yaml").write_text(yaml.safe_dump(host_vars, sort_keys=False), encoding="utf-8")

    return ans_dir / "inventory.yaml"

# ---------- Orchestration ----------

async def terraform_apply(tf_dir: Path, max_retries: int = 2) -> dict[str, Any]:
    """
    Execute Terraform with proper error handling and retry logic.

    Args:
        tf_dir: Directory containing Terraform configuration
        max_retries: Number of retry attempts on failure
    Returns:
        A dictionary of Terraform outputs on success.
    """
    env_map = os.environ.copy()
    if DEBUG:
        env_map["TF_LOG"] = "DEBUG"
        env_map["TF_LOG_PATH"] = str(tf_dir / "terraform-debug.log")

    # Initialize Terraform
    print("🔧 Initializing Terraform...")
    await run_cmd("terraform", "init", "-upgrade", cwd=tf_dir, env=env_map)

    # Validate configuration
    print("✅ Validating Terraform configuration...")
    await run_cmd("terraform", "validate", cwd=tf_dir, env=env_map)

    # Attempt apply with retries
    for attempt in range(max_retries):
        try:
            print(f"📋 Planning infrastructure (attempt {attempt + 1}/{max_retries})...")
            await run_cmd("terraform", "plan", "-input=false", "-out=tfplan", cwd=tf_dir, env=env_map)

            print(f"🚀 Applying infrastructure (attempt {attempt + 1}/{max_retries})...")
            await run_cmd("terraform", "apply", "-auto-approve", "-input=false", "tfplan", cwd=tf_dir, env=env_map)

            print("✅ Terraform apply completed successfully!")

            # Get outputs after apply
            print("... retrieving outputs ...")
            proc = await asyncio.create_subprocess_exec(
                "terraform", "output", "-json",
                cwd=tf_dir,
                env=env_map,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await proc.communicate()
            if proc.returncode != 0:
                print(f"⚠️ Could not get Terraform outputs: {stderr.decode()}")
                return {}

            return json.loads(stdout.decode())

        except ShellError as e:
            error_msg = str(e)

            # Check for specific error patterns
            if "timeout" in error_msg.lower():
                print(f"⏱️  Terraform timeout detected on attempt {attempt + 1}")
            elif "agent" in error_msg.lower():
                print(f"🤖 QEMU agent issue detected on attempt {attempt + 1}")
            elif "lock" in error_msg.lower():
                print(f"🔒 Resource lock detected on attempt {attempt + 1}")
            else:
                print(f"❌ Terraform error on attempt {attempt + 1}: {error_msg}")

            if attempt < max_retries - 1:
                print("🔄 Retrying after cleanup...")
                try:
                    print("🧹 Cleaning up partial infrastructure...")
                    await run_cmd("terraform", "destroy", "-auto-approve", "-input=false", cwd=tf_dir, env=env_map)
                except ShellError:
                    print("⚠️  Cleanup failed, but continuing with retry...")

                wait_time = 15 * (attempt + 1)
                print(f"⏳ Waiting {wait_time} seconds before retry...")
                await asyncio.sleep(wait_time)
            else:
                print(f"❌ Terraform apply failed after {max_retries} attempts")
                raise

    return {}  # Should not be reached

async def check_vm_health(vm_ip: str, vm_name: str, ssh_user: str, timeout: int = 300) -> bool:
    """
    Check if VM is healthy and cloud-init has completed.

    Args:
        vm_ip: IP address of the VM
        vm_name: Name of the VM
        ssh_user: The username to SSH with (e.g., 'ubuntu' or 'devops')
        timeout: Maximum time to wait in seconds
    """
    print(f"🏥 Checking health of VM {vm_name} at {vm_ip} as user {ssh_user}...")

    start_time = asyncio.get_event_loop().time()

    while (asyncio.get_event_loop().time() - start_time) < timeout:
        try:
            # Check SSH connectivity
            proc = await asyncio.create_subprocess_exec(
                "ssh",
                "-o", "StrictHostKeyChecking=no",
                "-o", "UserKnownHostsFile=/dev/null",
                "-o", "ConnectTimeout=5",
                f"{ssh_user}@{vm_ip}",
                "echo 'SSH OK'",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, _ = await proc.communicate()

            if proc.returncode == 0:
                print(f"✅ SSH is responsive on {vm_ip}")

                # Check cloud-init status
                proc = await asyncio.create_subprocess_exec(
                    "ssh",
                    "-o", "StrictHostKeyChecking=no",
                    "-o", "UserKnownHostsFile=/dev/null",
                    f"{ssh_user}@{vm_ip}",
                    "cloud-init status --wait || cloud-init status",
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                stdout, stderr = await proc.communicate()

                if b"done" in stdout or b"disabled" in stdout:
                    print(f"✅ Cloud-init completed on {vm_name}")
                    return True
                else:
                    print(f"⏳ Cloud-init still running on {vm_name}...")

        except Exception as e:
            if DEBUG:
                print(f"🔍 Health check error: {e}")

        await asyncio.sleep(10)

    print(f"⚠️  VM health check timed out after {timeout} seconds")
    return False

async def ansible_play(playbook: Path, inventory: Path, extra_vars_file: Path) -> None:
    args = [
        "ansible-playbook",
        "-i", str(inventory),
        str(playbook),
        "--extra-vars", f"@{extra_vars_file}",
    ]
    if DEBUG:
        args.insert(1, "-vvv")
    await run_cmd(*args)

async def provision_host(
    root_build: Path,
    vm: VMSpec,
    install: OSInstallConfig,
    defaults: Defaults,
    targets: set[str],
    username_override: Optional[str] = None
) -> tuple[str, Optional[Exception]]:
    """Enhanced provision_host with health checks and robust build dir creation."""
    host_dir = root_build / vm.name
    lock_path = host_dir.with_suffix(".lock")

    # Lock to prevent concurrent manipulation of the same host dir
    async with filelock(lock_path):
        ensure_clean_dir(host_dir, clean=True)

        try:
            # Terraform (infra for Proxmox VM; PXE uses Ansible only)
            if vm.hypervisor == "proxmox":
                render_tf_module(host_dir, vm, install, defaults, username_override)

                vm_ip_for_tasks = None
                ssh_user = "root"
                if install.os == "ubuntu":
                    ssh_user = username_override or (install.users[0].username if install.users else "ubuntu")

                if "infra" in targets:
                    # Capture outputs
                    tf_outputs = await terraform_apply(host_dir / "tf", max_retries=2)

                    if install.network.dhcp:
                        # Get IP from Terraform output for DHCP
                        try:
                            new_ip = tf_outputs.get("vm_ip", {}).get("value")
                            if new_ip and new_ip != "dhcp-pending":
                                vm_ip_for_tasks = new_ip
                                print(f"✅ DHCP IP detected: {vm_ip_for_tasks}")
                                # Update install config for Ansible
                                install.network.address_cidr = vm_ip_for_tasks
                            else:
                                raise RuntimeError("DHCP IP not found in Terraform output. 'vm_ip' was missing or pending.")
                        except Exception as e:
                            print(f"⚠️ Could not get DHCP IP: {e}")
                            return (vm.name, e)
                    else:
                        # Get IP from config for static
                        vm_ip_for_tasks = (install.network.address_cidr or "").split("/")[0]

                    if vm_ip_for_tasks:
                        print("... giving VM 30s to boot before health check ...")
                        await asyncio.sleep(30)
                        healthy = await check_vm_health(vm_ip_for_tasks, vm.name, ssh_user, timeout=300)
                        if not healthy:
                            print(f"⚠️  Warning: VM {vm.name} may not be fully ready")

            # Ansible (OS installation / post-config)
            inv = render_ansible_inventory(host_dir, vm, install, defaults, username_override)
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
    p.add_argument("--username", help="Override the username for VM and SSH.")
    p.add_argument("--debug", action="store_true", help="Enable verbose debug output and real-time command logs")
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
    # Override module-level DEBUG if flag is set
    global DEBUG
    if args.debug:
        DEBUG = True
        print("🐞 Debug mode enabled: streaming command logs; Terraform TF_LOG=INFO; Ansible -vvv")
    config = load_config(args.defaults, args.vm_specs, args.install_config)

    selected: list[VMSpec] = [
        vm for vm in config.vms if not args.hosts or vm.name in args.hosts
    ]
    if not selected:
        print("No hosts match selection.", file=sys.stderr)
        sys.exit(1)

    root_build = build_root()
    targets = set(args.targets)
    username_override = args.username or None

    # Render and optionally plan/apply concurrently
    sem = asyncio.Semaphore(args.concurrency)
    results: list[tuple[str, Optional[Exception]]] = []

    async def worker(vm: VMSpec) -> None:
        install = config.installs.get(vm.name)
        if not install:
            results.append((vm.name, RuntimeError("Missing install_config for host")))
            return
        async with sem:
            res = await provision_host(root_build, vm, install, config.defaults, targets, username_override)
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
