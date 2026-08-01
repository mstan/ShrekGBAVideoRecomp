#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include "runtime.h"
#include "runtime_arm.h"

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

constexpr uint32_t kMoviePlayerStart = 0x02000000u;
constexpr uint32_t kMoviePlayerEnd = 0x02002DA8u;
constexpr uint32_t kIwramStart = 0x03000000u;
constexpr uint32_t kIwramEnd = 0x03008000u;
constexpr uint32_t kMatrixApertureStart = 0x08000000u;
constexpr uint32_t kMatrixApertureEnd = 0x08002000u;

int interpret_live_movie_code(uint32_t pc, int) {
    // The Movie Pak executes a relocated EWRAM player, copied IWRAM helpers,
    // and code in its bank-switched 8 KiB cartridge aperture. These regions
    // change underneath the same guest addresses as playback advances, so they
    // cannot safely enter AOT even for the first phase: switching only after a
    // rewrite can strand an already-active generated call chain. Execute all
    // three live windows through the reference backend from their first entry.
    // BIOS and stable cartridge code remain recompiled.
    const bool is_live_code =
        (pc >= kMoviePlayerStart && pc < kMoviePlayerEnd) ||
        (pc >= kIwramStart && pc < kIwramEnd) ||
        (pc >= kMatrixApertureStart && pc < kMatrixApertureEnd);
    if (!is_live_code) return 0;

    static bool logged = false;
    if (!logged) {
        logged = true;
        std::fprintf(
            stderr,
            "movie_code_backend=interpreter player=0x%08X..0x%08X "
            "iwram=0x%08X..0x%08X "
            "aperture=0x%08X..0x%08X entry_pc=0x%08X\n",
            kMoviePlayerStart, kMoviePlayerEnd,
            kIwramStart, kIwramEnd,
            kMatrixApertureStart, kMatrixApertureEnd, pc);
    }
    return 1;
}

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
    g_runtime_force_interp_hook = interpret_live_movie_code;

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
