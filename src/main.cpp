#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include "runtime.h"

#ifndef GBARECOMP_BUILTIN_NAME
#define GBARECOMP_BUILTIN_NAME "Shrek Movie (USA)"
#endif
#ifndef GBARECOMP_BUILTIN_SHA1
#define GBARECOMP_BUILTIN_SHA1 ""
#endif
#ifndef GBARECOMP_BUILTIN_CRC32
#define GBARECOMP_BUILTIN_CRC32 0
#endif
#ifndef GBARECOMP_BUILTIN_REGION
#define GBARECOMP_BUILTIN_REGION ""
#endif
#ifndef GBARECOMP_DEFAULT_GAME_CONFIG
#define GBARECOMP_DEFAULT_GAME_CONFIG "game.toml"
#endif

#if defined(GBAGAME_RECOMP_UI)
#include "game_launcher_boot.h"
#endif

namespace {

void apply_movie_window_defaults(int argc, char** argv) {
    bool windowed = true;
    for (int i = 1; i < argc; ++i) {
        if (std::strcmp(argv[i], "--no-window") == 0) {
            windowed = false;
            break;
        }
    }
    if (!windowed || std::getenv("GBARECOMP_PRESENT_IN_PLACE")) return;

    // The movie player can spend a long time inside one translated decode
    // dispatch. Let the ordinary per-frame host loop regain control so Windows
    // messages and SDL events keep flowing throughout that work.
#if defined(_WIN32)
    _putenv_s("GBARECOMP_PRESENT_IN_PLACE", "0");
#else
    setenv("GBARECOMP_PRESENT_IN_PLACE", "0", 0);
#endif
}

}  // namespace

int main(int argc, char** argv) {
    apply_movie_window_defaults(argc, argv);

    for (int i = 1; i < argc; ++i) {
        if (std::strcmp(argv[i], "--help") == 0 ||
            std::strcmp(argv[i], "-h") == 0) {
            std::printf(
                "ShrekMovieRecomp [--bios <path>] [--rom <path>] [game.toml]\n");
            return 0;
        }
    }

    gbarecomp::RunOptions opts;
    opts.builtin_game_name = GBARECOMP_BUILTIN_NAME;
    opts.builtin_rom_sha1 = GBARECOMP_BUILTIN_SHA1;
    opts.builtin_rom_crc32 = GBARECOMP_BUILTIN_CRC32;
    opts.mod_game_id = "shrek-movie-us";
    opts.launcher_region = GBARECOMP_BUILTIN_REGION;
    opts.launcher_game_config = GBARECOMP_DEFAULT_GAME_CONFIG;
    opts.launcher_expose_widescreen = false;

    // Sharp integer prescaling is especially useful for GBA Video's already
    // heavily compressed bitmap frames. It is optional and can be toggled in
    // recomp-ui without changing emulation or the movie data.
    opts.launcher_expose_sharp_filter = true;
    opts.launcher_default_sharp_filter = true;

#if defined(GBAGAME_RECOMP_UI)
    std::vector<std::string> args(argv, argv + argc);
    if (game_launcher_preboot(args, opts)) return 0;
    std::vector<char*> av;
    av.reserve(args.size());
    for (auto& arg : args) av.push_back(arg.data());
    return gbarecomp::run_game(static_cast<int>(av.size()), av.data(), opts);
#else
    return gbarecomp::run_game(argc, argv, opts);
#endif
}
