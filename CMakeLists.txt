cmake_minimum_required(VERSION 3.20)
project(ShrekMovieRecomp C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(GBARECOMP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/gbarecomp"
    CACHE PATH "Path to the gbarecomp engine checkout")
set(RECOMP_UI_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/recomp-ui"
    CACHE PATH "Path to the shared recomp-ui checkout")
set(GBARECOMP_RUNTIME_UI_ROOT "${RECOMP_UI_ROOT}"
    CACHE PATH "recomp-ui root used by the live GBA runtime adapter")
set(GBARECOMP_ENABLE_MODS ON CACHE BOOL
    "Enable Shrek Movie's extensible GBA mod-package runtime" FORCE)

if(NOT EXISTS "${GBARECOMP_ROOT}/CMakeLists.txt")
    message(FATAL_ERROR
        "GBARECOMP_ROOT does not point to a gbarecomp checkout:\n"
        "  ${GBARECOMP_ROOT}\n"
        "Clone submodules or pass -DGBARECOMP_ROOT=<path>.")
endif()
if(NOT EXISTS "${RECOMP_UI_ROOT}/recomp_ui.cmake")
    message(FATAL_ERROR
        "RECOMP_UI_ROOT does not point to recomp-ui:\n"
        "  ${RECOMP_UI_ROOT}\n"
        "Clone submodules or pass -DRECOMP_UI_ROOT=<path>.")
endif()

add_subdirectory("${GBARECOMP_ROOT}" gbarecomp_build EXCLUDE_FROM_ALL)

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/generated/recompiled.cpp")
    message(FATAL_ERROR
        "Stale monolithic generated/recompiled.cpp found. "
        "Run tools/regen.ps1 with the current gbarecomp engine.")
endif()
file(GLOB GAME_GENERATED_SOURCES CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/generated/*.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/generated/*.cpp")

add_executable(ShrekMovieRecomp
    src/main.cpp
    ${GAME_GENERATED_SOURCES})

set(GAME_RECOMPILED_SOURCES ${GAME_GENERATED_SOURCES})
list(FILTER GAME_RECOMPILED_SOURCES INCLUDE REGEX
    "/recompiled_[0-9]+\\.cpp$")
if(GAME_RECOMPILED_SOURCES)
    set_source_files_properties(${GAME_RECOMPILED_SOURCES} PROPERTIES
        # The movie's software video decoder spends nearly all of its time in
        # guest translation units, so release builds need full optimization.
        COMPILE_OPTIONS "$<$<CONFIG:Release>:-O3;-g0>")
endif()

target_include_directories(ShrekMovieRecomp PRIVATE
    "${GBARECOMP_ROOT}/src/armv4t"
    "${GBARECOMP_ROOT}/src/gba"
    "${GBARECOMP_ROOT}/src/runtime"
    "${GBARECOMP_ROOT}/src/debug"
    src)

target_link_libraries(ShrekMovieRecomp PRIVATE
    "-Wl,--start-group"
    gbarecomp_runtime
    gbarecomp_debug
    gbarecomp_gba
    gbarecomp_armv4t
    "-Wl,--end-group")

target_compile_definitions(ShrekMovieRecomp PRIVATE
    GBARECOMP_DEFAULT_DEBUG_PORT=19883
    GBARECOMP_WINDOW_TITLE="ShrekMovieRecomp"
    GBARECOMP_DEFAULT_GAME_CONFIG="game.toml"
    GBARECOMP_BUILTIN_SHA1="2dedea86ec289a0e31089299613d9f74cca03609"
    GBARECOMP_BUILTIN_CRC32=0x690176E5
    GBARECOMP_BUILTIN_REGION="USA")

# Keep recomp-ui and Dear ImGui isolated from generated guest translation
# units. Only this bridge and main.cpp receive launcher compile definitions.
option(GBAGAME_RECOMP_UI "Build the recomp-ui pre-boot launcher" ON)
if(GBAGAME_RECOMP_UI)
    include(${RECOMP_UI_ROOT}/recomp_ui.cmake)
    add_library(game_launcher_ui STATIC src/game_launcher_boot.cpp)
    target_include_directories(game_launcher_ui PRIVATE
        "${GBARECOMP_ROOT}/src/runtime"
        "${GBARECOMP_ROOT}/src/gba"
        src)
    target_compile_definitions(game_launcher_ui PRIVATE
        GBARECOMP_ENABLE_MODS=1)
    recomp_target_launcher_ui(game_launcher_ui CONSOLE gba)
    find_package(SDL2 REQUIRED)
    target_link_libraries(game_launcher_ui PUBLIC SDL2::SDL2)
    if(WIN32)
        target_link_libraries(game_launcher_ui PUBLIC opengl32)
    endif()
    target_link_libraries(ShrekMovieRecomp PRIVATE game_launcher_ui)
    set_property(SOURCE src/main.cpp APPEND PROPERTY
        COMPILE_DEFINITIONS GBAGAME_RECOMP_UI)
endif()

# Preloaded data-only packages can be added without changing this build.
set(SHREK_PRELOADED_MODS "${CMAKE_CURRENT_SOURCE_DIR}/mods/preloaded")
if(EXISTS "${SHREK_PRELOADED_MODS}/packages")
    add_custom_command(TARGET ShrekMovieRecomp POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${SHREK_PRELOADED_MODS}"
            "$<TARGET_FILE_DIR:ShrekMovieRecomp>/mods"
        COMMENT "Preloading the Shrek Movie mod catalog")
endif()

if(MSVC)
    target_link_options(ShrekMovieRecomp PRIVATE /STACK:67108864)
elseif(MINGW OR WIN32)
    target_link_options(ShrekMovieRecomp PRIVATE -Wl,--stack,67108864)
endif()
