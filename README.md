# SLO VE — Voices and Expressions

Standalone scene **voices** and **facial expressions** for SexLab P+ scenes.
Extracted from Hentairim p+; no resistance/gameplay systems, no MCM — all
configuration lives in TOML files. "SLO" = SexLab / OStim (OStim backend
planned; v1 is SexLab P+ only).

## Requirements (hard)

| Dependency | Why |
|---|---|
| SKSE64, SexLab P+ (2.17+) | scene framework |
| **AudioUtil** | voice playback (folder-based slots), lipsync, TOML config API |
| PapyrusUtil | JSON preset data (expression faces) |
| Mfg Fix NG (MfgConsoleFunc/Ext) | all face writes |

Soft (auto-detected, optional): MFEE, sr_fillherup (tongue), Devious Devices
(gag), SexLab Survival (ahegao yield), SOS/TNG (huge-partner detection),
Accurate Penetration via AudioUtilPPA (measured penetration/gape).

## External data dependencies (not bundled)

- **Voice packs**: male packs M1–M8 and creature slots C1–C10 work out of the
  box (creatures play straight from vanilla BSAs). The **female F1 pack is
  bring-your-own**: drop WAVs into `Sound\fx\IVDT\F1\<Category>\` (see the
  category list in `SKSE\Plugins\AudioUtil\AudioUtil.toml`).
- **Scene tag data**: labels resolve from Hentairim-convention scene tags
  (`3asvp` = stage 3, actor A, vaginal penetration) in your SexLab P+ scene
  registry. Untagged animations fall back to lead-in behavior. Tag data comes
  from an existing tagged setup or a tag pack.

## Install order (MO2)

AudioUtil → voice pack assets → **SLO VE last** (its `AudioUtil.toml` preset
must win). **Mutually exclusive with full Hentairim p+** — disable one.

## Configuration

- `SKSE\Plugins\SLOVE\SLOVE.toml` — all settings (`[director]`, `[voice]`,
  `[expressions]`). Live reload: `cgf "TomlUtil.Reload" "SKSE\Plugins\SLOVE\SLOVE.toml"`.
- `SKSE\Plugins\AudioUtil\AudioUtil.toml` — voice slots/mapping (AudioUtil
  preset; live reload via `cgf "AudioUtil.ReloadConfig"`).
- `SKSE\Plugins\StorageUtilData\SLOVE\*.json` — expression preset data.

## Build (dev)

`powershell scripts\build.ps1` — mirrors `papyrus\Source` into `dist`, compiles
via Pyro, writes `Release\SLO VE.zip`. ESP authored via houseCARL (see repo
history).

## Architecture

`SLOVE_Director` (quest player-alias) is the only SexLab-P+-aware script: scene
detection, label arrays (via `SLOVE_Tags`), physics-label intensity, spell
application, and the `SLOVE_*` mod-event re-broadcasts. `SLOVE_Voice`
(player-only ability) runs the voice dispatcher; `SLOVE_Expressions`
(per-actor ability) runs faces. See `docs\framework-adapter.md` for the OStim
adapter contract.
