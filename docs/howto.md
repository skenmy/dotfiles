# How to change things

*Reviewed against `ada9e1c`, 2026-09-22.* Every change follows the same loop; the recipes below only
differ in which file you touch.

## The universal loop

```sh
chezmoi cd                      # or: cd ~/code/personal/dotfiles on a dev box
git switch -c change/<topic>
$EDITOR <source file>           # never the file in $HOME — the nightly apply overwrites it
chezmoi diff                    # preview the rendered change on this machine
chezmoi apply                   # apply here now (optional)
bash -n dot_local/private_bin/executable_*   # if you touched a script
git commit -am "feat: …" && git push -u origin HEAD
gh pr create --fill             # merge → every box picks it up at 03:17 local
```

Rules from `CLAUDE.md`: never edit rendered files on a target machine, never force-push `main`, never
disable or revert SSH commit signing.

## Packages

### Add a package everywhere (macOS)

Append `brew "name"` to `.chezmoitemplates/brew/common.Brewfile` (or `cask "name"` to `gui.Brewfile`, since
casks need a display). Or just `brew install name` on any Mac and let the 02:00 brew-sync commit it to
that machine's target fragment (`common` on work Macs, `personal` elsewhere); move the line afterwards
if it belongs in a different fragment. Either way `brew bundle` re-runs on every affected Mac at the next apply.

### Remove a package everywhere (macOS)

Delete the line from whichever fragment holds it (`grep -rn '"name"' .chezmoitemplates/brew/`). Removing a
line does not uninstall anywhere. On each Mac that should lose it: `brew uninstall name`. If you do not
uninstall locally, brew-sync will re-append the line on that machine's next run unless you also add
`^brew "name"$` to `~/.config/dotfiles/brew-sync-ignore` there.

### Remove a package from one profile only

Move the line between fragments in `.chezmoitemplates/brew/`:

| Move to | Installed on |
|---|---|
| `common.Brewfile` | every Mac |
| `gui.Brewfile` | Macs with `headless = false` |
| `personal.Brewfile` | Macs with `work = false` (regardless of headless) |

Nothing is uninstalled on machines that already have it: run `brew uninstall name` there. brew-sync
diffs against the union of all fragments, so a package gated to another profile is never re-added.
A finer gate (say, personal **and** desktop) means adding a fourth fragment and a matching
`{{ if and (not .work) (not .headless) }}` block in `Brewfile.tmpl`.

For a one-machine exception that should never reach the repo, `brew uninstall name` plus a line in
`~/.config/dotfiles/brew-sync-ignore`; note the next fragment change re-runs `brew bundle` and
reinstalls anything still listed for that profile.

### Add or remove a Linux package

Distro packages: edit the `COMMON_PKGS=(…)` array in `run_once_install-packages-linux.sh.tmpl` (Debian
names; see [G-06](gaps.md#g-06)). Upstream tools: copy one of the `if ! command -v X` blocks, or add a
`command -v X >/dev/null || install_release_bin "owner/repo" "X" "<asset regex>"` line. Changing the
script changes its hash, so it re-runs once on every Linux box.

### Add or remove a Windows package

Edit the `$packages = @(…)` array in `run_once_install-packages-windows.ps1.tmpl` with the exact winget ID
(`winget search name`).

### VS Code extension

Append the `publisher.name` ID to `dot_config/code/extensions.txt`. Removal from the file does not
uninstall; run `code --uninstall-extension id` where needed.

### Neovim plugin, LSP server, or parser

Plugin: add a spec table to the right file in `dot_config/nvim/lua/plugins/`. LSP: add the mason
server name to `servers` in `lsp.lua`. Parser: add to the `install({…})` list in `treesitter.lua`.
lazy.nvim and mason pick them up on the next `nvim` start.

### zsh plugin

One line in `dot_zsh_plugins.txt` in antidote syntax (`owner/repo`, optional `kind:defer`,
`path:plugins/x`). antidote rebuilds its bundle on the next shell.

## Settings

### Change a setting globally

Edit the template or config in the source tree (`dot_zshrc.tmpl`, `dot_gitconfig.tmpl`,
`dot_config/starship.toml`, …), run the loop. There is no separate "global" layer: every file is global
unless wrapped in a `{{ if }}`.

### Change a setting for one profile

Wrap the lines in a chezmoi guard inside the template. Available conditions:

```
{{ if eq .chezmoi.os "darwin" }} … {{ end }}        # darwin | linux | windows
{{ if .headless }} … {{ end }}   /  {{ if not .headless }}
{{ if .work }} … {{ end }}       /  {{ if not .work }}
{{ if and (eq .chezmoi.os "darwin") (not .headless) }} … {{ end }}
```

Static files (`dot_tmux.conf`, `dot_config/ghostty/config`, `Brewfile`, VS Code `settings.json`) must be
renamed with a `.tmpl` suffix first (`chezmoi chattr +template <target>` or `git mv`).

### Stop a whole file from reaching a profile

Add a line to `.chezmoiignore` inside the matching block. Paths are **target** paths (`.config/ghostty`,
not `dot_config/ghostty`). Existing blocks cover `ne .chezmoi.os "<os>"`, `eq .chezmoi.os "windows"`,
`.headless`, `not .work`.

### Override on one machine without touching the repo

| Want | Edit (unmanaged, survives apply) |
|---|---|
| shell env, aliases, `DOTFILES_NO_TIP=1` | `~/.zshrc.local` |
| ssh host entries | `~/.ssh/config.local` |
| extra login keys | `~/.ssh/authorized_keys.local` |
| keep a brew package off the shared Brewfile | `~/.config/dotfiles/brew-sync-ignore` |
| PowerShell extras | `~/Documents/PowerShell/profile.local.ps1` |
| flip `headless` / `work` / email | `chezmoi edit-config` then `chezmoi apply` |

### Change a timer schedule

macOS: `Hour`/`Minute` in the plist under `Library/LaunchAgents/`. Linux: `OnCalendar=` in the `.timer`
under `dot_config/systemd/user/`. The matching `run_onchange_after_install-*` script hashes the unit
files, so it reloads the agent or timer automatically on apply.

### Change a macOS default

Add or edit a `defaults write` line in `run_once_after_macos-defaults.sh.tmpl`, keeping the
`# ---- Section ----` headers (the generated page groups by them). The script re-runs once on every
non-headless Mac because its hash changed, and restarts Dock/Finder.

### Add a shell tip

One line in `dot_config/dotfiles/tips` under the right `# ── section ──` header. No unbalanced backticks.
Check: `awk '/^[^#]/ && NF' dot_config/dotfiles/tips | wc -l` should go up by one.

### Add a new automation

Create `run_onchange_after_<name>.sh.tmpl`. Guard it (`{{ if eq .chezmoi.os "darwin" }}` etc.), add
`# hash: {{ include "<file>" | sha256sum }}` for every file whose change should re-trigger it, `set -uo
pipefail`, exit 0 on soft failures. See `run_onchange_after_install-code-extensions.sh.tmpl` as a model.

## Secrets

Rotate a secret: update it locally, run `~/.local/share/chezmoi/scripts/seed-bitwarden.sh` on that
machine (upserts the four items), then re-run `scripts/bootstrap.sh` on other boxes. Never commit
anything private; the repo is public.

## Keep this site accurate

- **Generated pages** need nothing: the `docs` workflow rebuilds them from `main` on every push.
- **Hand-written pages** (`docs/*.md`, `docs/settings/*.md`, `docs/packages/index.md`) each carry a
  *Reviewed against `<sha>`* line. When you change a template, script or `.chezmoiignore`, update the
  relevant page in the same PR and bump the SHA. The Profiles matrix is the most drift-prone.
- **Gap register:** change an entry's status when you fix it; add new IDs at the end; never renumber.
- **Preview locally:**

```sh
PYTHONPATH=scripts python3 -m docsgen        # writes docs/generated/ (gitignored)
uvx --with mkdocs-material mkdocs serve      # http://127.0.0.1:8000
python3 -m unittest discover -s scripts -p 'test_*.py'   # parser tests
```

- **Add a generated inventory:** write a parser in `scripts/docsgen/parsers.py` with a test in
  `scripts/docsgen/tests/`, a renderer in `render.py`, wire it in `__main__.py`, add the page to `nav`
  in `mkdocs.yml`. `mkdocs build --strict` fails the build if a nav entry is missing.
- **Publishing:** GitHub Pages must be set to *Source: GitHub Actions* once (Settings → Pages). The
  workflow's `configure-pages` step also attempts to enable it. The site lives at
  <https://skenmy.github.io/dotfiles/>.
