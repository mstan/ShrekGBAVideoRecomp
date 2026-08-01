param(
    [string]$Rom = (Join-Path $PSScriptRoot '..\roms\shrek_movie_usa.gba'),
    [string]$GbarecompRoot = (Join-Path $PSScriptRoot '..\gbarecomp'),
    [int]$MaxFunctions = 65536
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$romPath = (Resolve-Path -LiteralPath $Rom).Path
$engine = (Resolve-Path -LiteralPath $GbarecompRoot).Path
$biosPath = Join-Path $engine 'bios\gba_bios.bin'
$tool = Join-Path $engine 'build-shrek\gba_recompile.exe'
if (-not (Test-Path -LiteralPath $tool)) {
    $tool = Join-Path $engine 'build\gba_recompile.exe'
}
if (-not (Test-Path -LiteralPath $tool)) {
    throw "Missing gba_recompile.exe under $engine. Configure and build the engine first."
}

$actual = (Get-FileHash -LiteralPath $romPath -Algorithm SHA1).Hash.ToLowerInvariant()
$expected = '2dedea86ec289a0e31089299613d9f74cca03609'
if ($actual -ne $expected) {
    throw "Shrek Movie ROM SHA-1 mismatch: got $actual expected $expected"
}

if (Test-Path -LiteralPath $biosPath -PathType Leaf) {
    $biosActual = (Get-FileHash -LiteralPath $biosPath -Algorithm SHA1).Hash.ToLowerInvariant()
    $biosExpected = '300c20df6731a33952ded8c436f7f186d25d3492'
    if ($biosActual -ne $biosExpected) {
        throw "GBA BIOS SHA-1 mismatch: got $biosActual expected $biosExpected"
    }
    Push-Location $engine
    try {
        & $tool --bios $biosPath --config (Join-Path $engine 'bios\gba_bios.toml')
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    } finally {
        Pop-Location
    }
} else {
    Write-Warning "No GBA BIOS at $biosPath; the build will use BIOS HLE fallback."
}

& $tool --rom $romPath --config (Join-Path $root 'game.toml') `
    --out (Join-Path $root 'generated') --max-functions $MaxFunctions
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
