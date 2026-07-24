# SLO VE build.
#
#   .\scripts\build.ps1                   # build both script sets + assemble the FOMOD
#   .\scripts\build.ps1 -Variant PPlus    # P+ scripts only
#   .\scripts\build.ps1 -Variant Classic  # classic-SexLab scripts only
#   .\scripts\build.ps1 -NoFomod          # skip FOMOD packaging
#
# SLO VE ships two script sets that differ only in the six framework-facing
# scripts (Director, Voice, SFX, Expressions, Resistance, Hentairim_Tags):
#   papyrus\Source          -> SexLab Framework P+ 2.x   (default, -> dist)
#   papyrus\classic\Source  -> SexLab SE 1.63 + SLSO     (-> dist-classic)
# The other four scripts are framework-free and ship once, from papyrus\Source.
#
# Overrides: PYRO_EXE, SKYRIM_GAME_PATH, SLOVE_BUILD_FOLDER.
param(
    [ValidateSet('Both', 'PPlus', 'Classic')]
    [string]$Variant = 'Both',
    [switch]$NoFomod
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

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

    # output + packaging
    $ppj = $ppj -replace [regex]::Escape('Output="dist\Scripts"'), 'Output="dist-classic\Scripts"'
    $ppj = $ppj -replace 'Zip="true"', 'Zip="false"'

    # compile the classic sources instead of the P+ ones
    $ppj = $ppj -replace [regex]::Escape('<Folder>.\papyrus\Source</Folder>'), '<Folder>.\papyrus\classic\Source</Folder>'

    # resolve classic scripts first, then fall through to papyrus\Source for the
    # four framework-free scripts (Config, Log, Test, VoiceCategories)
    $ppj = $ppj -replace [regex]::Escape('<Import>.\papyrus\Source</Import>'),
                         "<Import>.\papyrus\classic\Source</Import>`n        <Import>.\papyrus\Source</Import>"

    # SexLab P+ -> SLSO + classic 1.63
    $pplusImport = '<Import>@BuildFolder\SexLab Framework PPLUS - V2.17.1\Source\Scripts</Import>'
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

# ------------------------------------------------------------ FOMOD package ---
# Release\FOMOD\
#   fomod\{info,ModuleConfig}.xml
#   Core\            <- the whole dist tree (P+ scripts are the default set)
#   ClassicScripts\  <- the six classic .pex + sources, installed over Core
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

    # ClassicScripts = the six overrides
    $classicDist = Join-Path $root 'dist-classic\Scripts'
    if (Test-Path $classicDist) {
        $cs = Join-Path $stage 'ClassicScripts\Scripts'
        New-Item -ItemType Directory -Force (Join-Path $cs 'Source') | Out-Null
        Copy-Item (Join-Path $classicDist '*.pex') $cs -Force
        Copy-Item (Join-Path $classicDist 'Source\*.psc') (Join-Path $cs 'Source') -Force
    } else {
        Write-Warning 'dist-classic not built - FOMOD will offer only the P+ option'
    }

    $zip = Join-Path $root 'Release\SLOVE-FOMOD.zip'
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal
    Write-Host "FOMOD archive: $zip" -ForegroundColor Green
}

if ($Variant -eq 'Both' -or $Variant -eq 'PPlus')   { Build-PPlus }
if ($Variant -eq 'Both' -or $Variant -eq 'Classic') { Build-Classic }
if (-not $NoFomod -and $Variant -eq 'Both')         { Build-Fomod }
