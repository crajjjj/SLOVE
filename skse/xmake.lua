set_xmakever("3.0.0")  -- the commonlibsse-ng submodule requires 3.0

-- SLOVE.dll: the SLO VE in-game settings menu (an SKSE Menu Framework page over
-- SLOVE.toml). Build it through scripts\build.ps1, which passes the mod version
-- in and checks the result; a bare `xmake` here builds a 0.0.0 dev DLL that
-- build.ps1 refuses to package.

PROJECT_NAME = "SLOVE"
PROJECT_AUTHOR = "crajjjj"

-- The mod has ONE version, fomod\info.xml. build.ps1 reads it and passes it here.
option("slove_version")
    set_default("0.0.0")
    set_showmenu(true)
    set_description("Mod version stamped into the DLL (from fomod\\info.xml)")
option_end()

set_version(get_config("slove_version") or "0.0.0")
set_languages("cxx23")
set_license("gplv3")
set_warnings("allextra")

includes("lib/commonlibsse-ng")
set_project(PROJECT_NAME)  -- after the include: the library names the project too, and the last one wins

add_requires("toml++")
set_policy("package.requires_lock", true)

add_rules("mode.debug", "mode.release")

if is_mode("debug") then
    add_defines("DEBUG")
    set_optimize("none")
    set_runtimes("MTd")
elseif is_mode("release") then
    add_defines("NDEBUG")
    set_optimize("fastest")
    set_symbols("debug")
    set_runtimes("MT")
end

add_defines("_SILENCE_CXX17_CODECVT_HEADER_DEPRECATION_WARNING")  -- SKSEMenuFramework.h uses <codecvt>
add_defines("NOMINMAX")  -- CommonLib v7 headers pull in Windows.h

target(PROJECT_NAME)
    set_kind("shared")
    add_deps("commonlibsse-ng")
    add_rules("commonlibsse-ng.plugin", {
        name = PROJECT_NAME,
        author = PROJECT_AUTHOR,
        description = "SLO VE in-game settings menu (SKSE Menu Framework page over SLOVE.toml)."
    })
    add_packages("toml++")
    add_files("src/**.cpp")
    add_headerfiles("src/**.h")
    add_includedirs("src", "extern/SKSEMenuFramework")
    set_pcxxheader("src/PCH.h")

    add_cxxflags(
        "cl::/diagnostics:caret",
        "cl::/wd4200",
        "cl::/wd4201",
        "cl::/Zc:preprocessor",
        "cl::/utf-8"
    )
    if is_mode("debug") then
        add_cxxflags("cl::/bigobj")
    end

    -- NEVER install. The commonlib plugin rule runs `xmake install` after every
    -- build and, with XSE_TES5_MODS_PATH set, aims it at <mods>\<target name>: a
    -- stray "SLOVE" folder in the live Mod Organizer mods directory (the real mod
    -- there is "SLO VE"). Two guards here, a third in scripts\build.ps1:
    on_config(function (target)        -- runs after the rule's on_config
        target:set("installdir", path.join(os.projectdir(), "build", "install"))
    end)
    on_install(function (target) end)  -- a target-level on_install replaces the rule's

    after_build(function (target)
        -- the DLL only: a pdb under dist would ship in the FOMOD
        local out = path.join(os.projectdir(), "..", "dist", "SKSE", "Plugins")
        if not os.isdir(out) then
            os.mkdir(out)
        end
        os.cp(target:targetfile(), out)
    end)
target_end()

-- The pure core (no game, no SKSE) run against the shipped SLOVE.toml:
--   xmake build core-tests && xmake run core-tests <dist\SKSE\Plugins\SLOVE>
target("core-tests")
    set_kind("binary")
    set_default(false)
    add_packages("toml++")
    add_files("src/core/*.cpp", "tests/*.cpp")
    add_includedirs("src")
    add_cxxflags("cl::/utf-8")
target_end()
