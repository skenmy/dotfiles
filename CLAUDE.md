# skenmy/dotfiles — orientation for Claude

This is the **chezmoi source repo** for Paul's personal dotfiles. Files here render via chezmoi templates into `$HOME` on macOS, Linux, and Windows. One source of truth, many machines.

## What lives where

- `dot_*` / `private_dot_*` — files that map to `~/.foo` etc. chezmoi strips the `dot_` prefix and decodes `private_` to mean 0600 perms (dirs 0700). `private_dot_ssh/` → `~/.ssh/`.
- `dot_config/` — `~/.config/`. Per-tool folders inside: `starship.toml`, `ghostty/`, `nvim/`, `atuin/`, `mise/`, `pre-commit/`, `direnv/`, `restic/`, `dotfiles/` (tips file, brew-sync ignore list).
- `Library/LaunchAgents/` (macOS only) — launchd plists. Currently the daily `chezmoi-update`, nightly `restic-backup`, 02:00 `dotfiles-brew-sync` jobs.
- `dot_config/systemd/user/` (Linux only) — systemd user units for the same three jobs.
- `Brewfile` — every brew/cask installed by `brew bundle`. Re-applied automatically when its hash changes (see `run_onchange_after_brew-bundle.sh.tmpl`).
- `scripts/` — `.chezmoiignore`'d. Shell-out scripts not deployed to `$HOME`: `bootstrap.sh` (curl-pipe-bash entry point), `seed-bitwarden.sh` (one-time secret push).
- `dot_local/private_bin/executable_*` — scripts that end up at `~/.local/bin/` with 0700 perms. Workers for the timers.
- `gpg-public-key.asc` — armored public key, imported on apply via `run_onchange_after_import-gpg-key.sh.tmpl`.
- `.chezmoi.toml.tmpl` — first-run prompts (`name`, `email`, `signingKey`, `headless`, `work`).
- `.chezmoiignore` — branches files by `.chezmoi.os` and the `headless` / `work` flags.

## chezmoi naming refresher

| Source filename | Maps to | Notes |
|---|---|---|
| `dot_foo` | `~/.foo` | 0644 by default |
| `private_dot_foo` | `~/.foo` | 0600 (dirs 0700) |
| `dot_foo.tmpl` | `~/.foo` | Go-template rendered with `.chezmoi.*` + prompts |
| `executable_foo` | `foo` (anywhere under the source) | chmod +x |
| `run_once_<name>.sh.tmpl` | runs once per content hash | Bootstrapping (`install-packages-darwin`, etc.) |
| `run_onchange_<name>.sh.tmpl` | runs whenever rendered content changes | Use a `{{ include "..." \| sha256sum }}` header to re-trigger when a sibling file changes |

## How the automations hang together

```
push to main
   │
   ▼ (03:17 daily — launchd / systemd timer per box)
chezmoi update      = git pull --rebase + chezmoi apply
   │
   ├── files refresh under ~ (dotfiles)
   ├── run_onchange scripts re-fire if their hash changed:
   │     - brew bundle      (Brewfile changed?)
   │     - launchctl load   (a timer plist changed?)
   │     - gpg --import     (gpg-public-key.asc changed?)
   │     - tldr --update    (tips/tools changed?)
   │     - gh extension     (gh-extensions list changed?)
   └── log: ~/.local/state/chezmoi-update/last.log

02:00 daily — dotfiles-brew-sync
   ├── brew bundle dump → temp
   ├── diff vs source Brewfile, append new lines, commit, push
   └── other Macs pick it up via the 03:17 chezmoi-update

04:32 daily — restic-backup
   ├── reads ~/.config/restic/env (RESTIC_REPOSITORY / RESTIC_PASSWORD / B2_*)
   ├── restic backup ~ + restic forget --keep-… --prune
   └── log: ~/.local/state/restic/last.log
```

## Per-machine variables

Stored at `~/.config/chezmoi/chezmoi.toml`; prompted on first run, edit later with `chezmoi edit-config`.

| Var | Used to |
|---|---|
| `name` | `git user.name` |
| `email` | `git user.email` |
| `signingKey` | `git user.signingkey` (empty disables signing) |
| `headless` | Skip GUI configs (Ghostty), skip macOS defaults, `brew bundle --no-upgrade` |
| `work` | Personal vs employer-issued. Gates Tailscale install on Linux. Reserved for `IdentityAgent` branching too (1Password on work, Bitwarden on personal) |

## Secrets

Repo is **public**. Never commit anything private. Per-machine secrets live in Bitwarden under fixed item names; `scripts/bootstrap.sh` pulls them on every new box.

| BW item | Type | Contents |
|---|---|---|
| `atuin/skenmy.com` | Login | username + password + custom field `key` (encryption key) |
| `gpg/9BFD73704EA02674` | Secure Note | notes = armored private key, custom field `trust` = ownertrust |
| `ssh/personal/id_ed25519` | Secure Note | notes = private key, custom field `public` = `.pub` body |
| `restic/personal` | Secure Note | notes = full `~/.config/restic/env` body (RESTIC_REPOSITORY/PASSWORD/B2_*) |

Push to BW once with `scripts/seed-bitwarden.sh`, pull on every new box automatically via `bootstrap.sh`.

## What you can and can't do

You **can**:
- Add or edit chezmoi-managed files. Standard flow: edit source → `chezmoi diff` → `chezmoi apply` (or open a PR and let the 03:17 timer apply it everywhere).
- Add tips to `dot_config/dotfiles/tips` (one per line, propagates overnight).
- Append `brew` / `cask` lines to `Brewfile` (or let `dotfiles-brew-sync` do it for you).
- Add new `run_onchange_*` automation scripts. Re-run trigger: include `{{ include "<file>" | sha256sum }}` for any file that should re-fire the script.

You **cannot** (without explicit human approval):
- Edit `~/.zshrc`, `~/.gitconfig`, `~/.ssh/config`, etc. **directly on a target machine** — the next `chezmoi apply` overwrites those. Always edit the source.
- Force-push to `main` of `skenmy/dotfiles`. Open a PR.
- Disable GPG signing in `dot_gitconfig.tmpl` even if it's annoying in CI — it's a deliberate hard rule.

## Smoke test after any edit

```sh
chezmoi diff                              # preview the rendered change
chezmoi apply --dry-run                   # plus the script invocations
chezmoi apply                             # really do it on this box
bash -n dot_local/private_bin/executable_*     # syntax-check any new scripts
```

For Brewfile additions: `brew bundle check --file=Brewfile` lists missing entries.

For tips file additions: `awk '/^[^#]/ && NF' dot_config/dotfiles/tips | wc -l` — should match expectations; nothing should contain unbalanced backticks (1-in-N hang risk).

## When in doubt

Read `README.md` first — it has the day-to-day commands and the rationale for stack choices. Then look at the relevant `run_*` script (they're short and well-commented). PRs land fast here; small + focused beats big + comprehensive.
