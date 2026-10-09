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

### Break and recover

Two events tell you when an actor's willpower breaks and when the break is over (since 0.7.3). They are sent **from the actor**, for the player and for NPCs alike, so you do not have to poll the [StorageUtil keys](#storageutil-state).

| Event | Sender | `argNum` | Sent when |
|---|---|---|---|
| `SLOVE_Break` | the actor | game hours the break will last | the actor's willpower reaches `0` |
| `SLOVE_Recover` | the actor | `0` | the break ends and willpower is back at `100` |

```papyrus
RegisterForModEvent("SLOVE_Break", "OnSloveBreak")
RegisterForModEvent("SLOVE_Recover", "OnSloveRecover")

Event OnSloveBreak(String eventName, String argString, Float argNum, Form sender)
    Actor who = sender as Actor
    Int hours = argNum as Int      ; game hours until SLOVE_Recover, if no scene comes in between
    ; ...
EndEvent

Event OnSloveRecover(String eventName, String argString, Float argNum, Form sender)
    Actor who = sender as Actor
    ; ...
EndEvent
```

The rules:

- **On the change only.** An actor who is already broken does not send `SLOVE_Break` again, and nothing is sent for willpower that merely drains or recovers. Read the keys for the number.
- **`SLOVE_Recover` comes when the hours have passed, in a scene or not.** SLO VE keeps a game-time timer for the break that runs out first and checks again on every game load. After waiting, sleeping or fast travel the event arrives when the game resumes.
- **The keys already read the new state** when your handler runs: `SLOVE_BrokenPoints` is the break's hours after `SLOVE_Break`, and `0` with `SLOVE_Resistance` at `100` after `SLOVE_Recover`.
- **A scene pushes the end back.** The hours count from the actor's last scene, and an actor in a scene never recovers in the middle of it. Treat the hours in `SLOVE_Break` as the earliest end, not a promise.
- **Mod events are queued**, so your handler runs a moment after the fact, and it only runs if your script was registered at the time. On a game load, read `SLOVE_BrokenPoints` once to learn the current state.
- **Saves from before 0.7.3:** a break the player already carries is picked up on the first load. An NPC's is picked up at that NPC's next scene, which is also when it used to end.

To try your handlers without playing up to a break: `slovetest willpower 0` breaks the actor under the crosshair (or the player) and `slovetest willpower 100` lifts it again; both send the events.

### Muting an actor

Your mod can take an actor's voice away from SLO VE, for the current stage or for the rest of the scene, by sending a mod event **from that actor** with your mod's name as the string. Use it when you play that actor's sounds yourself (choking, a scripted line, a death) and SLO VE's moans and dirty talk would run over them.

| Event | Effect | Ends |
|---|---|---|
| `SLOVE_Mute_Stage` | The actor makes no SLO VE sound, so no lipsync either | About 2 seconds after the next stage starts (or the animation changes), with the scene, or on `SLOVE_Unmute_Stage` |
| `SLOVE_Mute_Scene` | Same | With the scene, or on `SLOVE_Unmute_Scene` |
| `SLOVE_Unmute_Stage` | Lifts a stage mute early | |
| `SLOVE_Unmute_Scene` | Lifts a scene mute early | |

```papyrus
akActor.SendModEvent("SLOVE_Mute_Stage", "MyMod")        ; quiet until the next stage starts
akActor.SendModEvent("SLOVE_Mute_Scene", "MyMod", 1.0)   ; quiet for the rest of the scene, face handed over too
akActor.SendModEvent("SLOVE_Unmute_Scene", "MyMod")      ; give the voice back early
```

- **The actor is the sender, the string is your mod's name.** Every event is written to `SLOVE.0.log` with both (`Mute : SLOVE_Mute_Stage actor=Lydia caller='MyMod' ...`), accepted or not. A silent actor can always be traced back to the mod that asked.
- **It takes effect at once.** The line the actor is in the middle of is cut, not just the next one.
- **`numArg` of `1.0` also hands over the face.** SLO VE stops writing that actor's expression while the mute is in force and leaves the face alone at scene end. Send it when your mod paints the face (MFG phonemes, modifiers, expression) while the actor is muted. With `0`, expressions carry on.
- **Per actor.** Everyone else in the scene keeps talking. Works in player scenes and in NPC-only scenes.
- **The actor has to be in a SexLab scene.** An event for an actor who is in none is logged and ignored. A scene mute can be sent as soon as the actor has been added to the scene, setup included.
- **A stage mute lasts until the next stage starts, with 2 seconds of slack on both sides of that start.** Answering `StageStart` with a fresh `SLOVE_Mute_Stage` is the intended pattern, and it does not matter whether your handler or SLO VE's runs first. The outgoing stage's mute stays in force for 2 seconds into the new stage, so there is no gap while yours is on its way; and a mute that reaches SLO VE up to 2 seconds before it hears that `StageStart` counts for the new stage. The price of the slack: a stage mute sent in the last 2 seconds of a stage also covers the one after it. A stage mute sent before the scene's first stage (during setup, or in answer to `AnimationStart`) belongs to the first stage.
- **You never have to unmute.** Both mutes run out on their own; the unmute events only give the voice back early. There is one slot per kind: a second caller's mute replaces the first, and any caller's unmute clears it.
- **A mute cannot leak.** It never carries over into the actor's next scene, and nothing survives a game load: SLO VE clears all mute state first thing on every load. If your scene is still running after a mid-scene load and you still need the mute, send it again on the next `StageStart`, or when you hear `SLOVE_SceneStart` (SLO VE sends it again once it has picked a player scene back up). Sent straight from your own load handler it can reach SLO VE before that clear and be lost.
- **SexLab's own voice.** SLO VE silences SexLab's moan engine for the actors of its scenes at scene start. Once a mute has been used, it applies that again for a few seconds after every unmute and after every stage start, so if your mod force-silences SexLab's voice for an actor and hands it back when it is done, SexLab's moans do not come back underneath SLO VE's. While your mute is in force SLO VE leaves that actor's SexLab voice exactly as you set it.
- No dependency on SLO VE: without it the events go nowhere.

To try it without writing a mod, aim at an actor (or nobody, for the player) and use the console: `slovetest mute stage`, `slovetest mute scene 1`, `slovetest unmute scene`. `slovetest mutes` lists every actor with a mute written on them and whether it is in force.

## StorageUtil state

Per-actor state, readable with PapyrusUtil:

| Key | Type | Meaning |
|---|---|---|
| `SLOVE_Resistance` | int | Current willpower `0–100` (default `100`) |
| `SLOVE_BrokenPoints` | int | Game hours the break lasts, counted from `SLOVE_LastSexTime`; `> 0` means **broken**. Back at `0` once the hours have passed (since 0.7.3; see [Break and recover](#break-and-recover)) |
| `SLOVE_ResDebt` | float | Pending forced-insertion trauma, drained on later ticks |
| `SLOVE_LastSexTime` | float | Game time of the actor's last scene; kept current while a scene runs |
| `SLOVE_RecoverPerHour` | int | The % per game-hour this actor recovers at (since 0.7.2) |
| `SLOVE_FaceOwnsMouth_Expr` | int | `1` while SLO VE's climax/ahegao face owns this actor's mouth |
| `SLOVE_FaceOwnsMouth_SLS` | int | `1` while SexLab Survival's ahegao owns the player's mouth |

```papyrus
Int willpower = StorageUtil.GetIntValue(akActor, "SLOVE_Resistance", 100)
Bool broken   = StorageUtil.GetIntValue(akActor, "SLOVE_BrokenPoints", 0) > 0
```

!!! note "Prefer the Director's getters"
    `GetResistance(actor)` and `IsBroken(actor)` on the Director apply the `resistance.enable` gate for you; the raw keys don't.

### Willpower between scenes

`SLOVE_Resistance` is the value the last scene left behind. Recovery is only **applied** when the actor's next scene starts, so a mod that shows willpower outside a scene (a HUD bar, a status icon) has to work out what that scene will find. Everything it needs is in the keys above, and during a scene the same lines give the live value, because the time stamp is then never more than a few seconds old:

```papyrus
Int Function WillpowerNow(Actor akActor)
    Int hours = 0
    Float last = StorageUtil.GetFloatValue(akActor, "SLOVE_LastSexTime", -1.0)
    If last >= 0.0
        hours = Math.Floor((Utility.GetCurrentGameTime() - last) * 24.0)
    EndIf
    If hours < 0
        hours = 0
    EndIf
    Int broken = StorageUtil.GetIntValue(akActor, "SLOVE_BrokenPoints", 0)
    If broken > 0
        ; a break is all or nothing: 0 until its hours have passed, then 100
        If broken > hours
            Return 0
        EndIf
        Return 100
    EndIf
    Int now = StorageUtil.GetIntValue(akActor, "SLOVE_Resistance", 100) + hours * StorageUtil.GetIntValue(akActor, "SLOVE_RecoverPerHour", 0)
    If now > 100
        now = 100
    EndIf
    Return now
EndFunction
```

`SLOVE_RecoverPerHour` is written at each scene start from `pcrecoverperhour` / `npcrecoverperhour`. On a save that has not seen a scene since 0.7.2 it is missing, which reads as "no recovery until the next scene". This is what [SL Widgets](https://github.com/crajjjj/slwidgets) draws its willpower bar from.

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
