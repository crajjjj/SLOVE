# For Mod Authors

How to build on SLO VE without touching its scripts — and how to ship a voice pack or an SFX set that plugs into it.

## Shipping a voice pack

A SLO VE-compatible pack is **just a folder of loose WAV files**. No ESP, no scripts, no sound-descriptor records, no voice aliases.

```
Data\Sound\fx\IVDT\<SlotId>\<Category>\*.wav
```

Guidelines:

- **Loose PCM `.wav`.** BSA-packed audio can't be found by a folder scan, and lipsync needs a loose PCM wav to read the amplitude envelope from.
- **Name folders after the categories** in the [Category Reference](../packs/categories.md). Matching is case- and space-insensitive, so `About To Cum` and `AboutToCum` are equivalent.
- **Partial packs are fine and expected.** Anything you don't cover backfills through the slot's `fallback` chain to SexLab's stock moans, per category.
- **Author for `F1`** (the player's slot) as the Hentairim/IVDT convention does. Users who want your pack on a follower rename the folder to `F2`/`F3`.
- **Several files per category** — the shuffle bag deals every file before repeating, so 5–10 clips per category sound far better than one.

If you want your pack to install its *own* slot rather than relying on the user renaming a folder, ship an additive overlay:

```toml
# Data\SKSE\Plugins\AudioUtil\config\MyPack.toml
[[slot]]
id = "MyPack"
sex = "female"
path = 'Sound\fx\MyPack\voice'
fallback = "F0B"
gag_slot = "F1gag"
```

Use a **stable, unique filename prefix** so your overlay sorts predictably and never collides with another mod's. Don't redefine SLO VE's slots — `[[slot]]` is keyed by `id` and a duplicate id replaces the **whole** slot. See [Configuration Overview](../config/index.md).

## Mod events

The Director re-broadcasts framework-independent events. These are **player-scene only** and fire for scenes SLO VE has adopted.

| Event | `argString` | `argNum` |
|---|---|---|
| `SLOVE_SceneStart` | SexLab thread id | — |
| `SLOVE_StageStart` | SexLab thread id | — |
| `SLOVE_Orgasm` | SexLab thread id | the orgasming actor's FormID, as a float |
| `SLOVE_SceneEnd` | SexLab thread id | — |

```papyrus
RegisterForModEvent("SLOVE_Orgasm", "OnSloveOrgasm")

Event OnSloveOrgasm(String eventName, String argString, Float argNum, Form sender)
    Int threadId = argString as Int
    Actor who = Game.GetFormEx(argNum as Int) as Actor
    ; …
EndEvent
```

These exist so consumers never have to touch raw SexLab events — the same events will be emitted by a future OStim backend.

## StorageUtil state

Per-actor state, readable with PapyrusUtil:

| Key | Type | Meaning |
|---|---|---|
| `SLOVE_Resistance` | int | Current willpower `0–100` (default `100`) |
| `SLOVE_BrokenPoints` | int | Game-hours-to-recover remaining; `> 0` means **broken** |
| `SLOVE_ResDebt` | float | Pending forced-insertion trauma, drained on later ticks |
| `SLOVE_LastSexTime` | float | Game time of the actor's last scene |
| `SLOVE_FaceOwnsMouth_Expr` | int | `1` while SLO VE's climax/ahegao face owns this actor's mouth |
| `SLOVE_FaceOwnsMouth_SLS` | int | `1` while SexLab Survival's ahegao owns the player's mouth |

```papyrus
Int willpower = StorageUtil.GetIntValue(akActor, "SLOVE_Resistance", 100)
Bool broken   = StorageUtil.GetIntValue(akActor, "SLOVE_BrokenPoints", 0) > 0
```

!!! note "Prefer the Director's getters"
    `GetResistance(actor)` and `IsBroken(actor)` on the Director apply the `resistance.enable` gate for you; the raw keys don't.

### Owning an actor's face

If your mod drives an actor's mouth (an expression set, an ahegao, a device animation), set `SLOVE_FaceOwnsMouth_Expr` to `1` on that actor while you own it. SLO VE reads the union of the two markers per line and plays that actor's voice with lipsync blocked, so its lipsync never fights your face. Clear it when you're done.

There is **no standing per-actor lipsync block** in AudioUtil — blocking is decided per line, which is why the marker has to stay accurate.

## Reading SLO VE's config

Settings are readable through AudioUtil's generic TomlUtil API — no dependency on SLO VE's scripts:

```papyrus
Int voiceOn = TomlUtil.GetInt("SKSE/Plugins/SLOVE/SLOVE.toml", "voice.pcvolume", 100)
```

Or via SLO VE's thin wrapper, which knows the path:

```papyrus
Int v = SLOVE_Config.GetInt("voice.pcvolume", 100)
Bool ok = SLOVE_Config.Available()      ; false when the AudioUtil DLL is absent
```

`SLOVE_Config` is **fail-open**: with no DLL, every getter returns the caller's default.

## Playing audio yourself

You don't need SLO VE for that — call [AudioUtil](https://crajjjj.github.io/AudioUtil/api/) directly:

```papyrus
Int h = AudioUtil.PlayVoice(akActor, "Orgasm")                   ; resolves the actor's slot
Int h = AudioUtil.PlayVoiceFromSlot("F1", "Orgasm", akActor)     ; explicit slot
Int h = AudioUtil.PlaySFX("MediumClap", akActor)
String slot = AudioUtil.GetSlotForActor(akActor)
Bool has = AudioUtil.CategoryExists("F1", "Orgasm")
```

Pass `blockLipSync = true` on `PlayVoice` for a line that must not move the mouth.

## The framework firewall

If you're contributing to SLO VE itself, one invariant governs the codebase: **`SLOVE_Director` is the only script allowed to reference `SexLabFramework` / `SexLabThread` / `SexlabRegistry` or SLPP mod-event names.** `SLOVE_Voice`, `SLOVE_Expressions`, `SLOVE_SFX` and `SLOVE_Resistance` talk only to the Director's API and the `SLOVE_*` events. That seam is what makes an OStim backend possible as an alternative Director with the same API surface.

## Building from source

```
powershell scripts\build.ps1
```

Mirrors `papyrus\Source` into `dist\Scripts\Source`, compiles with **Pyro**, and writes `Release\SLO VE.zip`. Pyro is auto-located from the VSCode papyrus-lang extension (override with `PYRO_EXE`); the game root defaults to the usual Steam path (override with `SKYRIM_GAME_PATH`).

Compilation needs **AudioUtil's Papyrus sources** on the import path — it is a hard build-time dependency, not just a runtime one. `SLOVE.esp` is authored externally and is not built by Pyro.
