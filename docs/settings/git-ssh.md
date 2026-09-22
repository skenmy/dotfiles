# Git & SSH

*Reviewed against `ada9e1c`, 2026-09-22.* Files: `dot_gitconfig.tmpl`, `dot_gitconfig-eit`, `dot_gitignore_global`,
`private_dot_ssh/private_config.tmpl`, `private_dot_ssh/private_authorized_keys.tmpl`, `private_dot_ssh/id_rsa.pub`,
`private_dot_git-hooks/executable_pre-commit`, `run_onchange_after_build-allowed-signers.sh.tmpl`.

## Identity and signing

| Setting | Personal (`work=false`) | Work (`work=true`) |
|---|---|---|
| `user.name` / `user.email` | from the `name` / `email` prompts (defaults Paul Williams / paul@skenmy.com) | same |
| `user.signingkey` | `~/.ssh/id_ed25519.pub` | `~/.ssh/id_ed25519_skenmy.pub` |
| Inside `~/code/eit/` | n/a | `includeIf gitdir:~/code/eit/` → `~/.gitconfig-eit`: `pwilliams@eit.org`, `~/.ssh/id_ed25519_eit.pub` |
| `commit.gpgsign`, `tag.gpgsign` | `true` when `signingKey` is non-empty | same |
| `gpg.format` | `ssh` | same |
| `gpg.ssh.allowedSignersFile` | `~/.ssh/allowed_signers` | same |

Signing is **SSH-based** (since 2026-06-30). The `signingKey` prompt value (a GPG key ID) is only an
on/off switch and the ownertrust target for the imported GPG public key; git never sees it. This is a
deliberate hard rule in `CLAUDE.md`: do not turn signing off or revert to GPG.

`~/.ssh/allowed_signers` is rebuilt by `run_onchange_after_build-allowed-signers.sh.tmpl` whenever the
rendered `email`/`work` values change. It writes `<email> <key>` for the personal key and, on work boxes,
`pwilliams@eit.org <key>` for the EIT key, skipping any key file that does not exist yet.

The private keys are **not** provisioned by chezmoi. `scripts/bootstrap.sh` writes the Bitwarden item
`ssh/personal/id_ed25519` to `~/.ssh/id_ed25519`. On work boxes the configs expect `id_ed25519_skenmy` and
`id_ed25519_eit`, which nothing creates ([G-08](../gaps.md#g-08)).

## Core behaviour

| Key | Value | Why |
|---|---|---|
| `init.defaultBranch` | `main` | |
| `core.editor` | `nvim` | |
| `core.autocrlf` | `input` | normalise to LF on commit |
| `core.pager` | `delta` | **delta is never installed on Linux** ([G-01](../gaps.md#g-01)) |
| `core.excludesfile` | `~/.gitignore_global` | |
| `core.hooksPath` | `~/.git-hooks` (work only) | commit-identity guard, below |
| `interactive.diffFilter` | `delta --color-only` | |
| `delta.*` | navigate, dark, line numbers, side-by-side off, theme *Monokai Extended* | |
| `merge.conflictstyle` / `merge.tool` | `zdiff3` / `nvimdiff` | |
| `diff.colorMoved` / `diff.algorithm` | `default` / `histogram` | |
| `pull.rebase` | `false` | merge on pull |
| `push.default` / `autoSetupRemote` / `followTags` | `current` / `true` / `true` | |
| `fetch.prune` / `pruneTags` | `true` / `true` | |
| `rebase.autoStash` / `autoSquash` | `true` / `true` | |
| `rerere.enabled` | `true` | remember conflict resolutions |
| `branch.sort` | `-committerdate` | |
| `column.ui` | `auto` | |
| `help.autocorrect` | `prompt` | |
| `color.ui` | `auto` | |
| `url "git@github.com:".insteadOf` | `gh:` | `git clone gh:user/repo` |
| `url "git@github.com:<name-lowercased>/".insteadOf` | `me:` | renders to `paulwilliams/` from the `name` prompt, **not** `skenmy/` |

Aliases: [generated list](../generated/git-aliases.md) (21). `wip` commits with `--no-verify`, bypassing
the identity hook.

`~/.gitignore_global`: OS junk (`.DS_Store`, `Thumbs.db`, …), editor files (`.vscode/`, `.idea/`, swap),
`.direnv/`, `.envrc.local`, `.env.local`, `*.local`, `node_modules/`, Python caches and `.venv/`, `*.log`,
`.claude/settings.local.json`.

## Commit-identity guard (work only)

`~/.git-hooks/pre-commit` runs for every repo because `core.hooksPath` points at it. Inside
`~/code/eit/*` it refuses any email other than `pwilliams@eit.org`; everywhere else it refuses that
email. Note that setting `core.hooksPath` globally means **per-repo `.git/hooks` are ignored**, including
anything `pre-commit install` writes, unless the repo overrides `core.hooksPath` locally.

## `~/.ssh/config`

`Include ~/.ssh/config.local` comes first so per-host overrides win.

| `Host *` option | Value |
|---|---|
| `AddKeysToAgent` | `yes` |
| `ServerAliveInterval` / `CountMax` | `60` / `30` |
| `HashKnownHosts` | `no` |
| `StrictHostKeyChecking` | `accept-new` |
| `VisualHostKey` | `yes` |
| `ControlMaster` / `ControlPath` / `ControlPersist` | `auto` / `~/.ssh/cm-%r@%h:%p` / `10m` (unsupported on Windows OpenSSH, [G-05](../gaps.md#g-05)) |
| `UseKeychain` | `yes` (macOS) |
| `IdentityAgent` | macOS work: 1Password `agent.sock`; macOS personal: `~/.bitwarden-ssh-agent.sock`; Linux work: `~/.1password/agent.sock`; Linux personal: `~/.bitwarden-ssh-agent.sock`; Windows: unset |

`Host github.com gh`: user `git`, publickey only. On work boxes additionally `IdentityFile ~/.ssh/id_ed25519_skenmy`
+ `IdentitiesOnly yes`, and a second `Host github-eit` alias pinned to `~/.ssh/id_ed25519_eit`.

## `~/.ssh/authorized_keys`

Rendered from `gitHubKeys "skenmy"` at **every** `chezmoi apply`: the live public keys on
github.com/skenmy.keys become login-authorised keys on every box, work machines included. Per-host extras
are appended from `~/.ssh/authorized_keys.local`. The template needs network access and the GitHub API at
apply time ([G-07](../gaps.md#g-07)).

`~/.ssh/id_rsa.pub` is deployed as a static file (public half of a legacy RSA key).
