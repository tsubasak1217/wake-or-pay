# Build a release APK, publish it to GitHub Releases at a fixed URL, and notify Discord.
#
#   powershell -ExecutionPolicy Bypass -File tools/release.ps1
#
# The fixed install URL (always the newest build) is:
#   https://github.com/tsubasak1217/wake-or-pay/releases/latest/download/WakeOrPay.apk
#
# The Discord webhook the completion notice goes to lives in tools/notify_webhook.txt,
# which is gitignored and must never be committed.
#
# ASCII only on purpose: Windows PowerShell 5.1 mis-parses a .ps1 that contains
# non-ASCII bytes without a BOM (brace matching breaks). Keep this file ASCII.
#
# No global $ErrorActionPreference='Stop' either: a native tool writing to stderr
# (gh's "release not found", flutter's warnings) would otherwise abort the script.
# Exit codes are checked explicitly instead.

$env:Path = "C:\Users\k023g\dev\flutter\bin;$env:Path"
$gh = "C:\Program Files\GitHub CLI\gh.exe"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$owner = 'tsubasak1217'
$repo = 'wake-or-pay'
$asset = 'WakeOrPay.apk'
$dlUrl = "https://github.com/$owner/$repo/releases/latest/download/$asset"

# versionCode = commit count (monotonic, so every commit is a clean update).
# versionName = pubspec's x.y.z.
$build = (git rev-list --count HEAD).Trim()
$verName = ([regex]::Match((Get-Content pubspec.yaml -Raw), '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)')).Groups[1].Value
if (-not $verName) { $verName = '1.0.0' }

Write-Host "Building Wake or Pay v$verName (build $build)..."
flutter build apk --release --build-number=$build --build-name=$verName
if ($LASTEXITCODE -ne 0) { Write-Error "flutter build failed (exit $LASTEXITCODE)"; exit 1 }

Copy-Item build/app/outputs/flutter-apk/app-release.apk $asset -Force
# Keep a local copy on the desktop too.
Copy-Item $asset "$env:USERPROFILE\OneDrive\Desktop\WakeOrPay.apk" -Force -ErrorAction SilentlyContinue
Copy-Item $asset "$env:USERPROFILE\OneDrive\$([char]0x30C7)$([char]0x30B9)$([char]0x30AF)$([char]0x30C8)$([char]0x30C3)$([char]0x30D7)\WakeOrPay.apk" -Force -ErrorAction SilentlyContinue

# One release, kept at the fixed "latest" URL; its asset is clobbered each build.
$title = "latest v$verName (build $build)"
$notes = "Automated build v$verName (build $build)"
# Does the fixed release already exist? On the very first run it does not, and gh prints
# "release not found" to stderr - that is expected, not a failure.
& $gh release view latest *> $null
if ($LASTEXITCODE -eq 0) {
  & $gh release upload latest $asset --clobber
  & $gh release edit latest --title $title --notes $notes --latest
} else {
  & $gh release create latest $asset --title $title --notes $notes --latest
}
if ($LASTEXITCODE -ne 0) { Write-Error "gh release publish failed (exit $LASTEXITCODE)"; exit 1 }

Remove-Item $asset -Force -ErrorAction SilentlyContinue

# Notify Discord that a new build is ready (skips quietly if the webhook file is absent).
$hookRaw = Get-Content "$PSScriptRoot\notify_webhook.txt" -Raw -ErrorAction SilentlyContinue
if ($hookRaw) {
  $hook = $hookRaw.Trim()
  $msg = "New Wake or Pay build v$verName (build $build)`nInstall/update: $dlUrl"
  $body = @{ content = $msg } | ConvertTo-Json
  try {
    Invoke-RestMethod -Uri $hook -Method Post -ContentType 'application/json' -Body $body | Out-Null
    Write-Host "Notified Discord."
  } catch {
    Write-Warning "Discord notify failed: $($_.Exception.Message)"
  }
} else {
  Write-Warning "tools/notify_webhook.txt missing - Discord notify skipped."
}

Write-Host "Published: $dlUrl"
