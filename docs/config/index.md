# Configuration Overview - the three layers

SLO VE has **no MCM**. Everything is TOML, and all of it reloads live from the console.

There are three layers, in two different systems. Knowing which file owns what saves a lot of confusion:

| File | Owns | Read by | Live reload |
|---|---|---|---|
| `SKSE\Plugins\SLOVE\SLOVE.toml` | **Behaviour** — what plays, how often, how strongly: voice, expressions, sfx, resistance, milk | SLO VE's scripts (via AudioUtil's TomlUtil) | `SLOVE_Config Reload` |
| `SKSE\Plugins\AudioUtil\config\SLOVE_*.toml` | **Content** - the voice slots (female / male / creature), the actor→voice routing, the category maps, the SFX slot | the AudioUtil DLL | `au reload` |
| `SKSE\Plugins\AudioUtil\AudioUtil.toml` | **Engine globals** — lipsync, gag, PPA bridge, default/reserved slots, sound flags | the AudioUtil DLL | `au reload` |

Rule of thumb:

- *"She should moan more often / the SFX are too loud / turn resistance off"* → [**SLOVE.toml**](slove.md)
- *"Give this follower a different voice / add a pack / change which folder a category plays"* → [**the voice overlays**](voices.md)
- *"Turn lipsync off / change what counts as a gag / play voices in 3D"* → [**AudioUtil.toml**](audioutil.md)

## Why the AudioUtil preset is split in two

AudioUtil merges its config from **the base `AudioUtil.toml` first, then every `config\*.toml` overlay** in sorted filename order. Two kinds of data behave differently in that merge:

- **Globals** — `[general]`, `[ppa]`, the `[lipsync]` scalar tuning, and the `[gag]` `enable`/`default_category` toggles — are read **only from the base `AudioUtil.toml`**. An overlay that sets them is **ignored, with a warning** in `AudioUtil.log`. This is deliberate: an add-on can never silently change engine-wide settings.
- **Additive data** — `[[slot]]`, `[sfx]`, `[npc_overrides]`, `[voicetype_remap]`, `[voicetype_map]`, `[race_map]`, `[category_aliases.*]`, `[male_only_remap]`, `[category_fallbacks.*]`, `[groups]`, plus `[gag].keywords` and `[lipsync].block_categories` — **accumulates** from the base and every overlay (union, last-writer-wins per key).

So SLO VE ships the globals in the base `AudioUtil.toml` (which must win the load order) and **all** the voice content in additive `config\*.toml` overlays, split by what they hold:

| File | Holds |
|---|---|
| `SLOVE_creatures.toml` | creature slots C0-C41 and the `[race_map]` hints that route them |
| `SLOVE_female.toml` | female slots: the PC slot `F1`, the gag pool `F1gag`, the stock voices `F0`/`F0B`/`F0v2`-`F0v8`, and the NPC pool `F2`-`F10` |
| `SLOVE_male.toml` | male slots: the bundled packs `M1`-`M8` and the stock moan slots `M0`-`M0D` |
| `SLOVE_voices.toml` | no slots - the actor->slot routing, the category maps, the group volumes and the `SFX0` slot |

They merge in sorted filename order (`c` < `f` < `m` < `v`), then any voicepack's `SLOVE_zpack_*.toml` last. No slot id is shared between them, so the split is purely additive. Full reference: [**Voice overlays**](voices.md).

!!! warning "SLO VE's `AudioUtil.toml` must overwrite AudioUtil's"
    AudioUtil's own bundled base file is SFW-neutral: it defines no slots and no SFX. **Install SLO VE after (below) AudioUtil** so its preset wins. If it doesn't, no actor resolves to a voice.

## Merge rules that bite

- **A `[[slot]]` is keyed by `id`.** If two files define the same id, the file that sorts **last** wins the **whole slot** — there is no per-category deep merge. To tweak one category of an existing slot, copy the entire block.
- **Tables merge per key.** `[npc_overrides]`, `[voicetype_map]` and friends union across files; a later file only overrides the individual keys it repeats.
- **A file that fails to parse is skipped**, and the remaining files still merge (the error is logged). If *every* file fails, the previous settings are kept — a broken edit never leaves the game silent.
- **Everything is normalised**: keys and names are lowercased with non-alphanumerics stripped, so `"About To Cum"` == `"AboutToCum"`.
- **Paths are Data-relative** and written as TOML *literal strings* (single quotes) so backslashes need no escaping: `path = 'Sound\fx\SLOVE\F1'`.

## Add your own overlay instead of editing in place

SLO VE's overlays ship with the mod, so an update overwrites your edits. Because overlays are additive and merged in sorted filename order, put your customisations in a file of your own:

```
Data\SKSE\Plugins\AudioUtil\config\ZZ_MyVoices.toml
```

A `ZZ_` prefix sorts last, so your keys win. Full worked example: [Keeping your edits across updates](../packs/female.md#keeping-your-edits-across-updates).

The one thing you **cannot** do from an overlay is change a global — `pc_male_slot`, lipsync tuning, `[gag] enable` and friends have to be edited in the base `AudioUtil.toml` itself.

## Live reload

Both sides reload without restarting the game:

```
SLOVE_Config Reload      ; re-read SLOVE.toml
au reload   ; re-read the AudioUtil base + all overlays, and rescan the folders
```

`AudioUtil.ReloadConfig` also **rescans the sound folders**, so it picks up a voice pack you just installed — you don't need to restart to test one.

!!! note "What doesn't reload"
    Values sampled once when an effect starts (e.g. an actor's already-running expression timers) keep their old value until the next scene. Slot/category/routing changes and every `SLOVE.toml` getter take effect immediately.

## Other data files

Not TOML, but part of the configuration surface:

| File | Contents |
|---|---|
| `SKSE\Plugins\StorageUtilData\SLOVE\PCExpressions.json` | face presets for the player, incl. `tongueoutphonemeoverride`, the mouth held open for a tongue (see [SLOVE.toml](slove.md#expressions)) |
| `…\MaleExpressions.json`, `…\FemaleExpressions.json` | face presets for NPCs |
| `…\Masks.json`, `…\NPCTongue.json`, `…\ErinMFEEConfig.json` | mask detection, tongue models, MFEE mapping |
| `…\ResistanceRaceBase.json` | per-race willpower denominators for NPCs |
| `…\ResistanceRacePCModifier.json` | partner-race modifier applied to the PC's drain |

These are PapyrusUtil JSON, read at runtime. See [Willpower / Resistance](../resistance.md) for the two resistance tables.

## Reference pages

- [**SLOVE.toml**](slove.md) — every behaviour key: `[director]`, `[voice]`, `[expressions]`, `[sfx]`, `[resistance]`, `[milk]`
- [**Voice overlays**](voices.md) - every slot and routing table
- [**AudioUtil.toml**](audioutil.md) — the engine globals SLO VE sets
- AudioUtil's own [config documentation](https://crajjjj.github.io/AudioUtil/config/) for the engine-level detail behind all of it
