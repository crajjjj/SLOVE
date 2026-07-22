# SLO VE — Voices and Expressions

Standalone scene **voices**, **facial expressions** and **body SFX**
(slushing/impacts/claps, optionally thrust-synced) for SexLab P+ scenes.
No gameplay systems, no MCM — all configuration lives in TOML files.
"SLO" = SexLab / OStim (OStim backend planned; v1 is SexLab P+ only).

## Requirements (hard)

| Dependency | Why |
|---|---|
| SKSE64, SexLab P+ (2.17+) | scene framework |
| **AudioUtil** | voice playback (folder-based slots), lipsync, TOML config API |
| PapyrusUtil | JSON preset data (expression faces) |
| Mfg Fix NG (MfgConsoleFunc/Ext) | all face writes |

Soft (auto-detected, optional): MFEE, sr_fillherup (tongue), Devious Devices
(gag), SexLab Survival (ahegao yield), SOS/TNG (huge-partner detection),
Accurate Penetration via AudioUtilPPA (measured penetration/gape),
Oninus Lactis NG (nipple squirts during scenes, `[milk]` in SLOVE.toml;
with Milk Mod Economy also installed, squirts require and drain her milk).

## External data dependencies (not bundled)

- **Voice packs**: male packs M1–M8, the Smack/PullOutGape one-shots and the
  body-SFX library (`Sound\fx\SloveSFX`) are **bundled**, creature slots
  C1–C10 play straight from vanilla BSAs, and **female voices default to
  SexLab's own moan sets** (stock slots F0/F0B — files every SexLab P+
  install already has) — everything works out of the box.
  **Female slot scheme**: F0 = stock default (all females), F1 = the
  player's pack slot, F2/F3 = partner/follower pack slots. Drop any
  Hentairim/IVDT-convention female pack into `Sound\fx\IVDT\F1` (or F2/F3)
  and it just plays — no config edits; categories the pack lacks backfill
  from the stock moans per category. Route a follower to F2/F3 via
  `[npc_overrides]` in `SKSE\Plugins\AudioUtil\AudioUtil.toml`.
- **Scene tag data**: labels resolve from Hentairim-convention scene tags
  (`3asvp` = stage 3, actor A, vaginal penetration) in your SexLab P+ scene
  registry. Untagged animations fall back to lead-in behavior. Tag data comes
  from an existing tagged setup or a tag pack.

## Install order (MO2)

AudioUtil → voice pack assets → **SLO VE last** (its `AudioUtil.toml` preset
must win). **Mutually exclusive with full Hentairim p+** — disable one.

## Configuration

- `SKSE\Plugins\SLOVE\SLOVE.toml` — all settings (`[director]`, `[voice]`,
  `[expressions]`, `[sfx]`, `[milk]`). Live reload: `cgf "TomlUtil.Reload" "SKSE\Plugins\SLOVE\SLOVE.toml"`.
- `SKSE\Plugins\AudioUtil\AudioUtil.toml` — voice slots/mapping (AudioUtil
  preset; live reload via `cgf "AudioUtil.ReloadConfig"`).
- `SKSE\Plugins\StorageUtilData\SLOVE\*.json` — expression preset data.

## Build (dev)

`powershell scripts\build.ps1` — mirrors `papyrus\Source` into `dist`, compiles
via Pyro, writes `Release\SLO VE.zip`. ESP authored via houseCARL (see repo
history).

## Architecture

`SLOVE_Director` (quest player-alias) is the only SexLab-P+-aware script: scene
detection, label arrays (via `SLOVE_Hentairim_Tags`), physics-label intensity, spell
application, and the `SLOVE_*` mod-event re-broadcasts. `SLOVE_Voice`
(player-only ability) runs the voice dispatcher; `SLOVE_Expressions`
(per-actor ability) runs faces. See `docs\framework-adapter.md` for the OStim
adapter contract.
