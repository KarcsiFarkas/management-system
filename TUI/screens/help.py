"""
Help Screen

Displays comprehensive help including keybindings, usage, and tips.
"""

from __future__ import annotations

from textual.app import ComposeResult
from textual.containers import VerticalScroll, Container
from textual.screen import Screen
from textual.widgets import Header, Footer, Static, Markdown

from keybindings import format_keybindings_help


HELP_CONTENT = """
# Provision TUI Manager - Help

## Overview

The Provision TUI Manager is a terminal-based interface for orchestrating
multi-tenant VM deployments using the provision.py script.

## Quick Start

1. **Launch the TUI**: Run `python main.py` from the TUI directory
2. **Navigate**: Use vim-style keys (j/k/h/l) or arrow keys
3. **Deploy**: Press `d` from the dashboard, select VMs, configure targets, and run
4. **View Logs**: Press `l` to see real-time deployment logs
5. **Help**: Press `?` anytime to see this help screen

## Navigation

### Vim Motions
- **j/k**: Move down/up
- **h/l**: Move left/right or go back/select
- **gg**: Go to top (press g twice)
- **G**: Go to bottom
- **Ctrl+d/u**: Scroll half page down/up
- **Ctrl+f/b**: Scroll full page down/up

### Arrow Keys
Standard arrow key navigation is also supported.

## Global Shortcuts

- **q**: Quit current screen or application
- **Ctrl+c**: Force quit application
- **Escape**: Cancel action or go back
- **?**: Show this help screen
- **:**: Open command palette (vim-style)
- **Ctrl+p**: Open command palette (alternate)
- **Ctrl+r**: Refresh current view
- **Tab/Shift+Tab**: Switch focus between elements

## Dashboard Shortcuts

- **d**: Go to deployment screen
- **l**: View logs
- **h**: View deployment history
- **c**: Edit configuration
- **t**: Change theme
- **s**: View system status

## Deployment Shortcuts

- **r**: Run deployment
- **p**: Plan only (dry run)
- **s**: Stop deployment
- **x**: Cancel deployment
- **a**: Select all VMs
- **A**: Deselect all VMs
- **Space**: Toggle selection of current VM
- **Enter**: Confirm and execute

## Log Viewer Shortcuts

- **f**: Toggle follow mode (auto-scroll)
- **/**: Search/filter logs
- **n/N**: Next/previous search result
- **c**: Clear log buffer
- **e**: Export logs to file
- **w**: Toggle word wrap
- **1**: Show only errors
- **2**: Show warnings and errors
- **3**: Show info and above
- **4**: Show all logs (debug included)

## Command Palette

Access the command palette with `:` or `Ctrl+p`, then type commands:

- `:quit` or `:q` - Quit application
- `:deploy vm1 vm2` - Deploy specific VMs
- `:logs` - Show logs
- `:config` - Edit configuration
- `:set theme=monokai` - Change theme
- `:help` - Show this help

## Deployment Workflow

1. **Select VMs**: Check the boxes next to VMs you want to deploy
2. **Configure Targets**: Choose deployment stages:
   - Infrastructure (Terraform)
   - PXE Setup (for bare metal)
   - OS Installation (Ansible)
   - Post-Configuration (hardening, services)
3. **Set Options**: Enable plan-only or debug mode if needed
4. **Run**: Press `r` or click "Run Deployment"
5. **Monitor**: Watch real-time logs and status updates
6. **Complete**: Review deployment results and history

## Configuration Files

The TUI uses these configuration files:

- `configs/defaults.yaml` - Default settings and provider config
- `configs/vm_specs.yaml` - VM definitions
- `configs/install_config.yaml` - OS installation configuration
- `tui_config.yaml` - TUI-specific settings and preferences

## Themes

Available themes:
- **monokai** (default) - Dark theme with vibrant colors
- **gruvbox** - Warm retro dark theme
- **nord** - Cool Arctic-inspired dark theme
- **solarized-dark** - Popular dark theme
- **dracula** - Dark theme with purple accents
- **github-light** - Clean light theme
- **solarized-light** - Light variant of Solarized

Change theme: `:set theme=<theme_name>`

## Tips & Tricks

- **Fast Navigation**: Use vim motions for quick navigation
- **Multi-Select**: Use Space to toggle individual VMs, `a` to select all
- **Follow Logs**: Enable follow mode (`f`) to auto-scroll logs
- **Export Logs**: Save deployment logs with `e` in log viewer
- **Plan First**: Use plan-only mode to preview changes
- **Debug Mode**: Enable debug for verbose output
- **Command History**: Use up/down arrows in command palette for history

## Troubleshooting

### TUI won't start
- Ensure Python 3.10+ is installed
- Install dependencies: `pip install -r requirements.txt`
- Check terminal supports UTF-8 and colors

### Deployment fails
- Check configuration files are valid
- Verify Proxmox API credentials in environment
- Enable debug mode for detailed error messages
- Review logs in log viewer

### VMs not showing
- Verify `configs/vm_specs.yaml` exists and is valid
- Check file permissions
- Reload configuration with `Ctrl+r`

## Support & Documentation

- **Project**: management-system/TUI/
- **Main Script**: OS_install/provision.py
- **Logs**: TUI/logs/
- **Config**: TUI/tui_config.yaml

For more information, see the full README.md in the TUI directory.

---

Press `q` to close this help screen.
"""


class HelpScreen(Screen):
    """
    Help and documentation screen.

    Displays:
    - Keyboard shortcuts
    - Usage guide
    - Tips and tricks
    - Troubleshooting
    """

    BINDINGS = [
        ("q", "back", "Back"),
        ("escape", "back", "Back"),
    ]

    DEFAULT_CSS = """
    HelpScreen {
        background: $background;
    }

    HelpScreen VerticalScroll {
        padding: 2;
    }

    HelpScreen Markdown {
        padding: 1;
    }
    """

    def compose(self) -> ComposeResult:
        """Compose the help screen."""
        yield Header()

        with VerticalScroll():
            yield Markdown(HELP_CONTENT)

        yield Footer()

    def action_back(self) -> None:
        """Go back to previous screen."""
        self.app.pop_screen()
