# `SLOVE.toml` — behaviour reference

**`Data\SKSE\Plugins\SLOVE\SLOVE.toml`** holds everything about *what SLO VE does*: which systems run, how often lines fire, how strong the faces are, how the SFX engine behaves, and how the willpower system is tuned.

It is read through AudioUtil's TomlUtil API with dotted keys (`voice.pcvolume`). Live reload:

```
SLOVE_Config Reload
```

!!! note "Fail-open"
    If the AudioUtil DLL is missing or too old, **every getter returns its default** — SLO VE degrades instead of erroring. That also means a typo'd key silently uses the default; check `AudioUtil.log` after an edit.

Values are integers unless noted. `1` / `0` are on / off; percentages are `0–100`.

## `[director]`

Master switches and scene detection.

| Key | Default | Meaning |
|---|---|---|
| `enablevoice` | `1` | Master switch for scene voices. |
| `suppresssexlabvoice` | `1` | Silence SexLab's own moan engine for every actor in a player scene, so AudioUtil is the sole voice source (no doubled moans). Auto-restores when the scene ends. Set `0` to let SexLab moan alongside SLO VE. Only acts while `enablevoice = 1`. |
| `enableexpressions` | `1` | Master switch for facial expressions. |
| `enablepcexpression` | `1` | Apply the expression effect to the player. |
| `enablemalenpcexpression` | `1` | Apply it to male NPCs. |
| `enablefemalenpcexpression` | `1` | Apply it to female NPCs. |
| `usephysicslabels` | `1` | Derive Slow/Fast intensity from SexLab P+ node-collision velocity, on top of the scene tags. Needs SLPP interactions. |
| `physicsfastvelocity` | `25.0` | *(float)* Absolute velocity at or above which a stage reads as **Fast**. |
| `physicsslowfactor` | `0.65` | *(float)* Hysteresis: drop back to Slow only below `physicsfastvelocity × this`. Stops rapid flapping between labels. |
| `soshugeppsize` | `6` | SOS/TNG size counted as "huge" — drives the huge-partner voice scenario, ahegao, and the resistance multiplier. |
| `enablenpcscenes` | `1` | Process **NPC-only** SexLab scenes (no player) — see [NPC-only scenes](#npc-only-scenes) below. `0` = the pre-0.5.x behavior (player scenes only). |
| `npcscenedistance` | `2048.0` | *(float)* Max distance (game units, ≈ hearing range) from the player to adopt an NPC scene. |
| `maxnpcscenes` | `3` | Cap on concurrent NPC scenes processed at once (protects the Papyrus VM in busy areas). |
| `printdebug` | `0` | Print director decisions to the console. |

### NPC-only scenes

With `enablenpcscenes = 1` (default), SexLab scenes the **player is not in** — two NPCs nearby, a brothel, an orgy mod — also get SLO VE's **ambient voice** (moans / breathing / reactions), **facial expressions**, **body SFX** and **willpower/resistance**. The player-only features stay player-only: the scripted dirty-talk voice engine, `[milk]`, on-screen willpower notifications, and the orgasm volume bus.

Adoption is deliberately bounded so a busy town can't flood the script engine:

- only scenes within **`npcscenedistance`** of the player,
- up to **`maxnpcscenes`** at once.

NPC scenes are adopted **even while you're in a scene of your own** — a follower or nearby couple starting a scene next to you gets voiced too (each scene is driven independently of yours).

Per-actor behavior reuses the existing toggles — `voice.voiceallactors`, `voice.malemoaning`, `voice.creaturebreathing`, `enablemalenpcexpression` / `enablefemalenpcexpression`, and the `[resistance]` NPC switches — there are no separate NPC-scene sub-switches. Works in both the P+ and classic script sets. NPC facial/SFX detail is coarser than a player scene (no velocity-driven physics overlay), which is plenty for background ambience.

## `[voice]`

The voice dispatcher. All `chance*` keys are **percent rolls (0–100)** evaluated when the relevant moment comes up.

### Line frequency

| Key | Default | Meaning |
|---|---|---|
| `chancetocommentonleadinstage` | `8` | Chance to speak during lead-in stages. |
| `chancetocommentonnonintensestage` | `22` | …during a soft stage. |
| `chancetocommentonintensestage` | `25` | …during an intense stage. |
| `chancetocommentononattackingstage` | `22` | …during an "on the attack" stage. |
| `chancetocommentonblowjobstage` | `15` | …during oral. |
| `chancetocommentwhenclosetoorgasm` | `45` | …when she is close to orgasm. |
| `chancetocommentwhenmaleclosetoorgasm` | `40` | …when he is close to orgasm. |
| `chancetocommentunamused` | `15` | Chance of an unamused/bored line where one applies. |

Raise these for a chattier scene, lower them for mostly-moaning. `moanonly = 1` is the blunt version.

### Scenarios & content

| Key | Default | Meaning |
|---|---|---|
| `moanonly` | `0` | `1` = moans only, no spoken lines. Males then moan via `malemoaning` (SexLab stock male moans through the `M0`–`M0D` fallback) instead of dirty-talk. |
| `enablehugeppscenario` | `1` | Special line set when the partner is huge (needs SOS/TNG, threshold `director.soshugeppsize`). |
| `enablevictimscenario` | `1` | Special line set when she is the submissive/victim of the scene. |
| `femaleorgasmhypeenjoyment` | `75` | Enjoyment threshold above which orgasm-hype / near-orgasm lines (`NearOrgasm*`, B `Orgasm Soon Comments`) start. As a fallback for setups where SLSO never feeds the enjoyment meter (it reads `0`), these lines **also** start from an authored HentaiRim intense tag on the climax (final) stage — so the near-orgasm pool is reachable even at enjoyment `0`. Run `slovetest anim` mid-scene to see the live `enjoy=` value per actor. |
| `maleorgasmhypeenjoyment` | `75` | Same, for the male (same intense-tag climax fallback). |
| `intenseenjoyment` | `50` | PC enjoyment at/above which voices switch to the intense (hot) set — mirrors SLSO's own `sl_hot_voice_strength`, so high enjoyment sounds intense even on a soft-tagged stage. With `intense_from_bar_only = 1` (the default) this bar is the **sole** intensity trigger, so keep it reachable within a scene. Overlaid on the authored intense-stage tag and refreshed every update tick, so rising enjoyment flips the scene intense **mid-stage**, not only at a stage change. `0` = off (authored tags only). **Both P+ and classic** honor it. Requires SLSO to feed the enjoyment meter — without it the value stays `0` and only the stage tag drives intensity. Run `slovetest anim` mid-scene to see the live `enjoy=` value. |
| `intense_from_bar_only` | `1` | How the "intense" state is decided. `1` (default): **SLSO-style bar-only** — the enjoyment bar **alone** decides intensity, so `NearOrgasmNoises` plays only at/above `intenseenjoyment`, and for no other reason (the granular meter control SLSO always gave). `0`: intense when **either** the bar crosses `intenseenjoyment` **or** the stage is authored fast/intense (HentaiRim `1F` label) — the pre-0.6.3 behavior; use it if your enjoyment bar never climbs (e.g. no SLSO meter feeding it), otherwise most animations read as intense from their motion tags. **Both P+ and classic.** Only affects **voice** — facial expressions stay tag-driven. |
| ~~`hypebeforeorgasm`~~ | `0` | **Deprecated — ignored.** Held climax back for an extra hype pass, but it disabled the SexLab orgasm with no release path, freezing **SLSO**'s meter at 100%. Now always ignored; leave at `0`. |
| ~~`voicevariation`~~ | — | **Removed.** Variation A/B is now a per-pack property — set `variation = "B"` on the pack's `[[slot]]` in its AudioUtil config (see `SLOVE_zpack_*.toml`). |
| `useblowjobsoundforkissing` | `1` | Reuse blowjob action audio for kissing stages. |
| `enableddgagvoice` | `1` | Route a gagged speaker through the muffled [gag slot](../packs/slots.md#the-gag-slot-f1gag). |

### Who speaks

| Key | Default | Meaning |
|---|---|---|
| `enablemalevoice` | `1` | Males speak at all. |
| `chanceformaletocomment` | `20` | Percent chance a male line fires when his turn comes up. |
| `voiceallactors` | `1` | `1` = **every** male in the scene speaks, rotating; `0` = lead male only. |
| `creaturebreathing` | `1` | Creature partners pant/growl through the scene (the `Breathing` category on `C*` slots). |
| `creaturebreathmininterval` | `5` | Seconds between creature breaths, minimum. **Halved on intense stages.** |
| `creaturebreathmaxinterval` | `12` | …maximum. |
| `malemoaning` | `1` | Ambient male-partner moaning — the male mirror of `creaturebreathing`. Non-PC males moan on a cadence in **every** scene (between dirty-talk lines, and the only male sound under `moanonly`). Male packs are spoken-only, so this uses SexLab's stock male moans (`vMaleMoan01`–`04`, four distinct voices) via the `M0`–`M0D` slot fallback. Needs `enablemalevoice = 1`. |
| `malemoanmininterval` | `5` | Seconds between a male's moans, minimum. **Halved on intense stages.** |
| `malemoanmaxinterval` | `12` | …maximum. |

### Volume

| Key | Default | Meaning |
|---|---|---|
| `pcvolume` | `100` | `0–100`, applied to the `pc_low`/`pc_high` audio groups (moans + comments). |
| `orgasmvolume` | `100` | `0–100`, applied to the dedicated `pc_orgasm` group — the PC's climax/orgasm cries only. Independent of `pcvolume`, so you can raise or lower orgasm cries without touching ordinary moans/comments. (If the key is removed entirely it falls back to `pcvolume`.) |
| `partnervolume` | `100` | `0–100`, applied to the `partner_low`/`partner_high` groups — partners **in your own scene**. |
| `npcscenevolume` | `100` | `0–100`, applied to the dedicated `npc_low`/`npc_high` groups — **NPC-only scenes** (moans/breathing/reactions *and* their orgasm cries). Lets you make nearby NPC scenes quieter than your own without touching `partnervolume`. Falls back to `partnervolume` if the key is removed. AudioUtil's distance `voice_attenuation` still applies on top. |
| `printdebug` | `0` | Print each voice decision (category, slot, handle) to the console. |

## `[expressions]`

Facial expression engine. All face writes go through Mfg Fix NG.

| Key | Default | Meaning |
|---|---|---|
| `enablebreathing` | `1` | Cheap "breathing" micro-pass between the main expression updates. |
| `breathingupdateinseconds` | `0.55` | *(float)* Breathing pass interval. |
| `pcnonintenseexpressionupdateinseconds` | `2.1` | *(float)* PC face refresh on soft stages. |
| `pcintenseexpressionupdateinseconds` | `1.6` | *(float)* PC face refresh on intense stages. |
| `npcnonintenseexpressionupdateinseconds` | `2.1` | *(float)* NPC face refresh, soft. |
| `npcintenseexpressionupdateinseconds` | `1.6` | *(float)* NPC face refresh, intense. |
| `enabletongue` | `1` | sr_fillherup tongue armors. |
| `tonguetype` | `1` | HALO HDT tongue model `1–10`; `0` = random per actor. |
| `removetongueonblowjob` | `1` | Unequip the tongue during oral stages. |
| `cunusetongue` | `1` | Use the tongue during cunnilingus stages. |
| `enableahegao` | `1` | Huge partners trigger the ahegao face while penetrating (needs MFEE for the extended version). |
| `ahegaoitems` | `""` | Comma-separated `Plugin.esp\|FormID` (hex local id, `0x` optional; plugin names may contain spaces), up to 16. While an actor wears any listed item, SLO VE **pauses its own expression writes** for that actor — a second yield alongside the built-in SexLab Survival (`_SLS_AhegaoStateChange`) hook, for any mod that signals ahegao by equipping an item. Empty = off. |
| `ahegaostoragekeys` | `"TongueOn"` | Same yield, keyed on **StorageUtil int keys** instead of items: while any listed key reads `> 0` on an actor, expression writes pause. The robust way to detect a mod whose many tongue/face variants all set one key — the default catches the Artsick **Ahegao** mod (`AhegaoTongues.esp`), which sets `TongueOn` per actor while its tongue is on. Comma-separated key names, up to 16; harmless (reads `0`) when the mod isn't installed. Empty = off. |
| `chancetostickouttongueduringintense` | `30` | Percent roll per update, intense stages. |
| `chancetostickouttongueduringattacking` | `30` | Percent roll per update, attacking stages. |
| `tonguemouthopenthreshold` | `0.4` | *(float)* **Jaw gate** — minimum measured mouth-open before a tongue is allowed to show, so it never clips through a closed mouth. |
| `printdebug` | `0` | Print expression decisions. |

!!! tip "Lowering script load"
    The four `*expressionupdateinseconds` values and `breathingupdateinseconds` are the expression engine's whole cost. Raising them to e.g. `3.0` / `1.0` noticeably cuts Papyrus work at the price of coarser faces.

## `[sfx]`

The body-SFX engine (`SLOVE_SFX`). Sound names resolve as categories of the [`SFX0` slot](../packs/slots.md#the-sfx-slot-sfx0); audio ships under `Sound\fx\SloveSFX`.

| Key | Default | Meaning |
|---|---|---|
| `enable` | `1` | Master switch — applies the SFX effect to scene actors. |
| `volume` | `60` | `0–100`, startup level for the `sfx` audio group. |
| `usevelocity` | `1` | Thrust-synced sounds driven by SLPP collision velocity instead of fixed pacing. |
| `useadaptivevelocity` | `0` | SOSBend **calibration search** when a scene reports no velocity data. |
| `timestosearch` | `0` | Max calibration attempts per stage. `0` = never search. |
| `usecontactsfx` | `1` | One-shots on contact edges: insertion, pull-out gape, kiss, oral. |
| `usecontactvictimreactions` | `1` | Suppress tender kiss cues when a victim is involved. |
| `velocitypoll` | `0.1` | *(float)* Seconds between velocity samples. Must stay tight to catch thrust reversals. |
| `normalpoll` | `0.5` | *(float)* Seconds between label/tag-driven passes. Raise to cut script load — clip length already paces playback. |
| `gapevaginalaverage` | `2.0` | *(float)* Measured-gape threshold for the average vaginal gape one-shot. |
| `gapevaginalhuge` | `2.7` | *(float)* …huge. |
| `gapeanalaverage` | `2.8` | *(float)* …average anal. |
| `gapeanalhuge` | `4.0` | *(float)* …huge anal. |
| `printdebug` | `0` | Print SFX decisions, including the measured opening value at pull-out. |

!!! danger "`useadaptivevelocity` is the heaviest path in the mod"
    The calibration search spams `Debug.SendAnimationEvent(SOSBend)` with 0.3 s waits, hunting for a bend that yields velocity data. It is **off by default** and needs *both* `useadaptivevelocity = 1` **and** `timestosearch > 0`. Only enable it if a scene otherwise reports no velocity at all.

!!! note "Calibrating gape thresholds"
    The opening values from the Accurate Penetration bridge are **unitless magic numbers** — `0.0` is closed, there is no defined scale. Set `printdebug = 1`, watch the pull-out line in your own scenes, and set the four thresholds from what you actually see.

## `[resistance]`

The optional willpower/break system. Full explanation of the mechanic: [Willpower / Resistance](../resistance.md).

| Key | Default | Meaning |
|---|---|---|
| `enable` | `1` | Master switch for the whole system. |
| `enablepc` | `1` | The player loses willpower. |
| `enablemalenpc` | `1` | Male NPCs do. |
| `enablefemalenpc` | `1` | Female NPCs do. |
| `enablecreaturenpc` | `1` | Creatures do. |
| `enablebrokenstatus` | `1` | Play broken/begging voice lines while broken. `0` = keep the broken **face** but not the broken voice. |
| `pcmaxresistance` | `1000` | PC drain denominator. **Higher = slower drain.** NPCs use `ResistanceRaceBase.json` instead. |
| `pcnonvictimmult` | `20` | Percent multiplier — PC, willing. |
| `npcnonvictimmult` | `30` | …NPC, willing. |
| `pcvictimmult` | `110` | …PC, victim/submissive (drains faster). |
| `npcvictimmult` | `130` | …NPC, victim/submissive. |
| `hugeppmult` | `200` | Extra multiplier when the PC's partner is huge. |
| `pcrecoverperhour` | `10` | Percent of willpower regained per game-hour without sex (PC). |
| `npcrecoverperhour` | `5` | …NPC. |
| `pcbrokenpoints` | `60` | Game-hours-to-recover set when the PC breaks. |
| `npcbrokenpoints` | `40` | …NPC. |
| `victiminsertiontrauma` | `5` | Extra willpower hit when a submissive is forcibly entered. `0` = off. |
| `pcnotifyinterval` | `25` | **PC only.** *"Your resolve weakens…"* notification each time the player's willpower **drains** down through this percent band (e.g. `75`/`50`/`25`), once per band per scene. Draining only — recovery is announced by `scenestartnotification`. `0` = off. |
| `scenestartnotification` | `1` | **PC only.** At scene start, announce break status: *"You have recovered your composure"* when a break has cleared, or *"You are still broken (N hours to recover)"* while it persists. `0` = off. |

## `[milk]`

Optional nipple squirts during scenes via **Oninus Lactis NG** (player only, driven by the Director). Stays off unless the mod is present.

| Key | Default | Meaning |
|---|---|---|
| `enable` | `0` | Master switch (and Oninus Lactis NG must be installed). |
| `chanceonorgasm` | `50` | Percent roll on any orgasm in the scene — always the intense squirt. |
| `chanceintense` | `20` | Percent per roll while penetrated on an intense stage. |
| `chancenonintense` | `8` | …on a soft stage. |
| `rollinterval` | `10` | Seconds between penetration rolls. |
| `mintime` | `4` | Squirt duration lower bound, seconds. |
| `maxtime` | `10` | Upper bound (the engine caps at 18). |
| `levelintense` | `2` | Oninus Lactis squirt level `0–2`, intense. |
| `levelnonintense` | `1` | …soft. |
| `requirebarechest` | `1` | Skip while body slot 32 is covered. |
| `mmeminfullness` | `20` | **Milk Mod Economy only:** skip at or below this % fullness. With MME installed, squirts require milk in the reserve and drain it (20–50 % of current, scaled by level and duration). |

!!! tip "Test squirts without waiting for a scene"
    `slovetest milk` (or `SLOVE_Test Milk`) forces one squirt on the player so you can
    tune `levelnonintense` / `levelintense` on the spot — add `1` for the intense level
    (`slovetest milk 1`). It honours every real gate and reports which one would block a
    live scene: `enable` off, Oninus Lactis missing, the bare-chest gate, or (with MME
    managing the player) `mmeminfullness`. Needs ConsoleUtil Extended; the squirt
    self-stops after `mintime`–`maxtime` seconds. Note the squirt **level** comes only
    from `levelintense` / `levelnonintense` — MME fullness gates and drains, it never
    scales the level.
