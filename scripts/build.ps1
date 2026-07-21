# SLO VE build: mirror sources into dist, compile via Pyro (also writes the
# Release\ zip since the ppj has Zip="true").
# Overrides: PYRO_EXE, SKYRIM_GAME_PATH.
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

$srcOut = Join-Path $root 'dist\Scripts\Source'
New-Item -ItemType Directory -Force $srcOut | Out-Null
Copy-Item (Join-Path $root 'papyrus\Source\*.psc') $srcOut -Force

& $pyro -i (Join-Path $root 'SLOVE.ppj') --game-path $game
exit $LASTEXITCODE
