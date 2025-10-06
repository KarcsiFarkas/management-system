# Pydantic models (mirrors those in provision.py)
# This file is kept minimal as the logic is primarily in provision.py
# to keep the deliverable self-contained as specified in the documentation.

from __future__ import annotations
from typing import Any, Literal, Optional
from pydantic import BaseModel, Field, HttpUrl, model_validator

# Type aliases
BootMethod = Literal["iso", "image", "pxe"]
OSType = Literal["ubuntu", "nixos"]
Hypervisor = Literal["proxmox", "baremetal"]

# Models mirror those in provision.py for potential future modularization