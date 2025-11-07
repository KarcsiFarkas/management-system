"""
Keybindings and Vim Motions Module

Comprehensive keyboard shortcut system with vim-style navigation:
- hjkl motion keys
- gg/G for top/bottom
- / for search/filter
- : for command mode
- ? for help
- Standard shortcuts (Ctrl+c, Escape, etc.)

All keybindings are configurable and context-aware.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Callable


@dataclass
class Keybinding:
    """Represents a single keybinding."""

    key: str
    description: str
    action: str
    context: str = "global"  # "global", "list", "deployment", "logs", etc.


# ---------- Global Keybindings ----------

GLOBAL_BINDINGS = [
    Keybinding("q", "Quit current screen or app", "quit", "global"),
    Keybinding("ctrl+c", "Force quit application", "force_quit", "global"),
    Keybinding("escape", "Cancel/go back", "cancel", "global"),
    Keybinding("?", "Show help screen", "show_help", "global"),
    Keybinding(":", "Open command palette", "command_palette", "global"),
    Keybinding("ctrl+p", "Open command palette (alt)", "command_palette", "global"),
    Keybinding("ctrl+r", "Refresh current view", "refresh", "global"),
    Keybinding("tab", "Switch focus to next element", "focus_next", "global"),
    Keybinding("shift+tab", "Switch focus to previous element", "focus_previous", "global"),
]


# ---------- Navigation Keybindings (Vim-style) ----------

NAVIGATION_BINDINGS = [
    Keybinding("j", "Move down", "move_down", "navigation"),
    Keybinding("k", "Move up", "move_up", "navigation"),
    Keybinding("h", "Move left / go back", "move_left", "navigation"),
    Keybinding("l", "Move right / select", "move_right", "navigation"),
    Keybinding("g", "Go to top (press gg)", "go_to_top", "navigation"),
    Keybinding("G", "Go to bottom", "go_to_bottom", "navigation"),
    Keybinding("ctrl+d", "Scroll down half page", "scroll_page_down", "navigation"),
    Keybinding("ctrl+u", "Scroll up half page", "scroll_page_up", "navigation"),
    Keybinding("ctrl+f", "Scroll down full page", "scroll_full_page_down", "navigation"),
    Keybinding("ctrl+b", "Scroll up full page", "scroll_full_page_up", "navigation"),
    Keybinding("down", "Move down (arrow key)", "move_down", "navigation"),
    Keybinding("up", "Move up (arrow key)", "move_up", "navigation"),
    Keybinding("left", "Move left (arrow key)", "move_left", "navigation"),
    Keybinding("right", "Move right (arrow key)", "move_right", "navigation"),
]


# ---------- Selection Keybindings ----------

SELECTION_BINDINGS = [
    Keybinding("enter", "Select/execute item", "select", "selection"),
    Keybinding("space", "Toggle selection", "toggle_select", "selection"),
    Keybinding("a", "Select all", "select_all", "selection"),
    Keybinding("A", "Deselect all", "deselect_all", "selection"),
    Keybinding("v", "Toggle visual selection mode", "visual_mode", "selection"),
]


# ---------- Search and Filter Keybindings ----------

SEARCH_BINDINGS = [
    Keybinding("/", "Search/filter", "search", "search"),
    Keybinding("n", "Next search result", "search_next", "search"),
    Keybinding("N", "Previous search result", "search_previous", "search"),
    Keybinding("ctrl+f", "Find in current view", "find", "search"),
    Keybinding("*", "Search for word under cursor", "search_current", "search"),
]


# ---------- Dashboard Keybindings ----------

DASHBOARD_BINDINGS = [
    Keybinding("d", "Go to deployment screen", "goto_deployment", "dashboard"),
    Keybinding("l", "View logs", "goto_logs", "dashboard"),
    Keybinding("c", "Edit configuration", "goto_config", "dashboard"),
    Keybinding("h", "View deployment history", "goto_history", "dashboard"),
    Keybinding("t", "Change theme", "change_theme", "dashboard"),
    Keybinding("s", "View system status", "goto_status", "dashboard"),
]


# ---------- Deployment Keybindings ----------

DEPLOYMENT_BINDINGS = [
    Keybinding("r", "Run deployment", "run_deployment", "deployment"),
    Keybinding("p", "Plan only (dry run)", "plan_deployment", "deployment"),
    Keybinding("s", "Stop deployment", "stop_deployment", "deployment"),
    Keybinding("x", "Cancel deployment", "cancel_deployment", "deployment"),
    Keybinding("e", "Edit deployment settings", "edit_settings", "deployment"),
    Keybinding("ctrl+t", "Select targets", "select_targets", "deployment"),
    Keybinding("ctrl+h", "Select hosts", "select_hosts", "deployment"),
    Keybinding("ctrl+s", "Save deployment profile", "save_profile", "deployment"),
    Keybinding("ctrl+l", "Load deployment profile", "load_profile", "deployment"),
]


# ---------- Log Viewer Keybindings ----------

LOG_BINDINGS = [
    Keybinding("f", "Follow logs (tail -f)", "follow_logs", "logs"),
    Keybinding("c", "Clear log buffer", "clear_logs", "logs"),
    Keybinding("e", "Export logs to file", "export_logs", "logs"),
    Keybinding("w", "Toggle word wrap", "toggle_wrap", "logs"),
    Keybinding("ctrl+l", "Filter by log level", "filter_level", "logs"),
    Keybinding("ctrl+h", "Filter by host", "filter_host", "logs"),
    Keybinding("1", "Show only errors", "show_errors", "logs"),
    Keybinding("2", "Show warnings and errors", "show_warnings", "logs"),
    Keybinding("3", "Show info and above", "show_info", "logs"),
    Keybinding("4", "Show debug (all)", "show_debug", "logs"),
]


# ---------- Config Editor Keybindings ----------

CONFIG_BINDINGS = [
    Keybinding("ctrl+s", "Save configuration", "save_config", "config"),
    Keybinding("ctrl+x", "Save and exit", "save_exit", "config"),
    Keybinding("ctrl+z", "Undo", "undo", "config"),
    Keybinding("ctrl+y", "Redo", "redo", "config"),
    Keybinding("ctrl+f", "Find in config", "find_config", "config"),
    Keybinding("ctrl+h", "Find and replace", "replace_config", "config"),
    Keybinding("ctrl+v", "Validate configuration", "validate_config", "config"),
]


# ---------- All Keybindings ----------

ALL_BINDINGS = (
    GLOBAL_BINDINGS
    + NAVIGATION_BINDINGS
    + SELECTION_BINDINGS
    + SEARCH_BINDINGS
    + DASHBOARD_BINDINGS
    + DEPLOYMENT_BINDINGS
    + LOG_BINDINGS
    + CONFIG_BINDINGS
)


# ---------- Keybinding Utilities ----------

def get_bindings_by_context(context: str) -> list[Keybinding]:
    """Get all keybindings for a specific context."""
    return [b for b in ALL_BINDINGS if b.context == context or b.context == "global"]


def get_binding_by_key(key: str, context: str = "global") -> Keybinding | None:
    """Find a keybinding by key and context."""
    for binding in ALL_BINDINGS:
        if binding.key == key and (binding.context == context or binding.context == "global"):
            return binding
    return None


def format_keybindings_help(context: str = "global") -> str:
    """Format keybindings as help text."""
    bindings = get_bindings_by_context(context)

    if not bindings:
        return "No keybindings available for this context."

    # Group by context
    contexts: dict[str, list[Keybinding]] = {}
    for binding in bindings:
        ctx = binding.context
        if ctx not in contexts:
            contexts[ctx] = []
        contexts[ctx].append(binding)

    # Format output
    output = []
    for ctx, ctx_bindings in sorted(contexts.items()):
        ctx_title = ctx.replace("_", " ").title()
        output.append(f"\n{ctx_title} Keybindings:")
        output.append("-" * 50)

        # Find max key length for alignment
        max_key_len = max(len(b.key) for b in ctx_bindings)

        for binding in ctx_bindings:
            key_display = binding.key.ljust(max_key_len)
            output.append(f"  {key_display}  {binding.description}")

    return "\n".join(output)


def get_status_bar_hints(context: str = "global") -> list[tuple[str, str]]:
    """Get key hints for status bar display.

    Returns:
        List of (key, description) tuples for the most important keys
    """
    important_keys = {
        "global": [
            ("?", "Help"),
            (":", "Command"),
            ("q", "Quit"),
        ],
        "dashboard": [
            ("d", "Deploy"),
            ("l", "Logs"),
            ("h", "History"),
            ("?", "Help"),
        ],
        "deployment": [
            ("r", "Run"),
            ("p", "Plan"),
            ("s", "Stop"),
            ("q", "Back"),
        ],
        "logs": [
            ("f", "Follow"),
            ("/", "Search"),
            ("c", "Clear"),
            ("q", "Back"),
        ],
        "navigation": [
            ("j/k", "Up/Down"),
            ("g/G", "Top/Bottom"),
            ("enter", "Select"),
        ],
    }

    return important_keys.get(context, important_keys["global"])


# ---------- Vim Command Mode ----------

class VimCommand:
    """Vim-style command parser and executor."""

    def __init__(self):
        self.command_history: list[str] = []
        self.history_index = -1

    def parse_command(self, cmd: str) -> tuple[str, list[str], dict[str, str]]:
        """Parse a vim-style command into action, args, and options.

        Examples:
            :q -> ("quit", [], {})
            :deploy vm1 vm2 --targets infra -> ("deploy", ["vm1", "vm2"], {"targets": "infra"})
            :set theme=monokai -> ("set", [], {"theme": "monokai"})
        """
        cmd = cmd.strip()
        if cmd.startswith(":"):
            cmd = cmd[1:]

        parts = cmd.split()
        if not parts:
            return ("", [], {})

        action = parts[0]
        args = []
        options = {}

        i = 1
        while i < len(parts):
            part = parts[i]
            if part.startswith("--"):
                # Long option
                key = part[2:]
                if "=" in key:
                    k, v = key.split("=", 1)
                    options[k] = v
                elif i + 1 < len(parts) and not parts[i + 1].startswith("-"):
                    options[key] = parts[i + 1]
                    i += 1
                else:
                    options[key] = "true"
            elif "=" in part:
                # Key=value format
                k, v = part.split("=", 1)
                options[k] = v
            else:
                # Regular argument
                args.append(part)
            i += 1

        return (action, args, options)

    def add_to_history(self, cmd: str) -> None:
        """Add command to history."""
        if cmd and (not self.command_history or self.command_history[-1] != cmd):
            self.command_history.append(cmd)
        self.history_index = len(self.command_history)

    def get_history_previous(self) -> str:
        """Get previous command from history."""
        if not self.command_history:
            return ""
        self.history_index = max(0, self.history_index - 1)
        return self.command_history[self.history_index]

    def get_history_next(self) -> str:
        """Get next command from history."""
        if not self.command_history:
            return ""
        self.history_index = min(len(self.command_history), self.history_index + 1)
        if self.history_index >= len(self.command_history):
            return ""
        return self.command_history[self.history_index]


# ---------- Command Aliases ----------

COMMAND_ALIASES = {
    "q": "quit",
    "quit": "quit",
    "exit": "quit",
    "qa": "quit_all",
    "deploy": "run_deployment",
    "run": "run_deployment",
    "stop": "stop_deployment",
    "cancel": "cancel_deployment",
    "logs": "goto_logs",
    "log": "goto_logs",
    "config": "goto_config",
    "cfg": "goto_config",
    "history": "goto_history",
    "hist": "goto_history",
    "help": "show_help",
    "h": "show_help",
    "theme": "change_theme",
    "set": "set_option",
    "refresh": "refresh",
    "r": "refresh",
}


def resolve_command_alias(cmd: str) -> str:
    """Resolve command alias to actual action."""
    return COMMAND_ALIASES.get(cmd, cmd)


# ---------- KeyBindings Manager ----------

class KeyBindings:
    """
    Central keyboard binding management system.

    Provides a unified interface for accessing and managing all keybindings
    across different contexts in the application.
    """

    def __init__(self):
        """Initialize KeyBindings manager with all binding collections."""
        self.global_bindings = GLOBAL_BINDINGS
        self.navigation_bindings = NAVIGATION_BINDINGS
        self.selection_bindings = SELECTION_BINDINGS
        self.search_bindings = SEARCH_BINDINGS
        self.dashboard_bindings = DASHBOARD_BINDINGS
        self.deployment_bindings = DEPLOYMENT_BINDINGS
        self.log_bindings = LOG_BINDINGS
        self.config_bindings = CONFIG_BINDINGS
        self.all_bindings = ALL_BINDINGS

        # Vim command parser
        self.vim_command = VimCommand()

    def get_bindings_for_context(self, context: str) -> list[Keybinding]:
        """
        Get all keybindings for a specific context.

        Args:
            context: Context name (e.g., 'dashboard', 'logs', 'deployment')

        Returns:
            List of Keybinding objects for the context
        """
        return get_bindings_by_context(context)

    def get_binding(self, key: str, context: str = "global") -> Keybinding | None:
        """
        Find a keybinding by key and context.

        Args:
            key: The key to look up
            context: Context to search in (defaults to 'global')

        Returns:
            Keybinding object if found, None otherwise
        """
        return get_binding_by_key(key, context)

    def format_help(self, context: str = "global") -> str:
        """
        Format keybindings as help text.

        Args:
            context: Context to format help for

        Returns:
            Formatted help text string
        """
        return format_keybindings_help(context)

    def get_status_hints(self, context: str = "global") -> list[tuple[str, str]]:
        """
        Get key hints for status bar display.

        Args:
            context: Context to get hints for

        Returns:
            List of (key, description) tuples
        """
        return get_status_bar_hints(context)

    def parse_command(self, cmd: str) -> tuple[str, list[str], dict[str, str]]:
        """
        Parse a vim-style command.

        Args:
            cmd: Command string (e.g., ':deploy vm1 vm2')

        Returns:
            Tuple of (action, args, options)
        """
        return self.vim_command.parse_command(cmd)

    def resolve_alias(self, cmd: str) -> str:
        """
        Resolve command alias to actual action.

        Args:
            cmd: Command or alias

        Returns:
            Resolved action name
        """
        return resolve_command_alias(cmd)
