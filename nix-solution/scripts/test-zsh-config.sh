#!/usr/bin/env bash
#
# Zsh Configuration Testing Script
# Tests all installed tools after nixos-rebuild switch
#
# Usage: ./test-zsh-config.sh
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
PASSED=0
FAILED=0

# Helper functions
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

print_failure() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Test 1: Check if running in new shell
print_header "Shell Environment Check"
if [ "$SHLVL" -le 2 ]; then
    print_success "Running in shell level $SHLVL"
else
    print_warning "Running in nested shell level $SHLVL (normal if using script)"
fi

# Test 2: Check if zsh is the current shell
if [ -n "$ZSH_VERSION" ]; then
    print_success "Running in zsh version: $ZSH_VERSION"
else
    print_failure "NOT running in zsh (current shell: $SHELL)"
    exit 1
fi

# Test 3: Tool availability
print_header "Tool Availability"

tools=("zoxide" "atuin" "yazi" "starship" "bat" "eza" "zellij")
for tool in "${tools[@]}"; do
    if command -v "$tool" &> /dev/null; then
        version=$(command "$tool" --version 2>&1 | head -1 || echo "unknown")
        print_success "$tool found: $version"
    else
        print_failure "$tool not found in PATH"
    fi
done

# Test 4: Zsh functions and aliases
print_header "Functions and Aliases"

# Check if 'z' function exists (from zoxide)
if type z &> /dev/null; then
    print_success "zoxide 'z' command available"
else
    print_failure "zoxide 'z' command not available"
fi

# Check if 'y' function exists (yazi wrapper)
if type y &> /dev/null; then
    func_def=$(type y)
    if echo "$func_def" | grep -q "builtin cd"; then
        print_success "yazi 'y' wrapper function defined correctly (uses builtin cd)"
    else
        print_warning "yazi 'y' function exists but may not use 'builtin cd'"
    fi
else
    print_failure "yazi 'y' wrapper function not defined"
fi

# Check aliases
aliases=("ll:ls -lah" "cat:bat" "gs:git status" "zj:zellij")
for alias_check in "${aliases[@]}"; do
    alias_name="${alias_check%%:*}"
    expected="${alias_check#*:}"
    actual=$(alias "$alias_name" 2>/dev/null | sed "s/.*='\\(.*\\)'/\\1/")
    if [ "$actual" = "$expected" ]; then
        print_success "alias '$alias_name' = '$expected'"
    else
        print_failure "alias '$alias_name' incorrect or missing (got: '$actual')"
    fi
done

# Test 5: Zsh features
print_header "Zsh Features"

# Check completion system
if [ -n "$fpath" ]; then
    print_success "Completion system fpath configured"
else
    print_failure "Completion system fpath not set"
fi

# Check if autosuggestions are available
if [ -d /nix/store/*-zsh-autosuggestions-*/share/zsh-autosuggestions ] 2>/dev/null; then
    print_success "Zsh autosuggestions installed"
else
    print_warning "Zsh autosuggestions package not found (check if loaded)"
fi

# Check if syntax highlighting is available
if [ -d /nix/store/*-zsh-syntax-highlighting-*/share/zsh-syntax-highlighting ] 2>/dev/null; then
    print_success "Zsh syntax highlighting installed"
else
    print_warning "Zsh syntax highlighting package not found (check if loaded)"
fi

# Test 6: Environment variables
print_header "Environment Variables"

env_vars=("EDITOR:vim" "VISUAL:vim" "STARSHIP_SHELL:zsh")
for var_check in "${env_vars[@]}"; do
    var_name="${var_check%%:*}"
    expected="${var_check#*:}"
    actual="${!var_name}"
    if [ "$actual" = "$expected" ]; then
        print_success "\$$var_name = '$expected'"
    else
        print_warning "\$$var_name = '$actual' (expected: '$expected')"
    fi
done

# Test 7: Atuin keybindings
print_header "Atuin Configuration"

# Check if atuin widget exists
if zle -la 2>/dev/null | grep -q atuin; then
    print_success "Atuin zle widgets registered"
else
    print_failure "Atuin zle widgets not found"
fi

# Check Ctrl+R binding
binding=$(bindkey | grep '\\^R' 2>/dev/null || echo "")
if echo "$binding" | grep -q atuin; then
    print_success "Ctrl+R bound to atuin search"
else
    print_failure "Ctrl+R not bound to atuin (current: $binding)"
fi

# Test 8: Starship prompt
print_header "Starship Prompt"

if [ -n "$STARSHIP_SHELL" ]; then
    print_success "Starship shell variable set: $STARSHIP_SHELL"
else
    print_warning "STARSHIP_SHELL not set (prompt may still work)"
fi

if command -v starship &> /dev/null; then
    starship_config=$(starship config 2>&1 | head -1 || echo "default")
    print_success "Starship configuration loaded"
else
    print_failure "Starship command not available"
fi

# Test 9: History configuration
print_header "History Configuration"

if [ -f "$HOME/.zsh_history" ]; then
    print_success "Zsh history file exists: ~/.zsh_history"
else
    print_warning "Zsh history file not created yet (normal for new shell)"
fi

# Check history options
history_opts=("HIST_IGNORE_ALL_DUPS" "SHARE_HISTORY" "INC_APPEND_HISTORY")
for opt in "${history_opts[@]}"; do
    if setopt | grep -q "$opt"; then
        print_success "History option set: $opt"
    else
        print_failure "History option not set: $opt"
    fi
done

# Test 10: File integrity
print_header "Configuration Files"

if [ -f /etc/zshrc ]; then
    mod_time=$(stat -c %y /etc/zshrc 2>/dev/null || stat -f %Sm /etc/zshrc 2>/dev/null)
    print_success "/etc/zshrc exists (modified: ${mod_time%.*})"
else
    print_failure "/etc/zshrc not found"
fi

if [ -d /nix/store ]; then
    zsh_stores=$(ls -d /nix/store/*-zsh-*/bin/zsh 2>/dev/null | wc -l)
    print_success "Found $zsh_stores zsh installations in /nix/store"
else
    print_failure "/nix/store not accessible"
fi

# Summary
print_header "Test Summary"
TOTAL=$((PASSED + FAILED))
echo -e "Tests passed: ${GREEN}$PASSED${NC}"
echo -e "Tests failed: ${RED}$FAILED${NC}"
echo -e "Total tests: $TOTAL"

if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All critical tests passed!${NC}"
    echo -e "${YELLOW}Note:${NC} Some warnings are normal. Test functionality manually:"
    echo -e "  1. Run: ${BLUE}z /tmp${NC} (should change to /tmp)"
    echo -e "  2. Press: ${BLUE}Ctrl+R${NC} (should open atuin search)"
    echo -e "  3. Run: ${BLUE}y${NC} (should open yazi file manager)"
    exit 0
else
    echo -e "\n${RED}❌ Some tests failed. Check the output above.${NC}"
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo -e "  1. Ensure you ran: ${BLUE}sudo nixos-rebuild switch --flake \".#wsl-paas\"${NC}"
    echo -e "  2. Start a NEW shell: ${BLUE}zsh${NC}"
    echo -e "  3. Check logs: ${BLUE}journalctl -xe${NC}"
    exit 1
fi
