"""
Status Panel Widget

Displays system status, deployment status, and key metrics.
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from rich.text import Text
from textual.app import ComposeResult
from textual.containers import Container, Horizontal, Vertical
from textual.widgets import Static, Label

from utils.formatters import format_duration, format_relative_time, colorize_status


class StatusPanel(Container):
    """Panel displaying current system and deployment status."""

    DEFAULT_CSS = """
    StatusPanel {
        height: auto;
        border: solid $primary;
        padding: 1;
        margin: 1;
    }

    StatusPanel .status-row {
        height: auto;
        layout: horizontal;
        padding: 0 1;
    }

    StatusPanel .status-label {
        width: 20;
        color: $text-muted;
    }

    StatusPanel .status-value {
        width: 1fr;
        color: $text;
    }

    StatusPanel .status-header {
        width: 100%;
        text-align: center;
        color: $primary;
        text-style: bold;
        padding: 0 0 1 0;
    }
    """

    def __init__(
        self,
        *,
        title: str = "System Status",
        **kwargs,
    ):
        super().__init__(**kwargs)
        self.title = title
        self.deployment_status = "Idle"
        self.deployment_progress = 0
        self.current_vm: Optional[str] = None
        self.vms_completed = 0
        self.vms_total = 0
        self.deployment_start_time: Optional[datetime] = None

    def compose(self) -> ComposeResult:
        """Compose the status panel."""
        yield Static(self.title, classes="status-header")

        with Horizontal(classes="status-row"):
            yield Label("Deployment:", classes="status-label")
            yield Label("Idle", id="deployment-status", classes="status-value")

        with Horizontal(classes="status-row"):
            yield Label("Progress:", classes="status-label")
            yield Label("0/0", id="deployment-progress", classes="status-value")

        with Horizontal(classes="status-row"):
            yield Label("Current VM:", classes="status-label")
            yield Label("None", id="current-vm", classes="status-value")

        with Horizontal(classes="status-row"):
            yield Label("Duration:", classes="status-label")
            yield Label("0s", id="deployment-duration", classes="status-value")

        with Horizontal(classes="status-row"):
            yield Label("Last Update:", classes="status-label")
            yield Label("Never", id="last-update", classes="status-value")

    def update_deployment_status(
        self,
        status: str,
        current_vm: Optional[str] = None,
        completed: int = 0,
        total: int = 0,
    ) -> None:
        """Update deployment status display."""
        self.deployment_status = status
        self.current_vm = current_vm
        self.vms_completed = completed
        self.vms_total = total

        if status.lower() in ("running", "in_progress"):
            if not self.deployment_start_time:
                self.deployment_start_time = datetime.now()
        elif status.lower() in ("completed", "failed", "idle"):
            self.deployment_start_time = None

        self._refresh_display()

    def _refresh_display(self) -> None:
        """Refresh the displayed values."""
        # Update deployment status
        status_widget = self.query_one("#deployment-status", Label)
        status_widget.update(colorize_status(self.deployment_status))

        # Update progress
        progress_widget = self.query_one("#deployment-progress", Label)
        progress_widget.update(f"{self.vms_completed}/{self.vms_total}")

        # Update current VM
        vm_widget = self.query_one("#current-vm", Label)
        vm_widget.update(self.current_vm or "None")

        # Update duration
        duration_widget = self.query_one("#deployment-duration", Label)
        if self.deployment_start_time:
            elapsed = (datetime.now() - self.deployment_start_time).total_seconds()
            duration_widget.update(format_duration(elapsed))
        else:
            duration_widget.update("0s")

        # Update last update time
        update_widget = self.query_one("#last-update", Label)
        update_widget.update(datetime.now().strftime("%H:%M:%S"))

    def start_deployment(self, total_vms: int) -> None:
        """Mark deployment as started."""
        self.deployment_start_time = datetime.now()
        self.vms_total = total_vms
        self.vms_completed = 0
        self.update_deployment_status("Running", completed=0, total=total_vms)

    def complete_vm(self, vm_name: str, success: bool = True) -> None:
        """Mark a VM as completed."""
        self.vms_completed += 1
        next_status = "Running" if self.vms_completed < self.vms_total else ("Completed" if success else "Failed")
        self.update_deployment_status(
            next_status,
            current_vm=None if self.vms_completed >= self.vms_total else "Processing...",
            completed=self.vms_completed,
            total=self.vms_total
        )

    def set_current_vm(self, vm_name: str) -> None:
        """Set the currently processing VM."""
        self.current_vm = vm_name
        self._refresh_display()

    def reset(self) -> None:
        """Reset status panel to initial state."""
        self.deployment_status = "Idle"
        self.current_vm = None
        self.vms_completed = 0
        self.vms_total = 0
        self.deployment_start_time = None
        self._refresh_display()


class CompactStatusBar(Static):
    """Compact status bar for footer."""

    DEFAULT_CSS = """
    CompactStatusBar {
        height: 1;
        background: $panel;
        color: $text-muted;
        dock: bottom;
    }

    CompactStatusBar .status-key {
        color: $accent;
    }
    """

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.status_items: dict[str, str] = {}

    def set_status(self, key: str, value: str) -> None:
        """Set a status item."""
        self.status_items[key] = value
        self._refresh()

    def remove_status(self, key: str) -> None:
        """Remove a status item."""
        self.status_items.pop(key, None)
        self._refresh()

    def _refresh(self) -> None:
        """Refresh the status bar display."""
        if not self.status_items:
            self.update("")
            return

        parts = []
        for key, value in self.status_items.items():
            parts.append(f"[bold]{key}[/bold]: {value}")

        self.update(" | ".join(parts))

    def set_deployment_status(self, status: str) -> None:
        """Quick helper to set deployment status."""
        self.set_status("Status", colorize_status(status))

    def set_vm_count(self, completed: int, total: int) -> None:
        """Quick helper to set VM count."""
        self.set_status("VMs", f"{completed}/{total}")
