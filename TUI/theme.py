"""
Theme System for TUI Application

Provides multiple color schemes and styling configurations:
- Monokai (default dark theme)
- Gruvbox (warm dark theme)
- Nord (cool dark theme)
- Solarized Dark
- Dracula
- Light theme options

Supports custom theme creation and dynamic theme switching.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

from textual.design import ColorSystem


ThemeName = Literal["monokai", "gruvbox", "nord", "solarized-dark", "dracula", "github-light", "solarized-light"]


@dataclass
class ThemeColors:
    """Color palette for a theme."""

    # Background colors
    background: str
    surface: str
    panel: str

    # Foreground colors
    foreground: str
    muted: str
    subtle: str

    # UI element colors
    primary: str
    secondary: str
    accent: str

    # Status colors
    success: str
    warning: str
    error: str
    info: str

    # Syntax highlighting colors
    keyword: str
    string: str
    number: str
    comment: str
    function: str
    variable: str

    # Border and shadow
    border: str
    border_active: str
    shadow: str


# ---------- Theme Definitions ----------

MONOKAI = ThemeColors(
    # Backgrounds
    background="#272822",
    surface="#3E3D32",
    panel="#49483E",

    # Foreground
    foreground="#F8F8F2",
    muted="#75715E",
    subtle="#49483E",

    # UI
    primary="#66D9EF",
    secondary="#A6E22E",
    accent="#F92672",

    # Status
    success="#A6E22E",
    warning="#E6DB74",
    error="#F92672",
    info="#66D9EF",

    # Syntax
    keyword="#F92672",
    string="#E6DB74",
    number="#AE81FF",
    comment="#75715E",
    function="#A6E22E",
    variable="#FD971F",

    # Borders
    border="#49483E",
    border_active="#66D9EF",
    shadow="#1B1A17"
)

GRUVBOX = ThemeColors(
    # Backgrounds
    background="#282828",
    surface="#3C3836",
    panel="#504945",

    # Foreground
    foreground="#EBDBB2",
    muted="#928374",
    subtle="#504945",

    # UI
    primary="#83A598",
    secondary="#B8BB26",
    accent="#FB4934",

    # Status
    success="#B8BB26",
    warning="#FABD2F",
    error="#FB4934",
    info="#83A598",

    # Syntax
    keyword="#FB4934",
    string="#B8BB26",
    number="#D3869B",
    comment="#928374",
    function="#FABD2F",
    variable="#FE8019",

    # Borders
    border="#504945",
    border_active="#83A598",
    shadow="#1D2021"
)

NORD = ThemeColors(
    # Backgrounds
    background="#2E3440",
    surface="#3B4252",
    panel="#434C5E",

    # Foreground
    foreground="#ECEFF4",
    muted="#4C566A",
    subtle="#434C5E",

    # UI
    primary="#88C0D0",
    secondary="#A3BE8C",
    accent="#BF616A",

    # Status
    success="#A3BE8C",
    warning="#EBCB8B",
    error="#BF616A",
    info="#88C0D0",

    # Syntax
    keyword="#81A1C1",
    string="#A3BE8C",
    number="#B48EAD",
    comment="#4C566A",
    function="#88C0D0",
    variable="#D08770",

    # Borders
    border="#434C5E",
    border_active="#88C0D0",
    shadow="#232831"
)

SOLARIZED_DARK = ThemeColors(
    # Backgrounds
    background="#002B36",
    surface="#073642",
    panel="#586E75",

    # Foreground
    foreground="#FDF6E3",
    muted="#586E75",
    subtle="#073642",

    # UI
    primary="#268BD2",
    secondary="#859900",
    accent="#DC322F",

    # Status
    success="#859900",
    warning="#B58900",
    error="#DC322F",
    info="#268BD2",

    # Syntax
    keyword="#CB4B16",
    string="#2AA198",
    number="#6C71C4",
    comment="#586E75",
    function="#268BD2",
    variable="#B58900",

    # Borders
    border="#073642",
    border_active="#268BD2",
    shadow="#001F27"
)

DRACULA = ThemeColors(
    # Backgrounds
    background="#282A36",
    surface="#44475A",
    panel="#6272A4",

    # Foreground
    foreground="#F8F8F2",
    muted="#6272A4",
    subtle="#44475A",

    # UI
    primary="#8BE9FD",
    secondary="#50FA7B",
    accent="#FF79C6",

    # Status
    success="#50FA7B",
    warning="#F1FA8C",
    error="#FF5555",
    info="#8BE9FD",

    # Syntax
    keyword="#FF79C6",
    string="#F1FA8C",
    number="#BD93F9",
    comment="#6272A4",
    function="#50FA7B",
    variable="#FFB86C",

    # Borders
    border="#44475A",
    border_active="#8BE9FD",
    shadow="#191A21"
)

GITHUB_LIGHT = ThemeColors(
    # Backgrounds
    background="#FFFFFF",
    surface="#F6F8FA",
    panel="#E1E4E8",

    # Foreground
    foreground="#24292E",
    muted="#6A737D",
    subtle="#E1E4E8",

    # UI
    primary="#0366D6",
    secondary="#28A745",
    accent="#D73A49",

    # Status
    success="#28A745",
    warning="#FFC107",
    error="#D73A49",
    info="#0366D6",

    # Syntax
    keyword="#D73A49",
    string="#032F62",
    number="#005CC5",
    comment="#6A737D",
    function="#6F42C1",
    variable="#E36209",

    # Borders
    border="#E1E4E8",
    border_active="#0366D6",
    shadow="#D1D5DA"
)

SOLARIZED_LIGHT = ThemeColors(
    # Backgrounds
    background="#FDF6E3",
    surface="#EEE8D5",
    panel="#93A1A1",

    # Foreground
    foreground="#002B36",
    muted="#93A1A1",
    subtle="#EEE8D5",

    # UI
    primary="#268BD2",
    secondary="#859900",
    accent="#DC322F",

    # Status
    success="#859900",
    warning="#B58900",
    error="#DC322F",
    info="#268BD2",

    # Syntax
    keyword="#CB4B16",
    string="#2AA198",
    number="#6C71C4",
    comment="#93A1A1",
    function="#268BD2",
    variable="#B58900",

    # Borders
    border="#EEE8D5",
    border_active="#268BD2",
    shadow="#D3CBAB"
)


# ---------- Theme Registry ----------

THEMES: dict[ThemeName, ThemeColors] = {
    "monokai": MONOKAI,
    "gruvbox": GRUVBOX,
    "nord": NORD,
    "solarized-dark": SOLARIZED_DARK,
    "dracula": DRACULA,
    "github-light": GITHUB_LIGHT,
    "solarized-light": SOLARIZED_LIGHT,
}


def get_theme(name: ThemeName = "monokai") -> ThemeColors:
    """Get theme colors by name."""
    return THEMES.get(name, MONOKAI)


def is_dark_theme(name: ThemeName) -> bool:
    """Check if theme is a dark theme."""
    return name not in ("github-light", "solarized-light")


# ---------- CSS Generation ----------

def generate_theme_css(theme: ThemeColors) -> str:
    """Generate Textual CSS from theme colors."""
    return f"""
/* Main application styling */
Screen {{
    background: {theme.background};
    color: {theme.foreground};
}}

/* Containers */
Container {{
    background: {theme.surface};
    border: solid {theme.border};
}}

.panel {{
    background: {theme.panel};
    border: solid {theme.border};
}}

/* Buttons */
Button {{
    background: {theme.primary};
    color: {theme.background};
}}

Button:hover {{
    background: {theme.secondary};
}}

Button:focus {{
    border: solid {theme.border_active};
}}

Button.-primary {{
    background: {theme.primary};
}}

Button.-warning {{
    background: {theme.warning};
    color: {theme.background};
}}

Button.-error {{
    background: {theme.error};
    color: {theme.background};
}}

/* Lists and selections */
ListView {{
    background: {theme.surface};
}}

ListItem {{
    background: {theme.surface};
}}

ListItem:hover {{
    background: {theme.panel};
}}

OptionList {{
    background: {theme.surface};
}}

OptionList > .option-list--option {{
    color: {theme.foreground};
}}

OptionList > .option-list--option-highlighted {{
    background: {theme.primary};
    color: {theme.background};
}}

/* Headers and labels */
Header {{
    background: {theme.panel};
    color: {theme.foreground};
}}

Footer {{
    background: {theme.panel};
    color: {theme.muted};
}}

Label {{
    color: {theme.foreground};
}}

.muted {{
    color: {theme.muted};
}}

/* Status indicators */
.success {{
    color: {theme.success};
}}

.warning {{
    color: {theme.warning};
}}

.error {{
    color: {theme.error};
}}

.info {{
    color: {theme.info};
}}

/* Progress bars */
ProgressBar > .bar--bar {{
    color: {theme.primary};
}}

ProgressBar > .bar--complete {{
    color: {theme.success};
}}

/* Input fields */
Input {{
    background: {theme.surface};
    border: solid {theme.border};
    color: {theme.foreground};
}}

Input:focus {{
    border: solid {theme.border_active};
}}

/* Text areas */
TextArea {{
    background: {theme.surface};
    border: solid {theme.border};
}}

/* Scrollbars */
ScrollBar {{
    background: {theme.surface};
}}

/* Tabs */
Tabs {{
    background: {theme.panel};
}}

Tab {{
    background: {theme.surface};
}}

Tab:hover {{
    background: {theme.panel};
}}

Tab.-active {{
    background: {theme.primary};
    color: {theme.background};
}}

/* Tooltips */
Tooltip {{
    background: {theme.panel};
    color: {theme.foreground};
    border: solid {theme.border};
}}

/* Log viewer */
.log-line {{
    color: {theme.foreground};
}}

.log-error {{
    color: {theme.error};
}}

.log-warning {{
    color: {theme.warning};
}}

.log-info {{
    color: {theme.info};
}}

.log-debug {{
    color: {theme.muted};
}}

/* Status bar */
.status-bar {{
    background: {theme.panel};
    color: {theme.muted};
}}

.status-key {{
    color: {theme.accent};
}}

.status-value {{
    color: {theme.foreground};
}}
"""


def get_theme_css(theme_name: ThemeName = "monokai") -> str:
    """Get CSS for a specific theme."""
    theme = get_theme(theme_name)
    return generate_theme_css(theme)


# ---------- Theme Manager ----------

class ThemeManager:
    """
    Manages theme switching and application of color schemes.

    Provides a centralized interface for theme management including:
    - Getting theme by name
    - Listing available themes
    - Switching themes dynamically
    - Generating CSS from themes
    """

    def __init__(self, default_theme: ThemeName = "monokai"):
        """
        Initialize ThemeManager.

        Args:
            default_theme: Default theme to use
        """
        self.current_theme_name = default_theme
        self.themes = THEMES

    def get_theme(self, name: str | ThemeName) -> ThemeColors | None:
        """
        Get theme colors by name.

        Args:
            name: Name of the theme

        Returns:
            ThemeColors object if theme exists, None otherwise
        """
        return self.themes.get(name, None)  # type: ignore

    def get_current_theme(self) -> ThemeColors:
        """Get the currently active theme."""
        return self.themes[self.current_theme_name]

    def set_theme(self, name: ThemeName) -> bool:
        """
        Set the current theme.

        Args:
            name: Name of theme to activate

        Returns:
            True if theme was set successfully, False otherwise
        """
        if name in self.themes:
            self.current_theme_name = name
            return True
        return False

    def list_themes(self) -> list[str]:
        """
        Get list of available theme names.

        Returns:
            List of theme names
        """
        return list(self.themes.keys())

    def get_theme_css(self, name: ThemeName | None = None) -> str:
        """
        Generate CSS for a theme.

        Args:
            name: Theme name (uses current theme if None)

        Returns:
            CSS string for the theme
        """
        theme_name = name or self.current_theme_name
        theme = self.get_theme(theme_name)
        if theme:
            return generate_theme_css(theme)
        return ""

    def is_dark_theme(self, name: ThemeName | None = None) -> bool:
        """
        Check if a theme is a dark theme.

        Args:
            name: Theme name (uses current theme if None)

        Returns:
            True if dark theme, False otherwise
        """
        theme_name = name or self.current_theme_name
        return is_dark_theme(theme_name)  # type: ignore
