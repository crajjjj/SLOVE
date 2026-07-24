# Willpower / Resistance

The **one gameplay system** SLO VE carries over from Hentairim. Everything else in the mod is presentation; this one changes behaviour. It is fully tunable and can be switched off entirely with `resistance.enable = 0`.

## The mechanic

Every scene participant holds a **willpower** value from `0` to `100`.

- While an actor is **being penetrated**, willpower drains by the **rise in their SexLab enjoyment**, multiplied by situational modifiers.
- At `0` the actor **breaks**: their voice switches to broken/begging lines and their face to the broken/ahegao look for the rest of the break.
- Breaking sets **broken points** — the number of game-hours without sex needed to recover.
- Between scenes, willpower regenerates lazily over game time.

Penetration is measured by the **Accurate Penetration bridge** when it is tracking the actor (context bit set *and* depth > 0), and falls back to SexLab position labels otherwise (Scene Builder on P+, SLATE tags on classic).

## The drain formula

Each tick (3–5 s while penetrated):

```
drain = (rise in enjoyment)
      ÷ denominator            (pcmaxresistance for the PC, the race table for NPCs)
      × victim/willing multiplier
      × huge-partner multiplier (PC only)
      × race modifiers
```

| Situation | Key | Ships |
|---|---|---|
| PC, willing | `pcnonvictimmult` | `20` |
| NPC, willing | `npcnonvictimmult` | `30` |
| PC, victim/submissive | `pcvictimmult` | `110` |
| NPC, victim/submissive | `npcvictimmult` | `130` |
| PC's partner is huge (SOS/TNG ≥ `director.soshugeppsize`) | `hugeppmult` | `200` |

`pcmaxresistance` (`1000`) is the PC's denominator — **higher means slower drain**. It is the single knob to turn if the whole system feels too fast or too slow for the player.

**Forced insertion trauma:** when a submissive receiver is forcibly entered, the SFX engine deposits an extra hit of `victiminsertiontrauma` (`5`) willpower, drained on the actor's next ticks. Set it to `0` to disable.

## Breaking and recovery

| Key | Ships | Meaning |
|---|---|---|
| `pcbrokenpoints` | `60` | Game-hours of no sex needed for the PC to recover from a break |
| `npcbrokenpoints` | `40` | …for an NPC |
| `pcrecoverperhour` | `10` | % of willpower regained per game-hour without sex (PC) |
| `npcrecoverperhour` | `5` | …NPC |

While broken, willpower is **frozen at 0** — it can't creep back up mid-break. Recovery is computed lazily on scene entry from the actor's last-sex timestamp, and the timestamp is re-stamped at scene start so a **mid-scene reload doesn't re-recover or wipe the drain**.

## What breaking changes

| Effect | Gate |
|---|---|
| **Voice** switches to broken/begging line selection | `enablebrokenstatus = 1` |
| **Face** shifts toward the broken/ahegao look | always (while `resistance.enable = 1`) |

Set `enablebrokenstatus = 0` to keep the broken *face* but not the broken *voice*.

## Who participates

| Key | Ships |
|---|---|
| `enablepc` | `1` |
| `enablemalenpc` | `1` |
| `enablefemalenpc` | `1` |
| `enablecreaturenpc` | `1` |

Each toggles whether that class of actor gets the resistance effect at all.

## The race tables

Two PapyrusUtil JSON files under `Data\SKSE\Plugins\StorageUtilData\SLOVE\`:

| File | Role |
|---|---|
| `ResistanceRaceBase.json` | Per-race **denominator** for NPCs — the equivalent of `pcmaxresistance`. A higher number means that race resists longer. |
| `ResistanceRacePCModifier.json` | Per-race modifier applied to the **PC's** drain based on her *partner's* race. |

Edit them to make, say, Nords stubborn and Bosmer fragile, or to make a particular creature partner especially damaging to the player.

## State storage

Per-actor state lives in StorageUtil, so it survives saves and is readable by other mods:

| Key | Type | Meaning |
|---|---|---|
| `SLOVE_Resistance` | int | Current willpower, `0–100` (defaults to `100`) |
| `SLOVE_BrokenPoints` | int | Game-hours-to-recover remaining, `0–127`. `> 0` = broken |
| `SLOVE_ResDebt` | float | Pending forced-insertion trauma, drained on the next ticks |
| `SLOVE_LastSexTime` | float | Game time of the last scene, used for lazy recovery |

Reading them from another mod: [For Mod Authors](authors/integration.md#storageutil-state).

## Turning it off

```toml
[resistance]
enable = 0
```

That's it — no spell is applied, nothing ticks, and voices/faces behave as if the actor were never broken.

Every key with its default: [`SLOVE.toml [resistance]`](config/slove.md#resistance).
