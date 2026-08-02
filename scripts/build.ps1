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
    # four framework-free scripts (Config, Log, Test, VoiceCategories)
    $ppj = Invoke-StrictReplace $ppj '<Import>.\papyrus\Source</Import>' `
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
    $variantScripts = @('SLOVE_Director', 'SLOVE_Voice', 'SLOVE_SFX',
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
    if ($bad) {
        throw ("variant type check FAILED:`n  " + ($bad -join "`n  ") +
               "`nDelete the offending .pex files and rebuild (Pyro's incremental build preserves stale outputs).")
    }
    Write-Host 'variant type check OK (no cross-variant pex contamination)' -ForegroundColor Green
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

    # Release archives are named SLO_VE_v<version>.zip. The version is read from
    # fomod\info.xml so there is a single source of truth and the archive name can
    # never drift from what the installer reports.
    [xml]$info = Get-Content (Join-Path $root 'fomod\info.xml') -Raw
    $ver = $info.fomod.Version.InnerText.Trim()
    if (-not $ver) { throw 'could not read <Version> from fomod\info.xml' }

    $zip = Join-Path $root "Release\SLO_VE_v$ver.zip"
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal
    Write-Host "FOMOD archive: $zip" -ForegroundColor Green
}

if ($Variant -eq 'Both' -or $Variant -eq 'PPlus')   { Build-PPlus }
if ($Variant -eq 'Both' -or $Variant -eq 'Classic') { Build-Classic }
Assert-VariantTypes
if (-not $NoFomod -and $Variant -eq 'Both')         { Build-Fomod }
