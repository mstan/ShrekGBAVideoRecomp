# Shrek Movie mods

This project enables gbarecomp's data-only `.gbamod` package loader and uses the
stable target ID `shrek-movie-us`. Packages must also target the verified ROM
SHA-1 `2dedea86ec289a0e31089299613d9f74cca03609`.

Preloaded packages use this layout:

```text
mods/preloaded/packages/<package-id>/<version>/manifest.toml
```

Native behavior remains game-owned and trusted: a package may activate only a
plugin ID compiled into `ShrekMovieRecomp`. ROMs, decoded movie frames, and
other copyrighted cartridge data must never be packaged.
