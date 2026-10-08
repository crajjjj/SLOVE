# SLO VE settings sync check (docs\smoke-test.md section 6).
#
#   .\scripts\check-config.ps1                  # check
#   .\scripts\check-config.ps1 -WriteDefaults   # (re)write SLOVE.defaults.toml, then check
#
# One setting lives in four hand-written places, and nothing at run time says so
# when they drift: a key the scripts read but the toml lacks runs on a fallback
# literal for ever, and a key the menu does not describe shows up as a bare field.
#
#   papyrus\**\*.psc                            SLOVE_Config.Get*("section.key", fallback)
#                                               (or, for a key only SLOVE.dll reads,
#                                               Flag(doc, "section.key"sv, fallback) in skse\src)
#   dist\SKSE\Plugins\SLOVE\SLOVE.toml          the shipped value
#   dist\SKSE\Plugins\SLOVE\SLOVE_Menu.toml     how the in-game menu presents it
#   docs\config\slove.md                        its row in the reference tables
#
# The same goes for the three things SLOVE.dll mirrors from elsewhere: the volume
# buses the scripts set (Bridge.cpp), the SKSE Menu Framework exports the menu
# calls (Env.cpp probes them at load) and its copy of AudioUtil's TomlEdit.h.
#
# Adding a setting = a script read + a toml line + a [[setting]] + a docs row;
# this script names whichever one is missing. It reads the two toml files with a
# small reader of its own (sections, [[tables]], one scalar per line) and stops
# on a line it does not understand; whether they are valid TOML is core-tests'
# job (skse\tests), which parses them with the library the plugin uses.
#
# Windows PowerShell 5.1 compatible. Keep this file ASCII.
param(
    [switch]$WriteDefaults
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$script:failed = $false

$tomlPath     = Join-Path $root 'dist\SKSE\Plugins\SLOVE\SLOVE.toml'
$schemaPath   = Join-Path $root 'dist\SKSE\Plugins\SLOVE\SLOVE_Menu.toml'
$defaultsPath = Join-Path $root 'dist\SKSE\Plugins\SLOVE\SLOVE.defaults.toml'
$docsPath     = Join-Path $root 'docs\config\slove.md'
$skse         = Join-Path $root 'skse'

function Fail([string]$message) { Write-Host "FAIL  $message" -ForegroundColor Red; $script:failed = $true }
function Warn([string]$message) { Write-Host "warn  $message" -ForegroundColor Yellow }
function Section([string]$title) { Write-Host "=== $title ===" -ForegroundColor Cyan }
function Read-Utf8([string]$path) { return [System.IO.File]::ReadAllText($path, (New-Object System.Text.UTF8Encoding($false))) }
function Read-Lines([string]$path) { return ,@((Read-Utf8 $path) -split "`r?`n") }
# a hash of the text, not of the bytes: the same file checked out with CRLF or LF
function Get-TextHash([string]$path) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(((Read-Utf8 $path) -replace "`r`n", "`n"))
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($bytes)) } finally { $sha.Dispose() }
}

# ------------------------------------------------------------- toml reader ---
function Read-TomlValue([string]$text) {
    $tail = '\s*(?:#.*)?$'
    if ($text -cmatch ('^("(?:[^"\\]|\\.)*")' + $tail)) {
        $raw = $Matches[1]
        $value = $raw.Substring(1, $raw.Length - 2).Replace('\"', '"').Replace('\\', '\')
        return [pscustomobject]@{ Raw = $raw; Type = 'string'; Value = $value }
    }
    if ($text -cmatch ("^('[^']*')" + $tail)) {
        $raw = $Matches[1]
        return [pscustomobject]@{ Raw = $raw; Type = 'string'; Value = $raw.Substring(1, $raw.Length - 2) }
    }
    if ($text -cmatch ('^(true|false)' + $tail)) {
        return [pscustomobject]@{ Raw = $Matches[1]; Type = 'bool'; Value = ($Matches[1] -ceq 'true') }
    }
    if ($text -cmatch ('^([+-]?\d+\.\d+(?:[eE][+-]?\d+)?)' + $tail)) {
        $number = [double]::Parse($Matches[1], [System.Globalization.CultureInfo]::InvariantCulture)
        return [pscustomobject]@{ Raw = $Matches[1]; Type = 'float'; Value = $number }
    }
    if ($text -cmatch ('^([+-]?\d+)' + $tail)) {
        return [pscustomobject]@{ Raw = $Matches[1]; Type = 'int'; Value = [long]$Matches[1] }
    }
    return $null
}

# One object per "key = value" line: the table it sits in, and for a [[table]]
# which one of them (Index, counted from 0).
function Read-Toml([string]$path) {
    $entries = @()
    $table = ''
    $index = -1
    $seen = @{}
    $n = 0
    foreach ($line in (Read-Lines $path)) {
        $n++
        $text = $line.Trim()
        if ($text -eq '' -or $text.StartsWith('#')) { continue }
        if ($text -cmatch '^\[\[([A-Za-z0-9_]+)\]\]\s*(?:#.*)?$') {
            $table = $Matches[1]
            if (-not $seen.ContainsKey($table)) { $seen[$table] = 0 }
            $index = $seen[$table]
            $seen[$table] = $index + 1
            continue
        }
        if ($text -cmatch '^\[([A-Za-z0-9_]+)\]\s*(?:#.*)?$') {
            $table = $Matches[1]
            $index = -1
            continue
        }
        if ($text -cmatch '^([A-Za-z0-9_]+)\s*=\s*(.+)$') {
            $key = $Matches[1]
            $value = Read-TomlValue $Matches[2]
            if ($null -eq $value) { throw "${path}(${n}): check-config.ps1 cannot read this value: $text" }
            $entries += [pscustomobject]@{
                Table = $table; Index = $index; Key = $key; Line = $n
                Raw = $value.Raw; Type = $value.Type; Value = $value.Value
            }
            continue
        }
        throw "${path}(${n}): check-config.ps1 cannot read this line: $text"
    }
    return ,$entries
}

function Compare-Sets([string]$nameA, $a, [string]$nameB, $b) {
    $onlyA = @($a | Where-Object { $b -notcontains $_ } | Sort-Object)
    $onlyB = @($b | Where-Object { $a -notcontains $_ } | Sort-Object)
    if ($onlyA.Count) { Fail "in $nameA but not in ${nameB}: $($onlyA -join ', ')" }
    if ($onlyB.Count) { Fail "in $nameB but not in ${nameA}: $($onlyB -join ', ')" }
    return ($onlyA.Count + $onlyB.Count) -eq 0
}

# The code of a source line: everything before the comment, strings kept whole.
function Get-PapyrusCode([string]$line) { return [regex]::Match($line, '^(?:[^";]|"(?:[^"\\]|\\.)*")*').Value }
function Get-CppCode([string]$line) { return [regex]::Match($line, '^(?:[^"/]|"(?:[^"\\]|\\.)*"|/(?!/))*').Value }

# --------------------------------------------------------------- the files ---
foreach ($p in @($tomlPath, $schemaPath, $docsPath)) {
    if (-not (Test-Path $p)) { throw "check-config.ps1: missing $p" }
}

# shipped toml: "section.key" -> entry
$toml = [ordered]@{}
foreach ($e in (Read-Toml $tomlPath)) {
    if ($e.Index -ge 0 -or $e.Table -eq '') { throw "${tomlPath}($($e.Line)): '$($e.Key)' sits outside a plain [section]" }
    $name = ("$($e.Table).$($e.Key)").ToLowerInvariant()
    if ($toml.Contains($name)) { Fail "SLOVE.toml sets $name twice (line $($e.Line))" }
    $toml[$name] = $e
}
$tomlKeys = @($toml.Keys)
$tomlSections = @($toml.Values | ForEach-Object { $_.Table.ToLowerInvariant() } | Select-Object -Unique)

# ---------------------------------------------------- 1. scripts <-> toml ---
Section 'Scripts <-> SLOVE.toml'
$reads = @{}       # key -> list of "tree\file(line) GetX"
$readTypes = @{}   # key -> getter names
$buses = @{}       # bus -> list of places
foreach ($tree in @('papyrus\Source', 'papyrus\classic\Source')) {
    foreach ($file in (Get-ChildItem (Join-Path $root $tree) -Filter '*.psc')) {
        $n = 0
        foreach ($line in [System.IO.File]::ReadAllLines($file.FullName)) {
            $n++
            if ($line.IndexOf('SLOVE_Config', [System.StringComparison]::OrdinalIgnoreCase) -lt 0 -and
                $line.IndexOf('SetGroupVolume', [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
            $code = Get-PapyrusCode $line
            $where = "$tree\$($file.Name)($n)"
            foreach ($m in [regex]::Matches($code, 'SLOVE_Config\.Get(Int|Float|String|Bool)\s*\(\s*(?:"([^"]*)")?', 'IgnoreCase')) {
                if (-not $m.Groups[2].Success) {
                    Fail "${where}: SLOVE_Config.Get$($m.Groups[1].Value) with a key that is not a string literal - this check cannot see it"
                    continue
                }
                $key = $m.Groups[2].Value.ToLowerInvariant()
                $getter = $m.Groups[1].Value.ToLowerInvariant()
                if (-not $reads.ContainsKey($key)) { $reads[$key] = @(); $readTypes[$key] = @() }
                $reads[$key] += $where
                if ($readTypes[$key] -notcontains $getter) { $readTypes[$key] += $getter }
            }
            foreach ($m in [regex]::Matches($code, 'AudioUtil\.SetGroupVolume\s*\(\s*(?:"([^"]*)")?', 'IgnoreCase')) {
                if (-not $m.Groups[1].Success) {
                    Fail "${where}: AudioUtil.SetGroupVolume with a bus that is not a string literal - this check cannot see it"
                    continue
                }
                $bus = $m.Groups[1].Value.ToLowerInvariant()
                if (-not $buses.ContainsKey($bus)) { $buses[$bus] = @() }
                $buses[$bus] += $where
            }
        }
    }
}
$scriptKeys = @($reads.Keys)

# A few keys are read by SLOVE.dll and not by any script (the TrueHUD bar): the
# plugin takes a flag with Flag(doc, "section.key"sv, fallback), like GetInt == 1.
$pluginReads = @{}   # key -> list of "file(line)"
$pluginSrc = Join-Path $skse 'src'
if (Test-Path $pluginSrc) {
    foreach ($file in (Get-ChildItem $pluginSrc -Filter '*.cpp')) {
        $n = 0
        foreach ($line in [System.IO.File]::ReadAllLines($file.FullName)) {
            $n++
            foreach ($m in [regex]::Matches((Get-CppCode $line), '\bFlag\s*\(\s*\w+\s*,\s*"([A-Za-z0-9_.]+)"sv')) {
                $key = $m.Groups[1].Value.ToLowerInvariant()
                if (-not $pluginReads.ContainsKey($key)) { $pluginReads[$key] = @() }
                $pluginReads[$key] += "skse\src\$($file.Name)($n)"
            }
        }
    }
}
foreach ($key in $pluginReads.Keys) {
    if ($toml.Contains($key) -and $toml[$key].Type -ne 'int') {
        Fail "$key is a TOML $($toml[$key].Type) but the plugin reads it as a 0/1 flag ($($pluginReads[$key][0]))"
    }
}
$readKeys = @(@($scriptKeys) + @($pluginReads.Keys) | Select-Object -Unique)
[void](Compare-Sets 'the scripts and the plugin' $readKeys 'SLOVE.toml' $tomlKeys)

# TomlUtil converts where nothing is lost (true reads as 1, 60.0 as 60) and otherwise
# hands back the caller's fallback, silently. A getter of another type than the
# shipped value is a mistake either way.
$fits = @{ 'int' = @('int'); 'float' = @('float', 'int'); 'string' = @('string'); 'bool' = @('bool') }
foreach ($key in $scriptKeys) {
    if (-not $toml.Contains($key)) { continue }
    foreach ($getter in $readTypes[$key]) {
        if ($fits[$getter] -notcontains $toml[$key].Type) {
            Fail "$key is a TOML $($toml[$key].Type) but is read with Get$getter ($($reads[$key][0])): the script would always get its fallback"
        }
    }
}
$pluginOnly = @($pluginReads.Keys | Where-Object { $scriptKeys -notcontains $_ })
Write-Host "$($scriptKeys.Count) key(s) read by the scripts, $($pluginOnly.Count) by the plugin alone, $($tomlKeys.Count) in SLOVE.toml"

# ------------------------------------------------- 2. menu schema <-> toml ---
Section 'SLOVE_Menu.toml <-> SLOVE.toml'
$schemaBytes = [System.IO.File]::ReadAllBytes($schemaPath)
$lineNo = 1
$badLines = @()
foreach ($byte in $schemaBytes) {
    if ($byte -eq 10) { $lineNo++; continue }
    if (($byte -gt 126 -or $byte -lt 32) -and $byte -ne 13 -and $byte -ne 9) {
        if ($badLines -notcontains $lineNo) { $badLines += $lineNo }
    }
}
if ($badLines.Count) { Fail "SLOVE_Menu.toml is not plain ASCII on line(s) $($badLines -join ', ') - the menu font would draw '?'" }

$pages = @{}
$settings = @{}
$schemaVersion = $null
foreach ($e in (Read-Toml $schemaPath)) {
    if ($e.Table -eq '' -and $e.Key -eq 'schema') { $schemaVersion = $e.Value; continue }
    if ($e.Index -lt 0) { Fail "SLOVE_Menu.toml($($e.Line)): '$($e.Key)' is outside a [[page]] or [[setting]]"; continue }
    if ($e.Table -eq 'page') { $bag = $pages } elseif ($e.Table -eq 'setting') { $bag = $settings } else {
        Fail "SLOVE_Menu.toml($($e.Line)): unknown table [[$($e.Table)]]"; continue
    }
    if (-not $bag.ContainsKey($e.Index)) { $bag[$e.Index] = @{ '_line' = $e.Line } }
    if ($bag[$e.Index].ContainsKey($e.Key)) { Fail "SLOVE_Menu.toml($($e.Line)): '$($e.Key)' given twice in one [[$($e.Table)]]" }
    $bag[$e.Index][$e.Key] = $e
}
if ($schemaVersion -ne 1) { Fail 'SLOVE_Menu.toml: "schema = 1" is missing (the plugin ignores a schema it does not know)' }

$pageSections = @()
foreach ($i in ($pages.Keys | Sort-Object)) {
    $page = $pages[$i]
    if (-not $page.ContainsKey('section') -or -not $page.ContainsKey('title')) { Fail "SLOVE_Menu.toml($($page['_line'])): a [[page]] needs section and title"; continue }
    $pageSections += $page['section'].Value.ToLowerInvariant()
}
[void](Compare-Sets 'the [[page]] list' $pageSections 'the sections of SLOVE.toml' $tomlSections)

$controlFits = @{ 'flag' = @('int'); 'int' = @('int'); 'percent' = @('int'); 'float' = @('float', 'int'); 'text' = @('string') }
$schemaKeys = @()
$controls = @{}   # key -> control name
$tips = @{}       # key -> tip
foreach ($i in ($settings.Keys | Sort-Object)) {
    $s = $settings[$i]
    $at = "SLOVE_Menu.toml($($s['_line']))"
    if (-not $s.ContainsKey('key')) { Fail "${at}: a [[setting]] without a key"; continue }
    $key = $s['key'].Value.ToLowerInvariant()
    if ($schemaKeys -contains $key) { Fail "${at}: $key is described twice" }
    $schemaKeys += $key
    foreach ($need in @('group', 'label', 'control', 'tip')) {
        if (-not $s.ContainsKey($need)) { Fail "${at}: $key has no $need" }
    }
    foreach ($field in $s.Keys) {
        if (@('_line', 'key', 'group', 'label', 'tip', 'unit', 'control', 'requires', 'min', 'max', 'step') -notcontains $field) {
            Fail "${at}: $key has an unknown field '$field' (the plugin would ignore it)"
        }
    }
    if ($s.ContainsKey('label') -and $s['label'].Value.Contains('##')) { Fail "${at}: the label of $key contains ## (ImGui reads the rest as an id)" }
    if ($s.ContainsKey('tip')) { $tips[$key] = $s['tip'].Value }
    if ($s.ContainsKey('requires') -and @('pplus', 'pplus219') -notcontains $s['requires'].Value) {
        Fail "${at}: $key requires '$($s['requires'].Value)' - only pplus and pplus219 exist"
    }
    if (-not $s.ContainsKey('control')) { continue }
    $control = $s['control'].Value
    $controls[$key] = $control
    if (-not $controlFits.ContainsKey($control)) { Fail "${at}: $key has unknown control '$control'"; continue }
    if (-not $toml.Contains($key)) { continue }   # reported by the set comparison below
    $shipped = $toml[$key]
    if ($controlFits[$control] -notcontains $shipped.Type) {
        Fail "${at}: $key is a TOML $($shipped.Type), which control '$control' cannot edit"
        continue
    }
    if ($control -eq 'flag' -and $shipped.Value -ne 0 -and $shipped.Value -ne 1) { Fail "${at}: $key is a flag but ships as $($shipped.Raw)" }
    $min = $null
    $max = $null
    if ($control -eq 'percent') { $min = 0; $max = 100 }
    if ($s.ContainsKey('min')) { $min = $s['min'].Value }
    if ($s.ContainsKey('max')) { $max = $s['max'].Value }
    if ($null -ne $min -and $null -ne $max -and $min -ge $max) { Fail "${at}: $key has min >= max" }
    if ($control -ne 'text') {
        if ($null -ne $min -and $shipped.Value -lt $min) { Fail "${at}: $key ships as $($shipped.Raw), below its min $min" }
        if ($null -ne $max -and $shipped.Value -gt $max) { Fail "${at}: $key ships as $($shipped.Raw), above its max $max" }
    }
}
[void](Compare-Sets 'SLOVE_Menu.toml' $schemaKeys 'SLOVE.toml' $tomlKeys)
Write-Host "$($schemaKeys.Count) setting(s) described on $($pageSections.Count) page(s)"

# ----------------------------------------------------------- 3. docs rows ---
# Every key has a row in the table of its "## `[section]`", and the Default cell
# is the shipped value as the toml spells it. A struck-through row (~~`key`~~)
# may outlive its key: that is how a removed setting is documented.
Section 'docs\config\slove.md <-> SLOVE.toml'
$docRows = @{}
$section = $null
$n = 0
foreach ($line in (Read-Lines $docsPath)) {
    $n++
    if ($line -cmatch '^## `\[([A-Za-z0-9_]+)\]`') { $section = $Matches[1].ToLowerInvariant(); continue }
    if ($line -cmatch '^## ') { $section = $null; continue }
    if ($null -eq $section) { continue }
    if ($line -cmatch '^\|\s*(~~)?`([A-Za-z0-9_]+)`(?:~~)?\s*\|\s*(.*?)\s*\|') {
        $key = "$section.$($Matches[2].ToLowerInvariant())"
        if ($docRows.ContainsKey($key)) { Fail "docs\config\slove.md(${n}): a second row for $key" }
        $docRows[$key] = [pscustomobject]@{ Line = $n; Default = $Matches[3]; Struck = [bool]$Matches[1] }
    }
}
foreach ($key in $tomlKeys) {
    if (-not $docRows.ContainsKey($key)) { Fail "docs\config\slove.md has no row for $key"; continue }
    $row = $docRows[$key]
    $want = '`' + $toml[$key].Raw + '`'
    if ($row.Default -cne $want) { Fail "docs\config\slove.md($($row.Line)): $key Default is $($row.Default), SLOVE.toml ships $want" }
}
foreach ($key in $docRows.Keys) {
    if (-not $toml.Contains($key) -and -not $docRows[$key].Struck) {
        Fail "docs\config\slove.md($($docRows[$key].Line)): a row for $key, which SLOVE.toml does not have (strike it through if it was removed)"
    }
}
Write-Host "$($docRows.Count) row(s)"

# ------------------------------------------------------ 4. shipped defaults ---
# SLOVE.defaults.toml = a note + the shipped SLOVE.toml, byte for byte. The menu
# reads it for "reset" and the "Default:" tooltip line; it is generated (and
# git-ignored) so that no second hand-kept copy of the defaults can exist.
Section 'SLOVE.defaults.toml'
$tomlBytes = [System.IO.File]::ReadAllBytes($tomlPath)
if ($tomlBytes.Length -ge 3 -and $tomlBytes[0] -eq 0xEF -and $tomlBytes[1] -eq 0xBB -and $tomlBytes[2] -eq 0xBF) {
    Fail 'SLOVE.toml starts with a UTF-8 byte order mark - save it without one'
}
$eol = "`n"
if ([System.Text.Encoding]::ASCII.GetString($tomlBytes).Contains("`r`n")) { $eol = "`r`n" }
$note = @(
    '# GENERATED - the values SLOVE.toml had when this version of SLO VE shipped.'
    '# The in-game menu reads this file for its reset buttons and "Default:" lines.'
    '# Editing it changes nothing in game: your settings live in SLOVE.toml.'
    ''
    ''
) -join $eol
$wantDefaults = [System.Text.Encoding]::ASCII.GetBytes($note) + $tomlBytes
if ($WriteDefaults) {
    [System.IO.File]::WriteAllBytes($defaultsPath, $wantDefaults)
    Write-Host "written from SLOVE.toml ($($tomlBytes.Length) bytes + note)"
} elseif (-not (Test-Path $defaultsPath)) {
    Warn 'not generated yet - scripts\build.ps1 writes it (or run this with -WriteDefaults)'
} else {
    $have = [System.IO.File]::ReadAllBytes($defaultsPath)
    $same = $have.Length -eq $wantDefaults.Length
    if ($same) {
        for ($i = 0; $i -lt $have.Length; $i++) { if ($have[$i] -ne $wantDefaults[$i]) { $same = $false; break } }
    }
    if ($same) { Write-Host 'in step with SLOVE.toml' } else { Fail 'SLOVE.defaults.toml is stale - rerun with -WriteDefaults (build.ps1 does)' }
}

# --------------------------------------------------- 5. plugin <-> scripts ---
# Only when the plugin sources are present: a script-only checkout still checks 1-4.
$bridgePath = Join-Path $skse 'src\Bridge.cpp'
if (-not (Test-Path $bridgePath)) {
    Warn 'skse\src not found - plugin checks skipped'
} else {
    Section 'Volume buses: scripts <-> skse\src\Bridge.cpp'
    $table = @{}   # key -> buses
    foreach ($line in (Read-Lines $bridgePath)) {
        if ((Get-CppCode $line) -cmatch '^\s*\{\s*"([a-z0-9_.]+)"sv,\s*\{([^}]*)\}\s*\},?\s*$') {
            $table[$Matches[1]] = @([regex]::Matches($Matches[2], '"([a-z0-9_]+)"sv') | ForEach-Object { $_.Groups[1].Value })
        }
    }
    if (-not $table.Count) { Fail 'no volume table found in Bridge.cpp - update this check to match it' }
    $bridgeBuses = @($table.Values | ForEach-Object { $_ } | Select-Object -Unique)
    [void](Compare-Sets 'the scripts (AudioUtil.SetGroupVolume)' @($buses.Keys) 'Bridge.cpp' $bridgeBuses)
    foreach ($key in $table.Keys) {
        if (-not $toml.Contains($key)) { Fail "Bridge.cpp pushes $key, which SLOVE.toml does not have"; continue }
        if ($controls[$key] -ne 'percent') { Fail "Bridge.cpp pushes $key live as value/100, but its control is '$($controls[$key])', not percent" }
    }
    # the tooltip is where the user is told, so it must be true both ways
    foreach ($key in $schemaKeys) {
        $promised = $tips.ContainsKey($key) -and $tips[$key].Contains('Applies at once')
        if ($promised -and -not $table.ContainsKey($key)) { Fail "the tip of $key says 'Applies at once' but Bridge.cpp does not push it" }
        if (-not $promised -and $table.ContainsKey($key)) { Fail "Bridge.cpp pushes $key live, but its tip does not say 'Applies at once'" }
    }
    Write-Host "$($bridgeBuses.Count) bus(es) behind $($table.Count) key(s)"

    # The vendored header's ImGui wrappers call GetProcAddress results unchecked,
    # so Env.cpp probes every export the menu reaches before any page is drawn.
    # This compares the two lists. Its limit: for an overloaded wrapper (PushID,
    # PushStyleColor...) it only checks that ONE of the overloads is probed, not
    # that it is the one the call resolves to.
    Section 'SKSE Menu Framework exports: calls <-> skse\src\Env.cpp probes'
    $headerPath = Join-Path $skse 'extern\SKSEMenuFramework\SKSEMenuFramework.h'
    $headerText = Read-Utf8 $headerPath
    $wrappers = @{}   # wrapper name -> exports of all its overloads
    $current = $null
    foreach ($line in ($headerText -split "`r?`n")) {
        if ($line -cmatch '^\s*inline\s+[^(]*?\b([A-Za-z_]\w*)\s*\(') { $current = $Matches[1] }
        if ($null -ne $current -and $line -cmatch 'GetMenuFrameworkFunction<[^>]*>\("(\w+)"\)') {
            if (-not $wrappers.ContainsKey($current)) { $wrappers[$current] = @() }
            $wrappers[$current] += $Matches[1]
        }
    }
    # the non-ImGui entry points, which have their own shape in the header
    $entryPoints = @{
        'AddSectionItem' = @('AddSectionItem')
        'AddEvent'       = @('RegisterEventPriority', 'UnregisterEvent')
        'SetSection'     = @()
        'Model'          = @()
    }

    $envText = Read-Utf8 (Join-Path $skse 'src\Env.cpp')
    $block = [regex]::Match($envText, 'kFrameworkExports\s*\{([^}]*)\}')
    $probes = @([regex]::Matches($block.Groups[1].Value, '"(\w+)"') | ForEach-Object { $_.Groups[1].Value })
    if (-not $probes.Count) { Fail 'kFrameworkExports not found in Env.cpp - update this check to match it' }

    $used = @()
    $calls = 0
    foreach ($file in (Get-ChildItem (Join-Path $skse 'src') -Recurse -Include '*.cpp', '*.h' | Where-Object { $_.Name -ne 'Ui.h' })) {
        $n = 0
        foreach ($line in [System.IO.File]::ReadAllLines($file.FullName)) {
            $n++
            $code = Get-CppCode $line
            foreach ($m in [regex]::Matches($code, '\bUi::([A-Za-z_]\w*)\s*\(')) {
                $name = $m.Groups[1].Value
                $calls++
                if ($wrappers.ContainsKey($name)) {
                    $hit = @($wrappers[$name] | Where-Object { $probes -contains $_ })
                    if (-not $hit.Count) { Fail "$($file.Name)(${n}): Ui::$name calls $($wrappers[$name] -join ' / '), none of which Env.cpp probes" }
                    $used += $hit
                } elseif ($headerText -notmatch ('\bstruct\s+' + $name + '\b')) {
                    Fail "$($file.Name)(${n}): Ui::$name is neither a wrapper nor a struct this check can find in the header"
                }
            }
            foreach ($m in [regex]::Matches($code, '\bSKSEMenuFramework::([A-Za-z_]\w*)')) {
                $name = $m.Groups[1].Value
                if (-not $entryPoints.ContainsKey($name)) { Fail "$($file.Name)(${n}): SKSEMenuFramework::$name is not in this check's entry-point list - add it, with the exports it reaches"; continue }
                foreach ($export in $entryPoints[$name]) {
                    if ($probes -notcontains $export) { Fail "$($file.Name)(${n}): SKSEMenuFramework::$name reaches $export, which Env.cpp does not probe" }
                    $used += $export
                }
            }
        }
    }
    $idle = @($probes | Where-Object { $used -notcontains $_ })
    if ($idle.Count) { Fail "Env.cpp probes exports nothing calls: $($idle -join ', ') - a framework without them would switch the menu off for nothing" }
    Write-Host "$($probes.Count) export(s) probed, $calls call site(s)"

    Section 'Vendored files'
    $readme = Read-Utf8 (Join-Path $skse 'extern\SKSEMenuFramework\README.txt')
    $recorded = [regex]::Match($readme, 'sha256:\s*([0-9a-fA-F]{64})').Groups[1].Value
    $actual = (Get-FileHash $headerPath -Algorithm SHA256).Hash
    if (-not $recorded) { Fail 'extern\SKSEMenuFramework\README.txt records no sha256' }
    elseif ($recorded -ne $actual) { Fail "SKSEMenuFramework.h was changed (sha256 $($actual.ToLowerInvariant())) - it is vendored verbatim; update README.txt only when taking a new upstream copy" }
    else { Write-Host 'SKSEMenuFramework.h matches the hash in its README' }

    # the TrueHUD interface header (the willpower bar, src\HudBar.cpp): the same rule
    $hudReadme = Read-Utf8 (Join-Path $skse 'extern\TrueHUD\README.txt')
    $hudRecorded = [regex]::Match($hudReadme, 'sha256:\s*([0-9a-fA-F]{64})').Groups[1].Value
    $hudActual = (Get-FileHash (Join-Path $skse 'extern\TrueHUD\TrueHUDAPI.h') -Algorithm SHA256).Hash
    $hudSame = $hudRecorded -and $hudRecorded -eq $hudActual
    if ($hudSame) { Write-Host 'TrueHUDAPI.h matches the hash in its README' }
    if (-not $hudSame) { Fail 'TrueHUDAPI.h differs from the copy its README records - it is vendored verbatim' }

    # AudioUtil's writer and ours must make the same edit to the same file
    $ours = Join-Path $skse 'src\core\TomlEdit.h'
    $theirs = Join-Path (Split-Path $root -Parent) 'AudioUtil\src\TomlEdit.h'
    if (-not (Test-Path $theirs)) {
        Write-Host 'TomlEdit.h: no AudioUtil checkout beside this repo to compare with'
    } elseif ((Get-TextHash $ours) -ne (Get-TextHash $theirs)) {
        Warn 'skse\src\core\TomlEdit.h differs from AudioUtil\src\TomlEdit.h - copy it over again (never edit the copy) and rerun core-tests'
    } else {
        Write-Host 'TomlEdit.h is identical to AudioUtil''s'
    }
}

if ($script:failed) { throw 'settings sync check FAILED - see above' }
Write-Host 'settings sync check OK' -ForegroundColor Green
