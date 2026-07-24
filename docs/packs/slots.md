# Male, Creature, Gag & SFX Slots

Female packs are covered in [Installing & Routing Female Packs](female.md). This page covers everything else SLO VE voices.

## Male slots M1–M8

The male packs are **bundled** — nothing to download. They install to `Data\Sound\fx\IVDT\M1` … `M8`:

| Slot | Voice | Routed from |
|---|---|---|
| `M1` | Even Toned | `MaleEvenToned` (+ remapped commoner/young/drunk/old-kindly voicetypes) — also `default_male_slot` |
| `M2` | Argonian | `MaleArgonian`, race hint `Argonian` |
| `M3` | Brute | `MaleBrute` (+ commander/soldier/old-grumpy), `MaleBandit` |
| `M4` | Nord | `MaleNord` (+ guard/nord-commander), `MaleBandit`, race hint `Nord` |
| `M5` | Condescending | `MaleCondescending` (+ elf-haughty/warlock/sly-cynical), race hint `HighElf` |
| `M6` | Dark Elf | `MaleDarkElf` (+ dark-elf-cynical), race hint `DarkElf` |
| `M7` | Khajiit | `MaleKhajitt` (+ khajiit-accented), race hint `Khajiit` |
| `M8` | Orc | `MaleOrc`, race hint `Orc` |

`MaleBandit = ["M3", "M4"]` spreads bandits over two packs deterministically, so a camp of bandits doesn't sound like one man.

### The male pack folder set

A male pack has up to 11 category folders:

```
About To Cum\     Aggressive\        Aroused\
Joke After Orgasm\  Lovey Dovey\     Orgasm\
Post Nut Remark\  Struggling Early\  Struggling Overt\
Struggling Subtle\  Tease Aggressive Partner\
```

Not every bundled pack has all 11 (`M1` has no *Struggling Overt*, for instance) — the [category layer](categories.md#male-categories) covers the gaps with aliases.

### Adding or replacing a male pack

Same mechanics as female. Drop folders into a new path and declare the slot:

```toml
[[slot]]
id = "M9"
sex = "male"
path = 'Sound\fx\IVDT\M9'
fallback = "M1"              # optional: backfill missing categories from a bundled pack

[voicetype_map]
MaleUniqueUlfric = "M9"
```

To *replace* a bundled pack's audio without touching the TOML, just overwrite the WAVs under `Sound\fx\IVDT\M<n>` in your mod manager.

### `[voicetype_remap]` — covering voicetypes you have no pack for

Runs **before** the slot lookup and renames a voicetype (one hop) to one you do have:

```toml
[voicetype_remap]
enable = true
MaleGuard = "MaleNord"          # a guard now resolves as a Nord → M4
MaleCommander = "MaleBrute"
```

The target must itself be a `[voicetype_map]` key. `enable = false` disables the whole layer.

## Creature slots C1–C10

Creatures play **straight out of the vanilla archives** — no assets ship and none are needed. Each slot is an explicit file list, which is the only way to reach BSA-packed audio (folder scans can't see inside archives).

| Slot | Creature | Race hint |
|---|---|---|
| `C1` | Werewolf | `Werewolf` |
| `C2` | Draugr | `Draugr` |
| `C3` | Falmer | `Falmer` |
| `C4` | Troll | `Troll` |
| `C5` | Giant | `Giant` |
| `C6` | Wolf | `Wolf` |
| `C7` | Dog / Husky | `Dog`, `Husky` |
| `C8` | Chaurus | `Chaurus` |
| `C9` | Spriggan | `Spriggan` |
| `C10` | Horse | `Horse` |

Race hints are **substring-matched against the race editor id, longest hint first** — that's what keeps `Werewolf` and `Wolf` apart, and what makes `Troll` cover `TrollFrostRace`.

All creature slots are `sex = "all"` so they resolve regardless of what sex the engine reports for a creature (most creature races have no `ActorBase` sex and read as male).

### Two creature categories

| Category | When it plays |
|---|---|
| `Orgasm` | at climax |
| `Breathing` | rolled periodically through the scene by the voice engine (`voice.creaturebreathing`, interval from `creaturebreathmin/maxinterval`, halved on intense stages) |

`[category_fallbacks.male]` maps `Breathing = "Orgasm"`, so a creature slot that defines only `Orgasm` still pants — it reuses those clips. Give a slot its own `Breathing` list to override.

Slots with no usable vanilla ambience simply omit `Breathing` (`C8` Chaurus) and stay silent between climaxes. Some vanilla creatures ship almost no `Sound\FX` material at all — Falmer and Spriggan combat barks live in the *voice* archives, not fx — which is why those lists are thin.

### Adding a creature

```toml
[race_map]
Bear = "C11"

[[slot]]
id = "C11"
sex = "all"
[slot.categories]
Orgasm = [
  'Sound\FX\NPC\Bear\NPC_Bear_Attack_01.wav',
  'Sound\FX\NPC\Bear\NPC_Bear_Attack_02.wav',
]
Breathing = [
  'Sound\FX\NPC\Bear\NPC_Bear_Idle_01.wav',
]
```

Paths are Data-relative and case-insensitive, and **must be exact** — a wrong path silently resolves nothing. Verify with:

```
cgf "SLOVE_Test.SampleCategory" "C11" "Orgasm"
```

Creature audio is BSA-packed, so **lipsync does not run** on it (and creatures generally have no facegen anyway). That is expected, not a fault.

!!! note "Skeletons aren't covered"
    `Draugr` does not substring-match skeleton races. Add your own hint if you want them voiced: `Skeleton = "C2"`.

## The gag slot (F1gag)

When a female speaker **wears a gag device**, her voice reroutes to her slot's `gag_slot` before category resolution runs. `F1`, `F2` and `F3` all point at the bundled `F1gag` pool.

```toml
[[slot]]
id = "F1gag"
sex = "female"
path = 'Sound\fx\IVDT\F1gag'
```

`F1gag` holds a single `GagMoan` folder of muffled clips. No SLO VE category matches that name, so **every gagged line falls through to `[gag] default_category = "GagMoan"`** — she is always muffled, never silent, and never leaks a clear line. The slot deliberately has **no `fallback`**, since a fallback chain could resolve a category to clear audio before the catch-all is reached.

Lipsync is suppressed for a gagged actor at the same time (the device owns the mouth), and this is re-checked on a throttle so equipping a gag mid-scene hands the mouth over immediately.

Which devices count is the `keywords` list in [`AudioUtil.toml [gag]`](../config/audioutil.md#gag) — Devious Devices, ZaZ, Toys and SexLab Survival's tongue keyword ship configured. A keyword whose mod isn't installed is silently skipped, so listing extras is harmless.

Turn the whole behaviour off with `voice.enableddgagvoice = 0` in `SLOVE.toml`, or `[gag] enable = false` in `AudioUtil.toml`.

## The SFX slot (SFX0)

Body SFX are a slot like everything else — `PlaySFX(name)` resolves `name` as a category of the slot named by `[general] sfx_slot` (default `SFX0`) before falling back to the flat `[sfx]` table. That gives the SFX library the same toolset as voices: folder refs, explicit BSA-capable file lists, shuffle bags.

```toml
[[slot]]
id = "SFX0"
sex = "all"
[slot.categories]
SmallWetSlush = 'Sound\fx\SloveSFX\WetSlush\small'
MediumClap    = 'Sound\fx\SloveSFX\MediumClap'
# …
```

The bundled library (`Sound\fx\SloveSFX`, ships with SLO VE) maps these categories:

| Family | Categories |
|---|---|
| **Slushing** | `SmallWetSlush`, `SmallWetSlush2`, `SmallFastSlush`, `SmallFastSlush2`, `MediumSlush`, `FastSlush`, `BigSlush`, `HeavySlushing`, `LightSlushing`, `MediumSlushing`, `RapidSlushing` |
| **Impacts / claps** | `SmallImpact`, `MediumImpact1`–`MediumImpact4`, `MediumImpact5Wet`, `FastImpact1`–`FastImpact3`, `SlowClap`, `MediumClap`, `FastClap` |
| **Kissing** | `Kiss1`–`Kiss6` |
| **Oral** | `Blowjob1`–`Blowjob6`, `FastBlowjob1`–`FastBlowjob5` |
| **Ejaculation** | `EjacSmall`, `EjacSmallDeep`, `EjacNormal`, `EjacNormalDeep`, `EjacSharp`, `EjacHeavy`, `EjacHeavySharp`, `EjacHeavyWet` |
| **Gape / contact** | `GapeAverage`, `GapeHuge`, `Smack`, `PullOutGape` |

Ejaculation clips are size-matched at orgasm; gape one-shots are chosen from measured penetration when the Accurate Penetration bridge is present (thresholds in [`SLOVE.toml [sfx]`](../config/slove.md#sfx)).

### Replacing SFX audio

Two options:

- **Overwrite the WAVs** under `Sound\fx\SloveSFX\...` in your mod manager — no config change.
- **Repoint a category** in your own overlay. Because `[[slot]]` is keyed by `id`, redefining `SFX0` replaces the **whole** slot, so copy the full block from `SLOVE_voices.toml` before editing it:

```toml
[[slot]]
id = "SFX0"
sex = "all"
[slot.categories]
MediumClap = 'Sound\fx\MyPack\Claps\medium'
# … every other category you still want, copied over …
```

Preview any of them in-game:

```
cgf "SLOVE_Test.SampleCategory" "SFX0" "MediumClap"
```

The whole SFX engine can be turned off with `sfx.enable = 0`, and its level set with `sfx.volume` — see [`SLOVE.toml [sfx]`](../config/slove.md#sfx).
