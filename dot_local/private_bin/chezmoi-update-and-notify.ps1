# chezmoi-update-and-notify.ps1 — Windows worker for the daily dotfiles update.
# Registered as the Scheduled Task 'skenmy-chezmoi-update' (daily 03:17) by
# run_onchange_after_install-update-task.ps1.tmpl. Mirrors the bash worker:
# logs to ~/.local/state/chezmoi-update/last.log and always exits 0.
$ErrorActionPreference = 'Continue'

$state = Join-Path $HOME '.local\state\chezmoi-update'
New-Item -ItemType Directory -Force -Path $state | Out-Null
$log = Join-Path $state 'last.log'

function Say([string]$Message) {
    $line = '[{0:yyyy-MM-ddTHH:mm:ssZ}] {1}' -f (Get-Date).ToUniversalTime(), $Message
    $line | Tee-Object -FilePath $log -Append
}

if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) { Say 'chezmoi not on PATH; aborting'; exit 0 }

$src = & chezmoi source-path 2>$null
if (-not $src) { $src = Join-Path $HOME '.local\share\chezmoi' }
$before = git -C $src rev-parse HEAD 2>$null

Say "starting chezmoi update on $env:COMPUTERNAME"
& chezmoi update --force *>> $log
$rc = $LASTEXITCODE
$after = git -C $src rev-parse HEAD 2>$null

if ($rc -ne 0) {
    Say "chezmoi update exited $rc — see $log"
} elseif ($before -eq $after) {
    Say "no changes (HEAD=$before)"
} else {
    Say ('updated: {0} -> {1}' -f $before.Substring(0, 7), $after.Substring(0, 7))
    git -C $src log --pretty=format:'  %h %s' "$before..$after" | Tee-Object -FilePath $log -Append
}
exit 0
