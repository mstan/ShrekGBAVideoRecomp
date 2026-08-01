param(
    [string]$Rom = "",
    [string]$Bios = "",
    [string]$BuildDir = "build",
    [int]$Frames = 600,
    [string]$InputReplay = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if (-not $Rom) { $Rom = Join-Path $root "roms\shrek_movie_usa.gba" }
if (-not $Bios) { $Bios = Join-Path $root "gbarecomp\bios\gba_bios.bin" }
$exe = Join-Path $root "$BuildDir\ShrekMovieRecomp.exe"
$config = Join-Path $root "game.toml"
$resultDir = Join-Path $root "$BuildDir\acceptance"

foreach ($path in @($exe, $config, $Rom, $Bios)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required file is missing: $path"
    }
}
New-Item -ItemType Directory -Path $resultDir -Force | Out-Null
$log = Join-Path $resultDir "playback-$Frames.log"
$png = Join-Path $resultDir "playback-$Frames.png"
Remove-Item -LiteralPath $log, $png -Force -ErrorAction SilentlyContinue

$oldReplay = $env:GBARECOMP_INPUT_REPLAY
try {
    if ($InputReplay) {
        $env:GBARECOMP_INPUT_REPLAY = (Resolve-Path -LiteralPath $InputReplay).Path
    } else {
        Remove-Item Env:GBARECOMP_INPUT_REPLAY -ErrorAction SilentlyContinue
    }
    $oldErrorAction = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & $exe --bios $Bios --rom $Rom --frames $Frames --no-window `
            --dump-png $png $config *> $log
        $nativeExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $oldErrorAction
    }
    if ($nativeExitCode -ne 0) {
        throw "Playback route exited with code $nativeExitCode. See $log"
    }
} finally {
    $env:GBARECOMP_INPUT_REPLAY = $oldReplay
}

$text = Get-Content -LiteralPath $log -Raw
foreach ($needle in @("matrix_mapper=active", "unmapped=0 io_unhandled=0")) {
    if (-not $text.Contains($needle)) {
        throw "Playback route did not report '$needle'. See $log"
    }
}
$matrixMatch = [regex]::Match(
    $text, 'matrix_maps=(\d+) matrix_highest_physical_end=0x([0-9a-fA-F]+)')
if (-not $matrixMatch.Success -or
    [int64]$matrixMatch.Groups[1].Value -le 0 -or
    [Convert]::ToInt64($matrixMatch.Groups[2].Value, 16) -le 0x02000000) {
    throw "Playback did not exercise Matrix-mapped data above 32 MiB. See $log"
}
$frameMatch = [regex]::Match($text, 'ppu_frames=(\d+)')
if (-not $frameMatch.Success -or
    [int64]$frameMatch.Groups[1].Value -lt $Frames) {
    throw "Playback route did not reach at least $Frames PPU frames. See $log"
}
if (-not (Test-Path -LiteralPath $png -PathType Leaf) -or
    (Get-Item -LiteralPath $png).Length -eq 0) {
    throw "Playback route did not produce a screenshot: $png"
}

Write-Host "PASS Shrek Movie route ($Frames frames)"
Write-Host "  log: $log"
Write-Host "  png: $png"
