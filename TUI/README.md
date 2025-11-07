# Management System TUI

A modern, feature-rich Terminal User Interface for managing multi-tenant Docker and NixOS deployments, user provisioning, and profile management.

![Management System TUI](https://img.shields.io/badge/TUI-Textual-brightgreen) ![Python](https://img.shields.io/badge/python-3.10+-blue) ![Status](https://img.shields.io/badge/status-production-success)

---

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Screenshots](#screenshots)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage Guide](#usage-guide)
  - [Main Dashboard](#main-dashboard)
  - [Deployment Workflow](#deployment-workflow)
  - [Profile Management](#profile-management)
  - [Log Viewer](#log-viewer)
  - [Command Palette](#command-palette)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Configuration](#configuration)
- [Themes](#themes)
- [Architecture](#architecture)
- [Advanced Features](#advanced-features)
- [Troubleshooting](#troubleshooting)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

---

## 🌟 Overview

The **Management System TUI** provides a unified, keyboard-driven interface for managing complex deployment operations across multiple tenants and environments. Built with [Textual](https://github.com/Textualize/textual), it brings modern terminal UI conventions to DevOps workflows.

### What Can You Do?

- 🚀 **Deploy Services**: Execute Docker Compose and NixOS deployments with live progress monitoring
- 👥 **Manage Profiles**: Create, switch, and configure multi-tenant Git branch-based profiles
- 📦 **Provision Users**: Automate user creation across multiple self-hosted services
- 📊 **Monitor Deployments**: Real-time log streaming and status tracking
- ⌨️  **Vi/Vim Motions**: Navigate efficiently with hjkl and other vim-style keybindings
- 🎨 **Multiple Themes**: Choose from dark and light themes with CSS-like customization
- 🔍 **Search & Filter**: Powerful search across logs, deployments, and configurations

---

## ✨ Features

### Core Functionality

#### Deployment Management
- **Multi-Variant Deployments**: Support for 8+ deployment script variants
  - `deploy-docker.sh` - Basic Docker Compose deployment
  - `deploy-docker-with-ldap-sso.sh` - Docker with LDAP SSO integration
  - `deploy-docker-with-users.sh` - Docker with automated user provisioning
  - `deploy-docker-with-vaultwarden.sh` - Docker with Vaultwarden password management
  - `deploy-nix.sh` - Basic NixOS deployment
  - `deploy-nix-with-ldap-sso.sh` - NixOS with LDAP SSO
  - `deploy-nix-with-users.sh` - NixOS with user provisioning
  - `deploy-nix-with-vaultwarden.sh` - NixOS with Vaultwarden

- **Real-time Progress**: Live deployment monitoring with:
  - Progress bars and spinners
  - Stage-by-stage status updates
  - Elapsed time tracking
  - Resource usage monitoring

- **Deployment History**: Track and review past deployments
  - Success/failure statistics
  - Duration tracking
  - Error logs
  - Quick re-run from history

#### Profile & Tenant Management
- **Git Branch-Based Profiles**: Each tenant gets a dedicated Git branch
- **Interactive Profile Creation**: Wizard-style profile setup
- **Service Selection**: Toggle individual services on/off per profile
- **Configuration Editor**: Built-in YAML/ENV file editing
- **Profile Switching**: Quick profile context switching
- **Bulk Operations**: Deploy to multiple profiles simultaneously

#### User Provisioning
- **Automated User Creation**: Create users across multiple services in one operation
- **Service Integration**: Support for:
  - Nextcloud (Files & Collaboration)
  - GitLab (Git Repository)
  - Jellyfin (Media Server)
  - Vaultwarden (Password Manager)
  - LDAP (Directory Services)
  - Homepage (Dashboard)

- **Password Management**:
  - Generate secure passwords
  - Store in Vaultwarden
  - LDAP integration

#### Monitoring & Logging
- **Live Log Streaming**: Real-time log output from deployments
- **Log Filtering**: Search and filter logs by:
  - Text content
  - Log level (ERROR, WARNING, INFO)
  - Time range
  - Service name

- **Log History**: Persistent storage of deployment logs
- **Export Logs**: Save logs to file for troubleshooting
- **Syntax Highlighting**: Colorized output for better readability

### UI/UX Features

#### Vim-Style Navigation
- **hjkl Movement**: Navigate up/down/left/right
- **gg/G**: Jump to top/bottom
- **w/b**: Word-wise navigation
- **/**: Search mode
- **:**: Command mode
- **Esc**: Cancel/go back
- **Ctrl+[**: Alternative escape

#### Modern Terminal UI
- **Responsive Layout**: Adapts to terminal size
- **Mouse Support**: Click buttons, scroll logs (optional)
- **Keyboard Focus**: Always keyboard-accessible
- **Clear Visual Hierarchy**: Organized panels and sections
- **Status Indicators**: Visual feedback for all actions
- **Notifications**: Toast messages for important events

#### Command Palette
- **Quick Actions**: `Ctrl+P` to access all commands
- **Fuzzy Search**: Find commands by typing partial names
- **Keyboard-Driven**: Execute any action without leaving keyboard
- **Recent Commands**: Quick access to frequently used actions

#### Theme System
- **Multiple Themes**: Dark and light theme variants
- **Live Theme Switching**: Change themes without restart
- **Custom Themes**: Create your own color schemes
- **CSS-Like Styling**: Familiar styling language

---

## 📸 Screenshots

### Main Dashboard
```
┌─────────────────────────────────────────────────────────────────┐
│ Management System TUI                            Profile: alice  │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─ Quick Actions ────────┐  ┌─ Recent Deployments ──────────┐ │
│  │                         │  │                                │ │
│  │  [Deploy Docker]        │  │  ✓ alice (docker-with-users)  │ │
│  │  [Deploy NixOS ]        │  │    2 min ago                   │ │
│  │  [Provision Users]      │  │                                │ │
│  │  [View Logs    ]        │  │  ✗ bob (nix-with-ldap)         │ │
│  │                         │  │    1 hour ago                  │ │
│  └─────────────────────────┘  └────────────────────────────────┘ │
│                                                                   │
│  ┌─ System Status ─────────┐  ┌─ Active Profiles ─────────────┐ │
│  │                         │  │                                │ │
│  │  Services:  12 running  │  │  • alice  (docker)             │ │
│  │  CPU:       45%         │  │  • bob    (nix)                │ │
│  │  Memory:    8.2 / 16 GB │  │  • company (docker-vaultwarden)│ │
│  │  Disk:      125 / 500GB │  │                                │ │
│  └─────────────────────────┘  └────────────────────────────────┘ │
│                                                                   │
├─────────────────────────────────────────────────────────────────┤
│ q:Quit  d:Dashboard  l:Logs  ?:Help  Ctrl+T:Theme  Ctrl+P:Cmd   │
└─────────────────────────────────────────────────────────────────┘
```

### Deployment Screen
```
┌─────────────────────────────────────────────────────────────────┐
│ Deployment Configuration                                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Deployment Type:  [Docker ▼]                                    │
│  Variant:          [with-users ▼]                                │
│  Profile:          [alice ▼]                                     │
│                                                                   │
│  Services:                                                        │
│    ☑ Nextcloud     ☑ GitLab      ☑ Jellyfin                      │
│    ☑ Vaultwarden   ☐ LDAP        ☑ Homepage                      │
│                                                                   │
│  [Start Deployment]  [Cancel]                                    │
│                                                                   │
│─────────────────────────────────────────────────────────────────│
│                                                                   │
│  Deployment Progress:                                             │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 75%             │
│                                                                   │
│  Stage: Provisioning services [3/4]                              │
│  Status: Creating Nextcloud users...                             │
│  Elapsed: 2m 15s                                                 │
│                                                                   │
│  Recent Output:                                                   │
│  ✓ Docker containers started                                     │
│  ✓ Database migrations applied                                   │
│  → Creating users in Nextcloud...                                │
│    • alice@example.com created                                   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Log Viewer
```
┌─────────────────────────────────────────────────────────────────┐
│ Log Viewer                          Filter: [error________] 🔍   │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  [2025-11-06 10:23:15] INFO  Starting deployment for alice       │
│  [2025-11-06 10:23:16] INFO  Loading configuration...            │
│  [2025-11-06 10:23:17] INFO  Validating services.env             │
│  [2025-11-06 10:23:18] WARN  Nextcloud version not specified     │
│  [2025-11-06 10:23:20] INFO  Starting Docker Compose...          │
│  [2025-11-06 10:23:25] ERROR Failed to start GitLab container    │
│  [2025-11-06 10:23:25] ERROR Port 8080 already in use            │
│  [2025-11-06 10:23:26] INFO  Retrying GitLab with port 8081...   │
│  [2025-11-06 10:23:30] INFO  GitLab container started            │
│  [2025-11-06 10:23:35] INFO  All services running                │
│                                                                   │
│  ⋮ 245 more lines ⋮                                              │
│                                                                   │
├─────────────────────────────────────────────────────────────────┤
│ j/k:Scroll  /:Search  e:Export  c:Clear  Esc:Back               │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Installation

### Prerequisites

- **Python 3.10+** (3.11 recommended)
- **Git**
- **Docker** or **NixOS** (depending on deployment type)
- **Terminal** with 256-color support
- **UTF-8 locale** for proper unicode rendering

### Quick Launch Scripts

For convenience, launcher scripts are provided that handle virtual environment setup and dependencies automatically.

#### Windows (PowerShell)

```powershell
# One-time setup: Allow script execution
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Navigate to TUI directory
cd D:\path\to\management-system\TUI

# Run the launcher (handles everything automatically)
.\run.ps1

# Development mode with hot reload
.\run.ps1 -Dev
```

The PowerShell launcher (`run.ps1`) will:
- Check Python 3.10+ is installed
- Create virtual environment at project root
- Install dependencies automatically (with your permission)
- Launch the TUI

See `POWERSHELL_QUICK_START.md` for details.

#### Linux/WSL/Mac (Bash)

```bash
# Navigate to TUI directory
cd /path/to/management-system/TUI

# Run the launcher
./run.sh

# Development mode with hot reload
./run.sh --dev
```

### Manual Installation from Source

If you prefer to install manually without the launcher scripts:

1. **Clone the repository**:
   ```bash
   cd /path/to/management-system
   ```

2. **Create virtual environment** (recommended):
   ```bash
   # Create venv in project root
   python -m venv /path/to/thesis-szakdoga/.venv

   # Activate it
   # On Windows:
   .venv\Scripts\activate
   # On Linux/Mac:
   source .venv/bin/activate
   ```

3. **Install Python dependencies**:
   ```bash
   cd TUI
   pip install -r requirements.txt
   ```

4. **Verify installation**:
   ```bash
   python main.py --version
   ```

### Install as System Command (Optional)

Create a symlink to run from anywhere:

```bash
# Make executable
chmod +x /path/to/management-system/TUI/main.py

# Create symlink
sudo ln -s /path/to/management-system/TUI/main.py /usr/local/bin/management-tui

# Now you can run from anywhere
management-tui
```

### Development Installation

For development with auto-reload:

```bash
pip install -r requirements.txt

# Install development dependencies
pip install textual-dev pytest pytest-asyncio black ruff mypy

# Run in development mode
textual run --dev main.py
```

---

## ⚡ Quick Start

### First Launch

1. **Start the TUI**:
   ```bash
   cd TUI
   python main.py
   ```

2. **You'll see the main dashboard** with quick actions and system status

3. **Press `?` or `F1`** to view the help screen with all keyboard shortcuts

### Your First Deployment

1. **Press `d` or select "Deploy Docker"** from the dashboard

2. **Configure deployment**:
   - Select deployment type (docker/nix)
   - Choose variant (basic, with-users, with-ldap, with-vaultwarden)
   - Select profile (or create new)
   - Toggle services on/off

3. **Press Enter** to start deployment

4. **Monitor progress** in real-time with live log output

5. **View results** when deployment completes

### Create a New Profile

1. **Press `p` or navigate to** "Profiles" section

2. **Press `n` to create new profile**

3. **Enter profile details**:
   - Name (becomes Git branch name)
   - Domain
   - Services to enable
   - Configuration options

4. **Profile is created** as a new Git branch with configuration files

---

## 📖 Usage Guide

### Main Dashboard

The dashboard is your starting point, providing an overview of:

- **Quick Actions**: Common tasks (Deploy, Provision, Logs, Help)
- **Recent Deployments**: History of recent operations
- **System Status**: Resource usage (CPU, RAM, Disk)
- **Active Profiles**: List of configured tenant profiles

**Navigation**:
- `j/k` or `↓/↑`: Move between panels
- `h/l` or `←/→`: Switch between columns
- `Enter`: Activate selected item
- `d`: Always return to dashboard

### Deployment Workflow

#### 1. Configure Deployment

Navigate to deployment screen (`Deploy Docker` or `Deploy NixOS`):

- **Deployment Type**: Docker Compose or NixOS
- **Variant**: Choose integration level:
  - `basic`: Core services only
  - `with-users`: Includes user provisioning
  - `with-ldap-sso`: Adds LDAP SSO integration
  - `with-vaultwarden`: Adds password management

- **Profile**: Select target tenant profile
- **Services**: Toggle individual services:
  - Nextcloud (Files & Collaboration)
  - GitLab (Git Repository)
  - Jellyfin (Media Server)
  - Vaultwarden (Password Manager)
  - Homepage (Dashboard)
  - LDAP (Directory Services)

#### 2. Start Deployment

Press `Enter` or click `[Start Deployment]` button

#### 3. Monitor Progress

Watch real-time progress:
- **Progress Bar**: Overall completion percentage
- **Stage Indicator**: Current deployment stage
- **Live Logs**: Streaming output from deployment scripts
- **Status Updates**: Success/failure for each step

#### 4. Handle Completion

- **Success**: Green notification, option to view full logs
- **Failure**: Red notification with error details, retry option
- **Partial**: Yellow warning for partially successful deployments

### Profile Management

Profiles represent individual tenants/users, each with dedicated configuration.

#### Create Profile

1. Press `p` → `n` (Profiles → New)
2. Enter profile name (alphanumeric, hyphens allowed)
3. Configure domain and timezone
4. Select services to enable
5. Profile is created as Git branch with `services.env` and `config.env`

#### Switch Profile

1. Press `p` → `s` (Profiles → Switch)
2. Select from list of existing profiles
3. Current profile context changes (shown in header)

#### Edit Profile

1. Press `p` → `e` (Profiles → Edit)
2. Modify service enablement in `services.env`
3. Update configuration in `config.env`
4. Changes are committed to profile's Git branch

#### Delete Profile

1. Press `p` → `d` (Profiles → Delete)
2. Confirm deletion (requires typing profile name)
3. Git branch is deleted

### Log Viewer

Access comprehensive logging:

#### View Logs

Press `l` or select "Logs" from dashboard

#### Filter Logs

- **Search**: Press `/` and type search term
- **Level Filter**: Press `f` to filter by level (ERROR, WARNING, INFO)
- **Time Range**: Press `t` to filter by time range
- **Service Filter**: Press `s` to filter by service name

#### Export Logs

- Press `e` to export current view to file
- Choose location and filename
- Logs saved in readable format

#### Clear Logs

- Press `c` to clear current log buffer
- Historical logs remain in `TUI/logs/`

### Command Palette

Quick access to all functions:

1. **Press `Ctrl+P`** to open command palette
2. **Type command name** (fuzzy search supported)
3. **Press Enter** to execute
4. **Esc to cancel**

**Popular Commands**:
- `deploy docker` - Start Docker deployment
- `deploy nix` - Start NixOS deployment
- `provision` - Run user provisioning
- `profile new` - Create new profile
- `logs` - Open log viewer
- `theme` - Change theme
- `help` - Show help screen

---

## ⌨️  Keyboard Shortcuts

### Global Shortcuts

| Key | Action | Description |
|-----|--------|-------------|
| `?` / `F1` | Help | Show help screen with all shortcuts |
| `q` | Quit | Exit application (with confirmation) |
| `Esc` | Back | Go back / Cancel current action |
| `Ctrl+C` | Force Quit | Immediately exit application |
| `Ctrl+P` | Command Palette | Open quick command search |
| `Ctrl+T` | Toggle Theme | Switch between dark/light themes |
| `d` | Dashboard | Go to main dashboard |
| `l` | Logs | Open log viewer |

### Vim Navigation

| Key | Action | Description |
|-----|--------|-------------|
| `h` | Left | Move left / Previous panel |
| `j` | Down | Move down / Next item |
| `k` | Up | Move up / Previous item |
| `l` | Right | Move right / Next panel |
| `gg` | Top | Jump to top of list |
| `G` | Bottom | Jump to bottom of list |
| `w` | Word Forward | Move to next word |
| `b` | Word Back | Move to previous word |
| `0` | Line Start | Jump to start of line |
| `$` | Line End | Jump to end of line |
| `/` | Search | Enter search mode |
| `n` | Next Match | Go to next search result |
| `N` | Previous Match | Go to previous search result |
| `:` | Command Mode | Enter command mode |

### Dashboard Shortcuts

| Key | Action |
|-----|--------|
| `1` | Quick Action 1 (Deploy Docker) |
| `2` | Quick Action 2 (Deploy NixOS) |
| `3` | Quick Action 3 (Provision Users) |
| `4` | Quick Action 4 (View Logs) |
| `r` | Refresh Status |

### Deployment Screen

| Key | Action |
|-----|--------|
| `Tab` | Next Field |
| `Shift+Tab` | Previous Field |
| `Space` | Toggle Service |
| `Enter` | Start Deployment |
| `c` | Cancel Deployment |
| `p` | Pause/Resume |

### Log Viewer

| Key | Action |
|-----|--------|
| `j` / `↓` | Scroll Down |
| `k` / `↑` | Scroll Up |
| `Ctrl+D` | Page Down |
| `Ctrl+U` | Page Up |
| `/` | Search |
| `f` | Filter by Level |
| `t` | Filter by Time |
| `s` | Filter by Service |
| `e` | Export Logs |
| `c` | Clear Buffer |
| `r` | Refresh |

### Profile Management

| Key | Action |
|-----|--------|
| `n` | New Profile |
| `s` | Switch Profile |
| `e` | Edit Profile |
| `d` | Delete Profile |
| `l` | List All Profiles |
| `r` | Refresh Profile List |

---

## ⚙️  Configuration

### Configuration File

The TUI stores configuration in:
```
~/.config/management-tui/tui_config.yaml
```

### Configuration Options

```yaml
# Display settings
show_line_numbers: true
show_status_bar: true
show_footer: true
show_clock: true

# Theme
theme: dark  # Options: dark, light, monokai, gruvbox, nord

# Vim mode
vim_mode: true

# Mouse support
mouse_enabled: true

# Deployment defaults
auto_refresh_interval: 5  # seconds
max_log_lines: 1000
log_tail_lines: 50

# Paths
scripts_path: /path/to/management-system/scripts
profiles_path: /path/to/profiles
config_path: ~/.config/management-tui

# Script names
provision_script: provision_users.py
profile_helper_script: profile_git_helper.py

# Advanced settings
debug_mode: false
confirm_destructive: true
save_deployment_history: true
max_history_items: 100
restore_last_session: true
```

### Environment Variables

Override config with environment variables:

```bash
# Enable debug mode
export TUI_DEBUG=1

# Custom scripts directory
export SCRIPTS_DIR=/custom/path/scripts

# Custom profiles directory
export PROFILES_DIR=/custom/path/profiles

# Disable vim mode
export VIM_MODE=0
```

### Session State

Session state is persisted in:
```
~/.config/management-tui/session.json
```

Stores:
- Last selected profile
- Last used theme
- Deployment history (last 10)
- Window size and position

---

## 🎨 Themes

### Available Themes

The TUI includes multiple built-in themes:

#### Dark Themes
- **dark** (default) - Modern dark theme with blue accents
- **monokai** - Inspired by Monokai Sublime
- **gruvbox** - Warm, retro groove colors
- **nord** - Arctic, north-bluish color palette
- **dracula** - Dark theme with pink and purple accents
- **solarized-dark** - Precision colors for readability

#### Light Themes
- **light** - Clean, minimal light theme
- **solarized-light** - Solarized light variant
- **github-light** - GitHub-inspired light theme

### Switch Theme

**During runtime**:
- Press `Ctrl+T` to cycle through themes
- Or use Command Palette: `Ctrl+P` → `theme`

**Persist theme**:
Edit `~/.config/management-tui/tui_config.yaml`:
```yaml
theme: monokai  # Your preferred theme
```

### Create Custom Theme

1. **Create theme file**: `TUI/themes/mytheme.py`

```python
from TUI.theme import ThemeColors

MYTHEME = ThemeColors(
    background="#1a1a1a",
    surface="#2a2a2a",
    panel="#3a3a3a",
    foreground="#ffffff",
    muted="#888888",
    subtle="#444444",
    primary="#00ff00",
    secondary="#00aa00",
    accent="#ffff00",
    success="#00ff00",
    warning="#ffaa00",
    error="#ff0000",
    info="#00aaff",
    # ... more colors
)
```

2. **Register in `theme.py`**:
```python
THEMES = {
    "dark": DARK_THEME,
    "mytheme": MYTHEME,  # Add your theme
}
```

3. **Use custom theme**:
```bash
# Set in config
theme: mytheme
```

---

## 🏗️ Architecture

### Project Structure

```
TUI/
├── main.py                 # Application entry point
├── config.py               # Configuration management
├── theme.py                # Theme system
├── keybindings.py          # Keyboard shortcuts
├── utils.py                # Helper functions
├── styles.tcss             # Textual CSS styling
├── requirements.txt        # Python dependencies
├── README.md               # This file
│
├── screens/                # Screen components
│   ├── __init__.py
│   ├── dashboard.py        # Main dashboard screen
│   ├── deployment.py       # Deployment configuration
│   ├── logs.py             # Log viewer screen
│   └── help.py             # Help/shortcuts screen
│
├── widgets/                # Reusable UI widgets
│   ├── __init__.py
│   ├── command_palette.py  # Quick command search
│   ├── confirmation_dialog.py  # Confirmation dialogs
│   ├── deployment_list.py  # Deployment history list
│   ├── log_viewer.py       # Log display widget
│   └── status_panel.py     # Status information panel
│
├── themes/                 # Theme definitions
│   ├── __init__.py
│   └── (custom theme files)
│
└── logs/                   # Application logs (auto-created)
    └── (log files)
```

### Integration with Management System

The TUI integrates with existing scripts:

```
management-system/
├── TUI/                    # TUI application (this)
│   └── main.py
│
├── scripts/                # Deployment scripts
│   ├── deploy-docker.sh
│   ├── deploy-nix.sh
│   ├── provision_users.py
│   └── profile_git_helper.py
│
└── profiles/               # Git-based profiles
    ├── alice/              # Git branch: alice
    │   ├── services.env
    │   └── config.env
    └── bob/                # Git branch: bob
        ├── services.env
        └── config.env
```

### Data Flow

```
User Input (Keyboard)
      ↓
Key Bindings (keybindings.py)
      ↓
Screen Handler (screens/*.py)
      ↓
Action Execution
      ↓
Script Invocation (subprocess)
      ↓
Live Log Streaming
      ↓
UI Update (widgets/*.py)
      ↓
User Feedback (notifications, progress)
```

### Component Responsibilities

#### `main.py` - Application Core
- Initialize Textual app
- Manage global state
- Handle screen navigation
- Session persistence

#### `screens/` - UI Screens
- `dashboard.py`: Overview and quick actions
- `deployment.py`: Deployment configuration and execution
- `logs.py`: Log viewing and filtering
- `help.py`: Keyboard shortcuts reference

#### `widgets/` - Reusable Components
- `command_palette.py`: Quick command search
- `confirmation_dialog.py`: Yes/no dialogs
- `deployment_list.py`: Deployment history display
- `log_viewer.py`: Log rendering with syntax highlighting
- `status_panel.py`: System resource monitoring

#### `config.py` - Configuration
- Load/save user preferences
- Manage paths and environment
- Deployment history persistence

#### `theme.py` - Visual Styling
- Color scheme definitions
- Theme switching logic
- CSS variable management

#### `keybindings.py` - Keyboard Input
- Vim motion handlers
- Shortcut definitions
- Command mode parsing

---

## 🔥 Advanced Features

### Bulk Deployments

Deploy to multiple profiles simultaneously:

1. Open deployment screen
2. Press `m` to enable multi-select mode
3. Select multiple profiles with `Space`
4. Press `Enter` to deploy to all selected

### Deployment Templates

Save common configurations as templates:

1. Configure a deployment
2. Press `Ctrl+S` to save as template
3. Name the template
4. Load later with `Ctrl+O` → select template

### Script Chaining

Chain multiple scripts in sequence:

1. Open command palette (`Ctrl+P`)
2. Type `chain`
3. Select scripts to run in order
4. Configure pause between scripts
5. Execute chain

### Conditional Deployments

Deploy only if conditions are met:

```yaml
# In profile config.env
DEPLOY_IF_CHANGED=true  # Only deploy if config changed
DEPLOY_IF_HEALTHY=true  # Only if system resources available
```

### Webhook Notifications

Get notified when deployments complete:

```yaml
# In tui_config.yaml
webhooks:
  - url: https://discord.com/webhook/xxx
    events: [deployment_complete, deployment_failed]
  - url: https://slack.com/webhook/yyy
    events: [all]
```

### Remote Deployments

Deploy to remote hosts via SSH:

```yaml
# In tui_config.yaml
remote_hosts:
  - name: production
    host: prod.example.com
    user: deploy
    key_file: ~/.ssh/deploy_key
```

Then use: `Ctrl+P` → `deploy remote production`

---

## 🔧 Troubleshooting

### TUI Won't Start

**Problem**: Error when running `python main.py`

**Solutions**:
1. Check Python version: `python --version` (need 3.10+)
2. Verify dependencies: `pip install -r requirements.txt`
3. Check terminal support: `echo $TERM` (should be xterm-256color or similar)
4. Enable debug mode: `TUI_DEBUG=1 python main.py`

### Broken UI Layout

**Problem**: UI elements overlapping or misaligned

**Solutions**:
1. Resize terminal to at least 80x24
2. Check UTF-8 support: `locale | grep UTF-8`
3. Try different theme: `Ctrl+T`
4. Reset config: `rm ~/.config/management-tui/tui_config.yaml`

### Vim Motions Not Working

**Problem**: hjkl keys don't navigate

**Solutions**:
1. Check vim mode enabled in config: `vim_mode: true`
2. Verify keybindings loaded: Check help screen (`?`)
3. Restart TUI
4. Check for key conflicts with terminal emulator

### Deployment Fails

**Problem**: Deployment script exits with error

**Solutions**:
1. Check logs: Press `l` to view full error output
2. Verify scripts are executable: `chmod +x scripts/*.sh`
3. Check script paths in config
4. Test script manually: `./scripts/deploy-docker.sh profile-name`
5. Review profile configuration: `services.env` and `config.env`

### Logs Not Appearing

**Problem**: No output in log viewer

**Solutions**:
1. Check log directory exists: `ls TUI/logs/`
2. Verify permissions: `ls -la TUI/logs/`
3. Enable debug logging: `debug_mode: true` in config
4. Check disk space: `df -h`

### Profile Creation Fails

**Problem**: Cannot create new profile

**Solutions**:
1. Verify profiles directory exists: `ls ../profiles/`
2. Check Git is configured: `git config --list`
3. Ensure Git user set:
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "you@example.com"
   ```
4. Check branch name validity (alphanumeric + hyphens only)

### Session State Not Persisting

**Problem**: Settings don't save between sessions

**Solutions**:
1. Check config directory: `ls ~/.config/management-tui/`
2. Verify write permissions
3. Check `restore_last_session: true` in config
4. Look for errors in logs

### High CPU Usage

**Problem**: TUI consuming excessive CPU

**Solutions**:
1. Disable auto-refresh: Set `auto_refresh_interval: 0`
2. Reduce log retention: `max_log_lines: 100`
3. Disable mouse support: `mouse_enabled: false`
4. Check for runaway deployments

### Theme Colors Wrong

**Problem**: Colors don't match theme

**Solutions**:
1. Verify terminal supports 256 colors: `tput colors`
2. Check $TERM variable: `echo $TERM`
3. Try different theme
4. Reset styles: `rm TUI/.cache/*`

---

## 👩‍💻 Development

### Setup Development Environment

```bash
# Install development dependencies
pip install textual-dev pytest pytest-asyncio black ruff mypy

# Run in development mode with hot reload
textual run --dev main.py

# Open Textual DevTools in separate terminal
textual console
```

### Development Tools

**Textual DevTools**: Real-time inspection
```bash
textual console  # Start console
textual run --dev main.py  # Run app with dev mode
```

**Code Formatting**:
```bash
black TUI/  # Format code
ruff check TUI/  # Lint code
```

**Type Checking**:
```bash
mypy TUI/ --strict
```

### Running Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=TUI --cov-report=html

# Run specific test file
pytest tests/test_deployment.py

# Run with verbose output
pytest -v -s
```

### Adding a New Screen

1. **Create screen file**: `TUI/screens/myscreen.py`

```python
from textual.screen import Screen
from textual.widgets import Static

class MyScreen(Screen):
    def compose(self):
        yield Static("My custom screen")

    def on_mount(self):
        # Initialize screen
        pass
```

2. **Register in main.py**:
```python
from TUI.screens.myscreen import MyScreen

# In ManagementTUI class
SCREENS = {
    "dashboard": DashboardScreen,
    "myscreen": MyScreen,  # Add your screen
}
```

3. **Add navigation**:
```python
# In keybindings
Binding("m", "push_screen('myscreen')", "My Screen")
```

### Adding a New Widget

1. **Create widget file**: `TUI/widgets/mywidget.py`

```python
from textual.widget import Widget
from textual.containers import Container

class MyWidget(Widget):
    def compose(self):
        yield Container(
            # Widget content
        )

    def on_button_pressed(self, event):
        # Handle events
        pass
```

2. **Use in screen**:
```python
from TUI.widgets.mywidget import MyWidget

class SomeScreen(Screen):
    def compose(self):
        yield MyWidget()
```

### Adding a New Theme

See [Themes → Create Custom Theme](#create-custom-theme)

### Debugging

**Enable debug mode**:
```bash
export TUI_DEBUG=1
python main.py
```

**View debug logs**:
```bash
tail -f TUI/logs/debug.log
```

**Use Textual console**:
```bash
# Terminal 1: Start console
textual console

# Terminal 2: Run app
textual run --dev main.py

# In code, print to console:
from textual import log
log("Debug message", value=some_variable)
```

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

### Code Style

- **Python**: Follow PEP 8, use Black formatter
- **Type Hints**: Use type hints for all functions
- **Docstrings**: Google-style docstrings
- **Comments**: Explain why, not what

### Pull Request Process

1. Fork the repository
2. Create feature branch: `git checkout -b feature/my-feature`
3. Make changes with tests
4. Format code: `black TUI/ && ruff check TUI/`
5. Run tests: `pytest`
6. Commit with clear message
7. Push and create PR

### Commit Messages

Use conventional commits:
```
feat: Add deployment template support
fix: Resolve log filtering issue
docs: Update keyboard shortcuts
style: Format code with Black
refactor: Simplify deployment logic
test: Add unit tests for config
```

### Adding Documentation

- Update README.md for user-facing changes
- Add docstrings for code changes
- Include examples where helpful
- Update CHANGELOG.md

### Reporting Issues

Use GitHub Issues with:
- **Bug Report**: Description, steps to reproduce, expected vs actual, environment
- **Feature Request**: Use case, proposed solution, alternatives
- **Question**: Clear question, context, what you've tried

---

## 📄 License

This project is part of the Management System and follows the same license.

See [LICENSE](../LICENSE) for details.

---

## 🙏 Acknowledgments

### Built With

- **[Textual](https://github.com/Textualize/textual)** - Modern TUI framework by Textualize
- **[Rich](https://github.com/Textualize/rich)** - Beautiful terminal output
- **[Pydantic](https://github.com/pydantic/pydantic)** - Data validation
- **[PyYAML](https://github.com/yaml/pyyaml)** - YAML parsing

### Inspired By

- **k9s** - Kubernetes TUI
- **lazygit** - Git TUI
- **btop** - System monitor
- **vim** - Text editor (keybindings)

---

## 📞 Support

### Documentation

- **This README**: Comprehensive guide
- **Help Screen**: Press `?` or `F1` in TUI
- **Code Comments**: Inline documentation

### Community

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: Questions and discussions

### Professional Support

Contact the management-system maintainers for:
- Custom deployments
- Training and onboarding
- Priority support

---

**Happy Deploying! 🚀**

*Made with ❤️  using Textual*
