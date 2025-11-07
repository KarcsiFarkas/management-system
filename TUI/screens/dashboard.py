"""
Dashboard Screen

Main landing screen showing deployment overview and quick actions.
"""

from __future__ import annotations

from textual.app import ComposeResult
from textual.containers import Container, Grid
from textual.screen import Screen
from textual.widgets import Button, Header, Footer, Label, Static

from config import load_deployment_history
from utils.formatters import format_relative_time, colorize_status
from widgets.status_panel import StatusPanel


class QuickActionsPanel(Container):
    """Panel with quick action buttons."""

    DEFAULT_CSS = """
    QuickActionsPanel {
        height: auto;
        border: solid $primary;
        padding: 1;
        margin: 1;
    }

    QuickActionsPanel .panel-title {
        width: 100%;
        text-align: center;
        color: $primary;
        text-style: bold;
        padding: 0 0 1 0;
    }

    QuickActionsPanel Grid {
        grid-size: 2 2;
        grid-gutter: 1;
        padding: 1;
        height: auto;
    }

    QuickActionsPanel Button {
        width: 100%;
        height: 3;
    }
    """

    def compose(self) -> ComposeResult:
        """Compose quick actions panel."""
        yield Label("Quick Actions", classes="panel-title")
        with Grid():
            yield Button("[bold]Deploy[/bold]\n(d)", id="btn-deploy", variant="primary")
            yield Button("[bold]View Logs[/bold]\n(l)", id="btn-logs")
            yield Button("[bold]History[/bold]\n(h)", id="btn-history")
            yield Button("[bold]Help[/bold]\n(?)", id="btn-help")


class RecentDeploymentsPanel(Container):
    """Panel showing recent deployment history."""

    DEFAULT_CSS = """
    RecentDeploymentsPanel {
        height: auto;
        border: solid $primary;
        padding: 1;
        margin: 1;
    }

    RecentDeploymentsPanel .panel-title {
        width: 100%;
        text-align: center;
        color: $primary;
        text-style: bold;
        padding: 0 0 1 0;
    }

    RecentDeploymentsPanel .history-item {
        width: 100%;
        height: auto;
        padding: 0 1;
    }

    RecentDeploymentsPanel .empty-message {
        width: 100%;
        text-align: center;
        color: $text-muted;
        padding: 2;
    }
    """

    def compose(self) -> ComposeResult:
        """Compose recent deployments panel."""
        yield Label("Recent Deployments", classes="panel-title")

        # Load deployment history
        history = load_deployment_history()

        if not history:
            yield Label("No deployment history", classes="empty-message")
        else:
            # Show last 5 deployments
            for record in history[:5]:
                status_color = colorize_status(record.status)
                vms_text = ", ".join(record.vms[:3])
                if len(record.vms) > 3:
                    vms_text += f" (+{len(record.vms) - 3} more)"

                time_text = format_relative_time(record.timestamp)

                item_text = f"{status_color} | {vms_text} | {time_text}"
                yield Label(item_text, classes="history-item")


class DashboardScreen(Screen):
    """
    Main dashboard screen.

    Shows:
    - System status
    - Quick action buttons
    - Recent deployment history
    - Key statistics
    """

    BINDINGS = [
        ("d", "goto_deployment", "Deploy"),
        ("l", "goto_logs", "Logs"),
        ("h", "goto_history", "History"),
        ("?", "show_help", "Help"),
        ("q", "quit", "Quit"),
    ]

    DEFAULT_CSS = """
    DashboardScreen {
        background: $background;
    }

    DashboardScreen .welcome-header {
        width: 100%;
        height: auto;
        text-align: center;
        padding: 2;
        color: $primary;
        text-style: bold;
    }

    DashboardScreen .dashboard-grid {
        layout: grid;
        grid-size: 2 2;
        grid-gutter: 1;
        padding: 1;
        height: 1fr;
    }
    """

    def compose(self) -> ComposeResult:
        """Compose the dashboard screen."""
        yield Header()

        yield Static(
            "[bold cyan]Provision TUI Manager[/bold cyan]\n"
            "Multi-tenant VM Deployment Orchestration",
            classes="welcome-header"
        )

        with Grid(classes="dashboard-grid"):
            yield StatusPanel(title="Current Status")
            yield QuickActionsPanel()
            yield RecentDeploymentsPanel()

            # Stats panel
            with Container():
                yield Label("System Statistics", classes="panel-title")
                yield Label("VMs Configured: --", id="stat-vms")
                yield Label("Tenants: --", id="stat-tenants")
                yield Label("Last Deploy: --", id="stat-last-deploy")

        yield Footer()

    def action_goto_deployment(self) -> None:
        """Navigate to deployment screen."""
        self.app.push_screen("deployment")

    def action_goto_logs(self) -> None:
        """Navigate to logs screen."""
        self.app.push_screen("logs")

    def action_goto_history(self) -> None:
        """Navigate to history screen."""
        self.app.push_screen("history")

    def action_show_help(self) -> None:
        """Show help screen."""
        self.app.push_screen("help")

    def action_quit(self) -> None:
        """Quit the application."""
        self.app.exit()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses."""
        button_id = event.button.id

        if button_id == "btn-deploy":
            self.action_goto_deployment()
        elif button_id == "btn-logs":
            self.action_goto_logs()
        elif button_id == "btn-history":
            self.action_goto_history()
        elif button_id == "btn-help":
            self.action_show_help()

    def on_mount(self) -> None:
        """Called when screen is mounted."""
        # Update statistics
        # This would be populated from actual config in real implementation
        pass
