<#
Build the ShrekGBAVideoRecomp Windows x64 release archive.

The archive contains the optimized runner, its MinGW/SDL runtime DLLs,
recomp-ui assets, and a short run guide. It never contains the ROM, BIOS,
generated translation sources, saves, or local configuration.

Usage:
  pwsh tools/make_release.ps1 -Version 0.0.1
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [string]$BuildDir = "build-release"
)

$ErrorActionPreference = "Stop"

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Version must use MAJOR.MINOR.PATCH form, for example 0.0.1."
}

# Keep this process and all compiler children out of the foreground priority
# class. This repository's release builds are intentionally low priority.
try {
    [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass =
        [System.Diagnostics.ProcessPriorityClass]::BelowNormal
} catch {
    Write-Warning "Could not lower process priority: $($_.Exception.Message)"
}

$mingwBin = "C:\msys64\mingw64\bin"
$env:PATH = "$mingwBin;$env:PATH"
$root = Split-Path -Parent $PSScriptRoot
$build = Join-Path $root $BuildDir
$out = Join-Path $root "release-stage"
$stageName = "ShrekGBAVideoRecomp-windows-x64-v$Version"
$stage = Join-Path $out $stageName
$zip = Join-Path $out "$stageName.zip"
$target = "ShrekMovieRecomp"
$dlls = @(
    "SDL2.dll",
    "libgcc_s_seh-1.dll",
    "libstdc++-6.dll",
    "libwinpthread-1.dll"
)

New-Item -ItemType Directory -Path $out -Force | Out-Null

# Configure every run so a pre-existing build directory cannot silently retain
# a non-Release configuration.
& cmake -S $root -B $build -G Ninja `
    -DCMAKE_C_COMPILER="$mingwBin/cc.exe" `
    -DCMAKE_CXX_COMPILER="$mingwBin/c++.exe" `
    -DCMAKE_MAKE_PROGRAM="$mingwBin/ninja.exe" `
    -DCMAKE_BUILD_TYPE=Release `
    -DGBARECOMP_BUILD_ORACLE=OFF `
    -DGBARECOMP_MINGW_PREFIX_UNIX="/c/msys64/mingw64" `
    -DSDL2_INCLUDE_DIR="C:/msys64/mingw64/include/SDL2" `
    -DSDL2_LIBRARY="C:/msys64/mingw64/lib/libSDL2.dll.a"
if ($LASTEXITCODE -ne 0) {
    throw "Release configuration failed with exit code $LASTEXITCODE."
}

& cmake --build $build --target $target --parallel 2
if ($LASTEXITCODE -ne 0) {
    throw "Release build failed with exit code $LASTEXITCODE."
}

$exe = Join-Path $build "$target.exe"
$assets = Join-Path $build "assets"
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
    throw "Expected executable is missing: $exe"
}
if (-not (Test-Path -LiteralPath (Join-Path $assets "img") -PathType Container)) {
    throw "recomp-ui launcher assets are missing: $assets"
}
foreach ($dll in $dlls) {
    $dllPath = Join-Path $mingwBin $dll
    if (-not (Test-Path -LiteralPath $dllPath -PathType Leaf)) {
        throw "Required runtime DLL is missing: $dllPath"
    }
}

# Validate the recursive cleanup target before removing an older stage.
$outFull = [System.IO.Path]::GetFullPath($out).TrimEnd('\', '/')
$stageFull = [System.IO.Path]::GetFullPath($stage)
$outPrefix = $outFull + [System.IO.Path]::DirectorySeparatorChar
if (-not $stageFull.StartsWith(
        $outPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean release stage outside $outFull`: $stageFull"
}
if (Test-Path -LiteralPath $stage) {
    Remove-Item -LiteralPath $stage -Recurse -Force
}
New-Item -ItemType Directory -Path $stage | Out-Null

$stagedExe = Join-Path $stage "$target.exe"
Copy-Item -LiteralPath $exe -Destination $stagedExe
& (Join-Path $mingwBin "strip.exe") $stagedExe
if ($LASTEXITCODE -ne 0) {
    throw "Stripping the release executable failed with exit code $LASTEXITCODE."
}

foreach ($dll in $dlls) {
    Copy-Item -LiteralPath (Join-Path $mingwBin $dll) -Destination $stage
}
Copy-Item -LiteralPath $assets -Destination $stage -Recurse

@"
# ShrekGBAVideoRecomp v$Version - Windows x64

This is a native PC runner for the Shrek GBA Video Movie Pak, built with
gbarecomp and recomp-ui.

## How to run

1. Extract the entire folder. Keep the DLLs and assets beside
   ``ShrekMovieRecomp.exe``.
2. Run ``ShrekMovieRecomp.exe``.
3. When prompted, select your own legally dumped:
   - Shrek Movie (USA) ROM
     - SHA-1: ``2dedea86ec289a0e31089299613d9f74cca03609``
   - Game Boy Advance BIOS
     - SHA-1: ``300c20df6731a33952ded8c436f7f186d25d3492``
4. Press Play. Shrek happens.

The ROM, BIOS, decoded movie, and other cartridge content are not included.
Local paths and settings are saved beside the executable after first launch.

Project: https://github.com/mstan/ShrekGBAVideoRecomp
"@ | Set-Content -LiteralPath (Join-Path $stage "README.md") -Encoding utf8

if (Test-Path -LiteralPath $zip) {
    Remove-Item -LiteralPath $zip -Force
}
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zip

Write-Host "Release archive created at $zip"
Get-ChildItem -LiteralPath $stage | Select-Object Name, Length | Format-Table
Get-FileHash -LiteralPath $zip -Algorithm SHA256 |
    Select-Object Path, Hash | Format-List
