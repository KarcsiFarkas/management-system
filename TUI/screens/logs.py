"""
Logs Screen

Dedicated screen for viewing and managing deployment logs.
"""

from __future__ import annotations

from textual.app import ComposeResult
from textual.containers import Container, Horizontal
from textual.screen import Screen
from textual.widgets import Button, Header, Footer, Label, Input

from widgets.log_viewer import LogViewer


class LogViewerScreen(Screen):
    """
    Logs viewing screen with advanced features.

    Features:
    - Real-time log streaming
    - Search and filter
    - Follow mode (auto-scroll)
    - Export logs to file
    - Log level filtering
    """

    BINDINGS = [
        ("f", "toggle_follow", "Follow"),
        ("/", "search_logs", "Search"),
        ("c", "clear_logs", "Clear"),
        ("e", "export_logs", "Export"),
        ("1", "filter_errors", "Errors Only"),
        ("2", "filter_warnings", "Warnings+"),
        ("3", "filter_info", "Info+"),
        ("4", "show_all", "All Logs"),
        ("q", "back", "Back"),
    ]

    DEFAULT_CSS = """
    LogViewerScreen {
        background: $background;
    }

    LogViewerScreen .controls-panel {
        height: auto;
        padding: 1;
    }

    LogViewerScreen .controls-row {
        layout: horizontal;
        height: auto;
        padding: 0 1;
    }

    LogViewerScreen Button {
        margin: 0 1;
    }

    LogViewerScreen .search-container {
        layout: horizontal;
        height: auto;
        padding: 1;
    }

    LogViewerScreen Input {
        width: 1fr;
        margin: 0 1;
    }
    """

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.current_filter = "all"

    def compose(self) -> ComposeResult:
        """Compose the logs screen."""
        yield Header()

        # Search bar
        with Container(classes="search-container"):
            yield Label("Search:")
            yield Input(placeholder="Filter logs...", id="search-input")
            yield Button("Clear Search", id="btn-clear-search")

        # Log viewer
        yield LogViewer(
            title="Deployment Logs",
            max_lines=10000,
            show_line_numbers=True,
            id="main-log-viewer"
        )

        # Control buttons
        with Container(classes="controls-panel"):
            with Horizontal(classes="controls-row"):
                yield Button("Follow (f)", id="btn-follow", variant="primary")
                yield Button("Clear (c)", id="btn-clear")
                yield Button("Export (e)", id="btn-export")
                yield Button("Errors (1)", id="btn-errors")
                yield Button("Warnings (2)", id="btn-warnings")
                yield Button("Info (3)", id="btn-info")
                yield Button("All (4)", id="btn-all")
                yield Button("Back (q)", id="btn-back")

        yield Footer()

    def on_mount(self) -> None:
        """Called when screen is mounted."""
        # Load existing logs if any
        self._load_logs()

    def _load_logs(self) -> None:
        """Load logs from log file or deployment output."""
        log_viewer = self.query_one("#main-log-viewer", LogViewer)

        # In real implementation, load from actual log files
        # For now, add some example logs
        example_logs = [
            "INFO: Starting deployment orchestration",
            "INFO: Loading configuration from configs/defaults.yaml",
            "INFO: Found 4 VMs to deploy",
            "DEBUG: Rendering Terraform modules",
            "INFO: [1/4] Deploying web-server-1...",
            "INFO: ✓ Terraform apply completed for web-server-1",
            "WARNING: VM cloud-init taking longer than expected",
            "INFO: ✓ VM health check passed",
            "INFO: [2/4] Deploying db-server-1...",
            "ERROR: Terraform apply failed for db-server-1",
            "ERROR: Connection timeout to Proxmox API",
            "INFO: Retrying deployment after 15 seconds...",
            "INFO: ✓ Retry successful",
        ]

        log_viewer.add_lines(example_logs)

    def action_toggle_follow(self) -> None:
        """Toggle follow mode."""
        log_viewer = self.query_one("#main-log-viewer", LogViewer)
        log_viewer.toggle_follow()

        btn = self.query_one("#btn-follow", Button)
        if log_viewer.follow_mode:
            btn.label = "Following (f)"
        else:
            btn.label = "Follow (f)"

    def action_search_logs(self) -> None:
        """Focus the search input."""
        search_input = self.query_one("#search-input", Input)
        search_input.focus()

    def action_clear_logs(self) -> None:
        """Clear all logs."""
        log_viewer = self.query_one("#main-log-viewer", LogViewer)
        log_viewer.clear()

    def action_export_logs(self) -> None:
        """Export logs to file."""
        log_viewer = self.query_one("#main-log-viewer", LogViewer)

        from datetime import datetime
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"deployment_logs_{timestamp}.txt"

        success = log_viewer.export_logs(filename)

        if success:
            log_viewer.add_line(f"✓ Logs exported to {filename}")
        else:
            log_viewer.add_line(f"✗ Failed to export logs")

    def action_filter_errors(self) -> None:
        """Show only errors."""
        self._apply_filter("error")

    def action_filter_warnings(self) -> None:
        """Show warnings and errors."""
        self._apply_filter("warning")

    def action_filter_info(self) -> None:
        """Show info, warnings, and errors."""
        self._apply_filter("info")

    def action_show_all(self) -> None:
        """Show all logs."""
        self._apply_filter("all")

    def _apply_filter(self, level: str) -> None:
        """Apply log level filter."""
        self.current_filter = level
        log_viewer = self.query_one("#main-log-viewer", LogViewer)

        if level == "all":
            log_viewer.set_filter("")
        else:
            log_viewer.set_filter(level)

    def action_back(self) -> None:
        """Go back to previous screen."""
        self.app.pop_screen()

    def on_input_changed(self, event: Input.Changed) -> None:
        """Handle search input changes."""
        if event.input.id == "search-input":
            log_viewer = self.query_one("#main-log-viewer", LogViewer)
            log_viewer.set_filter(event.value)

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses."""
        button_id = event.button.id

        if button_id == "btn-follow":
            self.action_toggle_follow()
        elif button_id == "btn-clear":
            self.action_clear_logs()
        elif button_id == "btn-export":
            self.action_export_logs()
        elif button_id == "btn-errors":
            self.action_filter_errors()
        elif button_id == "btn-warnings":
            self.action_filter_warnings()
        elif button_id == "btn-info":
            self.action_filter_info()
        elif button_id == "btn-all":
            self.action_show_all()
        elif button_id == "btn-back":
            self.action_back()
        elif button_id == "btn-clear-search":
            search_input = self.query_one("#search-input", Input)
            search_input.value = ""
