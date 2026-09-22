# Automations & timers

*Reviewed against `ada9e1c`, 2026-09-22.*

## Scheduled jobs

| Job | Schedule (local) | macOS | Linux | Windows | Worker | Log |
|---|---|---|---|---|---|---|
| Dotfiles update | 03:17 daily | launchd `com.skenmy.chezmoi-update` (all Macs) | systemd user timer `chezmoi-update.timer`, +30 min jitter, `Persistent=true` | Scheduled Task `skenmy-chezmoi-update`, `StartWhenAvailable`, logged-on only | `~/.local/bin/chezmoi-update-and-notify` (`.ps1` on Windows) | `~/.local/state/chezmoi-update/last.log` |
| Brewfile sync | 02:00 daily | launchd `com.skenmy.dotfiles-brew-sync` (desktop only) | – | – | `~/.local/bin/dotfiles-brew-sync` | `~/.local/state/dotfiles-brew-sync/last.log` |
| restic backup | 04:32 daily | launchd `com.skenmy.restic-backup` (all Macs) | systemd `restic-backup.timer`, +30 min jitter, `Nice=10`, idle I/O | – | `~/.local/bin/restic-backup` | `~/.local/state/restic/last.log` |

launchd agents run with a fixed `PATH` of `~/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin`
and fire on wake if the Mac was asleep. systemd user timers need `loginctl enable-linger $USER` on
servers, otherwise they only run while a session is open. All three workers always exit 0 so a bad
night never breaks the timer; **check the logs**, nothing alerts.

The order is deliberate: brew-sync pushes at 02:00, every box pulls at 03:17, restic snapshots the
result at 04:32.

### chezmoi-update-and-notify

Runs `chezmoi update --force` (git pull with rebase + apply, **overwriting local edits to managed
files**), then logs "no changes" or the range of commits that landed. Despite the name it does not
notify anything.

### dotfiles-brew-sync

0. If an earlier run appended but could not commit, retry that commit first.
1. `brew bundle dump --force --no-vscode --no-restart` to a temp file.
2. Normalise every line in the dump and in the **union** of `.chezmoitemplates/brew/*.Brewfile` to
   `kind "name"` (comments, options and whitespace stripped), `sort -u`.
3. Drop lines matching any regex in `~/.config/dotfiles/brew-sync-ignore`.
4. Anything in the dump but in no fragment is appended to `<target>.Brewfile` under
   `# auto-synced from <host> on <date>`; `<target>` comes from `~/.config/dotfiles/brew-sync-target`
   (templated: `common` when `work`, else `personal`).
5. `git pull --rebase --autostash`, **signed** commit directly to `main`, push. If signing fails the
   change stays staged and is retried tomorrow; nothing is ever committed unsigned.

Append-only by design: uninstalling locally never removes a line. Comparing names rather than whole
lines is what stopped the duplicate re-appends recorded in [G-04](../gaps.md#g-04).

## chezmoi run scripts

`run_once_*` run once per content hash; `run_onchange_*` run whenever their rendered content changes,
which the scripts exploit by embedding `{{ include "<file>" | sha256sum }}` of the files they care about.

| Script | Gate | Re-fires when | Does |
|---|---|---|---|
| `run_once_install-packages-darwin.sh.tmpl` | macOS | script changes | Homebrew, `brew bundle`, TPM, fzf bindings |
| `run_once_install-packages-linux.sh.tmpl` | Linux | script changes | distro packages, upstream installers, antidote, TPM |
| `run_once_install-packages-windows.ps1.tmpl` | Windows | script changes | winget packages, PSReadLine |
| `run_onchange_after_install-update-task.ps1.tmpl` | Windows | worker `.ps1` | register Scheduled Task, set `XDG_CONFIG_HOME` |
| `run_once_after_macos-defaults.sh.tmpl` | macOS, not headless | script changes | 42 `defaults write`, restarts Dock/Finder/SystemUIServer |
| `run_onchange_after_brew-bundle.sh.tmpl` | macOS | `Brewfile.tmpl` + all three fragments | `brew bundle` (`--no-upgrade` if headless) |
| `run_onchange_after_install-update-timer.sh.tmpl` | macOS + Linux | plist, units, worker | reload launchd agent / enable systemd timer |
| `run_onchange_after_install-brew-sync.sh.tmpl` | macOS, not headless | plist, worker | reload launchd agent |
| `run_onchange_after_install-restic-units.sh.tmpl` | macOS; Linux | plist, units, worker | reload / enable |
| `run_onchange_after_install-gh-extensions.sh.tmpl` | all (bash) | hard-coded list literal | `gh extension install dlvhdr/gh-dash` once authed |
| `run_onchange_after_import-gpg-key.sh.tmpl` | all (bash) | `gpg-public-key.asc` | `gpg --import` + ultimate ownertrust of `signingKey` |
| `run_onchange_after_build-allowed-signers.sh.tmpl` | all (bash) | `email`, `work` | rewrite `~/.ssh/allowed_signers` |
| `run_onchange_after_update-tldr-cache.sh.tmpl` | all (bash) | version stamp comment | `tldr --update` |

"all (bash)" scripts are ignored on Windows via `.chezmoiignore` (target names, see [G-21](../gaps.md#g-21)), so they run on macOS and Linux only.

## Template-time network calls

`private_dot_ssh/private_authorized_keys.tmpl` calls `gitHubKeys "skenmy"` on every apply. No other
template reaches the network; secrets are pulled by `scripts/bootstrap.sh`, not by chezmoi.
