# Gap register

*Reviewed against `ada9e1c`, 2026-09-22.* Everything found while reading all 64 source files. Each entry
has a stable ID so other pages and PRs can reference it. When you fix one, change its status here
rather than deleting it.

Severity: **High** = something is broken or lands on machines that should not get it ·
**Medium** = works but fragile, inconsistent, or undocumented · **Low** = polish.

| ID | Sev | Profiles | Summary | Status |
|---|---|---|---|---|
| [G-01](#g-01) | High | Linux | Tools the configs depend on are never installed (delta, eza, lazygit, gh, direnv, …) | **fixed** — GitHub release binaries into `~/.local/bin` |
| [G-02](#g-02) | High | Linux | Neovim config needs 0.11+, distros ship 0.7–0.9 | **fixed** — upstream tarball to `~/.local/nvim` when distro nvim < 0.11 |
| [G-03](#g-03) | High | macOS work, macOS headless | Brewfile is not profile-aware: every cask on every Mac | **fixed** — fragments in `.chezmoitemplates/brew/` |
| [G-04](#g-04) | High | macOS | brew-sync re-appends commented lines; 6 duplicates, two cask-name pairs | **fixed** — name-based diff, Brewfile deduped |
| [G-05](#g-05) | High | Windows | No auto-update, no bootstrap, signing key never provisioned, nvim config in wrong place | **fixed** — Scheduled Task, `bootstrap.ps1`, XDG_CONFIG_HOME, ControlMaster guard |
| [G-06](#g-06) | Medium | Linux (Arch, Alpine) | Debian package names break pacman/apk; dead headless branch | **fixed** — per-manager names; headless branch now gates Zed + font |
| [G-07](#g-07) | Medium | all | `authorized_keys` needs GitHub at every apply; personal keys land on work boxes | **fixed** — unmanaged on work; 168h API cache |
| [G-08](#g-08) | Medium | work | Work profile expects `id_ed25519_skenmy` / `_eit`; bootstrap writes `id_ed25519` | **fixed** — bootstrap names the key by the work flag |
| [G-09](#g-09) | Medium | macOS headless | No restic backup on headless Macs — intentional? | **fixed** — decided: headless Macs are backed up |
| [G-10](#g-10) | Medium | docs | README drift (GPG vs SSH signing, themes, age, agents) | **fixed** |
| [G-11](#g-11) | Medium | macOS desktop | VS Code settings hard-code `/Users/paul` | **fixed** — VS Code management removed; Zed replaces it |
| [G-12](#g-12) | Medium | repo | No CI or pre-commit on the repo itself | partly fixed by the docs workflow |
| [G-13](#g-13) | Low | all | Neovim `<C-j>`/`<C-k>` mapped twice | **fixed** — quickfix on `]q`/`[q` |
| [G-14](#g-14) | Low | all | pre-commit defaults pin 2024 revisions | **fixed** — v6.0.0 / v8.30.1 / v2.4.3 |
| [G-15](#g-15) | Low | Windows | Four bash `run_onchange` scripts have no OS guard | **fixed** — ignored on Windows by target name |
| [G-16](#g-16) | Low | all | Identity emails hard-coded in four places | **fixed** — `.chezmoidata/identity.toml` |
| [G-17](#g-17) | Low | Linux desktop | tmux copy assumes `pbcopy`/`xclip`; no Wayland; no Nerd Font installed | **fixed** — `wl-copy` fallback; JetBrainsMono Nerd Font installed on desktops |
| [G-18](#g-18) | Low | macOS | brew-sync commits unsigned, straight to `main` | **fixed** — commits are signed; unsigned fallback removed |
| [G-19](#g-19) | Low | Linux | `chsh` to zsh is manual | **fixed** — installer runs `chsh` when interactive |
| [G-20](#g-20) | Low | all | `me:` URL shortcut renders to `paulwilliams/`, not `skenmy/` | **fixed** — uses `githubUser` |
| [G-21](#g-21) | Medium | all | `.chezmoiignore` script entries used source names, so they never matched | **fixed** — target names |

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

**Fixed.** `install_release_bin` now handles archives and raw binaries and installs delta, eza, lazygit, gh, direnv, yq, tealdeer and xh from GitHub releases; the tealdeer pattern had also never matched its raw-binary assets, so `tldr` was missing too. `btop` moved to the distro list. Kubernetes tooling is still macOS-only by choice. Original options for the record: (a) Extend the existing `install_release_bin` helper to cover `dandavison/delta`,
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

**Fixed.** `neovim` left the distro package list; `install_release_tree` extracts the upstream `nvim-linux-<arch>.tar.gz` to `~/.local/nvim` and symlinks `~/.local/bin/nvim` whenever the nvim on `PATH` is missing or older than 0.11. A version guard in `init.lua` is still a nice-to-have.

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

**Fixed.** `Brewfile` is now rendered by `Brewfile.tmpl` from three fragments, and brew-sync diffs against their union and appends to the fragment named in `~/.config/dotfiles/brew-sync-target` (templated: `common` on work Macs, `personal` elsewhere). Original sketch kept for the record:

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

**Fixed.** `normalise()` in `dotfiles-brew-sync` reduces every line to `kind "name"` before comparing. The fragments were deduped by hand; `brew info` showed `tailscale-app` and `claude-code@latest` as the live casks, so `tailscale` and `claude-code` were dropped. `brew bundle` will not uninstall the stale variants on machines that already have them.

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

**Fixed.** `run_onchange_after_install-update-task.ps1.tmpl` registers the per-user Scheduled Task
`skenmy-chezmoi-update` (daily 03:17, runs when logged on, catches up after sleep) driving the new
`~/.local/bin/chezmoi-update-and-notify.ps1` worker, and sets `XDG_CONFIG_HOME=%USERPROFILE%\.config`
user-wide (the PowerShell profile also sets it per session) so Neovim, atuin and mise read the same
`~/.config` tree as on macOS/Linux. `scripts/bootstrap.ps1` installs chezmoi + `Bitwarden.CLI`, runs
`chezmoi init --apply`, writes the SSH key (named by the `work` flag), imports GPG when a `gpg.exe`
exists, and logs atuin in. `ControlMaster`/`ControlPath`/`ControlPersist` are wrapped in
`{{ if ne .chezmoi.os "windows" }}`. `.config/direnv`, `.config/dotfiles`, `.config/pre-commit`, the
bash workers and every bash run script are ignored on Windows. Still absent on Windows by choice:
restic, tmux, tips, `gh dash`, tealdeer cache refresh.

## G-06 — Linux installer portability {#g-06}

**Evidence.** `COMMON_PKGS` uses Debian names (`fd-find`). Arch and Alpine call it `fd`. `install_pacman`
appends `|| true`, so on Arch the whole transaction fails and nothing installs, silently. `install_apk`
has no `|| true` under `set -e`, so the run_once aborts on Alpine. The `{{ if not .headless }}` /
`{{ else }}` blocks around `COMMON_PKGS+=` are identical, so headless has no effect on Linux packages.

**Fixed.** Each `install_<manager>` passes its own spelling (`fd-find`/`xz-utils` on apt, `fd-find`/`xz` on dnf, `fd`/`xz` on pacman and apk) and `--needed` on pacman; failures are logged and the script continues with a summary. The headless branch now gates Zed and the Nerd Font instead of being a no-op.

## G-07 — `authorized_keys` from GitHub at apply time {#g-07}

**Evidence.** `private_authorized_keys.tmpl` calls `gitHubKeys "skenmy"` unconditionally.

**Impact.** Every `chezmoi apply`, including the nightly one, needs GitHub's API. Offline or during an
outage the whole apply fails (template error), not just this file. Unauthenticated API calls are limited
to 60/hour per IP. Separately, the personal GitHub keys become login-authorised on **work** machines.

**Fixed.** `.ssh/authorized_keys` is listed in `.chezmoiignore` under `{{ if .work }}`, so chezmoi stops managing it on employer machines without touching whatever is there. `.chezmoi.toml.tmpl` sets `gitHub.refreshPeriod = "168h"` so `gitHubKeys` is served from cache between weekly refreshes; **existing boxes only pick that up after `chezmoi init`** (re-renders the config, keeps prompt answers). Remaining risk: a brand-new personal box with no cache and no network still fails its first apply, which is acceptable.

## G-08 — Work profile key names vs bootstrap {#g-08}

**Evidence.** With `work=true`, `.gitconfig`, `.ssh/config` and `build-allowed-signers` expect
`~/.ssh/id_ed25519_skenmy` and `~/.ssh/id_ed25519_eit`. `bootstrap.sh` writes the vault key to
`~/.ssh/id_ed25519` (`SSH_ITEM=ssh/personal/id_ed25519`, name taken from the item). Nothing provisions
the EIT key or documents how to.

**Fixed.** `bootstrap.sh` now runs `chezmoi init --apply` first, then `install_ssh` reads `work` from `chezmoi data` and writes `~/.ssh/id_ed25519_skenmy` on work boxes (`id_ed25519` otherwise), prints a reminder to place the EIT key from 1Password, and runs `chezmoi apply` again so `build-allowed-signers` (whose hash now includes whether the key files exist) rebuilds `allowed_signers`.

## G-09 — Headless Macs have no backup {#g-09}

**Evidence.** `com.skenmy.restic-backup.plist.tmpl` and `install-restic-units` are gated
`and (eq .chezmoi.os "darwin") (not .headless)`; the Linux units are not headless-gated.

**Fixed (decision: back them up).** The `(not .headless)` gate was dropped from the restic plist and from
`install-restic-units`, so every Mac with a `~/.config/restic/env` gets the 04:32 job. brew-sync stays
desktop-only.

## G-10 — README drift {#g-10}

**Fixed.** README now describes SSH signing and the `signingKey` switch, Catppuccin Mocha for starship and
Ghostty, the per-profile SSH agents, and notes that age encryption is not configured. The `signingKey`
prompt text explains what the value does.

## G-11 — VS Code settings hard-code a username {#g-11}

**Fixed by removal.** VS Code settings and the extensions installer were deleted when Zed became the
managed editor (2026-09-22). Zed's settings template contains no machine-specific paths.

## G-12 — No CI on the repo {#g-12}

Before the docs workflow there was no `.github/`. Nothing shellchecks the 13 scripts, renders the
templates for each OS, or runs the repo's own pre-commit defaults. Suggested additions to
`.github/workflows/`: `shellcheck` over `scripts/` and `dot_local/private_bin/`; `chezmoi --source . execute-template`
smoke renders with `--promptBool headless=true,work=true`; a `.pre-commit-config.yaml` copied from
`dot_config/pre-commit/skenmy-defaults.yaml`.

## G-13 — Neovim `<C-j>` / `<C-k>` double-mapped {#g-13}

**Fixed.** Quickfix next/prev moved to `]q` / `[q`; `<C-j>`/`<C-k>` navigate windows again.

## G-14 — pre-commit defaults pinned to 2024 {#g-14}

**Fixed.** Bumped to `pre-commit-hooks v6.0.0`, `gitleaks v8.30.1`, `codespell v2.4.3` (2026-09-22); the
file header now carries the `pre-commit autoupdate -c …` one-liner for next time.

## G-15 — Unguarded bash scripts on Windows {#g-15}

**Fixed.** All eight bash run scripts are listed in the Windows block of `.chezmoiignore` under their
chezmoi target names (see G-21), so Windows never attempts them. Consequence: no GPG import,
`allowed_signers` rebuild, `gh dash` or tealdeer refresh on Windows; `bootstrap.ps1` covers GPG.

## G-16 — Identity emails hard-coded {#g-16}

**Fixed.** `.chezmoidata/identity.toml` (versioned, merged into template data automatically, no re-init) defines `githubUser` and `workEmail`. `dot_gitconfig-eit`, the git hook, `starship.toml` and `build-allowed-signers` became templates that reference them; the personal pill uses the `email` prompt value.

## G-17 — Linux desktop polish {#g-17}

**Fixed.** tmux copy tries `pbcopy`, then `wl-copy`, then `xclip`. Linux desktops get JetBrainsMono Nerd Font in `~/.local/share/fonts/JetBrainsMonoNerdFont` with `fc-cache`.

## G-18 — brew-sync bypasses PR and signing {#g-18}

**Fixed.** `dotfiles-brew-sync` now commits with the machine's normal git config, so commits are SSH-signed. If signing fails under launchd (key unavailable), the change stays staged and is retried on the next run; there is no unsigned fallback. Commits still land directly on `main` by design.

## G-19 — Default shell on Linux {#g-19}

**Fixed.** The installer runs `chsh -s $(command -v zsh)` when stdin is a terminal and `$SHELL` is not zsh; non-interactive applies skip it and print nothing.

## G-21 — `.chezmoiignore` script entries never matched {#g-21}

**Evidence.** Found while adding Windows entries: `chezmoi managed` still listed `install-packages-windows.ps1`
on macOS despite `run_once_install-packages-windows.ps1` being in `.chezmoiignore`. chezmoi strips the
`run_once_`/`run_onchange_`/`before_`/`after_` attributes to form a script's **target name**, and
`.chezmoiignore` matches target names. The original darwin/linux entries were therefore inert; nothing
broke only because every script also had an OS guard inside its template that rendered it empty.

**Fixed.** All script entries use target names (`install-packages-darwin.sh`, `brew-bundle.sh`, …), a
comment at the top of `.chezmoiignore` explains the rule, and the generated
[file inventory](generated/files.md) now shows the target name for every script so the two can be compared.

## G-20 — `me:` shortcut renders the wrong owner {#g-20}

**Fixed.** The `me:` shortcut now renders from `{{ .githubUser }}` → `git@github.com:skenmy/`.
