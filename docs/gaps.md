# Gap register

*Reviewed against `ada9e1c`, 2026-09-22.* Everything found while reading all 64 source files. Each entry
has a stable ID so other pages and PRs can reference it. When you fix one, change its status here
rather than deleting it.

Severity: **High** = something is broken or lands on machines that should not get it ·
**Medium** = works but fragile, inconsistent, or undocumented · **Low** = polish.

| ID | Sev | Profiles | Summary | Status |
|---|---|---|---|---|
| [G-01](#g-01) | High | Linux | Tools the configs depend on are never installed (delta, eza, lazygit, gh, direnv, …) | open |
| [G-02](#g-02) | High | Linux | Neovim config needs 0.11+, distros ship 0.7–0.9 | open |
| [G-03](#g-03) | High | macOS work, macOS headless | Brewfile is not profile-aware: every cask on every Mac | open |
| [G-04](#g-04) | High | macOS | brew-sync re-appends commented lines; 6 duplicates, two cask-name pairs | open |
| [G-05](#g-05) | High | Windows | No auto-update, no bootstrap, signing key never provisioned, nvim config in wrong place | open |
| [G-06](#g-06) | Medium | Linux (Arch, Alpine) | Debian package names break pacman/apk; dead headless branch | open |
| [G-07](#g-07) | Medium | all | `authorized_keys` needs GitHub at every apply; personal keys land on work boxes | open |
| [G-08](#g-08) | Medium | work | Work profile expects `id_ed25519_skenmy` / `_eit`; bootstrap writes `id_ed25519` | open |
| [G-09](#g-09) | Medium | macOS headless | No restic backup on headless Macs — intentional? | decision needed |
| [G-10](#g-10) | Medium | docs | README drift (GPG vs SSH signing, themes, age, agents) | open |
| [G-11](#g-11) | Medium | macOS desktop | VS Code settings hard-code `/Users/paul` | open |
| [G-12](#g-12) | Medium | repo | No CI or pre-commit on the repo itself | partly fixed by the docs workflow |
| [G-13](#g-13) | Low | all | Neovim `<C-j>`/`<C-k>` mapped twice | open |
| [G-14](#g-14) | Low | all | pre-commit defaults pin 2024 revisions | open |
| [G-15](#g-15) | Low | Windows | Four bash `run_onchange` scripts have no OS guard | open |
| [G-16](#g-16) | Low | all | Identity emails hard-coded in four places | open |
| [G-17](#g-17) | Low | Linux desktop | tmux copy assumes `pbcopy`/`xclip`; no Wayland; no Nerd Font installed | open |
| [G-18](#g-18) | Low | macOS | brew-sync commits unsigned, straight to `main` | accepted trade-off, revisit |
| [G-19](#g-19) | Low | Linux | `chsh` to zsh is manual | open |
| [G-20](#g-20) | Low | all | `me:` URL shortcut renders to `paulwilliams/`, not `skenmy/` | open |

---

## G-01 — Linux: required tools never installed {#g-01}

**Evidence.** `run_once_install-packages-linux.sh.tmpl` declares
`EXTRAS_VIA_BIN=(starship mise atuin zoxide eza lazygit delta gh)` but only starship, mise, atuin and
zoxide have install blocks. `delta`, `eza`, `lazygit`, `gh` are never installed. Neither are `direnv`,
`yq`, `btop`, `k9s`, `kubectl`, `helm`, `terraform`, `pre-commit`, `mkcert`, `uv`.

**Impact.** `~/.gitconfig` sets `core.pager = delta` and `interactive.diffFilter = delta`, and
`~/.config/chezmoi/chezmoi.toml` sets `diff.pager = "delta --paging=never"`. On every Linux box
`git diff`/`git log` print an error before falling back to plain output, and `chezmoi diff` fails outright.
`ls` keeps its `eza` aliases only because they are guarded; `k`, `tf`, `lzg` are dead aliases.

**Fix options.** (a) Extend the existing `install_release_bin` helper to cover `dandavison/delta`,
`eza-community/eza`, `jesseduffield/lazygit`, `cli/cli`, `direnv/direnv`, `mikefarah/yq`. (b) Install
Linuxbrew in the Linux script and reuse the Brewfile minus casks (`~/.zprofile` already loads it). Option
(a) keeps servers lean; (b) unifies the inventory. Either way, gate `core.pager` on `lookPath "delta"`
in the template so git degrades cleanly.

## G-02 — Linux: Neovim too old for the config {#g-02}

**Evidence.** `lsp.lua` calls `vim.lsp.config("*", …)` and relies on mason-lspconfig v2 auto-enable
(`vim.lsp.enable`), both Neovim 0.11 APIs. `treesitter.lua` targets the nvim-treesitter `main` branch,
which also requires 0.11 (its README says 0.11+). The Linux installer gets `neovim` from the distro:
Ubuntu 24.04 ships 0.9.5, Debian 12 ships 0.7.2.

**Impact.** On Linux, `nvim` starts with Lua errors and no LSP or tree-sitter.

**Fix.** Install from the upstream release tarball into `~/.local` (or `mise use -g neovim@latest`,
which uses the GitHub release) instead of the distro package, and pin a minimum in `init.lua` with
`vim.fn.has("nvim-0.11")` plus a clear message.

## G-03 — Brewfile is not profile-aware {#g-03}

**Evidence.** `Brewfile` is a plain file; the only profile influence is `--no-upgrade` on headless.
All 17 casks — Spotify, Telegram, Battle.net, Wireshark, Logi Options+, Raycast, Docker Desktop, Ghostty,
iTerm2, Claude Code (twice), OpenClaw, Tailscale (twice), Zulu 17, two fonts — plus heavyweights such as
`dotnet`, `ollama`, `whisper-cpp`, `ffmpeg`, `tesseract`, `streamlink`, `powershell` install on every Mac.

**Impact.** Work Macs get personal apps (Spotify, Battle.net, Telegram) and the Tailscale cask even
though the README says work boxes use the employer-managed Tailscale. Docker Desktop on an employer
machine may need a paid licence. Headless Macs pull down GUI apps and fonts they cannot use.
"Remove a package for one profile" is currently impossible from source; see the
[how-to](howto.md#remove-a-package-from-one-profile-only).

**Fix sketch.** Split into fragments and render one `Brewfile` from a template:

```
Brewfile.tmpl:
  {{ include "brew/common.Brewfile" }}
  {{ if not .headless }}{{ include "brew/gui.Brewfile" }}{{ end }}
  {{ if not .work }}{{ include "brew/personal.Brewfile" }}{{ end }}
```

`run_onchange_after_brew-bundle.sh.tmpl` hashes all fragments. `dotfiles-brew-sync` must then diff
against the **union** of fragments and append to a target fragment chosen per machine (default
`common`; a `BREW_SYNC_TARGET` line in `~/.config/dotfiles/brew-sync-ignore` or a new config file), or
it will re-add personal casks to `common` from personal Macs. Do this together with G-04.

## G-04 — brew-sync duplicates {#g-04}

**Evidence.** `extract_pkgs()` in `dotfiles-brew-sync` is `grep -E '^(brew|cask|tap|mas) ' | sort -u`
on whole lines. Original lines such as `brew "tealdeer"       # fast tldr pages` never equal the dump's
`brew "tealdeer"`, so they were appended again on 2026-07-04. The generated
[Brewfile page](generated/brewfile.md) lists the six current duplicates with line numbers. The same
run added `cask "claude-code@latest"` next to `cask "claude-code"` and `cask "tailscale-app"` next to
`cask "tailscale"`, so each Mac now tries to install both variants.

**Fix.** Normalise before comparing: strip trailing comments and whitespace (`sed -E 's/[[:space:]]*#.*$//'`)
and compare the `kind "name"` token only. Then dedupe the Brewfile by hand once and pick one cask name
per pair (`brew info --cask tailscale tailscale-app claude-code claude-code@latest` shows which are
current).

## G-05 — Windows is a second-class profile {#g-05}

**Evidence.**

- No scheduled `chezmoi update`; `Library/` and `.config/systemd` are both ignored on Windows and no
  Task Scheduler equivalent exists.
- `bootstrap.sh` tells Windows users to run `scripts/bootstrap.ps1`, which is not in the repo. No
  Bitwarden pull, so no GPG/SSH/atuin/restic secrets.
- `~/.gitconfig` renders `commit.gpgsign = true` with `signingkey = ~/.ssh/id_ed25519.pub`, which nothing
  creates on Windows. Every commit fails until the key is placed or `signingKey` is blanked.
- `dot_config/nvim` lands in `~/.config/nvim`; Neovim on Windows reads `%LOCALAPPDATA%\nvim` unless
  `XDG_CONFIG_HOME` is set, and the PowerShell profile does not set it.
- `~/.ssh/config` sets `ControlMaster`/`ControlPath`, which Windows OpenSSH does not support.
- `~/.config/dotfiles/tips` and `~/.config/direnv/direnvrc` are deployed with nothing to consume them.

**Fix.** Add `run_once_after_register-update-task.ps1.tmpl` using `Register-ScheduledTask`; write
`scripts/bootstrap.ps1` (Bitwarden CLI is available via winget as `Bitwarden.CLI`); wrap the
`ControlMaster` block in `{{ if ne .chezmoi.os "windows" }}`; either set `$env:XDG_CONFIG_HOME = "$HOME\.config"`
in the PowerShell profile or add a Windows-only `AppData/Local/nvim` source; ignore `.config/direnv`
and `.config/dotfiles` on Windows.

## G-06 — Linux installer portability {#g-06}

**Evidence.** `COMMON_PKGS` uses Debian names (`fd-find`). Arch and Alpine call it `fd`. `install_pacman`
appends `|| true`, so on Arch the whole transaction fails and nothing installs, silently. `install_apk`
has no `|| true` under `set -e`, so the run_once aborts on Alpine. The `{{ if not .headless }}` /
`{{ else }}` blocks around `COMMON_PKGS+=` are identical, so headless has no effect on Linux packages.

**Fix.** A per-manager name map (`declare -A`) or install `fd`/`bat` from release binaries everywhere.
Delete the dead headless branch or give it a purpose (skip `neovim`, `ripgrep`, `bat` on servers).

## G-07 — `authorized_keys` from GitHub at apply time {#g-07}

**Evidence.** `private_authorized_keys.tmpl` calls `gitHubKeys "skenmy"` unconditionally.

**Impact.** Every `chezmoi apply`, including the nightly one, needs GitHub's API. Offline or during an
outage the whole apply fails (template error), not just this file. Unauthenticated API calls are limited
to 60/hour per IP. Separately, the personal GitHub keys become login-authorised on **work** machines.

**Fix.** Gate with `{{ if not .work }}`; set `gitHub.refreshPeriod` in `.chezmoi.toml.tmpl` (chezmoi caches
`gitHubKeys` responses when a refresh period is set); consider a `GITHUB_TOKEN` for the rate limit.

## G-08 — Work profile key names vs bootstrap {#g-08}

**Evidence.** With `work=true`, `.gitconfig`, `.ssh/config` and `build-allowed-signers` expect
`~/.ssh/id_ed25519_skenmy` and `~/.ssh/id_ed25519_eit`. `bootstrap.sh` writes the vault key to
`~/.ssh/id_ed25519` (`SSH_ITEM=ssh/personal/id_ed25519`, name taken from the item). Nothing provisions
the EIT key or documents how to.

**Fix.** In `install_ssh`, read `work` from `chezmoi data` (or a `--work` flag) and write to
`id_ed25519_skenmy` when set; add a README/how-to step for placing `id_ed25519_eit` from 1Password.

## G-09 — Headless Macs have no backup {#g-09}

**Evidence.** `com.skenmy.restic-backup.plist.tmpl` and `install-restic-units` are gated
`and (eq .chezmoi.os "darwin") (not .headless)`; the Linux units are not headless-gated.

**Decision needed.** If a headless Mac (mini, build box) holds nothing worth keeping, record that here
and on the Profiles page. If not, drop the `(not .headless)` from both files.

## G-10 — README drift {#g-10}

`README.md` still says: GPG-signed commits and `signingKey → user.signingkey` (now SSH signing, the
value is a flag); starship "Gruvbox-dark" (Catppuccin Mocha); Ghostty "TokyoNight" (Catppuccin Mocha);
chezmoi-encrypted files "via the existing `~/.age-key`" (no `[age]` section exists); "macOS uses
Keychain + 1Password SSH agent" (now 1Password on work, Bitwarden on personal). The
`.chezmoi.toml.tmpl` prompt text still says "GPG signing key". `CLAUDE.md` is current.

## G-11 — VS Code settings hard-code a username {#g-11}

Four `parallels-desktop.*` keys reference `/Users/paul/…` and `/usr/local/bin/prlctl`. This machine's
home is `/Users/pwilliams`. Make `settings.json` a `.tmpl` using `{{ .chezmoi.homeDir }}`, or drop the
Parallels keys and let the extension re-detect.

## G-12 — No CI on the repo {#g-12}

Before the docs workflow there was no `.github/`. Nothing shellchecks the 13 scripts, renders the
templates for each OS, or runs the repo's own pre-commit defaults. Suggested additions to
`.github/workflows/`: `shellcheck` over `scripts/` and `dot_local/private_bin/`; `chezmoi --source . execute-template`
smoke renders with `--promptBool headless=true,work=true`; a `.pre-commit-config.yaml` copied from
`dot_config/pre-commit/skenmy-defaults.yaml`.

## G-13 — Neovim `<C-j>` / `<C-k>` double-mapped {#g-13}

`keymaps.lua` maps them to window navigation, then to quickfix next/prev. The later mapping wins, so
moving between splits vertically does not work. Move quickfix to `]q` / `[q`.

## G-14 — pre-commit defaults pinned to 2024 {#g-14}

`pre-commit-hooks v5.0.0`, `gitleaks v8.18.4`, `codespell v2.3.0`. Run `pre-commit autoupdate` on the
defaults file periodically.

## G-15 — Unguarded bash scripts on Windows {#g-15}

`build-allowed-signers`, `import-gpg-key`, `install-gh-extensions`, `update-tldr-cache` have no OS guard.
chezmoi on Windows runs `.sh` scripts through `sh` only if one is on `PATH` (Git for Windows); otherwise
apply errors. Wrap each in `{{ if ne .chezmoi.os "windows" }}`.

## G-16 — Identity emails hard-coded {#g-16}

`pwilliams@eit.org` appears in `build-allowed-signers`, the git hook, `dot_gitconfig-eit` and
`starship.toml`; `paul@skenmy.com` in `starship.toml` and as a prompt default. One `eitEmail` value in
`.chezmoi.toml.tmpl` `[data]` would let every template reference it.

## G-17 — Linux desktop polish {#g-17}

tmux copy pipes to `pbcopy` or `xclip` (no `wl-copy` for Wayland). No Nerd Font is installed on Linux,
so starship/eza glyphs render as boxes in a local terminal (fine over SSH from a Mac).

## G-18 — brew-sync bypasses PR and signing {#g-18}

Nightly commits are unsigned and pushed straight to `main`, which otherwise enforces signed commits via
PR. Documented and accepted in the README. Alternatives if it ever matters: push to a `brew-sync` branch
and open a PR with `gh pr create --fill`, or allow the sync script to sign with the on-disk SSH key.

## G-19 — Default shell on Linux {#g-19}

zsh is installed but `chsh` is left to the user (README says so). Could be automated in the run_once
with `chsh -s "$(command -v zsh)"` when `$SHELL` is not zsh.

## G-20 — `me:` shortcut renders the wrong owner {#g-20}

`[url "git@github.com:{{ .name | replace " " "" | lower }}/"] insteadOf = "me:"` renders to
`paulwilliams/`, but the GitHub account is `skenmy`. Use a dedicated `githubUser` data value.
