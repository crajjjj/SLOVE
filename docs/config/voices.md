# `SLOVE_voices.toml` — slots & routing reference

**`Data\SKSE\Plugins\AudioUtil\config\SLOVE_voices.toml`** is SLO VE's voice **content**: every `[[slot]]`, the actor→slot routing tables, the category maps, and the SFX slot.

It is an **additive overlay**. AudioUtil loads the base `AudioUtil.toml` first, then merges every `config\*.toml` on top in sorted filename order. Everything on this page is additive and merges across files — you can put your own version of any of it in [your own overlay](../packs/female.md#keeping-your-edits-across-updates).

Live reload (also rescans folders):

```
cgf "AudioUtil.ReloadConfig"
```

!!! note "Conventions"
    - All keys and names are **normalised** — lowercased, non-alphanumerics stripped.
    - Paths are **Data-relative** and written as TOML literal strings (single quotes) so backslashes need no escaping: `'Sound\fx\IVDT\F1'`.
    - This preset sets **no `voice_root` / `sfx_root`** — every path is written out in full, so nothing depends on a shared root global.

## Slot resolution tables

These decide **which slot an actor speaks**. Evaluated in the order below; first hit wins. (The player is decided before all of them by `pc_female_slot` / `pc_male_slot` in [`AudioUtil.toml`](audioutil.md).)

### `[npc_overrides]`

Pin one specific NPC to one slot. Beats everything else.

```toml
[npc_overrides]
'MyFollower.esp|000D62' = "F2"
'MyEslMod.esp|D62'      = "F3"    # ESL-flagged: last 3 hex digits
```

Key format is `'Plugin.esp|FormID'`. May target any slot, including a PC-reserved one. Ships empty (one commented example).

### `[voicetype_remap]`

Renames a voicetype to one you have a pack for, **before** the slot lookup. Values are voicetype names — a single hop, so the target must itself be a `[voicetype_map]` key.

```toml
[voicetype_remap]
enable = true
MaleGuard = "MaleNord"
MaleCommander = "MaleBrute"
```

`enable = false` disables the entire layer, so only exact `[voicetype_map]` matches get voices.

**Shipped remaps:** `MaleCommander`/`MaleSoldier`/`MaleOldGrumpy` → MaleBrute · `MaleCommoner`/`MaleCommonerAccented`/`MaleEvenTonedAccented`/`MaleYoungEager`/`MaleDrunk`/`MaleOldKindly` → MaleEvenToned · `MaleElfHaughty`/`MaleWarlock`/`MaleSlyCynical` → MaleCondescending · `MaleGuard`/`MaleNordCommander` → MaleNord · `MaleDarkElfCynical` → MaleDarkElf · `MaleKhajiitAccented` → MaleKhajitt.

### `[voicetype_map]`

VoiceType → slot. A value may be a **single slot** or a **list**; with a list, actors sharing the voicetype spread across the slots deterministically by form id (the same NPC always gets the same slot).

```toml
[voicetype_map]
MaleEvenToned = "M1"
MaleBandit = ["M3", "M4"]
FemaleEvenToned = ["F2", "F3"]    # add your own female routing
```

**Shipped:** `MaleEvenToned`→M1, `MaleArgonian`→M2, `MaleBrute`→M3, `MaleNord`→M4, `MaleBandit`→[M3,M4], `MaleCondescending`→M5, `MaleDarkElf`→M6, `MaleKhajitt`→M7, `MaleOrc`→M8. **No female voicetypes are mapped by default** — unrouted females fall through to `default_female_slot` (`F0`, the stock moans).

### `[race_map]`

Race → slot, used when no voicetype matches. Hints are **substring-matched against the race editor id, longest hint first**, so `Werewolf` beats `Wolf` and `Troll` covers `TrollFrostRace`.

```toml
[race_map]
Nord = "M4"
Werewolf = "C1"
```

**Shipped:** `Argonian`→M2, `Nord`→M4, `DarkElf`→M6, `HighElf`→M5, `Khajiit`→M7, `Orc`→M8, plus the creature hints `Werewolf`→C1, `Draugr`→C2, `Falmer`→C3, `Troll`→C4, `Giant`→C5, `Wolf`→C6, `Dog`/`Husky`→C7, `Chaurus`→C8, `Spriggan`→C9, `Horse`→C10.

!!! note
    `Draugr` does not match skeleton races — add `Skeleton = "C2"` if you want them covered. `Husky` is listed separately because `DLC1HuskyRace` doesn't contain "Dog".

## Category layer tables

These decide **which folder a category name resolves to**, once the slot is known. Split by sex; `sex = "all"` slots use the **male** tables (that's where the creature/neutral fallbacks are authored) and skip `[male_only_remap]`.

### `[category_aliases]`

Script/property name → on-disk folder name. Applied when the exact folder doesn't exist.

```toml
[category_aliases.female]
TeaseMaleCloseToOrgasmIntense = "Male Close Tease Intense"
TeaseMaleCloseToOrgasmSoft = "Male Close Tease Soft"
MCMSampleSounds = "Orgasm"

[category_aliases.male]
StrugglingOvert = "Struggling Early"
JokeAroused = "Joke After Orgasm"
TeaseFemaleOrgasm = "Tease Aggressive Partner"
AfterFemaleOrgasm = "Post Nut Remark"
MCMSampleSounds = "Orgasm"
```

### `[male_only_remap]`

In a male-only scene the female engine's category names get routed to a male slot; this substitutes the closest male category. **Male slots only** (`sex = "all"` slots skip it). Full table: [Male-only scenes](../packs/categories.md#male-only-scenes-male_only_remap).

### `[category_fallbacks]`

Substitute (one hop) when a category has no folder in the slot. The substitute must resolve directly.

```toml
[category_fallbacks.female]
GreetLover = "Greet Familiar"
BreathySoft = "Breathy Intense"

[category_fallbacks.male]
Breathing = "Orgasm"     # creature ambience reuses the climax clips
```

Full female table: [Category Reference](../packs/categories.md#female-categories).

## `[groups]`

Startup volumes per audio group, `0.0–1.0`. **Startup only** — `voice.pcvolume`, `voice.partnervolume` and `sfx.volume` in `SLOVE.toml` override these at runtime.

```toml
[groups]
pc_high = 1.0
pc_low = 1.0
partner_high = 1.0
partner_low = 1.0
sfx = 1.0
oneshot = 1.0
```

| Group | Carries |
|---|---|
| `pc_low` / `pc_high` | the player's voice (soft / intense lines) |
| `partner_low` / `partner_high` | NPC partner voices |
| `sfx` | the body-SFX engine |
| `oneshot` | out-of-scene one-shots |

## `[[slot]]`

One table per voice. Keyed by `id` — **if two files define the same id, the last one wins the whole slot** (no per-category merge).

| Key | Type | Meaning |
|---|---|---|
| `id` | string | The slot id used everywhere else (`"F1"`, `"M3"`, `"SFX0"`, or any name you like). |
| `sex` | string | `"female"`, `"male"`, or `"all"`. `"all"` matches either sex on an explicit route but is skipped by the blind default-by-sex fallback; it uses the male category tables. |
| `path` | path | Folder scanned for `<Category>\*.wav` subfolders. **Loose files only.** Optional if every category is explicit. |
| `fallback` | slot id | Categories this slot can't resolve are retried in that slot, per category. Chains allowed, **capped at 4 hops**. |
| `gag_slot` | slot id | Slot to use instead while the actor wears a gag device. |
| `[slot.categories]` | table | Explicit per-category audio — **wins over a same-named scanned folder**. |

### `[slot.categories]`

Two value forms:

```toml
[[slot]]
id = "F0"
sex = "female"
[slot.categories]
# string = one FOLDER scanned for this category.
#   'Sound\...' = full Data path; anything else = relative to the slot's `path`.
#   Loose files only. Several categories may share one pool.
Satisfied = 'Sound\fx\SexLab\vFemaleMoan01\mild'

# array = an explicit FILE LIST. Needs no folders on disk and MAY POINT INTO A BSA.
Orgasm = [
  'Sound\fx\SexLab\vFemaleMoan01\hot\hot_moans_01.wav',
  'Sound\fx\SexLab\fxOrgasm01\01.wav',
]
```

### The shipped slots

| Slot | Sex | Definition |
|---|---|---|
| `F1` | female | scans `Sound\fx\IVDT\F1`, `fallback = "F0"`, `gag_slot = "F1gag"` |
| `F2` | female | scans `Sound\fx\IVDT\F2`, `fallback = "F0B"`, `gag_slot = "F1gag"` |
| `F3` | female | scans `Sound\fx\IVDT\F3`, `fallback = "F0B"`, `gag_slot = "F1gag"` |
| `F1gag` | female | scans `Sound\fx\IVDT\F1gag` — one `GagMoan` pool, **no fallback** |
| `F0` | female | ~50 category folder-refs into SexLab's `vFemaleMoan01` (mild/medium/hot) + explicit `Orgasm` and blowjob-action lists |
| `F0B` | female | the same mapping over SexLab's `vFemaleMoan03` |
| `M1`–`M8` | male | scan `Sound\fx\IVDT\M1`…`M8` |
| `C1`–`C10` | all | explicit vanilla-BSA file lists, `Orgasm` + usually `Breathing` |
| `SFX0` | all | ~50 folder refs into `Sound\fx\SloveSFX` (+ `Smack`, `PullOutGape` from `Sound\fx\IVDT\Sounds`) |

Details per family: [Female packs](../packs/female.md) · [Male, creature, gag & SFX slots](../packs/slots.md).

## `[sfx]`

A flat `name = 'folder'` table, checked **after** the sfx slot's categories. SLO VE's preset defines everything as `SFX0` categories instead, so this table ships empty — it exists for add-ons that want to contribute a sound name without redefining the slot:

```toml
[sfx]
MyCustomSlap = 'Sound\fx\MyMod\slap'
```

A `[sfx]` name is also the **last resort** of voice-category resolution, so a body-SFX name can double as a voice category where that makes sense (which is how `Smack` and `PullOutGape` are reachable from the voice engine).

## Worked example — a complete custom slot

```toml
# Data\SKSE\Plugins\AudioUtil\config\ZZ_MyVoices.toml

[npc_overrides]
'Serana.esp|002B6C' = "Serana"      # pin her to a slot of her own

[[slot]]
id = "Serana"
sex = "female"
path = 'Sound\fx\IVDT\Serana'       # <Category>\*.wav lives here
fallback = "F0B"                    # anything the pack lacks → stock moans
gag_slot = "F1gag"

[[slot]]
id = "Serana"                       # ← WRONG: a second block with the same id
                                    #    replaces the whole slot above
```

Then:

```
cgf "AudioUtil.ReloadConfig"
cgf "SLOVE_Test.AuditVoicePack" "Serana"
cgf "SLOVE_Test.SampleCategory" "Serana" "Orgasm"
```

For the engine-level detail behind all of this, see AudioUtil's [Voice & Category Resolution](https://crajjjj.github.io/AudioUtil/config/resolution/) and [Config Reference](https://crajjjj.github.io/AudioUtil/config/reference/).
