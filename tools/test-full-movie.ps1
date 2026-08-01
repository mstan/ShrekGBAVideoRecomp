param(
    [string]$Rom = "",
    [string]$Bios = "",
    [string]$BuildDir = "build",
    [int]$Frames = 360000
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$smoke = Join-Path $PSScriptRoot "test-playback.ps1"

& $smoke -Rom $Rom -Bios $Bios -BuildDir $BuildDir -Frames $Frames
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$log = Join-Path $root "$BuildDir\acceptance\playback-$Frames.log"
$text = Get-Content -LiteralPath $log -Raw
foreach ($needle in @(
    "bios_backend=LLE (recompiled BIOS)",
    "matrix_mapper=active",
    "unmapped=0 io_unhandled=0",
    "dispatch_misses=0 interpreted_insns=0"
)) {
    if (-not $text.Contains($needle)) {
        throw "Full-movie route did not report '$needle'. See $log"
    }
}

Write-Host "PASS Shrek Movie long route ($Frames frames, recompiled BIOS)"
