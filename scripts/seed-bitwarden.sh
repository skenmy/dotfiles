#!/usr/bin/env bash
#
# skenmy/dotfiles — one-time Bitwarden seeding.
#
# Run on the machine that already has all your secrets locally (GPG keyring,
# ~/.ssh/, ~/.local/share/atuin/key). It pushes them into Bitwarden under
# the schema that scripts/bootstrap.sh reads back.
#
# Schema:
#   atuin/skenmy.com   — Login item.   username=skenmy, password=<atuin pw>, custom field `key`=<atuin encryption key>.
#   gpg/<KEY_ID>       — Secure Note.  notes=<armored private key>, custom field `trust`=<ownertrust>.
#   ssh/personal/<NAME>— Secure Note.  notes=<private key>, custom field `public`=<.pub contents>.
#
# Re-running is safe: existing items are updated in place.

set -euo pipefail

GPG_KEY_ID="${GPG_KEY_ID:-9BFD73704EA02674}"
SSH_KEY_NAME="${SSH_KEY_NAME:-id_ed25519}"
ATUIN_USER="${ATUIN_USER:-skenmy}"
ATUIN_ITEM="atuin/skenmy.com"
GPG_ITEM="gpg/$GPG_KEY_ID"
SSH_ITEM="ssh/personal/$SSH_KEY_NAME"

c_blue=$'\033[1;34m' c_reset=$'\033[0m'
log() { printf "%s==>%s %s\n" "$c_blue" "$c_reset" "$*"; }
die() { printf "!! %s\n" "$*" >&2; exit 1; }

command -v bw >/dev/null || die "bw CLI required: brew install bitwarden-cli"
command -v jq >/dev/null || die "jq required"
command -v gpg >/dev/null || die "gpg required"

if [ -z "${BW_SESSION:-}" ]; then
    log "Unlock Bitwarden:"
    BW_SESSION="$(bw unlock --raw)" || die "unlock failed"
    export BW_SESSION
fi

# ---------------------------------------------------------------------------
# Helpers — create-or-update by item name.
# ---------------------------------------------------------------------------
existing_id() {
    bw list items --search "$1" --session "$BW_SESSION" \
        | jq -r ".[] | select(.name == \"$1\") | .id" | head -1
}

upsert() {
    # $1 = item name, $2 = JSON body (without id)
    local name="$1" body="$2" id
    id="$(existing_id "$name")"
    if [ -n "$id" ]; then
        log "Updating $name ($id)"
        printf '%s' "$body" | jq --arg id "$id" '.id = $id' \
            | bw encode | bw edit item "$id" --session "$BW_SESSION" >/dev/null
    else
        log "Creating $name"
        printf '%s' "$body" | bw encode | bw create item --session "$BW_SESSION" >/dev/null
    fi
}

# ---------------------------------------------------------------------------
# Atuin
# ---------------------------------------------------------------------------
seed_atuin() {
    local key_file="$HOME/.local/share/atuin/key"
    [ -f "$key_file" ] || die "atuin key not found at $key_file — run 'atuin register' first"

    local key
    key="$(cat "$key_file")"

    printf "Atuin password (the one you set during register, won't echo): "
    stty -echo; read -r atuin_pw; stty echo; echo

    local body
    body="$(jq -n \
        --arg name "$ATUIN_ITEM" \
        --arg user "$ATUIN_USER" \
        --arg pw   "$atuin_pw" \
        --arg key  "$key" \
        '{
            organizationId: null,
            folderId: null,
            type: 1,
            name: $name,
            login: { username: $user, password: $pw, uris: [{match: null, uri: "https://atuin.skenmy.com"}] },
            fields: [ { name: "key", value: $key, type: 0 } ],
            secureNote: null,
            notes: null
        }')"
    upsert "$ATUIN_ITEM" "$body"
}

# ---------------------------------------------------------------------------
# GPG
# ---------------------------------------------------------------------------
seed_gpg() {
    log "Exporting GPG private key ${GPG_KEY_ID}…"
    local priv trust
    priv="$(gpg --armor --export-secret-keys "$GPG_KEY_ID")" || die "GPG export failed (need passphrase via agent)"
    trust="$(gpg --export-ownertrust 2>/dev/null | grep "^$(echo "$GPG_KEY_ID" | tr 'a-z' 'A-Z')" || true)"
    [ -z "$trust" ] && trust="$(gpg --fingerprint --with-colons "$GPG_KEY_ID" | awk -F: '/^fpr/ {print $10; exit}'):6:"

    local body
    body="$(jq -n \
        --arg name "$GPG_ITEM" \
        --arg priv "$priv" \
        --arg trust "$trust" \
        '{
            organizationId: null,
            folderId: null,
            type: 2,
            name: $name,
            secureNote: { type: 0 },
            notes: $priv,
            fields: [ { name: "trust", value: $trust, type: 0 } ],
            login: null
        }')"
    upsert "$GPG_ITEM" "$body"
}

# ---------------------------------------------------------------------------
# SSH
# ---------------------------------------------------------------------------
seed_ssh() {
    local priv_file="$HOME/.ssh/$SSH_KEY_NAME"
    local pub_file="$HOME/.ssh/$SSH_KEY_NAME.pub"
    [ -f "$priv_file" ] || die "SSH private key not found at $priv_file"

    local priv pub
    priv="$(cat "$priv_file")"
    pub="$([ -f "$pub_file" ] && cat "$pub_file" || true)"

    local body
    body="$(jq -n \
        --arg name "$SSH_ITEM" \
        --arg priv "$priv" \
        --arg pub  "$pub" \
        '{
            organizationId: null,
            folderId: null,
            type: 2,
            name: $name,
            secureNote: { type: 0 },
            notes: $priv,
            fields: [ { name: "public", value: $pub, type: 0 } ],
            login: null
        }')"
    upsert "$SSH_ITEM" "$body"
}

seed_atuin
seed_gpg
seed_ssh

bw sync --session "$BW_SESSION" >/dev/null
log "Done. Verify in Bitwarden: $ATUIN_ITEM, $GPG_ITEM, $SSH_ITEM"
