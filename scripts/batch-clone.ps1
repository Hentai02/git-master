param(
[string]$BaseDir = ".",
[switch]$Force
)

$ErrorActionPreference = "Continue"

$repos = @(
"http://xxxx.git",
"http://xxxx.git",
"http://xxxx.git"
)

if (!(Test-Path -Path $BaseDir)) {
New-Item -ItemType Directory -Path $BaseDir | Out-Null
}
Set-Location -Path $BaseDir

$ok = @()
$skip = @()
$fail = @()

foreach ($repo in $repos) {
$name = [System.IO.Path]::GetFileNameWithoutExtension($repo)
$target = Join-Path (Get-Location) $name

if ((Test-Path -Path $target) -and (-not $Force)) {
Write-Host "Skip: $name already exists" -ForegroundColor Yellow
$skip += $repo
continue
}

if ((Test-Path -Path $target) -and $Force) {
Write-Host "Re-clone: $name" -ForegroundColor Yellow
Remove-Item -Path $target -Recurse -Force
}

Write-Host "Cloning: $repo" -ForegroundColor Cyan
git clone $repo

if ($LASTEXITCODE -eq 0) {
$ok += $repo
Write-Host "Success: $repo" -ForegroundColor Green
} else {
$fail += $repo
Write-Host "Failed: $repo" -ForegroundColor Red
}
}

Write-Host ""
Write-Host "===== Summary =====" -ForegroundColor White
Write-Host ("Success: {0}" -f $ok.Count) -ForegroundColor Green
Write-Host ("Skipped: {0}" -f $skip.Count) -ForegroundColor Yellow
Write-Host ("Failed: {0}" -f $fail.Count) -ForegroundColor Red

if ($fail.Count -gt 0) {
Write-Host ""
Write-Host "Failed repositories:" -ForegroundColor Red
$fail | ForEach-Object { Write-Host $_ -ForegroundColor Red }
exit 1
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green