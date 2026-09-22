# Shell & prompt

*Reviewed against `ada9e1c`, 2026-09-22.* Files: `dot_zshenv.tmpl`, `dot_zprofile.tmpl`, `dot_zshrc.tmpl`,
`dot_zsh_plugins.txt`, `dot_config/starship.toml`, `dot_config/atuin/config.toml`, `dot_config/mise/config.toml`,
`dot_config/direnv/direnvrc`, `dot_tmux.conf`, `Documents/PowerShell/Microsoft.PowerShell_profile.ps1.tmpl`.

## `~/.zshenv` — every zsh, including non-interactive

| Setting | Value | Note |
|---|---|---|
| `XDG_CONFIG_HOME` / `CACHE` / `DATA` / `STATE` | `~/.config`, `~/.cache`, `~/.local/share`, `~/.local/state` | only if unset |
| `EDITOR`, `VISUAL` | `nvim` | |
| `PAGER`, `LESS` | `less`, `-FRX` | quit-if-one-screen, raw colour, no init |
| Rust | sources `~/.cargo/env` if present | |
| `PATH` | prepends `~/.local/bin:~/bin` | |
| `GPG_TTY` | `$(tty)` | so pinentry attaches to the right terminal |
| `_ZO_DOCTOR` | `0` | silences zoxide's "not initialised last" warning in tooling shells |

## `~/.zprofile` — login shells

macOS: `eval "$(brew shellenv)"` from `/opt/homebrew` or `/usr/local`. Linux: same for Linuxbrew if
`/home/linuxbrew/.linuxbrew/bin/brew` exists (it is never installed by these dotfiles).

## `~/.zshrc` — interactive shells

**History.** `~/.local/state/zsh/history`, 1,000,000 lines, `EXTENDED_HISTORY`, `HIST_EXPIRE_DUPS_FIRST`,
`HIST_IGNORE_DUPS`, `HIST_IGNORE_SPACE`, `HIST_VERIFY`, `INC_APPEND_HISTORY`, `SHARE_HISTORY`.
Atuin then takes over `Ctrl-R`; the up arrow stays with zsh (`--disable-up-arrow`) and is bound to
history-substring-search.

**Options.** `AUTO_CD`, `AUTO_PUSHD`, `PUSHD_IGNORE_DUPS`, `PUSHD_SILENT`, `INTERACTIVE_COMMENTS`, `NO_BEEP`,
`PROMPT_SUBST`, `COMPLETE_IN_WORD`, `ALWAYS_TO_END`.

**Completion.** `compinit` with the dump at `~/.cache/zsh/zcompdump-$ZSH_VERSION`; the security audit is
skipped (`-C`) when the dump is under 24 hours old. Menu selection, case-insensitive matching,
`LS_COLORS` in listings, fzf-tab with a 50 % reverse bordered window.

**Plugin manager.** antidote from the Homebrew prefix on macOS, `~/.antidote` elsewhere (cloned on the fly
if missing). Plugins: [generated list](../generated/zsh-plugins.md).

**Eval cache.** `starship init`, `mise activate`, `fzf --zsh`, `atuin init`, `direnv hook`, `gh completion`,
`flux completion` (macOS) and `zoxide init` all print static scripts. `_evalcache` stores each in
`~/.cache/zsh/evalcache/` and re-generates only when the binary or `.zshrc` is newer. This was measured
at roughly 1.5 s saved per shell start. Each block is a no-op when the tool is absent.

**Tool hooks.**

| Tool | Hook | Effect |
|---|---|---|
| starship | `starship init zsh` | prompt (below) |
| mise | `mise activate zsh` | per-directory runtime versions on `PATH` |
| fzf | `fzf --zsh`; `FZF_DEFAULT_OPTS="--height=50% --layout=reverse --border --info=inline"`; `FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'` when `fd` exists | `Ctrl-T` files, `Alt-C` cd |
| atuin | `atuin init zsh --disable-up-arrow` | `Ctrl-R` synced fuzzy history |
| direnv | `direnv hook zsh` | `.envrc` auto-load |
| gh, flux | completions | |
| zoxide | `zoxide init zsh --cmd cd` — **replaces `cd`** | `cd frag` jumps to the best frecent match; `cdi` interactive |

**Aliases.** [Generated list](../generated/zsh-aliases.md). Notable: `ls`/`l`/`la`/`ll`/`tree` become `eza`,
`cat` becomes `bat --paging=never`, `vi`/`vim` become `nvim`. `k`, `tf`, `dco`, `dps`, `myip`, `serve`, `mkcd`.
On `work` machines an `eitclone org/repo` function clones via the `github-eit` SSH alias into `~/code/eit/`.

**Key bindings.** Emacs mode (`bindkey -e`); up/down = history-substring-search; `Ctrl-→`/`Ctrl-←` word moves.

**macOS-only block.** Bun (`~/.bun`), Android SDK (`~/Library/Android/sdk` emulator + platform-tools on
`PATH`), `JAVA_HOME` = Zulu 17 if installed, iTerm2 shell integration if present. NVM is intentionally gone;
the comment explains the mise migration.

**Random tip.** One non-comment line from `~/.config/dotfiles/tips` on every interactive start, printed with
`printf` so `%` and backticks are safe. Silence per machine with `DOTFILES_NO_TIP=1` in `~/.zshrc.local`.

**Local overrides.** `~/.zshrc.local` is sourced last and is not managed.

## starship (`~/.config/starship.toml`)

- Palette **Catppuccin Mocha** (Frappé, Latte and Macchiato palettes are defined but unused).
- Left powerline: OS icon → user (always shown) → directory (3 segments, `…/`, icon substitutions for
  Documents/Downloads/Music/Pictures/Developer) → git branch + status → language versions
  (c, rust, go, node, bun, php, java, kotlin, haskell, python with venv) → docker context, conda,
  kubernetes (context + namespace, detects `k8s/`, `kustomization.yaml`, `Chart.yaml`, `.kube`, `helm`, `charts`) → time (`%R`) → `cmd_duration` with milliseconds.
- `cmd_duration.show_notifications = true`, `min_time_to_notify = 45000`: a desktop notification after any
  command over 45 s.
- Single-line prompt (`line_break.disabled = true`), `❯` green/red, vim-mode symbols.
- Right side: **identity pill**. Two `custom` modules run `git config user.email` and show `EIT` (peach) or
  `skenmy` (blue). The two emails are hard-coded here, in the git hook and in `allowed_signers`
  ([G-16](../gaps.md#g-16)).
- Windows reads the same file via `$ENV:STARSHIP_CONFIG`.

## atuin (`~/.config/atuin/config.toml`)

| Setting | Value |
|---|---|
| `sync_address` | `https://atuin.skenmy.com` (self-hosted, end-to-end encrypted) |
| `auto_sync` / `sync_frequency` | `true` / `5m` |
| `dialect` | `uk` (dd/mm dates) |
| `update_check` | `false` |
| `search_mode` / `filter_mode` | `fuzzy` / `global`; up-key filter `session` |
| UI | `compact`, inline height 25, preview on (max 4 lines), help shown |
| `history_filter` | commands starting `secret-` or a space are never recorded |

Login and first sync are done by `scripts/bootstrap.sh` from the Bitwarden item `atuin/skenmy.com`.

## mise (`~/.config/mise/config.toml`)

`experimental = true`, `not_found_auto_install = false`, `legacy_version_file = true` (honours
`.nvmrc`, `.python-version`, …). **No global tools pinned**; the `[tools]` block is all comments.

## direnv (`~/.config/direnv/direnvrc`)

Stdlib extensions available to every `.envrc`: `layout mise` (activates the directory's mise toolchain),
`dotenv_if_exists`, `use_flake` (Nix, no-op without `nix`), `use_op VAR op://…` (1Password read).
`strict_env` is on, so `.envrc` typos fail fast.

## tmux (`~/.tmux.conf`)

Prefix `C-a`. `tmux-256color` with RGB overrides, mouse on, 1,000,000-line history, windows and panes
indexed from 1 and renumbered, focus events, 10 ms escape time, 5 s status interval, clipboard passthrough,
vi copy mode (`v` select, `y` copies via `pbcopy` or `xclip`, `r` rectangle). `|` and `-` split in the current
path, `c` new window in current path, `h/j/k/l` navigate, `H/J/K/L` resize by 5, `r` reload. Status bar on top,
transparent, session on the left, date/time/host on the right. TPM bootstraps itself; plugins in the
[generated list](../generated/tmux-plugins.md); continuum restore on, resurrect captures pane contents.

## PowerShell profile (Windows)

UTF-8 output, PSReadLine with history + plugin predictions in list view, `Tab` menu-complete, `Ctrl-R`
reverse search, starship (using the shared `starship.toml`), zoxide (`--cmd cd`), mise, atuin, gh
completion. Aliases `vim`/`vi`→`nvim`, `g`, `k`, `tf`; functions `gs gd gp gl gco gcm ll la .. ...`.
Sources `~/Documents/PowerShell/profile.local.ps1` if present. No tips, no antidote equivalents.
