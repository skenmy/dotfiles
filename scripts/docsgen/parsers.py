"""Pure parsers that turn dotfiles sources into inventory data.

Every function takes text in and returns plain tuples/dataclasses out, so it
can be unit-tested without touching the filesystem. Nothing here mutates
its inputs.
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Iterable

# --------------------------------------------------------------------------
# Brewfile
# --------------------------------------------------------------------------

BREW_LINE = re.compile(r'^(brew|cask|tap|mas|vscode)\s+"([^"]+)"(?:\s*,\s*[^#]*)?\s*(?:#\s*(.*))?$')
SECTION_COMMENT = re.compile(r"^#\s*(.+?)\s*$")
AUTO_SYNCED = re.compile(r"^auto-synced from", re.IGNORECASE)


@dataclass(frozen=True)
class BrewEntry:
    kind: str
    name: str
    note: str
    section: str
    line: int
    fragment: str = ""

    @property
    def key(self) -> str:
        return f'{self.kind} "{self.name}"'

    @property
    def is_auto_synced(self) -> bool:
        return bool(AUTO_SYNCED.match(self.section))


def parse_brewfile(text: str, fragment: str = "") -> list[BrewEntry]:
    """Return every package line with its nearest preceding comment as section.

    `fragment` labels which Brewfile fragment the text came from.
    """
    entries: list[BrewEntry] = []
    section = "Unsectioned"
    for number, raw in enumerate(text.splitlines(), start=1):
        line = raw.strip()
        if not line:
            continue
        heading = SECTION_COMMENT.match(line)
        if heading:
            section = heading.group(1)
            continue
        match = BREW_LINE.match(line)
        if match:
            kind, name, note = match.groups()
            entries.append(BrewEntry(kind, name, (note or "").strip(), section, number, fragment))
    return entries


def find_duplicates(entries: Iterable[BrewEntry]) -> dict[str, list[BrewEntry]]:
    """Group entries by kind+name; keep only keys that appear more than once."""
    grouped: dict[str, list[BrewEntry]] = {}
    for entry in entries:
        grouped[entry.key] = [*grouped.get(entry.key, []), entry]
    return {key: items for key, items in grouped.items() if len(items) > 1}


# --------------------------------------------------------------------------
# Shell scripts (Linux installer)
# --------------------------------------------------------------------------


@dataclass(frozen=True)
class GuardedInstall:
    tool: str
    method: str


def parse_bash_array(text: str, name: str) -> list[str]:
    """Merge `NAME=(...)` and `NAME+=(...)` assignments, de-duplicated in order."""
    pattern = re.compile(rf"^\s*{re.escape(name)}\+?=\((.*?)\)\s*$", re.MULTILINE)
    seen: list[str] = []
    for body in pattern.findall(text):
        for item in body.split():
            if item not in seen:
                seen.append(item)
    return seen


IF_GUARD = re.compile(r"^\s*if\s+!\s+command\s+-v\s+(\S+)\s+>/dev/null.*;\s*then\s*$")
OR_GUARD = re.compile(r"^\s*command\s+-v\s+(\S+)\s+>/dev/null\S*\s*\|\|\s*(.+?)\s*$")


def parse_guarded_installs(text: str) -> list[GuardedInstall]:
    """Find `if ! command -v X; then <cmd>` and `command -v X || <cmd>` installs.

    Brace-group fallbacks (`|| { echo ...; exit 0; }`) are early exits, not
    installs, and are skipped.
    """
    lines = text.splitlines()
    found: list[GuardedInstall] = []
    for index, line in enumerate(lines):
        if_match = IF_GUARD.match(line)
        if if_match and index + 1 < len(lines):
            found.append(GuardedInstall(if_match.group(1), lines[index + 1].strip()))
            continue
        or_match = OR_GUARD.match(line)
        if or_match and not or_match.group(2).startswith("{"):
            found.append(GuardedInstall(or_match.group(1), or_match.group(2)))
    return found


# --------------------------------------------------------------------------
# Windows installer
# --------------------------------------------------------------------------

WINGET_BLOCK = re.compile(r"\$packages\s*=\s*@\((.*?)\)", re.DOTALL)


def parse_winget_packages(text: str) -> list[str]:
    match = WINGET_BLOCK.search(text)
    if not match:
        return []
    return re.findall(r'"([^"]+)"', match.group(1))


# --------------------------------------------------------------------------
# Line lists (extensions, zsh plugins, tips)
# --------------------------------------------------------------------------

TIP_SECTION = re.compile(r"^#\s*─+\s*(.+?)\s*─+\s*$")


def parse_line_list(text: str) -> list[str]:
    return [line.strip() for line in text.splitlines() if line.strip() and not line.lstrip().startswith("#")]


def parse_tips(text: str) -> list[tuple[str, str]]:
    """Return (section, tip) pairs; sections come from `# ── name ──` headers."""
    section = "General"
    tips: list[tuple[str, str]] = []
    for raw in text.splitlines():
        line = raw.strip()
        header = TIP_SECTION.match(line)
        if header:
            section = header.group(1)
        elif line and not line.startswith("#"):
            tips.append((section, line))
    return tips


# --------------------------------------------------------------------------
# Zed settings (JSON with comments)
# --------------------------------------------------------------------------

AUTO_INSTALL_BLOCK = re.compile(r'"auto_install_extensions"\s*:\s*\{(.*?)\}', re.DOTALL)
JSONC_COMMENT = re.compile(r"^\s*//.*$", re.MULTILINE)


def parse_zed_extensions(text: str) -> list[tuple[str, bool]]:
    """Return (extension, enabled) pairs from Zed's auto_install_extensions block."""
    body = JSONC_COMMENT.sub("", text)
    match = AUTO_INSTALL_BLOCK.search(body)
    if not match:
        return []
    return [(name, flag == "true") for name, flag in re.findall(r'"([^"]+)"\s*:\s*(true|false)', match.group(1))]


# --------------------------------------------------------------------------
# macOS defaults
# --------------------------------------------------------------------------

DEFAULTS_LINE = re.compile(
    r"^defaults\s+(-currentHost\s+)?write\s+(\S+)\s+(\S+)\s+-(\w+)\s+(.+?)(?:\s+2>/dev/null.*)?$"
)
DEFAULTS_SECTION = re.compile(r"^#\s*-{2,}\s*(.+?)\s*-{2,}\s*$")


@dataclass(frozen=True)
class DefaultsEntry:
    section: str
    domain: str
    key: str
    kind: str
    value: str
    current_host: bool


def parse_macos_defaults(text: str) -> list[DefaultsEntry]:
    section = "General"
    rows: list[DefaultsEntry] = []
    for raw in text.splitlines():
        line = raw.strip()
        heading = DEFAULTS_SECTION.match(line)
        if heading:
            section = heading.group(1)
            continue
        match = DEFAULTS_LINE.match(line)
        if match:
            host_flag, domain, key, kind, value = match.groups()
            rows.append(DefaultsEntry(section, domain, key, kind, value.strip().strip('"'), bool(host_flag)))
    return rows


# --------------------------------------------------------------------------
# Aliases
# --------------------------------------------------------------------------

INI_SECTION = re.compile(r"^\[([^\]]+)\]")
INI_KV = re.compile(r"^\s*([A-Za-z0-9_-]+)\s*=\s*(.*)$")
SHELL_ALIAS = re.compile(r"""^\s*alias\s+([^=\s]+)=(['"])(.*)\2\s*$""")


def parse_git_aliases(text: str) -> list[tuple[str, str]]:
    aliases: list[tuple[str, str]] = []
    in_alias = False
    for line in text.splitlines():
        section = INI_SECTION.match(line.strip())
        if section:
            in_alias = section.group(1).strip() == "alias"
            continue
        kv = INI_KV.match(line)
        if in_alias and kv:
            aliases.append((kv.group(1), kv.group(2).strip()))
    return aliases


def parse_shell_aliases(text: str) -> list[tuple[str, str]]:
    return [(m.group(1), m.group(3)) for m in map(SHELL_ALIAS.match, text.splitlines()) if m]


# --------------------------------------------------------------------------
# Lua (Neovim)
# --------------------------------------------------------------------------

REPO_SLUG = re.compile(r'"([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)"')


def parse_lua_string_list(text: str, anchor: str) -> list[str]:
    """Return the double-quoted strings inside the first `{ ... }` after anchor."""
    start = text.find(anchor)
    if start < 0:
        return []
    open_brace = text.find("{", start)
    close_brace = text.find("}", open_brace)
    if open_brace < 0 or close_brace < 0:
        return []
    return re.findall(r'"([^"]+)"', text[open_brace:close_brace])


def parse_repo_slugs(text: str) -> list[str]:
    seen: list[str] = []
    for slug in REPO_SLUG.findall(text):
        if slug not in seen:
            seen.append(slug)
    return seen


# --------------------------------------------------------------------------
# tmux
# --------------------------------------------------------------------------

TMUX_PLUGIN = re.compile(r"""^\s*set\s+-g\s+@plugin\s+['"]([^'"]+)['"]""")


def parse_tmux_plugins(text: str) -> list[str]:
    return [m.group(1) for m in map(TMUX_PLUGIN.match, text.splitlines()) if m]


# --------------------------------------------------------------------------
# chezmoi source naming
# --------------------------------------------------------------------------

SCRIPT_PREFIXES = ("run_once_", "run_onchange_", "run_")
COMPONENT_PREFIXES = (
    "private_", "readonly_", "executable_", "exact_", "symlink_", "modify_",
    "create_", "remove_", "empty_", "encrypted_", "literal_",
)


@dataclass(frozen=True)
class TargetInfo:
    target: str
    is_template: bool
    is_private: bool
    is_executable: bool
    is_script: bool


def _strip_component(component: str) -> tuple[str, bool, bool]:
    name, is_private, is_executable = component, False, False
    changed = True
    while changed:
        changed = False
        for prefix in COMPONENT_PREFIXES:
            if name.startswith(prefix):
                name = name[len(prefix):]
                is_private = is_private or prefix == "private_"
                is_executable = is_executable or prefix == "executable_"
                changed = True
    if name.startswith("dot_"):
        name = "." + name[len("dot_"):]
    return name, is_private, is_executable


def source_to_target(source_path: str) -> TargetInfo:
    """Map a chezmoi source path to the destination it renders to."""
    is_template = source_path.endswith(".tmpl")
    path = source_path[: -len(".tmpl")] if is_template else source_path
    components = path.split("/")
    if components[-1].startswith(SCRIPT_PREFIXES):
        return TargetInfo(components[-1], is_template, False, True, True)
    cleaned: list[str] = []
    is_private = is_executable = False
    for component in components:
        name, private, executable = _strip_component(component)
        cleaned.append(name)
        is_private = is_private or private
        is_executable = is_executable or executable
    return TargetInfo("~/" + "/".join(cleaned), is_template, is_private, is_executable, False)


def parse_unconditional_ignores(text: str) -> list[str]:
    """Lines of .chezmoiignore outside any `{{ if }}` block."""
    depth = 0
    unconditional: list[str] = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("{{"):
            if re.search(r"\bif\b", line):
                depth += 1
            elif re.search(r"\bend\b", line):
                depth -= 1
            continue
        if depth == 0:
            unconditional.append(line)
    return unconditional
