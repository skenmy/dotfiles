# skenmy/dotfiles — fresh Windows box bootstrap (PowerShell 7 recommended).
#
#   iex "& { $(irm https://raw.githubusercontent.com/skenmy/dotfiles/main/scripts/bootstrap.ps1) }"
#
# What it does (idempotent):
#   1. winget-installs chezmoi and the Bitwarden CLI if missing.
#   2. Unlocks the vault (master password prompt) → $env:BW_SESSION.
#   3. chezmoi init --apply skenmy (prompts for name/email/headless/work; installs winget packages,
#      profile, Zed, Scheduled Task).
#   4. Writes the SSH private key from Bitwarden to ~/.ssh/id_ed25519 (or id_ed25519_skenmy when work=true).
#   5. Imports the GPG private key if a gpg.exe is on PATH (Git for Windows ships one).
#   6. atuin login + import + sync.
# Restic is not scheduled on Windows, so its env is not pulled here.

$ErrorActionPreference = 'Stop'
$GitHubUser = if ($env:GITHUB_USER) { $env:GITHUB_USER } else { 'skenmy' }
$AtuinItem  = 'atuin/skenmy.com'
$GpgItem    = 'gpg/9BFD73704EA02674'
$SshItem    = 'ssh/personal/id_ed25519'
$AtuinServer = 'https://atuin.skenmy.com'

function Log($m)  { Write-Host "==> $m" -ForegroundColor Blue }
function Ok($m)   { Write-Host " OK  $m" -ForegroundColor Green }
function Warn($m) { Write-Host " !!  $m" -ForegroundColor Red }
function Has($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function WingetInstall($id) {
    winget install --id $id --exact --silent --accept-source-agreements --accept-package-agreements | Out-Null
}

# 1. tooling
if (-not (Has winget)) { throw "winget not found. Install 'App Installer' from the Microsoft Store first." }
if (-not (Has chezmoi)) { Log 'Installing chezmoi'; WingetInstall 'twpayne.chezmoi' }
if (-not (Has bw))      { Log 'Installing Bitwarden CLI'; WingetInstall 'Bitwarden.CLI' }
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + [Environment]::GetEnvironmentVariable('Path', 'Machine')
Ok "chezmoi $(chezmoi --version | Select-Object -First 1)"

# 2. vault
$status = (bw status | ConvertFrom-Json).status
if ($status -eq 'unauthenticated') { Log 'Logging in to Bitwarden'; bw login | Out-Null }
if (-not $env:BW_SESSION) {
    Log 'Unlocking Bitwarden (master password)'
    $env:BW_SESSION = bw unlock --raw
    if (-not $env:BW_SESSION) { throw 'bw unlock failed' }
}
Ok 'Bitwarden unlocked'
function BwItem($name)        { bw get item $name --session $env:BW_SESSION | ConvertFrom-Json }
function BwField($item, $f)   { ($item.fields | Where-Object name -eq $f | Select-Object -First 1).value }

# 3. chezmoi
$srcGit = Join-Path $HOME '.local\share\chezmoi\.git'
if (Test-Path $srcGit) { Log 'chezmoi source exists — applying'; chezmoi apply --force }
else { Log "chezmoi init --apply $GitHubUser"; chezmoi init --apply $GitHubUser }
Ok 'chezmoi applied'
$isWork = (chezmoi data --format json | ConvertFrom-Json).work -eq $true

# 4. ssh key
$ssh = BwItem $SshItem
if ($ssh) {
    $name = ($SshItem -split '/')[-1]; if ($isWork) { $name = "${name}_skenmy" }
    $sshDir = Join-Path $HOME '.ssh'; New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
    $keyPath = Join-Path $sshDir $name
    Set-Content -Path $keyPath -Value $ssh.notes -NoNewline -Encoding ascii
    $pub = BwField $ssh 'public'; if ($pub) { Set-Content -Path "$keyPath.pub" -Value $pub -Encoding ascii }
    icacls $keyPath /inheritance:r /grant:r "$env:USERNAME`:R" | Out-Null
    Ok "SSH key written to $keyPath"
    if ($isWork) { Warn 'work box: also place ~/.ssh/id_ed25519_eit(.pub) from 1Password' }
    chezmoi apply | Out-Null   # rebuild allowed_signers now the key exists
} else { Warn "$SshItem not in vault; skipping" }

# 5. gpg
if (Has gpg) {
    $gpg = BwItem $GpgItem
    if ($gpg) {
        $gpg.notes | gpg --batch --import 2>&1 | Out-Null
        $trust = BwField $gpg 'trust'; if ($trust) { $trust | gpg --import-ownertrust 2>&1 | Out-Null }
        Ok 'GPG key imported'
    }
} else { Warn 'gpg not on PATH (install Git for Windows or Gpg4win); skipping GPG import' }

# 6. atuin
if (Has atuin) {
    $atuin = BwItem $AtuinItem
    if ($atuin) {
        if (-not (atuin status 2>$null | Select-String 'Username:')) {
            atuin login -u $GitHubUser -p $atuin.login.password -k (BwField $atuin 'key')
        }
        atuin import auto | Out-Null
        atuin sync -f | Out-Null
        Ok "atuin synced with $AtuinServer"
    }
} else { Warn 'atuin not on PATH yet — open a new shell and re-run' }

Write-Host "`nDone. Open a fresh PowerShell." -ForegroundColor Green
