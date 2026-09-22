# Profiles

*Reviewed against `ada9e1c`, 2026-09-22. Derived by hand from `.chezmoiignore` and the
`{{ if }}` guards in each template and script. If either changes, re-check this page.*

## Dimensions

| Input | Source | Values | What it gates |
|---|---|---|---|
| OS | `.chezmoi.os`, detected at run time and not overridable | `darwin`, `linux`, `windows` | Package manager, timers, shell files, Ghostty, PowerShell |
| `headless` | first-run prompt, default `false` | bool | GUI configs, macOS defaults, VS Code, brew-sync, restic on macOS, `brew bundle --no-upgrade` |
| `work` | first-run prompt, default `false` | bool | Two-account GitHub setup, SSH agent choice, Tailscale on Linux, commit-identity hook |
| `signingKey` | first-run prompt, default `9BFD73704EA02674` | string, empty = off | SSH commit/tag signing and the `allowed_signers` rebuild |

Change any of them later with `chezmoi edit-config` then `chezmoi apply`.

## The five OS profiles

| | macOS desktop | macOS headless | Linux desktop | Linux server (`headless`) | Windows |
|---|---|---|---|---|---|
| **Packages** | Homebrew: `common` + `gui` fragments (+ `personal` unless `work`) | `common` (+ `personal` unless `work`), `--no-upgrade`; no casks | apt/dnf/pacman/apk base list + upstream install scripts | Same as Linux desktop (the headless branch is identical) | 19 winget packages + PSReadLine |
| **Shell** | zsh + antidote + starship | same | same | same | PowerShell profile + starship |
| **Neovim config** | ✓ | ✓ | ✓ (but apt Neovim is too old, see [G-02](gaps.md#g-02)) | ✓ (same caveat) | deployed to the wrong path, see [G-05](gaps.md#g-05) |
| **tmux config** | ✓ | ✓ | ✓ | ✓ | – |
| **Ghostty config** | ✓ | – | – | – | – |
| **Zed** (cask / install.sh / winget) + `settings.json` | ✓ | – | ✓ | – | ✓ (`AppData\Roaming\Zed`) |
| **macOS defaults** | ✓ (42 keys) | – | – | – | – |
| **Nightly `chezmoi update`** | launchd 03:17 | launchd 03:17 | systemd user timer 03:17 (+30 min jitter) | same, needs `loginctl enable-linger` | **none** |
| **Nightly restic backup** | launchd 04:32 | **none** | systemd 04:32 (+jitter) | systemd 04:32 | **none** |
| **Nightly brew-sync** | launchd 02:00 → `common` if work, else `personal` | – | – | – | – |
| **Tailscale** | `tailscale-app` cask, personal only | same (personal) | `install.sh` unless `work` | same | – |
| **Bitwarden bootstrap** (`scripts/bootstrap.sh`) | ✓ | ✓ | ✓ | ✓ | **none** |
| **git config** | ✓ SSH signing | ✓ | ✓ | ✓ | ✓ but signing key never provisioned |
| **ssh config + authorized_keys** | ✓ | ✓ | ✓ | ✓ | ✓ (`ControlMaster` unsupported) |
| **gpg public key import** | ✓ | ✓ | ✓ | ✓ | runs via `sh` if Git for Windows is present |
| **`gh dash` extension** | ✓ once `gh` is authed | ✓ | ✓ | ✓ | same |
| **tealdeer cache refresh** | ✓ | ✓ | ✓ | ✓ | same |

Legend: ✓ deployed and active · – not deployed by design · **bold** = a gap, see the register.

## What the `work` flag changes

Applies on every OS unless stated.

| Area | `work = false` (personal) | `work = true` (employer-issued) |
|---|---|---|
| Git identity outside `~/code/eit` | `paul@skenmy.com`, signs with `~/.ssh/id_ed25519.pub` | same email, signs with `~/.ssh/id_ed25519_skenmy.pub` |
| Git identity inside `~/code/eit/` | n/a | `pwilliams@eit.org`, signs with `~/.ssh/id_ed25519_eit.pub` via `includeIf` → `~/.gitconfig-eit` |
| Commit-identity guard | none | `core.hooksPath = ~/.git-hooks`; `pre-commit` blocks EIT email outside the tree and non-EIT email inside it |
| SSH agent (macOS) | Bitwarden Desktop agent socket | 1Password agent socket |
| SSH agent (Linux) | `~/.bitwarden-ssh-agent.sock` | `~/.1password/agent.sock` |
| `Host github.com` | agent decides | pinned to `~/.ssh/id_ed25519_skenmy`, `IdentitiesOnly yes` |
| `Host github-eit` | absent | pinned to `~/.ssh/id_ed25519_eit`; `eitclone org/repo` zsh helper clones into `~/code/eit/` |
| `allowed_signers` | personal key only | personal key + EIT key (`pwilliams@eit.org`) |
| Tailscale on Linux | installed by `install.sh` | skipped (employer-managed) |
| Tailscale on macOS | `tailscale-app` cask | not installed |
| Starship prompt | identity pill shows `skenmy` or `EIT` based on the resolved commit email | same |

## What the `headless` flag changes

| OS | Effect |
|---|---|
| macOS | Skips Ghostty config, Zed config, macOS defaults, brew-sync timer, **restic timer**, and the whole `gui.Brewfile` fragment (all casks and fonts); `brew bundle` runs with `--no-upgrade`. |
| Linux | Skips the Zed install and `~/.config/zed`. Packages are otherwise identical. |
| Windows | Nothing (Zed config lives under `AppData`, which is not headless-gated; a headless Windows box is not a supported profile). |

## Unconditional exclusions

`README.md`, `CLAUDE.md`, `gpg-public-key.asc`, `scripts/`, `docs/`, `mkdocs.yml` are never deployed.
`.github/` and `.gitignore` are skipped automatically because chezmoi ignores dot-prefixed entries in
the source root. The GPG key is imported by a script instead of being copied as a file.
