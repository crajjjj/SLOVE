# SexLab P+ version-gate check (docs\smoke-test.md section 3a).
#
#   .\scripts\check-pplus-compat.ps1
#   .\scripts\check-pplus-compat.ps1 -Headers 'D:\some P+ 2.18\Source\Scripts'
#
# The P+ script set is compiled against the P+ 2.19 headers but ships for P+
# 2.17+. Three SexLabThread members exist only from 2.19 on, and Papyrus binds a
# member call when it is DISPATCHED - so the build is safe on an older P+ exactly
# as long as each of those calls sits behind InteractionsLive() (the version
# probe, SLOVE_Utils.HasInteractionAPI). Two checks:
#
#   1. gate audit      every function that calls one of the three checks
#                      InteractionsLive() first (two documented exceptions)
#   2. stubbed compile the P+ set compiles against each older P+'s headers with
#                      ONLY those three functions declared on its SexLabThread -
#                      so nothing ELSE the scripts use is missing there either
#
# Overrides: PYRO_EXE, SKYRIM_GAME_PATH, SLOVE_BUILD_FOLDER.
param(
    # Source\Scripts folders of the older P+ versions to compile against.
    # Default: every "SexLab Framework PPLUS - V2.17*" / "V2.18*" in the build folder.
    [string[]]$Headers
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$failed = $false

# The members SexLab P+ gained in 2.19, as declared there. Add to this list (and
# gate the call) when the stubbed compile names another one.
$gated = [ordered]@{
    'GetInteractionFlags'         = 'bool[] Function GetInteractionFlags(Actor akPosition)'
    'GetPartnerByInteractionType' = 'Actor Function GetPartnerByInteractionType(Actor akPosition, int InterTypes)'
    'GetInteractionVelocity'      = 'float Function GetInteractionVelocity(Actor akPosition, Actor akPartner, int InterTypes)'
}

# Calls with no InteractionsLive() of their own: both need a FuckingPartner, and
# only UpdateFuckingPartner - which IS gated - ever sets one.
$exceptions = @('SLOVE_SFX.psc:CalculateAndPlayVelocitySFX', 'SLOVE_SFX.psc:RunAdaptiveVelocitySFX')

# ---------------------------------------------------------------- gate audit ---
Write-Host '=== Gate audit: P+ 2.19-only calls behind InteractionsLive() ===' -ForegroundColor Cyan
$apiPattern = '\.(' + ($gated.Keys -join '|') + ')\s*\('
$calls = 0
foreach ($file in Get-ChildItem (Join-Path $root 'papyrus\Source\*.psc')) {
    $func = $null
    $body = New-Object System.Text.StringBuilder
    foreach ($raw in Get-Content $file.FullName) {
        $code = ($raw -split ';', 2)[0]
        if ($code -match '^\s*end(function|event)\b') { $func = $null; continue }
        if ($code -match '^\s*(?:[\w\[\]]+\s+)?(?:function|event)\s+(\w+)') {
            $func = $Matches[1]
            [void]$body.Clear()
            continue
        }
        if ($func -and $code -match $apiPattern) {
            $calls++
            $key = "$($file.Name):$func"
            if ($body.ToString() -notmatch 'InteractionsLive\(\)' -and $exceptions -notcontains $key) {
                Write-Host "UNGATED  $key calls $($Matches[1]) with no InteractionsLive() before it" -ForegroundColor Red
                $failed = $true
            }
        }
        [void]$body.AppendLine($code)
    }
}
if ($calls -eq 0) {
    Write-Host 'no gated call found at all - the member list above no longer matches the sources' -ForegroundColor Red
    $failed = $true
} elseif (-not $failed) {
    Write-Host "OK - $calls call(s), all gated"
}

# ------------------------------------------------------------ stubbed compile ---
$pyro = $env:PYRO_EXE
if (-not $pyro -or -not (Test-Path $pyro)) {
    $candidate = Get-ChildItem "$env:USERPROFILE\.vscode\extensions\joelday.papyrus-lang-vscode-*\pyro\pyro.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($candidate) { $pyro = $candidate.FullName }
}
if (-not $pyro) { throw 'pyro.exe not found - set PYRO_EXE' }

$game = $env:SKYRIM_GAME_PATH
if (-not $game) { $game = 'C:\SteamLibrary\steamapps\common\Skyrim Special Edition' }

$buildFolder = $env:SLOVE_BUILD_FOLDER
if (-not $buildFolder) { $buildFolder = 'C:\Playground\Skyrim\mods\build' }

if (-not $Headers) {
    $Headers = Get-ChildItem $buildFolder -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^SexLab Framework PPLUS - V2\.1[78]' } |
        ForEach-Object { Get-ChildItem $_.FullName -Recurse -Filter 'SexLabThread.psc' | Select-Object -First 1 } |
        ForEach-Object { $_.DirectoryName }
}
if (-not $Headers) { throw "no older SexLab P+ headers found under $buildFolder - pass -Headers <Source\Scripts folder>" }

$basePpj = Join-Path $root 'SLOVE.ppj'
if (-not (Test-Path $basePpj)) { throw "SLOVE.ppj not found at $basePpj (it is git-ignored; see README)" }
$pplusImport = '@BuildFolder\SexLab Framework PPLUS - V2.19.0\Source\Scripts'

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("slove-pplus-compat-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $work | Out-Null
try {
    $n = 0
    foreach ($h in $Headers) {
        $n++
        Write-Host "=== Stubbed compile against: $h ===" -ForegroundColor Cyan
        $thread = Join-Path $h 'SexLabThread.psc'
        if (-not (Test-Path $thread)) { throw "no SexLabThread.psc in $h" }
        $present = $gated.Keys | Where-Object { (Get-Content $thread -Raw) -match "(?im)^\s*[\w\[\]]+\s+function\s+$_\s*\(" }
        if ($present) {
            Write-Host "skipped - these headers already declare $($present -join ', ') (P+ 2.19 or newer?)" -ForegroundColor Yellow
            continue
        }

        $hdr = Join-Path $work "hdr$n"
        $out = Join-Path $work "out$n"
        New-Item -ItemType Directory -Force $hdr, $out | Out-Null
        Copy-Item (Join-Path $h '*.psc') $hdr -Force
        $stub = "`r`n; --- compile-check stubs: the SexLab P+ 2.19 interaction functions ---`r`n" +
                (($gated.Values | ForEach-Object { "$_`r`nEndFunction" }) -join "`r`n") + "`r`n"
        Add-Content -Path (Join-Path $hdr 'SexLabThread.psc') -Value $stub -Encoding UTF8

        $ppj = Get-Content $basePpj -Raw
        foreach ($needle in @('Output="dist\Scripts"', 'Zip="true"', $pplusImport, '.\papyrus\Source', '.\papyrus\stubs')) {
            if (-not $ppj.Contains($needle)) { throw "Could not find '$needle' in SLOVE.ppj - update check-pplus-compat.ps1 to match your ppj" }
        }
        $ppj = $ppj.Replace('Output="dist\Scripts"', "Output=`"$out`"").Replace('Zip="true"', 'Zip="false"')
        $ppj = $ppj.Replace($pplusImport, $hdr)
        $ppj = $ppj.Replace('.\papyrus\Source', (Join-Path $root 'papyrus\Source')).Replace('.\papyrus\stubs', (Join-Path $root 'papyrus\stubs'))
        $ppjPath = Join-Path $work "compat$n.ppj"
        Set-Content -Path $ppjPath -Value $ppj -Encoding UTF8

        $log = & $pyro -i $ppjPath --game-path $game 2>&1 | ForEach-Object { "$_" }
        $errors = $log | Where-Object { $_ -match 'psc\(\d+,\d+\)' } |
            ForEach-Object { $_ -replace '^.*COMPILATION FAILED:\s*', '' } | Sort-Object -Unique
        $summary = $log | Where-Object { $_ -match '\d+ succeeded, \d+ failed' } | Select-Object -Last 1
        if ($errors -or $summary -notmatch ' 0 failed' -or $summary -match '\b0 succeeded') {
            $errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
            Write-Host ("FAILED - " + ($summary -replace '^.*Compile time:[^-]*-\s*', '')) -ForegroundColor Red
            $failed = $true
        } else {
            Write-Host ("OK - " + ($summary -replace '^.*Compile time:[^-]*-\s*', ''))
        }
    }
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failed) { throw 'SexLab P+ version-gate check FAILED - see above' }
Write-Host 'SexLab P+ version-gate check OK' -ForegroundColor Green
