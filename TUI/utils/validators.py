"""
Validation utilities for configuration files and user input.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import yaml
from pydantic import ValidationError


def validate_yaml(content: str) -> tuple[bool, str, dict[str, Any] | None]:
    """
    Validate YAML content.

    Returns:
        Tuple of (is_valid, error_message, parsed_data)
    """
    try:
        data = yaml.safe_load(content)
        return (True, "", data)
    except yaml.YAMLError as e:
        return (False, f"YAML parsing error: {e}", None)


def validate_config_file(file_path: Path) -> tuple[bool, str]:
    """
    Validate that a configuration file exists and is readable.

    Returns:
        Tuple of (is_valid, error_message)
    """
    if not file_path.exists():
        return (False, f"File does not exist: {file_path}")

    if not file_path.is_file():
        return (False, f"Path is not a file: {file_path}")

    try:
        with open(file_path, "r", encoding="utf-8") as f:
            _ = f.read()
        return (True, "")
    except PermissionError:
        return (False, f"Permission denied: {file_path}")
    except Exception as e:
        return (False, f"Error reading file: {e}")


def validate_hostname(hostname: str) -> tuple[bool, str]:
    """
    Validate hostname format.

    Returns:
        Tuple of (is_valid, error_message)
    """
    if not hostname:
        return (False, "Hostname cannot be empty")

    if len(hostname) > 253:
        return (False, "Hostname too long (max 253 characters)")

    # Check for valid characters
    allowed = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-.")
    if not all(c in allowed for c in hostname):
        return (False, "Hostname contains invalid characters")

    # Check label length (between dots)
    labels = hostname.split(".")
    for label in labels:
        if len(label) > 63:
            return (False, "Hostname label too long (max 63 characters)")
        if label.startswith("-") or label.endswith("-"):
            return (False, "Hostname label cannot start or end with hyphen")

    return (True, "")


def validate_ip_address(ip: str) -> tuple[bool, str]:
    """
    Validate IPv4 address format.

    Returns:
        Tuple of (is_valid, error_message)
    """
    if not ip:
        return (False, "IP address cannot be empty")

    parts = ip.split(".")
    if len(parts) != 4:
        return (False, "IP address must have 4 octets")

    try:
        for part in parts:
            num = int(part)
            if num < 0 or num > 255:
                return (False, f"Invalid octet value: {num}")
        return (True, "")
    except ValueError:
        return (False, "IP address octets must be numbers")


def validate_cidr(cidr: str) -> tuple[bool, str]:
    """
    Validate CIDR notation (IP/prefix).

    Returns:
        Tuple of (is_valid, error_message)
    """
    if not cidr:
        return (False, "CIDR cannot be empty")

    if "/" not in cidr:
        return (False, "CIDR must include prefix length (e.g., 192.168.1.0/24)")

    ip, prefix = cidr.split("/", 1)

    # Validate IP part
    is_valid, error = validate_ip_address(ip)
    if not is_valid:
        return (False, error)

    # Validate prefix
    try:
        prefix_num = int(prefix)
        if prefix_num < 0 or prefix_num > 32:
            return (False, "CIDR prefix must be between 0 and 32")
    except ValueError:
        return (False, "CIDR prefix must be a number")

    return (True, "")


def validate_port(port: int | str) -> tuple[bool, str]:
    """
    Validate port number.

    Returns:
        Tuple of (is_valid, error_message)
    """
    try:
        port_num = int(port)
        if port_num < 1 or port_num > 65535:
            return (False, "Port must be between 1 and 65535")
        return (True, "")
    except ValueError:
        return (False, "Port must be a number")


def validate_path(path: str | Path, must_exist: bool = False) -> tuple[bool, str]:
    """
    Validate file system path.

    Args:
        path: Path to validate
        must_exist: If True, path must exist

    Returns:
        Tuple of (is_valid, error_message)
    """
    if not path:
        return (False, "Path cannot be empty")

    path_obj = Path(path) if isinstance(path, str) else path

    if must_exist and not path_obj.exists():
        return (False, f"Path does not exist: {path}")

    return (True, "")


def validate_username(username: str) -> tuple[bool, str]:
    """
    Validate Unix username format.

    Returns:
        Tuple of (is_valid, error_message)
    """
    if not username:
        return (False, "Username cannot be empty")

    if len(username) > 32:
        return (False, "Username too long (max 32 characters)")

    if not username[0].isalpha() and username[0] != "_":
        return (False, "Username must start with letter or underscore")

    allowed = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
    if not all(c in allowed for c in username):
        return (False, "Username contains invalid characters")

    return (True, "")


def validate_positive_int(value: Any, name: str = "Value") -> tuple[bool, str]:
    """
    Validate positive integer.

    Returns:
        Tuple of (is_valid, error_message)
    """
    try:
        num = int(value)
        if num <= 0:
            return (False, f"{name} must be positive")
        return (True, "")
    except (ValueError, TypeError):
        return (False, f"{name} must be a number")


def validate_memory_mb(value: Any) -> tuple[bool, str]:
    """
    Validate memory value in MB.

    Returns:
        Tuple of (is_valid, error_message)
    """
    is_valid, error = validate_positive_int(value, "Memory")
    if not is_valid:
        return (is_valid, error)

    mb = int(value)
    if mb < 512:
        return (False, "Memory must be at least 512 MB")

    return (True, "")


def validate_cpu_count(value: Any) -> tuple[bool, str]:
    """
    Validate CPU count.

    Returns:
        Tuple of (is_valid, error_message)
    """
    is_valid, error = validate_positive_int(value, "CPU count")
    if not is_valid:
        return (is_valid, error)

    cpus = int(value)
    if cpus > 128:
        return (False, "CPU count seems unreasonably high (max 128)")

    return (True, "")


def validate_disk_size_gb(value: Any) -> tuple[bool, str]:
    """
    Validate disk size in GB.

    Returns:
        Tuple of (is_valid, error_message)
    """
    is_valid, error = validate_positive_int(value, "Disk size")
    if not is_valid:
        return (is_valid, error)

    gb = int(value)
    if gb < 8:
        return (False, "Disk size must be at least 8 GB")

    return (True, "")
