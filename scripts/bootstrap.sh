#!/usr/bin/env bash
#
# skenmy/dotfiles — fresh-box bootstrap.
#
# Run on any new macOS or Linux machine:
#     curl -fsSL https://raw.githubusercontent.com/skenmy/dotfiles/main/scripts/bootstrap.sh | bash
#
# What it does:
#   1. Installs chezmoi if missing.
#   2. Installs Bitwarden CLI (bw) if missing.
#   3. Unlocks the Bitwarden vault (Touch ID on macOS if seeded, else master pw prompt).
#   4. Pulls GPG private key, SSH private key, and atuin creds from Bitwarden.
#   5. Imports GPG key, writes SSH key with 0600.
#   6. Runs `chezmoi init --apply skenmy` (installs brews/configs/etc.).
#   7. Patches atuin sync_address if needed, then `atuin login` + `atuin sync`.
#
# Idempotent: every step checks before doing.

set -euo pipefail

# ---------------------------------------------------------------------------
# config — keep all the Bitwarden item names in one place
# ---------------------------------------------------------------------------
GITHUB_USER="${GITHUB_USER:-skenmy}"
ATUIN_ITEM="${ATUIN_ITEM:-atuin/skenmy.com}"
GPG_ITEM="${GPG_ITEM:-gpg/9BFD73704EA02674}"
SSH_ITEM="${SSH_ITEM:-ssh/personal/id_ed25519}"
RESTIC_ITEM="${RESTIC_ITEM:-restic/personal}"
RESTIC_ENV_FILE="${RESTIC_ENV_FILE:-$HOME/.config/restic/env}"
ATUIN_SERVER="${ATUIN_SERVER:-https://atuin.skenmy.com}"
KEYCHAIN_ENTRY="${KEYCHAIN_ENTRY:-bw-master}"

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
c_blue=$'\033[1;34m' c_green=$'\033[1;32m' c_red=$'\033[1;31m' c_dim=$'\033[2m' c_reset=$'\033[0m'
log()  { printf "%s==>%s %s\n" "$c_blue"  "$c_reset" "$*"; }
ok()   { printf "%s ✓%s  %s\n" "$c_green" "$c_reset" "$*"; }
warn() { printf "%s !!%s %s\n" "$c_red"   "$c_reset" "$*" >&2; }
die()  { warn "$*"; exit 1; }
has()  { command -v "$1" >/dev/null 2>&1; }

# Run a command with the controlling terminal as its stdin. When this script is
# piped in (curl … | bash), the script's own stdin is the pipe carrying the
# script text — already at EOF — so any interactive prompt (bw login/unlock,
# chezmoi's promptString) reads from a dead fd and crashes. Routing stdin to
# /dev/tty lets those prompts talk to the human. Falls back to the inherited
# stdin when no terminal is available (e.g. CI), so behaviour is unchanged there.
tty_in() {
    if { : < /dev/tty; } 2>/dev/null; then "$@" < /dev/tty; else "$@"; fi
}

# detect OS up front
case "$(uname -s)" in
    Darwin) OS=darwin ;;
    Linux)  OS=linux  ;;
    *)      die "Unsupported OS: $(uname -s). Use scripts/bootstrap.ps1 on Windows." ;;
esac

# ---------------------------------------------------------------------------
# step 1: chezmoi
# ---------------------------------------------------------------------------
ensure_chezmoi() {
    if has chezmoi; then ok "chezmoi present: $(chezmoi --version | head -1)"; return; fi
    log "Installing chezmoi…"
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
    ok "chezmoi installed: $(chezmoi --version | head -1)"
}

# ---------------------------------------------------------------------------
# step 2: bitwarden cli
# ---------------------------------------------------------------------------
ensure_bw() {
    if has bw; then ok "bw present: $(bw --version)"; return; fi
    log "Installing Bitwarden CLI…"
    if [ "$OS" = darwin ]; then
        has brew || die "Install Homebrew first, then re-run."
        brew install bitwarden-cli
    else
        # Linux: prefer snap, fall back to npm, then to release binary
        if has snap; then
            sudo snap install bw
        elif has npm; then
            sudo npm install -g @bitwarden/cli
        else
            local arch=x64; [ "$(uname -m)" = "aarch64" ] && arch=arm64
            local tmp; tmp="$(mktemp -d)"
            curl -fsSL "https://vault.bitwarden.com/download/?app=cli&platform=linux" -o "$tmp/bw.zip"
            unzip -q "$tmp/bw.zip" -d "$HOME/.local/bin"
            chmod +x "$HOME/.local/bin/bw"
            rm -rf "$tmp"
        fi
    fi
    ok "bw installed: $(bw --version)"
}

# ---------------------------------------------------------------------------
# step 3: unlock the vault → export BW_SESSION
# ---------------------------------------------------------------------------
unlock_bw() {
    local status
    status="$(bw status 2>/dev/null | grep -oE '"status":\s*"[^"]+"' | sed -E 's/.*"([^"]+)"/\1/')"

    if [ "$status" = "unauthenticated" ]; then
        log "Logging in to Bitwarden (interactive)…"
        tty_in bw login || die "bw login failed"
    fi

    # Already unlocked?
    if [ "$status" = "unlocked" ] && [ -n "${BW_SESSION:-}" ]; then
        ok "Bitwarden already unlocked"
        return
    fi

    # macOS: try Keychain
    if [ "$OS" = darwin ] && security find-generic-password -s "$KEYCHAIN_ENTRY" -w >/dev/null 2>&1; then
        log "Unlocking Bitwarden via Touch ID (Keychain entry: $KEYCHAIN_ENTRY)…"
        local pw
        pw="$(security find-generic-password -s "$KEYCHAIN_ENTRY" -w)"
        BW_SESSION="$(BW_PASSWORD="$pw" bw unlock --passwordenv BW_PASSWORD --raw)" || die "Keychain pw rejected by bw"
        unset pw
    else
        log "Unlocking Bitwarden (master password prompt)…"
        BW_SESSION="$(tty_in bw unlock --raw)" || die "bw unlock failed"
    fi
    export BW_SESSION
    ok "Bitwarden unlocked"
}

# ---------------------------------------------------------------------------
# step 4: pull secrets and install them
# ---------------------------------------------------------------------------
bw_field() { bw get item "$1" --session "$BW_SESSION" | jq -r ".fields[] | select(.name == \"$2\") | .value"; }
bw_pw()    { bw get password "$1" --session "$BW_SESSION"; }
bw_notes() { bw get item "$1" --session "$BW_SESSION" | jq -r .notes; }

import_gpg() {
    log "Importing GPG private key from ${GPG_ITEM}…"
    local key trust
    key="$(bw_notes "$GPG_ITEM")" || { warn "GPG item missing; skipping"; return; }
    trust="$(bw_field "$GPG_ITEM" trust || true)"
    printf '%s\n' "$key" | gpg --batch --import 2>&1 | sed 's/^/    /'
    [ -n "$trust" ] && printf '%s\n' "$trust" | gpg --import-ownertrust 2>/dev/null || true
    ok "GPG imported"
}

install_ssh() {
    log "Installing SSH private key from ${SSH_ITEM}…"
    local name key pub
    name="${SSH_ITEM##*/}"
    key="$(bw_notes "$SSH_ITEM")" || { warn "SSH item missing; skipping"; return; }
    pub="$(bw_field  "$SSH_ITEM" public || true)"
    mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
    printf '%s\n' "$key" > "$HOME/.ssh/$name"
    chmod 600 "$HOME/.ssh/$name"
    [ -n "$pub" ] && { printf '%s\n' "$pub" > "$HOME/.ssh/$name.pub"; chmod 644 "$HOME/.ssh/$name.pub"; }
    ok "SSH key written to ~/.ssh/$name"
}

stage_atuin_secret() {
    # Atuin needs to be installed first (chezmoi will install it via brew/apt),
    # so we just stash the password + key in env vars and apply them after
    # chezmoi has run.
    log "Fetching atuin credentials from ${ATUIN_ITEM}…"
    ATUIN_PW="$(bw_pw "$ATUIN_ITEM")"  || die "atuin password not in vault"
    ATUIN_KEY="$(bw_field "$ATUIN_ITEM" key)" || die "atuin key not in vault"
    [ -n "$ATUIN_PW" ] && [ -n "$ATUIN_KEY" ] || die "atuin creds missing from vault"
    ok "atuin credentials staged"
}

install_restic_env() {
    log "Fetching restic env from ${RESTIC_ITEM}…"
    local notes
    if ! notes="$(bw_notes "$RESTIC_ITEM" 2>/dev/null)" || [ -z "$notes" ] || [ "$notes" = "null" ]; then
        warn "${RESTIC_ITEM} not found in vault — skipping. Run scripts/seed-bitwarden.sh from a primed box to create it."
        return
    fi
    mkdir -p "$(dirname "$RESTIC_ENV_FILE")"
    printf '%s\n' "$notes" > "$RESTIC_ENV_FILE"
    chmod 0600 "$RESTIC_ENV_FILE"
    ok "wrote $RESTIC_ENV_FILE (0600)"
}

# ---------------------------------------------------------------------------
# step 5: chezmoi apply
# ---------------------------------------------------------------------------
run_chezmoi() {
    if [ -d "$HOME/.local/share/chezmoi/.git" ]; then
        log "chezmoi source dir exists — running chezmoi apply"
        chezmoi apply --force
    else
        log "Running chezmoi init --apply for github.com/$GITHUB_USER/dotfiles…"
        tty_in chezmoi init --apply "$GITHUB_USER"
    fi
    ok "chezmoi applied"
}

# ---------------------------------------------------------------------------
# step 6: atuin login + sync
# ---------------------------------------------------------------------------
finish_atuin() {
    has atuin || { warn "atuin not on PATH after chezmoi apply — skipping login (open a new shell and run scripts/bootstrap.sh again)"; return; }

    # Make sure config points at our server (PR #2 may not be merged yet).
    if [ -f "$HOME/.config/atuin/config.toml" ] && ! grep -q "$ATUIN_SERVER" "$HOME/.config/atuin/config.toml"; then
        log "Patching atuin sync_address → $ATUIN_SERVER"
        sed -i.bak -E "s|^sync_address.*|sync_address = \"$ATUIN_SERVER\"|" "$HOME/.config/atuin/config.toml"
    fi

    # Already logged in?
    if atuin status 2>/dev/null | grep -q "Username:"; then
        ok "atuin already logged in: $(atuin status | grep Username)"
    else
        log "Logging in to atuin…"
        # atuin login -u USER -p PW -k KEY (non-interactive)
        atuin login -u "$GITHUB_USER" -p "$ATUIN_PW" -k "$ATUIN_KEY" || die "atuin login failed"
        ok "atuin logged in"
    fi

    log "Importing local shell history (idempotent)…"
    atuin import auto 2>&1 | sed 's/^/    /' || true
    log "Syncing with ${ATUIN_SERVER}…"
    atuin sync -f 2>&1 | sed 's/^/    /'
    ok "atuin synced"
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
    log "skenmy/dotfiles bootstrap — OS=$OS"
    ensure_chezmoi
    ensure_bw
    unlock_bw
    has jq    || { has brew && brew install jq    || { has apt-get && sudo apt-get install -y jq; }; }
    has gpg   || { has brew && brew install gnupg || { has apt-get && sudo apt-get install -y gnupg; }; }

    import_gpg
    install_ssh
    stage_atuin_secret
    install_restic_env
    run_chezmoi
    finish_atuin

    printf "\n%s🎉 done.%s Open a fresh shell.\n" "$c_green" "$c_reset"
}

main "$@"
