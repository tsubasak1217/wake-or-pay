# Build a release APK, publish it to GitHub Releases at a fixed URL, and notify Discord.
#
#   powershell -File tools/release.ps1
#
# The fixed install URL (always the newest build) is:
#   https://github.com/tsubasak1217/wake-or-pay/releases/latest/download/WakeOrPay.apk
#
# The Discord webhook the completion notice goes to lives in tools/notify_webhook.txt,
# which is gitignored and must never be committed.

$ErrorActionPreference = 'Stop'
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
Copy-Item build/app/outputs/flutter-apk/app-release.apk $asset -Force
# Keep a local copy on the desktop too.
Copy-Item $asset "$env:USERPROFILE\OneDrive\デスクトップ\WakeOrPay.apk" -Force -ErrorAction SilentlyContinue

# One release, kept at the fixed "latest" URL; its asset is clobbered each build.
$notes = "自動ビルド v$verName (build $build)"
& $gh release view latest 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
  & $gh release upload latest $asset --clobber
  & $gh release edit latest --title "最新ビルド v$verName (build $build)" --notes $notes --latest
} else {
  & $gh release create latest $asset --title "最新ビルド v$verName (build $build)" --notes $notes --latest
}

Remove-Item $asset -Force

# Notify Discord that a new build is ready.
$hook = (Get-Content "$PSScriptRoot\notify_webhook.txt" -Raw).Trim()
if ($hook) {
  $body = @{ content = "🔔 Wake or Pay の新しいビルドができました  v$verName (build $build)`nインストール／更新はこちら: $dlUrl" } | ConvertTo-Json
  Invoke-RestMethod -Uri $hook -Method Post -ContentType 'application/json' -Body $body | Out-Null
}

Write-Host "Published: $dlUrl"
