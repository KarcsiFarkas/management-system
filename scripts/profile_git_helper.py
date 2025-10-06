#!/usr/bin/env python3
"""
Profile Git Helper

Scenario
- You have a nested Git repo at <ROOT>/profiles (each branch = a user profile).
- You want to run this helper *outside* the ROOT and still manage branches in
  the nested repo.

What it does
- Locates the profiles repo (via --profiles path OR by searching for a
  "profiles/.git" folder upward and downward from the current working dir).
- Lists local branches with a numbered, colored UI (marks the current branch).
- Lets you pick a branch by number or by name, then checks it out.
- Optional flags to only list, to checkout directly, or to be non-interactive.

Usage examples
  python profile_git_helper.py --profiles /path/to/ROOT/profiles
  python profile_git_helper.py --root /path/to/ROOT       # uses ROOT/profiles
  python profile_git_helper.py                             # tries to auto-detect
  python profile_git_helper.py --list-only                 # just list branches
  python profile_git_helper.py --checkout my-branch        # non-interactive

No third-party dependencies. Uses ANSI colors; will degrade gracefully if
colors are not supported.
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from typing import List, Optional, Tuple

# --- Minimal color helper (no external deps) ---------------------------------
class Colors:
    def __init__(self, enabled: bool) -> None:
        if not enabled:
            # No-op strings when disabled
            self.reset = self.bold = self.dim = self.red = self.green = self.yellow = (
                self.blue
            ) = self.magenta = self.cyan = self.white = ""
        else:
            self.reset = "\033[0m"
            self.bold = "\033[1m"
            self.dim = "\033[2m"
            self.red = "\033[31m"
            self.green = "\033[32m"
            self.yellow = "\033[33m"
            self.blue = "\033[34m"
            self.magenta = "\033[35m"
            self.cyan = "\033[36m"
            self.white = "\033[37m"

    def colorize(self, text: str, *styles: str) -> str:
        if not styles:
            return text
        return "".join(styles) + text + self.reset


def supports_color() -> bool:
    return sys.stdout.isatty() and (os.environ.get("TERM") not in ("dumb", None))


C = Colors(enabled=supports_color())


# --- Git helpers --------------------------------------------------------------
@dataclass
class GitResult:
    ok: bool
    out: str
    err: str
    code: int


def which_git() -> str:
    g = shutil.which("git")
    if not g:
        die("git is not installed or not on PATH.")
    return g


def git(repo: str, *args: str) -> GitResult:
    git_bin = which_git()
    cmd = [git_bin, "-C", repo, *args]
    try:
        proc = subprocess.run(
            cmd, capture_output=True, text=True, check=False, encoding="utf-8"
        )
    except FileNotFoundError:
        die("git not found on PATH.")
    return GitResult(
        ok=proc.returncode == 0, out=proc.stdout.strip(), err=proc.stderr.strip(), code=proc.returncode
    )


def die(msg: str, code: int = 1) -> None:
    print(C.colorize(f"✖ {msg}", C.red, C.bold))
    sys.exit(code)


# --- Repo discovery -----------------------------------------------------------

def is_git_repo(path: str) -> bool:
    return os.path.isdir(os.path.join(path, ".git"))


def resolve_profiles_repo(args_ns: argparse.Namespace) -> str:
    # Priority: --profiles > --root/profiles > AUTO
    if args_ns.profiles:
        repo = os.path.abspath(args_ns.profiles)
        if not is_git_repo(repo):
            die(f"--profiles path is not a git repo: {repo}")
        return repo

    if args_ns.root:
        repo = os.path.abspath(os.path.join(args_ns.root, "profiles"))
        if not is_git_repo(repo):
            die(f"No git repo at: {repo}")
        return repo

    # Auto-detect: look for a 'profiles/.git' folder upwards and in common spots
    cwd = os.path.abspath(os.getcwd())

    # 1) Check ./profiles
    direct = os.path.join(cwd, "profiles")
    if is_git_repo(direct):
        return direct

    # 2) Walk upwards a few levels
    here = cwd
    for _ in range(6):
        candidate = os.path.join(here, "profiles")
        if is_git_repo(candidate):
            return candidate
        parent = os.path.dirname(here)
        if parent == here:
            break
        here = parent

    die("Could not auto-detect a 'profiles' git repo. Use --profiles or --root.")


# --- Branch listing & selection ----------------------------------------------
@dataclass
class Branches:
    current: Optional[str]
    local: List[str]


def get_branches(repo: str) -> Branches:
    # Current branch (works unless detached HEAD)
    cur = git(repo, "rev-parse", "--abbrev-ref", "HEAD")
    current = cur.out if cur.ok and cur.out != "HEAD" else None

    # Local branches
    br = git(repo, "for-each-ref", "--format=%(refname:short)", "refs/heads/")
    if not br.ok:
        die(f"Failed listing branches: {br.err}")
    local = [line.strip() for line in br.out.splitlines() if line.strip()]
    return Branches(current=current, local=local)


def print_branches(branches: Branches) -> None:
    title = C.colorize("Available profiles (branches):", C.cyan, C.bold)
    print(title)
    if not branches.local:
        print(C.colorize("(no local branches found)", C.yellow))
        return

    width = len(str(len(branches.local)))
    for idx, name in enumerate(branches.local, 1):
        prefix = f"{idx:>{width}}. "
        if name == branches.current:
            line = f"{prefix}{name} " + C.colorize("← current", C.yellow)
            print(C.colorize(line, C.bold))
        else:
            print(prefix + name)


def parse_choice(inp: str, branches: Branches) -> Optional[str]:
    s = inp.strip()
    if not s:
        return None
    if s.lower() in {"q", "quit", "exit"}:
        return None
    # Numbered selection
    if s.isdigit():
        i = int(s)
        if 1 <= i <= len(branches.local):
            return branches.local[i - 1]
        return None
    # Name selection (exact match)
    if s in branches.local:
        return s
    # Fuzzy: case-insensitive exact
    for name in branches.local:
        if name.lower() == s.lower():
            return name
    return None


# --- Checkout ---------------------------------------------------------------

def checkout(repo: str, branch: str) -> None:
    res = git(repo, "checkout", branch)
    if not res.ok:
        die(f"Checkout failed: {res.err}")


# --- CLI ---------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Helper to manage a nested 'profiles' git repo where each branch is a profile.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    loc = p.add_mutually_exclusive_group()
    loc.add_argument("--profiles", type=str, help="Path directly to the profiles git repo")
    loc.add_argument("--root", type=str, help="Path to the project root that contains 'profiles/'")

    p.add_argument("--list-only", action="store_true", help="Only list branches and exit")
    p.add_argument("--checkout", metavar="BRANCH", help="Non-interactive: checkout this branch and exit")
    p.add_argument("--no-color", action="store_true", help="Disable ANSI colors")
    p.add_argument("--yes", "-y", action="store_true", help="Assume yes for prompts when --checkout is used")
    return p


def main(argv: Optional[List[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    # Reconfigure colors if requested
    global C
    if args.no_color:
        C = Colors(enabled=False)

    repo = resolve_profiles_repo(args)
    if not is_git_repo(repo):
        die(f"Not a git repo: {repo}")

    # Safety: ensure we can talk to git
    _ = which_git()

    branches = get_branches(repo)

    header = f"Repo: {repo}"
    if branches.current:
        header += f"  |  current: {C.colorize(branches.current, C.yellow, C.bold)}"
    print(C.colorize(header, C.magenta, C.bold))
    print_branches(branches)

    if args.list_only:
        return 0

    if args.checkout:
        target = args.checkout
        if target not in branches.local:
            die(f"Branch '{target}' not found in repo.")
        if not args.yes and sys.stdout.isatty():
            confirmation = input(C.colorize(f"Checkout '{target}'? [y/N]: ", C.cyan))
            if confirmation.strip().lower() not in {"y", "yes"}:
                print(C.colorize("Aborted.", C.yellow))
                return 1
        checkout(repo, target)
        print(C.colorize(f"✔ Checked out '{target}'.", C.green, C.bold))
        return 0

    # Interactive selection
    if sys.stdin.isatty():
        prompt = C.colorize(
            "Select a profile by number or name (or 'q' to quit): ", C.cyan, C.bold
        )
        choice = input(prompt)
        picked = parse_choice(choice, branches)
        if not picked:
            print(C.colorize("No selection. Bye!", C.yellow))
            return 1
        checkout(repo, picked)
        print(C.colorize(f"✔ Checked out '{picked}'.", C.green, C.bold))
        return 0

    # If non-interactive and no --checkout provided
    print(C.colorize("No TTY and no --checkout provided. Nothing to do.", C.yellow))
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
