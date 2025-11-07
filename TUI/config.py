"""
TUI Configuration Module

Manages application-wide configuration including:
- File paths and directories
- Default settings
- User preferences
- Theme selection
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

import yaml
from pydantic import BaseModel, Field


# ---------- Path Configuration ----------

# Root paths
PROJECT_ROOT = Path(__file__).resolve().parents[1]  # management-system/
TUI_ROOT = Path(__file__).resolve().parent
SCRIPTS_DIR = PROJECT_ROOT / "scripts"


def _dir_has_yaml(path: Path) -> bool:
    try:
        if not path.exists() or not path.is_dir():
            return False
        # Look for at least one YAML file
        for ext in ("*.yml", "*.yaml"):
            if any(path.rglob(ext)):
                return True
        return False
    except Exception:
        return False


def resolve_profiles_dir() -> Path:
    """Resolve the profiles directory with preference order.

    Order of precedence:
    1. PROFILES_DIR environment variable, if it exists and contains YAML files
    2. <repo-root>/ms-config/tenants (primary)
    3. <repo-root>/ms-config/infrastructure
    4. <repo-root>/management-system/profiles
    5. <repo-root>/profiles
    """
    # 1) Environment variable override
    env_path = os.environ.get("PROFILES_DIR")
    if env_path:
        env_dir = Path(env_path).expanduser().resolve()
        if _dir_has_yaml(env_dir):
            return env_dir

    # Candidates in order
    candidates = [
        PROJECT_ROOT.parent / "ms-config" / "tenants",
        PROJECT_ROOT.parent / "ms-config" / "infrastructure",
        PROJECT_ROOT / "profiles",
        PROJECT_ROOT.parent / "profiles",
    ]

    for candidate in candidates:
        if _dir_has_yaml(candidate):
            return candidate

    # Fallback to <repo-root>/ms-config/tenants even if empty
    return (PROJECT_ROOT.parent / "ms-config" / "tenants")


PROFILES_DIR = resolve_profiles_dir()
CONFIG_DIR = Path.home() / ".config" / "management-tui"

# Build and log directories
BUILD_DIR = PROJECT_ROOT / "build"
LOGS_DIR = TUI_ROOT / "logs"
CACHE_DIR = TUI_ROOT / ".cache"

# Ensure directories exist
LOGS_DIR.mkdir(parents=True, exist_ok=True)
CACHE_DIR.mkdir(parents=True, exist_ok=True)


# ---------- Application Configuration ----------

class AppConfig(BaseModel):
    """Main application configuration."""

    # Display settings
    show_line_numbers: bool = True
    show_status_bar: bool = True
    show_footer: bool = True
    show_clock: bool = True

    # Theme
    theme: str = "dark"

    # Vim mode
    vim_mode: bool = True

    # Mouse support
    mouse_enabled: bool = True

    # Deployment defaults
    auto_refresh_interval: int = 5  # seconds
    max_log_lines: int = 1000
    log_tail_lines: int = 50

    # Paths
    scripts_path: str = str(SCRIPTS_DIR)
    profiles_path: str = str(PROFILES_DIR)
    config_path: str = str(CONFIG_DIR)

    # Script names
    provision_script: str = "provision_users.py"
    profile_helper_script: str = "profile_git_helper.py"

    # Advanced settings
    debug_mode: bool = False
    confirm_destructive: bool = True
    save_deployment_history: bool = True
    max_history_items: int = 100

    # Session management
    restore_last_session: bool = True

    class Config:
        arbitrary_types_allowed = True

    @classmethod
    def load(cls) -> "AppConfig":
        """Load config from file or return defaults"""
        return load_app_config()

    def save(self) -> None:
        """Save config to file"""
        save_app_config(self)


# ---------- Configuration Management ----------

CONFIG_FILE = TUI_ROOT / "tui_config.yaml"


def load_app_config() -> AppConfig:
    """Load app configuration from file or create default."""
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)

    if CONFIG_FILE.exists():
        try:
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                data = yaml.safe_load(f) or {}
                return AppConfig(**data)
        except Exception as e:
            print(f"Warning: Could not load config: {e}, using defaults")

    # Return default config
    return AppConfig()


def save_app_config(config: AppConfig) -> None:
    """Save app configuration to file."""
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)

    with open(CONFIG_FILE, "w", encoding="utf-8") as f:
        yaml.safe_dump(
            config.model_dump(mode="json"),
            f,
            default_flow_style=False,
            sort_keys=False
        )


# ---------- Deployment History ----------

HISTORY_FILE = CACHE_DIR / "deployment_history.yaml"


class DeploymentRecord(BaseModel):
    """Record of a deployment execution."""

    timestamp: str
    vms: list[str]
    targets: list[str]
    status: str  # "success", "failed", "partial"
    duration_seconds: float
    errors: list[str] = Field(default_factory=list)
    username: str | None = None


def load_deployment_history() -> list[DeploymentRecord]:
    """Load deployment history from file."""
    if not HISTORY_FILE.exists():
        return []

    with open(HISTORY_FILE, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or []
        return [DeploymentRecord(**item) for item in data]


def save_deployment_history(history: list[DeploymentRecord]) -> None:
    """Save deployment history to file."""
    with open(HISTORY_FILE, "w", encoding="utf-8") as f:
        yaml.safe_dump(
            [record.model_dump(mode="json") for record in history],
            f,
            default_flow_style=False,
            sort_keys=False
        )


def add_deployment_record(record: DeploymentRecord) -> None:
    """Add a new deployment record to history."""
    config = load_app_config()
    if not config.save_deployment_history:
        return

    history = load_deployment_history()
    history.insert(0, record)

    # Limit history size
    if len(history) > config.max_history_items:
        history = history[:config.max_history_items]

    save_deployment_history(history)


# ---------- Global Settings ----------

# Environment variable overrides
DEBUG = bool(int(os.environ.get("TUI_DEBUG", "0") or "0"))
PROVISION_DEBUG = bool(int(os.environ.get("ORCH_DEBUG", "0") or "0"))

# Terminal detection
TERM = os.environ.get("TERM", "xterm-256color")
SUPPORTS_UNICODE = os.environ.get("LANG", "").endswith("UTF-8")

# Version info
TUI_VERSION = "1.0.0"
TUI_NAME = "Provision TUI Manager"
