# Packages — overview

*Reviewed against `1e30dcf` + `fix/brewfile-profiles` + `feat/zed-everywhere`, 2026-09-22.*

Three install mechanisms, one per OS, plus a handful of cross-OS bootstraps. The generated pages in
this section list every entry; this page explains how they are wired.

## macOS: Homebrew

- `Brewfile.tmpl` renders `~/Brewfile` from three fragments in `.chezmoitemplates/brew/`:
  `common.Brewfile` (every Mac), `gui.Brewfile` (`headless = false`), `personal.Brewfile` (`work = false`).
  `brew bundle` runs on first apply (`run_once_install-packages-darwin.sh.tmpl`) and again whenever any
  fragment or the template changes (`run_onchange_after_brew-bundle.sh.tmpl` hashes all four).
- `headless` additionally passes `--no-upgrade`.
- `brew bundle` never uninstalls. Removing a line stops future installs; existing boxes keep the package
  until someone runs `brew bundle cleanup --file=~/Brewfile` by hand.
- The nightly `dotfiles-brew-sync` appends anything installed locally but missing from **all** fragments
  to the fragment named in `~/.config/dotfiles/brew-sync-target` (`common` on work Macs, `personal`
  otherwise), then signs and pushes a commit to `main`. Append-only; see
  [Automations](../settings/automations.md#dotfiles-brew-sync).
- Also on first run: Homebrew itself if missing, TPM clone, fzf key bindings.

→ [Brewfile inventory](../generated/brewfile.md)

## Linux: distro packages + upstream installers

- `run_once_install-packages-linux.sh.tmpl` detects apt, dnf, pacman or apk and installs a fixed list of
  14 base packages with one verbatim name list (Debian spelling).
- Tools without a good distro package come from upstream scripts or GitHub release tarballs into
  `~/.local/bin`: starship, mise, atuin, zoxide, fzf, tealdeer, xh, restic (distro), Tailscale (personal only),
  Zed (desktops only).
- Antidote and TPM are cloned into `~/.antidote` and `~/.tmux/plugins/tpm`.
- Nothing installs `delta`, `eza`, `lazygit`, `gh`, `direnv`, `yq`, `btop`, `k9s`, `kubectl`, `helm`, `terraform`
  or a current Neovim, although shell and git configs assume several of them. See [G-01](../gaps.md#g-01)
  and [G-02](../gaps.md#g-02).
- `~/.zprofile` will load Linuxbrew if it exists, but nothing installs it.

→ [Linux inventory](../generated/linux.md)

## Windows: winget

- `run_once_install-packages-windows.ps1.tmpl` installs 20 winget IDs (`--exact --silent`, including Zed) and the
  latest PSReadLine module. It exits early with a message if winget is missing.
- No Bitwarden, restic, tmux, GnuPG, direnv, pre-commit, k8s tooling, or auto-update timer.

→ [Windows inventory](../generated/windows.md)

## Cross-OS bootstraps (chezmoi `run_*` scripts)

| Mechanism | What it installs | Where |
|---|---|---|
| `run_onchange_after_install-gh-extensions.sh.tmpl` | `dlvhdr/gh-dash` once `gh auth status` succeeds | all OS |
| `run_onchange_after_update-tldr-cache.sh.tmpl` | refreshes the tealdeer page cache | all OS |
| `run_onchange_after_import-gpg-key.sh.tmpl` | imports `gpg-public-key.asc`, sets ultimate ownertrust | all OS |
| Zed `settings.json` → `auto_install_extensions` | Zed extensions, by Zed itself on launch | every desktop |
| Neovim `init.lua` | lazy.nvim, then every plugin, LSP server (via mason) and tree-sitter parser on first start | wherever nvim runs |
| `~/.tmux.conf` | TPM and its plugins on first tmux start | macOS, Linux |
| `~/.zshrc` (Linux) | clones antidote if `~/.antidote` is missing | Linux |

→ [Neovim](../generated/nvim.md) · [Zed extensions](../generated/zed-extensions.md) ·
[zsh plugins](../generated/zsh-plugins.md) · [tmux plugins](../generated/tmux-plugins.md)

## Runtimes

Language runtimes are deliberately **not** installed by the dotfiles. `mise` is installed everywhere
and `~/.config/mise/config.toml` ships with every tool commented out; `mise use -g node@lts` (etc.) is a
manual, per-box step. Exceptions that *are* in the Brewfile: `go`, `node`, `uv`, `python@3.14`, `dotnet`
(the last two arrived via brew-sync).
