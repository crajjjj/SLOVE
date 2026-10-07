# SLO VE build.
#
#   .\scripts\build.ps1                   # SLOVE.dll + both script sets + the FOMOD
#   .\scripts\build.ps1 -Variant PPlus    # P+ scripts only
#   .\scripts\build.ps1 -Variant Classic  # classic-SexLab scripts only
#   .\scripts\build.ps1 -NoFomod          # skip FOMOD packaging
#   .\scripts\build.ps1 -NoFomod -NoPlugin   # both script sets, no C++ toolchain needed
#
# Every run starts with scripts\check-config.ps1 (settings in step across the
# scripts, SLOVE.toml, the menu schema and the docs), which also writes the
# generated SLOVE.defaults.toml.
#
# The full build also compiles skse\ (SLOVE.dll, the in-game settings menu:
# xmake 3.0+, VS 2022, the CommonLibSSE-NG submodule) and runs its core-tests
# against the shipped SLOVE.toml. A FOMOD is never packaged without it.
#
# SLO VE ships two script sets that differ only in the framework-facing scripts
# (Director, SFX, Expressions, Resistance, Hentairim_Tags, NpcScene, ThreadHook):
#   papyrus\Source          -> SexLab Framework P+ 2.x   (default, -> dist)
#   papyrus\classic\Source  -> SexLab SE 1.63 + SLSO     (-> dist-classic)
# Everything else - SLOVE_Voice included since the variant unification - is
# framework-free and ships once, from papyrus\Source: Voice reads SexLab only
# through SLOVE_Director's adapter API, so ONE compiled pex (in the FOMOD Core)
# serves both variants. Assert-VariantTypes enforces that it stays that way.
#
# Overrides: PYRO_EXE, SKYRIM_GAME_PATH, SLOVE_BUILD_FOLDER, XMAKE_EXE.
param(
    [ValidateSet('Both', 'PPlus', 'Classic')]
    [string]$Variant = 'Both',
    [switch]$NoFomod,
    [switch]$NoPlugin
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

$packaging = (-not $NoFomod -and $Variant -eq 'Both')
if ($NoPlugin -and $packaging) {
    throw '-NoPlugin cannot package the FOMOD: a release carries the SLOVE.dll built from this tree. Add -NoFomod, or drop -NoPlugin.'
}

# The mod has ONE version, fomod\info.xml: the archive name and the file version
# stamped into SLOVE.dll both come from it, so neither can drift from what the
# installer reports.
[xml]$info = Get-Content (Join-Path $root 'fomod\info.xml') -Raw
$version = $info.fomod.Version.InnerText.Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw "fomod\info.xml <Version> is '$version' - expected major.minor.patch" }

$pyro = $env:PYRO_EXE
if (-not $pyro -or -not (Test-Path $pyro)) {
    $candidate = Get-ChildItem "$env:USERPROFILE\.vscode\extensions\joelday.papyrus-lang-vscode-*\pyro\pyro.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($candidate) { $pyro = $candidate.FullName }
}
if (-not $pyro) { throw 'pyro.exe not found - set PYRO_EXE' }

$game = $env:SKYRIM_GAME_PATH
if (-not $game) { $game = 'C:\SteamLibrary\steamapps\common\Skyrim Special Edition' }

$basePpj = Join-Path $root 'SLOVE.ppj'
if (-not (Test-Path $basePpj)) { throw "SLOVE.ppj not found at $basePpj (it is git-ignored; see README)" }

# --------------------------------------------------------------- SLOVE.dll ---
function Assert-PluginDll([string]$path) {
    $have = (Get-Item $path).VersionInfo.FileVersion
    if ($have -ne "$version.0") {
        throw "$path is version '$have' but fomod\info.xml says $version - a DLL from another build. Rebuild with this script."
    }
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $machine = [BitConverter]::ToUInt16($bytes, [BitConverter]::ToInt32($bytes, 0x3C) + 4)
    if ($machine -ne 0x8664) { throw "$path is not an x64 image (machine 0x$($machine.ToString('X4')))" }
}

# The in-game settings menu (skse\: xmake + CommonLibSSE-NG). skse\xmake.lua
# copies the DLL, and only the DLL, to dist\SKSE\Plugins; Build-Fomod then ships
# it in Core like everything else under dist.
function Build-Plugin {
    Write-Host '=== Building SLOVE.dll (in-game settings menu) -> dist\SKSE\Plugins ===' -ForegroundColor Cyan
    $skse = Join-Path $root 'skse'

    $xmake = $env:XMAKE_EXE
    if (-not $xmake) {
        $found = Get-Command xmake -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $xmake = $found.Source }
    }
    if (-not $xmake -or -not (Test-Path $xmake)) {
        throw 'xmake not found - install xmake 3.0 or newer (https://xmake.io) or set XMAKE_EXE. For the scripts alone: -NoFomod -NoPlugin'
    }
    foreach ($p in @('lib\commonlibsse-ng\xmake.lua', 'lib\commonlibsse-ng\extern\openvr\headers\openvr.h')) {
        if (-not (Test-Path (Join-Path $skse $p))) {
            throw "skse\$p is missing - run: git submodule update --init --recursive"
        }
    }

    # The install trap (see skse\xmake.lua): the CommonLib plugin rule runs
    # `xmake install` after every build, into %XSE_TES5_MODS_PATH%\<target> - a
    # stray "SLOVE" folder in the live Mod Organizer mods directory. xmake.lua
    # disarms it twice; here the child never sees the variables, and the folder
    # appearing anyway fails the build.
    $stray = $null
    if ($env:XSE_TES5_MODS_PATH) { $stray = Join-Path $env:XSE_TES5_MODS_PATH 'SLOVE' }
    $strayBefore = ($null -ne $stray) -and (Test-Path $stray)
    $savedMods = $env:XSE_TES5_MODS_PATH
    $savedGame = $env:XSE_TES5_GAME_PATH
    $env:XSE_TES5_MODS_PATH = $null
    $env:XSE_TES5_GAME_PATH = $null
    Push-Location $skse
    try {
        & $xmake f -y -m release "--slove_version=$version"
        if ($LASTEXITCODE -ne 0) { throw "xmake configure failed (exit $LASTEXITCODE)" }
        & $xmake build -y SLOVE
        if ($LASTEXITCODE -ne 0) { throw "SLOVE.dll failed to build (exit $LASTEXITCODE)" }
        & $xmake build -y core-tests
        if ($LASTEXITCODE -ne 0) { throw "core-tests failed to build (exit $LASTEXITCODE)" }
    } finally {
        Pop-Location
        $env:XSE_TES5_MODS_PATH = $savedMods
        $env:XSE_TES5_GAME_PATH = $savedGame
    }
    if (($null -ne $stray) -and -not $strayBefore -and (Test-Path $stray)) {
        throw "the plugin build created $stray - the install guards in skse\xmake.lua no longer hold. Delete that folder and fix them before building again."
    }

    # The pure core against the file that ships: the writer must leave every key
    # it does not change byte-identical, and the schema must describe every key.
    $out = Join-Path $skse 'build\windows\x64\release'
    & (Join-Path $out 'core-tests.exe') (Join-Path $root 'dist\SKSE\Plugins\SLOVE')
    if ($LASTEXITCODE -ne 0) { throw "core-tests FAILED (exit $LASTEXITCODE) - the menu's config writer or its schema is broken" }

    $built = Join-Path $out 'SLOVE.dll'
    $dll = Join-Path $root 'dist\SKSE\Plugins\SLOVE.dll'
    foreach ($p in @($built, $dll)) {
        if (-not (Test-Path $p)) { throw "expected $p after the plugin build" }
    }
    if ((Get-FileHash $built).Hash -ne (Get-FileHash $dll).Hash) {
        throw 'dist\SKSE\Plugins\SLOVE.dll is not the DLL just built - the after_build copy in skse\xmake.lua did not run'
    }
    Assert-PluginDll $dll
    Write-Host "SLOVE.dll $version OK (x64, core-tests passed)" -ForegroundColor Green
}

# ---------------------------------------------------------------- P+ build ---
function Build-PPlus {
    Write-Host '=== Building P+ script set -> dist\Scripts ===' -ForegroundColor Cyan
    $srcOut = Join-Path $root 'dist\Scripts\Source'
    New-Item -ItemType Directory -Force $srcOut | Out-Null
    Copy-Item (Join-Path $root 'papyrus\Source\*.psc') $srcOut -Force

    & $pyro -i $basePpj --game-path $game
    if ($LASTEXITCODE -ne 0) { throw "Pyro failed for the P+ script set (exit $LASTEXITCODE)" }
}

# ------------------------------------------------------------ classic build ---
# Derive a classic .ppj from SLOVE.ppj: swap the compile folder, the output
# folder, and the SexLab import (P+ -> SLSO + classic 1.63). SLSO is imported
# ahead of classic SexLab because it ships an sslActorAlias override.
function Build-Classic {
    Write-Host '=== Building classic-SexLab script set -> dist-classic\Scripts ===' -ForegroundColor Cyan

    $buildFolder = $env:SLOVE_BUILD_FOLDER
    if (-not $buildFolder) { $buildFolder = 'C:\Playground\Skyrim\mods\build' }

    # NOTE: classic SexLab's sslSystemConfig.psc calls FNIS.GetMajor/VersionCompare/
    # IsGenerated, and the compiler resolves that file transitively via
    # SexLabFramework's "sslSystemConfig property Config". SLO VE never calls FNIS,
    # so papyrus\stubs\FNIS.psc satisfies the type-check - no FNIS source tree
    # needed. (papyrus\stubs is already on the import path.)
    $classicSexLab = Join-Path $buildFolder 'SexLabFrameworkSE_v163\scripts\Source'
    $slso          = Join-Path $buildFolder 'SexLab Separate Orgasm\Scripts\Source'
    foreach ($p in @($classicSexLab, $slso)) {
        if (-not (Test-Path $p)) { throw "classic build needs sources at: $p (set SLOVE_BUILD_FOLDER)" }
    }

    $ppj = Get-Content $basePpj -Raw

    # Every derive-replace below MUST match, or the classic build would silently
    # compile/output the wrong thing. A missed Output replace once wrote classic
    # pexes into dist\Scripts, and Pyro's incremental build then preserved the
    # stale classic SLOVE_Hentairim_Tags.pex there across releases (0.5.0-0.6.2):
    # its sslBaseAnimation signature made every P+ label call fail, killing the
    # whole label-driven voice engine downstream. Hence Invoke-StrictReplace + the
    # Assert-VariantTypes post-build check.
    function Invoke-StrictReplace([string]$text, [string]$pattern, [string]$replacement) {
        if ($text -notmatch [regex]::Escape($pattern)) {
            throw "Could not find '$pattern' in SLOVE.ppj - update build.ps1 to match your ppj"
        }
        return $text -replace [regex]::Escape($pattern), $replacement
    }

    # output + packaging
    $ppj = Invoke-StrictReplace $ppj 'Output="dist\Scripts"' 'Output="dist-classic\Scripts"'
    $ppj = Invoke-StrictReplace $ppj 'Zip="true"' 'Zip="false"'

    # compile the classic sources instead of the P+ ones
    $ppj = Invoke-StrictReplace $ppj '<Folder>.\papyrus\Source</Folder>' '<Folder>.\papyrus\classic\Source</Folder>'

    # resolve classic scripts first, then fall through to papyrus\Source for the
    # framework-free scripts (Config, Log, Test, VoiceCategories - and SLOVE_Voice,
    # which is unified: classic has no copy, so the compiler resolves the shared one)
    $ppj = Invoke-StrictReplace $ppj '<Import>.\papyrus\Source</Import>' `
                         "<Import>.\papyrus\classic\Source</Import>`n        <Import>.\papyrus\Source</Import>"

    # SexLab P+ -> SLSO + classic 1.63
    $pplusImport = '<Import>@BuildFolder\SexLab Framework PPLUS - V2.19.0\Source\Scripts</Import>'
    $classicImports = "<Import>$slso</Import>`n        <Import>$classicSexLab</Import>"
    if ($ppj -notmatch [regex]::Escape($pplusImport)) {
        throw 'Could not find the SexLab P+ <Import> line in SLOVE.ppj - update build.ps1 to match your ppj'
    }
    $ppj = $ppj -replace [regex]::Escape($pplusImport), $classicImports

    $classicPpj = Join-Path $root 'SLOVE-classic.ppj'
    Set-Content -Path $classicPpj -Value $ppj -Encoding UTF8

    $srcOut = Join-Path $root 'dist-classic\Scripts\Source'
    New-Item -ItemType Directory -Force $srcOut | Out-Null
    Copy-Item (Join-Path $root 'papyrus\classic\Source\*.psc') $srcOut -Force

    & $pyro -i $classicPpj --game-path $game
    if ($LASTEXITCODE -ne 0) { throw "Pyro failed for the classic script set (exit $LASTEXITCODE)" }
}

# -------------------------------------------------------- variant type guard ---
# A compiled .pex embeds every type it references in its string table, so a
# cross-variant contamination (a classic pex in dist, or a P+ pex in
# dist-classic) is detectable byte-wise: classic scripts reference
# sslBaseAnimation (classic SexLab), P+ scripts reference SexLabThread (P+).
# This caught nothing until it caught everything - a stale classic
# SLOVE_Hentairim_Tags.pex shipped in the P+ Core of 0.5.0-0.6.2 and broke the
# entire label engine (every label call failed on the type mismatch). Runs after
# every build; checks whichever dist trees exist, so stale leftovers are caught
# even when only one variant was rebuilt.
function Assert-VariantTypes {
    $variantScripts = @('SLOVE_Director', 'SLOVE_SFX',
                        'SLOVE_Expressions', 'SLOVE_Resistance', 'SLOVE_Hentairim_Tags')
    # dist tree -> type that must NOT appear in its pexes
    $forbidden = @{ 'dist' = 'sslBaseAnimation'; 'dist-classic' = 'SexLabThread' }
    $bad = @()
    foreach ($d in $forbidden.Keys) {
        foreach ($s in $variantScripts) {
            $pex = Join-Path $root "$d\Scripts\$s.pex"
            if (-not (Test-Path $pex)) { continue }
            $text = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($pex))
            if ($text.IndexOf($forbidden[$d], [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $bad += "$d\Scripts\$s.pex references $($forbidden[$d]) - wrong/stale variant compile"
            }
        }
    }

    # Unified scripts (one pex serves both variants from the FOMOD Core) must be
    # FRAMEWORK-FREE: any direct SexLab type reference means someone bypassed the
    # Director adapter and the single pex would break one of the two frameworks.
    # A stale copy in dist-classic is just as fatal - the FOMOD's ClassicScripts
    # overlay would shadow the unified Core pex with an outdated build.
    $unifiedScripts = @('SLOVE_Voice', 'SLOVE_NpcVoice', 'SLOVE_PPA', 'SLOVE_Utils')
    $frameworkTypes = @('SexLabThread', 'sslBaseAnimation', 'sslThreadController',
                        'SexlabRegistry', 'sslActorAlias')
    foreach ($s in $unifiedScripts) {
        $pex = Join-Path $root "dist\Scripts\$s.pex"
        if (Test-Path $pex) {
            $text = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($pex))
            foreach ($t in $frameworkTypes) {
                if ($text.IndexOf($t, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    $bad += "dist\Scripts\$s.pex references $t - unified script must stay framework-free (route the call through SLOVE_Director)"
                }
            }
        }
        if (Test-Path (Join-Path $root "dist-classic\Scripts\$s.pex")) {
            $bad += "dist-classic\Scripts\$s.pex exists - $s is unified; delete it or the FOMOD ships a stale shadow over the Core copy"
        }
    }

    if ($bad) {
        throw ("variant type check FAILED:`n  " + ($bad -join "`n  ") +
               "`nDelete the offending .pex files and rebuild (Pyro's incremental build preserves stale outputs).")
    }
    Write-Host 'variant type check OK (no cross-variant contamination; unified scripts framework-free)' -ForegroundColor Green
}

# ------------------------------------------------------------ FOMOD package ---
# Release\FOMOD\
#   fomod\{info,ModuleConfig}.xml
#   Core\            <- the whole dist tree (P+ scripts are the default set;
#                       unified scripts like SLOVE_Voice serve BOTH variants)
#   ClassicScripts\  <- the classic .pex + sources, installed over Core
function Build-Fomod {
    Write-Host '=== Assembling FOMOD ===' -ForegroundColor Cyan
    $stage = Join-Path $root 'Release\FOMOD'
    if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
    New-Item -ItemType Directory -Force $stage | Out-Null

    # fomod metadata
    Copy-Item (Join-Path $root 'fomod') (Join-Path $stage 'fomod') -Recurse -Force

    # Core = everything the P+ build produced/ships
    $core = Join-Path $stage 'Core'
    New-Item -ItemType Directory -Force $core | Out-Null
    Copy-Item (Join-Path $root 'dist\*') $core -Recurse -Force
    # never ship stray backups
    Get-ChildItem $core -Recurse -Filter '*.bak-*' -ErrorAction SilentlyContinue | Remove-Item -Force

    # Every tongue mesh SLOVE.esp names must ship: an addon without its mesh is an
    # invisible tongue on that addon's races. The Khajiit and Argonian copies are
    # generated (tools\tonguefit\fit_tongues.py), which makes them easy to forget.
    $baseEsp = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes((Join-Path $core 'SLOVE.esp')))
    $tongues = @([regex]::Matches($baseEsp, 'SLOVE\\tongues\\[\x20-\x7e]+?\.nif') | ForEach-Object { $_.Value } | Sort-Object -Unique)
    $lost = @($tongues | Where-Object { -not (Test-Path -LiteralPath (Join-Path $core "meshes\$_")) })
    if ($lost.Count) { throw "SLOVE.esp names tongue meshes that dist\meshes does not hold: $($lost -join ', ') - run tools\tonguefit\fit_tongues.py" }
    if ($tongues.Count -lt 30) { throw "SLOVE.esp names $($tongues.Count) tongue meshes, expected 30 (ten each: standard, Khajiit, Argonian)" }
    $python = Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($python) {
        & $python.Source (Join-Path $root 'tools\tonguefit\fit_tongues.py') --check
        if ($LASTEXITCODE -ne 0) { throw 'the beast-race tongue meshes are not what tools\tonguefit\fit_tongues.py produces - rerun it without arguments' }
        # the BodySlide projects hold a copy of every tongue mesh: stale copies would
        # build yesterday's fit
        & $python.Source (Join-Path $root 'tools\tonguefit\make_bodyslide.py') --check
        if ($LASTEXITCODE -ne 0) { throw 'the BodySlide tongue projects are stale - run tools\tonguefit\make_bodyslide.py' }
    } else {
        Write-Warning 'python not found - skipped the tongue mesh and BodySlide project checks (tools\tonguefit\*.py --check)'
    }
    Write-Host "tongue meshes: $($tongues.Count) named by SLOVE.esp, all staged" -ForegroundColor Cyan

    # ClassicScripts = the classic overrides
    $classicDist = Join-Path $root 'dist-classic\Scripts'
    if (Test-Path $classicDist) {
        $cs = Join-Path $stage 'ClassicScripts\Scripts'
        New-Item -ItemType Directory -Force (Join-Path $cs 'Source') | Out-Null
        Copy-Item (Join-Path $classicDist '*.pex') $cs -Force
        Copy-Item (Join-Path $classicDist 'Source\*.psc') (Join-Path $cs 'Source') -Force
    } else {
        Write-Warning 'dist-classic not built - FOMOD will offer only the P+ option'
    }

    # PPACompat = silent twins of the contact-SFX folders that collide with PPA's
    # own thrust audio (idea + folder set by DuskWanderer). Generated, not stored:
    # each shipped wav is copied and its PCM data chunk zeroed, so format and
    # DURATION are preserved - the SFX loop paces itself with PlaySFXAndWait, so a
    # shorter silent file would speed the loop up. Kissing / Ejaculation / Gape
    # stay audible on purpose: PPA does not cover them.
    $ppaFolders = @('blowjob', 'FastClap', 'HeavySlushing', 'Impact', 'LightSlushing',
                    'MediumClap', 'MediumSlushing', 'RapidSlushing', 'SlowClap', 'WetSlush')
    $sfxRoot = Join-Path $root 'dist\Sound\fx\SloveSFX'
    $script:ppaCount = 0   # $script: scope - ForEach-Object body below can't see a plain local
    foreach ($pf in $ppaFolders) {
        $src = Join-Path $sfxRoot $pf
        if (-not (Test-Path $src)) { Write-Warning "PPACompat: SFX folder missing: $src"; continue }
        Get-ChildItem $src -Recurse -Filter '*.wav' | ForEach-Object {
            $rel = $_.FullName.Substring($sfxRoot.Length + 1)
            $out = Join-Path $stage "PPACompat\Sound\fx\SloveSFX\$rel"
            New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
            $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
            # walk RIFF chunks to the data chunk, zero its payload
            $pos = 12
            while ($pos + 8 -le $bytes.Length) {
                $id = [System.Text.Encoding]::ASCII.GetString($bytes, $pos, 4)
                $size = [BitConverter]::ToUInt32($bytes, $pos + 4)
                if ($id -eq 'data') {
                    $end = [Math]::Min($pos + 8 + $size, $bytes.Length)
                    [Array]::Clear($bytes, $pos + 8, $end - ($pos + 8))
                    break
                }
                $pos += 8 + $size + ($size % 2)   # chunks are word-aligned
            }
            [System.IO.File]::WriteAllBytes($out, $bytes)
            $script:ppaCount++
        }
    }
    Write-Host "PPACompat: $($script:ppaCount) silent SFX twins generated" -ForegroundColor Cyan

    # UBESupport = the optional UBE custom-race tongue option: SLOVE_UBE_Support.esp
    # plus the UBE-fitted tongue meshes its armor addons point at
    # (meshes\!UBE\SLOVE\tongues). Stored, not generated: the esp has
    # UBE_AllRace.esp as a master, so it can only be authored with UBE loaded
    # (optional\UBESupport\README.md). We stage the esp and the meshes; the README
    # stays out of the install. Warn (don't fail) if the esp is absent, exactly
    # like dist-classic - but an esp naming a mesh we do not ship is an invisible
    # tongue in game, so that one is a hard error.
    $ubeSrc = Join-Path $root 'optional\UBESupport'
    $ubeEsp = Join-Path $ubeSrc 'SLOVE_UBE_Support.esp'
    if (Test-Path $ubeEsp) {
        $ubeStage = Join-Path $stage 'UBESupport'
        New-Item -ItemType Directory -Force $ubeStage | Out-Null
        Copy-Item $ubeEsp $ubeStage -Force
        $ubeMeshes = Join-Path $ubeSrc 'meshes'
        if (Test-Path $ubeMeshes) { Copy-Item $ubeMeshes $ubeStage -Recurse -Force }
        # the BodySlide project for the UBE-fitted tongues (tools\tonguefit\make_bodyslide.py)
        $ubeBodySlide = Join-Path $ubeSrc 'CalienteTools'
        if (Test-Path $ubeBodySlide) { Copy-Item $ubeBodySlide $ubeStage -Recurse -Force }
        $espText = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($ubeEsp))
        $named = @([regex]::Matches($espText, '!UBE\\[\x20-\x7e]+?\.nif') | ForEach-Object { $_.Value } | Sort-Object -Unique)
        $missing = @($named | Where-Object { -not (Test-Path -LiteralPath (Join-Path $ubeStage "meshes\$_")) })
        if ($missing.Count) { throw "UBESupport: SLOVE_UBE_Support.esp names meshes missing from optional\UBESupport\meshes: $($missing -join ', ')" }
        if (-not $named.Count) { throw 'UBESupport: SLOVE_UBE_Support.esp names no !UBE mesh - it is the pre-0.6.28 race-list patch, rebuild it (optional\UBESupport\README.md).' }
        Write-Host "UBESupport: staged SLOVE_UBE_Support.esp + $($named.Count) UBE tongue meshes" -ForegroundColor Cyan
    } else {
        Write-Warning "UBESupport: optional\UBESupport\SLOVE_UBE_Support.esp not found - FOMOD's UBE option will install nothing. Author it with UBE loaded (optional\UBESupport\README.md)."
    }

    # The in-game menu ships in Core for both variants: the DLL built by this run,
    # its schema, and the generated defaults. Checked on the staging tree, before
    # an archive exists that could be uploaded without them.
    $plugins = Join-Path $core 'SKSE\Plugins'
    foreach ($f in @('SLOVE.dll', 'SLOVE\SLOVE.toml', 'SLOVE\SLOVE_Menu.toml', 'SLOVE\SLOVE.defaults.toml')) {
        if (-not (Test-Path (Join-Path $plugins $f))) { throw "release check FAILED: Core\SKSE\Plugins\$f is missing" }
    }
    Assert-PluginDll (Join-Path $plugins 'SLOVE.dll')
    $pdbs = @(Get-ChildItem $stage -Recurse -Filter '*.pdb')
    if ($pdbs.Count) { throw "release check FAILED: debug symbols staged for release: $($pdbs.FullName -join ', ')" }
    Write-Host "release check OK (SLOVE.dll $version, menu schema and defaults in Core; no pdb)" -ForegroundColor Green

    # Release archives are named SLO_VE_v<version>.zip, from fomod\info.xml (read
    # once, at the top).
    $zip = Join-Path $root "Release\SLO_VE_v$version.zip"
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal
    Write-Host "FOMOD archive: $zip" -ForegroundColor Green
}

& (Join-Path $PSScriptRoot 'check-config.ps1') -WriteDefaults
if ($Variant -eq 'Both' -and -not $NoPlugin) {
    Build-Plugin
} else {
    # Not rebuilt in this run. dist is what gets copied to a test install, so say
    # so when the DLL sitting there belongs to another version.
    $distDll = Join-Path $root 'dist\SKSE\Plugins\SLOVE.dll'
    if (Test-Path $distDll) {
        $have = (Get-Item $distDll).VersionInfo.FileVersion
        if ($have -ne "$version.0") {
            Write-Warning "dist\SKSE\Plugins\SLOVE.dll is version $have, not $version - the plugin was not built in this run"
        }
    }
}
if ($Variant -eq 'Both' -or $Variant -eq 'PPlus')   { Build-PPlus }
if ($Variant -eq 'Both' -or $Variant -eq 'Classic') { Build-Classic }
Assert-VariantTypes
if ($packaging)                                     { Build-Fomod }
