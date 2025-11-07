"""
Confirmation Dialog Widget

Modal dialog for confirming destructive actions.
"""

from __future__ import annotations

from textual.app import ComposeResult
from textual.containers import Container, Horizontal, Vertical
from textual.widgets import Button, Label, Static
from textual.message import Message


class ConfirmationDialog(Container):
    """
    Modal confirmation dialog.

    Usage:
        dialog = ConfirmationDialog(
            title="Confirm Deployment",
            message="Deploy to 3 VMs?",
            confirm_text="Deploy",
            cancel_text="Cancel"
        )
    """

    DEFAULT_CSS = """
    ConfirmationDialog {
        align: center middle;
        width: 60;
        height: auto;
        background: $surface;
        border: thick $primary;
        padding: 2;
    }

    ConfirmationDialog .dialog-title {
        width: 100%;
        text-align: center;
        color: $primary;
        text-style: bold;
        padding: 0 0 1 0;
    }

    ConfirmationDialog .dialog-message {
        width: 100%;
        text-align: center;
        padding: 1 0;
    }

    ConfirmationDialog .dialog-buttons {
        width: 100%;
        height: auto;
        align: center middle;
        padding: 1 0 0 0;
    }

    ConfirmationDialog Button {
        margin: 0 1;
    }
    """

    class Confirmed(Message):
        """Message sent when user confirms."""

        def __init__(self, data: dict | None = None):
            super().__init__()
            self.data = data or {}

    class Cancelled(Message):
        """Message sent when user cancels."""
        pass

    def __init__(
        self,
        *,
        title: str = "Confirm Action",
        message: str = "Are you sure?",
        confirm_text: str = "Confirm",
        cancel_text: str = "Cancel",
        confirm_variant: str = "primary",
        data: dict | None = None,
        **kwargs,
    ):
        super().__init__(**kwargs)
        self.title = title
        self.message = message
        self.confirm_text = confirm_text
        self.cancel_text = cancel_text
        self.confirm_variant = confirm_variant
        self.data = data or {}

    def compose(self) -> ComposeResult:
        """Compose the confirmation dialog."""
        with Vertical():
            yield Label(self.title, classes="dialog-title")
            yield Label(self.message, classes="dialog-message")
            with Horizontal(classes="dialog-buttons"):
                yield Button(self.confirm_text, id="confirm-btn", variant=self.confirm_variant)
                yield Button(self.cancel_text, id="cancel-btn")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses."""
        if event.button.id == "confirm-btn":
            self.post_message(self.Confirmed(self.data))
        else:
            self.post_message(self.Cancelled())

        # Remove the dialog
        self.remove()

    def on_key(self, event) -> None:
        """Handle keyboard shortcuts."""
        if event.key == "escape":
            self.post_message(self.Cancelled())
            self.remove()
            event.stop()
        elif event.key == "enter":
            self.post_message(self.Confirmed(self.data))
            self.remove()
            event.stop()
