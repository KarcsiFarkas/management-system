"""
Log Viewer Widget

Real-time log display with filtering, search, and auto-scroll.
"""

from __future__ import annotations

from collections import deque
from typing import Optional

from rich.text import Text
from textual.app import ComposeResult
from textual.containers import VerticalScroll
from textual.widgets import Static, Label
from textual.reactive import reactive

from utils.formatters import colorize_log_line


class LogViewer(VerticalScroll):
    """
    Widget for displaying and managing logs with advanced features:
    - Auto-scroll (follow mode)
    - Search and filtering
    - Color-coded log levels
    - Line numbers
    - Max lines limit
    """

    DEFAULT_CSS = """
    LogViewer {
        border: solid $primary;
        background: $surface;
        height: 1fr;
        padding: 1;
    }

    LogViewer .log-line {
        width: 100%;
        height: auto;
    }

    LogViewer .log-header {
        color: $primary;
        text-style: bold;
        padding: 0 0 1 0;
    }
    """

    follow_mode = reactive(True)
    filter_text = reactive("")

    def __init__(
        self,
        *,
        title: str = "Logs",
        max_lines: int = 1000,
        show_line_numbers: bool = False,
        **kwargs,
    ):
        super().__init__(**kwargs)
        self.title = title
        self.max_lines = max_lines
        self.show_line_numbers = show_line_numbers
        self.log_lines: deque[str] = deque(maxlen=max_lines)
        self.line_widgets: list[Static] = []

    def compose(self) -> ComposeResult:
        """Compose the log viewer."""
        yield Label(self.title, classes="log-header")

    def add_line(self, line: str) -> None:
        """Add a new log line."""
        # Store the line
        self.log_lines.append(line)

        # Create widget for the line
        if self.show_line_numbers:
            line_num = len(self.log_lines)
            display_text = f"{line_num:6d} | {line}"
        else:
            display_text = line

        # Apply coloring
        colored_line = colorize_log_line(display_text)

        # Create and add widget
        line_widget = Static(colored_line, classes="log-line")
        self.mount(line_widget)
        self.line_widgets.append(line_widget)

        # Manage max lines
        if len(self.line_widgets) > self.max_lines:
            old_widget = self.line_widgets.pop(0)
            old_widget.remove()

        # Auto-scroll if follow mode is enabled
        if self.follow_mode:
            self.scroll_end(animate=False)

    def add_lines(self, lines: list[str]) -> None:
        """Add multiple log lines at once."""
        for line in lines:
            self.add_line(line)

    def clear(self) -> None:
        """Clear all log lines."""
        self.log_lines.clear()

        # Remove all line widgets
        for widget in self.line_widgets:
            widget.remove()

        self.line_widgets.clear()

    def toggle_follow(self) -> None:
        """Toggle follow mode."""
        self.follow_mode = not self.follow_mode

    def set_filter(self, filter_text: str) -> None:
        """Set filter text and update display."""
        self.filter_text = filter_text.lower()
        self._refresh_display()

    def _refresh_display(self) -> None:
        """Refresh the display based on current filter."""
        # Remove all current widgets
        for widget in self.line_widgets:
            widget.remove()
        self.line_widgets.clear()

        # Re-add filtered lines
        for idx, line in enumerate(self.log_lines):
            # Apply filter
            if self.filter_text and self.filter_text not in line.lower():
                continue

            # Format line
            if self.show_line_numbers:
                display_text = f"{idx+1:6d} | {line}"
            else:
                display_text = line

            colored_line = colorize_log_line(display_text)

            # Create and add widget
            line_widget = Static(colored_line, classes="log-line")
            self.mount(line_widget)
            self.line_widgets.append(line_widget)

    def export_logs(self, file_path: str) -> bool:
        """Export logs to a file."""
        try:
            with open(file_path, "w", encoding="utf-8") as f:
                for line in self.log_lines:
                    f.write(line + "\n")
            return True
        except Exception:
            return False

    def get_lines(self) -> list[str]:
        """Get all log lines as a list."""
        return list(self.log_lines)

    def search(self, query: str) -> int:
        """Search for text in logs and return match count."""
        query_lower = query.lower()
        count = sum(1 for line in self.log_lines if query_lower in line.lower())
        return count

    def toggle_line_numbers(self) -> None:
        """Toggle display of line numbers."""
        self.show_line_numbers = not self.show_line_numbers
        self._refresh_display()
