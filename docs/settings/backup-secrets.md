# Backup & secrets

*Reviewed against `ada9e1c`, 2026-09-22.* Files: `dot_local/private_bin/executable_restic-backup`,
`dot_config/restic/env.example`, `dot_config/restic/excludes`, `scripts/bootstrap.sh`, `scripts/seed-bitwarden.sh`.

## restic

Runs nightly on every Mac (headless included, since 2026-09-22) and every Linux box (see
[Automations](automations.md)); never on Windows. Skips silently, logging one line, if `~/.config/restic/env` is missing.

| Aspect | Value |
|---|---|
| Config | `~/.config/restic/env`, `set -a` sourced; must define `RESTIC_REPOSITORY` (+ `RESTIC_PASSWORD`, backend creds) |
| Command | `restic backup $HOME --tag <host> --tag daily --one-file-system --exclude-caches --exclude-file ~/.config/restic/excludes` |
| First run | `restic init` if `restic snapshots` fails |
| Retention | `restic forget --tag <host> --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --keep-yearly 3 --prune` |
| Progress | `RESTIC_PROGRESS_FPS=0.1` so the log shows periodic status |
| Excludes | caches, build artefacts (`node_modules`, `.venv`, `target`, `dist`, …), cloud-synced dirs (iCloud Drive, Dropbox, Google Drive), `Downloads`/`Movies`/`Music`, Logs, Mail, Notes and Messages containers, Xcode DerivedData/simulators, MobileSync backups, Steam, Spotify cache, VS Code/Cursor caches, dev caches (`.gradle`, `.m2`, `.npm`, `.cargo/registry`, `.ollama/models`, …). Photos Library is **kept**. Parallels is a commented opt-in. |

All hosts share one repository; per-host tags keep `forget` scoped. The repo password is only in the
env file and Bitwarden.

## Secrets flow

The repo is public. Nothing private is committed; these are safe by design: SSH `.pub` files, the
armored GPG **public** key, `authorized_keys` (public keys pulled from GitHub).

`scripts/bootstrap.sh` (macOS/Linux, `curl | bash`) installs chezmoi and the Bitwarden CLI, unlocks
the vault (Touch ID via the Keychain entry `bw-master` if seeded, else master password from `/dev/tty`),
then pulls:

| Bitwarden item | Type | Written to |
|---|---|---|
| `gpg/9BFD73704EA02674` | Secure Note (notes = armored private key, field `trust`) | `gpg --import` + ownertrust |
| `ssh/personal/id_ed25519` | Secure Note (notes = private key, field `public`) | `~/.ssh/id_ed25519` (personal) or `~/.ssh/id_ed25519_skenmy` (work), 0600, + `.pub` — written **after** `chezmoi init` so the flag is known |
| `restic/personal` | Secure Note (notes = env file body) | `~/.config/restic/env` (0600) |
| `atuin/skenmy.com` | Login (password + field `key`) | `atuin login -u skenmy -p … -k …`, then `atuin import auto && atuin sync -f` |

Order: GPG import → stage atuin creds → restic env → `chezmoi init --apply skenmy` (or `chezmoi apply --force`
if the source dir exists) → SSH key → a second `chezmoi apply` so `allowed_signers` sees the key → atuin
login and sync. Re-runnable.
`scripts/seed-bitwarden.sh` pushes the same four items from a machine that already has the secrets.

`scripts/bootstrap.ps1` is the Windows counterpart: winget installs chezmoi and `Bitwarden.CLI`, then
`chezmoi init --apply`, SSH key (named by the `work` flag, ACL restricted to the user), GPG import if a
`gpg.exe` is on `PATH`, atuin login and sync. It does not pull the restic env because nothing schedules
restic on Windows.

## Per-machine override files (never managed)

| File | Purpose |
|---|---|
| `~/.zshrc.local` | extra env, aliases, `DOTFILES_NO_TIP=1` |
| `~/.ssh/config.local` | host entries, wins over managed defaults |
| `~/.ssh/authorized_keys.local` | extra login keys, appended at apply |
| `~/.config/dotfiles/brew-sync-ignore` | regexes of Brewfile lines this Mac should not push |
| `~/.config/restic/env` | backup credentials |
| `~/Documents/PowerShell/profile.local.ps1` | Windows shell extras |
| `~/.config/chezmoi/chezmoi.toml` | the five prompt answers; `chezmoi edit-config` |
