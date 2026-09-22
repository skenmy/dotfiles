"""Generate the inventory pages under docs/generated/.

Usage (from the repo root):
    python3 -m docsgen            # needs `scripts/` on PYTHONPATH, or:
    PYTHONPATH=scripts python3 -m docsgen [--repo PATH] [--out PATH]
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

from . import parsers as p
from . import render as r

BREW_FRAGMENTS = ("common", "gui", "personal")

LINUX_DISTRO_EXTRAS = {
    "apt": "fd-find, xz-utils, build-essential (+ symlinks batcat→bat, fdfind→fd)",
    "dnf": "fd-find, xz, @development-tools",
    "pacman": "fd, xz, base-devel (--needed)",
    "apk": "fd, xz, build-base",
}


def read(repo: Path, relative: str) -> str:
    path = repo / relative
    if not path.is_file():
        raise SystemExit(f"docsgen: missing source file {relative}")
    return path.read_text(encoding="utf-8")


def tracked_files(repo: Path) -> list[str]:
    result = subprocess.run(["git", "-C", str(repo), "ls-files"], check=True, capture_output=True, text=True)
    return [line for line in result.stdout.splitlines() if line]


def build_pages(repo: Path) -> dict[str, str]:
    brew = [
        entry
        for fragment in BREW_FRAGMENTS
        for entry in p.parse_brewfile(read(repo, f".chezmoitemplates/brew/{fragment}.Brewfile"), fragment)
    ]
    linux_script = read(repo, "run_once_install-packages-linux.sh.tmpl")
    linux_common = p.parse_bash_array(linux_script, "COMMON_PKGS")
    linux_guarded = p.parse_guarded_installs(linux_script)
    winget = p.parse_winget_packages(read(repo, "run_once_install-packages-windows.ps1.tmpl"))
    zed_extensions = p.parse_zed_extensions(read(repo, ".chezmoitemplates/zed-settings.json"))
    zsh_plugins = p.parse_line_list(read(repo, "dot_zsh_plugins.txt"))
    git_aliases = p.parse_git_aliases(read(repo, "dot_gitconfig.tmpl"))
    zsh_aliases = p.parse_shell_aliases(read(repo, "dot_zshrc.tmpl"))
    defaults = p.parse_macos_defaults(read(repo, "run_once_after_macos-defaults.sh.tmpl"))
    servers = p.parse_lua_string_list(read(repo, "dot_config/nvim/lua/plugins/lsp.lua"), "local servers =")
    parsers_ = p.parse_lua_string_list(read(repo, "dot_config/nvim/lua/plugins/treesitter.lua"), "install(")
    plugin_dir = repo / "dot_config/nvim/lua/plugins"
    plugins = p.parse_repo_slugs("\n".join(f.read_text(encoding="utf-8") for f in sorted(plugin_dir.glob("*.lua"))))
    tmux = p.parse_tmux_plugins(read(repo, "dot_tmux.conf"))
    tips = p.parse_tips(read(repo, "dot_config/dotfiles/tips"))
    ignored = p.parse_unconditional_ignores(read(repo, ".chezmoiignore"))
    sources = tracked_files(repo)

    counts = {
        "Brewfile entries": len(brew),
        "Brewfile duplicates": len(p.find_duplicates(brew)),
        "Linux distro packages": len(linux_common),
        "Linux upstream installs": len(linux_guarded),
        "Windows winget packages": len(winget),
        "Zed extensions": len(zed_extensions),
        "zsh plugins": len(zsh_plugins),
        "git aliases": len(git_aliases),
        "zsh aliases": len(zsh_aliases),
        "macOS defaults": len(defaults),
        "Neovim LSP servers": len(servers),
        "Neovim tree-sitter parsers": len(parsers_),
        "Neovim plugins": len(plugins),
        "tmux plugins": len(tmux),
        "Shell tips": len(tips),
        "Tracked source files": len(sources),
    }

    return {
        "summary.md": r.render_summary(counts),
        "brewfile.md": r.render_brewfile(brew),
        "linux.md": r.render_linux(linux_common, linux_guarded, LINUX_DISTRO_EXTRAS),
        "windows.md": r.render_windows(winget),
        "zed-extensions.md": r.render_pairs(
            "Zed extensions", ".chezmoitemplates/zed-settings.json",
            "Declared under `auto_install_extensions`; Zed installs them itself on launch, on every OS. "
            "Removing a line stops future installs but does not uninstall.",
            [(name, "install" if on else "skip") for name, on in zed_extensions], ["Extension", "Action"]),
        "zsh-plugins.md": r.render_simple_list(
            "zsh plugins", "dot_zsh_plugins.txt",
            "Loaded by antidote on every interactive zsh. `kind:defer` loads after the first prompt.",
            zsh_plugins, "Plugin spec"),
        "git-aliases.md": r.render_pairs(
            "git aliases", "dot_gitconfig.tmpl", "From the `[alias]` block of the rendered `~/.gitconfig`.",
            git_aliases, ["Alias", "Expands to"]),
        "zsh-aliases.md": r.render_pairs(
            "zsh aliases", "dot_zshrc.tmpl", "Static aliases only; conditional ones (eza, bat) apply when the tool is installed.",
            zsh_aliases, ["Alias", "Expands to"]),
        "macos-defaults.md": r.render_macos_defaults(defaults),
        "nvim.md": r.render_nvim(servers, parsers_, plugins),
        "tmux-plugins.md": r.render_simple_list(
            "tmux plugins", "dot_tmux.conf", "Managed by TPM, which is cloned on first `tmux` start if missing.",
            tmux, "Plugin"),
        "tips.md": r.render_tips(tips),
        "files.md": r.render_files(sources, ignored),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="docsgen", description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--out", type=Path, default=None)
    args = parser.parse_args(argv)
    out = args.out or (args.repo / "docs" / "generated")
    out.mkdir(parents=True, exist_ok=True)
    pages = build_pages(args.repo)
    for name, content in pages.items():
        (out / name).write_text(content, encoding="utf-8")
    print(f"docsgen: wrote {len(pages)} pages to {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
