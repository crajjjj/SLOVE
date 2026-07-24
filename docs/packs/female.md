# Installing & Routing Female Packs

Female voices work **out of the box** — every unrouted female speaks SexLab's own moan sets from slot `F0`, which every SexLab P+ install already has. Adding a pack is an upgrade, not a requirement.

SLO VE stays compatible with **Hentairim / IVDT-convention female packs**. You only need the pack's **sound files**; its ESP, scripts and sound-descriptor records are unused, because SLO VE plays WAVs by folder path.

## The female slot scheme

| Slot | Who speaks it | Scans | Backfills from |
|---|---|---|---|
| `F0` | every unrouted female NPC | *(stock SexLab `vFemaleMoan01`)* | — |
| `F0B` | *(backfill only)* | *(stock SexLab `vFemaleMoan03`)* | — |
| **`F1`** | **the player, always** | `Sound\fx\IVDT\F1` | `F0` |
| **`F2`** | whoever you route to it | `Sound\fx\IVDT\F2` | `F0B` |
| **`F3`** | whoever you route to it | `Sound\fx\IVDT\F3` | `F0B` |
| `F1gag` | any gagged female | `Sound\fx\IVDT\F1gag` | *(none — never leaks a clear line)* |

`F1` is **reserved for the player** (`pc_female_slot`), so an NPC can never accidentally end up speaking your character's voice.

## Give the player a voice pack

1. Get a Hentairim/IVDT-convention female voice pack.
2. Install its audio so the category folders land in **`Data\Sound\fx\IVDT\F1\`**:

    ```
    Data\Sound\fx\IVDT\F1\
        Greet Familiar\      01.wav …
        Foreplay Soft\       …
        Near Orgasm Noises\  …
        Orgasm\              …
    ```

    Most packs are authored for exactly this path, so they install as-is. If a pack puts its folders somewhere else, just move them under `F1`.

3. That's it. No config edit. Load the game and start a scene.

Verify without restarting:

```
cgf "AudioUtil.ReloadConfig"
cgf "SLOVE_Test.AuditVoicePack" "F1"
cgf "SLOVE_Test.SampleCategory" "F1" "Orgasm"
```

!!! tip "Partial packs are fine"
    Anything the pack doesn't cover falls through `fallback = "F0"` to the stock moans, **per category**. A pack with 20 folders gives you 20 pack categories and 51 stock ones — never silence.

## Give a follower or partner her own voice

A pack's audio is authored for the `F1` folder, so installing a *second* pack means putting the same files in `F2` — i.e. **rename the pack's `F1` folder to `F2`**:

```
Data\Sound\fx\IVDT\F2\
    Greet Familiar\  …
    Orgasm\          …
```

Then route someone to it. Two ways:

### Pin one specific NPC — `[npc_overrides]`

Edit `SKSE\Plugins\AudioUtil\config\SLOVE_voices.toml` (or better, [your own overlay](#keeping-your-edits-across-updates)):

```toml
[npc_overrides]
'MyFollower.esp|000D62' = "F2"
'AnotherMod.esp|001A4F' = "F3"
```

- The key is `'Plugin.esp|FormID'` — plugin filename, a pipe, the hex form id.
- For an **ESL-flagged** plugin (`.esl`, or an ESP-FE) use the **last 3 hex digits**: `'MyEslMod.esp|D62'`.
- Get the form id by clicking the NPC in the console — the 8-digit number shown there has a load-order prefix; drop the prefix (and for ESL, keep only the last three digits).
- Pins beat voicetype and race routing, and may target any slot.

### Auto-map female NPCs across your packs

Rather than pinning individuals, map **voicetypes** to your installed slots. A list value spreads actors across the slots deterministically — the same NPC always gets the same voice:

```toml
[voicetype_map]
FemaleEvenToned = ["F2", "F3"]
FemaleSultry    = "F2"
FemaleYoungEager = ["F2", "F3"]
FemaleCommander = "F3"
```

Common vanilla female voicetypes: `FemaleEvenToned`, `FemaleYoungEager`, `FemaleSultry`, `FemaleCommander`, `FemaleCommoner`, `FemaleSoldier`, `FemaleCondescending`, `FemaleShrill`, `FemaleNord`, `FemaleArgonian`, `FemaleKhajiit`, `FemaleDarkElf`, `FemaleElfHaughty`, `FemaleOldGrumpy`, `FemaleOldKindly`.

Anything you don't map keeps the stock `F0` moans. Add packs, add a line, done.

!!! note "Order of authority"
    `[npc_overrides]` → `[voicetype_remap]` → `[voicetype_map]` → `[race_map]` → `default_female_slot`. A pin always wins.

## Add more slots than F1–F3

Nothing is special about the number three. To add `F4`:

```toml
[[slot]]
id = "F4"
sex = "female"
path = 'Sound\fx\IVDT\F4'
fallback = "F0B"          # backfill categories this pack lacks
gag_slot = "F1gag"        # muffled voice while gagged (optional)

[voicetype_map]
FemaleSultry = "F4"
```

Then install the pack's folders into `Data\Sound\fx\IVDT\F4\`, reload, and audit:

```
cgf "AudioUtil.ReloadConfig"
cgf "SLOVE_Test.AuditVoicePack" "F4"
```

Slot ids are arbitrary strings — `F4`, `Serana`, `MyPack` all work. Only the **sex** field and the routing tables matter to the engine.

!!! warning "`sex` must be right"
    `sex = "female"` slots are only offered to female actors by the blind default-by-sex fallback; `"male"` likewise; `"all"` matches either sex on an explicit route (used by creatures and SFX) but is skipped by the blind default. A female pack declared `sex = "male"` will resolve categories through the *male* alias/remap layer and mostly come up empty.

## Playing a male character

The PC's slot is reserved by sex. For a male PC, set the reserved male slot in the **base** `SKSE\Plugins\AudioUtil\AudioUtil.toml`:

```toml
[general]
pc_female_slot = "F1"
pc_male_slot = "M1"       # the player now always speaks M1
```

This is a **global** key, so it must be set in the base file — an overlay cannot change it. See [AudioUtil.toml Reference](../config/audioutil.md).

## Keeping your edits across updates

`SLOVE_voices.toml` ships with SLO VE, so **an update overwrites your edits to it**. AudioUtil merges *every* `config\*.toml` in sorted filename order, and the routing tables are **additive**, so put your customisations in a file of your own:

**`Data\SKSE\Plugins\AudioUtil\config\ZZ_MyVoices.toml`**

```toml
# My personal SLO VE voice routing. Sorts after SLOVE_voices.toml, so my
# entries win on any key they share.

[npc_overrides]
'MyFollower.esp|000D62' = "F2"

[voicetype_map]
FemaleEvenToned = ["F2", "F3"]

[[slot]]
id = "F4"
sex = "female"
path = 'Sound\fx\IVDT\F4'
fallback = "F0B"
```

Rules to keep in mind:

- **Additive tables merge** (`[[slot]]`, `[sfx]`, `[npc_overrides]`, `[voicetype_remap]`, `[voicetype_map]`, `[race_map]`, `[category_aliases.*]`, `[male_only_remap]`, `[category_fallbacks.*]`, `[groups]`) — later files win **per key**.
- **A `[[slot]]` is keyed by `id`.** Redefining an existing id replaces the **whole slot**, not individual categories.
- **Globals cannot be overridden here.** `[general]`, `[ppa]`, `[lipsync]` scalars and the `[gag]` toggles are read only from the base `AudioUtil.toml`; an overlay that sets them is ignored and warned about in `AudioUtil.log`.
- A file that fails to parse is **skipped**, and the rest still merge — a broken edit never leaves the game silent. The parse error is logged.

Full details: [Configuration Overview](../config/index.md).

## Checklist when a pack doesn't play

1. `cgf "AudioUtil.ReloadConfig"` — did the parse succeed? (check `AudioUtil.log`)
2. `cgf "SLOVE_Test.DumpState"` — is the player actually on `F1`?
3. `cgf "SLOVE_Test.AuditVoicePack" "F1"` — which categories are `MISSING`?
4. `cgf "SLOVE_Test.SampleCategory" "F1" "Orgasm"` — `handle=0` means nothing resolved.
5. Are the WAVs **loose** (not in a BSA) and under exactly `Data\Sound\fx\IVDT\F1\<Category>\`?
6. Is SLO VE still winning the `.toml` conflict after your last install?

More in [Troubleshooting](../troubleshooting.md).
