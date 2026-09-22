"""Unit tests for the docs inventory parsers.

Run: python3 -m unittest discover -s scripts -p 'test_*.py'
"""
import unittest

from docsgen import parsers as p


class BrewfileTests(unittest.TestCase):
    SAMPLE = """# Shell + prompt
brew "zsh"
brew "tealdeer"       # fast `tldr` pages

# Kubernetes
brew "fluxcd/tap/flux"
cask "ghostty"

# auto-synced from Mac on 2026-07-04
brew "tealdeer"
tap "fluxcd/tap"
"""

    def test_parses_kind_name_note_and_section(self):
        entries = p.parse_brewfile(self.SAMPLE)
        self.assertEqual(entries[0], p.BrewEntry("brew", "zsh", "", "Shell + prompt", 2))
        self.assertEqual(entries[1].note, "fast `tldr` pages")
        self.assertEqual(entries[2].section, "Kubernetes")
        self.assertEqual(entries[4].kind, "brew")
        self.assertEqual(entries[5].kind, "tap")

    def test_finds_duplicates_regardless_of_trailing_comment(self):
        dupes = p.find_duplicates(p.parse_brewfile(self.SAMPLE))
        self.assertEqual(list(dupes), ['brew "tealdeer"'])
        self.assertEqual([e.line for e in dupes['brew "tealdeer"']], [3, 10])

    def test_auto_synced_sections_are_flagged(self):
        entries = p.parse_brewfile(self.SAMPLE)
        self.assertFalse(entries[0].is_auto_synced)
        self.assertTrue(entries[4].is_auto_synced)

    def test_fragment_label_is_carried_and_defaults_empty(self):
        self.assertEqual(p.parse_brewfile(self.SAMPLE)[0].fragment, "")
        self.assertEqual(p.parse_brewfile(self.SAMPLE, "gui")[0].fragment, "gui")

    def test_duplicates_are_found_across_fragments(self):
        entries = [*p.parse_brewfile('brew "zsh"\n', "common"), *p.parse_brewfile('brew "zsh"\n', "personal")]
        dupes = p.find_duplicates(entries)
        self.assertEqual([e.fragment for e in dupes['brew "zsh"']], ["common", "personal"])


class BashTests(unittest.TestCase):
    SCRIPT = """COMMON_PKGS=(git curl zsh)
{{- if not .headless }}
COMMON_PKGS+=(neovim ripgrep)
{{- else }}
COMMON_PKGS+=(neovim ripgrep)
{{- end }}
EXTRAS_VIA_BIN=(starship mise)

if ! command -v starship >/dev/null; then
    curl -sS https://starship.rs/install.sh | sh
fi
if ! command -v mise >/dev/null; then
    curl -fsSL https://mise.run | sh
fi
command -v tldr >/dev/null || install_release_bin "dbrgn/tealdeer" "tldr" "x"
command -v brew >/dev/null 2>&1 || { echo "no"; exit 0; }
"""

    def test_bash_array_merges_and_dedupes(self):
        self.assertEqual(p.parse_bash_array(self.SCRIPT, "COMMON_PKGS"), ["git", "curl", "zsh", "neovim", "ripgrep"])

    def test_bash_array_missing_returns_empty(self):
        self.assertEqual(p.parse_bash_array(self.SCRIPT, "NOPE"), [])

    def test_guarded_installs_are_found_with_their_method(self):
        installs = p.parse_guarded_installs(self.SCRIPT)
        self.assertEqual(installs, [
            p.GuardedInstall("starship", "curl -sS https://starship.rs/install.sh | sh"),
            p.GuardedInstall("mise", "curl -fsSL https://mise.run | sh"),
            p.GuardedInstall("tldr", 'install_release_bin "dbrgn/tealdeer" "tldr" "x"'),
        ])


class WingetTests(unittest.TestCase):
    def test_parses_package_ids(self):
        text = '$packages = @(\n    "Git.Git",\n    "GitHub.cli"\n)\nforeach ($pkg in $packages) {}'
        self.assertEqual(p.parse_winget_packages(text), ["Git.Git", "GitHub.cli"])


class LineListTests(unittest.TestCase):
    def test_skips_comments_and_blanks(self):
        self.assertEqual(p.parse_line_list("# c\n\na\n b \n"), ["a", "b"])

    def test_tips_grouped_by_section_header(self):
        text = "# intro\n# ── core CLI ─────\ntip one\n# ── git ──\ntip two\n"
        self.assertEqual(p.parse_tips(text), [("core CLI", "tip one"), ("git", "tip two")])

    def test_tips_before_any_header_land_in_general(self):
        self.assertEqual(p.parse_tips("tip zero\n"), [("General", "tip zero")])


class MacosDefaultsTests(unittest.TestCase):
    SCRIPT = """# ---- Keyboard ----
defaults write NSGlobalDomain KeyRepeat -int 2
# ---- Trackpad ----
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
defaults write com.apple.Safari IncludeDevelopMenu -bool true 2>/dev/null || true
"""

    def test_parses_domain_key_type_value_and_section(self):
        rows = p.parse_macos_defaults(self.SCRIPT)
        self.assertEqual(rows[0], p.DefaultsEntry("Keyboard", "NSGlobalDomain", "KeyRepeat", "int", "2", False))
        self.assertEqual(rows[1].current_host, True)
        self.assertEqual(rows[2].value, "SCcf")
        self.assertEqual(rows[3], p.DefaultsEntry("Trackpad", "com.apple.Safari", "IncludeDevelopMenu", "bool", "true", False))


class GitAndShellAliasTests(unittest.TestCase):
    def test_git_aliases_only_from_alias_section(self):
        text = "[core]\n    editor = nvim\n[alias]\n    s = status -sb\n    lg = log --graph\n[color]\n    ui = auto\n"
        self.assertEqual(p.parse_git_aliases(text), [("s", "status -sb"), ("lg", "log --graph")])

    def test_shell_aliases(self):
        text = "alias g='git'\nalias ll=\"eza -lh\"\n  alias vi='nvim'\nnot an alias\n"
        self.assertEqual(p.parse_shell_aliases(text), [("g", "git"), ("ll", "eza -lh"), ("vi", "nvim")])


class LuaTests(unittest.TestCase):
    def test_string_list_after_anchor(self):
        text = 'local servers = { "lua_ls", "gopls",\n "pyright" }\nother = { "x" }'
        self.assertEqual(p.parse_lua_string_list(text, "local servers ="), ["lua_ls", "gopls", "pyright"])

    def test_plugin_repos(self):
        text = '{ "lewis6991/gitsigns.nvim", opts = {} },\n"folke/which-key.nvim",\n"not a repo"'
        self.assertEqual(p.parse_repo_slugs(text), ["lewis6991/gitsigns.nvim", "folke/which-key.nvim"])


class TmuxTests(unittest.TestCase):
    def test_plugins(self):
        text = "set -g @plugin 'tmux-plugins/tpm'\nset -g @plugin 'tmux-plugins/tmux-yank'\nset -g mouse on\n"
        self.assertEqual(p.parse_tmux_plugins(text), ["tmux-plugins/tpm", "tmux-plugins/tmux-yank"])


class ChezmoiNamingTests(unittest.TestCase):
    def test_dotfile_and_private(self):
        self.assertEqual(p.source_to_target("dot_zshrc.tmpl"), p.TargetInfo("~/.zshrc", True, False, False, False))
        self.assertEqual(p.source_to_target("private_dot_ssh/private_config.tmpl").target, "~/.ssh/config")
        self.assertTrue(p.source_to_target("private_dot_ssh/private_config.tmpl").is_private)

    def test_executable_bin(self):
        info = p.source_to_target("dot_local/private_bin/executable_restic-backup")
        self.assertEqual(info.target, "~/.local/bin/restic-backup")
        self.assertTrue(info.is_executable)
        self.assertTrue(info.is_private)

    def test_scripts_have_no_target(self):
        info = p.source_to_target("run_onchange_after_brew-bundle.sh.tmpl")
        self.assertTrue(info.is_script)
        self.assertEqual(info.target, "run_onchange_after_brew-bundle.sh")

    def test_plain_files_keep_their_name(self):
        self.assertEqual(p.source_to_target("Brewfile").target, "~/Brewfile")
        self.assertEqual(p.source_to_target("Library/LaunchAgents/x.plist.tmpl").target, "~/Library/LaunchAgents/x.plist")

    def test_unconditional_ignores(self):
        text = '{{- if ne .chezmoi.os "darwin" }}\nBrewfile\n{{- end }}\n\nREADME.md\nscripts\n'
        self.assertEqual(p.parse_unconditional_ignores(text), ["README.md", "scripts"])


if __name__ == "__main__":
    unittest.main()
