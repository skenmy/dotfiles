# dotfiles

Cross-platform dotfiles for **macOS, Linux, and Windows**, managed by [chezmoi](https://chezmoi.io).

One source of truth → applied identically to every MacBook, Windows PC, and Linux server I touch.

---

## TL;DR — what to run on a fresh box

### Every box (macOS / Linux)

```sh
curl -fsSL https://raw.githubusercontent.com/skenmy/dotfiles/main/scripts/bootstrap.sh | bash
```

Pulls dotfiles, installs packages, unlocks Bitwarden, restores GPG + SSH + atuin. Re-runnable; every step is a no-op if already done.

### Every Linux **server** (extra one-liner)

```sh
sudo loginctl enable-linger "$USER"
```

Without this, the user-level systemd timer (which runs `chezmoi update` daily) won't fire when you're logged out. Skip on Linux *desktops* you stay logged into.

### Join the tailnet (personal devices only)

```sh
# macOS: open the Tailscale menu-bar app and click "Log in" — installed by bootstrap.
# Linux:
sudo tailscale up --operator="$USER"
```

Tailscale is installed automatically by `bootstrap.sh` on personal boxes (it's skipped when `work=true`). Work boxes use the employer-managed install. Authenticating is interactive (browser-based) and only needed once per device.

### Every Windows box

```powershell
iex "&{$(irm 'https://get.chezmoi.io/ps1')} -b $HOME/.local/bin init --apply skenmy"
```

Note: no Bitwarden integration on Windows yet — GPG / SSH / atuin still need importing by hand.

**That's it for every-box setup.** Everything below is one-time-ever or optional.

---

## Optional / one-time-ever

### Once, on the machine that has all your secrets locally

```sh
# Push atuin key, GPG private key, SSH private key into Bitwarden so bootstrap.sh can pull them on new boxes.
~/.local/share/chezmoi/scripts/seed-bitwarden.sh
```

Only needs to happen the very first time, or whenever you rotate a secret. Existing boxes don't need this.

### Optional UX, macOS only

```sh
# Use Touch ID instead of typing the Bitwarden master password during bootstrap.
security add-generic-password -T '' -s bw-master -a "$USER" -w
```

---

## Quick start

### Just dotfiles + packages (one command)

**macOS / Linux:**
```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply skenmy
```

**Windows (PowerShell):**
```powershell
iex "&{$(irm 'https://get.chezmoi.io/ps1')} -b $HOME/.local/bin init --apply skenmy"
```

That clones the repo, prompts for `name`/`email`/`signingKey`/`headless`/`work`, renders templates into `$HOME`, and runs `run_once_*` scripts to install packages and apply macOS defaults.

### Everything (dotfiles + GPG + SSH + atuin login)

```sh
curl -fsSL https://raw.githubusercontent.com/skenmy/dotfiles/main/scripts/bootstrap.sh | bash
```

`scripts/bootstrap.sh` adds, on top of the chezmoi step above:
- Installs Bitwarden CLI (`bw`) if missing.
- Unlocks the vault — Touch ID via macOS Keychain if the entry `bw-master` exists, otherwise prompts for master password.
- Pulls **GPG private key** from `gpg/9BFD73704EA02674`, imports it + sets ultimate trust.
- Pulls **SSH private key** from `ssh/personal/id_ed25519`, writes to `~/.ssh/` with 0600.
- Stashes **atuin password + encryption key** from `atuin/skenmy.com`, runs `atuin login -u skenmy -p … -k …` after chezmoi has installed atuin, then `atuin import auto && atuin sync -f`.

The schema is whatever `scripts/seed-bitwarden.sh` puts in the vault (see below). All steps are idempotent — re-running is safe.

#### One-time seeding (run on a machine that already has all your secrets)

```sh
~/.local/share/chezmoi/scripts/seed-bitwarden.sh
```

Reads `~/.local/share/atuin/key` and `~/.ssh/id_ed25519`, asks for the atuin password, exports the GPG private key + ownertrust, and pushes everything into Bitwarden under fixed item names (`atuin/skenmy.com`, `gpg/<KEY_ID>`, `ssh/personal/<KEY_NAME>`).

#### Enable Touch ID unlock on macOS (optional, one-time)

```sh
security add-generic-password -T '' -s bw-master -a "$USER" -w
```

You'll be prompted for the Bitwarden master password once. After that, `bootstrap.sh` will unlock the vault via Keychain (Touch ID gates the Keychain read) instead of prompting.

### Brew auto-sync (macOS)

If you `brew install <foo>` on one Mac, you don't want to remember to PR it into the Brewfile. A nightly script handles it:

- **`~/.local/bin/dotfiles-brew-sync`** — runs `brew bundle dump`, diffs against the source `Brewfile`, appends any newly-installed packages under a dated `# auto-synced from <host>` comment, commits, pushes.
- Launchd schedule: 02:00 local, before the 03:17 chezmoi-update — so other Macs pick up the change the same morning.
- **Append-only by design.** Local uninstalls do *not* remove from Brewfile (removal is intentional and should go via a PR).
- Per-machine exceptions: `~/.config/dotfiles/brew-sync-ignore` — one extended-regex per line, matched against Brewfile lines. Add `^cask "firefox"$` to keep Firefox on this Mac only.
- Logs at `~/.local/state/dotfiles-brew-sync/last.log`. Run the script ad-hoc to force a sync.

### Shell tips on every new terminal

Every new interactive zsh prints one tip from `~/.config/dotfiles/tips` — a curated reminder list for the tools in your $PATH (`tldr <cmd>`, `gh dash`, `mise use -g node@lts`, neovim leader keys, tmux prefix bindings, restic recovery commands, etc.). Add new tips one-per-line; lines starting with `#` are ignored. Silence on a specific machine with `export DOTFILES_NO_TIP=1` in `~/.zshrc.local`.

### Auto-updates

Every box runs `chezmoi update` daily at 03:17 local — pulls from `main` and applies.

- **macOS:** `~/Library/LaunchAgents/com.skenmy.chezmoi-update.plist` (loaded by launchd at apply time).
- **Linux:** `~/.config/systemd/user/chezmoi-update.{service,timer}` (enabled via `systemctl --user enable --now chezmoi-update.timer`). On servers, run `loginctl enable-linger "$USER"` first so the user timer fires without an active login session.
- **Worker:** `~/.local/bin/chezmoi-update-and-notify` — wraps `chezmoi update` and logs to `~/.local/state/chezmoi-update/last.log`.

Run `~/.local/bin/chezmoi-update-and-notify` ad-hoc to fire a sync immediately. Inspect `last.log` to see whether a change rolled out.

### Post-bootstrap

- Open a new shell (so starship/mise/atuin/zsh load).
- `chsh -s $(which zsh)` if zsh isn't your default shell (Linux).
- `mise use -g node@lts` (or python/go/rust) to install runtimes.

---

## Daily workflow

| Command | Purpose |
|---|---|
| `chezmoi edit ~/.zshrc` | Open the source template for `~/.zshrc` in `$EDITOR` |
| `chezmoi diff` | Preview what would change |
| `chezmoi apply` | Apply pending changes to `$HOME` |
| `chezmoi cd` | Drop into the source repo (`~/.local/share/chezmoi`) |
| `chezmoi update` | `git pull` the source repo and apply |
| `chezmoi re-add` | After ad-hoc edits to live files, suck them back into source |
| `chezmoi data` | Show resolved template variables (os, hostname, prompts) |
| `chezmoi managed` | List every file under chezmoi's control |

> **Never edit `~/.zshrc`, `~/.gitconfig`, etc. directly.** Edit in the source dir (or with `chezmoi edit`) — direct edits will be overwritten on next `chezmoi apply`.

---

## What's in here

### Manager
- **chezmoi** — single binary, templating, per-machine variables, cross-platform.
- `.chezmoi.toml.tmpl` — prompts for `name`, `email`, `signingKey`, `headless`, `work` on first run.
- `.chezmoiignore` — per-OS file exclusions (Brewfile only on macOS, etc.).

### Shell (zsh)
- `dot_zshenv.tmpl` — XDG dirs, editor, GPG_TTY, cargo env, local bin on PATH.
- `dot_zprofile.tmpl` — Homebrew shellenv (macOS / Linuxbrew).
- `dot_zshrc.tmpl` — main config: history, completion, antidote, starship, mise, atuin, fzf, zoxide, direnv, aliases, NVM/Bun/Android/Java preserved on macOS.
- `dot_zsh_plugins.txt` — antidote plugin list:
  - `zsh-autosuggestions` (Fish-like suggestions)
  - `zsh-syntax-highlighting` (deferred)
  - `zsh-completions`
  - `fzf-tab` (fzf-powered tab completion)
  - `zsh-defer`
  - omz plugins: `git`, `sudo`, `extract`, `colored-man-pages`, `command-not-found`

### Prompt
- **starship** (`dot_config/starship.toml`) — Gruvbox-dark palette, OS icon, user, dir, git branch/status, language/runtime, docker, kubernetes, time. Cross-shell (zsh + pwsh).

### Runtime version manager
- **mise** (`dot_config/mise/config.toml`) — replaces nvm/rbenv/pyenv/asdf. Lazy, single binary, project-local `.mise.toml` overrides.

### Shell history
- **atuin** (`dot_config/atuin/config.toml`) — sqlite-backed history with fuzzy search and **end-to-end encrypted sync** against the self-hosted server at `https://atuin.skenmy.com` (deployed via `skenmy-vps`). Bound to `Ctrl-R`. Server only ever stores ciphertext; the encryption key never leaves the client.

### Editor
- **Neovim** (`dot_config/nvim/`) — kickstart-style lazy.nvim config. Tokyonight colorscheme.
  - `lua/options.lua` — sensible defaults (relative numbers, undo file, system clipboard, etc.)
  - `lua/keymaps.lua` — `<leader>` = Space; window nav, move-line in visual, paste-without-yank.
  - `lua/plugins/colorscheme.lua` — tokyonight.
  - `lua/plugins/telescope.lua` — `<leader>ff` files, `<leader>fg` live grep, `<leader>fb` buffers.
  - `lua/plugins/treesitter.lua` — syntax for Lua/Go/Rust/Python/JS/TS/YAML/Terraform/etc.
  - `lua/plugins/lsp.lua` — mason + lspconfig + nvim-cmp; auto-installs `lua_ls`, `gopls`, `rust_analyzer`, `pyright`, `ts_ls`, `yamlls`, `jsonls`, `bashls`, `terraformls`.
  - `lua/plugins/editor.lua` — gitsigns, autopairs, Comment.nvim, nvim-surround, lualine, nvim-tree, which-key, lazygit integration.

### Terminal multiplexer
- **tmux** (`dot_tmux.conf`) — prefix `C-a`, vim-style splits/nav, mouse on, 256-color, large history, status line, TPM auto-bootstrap. Plugins: tmux-sensible, tmux-resurrect, tmux-continuum, tmux-yank, vim-tmux-navigator.

### Terminal emulator (macOS desktop only)
- **Ghostty** (`dot_config/ghostty/config`) — JetBrainsMono Nerd Font, TokyoNight theme, cmd-based splits and tabs, shell integration, option-as-alt.

### Terminal quick-wins

- **tealdeer** (`tldr`) — instant offline summaries for any CLI command. Cache refreshes on chezmoi apply.
- **xh** — curl with sane syntax. `xh POST httpbin.org/post name=paul age:=33` (note `:=` for raw JSON).
- **mkcert** — generate trusted local TLS certs. Run `mkcert -install` once on a new box to install the local CA.
- **gh-dash** — terminal dashboard for GitHub PRs/issues/repos. Auto-installed via `gh extension install dlvhdr/gh-dash` on apply once `gh` is authed. Run with `gh dash`.
- **direnv** (`dot_config/direnv/direnvrc`) — global helpers: `layout mise` (use the project's mise toolchain), `dotenv_if_exists`, `use_flake`, `use_op` (pull 1Password secrets into env).

### Editor: VS Code (macOS)

- **`Library/Application Support/Code/User/settings.json`** — global user settings (formatter, autosave, git auto-fetch, formatOnSave, etc.).
- **`dot_config/code/extensions.txt`** — one extension ID per line. The `run_onchange_after_install-code-extensions.sh.tmpl` script diffs this against `code --list-extensions` on apply and installs missing ones via `code --install-extension`.
- Append-only on the extensions file: a local `code --install-extension foo` won't sync back. To propagate, edit the source list directly. (Mirrors the brew-sync philosophy: removals are intentional and live in PRs.)
- Skipped on `headless=true` boxes (no point installing extensions on a server with no GUI).

### Mesh VPN (personal boxes only)
- **Tailscale** — installed via the Brewfile cask on macOS and the official `install.sh` on Linux. On Linux, install is gated to `work=false` so employer-managed boxes aren't disturbed. Authenticating is interactive (`sudo tailscale up --operator=$USER` on Linux, menu-bar app on macOS) and only needed once per device.

### Pre-commit framework
- **pre-commit** is in the Brewfile; `dot_config/pre-commit/skenmy-defaults.yaml` ships a starter `.pre-commit-config.yaml` you can copy into any project. The defaults cover the language-agnostic safety net: trailing whitespace, EOL normalisation, JSON/YAML/TOML validation, large-file guard, **gitleaks** to block accidental secret commits, **codespell** for typos.
- Enable in a new repo:
  ```sh
  cp ~/.config/pre-commit/skenmy-defaults.yaml .pre-commit-config.yaml
  pre-commit install
  git add .pre-commit-config.yaml && git commit -m "Add pre-commit"
  ```
- Add language-specific hooks (ruff / eslint / gofumpt / etc.) per-repo *below* the defaults — they're project state, not user state, so they don't belong in this dotfile.

### Encrypted backup (restic)

Nightly snapshot of `$HOME` to a restic repository (B2 / S3 / SFTP / etc.). Encrypted and deduplicated at rest — the server never sees plaintext.

| File | Purpose |
|---|---|
| `~/.local/bin/restic-backup` | Worker. Reads `~/.config/restic/env`, runs `restic backup ~` with sensible flags, then `restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --keep-yearly 3 --prune`. |
| `~/.config/restic/env.example` | Template — copy to `env`, fill in `RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, and backend creds (B2/S3). `chmod 0600` it. |
| `~/.config/restic/excludes` | Exclude list — caches, build artefacts, cloud-sync dirs, Downloads/Movies/Music. |
| `~/Library/LaunchAgents/com.skenmy.restic-backup.plist` (macOS) | Daily at 04:32 local. |
| `~/.config/systemd/user/restic-backup.{service,timer}` (Linux) | Same schedule, with 30-min jitter for fleet rollouts. |

**One-time setup per laptop:**

```sh
cp ~/.config/restic/env.example ~/.config/restic/env
$EDITOR ~/.config/restic/env                 # fill in repo URL + password + creds
chmod 0600 ~/.config/restic/env
~/.local/bin/restic-backup                   # first run also runs `restic init`
```

Logs land in `~/.local/state/restic/last.log`. Run the worker ad-hoc any time to force a backup.

> **Back the `RESTIC_PASSWORD` up in Bitwarden.** Losing it bricks your snapshots.

### Git
- **`dot_gitconfig.tmpl`** — name/email/signingKey from chezmoi prompts. GPG sign commits and tags. **delta** as pager and interactive diff filter. `init.defaultBranch=main`, `pull.rebase=false`, `push.default=current` with `autoSetupRemote`, `fetch.prune`, `rebase.autoStash`+`autoSquash`, `rerere.enabled`, branches sorted by recent commit, `merge.conflictstyle=zdiff3`, `diff.algorithm=histogram`, `help.autocorrect=prompt`.
- URL aliases: `gh:user/repo` → `git@github.com:user/repo`.
- Aliases: `s`, `co`, `sw`, `cm`, `ca`, `cane`, `lg`, `ls`, `last`, `diffs`, `pushf`, `wip`, `undo`, `cleanup`, `root`, `aliases`, `fixup`, `sync`.
- **`dot_gitignore_global`** — DS_Store, swap files, .direnv, node_modules, .venv, .env.local, etc.

### SSH + GPG public keys
- **`private_dot_ssh/authorized_keys.tmpl`** — applied to `~/.ssh/authorized_keys` (0600 via `private_` prefix). Pulled live from `github.com/skenmy.keys` via chezmoi's `gitHubKeys` template function — add a key on GitHub and the next `chezmoi apply` ships it everywhere. Per-host extras can go in `~/.ssh/authorized_keys.local` (sourced if present).
- **`private_dot_ssh/id_rsa.pub`** — public counterpart of the RSA key. Safe to commit.
- **`private_dot_ssh/config.tmpl`** — `AddKeysToAgent`, control sockets, `accept-new` host key policy, includes `~/.ssh/config.local` for per-host overrides. On macOS, uses Keychain + 1Password SSH agent socket.
- **`gpg-public-key.asc`** — ASCII-armored export of GPG key `9BFD73704EA02674`. Not deployed as a file; instead `run_onchange_after_import-gpg-key.sh.tmpl` runs `gpg --import` on apply and marks the key as ultimately trusted so signing works out of the box.

> The repo is **public**. Public keys (SSH `.pub`, GPG armored export, `authorized_keys`) are safe to commit by design. Never commit private keys.

### Bootstrap scripts

| File | When it runs |
|---|---|
| `run_once_install-packages-darwin.sh.tmpl` | First chezmoi apply on macOS — installs Homebrew, runs `brew bundle`, sets up fzf, TPM. |
| `run_once_install-packages-linux.sh.tmpl` | First apply on Linux — detects apt/dnf/pacman/apk for base packages; installs starship/mise/atuin/zoxide via official scripts; clones antidote, fzf, TPM. |
| `run_once_install-packages-windows.ps1.tmpl` | First apply on Windows — `winget install` for git, gh, starship, fzf, zoxide, bat, fd, rg, eza, delta, jq, neovim, lazygit, atuin, mise, Windows Terminal, JetBrains Mono Nerd Font. |
| `run_once_after_macos-defaults.sh.tmpl` | After every "first apply" on a non-headless macOS — sensible `defaults write` for keyboard, Finder, screenshots, Dock, trackpad, Safari dev menu, TextEdit. |

`run_once_*` scripts re-run only if their content hash changes — safe to land in a fresh apply.

### Brewfile (macOS)

CLI: `zsh starship antidote mise direnv fzf zoxide eza bat ripgrep fd jq yq btop tree wget watch tmux neovim lazygit git-delta gh atuin gnupg go node uv ffmpeg tesseract streamlink watchman`.

Kubernetes / infra: `kubernetes-cli helm kustomize kubeseal flux terraform`.

Casks: `ghostty iterm2 raycast docker-desktop spotify telegram claude-code zulu@17 logi-options+ tailscale`. (Headless macOS boxes get the same casks; only the Ghostty *config file* is skipped on headless via `.chezmoiignore`.)

Fonts: `font-jetbrains-mono-nerd-font font-symbols-only-nerd-font`.

### PowerShell profile (Windows)
- `Documents/PowerShell/Microsoft.PowerShell_profile.ps1.tmpl` — PSReadLine (history+plugin predictions, ListView), starship, zoxide, mise, atuin, gh completion, posix-style aliases (`ll`, `..`, `gs`, `gd`, `vim` → `nvim`).

---

## Per-machine variables

Prompted on first run, stored in `~/.config/chezmoi/chezmoi.toml`:

| Variable | Used for |
|---|---|
| `name` | git `user.name` |
| `email` | git `user.email` |
| `signingKey` | git `user.signingkey` (empty → no GPG signing) |
| `headless` | Skip GUI configs (Ghostty), skip macOS defaults, suppress cask upgrades |
| `work` | Personal vs employer-managed. On Linux, gates the auto-install of Tailscale (skipped on work boxes). |

Change them later: `chezmoi edit-config`, then `chezmoi apply`.

---

## Secrets

The repo is **public**. Never commit anything secret. Options for per-machine secrets, in rough order of how often I use them:

- **Bitwarden + `scripts/bootstrap.sh`** — the bootstrap pulls GPG private key, SSH private keys, and atuin credentials from the vault under fixed item names (`atuin/skenmy.com`, `gpg/<KEY_ID>`, `ssh/personal/<KEY_NAME>`). Seed once with `scripts/seed-bitwarden.sh`. This is the path the TL;DR assumes.
- **`~/.zshrc.local`** — sourced at the end of `.zshrc`, not tracked. Good for one-off per-machine env vars.
- **chezmoi templating** with `{{ bitwarden ... }}`, `{{ onepasswordRead ... }}`, or `{{ pass ... }}` — pulls a secret at apply time, so the source remains plaintext but the rendered file isn't.
- **chezmoi-encrypted files** (via the existing `~/.age-key`) — name a file `encrypted_secret_thing.age.tmpl` and chezmoi decrypts on apply.

---

## Adding a new file

```sh
chezmoi add ~/.config/foo/bar.conf                       # static file
chezmoi add --template ~/.config/foo/bar.conf            # template (will need {{ … }} edits)
$EDITOR "$(chezmoi source-path)/dot_config/foo/bar.conf" # edit (substitute the chezmoi-mangled name)
chezmoi diff && chezmoi apply                            # verify + apply
cd "$(chezmoi source-path)" && git add -A \
    && git commit -m "add foo config" && git push
```

---

## Uninstall / reset

```sh
chezmoi purge          # remove source dir + state, leaves applied files
chezmoi unmanaged      # list files in $HOME not under chezmoi
```

To restore a specific file from the backup taken on first setup, look in `~/.dotfiles-backup-YYYYMMDD-HHMMSS/`.

---

## Stack rationale (vs. older common choices)

| Old | Now | Why |
|---|---|---|
| oh-my-zsh | antidote | omz is monolithic and slow; antidote is a thin plugin manager |
| powerlevel10k | starship | p10k was archived in 2024 |
| nvm | mise | nvm adds ~100ms to shell startup; mise covers node/python/go/rust/ruby in one binary |
| iterm2 | Ghostty (alongside iTerm2) | GPU-accelerated, config-as-code |
| default zsh history | atuin | sqlite-backed, encrypted sync across machines |

Tools that stayed (still best-in-class): tmux, neovim, ripgrep, fd, bat, eza, zoxide, fzf, delta, lazygit, direnv, jq, btop.
