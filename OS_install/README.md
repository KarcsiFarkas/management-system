# Provisioning Framework

A **production‑grade starting point** for a Python + Terraform + Ansible framework that provisions **Ubuntu or NixOS** onto **Proxmox VMs** or **bare‑metal via PXE**, with clean layering, sane defaults, and room for growth.

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

## Usage

### Prerequisites

- Python 3.12+
- Terraform >= 1.5.0
- Ansible
- Required Python packages: `pydantic`, `pyyaml`

### Basic Usage

```bash
# Install all hosts with default configuration
python3 provision.py

# Install specific hosts
python3 provision.py --hosts web-01 ci-runner-01

# Run only infrastructure provisioning
python3 provision.py --targets infra

# Use custom configuration files
python3 provision.py --defaults custom-defaults.yaml --vm-specs custom-vms.yaml

# Pipe install config from stdin
cat custom-install.yaml | python3 provision.py --install-config -
```

### Configuration Files

- **`configs/defaults.yaml`**: Global defaults (image URLs, provider settings)
- **`configs/vm_specs.yaml`**: VM hardware specifications
- **`configs/install_config.yaml`**: OS installation and user configuration

## File Structure

```
provisioning-framework/
├── provision.py                    # Main orchestrator
├── core/                          # Core modules
│   ├── __init__.py
│   └── types.py                   # Pydantic models
├── terraform/                     # Terraform modules
│   ├── modules/proxmox_vm/        # Proxmox VM module
│   └── envs/default/              # Default environment
├── ansible/                       # Ansible playbooks and roles
│   ├── playbooks/                 # Main playbooks
│   └── roles/                     # Ansible roles
├── templates/                     # Template files
│   └── cloudinit/                 # Cloud-init templates
├── configs/                       # Configuration files
└── README.md                      # This file
```

## Key Design Choices

1. **Strict separation of concerns**
   * **Terraform** owns VM lifecycle (resource IDs, disks, NICs, ISO attachment)
   * **Ansible** owns OS installation and configuration
   * **Python** orchestrates and glues (validation, rendering, async command runs)

2. **Layered configuration**
   * Merge precedence: **install_config > vm_specs > defaults**
   * New defaults propagate without overwriting user values

3. **Async orchestration**
   * Terraform and Ansible steps are fan‑out concurrent with configurable parallelism

4. **Multiple boot methods**
   * **ISO**: simplest for autoinstall (Ubuntu) and bootstrap (NixOS)
   * **Image**: instant boot with cloud images
   * **PXE**: suitable for baremetal and network installs

## Authentication

- **Proxmox**: Use environment variables `PM_API_TOKEN_ID` and `PM_API_TOKEN_SECRET`
- **SSH**: Keys are configured in `install_config.yaml`

## Examples

See the example configuration files in the `configs/` directory for complete working examples of:
- Ubuntu VM with Docker
- NixOS baremetal installation via PXE
- Multi-host deployments with different network configurations