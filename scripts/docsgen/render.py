"""Markdown rendering for the generated inventory pages.

Each `render_*` function returns a complete Markdown document as a string.
The caller decides where to write it.
"""
from __future__ import annotations

from collections import Counter
from typing import Iterable, Sequence

from . import parsers as p

GENERATED_BANNER = (
    '!!! info "Generated page"\n'
    "    Built from the repository sources at publish time by `scripts/docsgen`. "
    "Do not edit by hand; change the source file named below and the page follows.\n\n"
)


def code(value: str) -> str:
    """Wrap in a code span, tolerating embedded backticks.

    Pipes are left alone: Python-Markdown's tables extension never splits a
    row inside a backtick span, and it renders a backslash-escaped pipe
    literally there.
    """
    if not value:
        return ""
    fence = "``" if "`" in value else "`"
    return f"{fence}{value}{fence}"


def text(value: str) -> str:
    return value.replace("|", "\\|")


def table(headers: Sequence[str], rows: Iterable[Sequence[str]]) -> str:
    lines = ["| " + " | ".join(headers) + " |", "|" + "---|" * len(headers)]
    lines.extend("| " + " | ".join(row) + " |" for row in rows)
    return "\n".join(lines) + "\n\n"


def page(title: str, source: str, body: str) -> str:
    return f"# {title}\n\n{GENERATED_BANNER}Source: {code(source)}\n\n{body}"


def grouped(items: Iterable, key) -> dict:
    """Order-preserving group-by returning a new dict."""
    out: dict = {}
    for item in items:
        out[key(item)] = [*out.get(key(item), []), item]
    return out


# --------------------------------------------------------------------------


def render_brewfile(entries: list[p.BrewEntry]) -> str:
    counts = Counter(entry.kind for entry in entries)
    summary = ", ".join(f"{count} {kind}" for kind, count in sorted(counts.items()))
    body = f"**{len(entries)} entries** ({summary}). "
    body += "Applied on every macOS box by `brew bundle`. The Brewfile is not a template, so every macOS profile gets every line.\n\n"

    dupes = p.find_duplicates(entries)
    if dupes:
        body += '!!! warning "Duplicate entries"\n'
        body += "    These names appear more than once. `brew bundle` tolerates it, but each duplicate means "
        body += "`dotfiles-brew-sync` re-appended a package whose original line carries a trailing comment "
        body += "(the sync script compares whole lines, not names). See the gap register.\n\n"
        body += "    | Entry | Lines |\n    |---|---|\n"
        for key, items in dupes.items():
            body += f"    | {code(key)} | {', '.join(str(i.line) for i in items)} |\n"
        body += "\n"

    for section, items in grouped(entries, lambda e: e.section).items():
        body += f"## {text(section)}\n\n"
        rows = [(e.kind, code(e.name), text(e.note), "duplicate" if e.key in dupes else "") for e in items]
        body += table(["Type", "Name", "Note", "Flags"], rows)
    return page("Brewfile (macOS)", "Brewfile", body)


def render_linux(common: list[str], guarded: list[p.GuardedInstall], distro_extras: dict[str, str]) -> str:
    body = "## Distro package manager\n\n"
    body += "Installed through whichever of apt, dnf, pacman or apk is present. Names are passed verbatim, "
    body += "so a name that only exists on Debian (for example `fd-find`) fails elsewhere.\n\n"
    body += table(["Package"], [(code(name),) for name in common])
    body += "Per-manager extras:\n\n"
    body += table(["Manager", "Extra"], [(code(k), code(v)) for k, v in distro_extras.items()])
    body += "## Installed by upstream script or release binary\n\n"
    body += "Each is skipped when the command is already on `PATH`.\n\n"
    body += table(["Tool", "Method"], [(code(g.tool), code(g.method)) for g in guarded])
    return page("Linux packages", "run_once_install-packages-linux.sh.tmpl", body)


def render_windows(packages: list[str]) -> str:
    body = f"**{len(packages)} winget packages**, installed with `winget install --exact --silent`, "
    body += "plus `Install-Module PSReadLine` from the PowerShell Gallery.\n\n"
    body += table(["winget ID"], [(code(pkg),) for pkg in packages])
    return page("Windows packages", "run_once_install-packages-windows.ps1.tmpl", body)


def render_simple_list(title: str, source: str, intro: str, items: list[str], header: str) -> str:
    body = f"{intro}\n\n**{len(items)} entries.**\n\n" + table([header], [(code(item),) for item in items])
    return page(title, source, body)


def render_pairs(title: str, source: str, intro: str, pairs: list[tuple[str, str]], headers: Sequence[str]) -> str:
    body = f"{intro}\n\n**{len(pairs)} entries.**\n\n" + table(headers, [(code(a), code(b)) for a, b in pairs])
    return page(title, source, body)


def render_macos_defaults(rows: list[p.DefaultsEntry]) -> str:
    body = f"**{len(rows)} `defaults write` calls**, run once per content hash on non-headless macOS. "
    body += "Dock, Finder and SystemUIServer are restarted afterwards.\n\n"
    for section, items in grouped(rows, lambda r: r.section).items():
        body += f"## {text(section)}\n\n"
        body += table(
            ["Domain", "Key", "Type", "Value", "Scope"],
            [(code(r.domain), code(r.key), r.kind, code(r.value), "current host" if r.current_host else "user") for r in items],
        )
    return page("macOS defaults", "run_once_after_macos-defaults.sh.tmpl", body)


def render_nvim(servers: list[str], parsers_: list[str], plugins: list[str]) -> str:
    body = "## Language servers (mason `ensure_installed`)\n\n" + table(["Server"], [(code(s),) for s in servers])
    body += "## Tree-sitter parsers\n\n" + table(["Parser"], [(code(s),) for s in parsers_])
    body += "## Plugins (lazy.nvim)\n\n" + table(["Repository"], [(f"[{slug}](https://github.com/{slug})",) for slug in plugins])
    return page("Neovim", "dot_config/nvim/", body)


def render_tips(tips: list[tuple[str, str]]) -> str:
    body = f"**{len(tips)} tips.** One is printed at random on every interactive zsh start.\n\n"
    for section, items in grouped(tips, lambda t: t[0]).items():
        body += f"## {text(section)}\n\n" + "\n".join(f"- {text(tip)}" for _, tip in items) + "\n\n"
    return page("Shell tips", "dot_config/dotfiles/tips", body)


def render_files(sources: list[str], ignored: list[str]) -> str:
    body = "Every tracked source file and where chezmoi puts it. Rows marked *not deployed* are "
    body += "unconditionally excluded by `.chezmoiignore`; per-profile exclusions are on the Profiles page.\n\n"
    rows = []
    for source in sources:
        info = p.source_to_target(source)
        if source in ignored or source.split("/")[0] in ignored:
            rows.append((code(source), "*not deployed*", ""))
            continue
        flags = (("template", info.is_template), ("private", info.is_private), ("executable", info.is_executable), ("script", info.is_script))
        rows.append((code(source), code(info.target), ", ".join(name for name, on in flags if on)))
    body += table(["Source", "Target", "Attributes"], rows)
    return page("File inventory", "git ls-files", body)


def render_summary(counts: dict[str, int]) -> str:
    body = "Headline numbers for the current `main`.\n\n" + table(["Inventory", "Count"], [(k, str(v)) for k, v in counts.items()])
    return page("Summary", "all generated pages", body)
