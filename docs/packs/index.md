# How Voices Work

Everything about voice packs in SLO VE comes down to two questions, answered in this order every time a line plays:

1. **Slot resolution** — which voice pack does *this actor* use?
2. **Category resolution** — which folder inside that pack does *this category* map to?

SLO VE never names a file. It asks AudioUtil for a **category** ("play `NearOrgasmNoises` on this actor") and AudioUtil resolves the slot, resolves the folder, and shuffle-picks a wav. Understanding these two chains is the whole game when working with packs.

## Slots — the core idea

A **slot** is one voice: an id, a sex, and somewhere to get audio from. Nothing about an actor is baked into a pack; the pack just sits in a folder, and the routing tables decide who speaks it.

SLO VE's preset ships these slots:

| Slot | Sex | Who uses it | Where its audio comes from |
|---|---|---|---|
| `F0` | female | **default for all unrouted females** | SexLab's own `vFemaleMoan01` set, mapped per category by intensity |
| `F0B` | female | backfill for `F2`/`F3` | SexLab's own `vFemaleMoan03` set |
| `F1` | female | **the player** (reserved — no NPC ever gets it) | scans `Sound\fx\IVDT\F1`, backfills from `F0` |
| `F2` | female | a follower/partner you route to it | scans `Sound\fx\IVDT\F2`, backfills from `F0B` |
| `F3` | female | a second follower/partner | scans `Sound\fx\IVDT\F3`, backfills from `F0B` |
| `F1gag` | female | any female wearing a gag device | scans `Sound\fx\IVDT\F1gag` (one muffled pool) |
| `M1`–`M8` | male | males, by voicetype / race | bundled packs in `Sound\fx\IVDT\M1`…`M8` |
| `C1`–`C10` | all | creatures, by race | explicit file lists straight out of the vanilla BSAs |
| `SFX0` | all | body SFX (not a voice) | folders under `Sound\fx\SloveSFX` |

!!! tip "F1 is the player's slot, always"
    `pc_female_slot = "F1"` in [`AudioUtil.toml`](../config/audioutil.md) reserves it: the player *always* resolves to `F1`, and **no NPC ever does**. That is why a pack dropped into `F1` becomes the player's voice with zero configuration. Playing a male character? Set `pc_male_slot = "M1"` (or any male slot) in the same file.

## On-disk layout

A voice pack is a folder of category folders full of `.wav` files:

```
Data\Sound\fx\IVDT\F1\
    Greet Familiar\        01.wav  02.wav  03.wav …
    Foreplay Soft\         01.wav  02.wav …
    Near Orgasm Noises\    …
    Orgasm\                …
```

The folder names are **category names**, matched case- and space-insensitively (see [Normalisation](#normalisation)). The file names inside are irrelevant — any `.wav` in the folder is a candidate.

!!! warning "Loose PCM WAVs only"
    - **Folder scans cannot see inside BSA archives.** A packed pack (`.bsa`) will never be found by a slot's `path` scan. To play BSA audio you must list the files explicitly — see [explicit file lists](#3-explicit-file-lists-bsa-capable).
    - **Lipsync requires a loose PCM wav.** Compressed formats still play, but the mouth stays shut; AudioUtil reads the waveform's amplitude envelope to drive the phonemes.

## 1. Slot resolution — which pack an actor gets

Checked top to bottom, **first hit wins**:

| # | Source | Notes |
|---|---|---|
| 1 | `pc_female_slot` / `pc_male_slot` | **Player only.** The PC always lands here; no NPC ever does. |
| 2 | `[npc_overrides]` | Explicit per-NPC pin: `'Plugin.esp\|FormID' = "Slot"`. Beats everything below. |
| 3 | `[voicetype_remap]` → `[voicetype_map]` | Rename a voicetype you have no pack for to one you do (one hop), then map it to a slot. |
| 4 | `[race_map]` | Substring match against the race editor id, **longest hint wins**. Creatures land here. |
| 5 | `default_female_slot` / `default_male_slot` | Last resort, by sex. Unrouted females → `F0`. |

Then one final check: if the actor **wears a gag device** and their slot names a `gag_slot`, resolution switches there — see [The gag slot](slots.md#the-gag-slot-f1gag).

`GetSlotForActor(actor)` returns exactly what this chain produces. Check it live:

```
cgf "SLOVE_Test.DumpState"            ; prints the player's slot
```

### Spreading NPCs across several slots

A `[voicetype_map]` or `[race_map]` value may be a **list** instead of one slot:

```toml
[voicetype_map]
MaleBandit = ["M3", "M4"]     # bandits spread across two packs
```

Actors sharing that voicetype are distributed **deterministically by form id** — the same NPC always gets the same slot, every scene, load-order independent. This is how you auto-map many NPCs across your installed packs without pinning each one. See [auto-mapping female NPCs](female.md#auto-map-female-npcs-across-your-packs).

## 2. Category resolution — which folder plays

Once the slot is known, the requested category resolves **inside that slot**, in this order:

```
exact folder in the slot
  → [category_aliases.female] / [category_aliases.male]   (rename: script name → on-disk folder)
  → [male_only_remap]                                      (male slots only)
  → [category_fallbacks.female] / [category_fallbacks.male] (substitute, one hop)
  → the slot's `fallback` slot                             (retry the whole chain there, max 4 hops)
  → the [sfx] table                                        (last resort, same name)
```

If nothing resolves, the line simply doesn't play (and AudioUtil logs it).

This chain is why a **partial pack still works**. Drop a pack with 20 of the 71 female categories into `F1`: those 20 play from the pack, and the other 51 fall through `fallback = "F0"` to SexLab's stock moans — per category, not all-or-nothing.

See the [Category Reference](categories.md) for every category name, its expected folder, and what it falls back to.

## 3. How a slot gets its audio

Three mechanisms, freely mixed within one slot:

### 1. A scanned folder tree

```toml
[[slot]]
id = "F1"
sex = "female"
path = 'Sound\fx\IVDT\F1'      # holds <Category>\*.wav subfolders
fallback = "F0"
```

The normal case for a voice pack. **Loose files only.**

### 2. Per-category folder references

A `[slot.categories]` **string** value points one category at one folder. `Sound\...` is a full Data-relative path; anything else is relative to the slot's own `path`.

```toml
[[slot]]
id = "F0"
sex = "female"
[slot.categories]
Satisfied     = 'Sound\fx\SexLab\vFemaleMoan01\mild'
ForeplaySoft  = 'Sound\fx\SexLab\vFemaleMoan01\mild'   # several categories may share one pool
```

This is how the stock `F0`/`F0B` slots map 50+ categories onto SexLab's three intensity folders without copying a single file. **Loose files only.**

### 3. Explicit file lists (BSA-capable)

A `[slot.categories]` **array** value lists exact files. No folders on disk are needed and the paths **may live inside a BSA** — the engine's resource loader resolves them where a folder scan cannot.

```toml
[[slot]]
id = "C1"
sex = "all"
[slot.categories]
Orgasm = [
  'Sound\FX\NPC\Werewolf\Growl\NPC_Werewolf_Growl_01.wav',
  'Sound\FX\NPC\Werewolf\Growl\NPC_Werewolf_Growl_02.wav',
]
```

This is how creature slots play vanilla sounds with nothing installed.

**Explicit categories (2 and 3) win over a same-named folder found by the `path` scan.**

## Shuffle bags — why lines don't repeat

Each (slot, category) pair has its own **shuffle bag**: files are dealt out in random order and none repeats until the bag is empty and refills. A five-file category plays all five before any repeats, so a small pack still sounds varied instead of hammering the same clip.

## Normalisation

Every name — slot id, category, folder, group, voicetype, race hint — is **lowercased with all non-alphanumerics stripped** before matching. So these are all the same key:

```
"About To Cum"  ==  "AboutToCum"  ==  "about_to_cum"  ==  "abouttocum"
```

You never have to match spacing or case between a pack's folder names, the TOML, and the engine.

## Groups and channels

Every voice line plays into a **group** (a live volume bus) and optionally a **channel** (an exclusivity lane — a new line on an occupied channel replaces the old one).

- **Voice groups:** `pc_low`, `pc_high`, `partner_low`, `partner_high` — startup levels in `[groups]`, runtime levels from `voice.pcvolume` / `voice.partnervolume`.
- **SFX groups:** `sfx` (startup level from `sfx.volume`), `oneshot`.
- **SFX channels:** `sfx_main_<position>` and `sfx_contact_<position>` — each actor's continuous stream and their one-shots never cut each other off.

`voice_no_interrupt = true` (default) means a speaker whose channel is still playing **skips** the new line rather than cutting the old one short. Different speakers still overlap freely.

## Diagnosing resolution

Three console commands answer nearly every "why is she silent" question:

```
cgf "SLOVE_Test.DumpState"                          ; config flags + the player's resolved slot
cgf "SLOVE_Test.AuditVoicePack" "F1"                ; every category a slot resolves, and what's MISSING
cgf "SLOVE_Test.SampleCategory" "F1" "Orgasm"       ; play one clip from a slot/category right now
cgf "AudioUtil.ReloadConfig"                        ; re-read the TOMLs and rescan folders, live
```

`AuditVoicePack` loops the full category list for that sex (71 female / 15 male) against the slot **after** aliases and fallbacks, so a healthy pack reports `71/71 categories resolve` even if the pack itself only ships 20 folders.
