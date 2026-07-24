# `SLOVE.toml` — behaviour reference

**`Data\SKSE\Plugins\SLOVE\SLOVE.toml`** holds everything about *what SLO VE does*: which systems run, how often lines fire, how strong the faces are, how the SFX engine behaves, and how the willpower system is tuned.

It is read through AudioUtil's TomlUtil API with dotted keys (`voice.pcvolume`). Live reload:

```
cgf "SLOVE_Config.Reload"
```

!!! note "Fail-open"
    If the AudioUtil DLL is missing or too old, **every getter returns its default** — SLO VE degrades instead of erroring. That also means a typo'd key silently uses the default; check `AudioUtil.log` after an edit.

Values are integers unless noted. `1` / `0` are on / off; percentages are `0–100`.

## `[director]`

Master switches and scene detection.

| Key | Default | Meaning |
|---|---|---|
| `enablevoice` | `1` | Master switch for scene voices. |
| `enableexpressions` | `1` | Master switch for facial expressions. |
| `enablepcexpression` | `1` | Apply the expression effect to the player. |
| `enablemalenpcexpression` | `1` | Apply it to male NPCs. |
| `enablefemalenpcexpression` | `1` | Apply it to female NPCs. |
| `usephysicslabels` | `1` | Derive Slow/Fast intensity from SexLab P+ node-collision velocity, on top of the scene tags. Needs SLPP interactions. |
| `physicsfastvelocity` | `25.0` | *(float)* Absolute velocity at or above which a stage reads as **Fast**. |
| `physicsslowfactor` | `0.65` | *(float)* Hysteresis: drop back to Slow only below `physicsfastvelocity × this`. Stops rapid flapping between labels. |
| `soshugeppsize` | `6` | SOS/TNG size counted as "huge" — drives the huge-partner voice scenario, ahegao, and the resistance multiplier. |
| `printdebug` | `0` | Print director decisions to the console. |

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
| `moanonly` | `0` | `1` = moans only, no spoken lines. |
| `enablehugeppscenario` | `1` | Special line set when the partner is huge (needs SOS/TNG, threshold `director.soshugeppsize`). |
| `enablevictimscenario` | `1` | Special line set when she is the submissive/victim of the scene. |
| `femaleorgasmhypeenjoyment` | `75` | Enjoyment threshold above which orgasm hype lines start. |
| `maleorgasmhypeenjoyment` | `75` | Same, for the male. |
| `hypebeforeorgasm` | `0` | Extra hype pass before climax. |
| `voicevariation` | `"NA"` | *(string)* `"B"` selects the **VarB** alternate line variants where a pack provides them. |
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

### Volume

| Key | Default | Meaning |
|---|---|---|
| `pcvolume` | `100` | `0–100`, applied to the `pc_low`/`pc_high` audio groups. |
| `partnervolume` | `100` | `0–100`, applied to the `partner_low`/`partner_high` groups. |
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
| `fhutonguetype` | `7` | sr_fillherup tongue model `1–10`; `0` = random per actor. |
| `removetongueonblowjob` | `1` | Unequip the tongue during oral stages. |
| `cunusetongue` | `1` | Use the tongue during cunnilingus stages. |
| `enableahegao` | `1` | Huge partners trigger the ahegao face while penetrating (needs MFEE for the extended version). |
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
