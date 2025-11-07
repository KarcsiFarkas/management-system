#!/usr/bin/env python3
"""
Management System TUI - Main Application Entry Point

A modern Terminal User Interface for managing multi-tenant deployments,
user provisioning, and profile management for Docker and NixOS-based
self-hosted PaaS environments.

Features:
- Vim-style keyboard navigation
- Real-time deployment monitoring
- Multi-tenant profile management
- Interactive service configuration
- Live log streaming
- Command palette
- Multiple themes
"""

import sys
from pathlib import Path
from typing import Optional

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Container
from textual.widgets import Footer, Header
from textual.reactive import reactive

# Add parent directory to path for imports
# sys.path.insert(0, str(Path(__file__).parent.parent))

from screens.dashboard import DashboardScreen
from screens.deployment import DeploymentScreen
from screens.logs import LogViewerScreen
from screens.help import HelpScreen
from widgets.command_palette import CommandPalette
from widgets.confirmation_dialog import ConfirmationDialog
from config import AppConfig
from theme import ThemeManager
from keybindings import KeyBindings


class ManagementTUI(App):
    """
    Main TUI Application for Management System

    Provides a unified interface for:
    - Deploying services (Docker/NixOS variants)
    - Managing user profiles and Git branches
    - Provisioning users across services
    - Monitoring deployments in real-time
    - Viewing and searching logs
    """

    CSS_PATH = "styles.tcss"

    # Bindings available globally
    BINDINGS = [
        Binding("q", "quit", "Quit", show=True, priority=True),
        Binding("question_mark,f1", "show_help", "Help", show=True),
        Binding("ctrl+p", "command_palette", "Command Palette", show=False),
        Binding("ctrl+t", "toggle_theme", "Theme", show=True),
        Binding("d", "push_screen('dashboard')", "Dashboard", show=True),
        Binding("l", "push_screen('logs')", "Logs", show=True),
        Binding("escape", "app.pop_screen", "Back", show=False),
    ]

    # Reactive attributes
    current_theme = reactive("dark")
    deployment_running = reactive(False)

    def __init__(self, **kwargs):
        """Initialize the application with configuration and theme"""
        super().__init__(**kwargs)

        # Load configuration
        self.config = AppConfig.load()

        # Initialize theme manager
        self.theme_manager = ThemeManager()

        # Initialize keybindings
        self.keybindings = KeyBindings()

        # Store paths
        self.scripts_dir = Path(__file__).parent.parent / "scripts"
        self.profiles_dir = Path(self.config.profiles_path) if self.config.profiles_path else None

        # Application state
        self.selected_profile: Optional[str] = None
        self.last_deployment: Optional[dict] = None
        self.deployment_history: list = []

    def compose(self) -> ComposeResult:
        """App composes no child widgets; Screens manage their own layout."""
        yield from ()

    def on_mount(self) -> None:
        """
        Called when app is mounted

        - Apply theme
        - Load last session state
        - Install screens and show dashboard
        """
        # Apply theme
        self.apply_theme(self.current_theme)

        # Set title
        self.title = "Management System TUI"
        self.sub_title = f"Profile: {self.selected_profile or 'None'}"

        # Load last session
        self._load_session_state()

        # Install screens by name so push_screen("name") works
        try:
            self.install_screen(DashboardScreen(), "dashboard")
            self.install_screen(DeploymentScreen(), "deployment")
            self.install_screen(LogViewerScreen(), "logs")
            self.install_screen(HelpScreen(), "help")
            # Optional history screen installed if available
            try:
                from screens.history import HistoryScreen  # type: ignore
                self.install_screen(HistoryScreen(), "history")
            except Exception:
                pass
        except Exception as e:
            self.notify(f"Failed to install screens: {e}", severity="error")

        # Show the dashboard as the initial screen
        try:
            self.push_screen("dashboard")
        except Exception as e:
            self.notify(f"Unable to open dashboard: {e}", severity="error")

        # Welcome message
        self.notify(
            "Welcome to Management System TUI! Press ? for help",
            severity="information",
            timeout=5
        )

    def action_quit(self) -> None:
        """Quit the application with confirmation if deployment is running"""
        if self.deployment_running:
            dialog = ConfirmationDialog(
                title="Quit Application",
                message="A deployment is running. Are you sure you want to quit?",
                confirm_text="Quit",
                cancel_text="Cancel",
                confirm_variant="error",
                data={"intent": "quit"},
            )
            self.mount(dialog)
        else:
            self.exit()

    def action_show_help(self) -> None:
        """Show help screen with keyboard shortcuts"""
        self.push_screen("help")

    def action_command_palette(self) -> None:
        """Show command palette for quick actions"""
        # Mount or reveal a single instance of the command palette on the current screen
        try:
            palette = self.screen.query_one(CommandPalette)
        except Exception:
            palette = CommandPalette()
            try:
                self.screen.mount(palette)
            except Exception:
                # Fallback: mount to app root if screen not available
                self.mount(palette)
        palette.show_palette()

    def action_toggle_theme(self) -> None:
        """Toggle between light and dark themes"""
        if self.current_theme == "dark":
            self.current_theme = "light"
        else:
            self.current_theme = "dark"

        self.apply_theme(self.current_theme)
        self.notify(f"Theme changed to {self.current_theme}")

    def apply_theme(self, theme_name: str) -> None:
        """
        Apply a theme to the application

        Args:
            theme_name: Name of theme to apply ('dark', 'light', etc.)
        """
        theme = self.theme_manager.get_theme(theme_name)
        if theme:
            # Apply theme variables to CSS
            # Textual will automatically pick up CSS variables
            self.notify(f"Applied {theme_name} theme", timeout=2)

    def push_deployment_screen(
        self,
        deployment_type: str,
        profile: Optional[str] = None
    ) -> None:
        """
        Push deployment screen with pre-selected options

        Args:
            deployment_type: Type of deployment ('docker', 'nix', etc.)
            profile: Optional profile name to pre-select
        """
        screen = DeploymentScreen(
            deployment_type=deployment_type,
            profile=profile or self.selected_profile
        )
        self.push_screen(screen)

    def push_logs_screen(self, filter_text: Optional[str] = None) -> None:
        """
        Push log viewer screen

        Args:
            filter_text: Optional text to pre-filter logs
        """
        screen = LogViewerScreen(filter_text=filter_text)
        self.push_screen(screen)

    def on_deployment_started(self, deployment_info: dict) -> None:
        """
        Handle deployment started event

        Args:
            deployment_info: Dictionary with deployment details
        """
        self.deployment_running = True
        self.last_deployment = deployment_info
        self.sub_title = f"Deploying: {deployment_info.get('profile', 'Unknown')}"

        self.notify(
            f"Deployment started: {deployment_info.get('type', 'unknown')}",
            severity="information"
        )

    def on_deployment_completed(self, result: dict) -> None:
        """
        Handle deployment completed event

        Args:
            result: Dictionary with deployment results
        """
        self.deployment_running = False
        self.deployment_history.append(result)

        # Save session state
        self._save_session_state()

        success = result.get("success", False)
        if success:
            self.notify(
                f"Deployment completed successfully",
                severity="success",
                timeout=5
            )
        else:
            self.notify(
                f"Deployment failed: {result.get('error', 'Unknown error')}",
                severity="error",
                timeout=10
            )

        # Update subtitle
        self.sub_title = f"Profile: {self.selected_profile or 'None'}"

    def on_confirmation_dialog_confirmed(self, message: ConfirmationDialog.Confirmed) -> None:
        """Handle confirmation dialog confirmations from anywhere in the app."""
        intent = (message.data or {}).get("intent")
        if intent == "quit":
            self.exit()

    def on_confirmation_dialog_cancelled(self, message: ConfirmationDialog.Cancelled) -> None:
        """Handle confirmation dialog cancellations (no-op)."""
        pass

    def _load_session_state(self) -> None:
        """Load last session state from disk"""
        session_file = Path.home() / ".config" / "management-tui" / "session.json"
        if session_file.exists():
            try:
                import json
                with open(session_file) as f:
                    state = json.load(f)
                    self.selected_profile = state.get("selected_profile")
                    self.current_theme = state.get("theme", "dark")
                    self.deployment_history = state.get("history", [])
            except Exception as e:
                self.notify(f"Could not load session: {e}", severity="warning")

    def _save_session_state(self) -> None:
        """Save current session state to disk"""
        session_file = Path.home() / ".config" / "management-tui" / "session.json"
        session_file.parent.mkdir(parents=True, exist_ok=True)

        try:
            import json
            state = {
                "selected_profile": self.selected_profile,
                "theme": self.current_theme,
                "history": self.deployment_history[-10:]  # Keep last 10
            }
            with open(session_file, "w") as f:
                json.dump(state, f, indent=2)
        except Exception as e:
            self.notify(f"Could not save session: {e}", severity="warning")


def main():
    """Main entry point for the TUI application"""
    app = ManagementTUI()
    app.run()


if __name__ == "__main__":
    main()
