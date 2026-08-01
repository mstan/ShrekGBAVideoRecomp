# ShrekMovieRecomp

Static recompilation of **Shrek Movie** (Game Boy Advance Video, USA) to native
PC, built on [`gbarecomp`](https://github.com/mstan/gbarecomp) with the shared
[`recomp-ui`](https://github.com/mstan/recomp-ui) launcher.

This repository contains no ROM, decoded movie data, or Nintendo BIOS. Supply
your own legally dumped cartridge and BIOS.

## Status

Booting native bring-up. The project has:

- the verified 64 MiB `MSKE` ROM identity and conservative AOT configuration;
- native Matrix Memory mapper support for GBA Video movie cartridges;
- real recompiled-BIOS boot when the user supplies the verified BIOS;
- statically recompiled boot, EWRAM player, and IWRAM IRQ relocations;
- a Shrek-specific responsive window-loop default for long video decode spans;
- recomp-ui pre-boot and in-game settings surfaces;
- data-only `.gbamod` loading under the stable ID `shrek-movie-us`;
- an optional sharp-scaling presentation enhancement; and
- headless playback/capture tooling for long regression routes.

The cold-cache 600-frame acceptance route renders the opening Majesco sequence
with a real recompiled BIOS, zero unmapped or unhandled accesses, and fully
static coverage (`dispatch_misses=0`, `interpreted_insns=0`). It performs 51+
Matrix map commands and reaches physical ROM data above `0x0335BE00`, proving
that the player crosses into the cartridge's second 32 MiB half.

A complete 360,000-frame film route is scaffolded but has not been completed:
the software movie decoder currently runs much slower than real time after the
opening sequence. See `tools/test-full-movie.ps1`.

## Required inputs

| Input | Local path | SHA-1 |
|---|---|---|
| Shrek Movie (USA) ROM | `roms/shrek_movie_usa.gba` | `2dedea86ec289a0e31089299613d9f74cca03609` |
| Game Boy Advance BIOS | `gbarecomp/bios/gba_bios.bin` | `300c20df6731a33952ded8c436f7f186d25d3492` |

The ROM is 64 MiB, twice the normal GBA address window. Its Matrix Memory
cartridge pages video payloads through a small mapper aperture; a runtime
without that mapper may boot but cannot play the whole film.

## Build

Prerequisites on Windows are CMake 3.20+, Ninja, an MSYS2 MinGW64 compiler, and
SDL2.

```powershell
git clone --recurse-submodules <this-repository>
cd ShrekMovieRecomp

cmake -S gbarecomp -B gbarecomp/build -G Ninja
cmake --build gbarecomp/build --target gba_recompile
# Generates ignored ROM translation and recompiled BIOS output.
pwsh tools/regen.ps1

cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build --target ShrekMovieRecomp
```

Run `build/ShrekMovieRecomp.exe`; recomp-ui prompts for the verified ROM and
BIOS and persists local launcher settings.

## Controls

| GBA control | Keyboard |
|---|---|
| D-Pad | Arrow keys |
| A / B | Z / X |
| L / R | A / S |
| Start | Enter |
| Select | Backspace |

Save states use **Shift+F1-F9** to save and **F1-F9** to load.

## Playback regression

The headless smoke route captures a decoded checkpoint:

```powershell
pwsh tools/test-playback.ps1
```

The Movie Pak starts playback automatically. The opt-in complete-film route is:

```powershell
pwsh tools/test-full-movie.ps1
```

The long route intentionally stays opt-in because it represents roughly the
duration of the film at 60 GBA frames per second and is currently substantially
slower than real time.

## Legal

Shrek and related names and artwork are trademarks or copyrights of their
respective owners. This is an unaffiliated, non-commercial preservation and
research project. No copyrighted cartridge or movie content is distributed.
