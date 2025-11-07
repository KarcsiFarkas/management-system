"""
Command Palette Widget

Vim-style command interface for quick actions.
"""

from __future__ import annotations

from textual.app import ComposeResult
from textual.containers import Container
from textual.widgets import Input, Label
from textual.message import Message

from keybindings import VimCommand, resolve_command_alias


class CommandPalette(Container):
    """
    Command palette for vim-style command execution.

    Usage:
        :quit - Quit application
        :deploy vm1 vm2 - Deploy specific VMs
        :logs - Show logs
        :set theme=monokai - Change theme
    """

    DEFAULT_CSS = """
    CommandPalette {
        height: 3;
        dock: bottom;
        background: $panel;
        border-top: solid $primary;
    }

    CommandPalette Input {
        border: none;
        background: $surface;
        padding: 0 1;
    }

    CommandPalette Label {
        padding: 0 1;
        color: $text-muted;
    }
    """

    class CommandSubmitted(Message):
        """Message sent when a command is submitted."""

        def __init__(self, action: str, args: list[str], options: dict[str, str]):
            super().__init__()
            self.action = action
            self.args = args
            self.options = options

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.vim_command = VimCommand()
        self.visible = False

    def compose(self) -> ComposeResult:
        """Compose the command palette."""
        yield Label("Command:", classes="command-label")
        yield Input(
            placeholder="Enter command (e.g., :quit, :deploy vm1)",
            id="command-input",
        )

    def show_palette(self) -> None:
        """Show the command palette."""
        self.visible = True
        self.styles.display = "block"
        input_widget = self.query_one("#command-input", Input)
        input_widget.value = ":"
        input_widget.focus()

    def hide_palette(self) -> None:
        """Hide the command palette."""
        self.visible = False
        self.styles.display = "none"
        input_widget = self.query_one("#command-input", Input)
        input_widget.value = ""

    def on_input_submitted(self, event: Input.Submitted) -> None:
        """Handle command submission."""
        command = event.value.strip()

        if not command:
            self.hide_palette()
            return

        # Parse command
        action, args, options = self.vim_command.parse_command(command)

        if not action:
            self.hide_palette()
            return

        # Add to history
        self.vim_command.add_to_history(command)

        # Resolve aliases
        action = resolve_command_alias(action)

        # Send message to app
        self.post_message(self.CommandSubmitted(action, args, options))

        # Hide palette
        self.hide_palette()

    def on_key(self, event) -> None:
        """Handle keyboard events."""
        if event.key == "escape":
            self.hide_palette()
            event.stop()
        elif event.key == "up":
            # Show previous command from history
            prev_cmd = self.vim_command.get_history_previous()
            if prev_cmd:
                input_widget = self.query_one("#command-input", Input)
                input_widget.value = prev_cmd
            event.stop()
        elif event.key == "down":
            # Show next command from history
            next_cmd = self.vim_command.get_history_next()
            if next_cmd:
                input_widget = self.query_one("#command-input", Input)
                input_widget.value = next_cmd
            event.stop()
