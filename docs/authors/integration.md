# For Mod Authors

How to build on SLO VE without touching its scripts — and how to ship a voice pack or an SFX set that plugs into it.

## Shipping a voice pack

A SLO VE-compatible pack is **just a folder of loose WAV files**. No ESP, no scripts, no sound-descriptor records, no voice aliases.

```
Data\Sound\fx\SLOVE\<SlotId>\<Category>\*.wav
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
gag_slot = "MyPackGag"       # your own gag slot (below), not the shared F1gag

# Optional: your pack's own muffled gag voice. Ship "Gagged Grunt" and
# "Gagged Grunt Intense" folders and route the gag slot at them; SLO VE requests
# those two categories on a gagged line. fallback = "F1gag" muffles anything they
# don't cover with the shared GagMoan pool. Omit this whole slot (and point
# gag_slot = "F1gag") to just use the shared muffled pool.
[[slot]]
id = "MyPackGag"
sex = "female"
fallback = "F1gag"
[slot.categories]
"Gagged Grunt" = 'Sound\fx\MyPack\voice\Gagged Grunt'
"Gagged Grunt Intense" = 'Sound\fx\MyPack\voice\Gagged Grunt Intense'
```

Use a **stable, unique filename prefix** so your overlay sorts predictably and never collides with another mod's, and a **unique gag slot id** (`<Pack>Gag`) so two installed packs never collide. Don't redefine SLO VE's slots — `[[slot]]` is keyed by `id` and a duplicate id replaces the **whole** slot. See [Configuration Overview](../config/index.md).

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

### Muting an actor

Your mod can take an actor's voice away from SLO VE, for the current stage or for the rest of the scene, by sending a mod event **from that actor** with your mod's name as the string. Use it when you play that actor's sounds yourself (choking, a scripted line, a death) and SLO VE's moans and dirty talk would run over them.

| Event | Effect | Ends |
|---|---|---|
| `SLOVE_Mute_Stage` | The actor makes no SLO VE sound, so no lipsync either | When the stage or animation changes, when the scene ends, or on `SLOVE_Unmute_Stage` |
| `SLOVE_Mute_Scene` | Same | When the scene ends, or on `SLOVE_Unmute_Scene` |
| `SLOVE_Unmute_Stage` | Lifts a stage mute early | |
| `SLOVE_Unmute_Scene` | Lifts a scene mute early | |

```papyrus
akActor.SendModEvent("SLOVE_Mute_Stage", "MyMod")        ; quiet until the stage changes
akActor.SendModEvent("SLOVE_Mute_Scene", "MyMod", 1.0)   ; quiet for the rest of the scene, face handed over too
akActor.SendModEvent("SLOVE_Unmute_Scene", "MyMod")      ; give the voice back early
```

- **The actor is the sender, the string is your mod's name.** Every event is written to `SLOVE.0.log` with both (`Mute : SLOVE_Mute_Stage actor=Lydia caller='MyMod' ...`), accepted or not, and so is every mute that ends on its own. A silent actor can always be traced back to the mod that asked.
- **`numArg` of `1.0` also hands over the face.** SLO VE stops writing that actor's expression until the mute ends and leaves the face alone at scene end. Send it when your mod paints the face (MFG phonemes, modifiers, expression) while the actor is muted. With `0`, expressions carry on.
- **Per actor.** Everyone else in the scene keeps talking. Works in player scenes and in NPC-only scenes.
- **Send it once the scene is running** (`AnimationStart` or later). An event for an actor who is not in a scene is logged and ignored.
- **A stage mute belongs to the stage it was sent on.** Answering `StageStart` with a fresh `SLOVE_Mute_Stage` is the intended pattern, and it does not matter whether your handler or SLO VE's runs first.
- **You never have to unmute.** Both mutes end on their own; the unmute events only give the voice back early. There is one slot per kind: a second caller's mute replaces the first, and any caller's unmute clears it.
- **SexLab's own voice.** SLO VE silences SexLab's moan engine for its scenes. If your mod also force-silences an actor there and restores that when it unmutes, SLO VE re-applies its own silence for a few seconds after the mute ends, so SexLab's moans do not come back underneath.
- No dependency on SLO VE: without it the events go nowhere.

To try it without writing a mod, aim at an actor (or nobody, for the player) and use the console: `slovetest mute stage`, `slovetest mute scene 1`, `slovetest unmute scene`, `slovetest mutes`.

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
