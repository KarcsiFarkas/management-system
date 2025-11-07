#!/usr/bin/env bash
#
# Management System TUI Launcher
#
# Quick launcher script with automatic dependency checking
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Management System TUI Launcher${NC}"
echo ""

# Check Python version
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is not installed${NC}"
    exit 1
fi

PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
REQUIRED_VERSION="3.10"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$PYTHON_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo -e "${RED}Error: Python $REQUIRED_VERSION or higher required (found $PYTHON_VERSION)${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Python $PYTHON_VERSION found"

# Check dependencies
if ! python3 -c "import textual" 2>/dev/null; then
    echo -e "${YELLOW}⚠${NC}  Dependencies not installed"
    echo ""
    read -p "Install dependencies now? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Installing dependencies..."
        pip3 install -r requirements.txt
        echo -e "${GREEN}✓${NC} Dependencies installed"
    else
        echo -e "${RED}Error: Please install dependencies with: pip3 install -r requirements.txt${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓${NC} Dependencies installed"
fi

# Check terminal capabilities
if [ -z "$TERM" ] || [ "$TERM" = "dumb" ]; then
    echo -e "${YELLOW}⚠${NC}  Warning: Terminal type not set properly"
    export TERM=xterm-256color
fi

echo -e "${GREEN}✓${NC} Terminal: $TERM"

# Discover profiles directory (prefer ms-config/tenants, then infrastructure, then defaults)
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Helper to test if a directory contains at least one YAML file
_dir_has_yaml() {
    local dir="$1"
    [ -d "$dir" ] || return 1
    if [ -n "$(find "$dir" -type f \( -name "*.yml" -o -name "*.yaml" \) -print -quit 2>/dev/null)" ]; then
        return 0
    fi
    return 1
}

# If PROFILES_DIR is preset and valid, use it; otherwise discover
if [ -n "$PROFILES_DIR" ] && _dir_has_yaml "$PROFILES_DIR"; then
    :
else
    for CAND in \
        "$REPO_ROOT/ms-config/tenants" \
        "$REPO_ROOT/ms-config/infrastructure" \
        "$SCRIPT_DIR/../profiles" \
        "$REPO_ROOT/profiles"; do
        if _dir_has_yaml "$CAND"; then
            PROFILES_DIR="$CAND"
            break
        fi
    done
fi

if [ -n "$PROFILES_DIR" ] && [ -d "$PROFILES_DIR" ]; then
    export PROFILES_DIR
    echo -e "${GREEN}✓${NC} Using profiles directory: $PROFILES_DIR"
else
    echo -e "${YELLOW}⚠${NC}  Warning: No profiles directory with YAML found"
    echo "   Searched ms-config/tenants, ms-config/infrastructure, and profiles"
    echo "   Profile management features will be limited"
fi

echo ""
echo -e "${GREEN}Starting TUI...${NC}"
echo ""

# Launch TUI
if [ "$1" = "--dev" ]; then
    echo "Running in development mode with hot reload..."
    textual run --dev main.py
else
    python3 main.py "$@"
fi
