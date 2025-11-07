"""
Formatting utilities for displaying data in the TUI.

Includes formatters for:
- Timestamps and durations
- File sizes
- Status messages
- Log lines
- YAML/JSON
"""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from rich.console import Console
from rich.syntax import Syntax
from rich.table import Table


# ---------- Time Formatting ----------

def format_timestamp(ts: str | datetime, fmt: str = "%Y-%m-%d %H:%M:%S") -> str:
    """Format timestamp for display."""
    if isinstance(ts, str):
        try:
            ts = datetime.fromisoformat(ts)
        except ValueError:
            return ts

    return ts.strftime(fmt)


def format_duration(seconds: float) -> str:
    """Format duration in human-readable format.

    Examples:
        2.5 -> "2.5s"
        65 -> "1m 5s"
        3665 -> "1h 1m 5s"
    """
    if seconds < 1:
        return f"{seconds:.2f}s"

    td = timedelta(seconds=int(seconds))
    parts = []

    hours = td.seconds // 3600
    minutes = (td.seconds % 3600) // 60
    secs = td.seconds % 60

    if td.days > 0:
        parts.append(f"{td.days}d")
    if hours > 0:
        parts.append(f"{hours}h")
    if minutes > 0:
        parts.append(f"{minutes}m")
    if secs > 0 or not parts:
        parts.append(f"{secs}s")

    return " ".join(parts)


def format_relative_time(ts: datetime | str) -> str:
    """Format timestamp as relative time (e.g., '2 hours ago')."""
    if isinstance(ts, str):
        try:
            ts = datetime.fromisoformat(ts)
        except ValueError:
            return ts

    now = datetime.now()
    diff = now - ts

    if diff.total_seconds() < 60:
        return "just now"
    elif diff.total_seconds() < 3600:
        minutes = int(diff.total_seconds() / 60)
        return f"{minutes}m ago"
    elif diff.total_seconds() < 86400:
        hours = int(diff.total_seconds() / 3600)
        return f"{hours}h ago"
    elif diff.days < 7:
        return f"{diff.days}d ago"
    else:
        return ts.strftime("%Y-%m-%d")


# ---------- Size Formatting ----------

def format_size(bytes: int, precision: int = 2) -> str:
    """Format byte size in human-readable format.

    Examples:
        1024 -> "1.00 KB"
        1048576 -> "1.00 MB"
    """
    units = ["B", "KB", "MB", "GB", "TB", "PB"]
    size = float(bytes)
    unit_index = 0

    while size >= 1024 and unit_index < len(units) - 1:
        size /= 1024
        unit_index += 1

    return f"{size:.{precision}f} {units[unit_index]}"


# ---------- String Formatting ----------

def truncate_string(s: str, max_length: int, suffix: str = "...") -> str:
    """Truncate string to max length with suffix."""
    if len(s) <= max_length:
        return s

    return s[:max_length - len(suffix)] + suffix


def pad_string(s: str, width: int, align: str = "left") -> str:
    """Pad string to specified width."""
    if align == "left":
        return s.ljust(width)
    elif align == "right":
        return s.rjust(width)
    elif align == "center":
        return s.center(width)
    return s


# ---------- Status Formatting ----------

def colorize_status(status: str) -> str:
    """Add color markup to status string based on status value."""
    status_lower = status.lower()

    if status_lower in ("success", "completed", "ok", "running"):
        return f"[green]{status}[/green]"
    elif status_lower in ("warning", "pending", "waiting"):
        return f"[yellow]{status}[/yellow]"
    elif status_lower in ("error", "failed", "critical"):
        return f"[red]{status}[/red]"
    elif status_lower in ("info", "starting", "in_progress"):
        return f"[cyan]{status}[/cyan]"
    else:
        return status


def format_status_icon(status: str) -> str:
    """Get icon for status."""
    status_lower = status.lower()

    icons = {
        "success": "✓",
        "completed": "✓",
        "ok": "✓",
        "running": "▶",
        "pending": "○",
        "waiting": "⏳",
        "warning": "⚠",
        "error": "✗",
        "failed": "✗",
        "critical": "⚠",
        "info": "ℹ",
        "starting": "▶",
        "in_progress": "▶",
    }

    return icons.get(status_lower, "•")


# ---------- Log Formatting ----------

def colorize_log_line(line: str) -> str:
    """Add color to log line based on content."""
    line_lower = line.lower()

    if any(word in line_lower for word in ["error", "failed", "exception", "traceback"]):
        return f"[red]{line}[/red]"
    elif any(word in line_lower for word in ["warning", "warn"]):
        return f"[yellow]{line}[/yellow]"
    elif any(word in line_lower for word in ["success", "completed", "done"]):
        return f"[green]{line}[/green]"
    elif any(word in line_lower for word in ["info", "starting"]):
        return f"[cyan]{line}[/cyan]"
    elif any(word in line_lower for word in ["debug", "trace"]):
        return f"[dim]{line}[/dim]"

    return line


def format_log_level(level: str) -> str:
    """Format log level with color and padding."""
    level = level.upper().ljust(8)

    level_colors = {
        "DEBUG": "dim",
        "INFO": "cyan",
        "WARNING": "yellow",
        "ERROR": "red",
        "CRITICAL": "red bold",
    }

    color = level_colors.get(level.strip(), "")
    if color:
        return f"[{color}]{level}[/{color}]"
    return level


# ---------- YAML/JSON Formatting ----------

def format_yaml(content: str, theme: str = "monokai") -> Syntax:
    """Format YAML content with syntax highlighting."""
    return Syntax(content, "yaml", theme=theme, line_numbers=True)


def format_json(content: str, theme: str = "monokai") -> Syntax:
    """Format JSON content with syntax highlighting."""
    return Syntax(content, "json", theme=theme, line_numbers=True)


def format_python(content: str, theme: str = "monokai") -> Syntax:
    """Format Python content with syntax highlighting."""
    return Syntax(content, "python", theme=theme, line_numbers=True)


# ---------- Table Formatting ----------

def create_status_table(data: list[dict[str, Any]], title: str = "Status") -> Table:
    """Create a formatted table for status display."""
    table = Table(title=title, show_header=True, header_style="bold cyan")

    if not data:
        return table

    # Add columns based on first row
    for key in data[0].keys():
        table.add_column(key.replace("_", " ").title())

    # Add rows
    for row in data:
        table.add_row(*[str(v) for v in row.values()])

    return table


# ---------- Progress Formatting ----------

def format_progress(current: int, total: int, width: int = 20) -> str:
    """Create ASCII progress bar.

    Example: [=========>          ] 45%
    """
    if total == 0:
        percentage = 0
    else:
        percentage = int((current / total) * 100)

    filled = int((current / total) * width) if total > 0 else 0
    bar = "=" * filled + ">" + " " * (width - filled - 1)

    return f"[{bar}] {percentage}%"


# ---------- List Formatting ----------

def format_list_items(items: list[str], prefix: str = "•", indent: int = 2) -> str:
    """Format list of items with prefix."""
    indent_str = " " * indent
    return "\n".join([f"{indent_str}{prefix} {item}" for item in items])


def format_numbered_list(items: list[str], indent: int = 2) -> str:
    """Format numbered list."""
    indent_str = " " * indent
    return "\n".join([f"{indent_str}{i+1}. {item}" for i, item in enumerate(items)])


# ---------- Key-Value Formatting ----------

def format_key_value(data: dict[str, Any], indent: int = 2, separator: str = ": ") -> str:
    """Format dictionary as key-value pairs."""
    indent_str = " " * indent
    lines = []

    max_key_len = max(len(str(k)) for k in data.keys()) if data else 0

    for key, value in data.items():
        key_padded = str(key).ljust(max_key_len)
        lines.append(f"{indent_str}{key_padded}{separator}{value}")

    return "\n".join(lines)


# ---------- Box Drawing ----------

def create_box(content: str, title: str = "", width: int | None = None) -> str:
    """Create a box around content using Unicode box drawing characters."""
    lines = content.split("\n")

    if width is None:
        width = max(len(line) for line in lines) if lines else 0

    if title:
        title = f" {title} "
        if len(title) > width - 2:
            title = title[:width-5] + "... "

    # Top border
    if title:
        title_len = len(title)
        left_border = "─" * 2
        right_border = "─" * (width - title_len - 2)
        top = f"┌{left_border}{title}{right_border}┐"
    else:
        top = f"┌{'─' * width}┐"

    # Content lines
    content_lines = [f"│ {line.ljust(width - 2)} │" for line in lines]

    # Bottom border
    bottom = f"└{'─' * width}┘"

    return "\n".join([top] + content_lines + [bottom])
