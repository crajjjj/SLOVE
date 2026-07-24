# `AudioUtil.toml` — engine globals

**`Data\SKSE\Plugins\AudioUtil\AudioUtil.toml`** is the **base** config file of the AudioUtil engine. SLO VE ships its own copy holding **only the globals** — the slots and routing live in the additive overlay [`config\SLOVE_voices.toml`](voices.md).

!!! danger "This file must win the load order"
    AudioUtil ships its own SFW-neutral `AudioUtil.toml` that defines nothing. **SLO VE must overwrite it** (install SLO VE below AudioUtil in MO2), or no actor resolves to a voice.

!!! warning "Base-only — overlays cannot set these"
    `[general]`, `[ppa]`, the `[lipsync]` scalar tuning and the `[gag]` `enable`/`default_category` toggles are read **only from this file**. A `config\*.toml` overlay that sets them is **ignored, with a warning** in `AudioUtil.log`. The two additive exceptions inside those tables are `[lipsync] block_categories` and `[gag] keywords`, which **do** merge from every file.

    In practice: to change anything on this page you edit **this file**, and an update to SLO VE will overwrite your edit.

Live reload:

```
au reload
```

## `[general]`

```toml
[general]
log_level = "info"
sound_flags = 0x1A
sound_priority = 128
voice_3d = true
voice_no_interrupt = true
default_female_slot = "F0"
default_male_slot = "M1"
pc_female_slot = "F1"
pc_male_slot = ""
```

| Key | SLO VE ships | Meaning |
|---|---|---|
| `log_level` | `"info"` | Verbosity of `AudioUtil.log`: `trace`/`debug`/`info`/`warn`/`error`. Set `debug` when diagnosing resolution. |
| `sound_flags` | `0x1A` | `BuildSoundDataFromFile` flags. Only touch if audio is silent or not 3D-positioned; sweep values with `AudioUtil.DebugPlayFile`. |
| `sound_priority` | `128` | Engine sound priority. |
| `voice_3d` | `true` | `true` = voices are 3D-positioned at the speaker and attenuate with distance. `false` = flat/2D at full volume, so every speaker is equally audible. **Lipsync is unaffected either way; SFX always play 3D at the actor.** |
| `voice_no_interrupt` | `true` | `true` = skip a new line while that speaker's channel is still playing, so a line finishes. Per speaker — different speakers still overlap. `false` = cut the old line off. |
| `default_female_slot` | `"F0"` | Unrouted female NPCs speak the stock SexLab moans. |
| `default_male_slot` | `"M1"` | Unrouted males (and creatures with no race hint) speak M1. |
| `pc_female_slot` | `"F1"` | **Reserved for the player.** The PC always resolves here and no NPC ever does. |
| `pc_male_slot` | `""` | Same for a male PC — **set this to `"M1"` (or any male slot) when playing a male character.** |
| `sfx_slot` | *(default `"SFX0"`)* | The slot whose categories `PlaySFX` checks before the flat `[sfx]` table. |

## `[ppa]`

The optional **Accurate Penetration** bridge. When PPA is installed, SLO VE uses *measured* penetration depth and gape instead of authored scene labels — thrust-synced SFX, contact one-shots, expression penetration checks, and the resistance system's "is she being penetrated" test.

```toml
[ppa]
enable = true
event_rate_ms = 2000
```

| Key | SLO VE ships | Meaning |
|---|---|---|
| `enable` | `true` | Gate the bridge. Harmless when PPA isn't installed — it simply never connects. |
| `event_rate_ms` | `2000` | Minimum interval per receiver for `AudioUtilPPA_Update` mod events. **Floored at 1000 ms.** A change in the context bitmask still fires immediately. |

## `[lipsync]`

Mouths move with the audio: every voice line drives the speaker's MFG `Aah`/`BigAah` phonemes from the wav's loudness envelope, per frame.

```toml
[lipsync]
enable = true
gain = 1.0
attack_ms = 30
release_ms = 90
min_level = 0.04
block_categories = ["BlowjobActionSoft", "BlowjobActionIntense", "Orgasm"]
```

| Key | SLO VE ships | Meaning |
|---|---|---|
| `enable` | `true` | Master switch. |
| `gain` | `1.0` | `0.0–2.0` mouth-open strength. Lower it if mouths gape too wide. |
| `attack_ms` | `30` | How fast the mouth opens toward a louder level. |
| `release_ms` | `90` | How fast it closes on quiet or at clip end. |
| `min_level` | `0.04` | Levels below this keep the mouth shut (kills jitter on noise floors). |
| `block_in_dialogue` | *(default `true`)* | Suppress lipsync while the actor is in a dialogue with the player — the game drives that mouth. |
| `block_categories` | see above | **Additive across files.** Categories that never move the mouth. |

Why the three shipped blocks: **blowjob action** clips are oral SFX (slurping, not vocalisation), and **`Orgasm`** hands the mouth to the climax/ahegao face so a line can't lipsync over an open-mouth expression.

!!! note "Lipsync needs a loose PCM wav"
    BSA-packed or compressed audio still plays, but the mouth stays shut — the plugin reads the waveform to build the envelope. Creature slots play from the vanilla BSAs and are silent-mouthed by design.

Runtime control from the console:

```
SLOVE_LipSync Enabled 0
SLOVE_LipSync Gain 0.8
```

## `[gag]`

Routes a gagged speaker's voice through her slot's `gag_slot` and suppresses her lipsync (the device owns the mouth). See [The gag slot](../packs/slots.md#the-gag-slot-f1gag).

```toml
[gag]
enable = true
default_category = "GagMoan"
keywords = [
  'Devious Devices - Assets.esm|7EB8',   # zad_DeviousGag
  'ZaZAnimationPack.esm|8A4D',           # zbfWornGag
  'ZaZAnimationPack.esm|8A35',           # zbfEffectOpenMouth
  'Toys.esm|8C2',                        # ToysEffectMouthOpen
  'SL Survival.esp|0B74B5',              # _SLS_TongueKeyword
]
```

| Key | SLO VE ships | Meaning |
|---|---|---|
| `enable` | `true` | Master switch (base-only). |
| `default_category` | `"GagMoan"` | Catch-all played in the gag slot when the requested category has no audio there — so a gagged actor is always muffled, never silent (base-only). |
| `keywords` | 5 entries | **Additive across files.** Worn-item keywords that count as a gag, as `'Plugin.esp\|FormID'`. A keyword whose mod isn't installed is silently skipped, so listing extras is harmless. |

Adding your own device:

```toml
# in your own config\ZZ_MyVoices.toml — keywords are additive
[gag]
keywords = ['MyDeviceMod.esp|001234']
```

Gag detection also re-checks on a throttle during a line, so equipping a gag mid-scene hands the mouth over right away.

To disable the behaviour without touching keywords, set `voice.enableddgagvoice = 0` in [`SLOVE.toml`](slove.md#voice).

## Full engine documentation

Every key AudioUtil understands, including the ones SLO VE doesn't set, is documented at **[crajjjj.github.io/AudioUtil](https://crajjjj.github.io/AudioUtil/config/reference/)**.
