# `SLOVE.toml` — behaviour reference

**`Data\SKSE\Plugins\SLOVE\SLOVE.toml`** holds everything about *what SLO VE does*: which systems run, how often lines fire, how strong the faces are, how the SFX engine behaves, and how the willpower system is tuned.

It is read through AudioUtil's TomlUtil API with dotted keys (`voice.pcvolume`). Live reload:

```
SLOVE_Config Reload
```

!!! note "Fail-open"
    If the AudioUtil DLL is missing or too old, **every getter returns its default** — SLO VE degrades instead of erroring. That also means a typo'd key silently uses the default; check `AudioUtil.log` after an edit.

Every key on this page can also be changed in game, through the optional [settings menu](menu.md).

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
| `usephysicslabels` | `1` | Derive Slow/Fast intensity from SexLab P+ contact speed, on top of the scene tags. Needs SLPP interactions (P+ 2.19+); on an older P+ the tags alone decide. |
| `physicsfastvelocity` | `18.0` | *(float)* Contact speed (world units per second) at or above which a stage reads as **Fast**. P+ 2.19 reports a short average rather than the peak 2.18 gave, so `18` is the old `25` re-based and **not yet calibrated in game**; `printdebug = 1` logs the live values as `Physics speed` lines to tune against. |
| `physicsslowfactor` | `0.65` | *(float)* Hysteresis: drop back to Slow only below `physicsfastvelocity × this`. Stops rapid flapping between labels. |
| `soshugeppsize` | `6` | SOS/TNG size counted as "huge" — drives the huge-partner voice scenario, ahegao, and the resistance multiplier. |
| `enablenpcscenes` | `1` | Process **NPC-only** SexLab scenes (no player) — see [NPC-only scenes](#npc-only-scenes) below. `0` = the pre-0.5.x behavior (player scenes only). |
| `npcscenedistance` | `2048.0` | *(float)* Max distance (game units, ≈ hearing range) from the player to adopt an NPC scene. |
| `maxnpcscenes` | `3` | Cap on concurrent NPC scenes processed at once (protects the Papyrus VM in busy areas). |
| `enablearmorswap` | `0` | **Player only.** Exchange the armors the player still wears at scene start for their scene versions, and put them back at scene end. See [Armor swap](#armor-swap) below. |
| `printdebug` | `0` | Log director decisions to `SLOVE.0.log`, **including the per-line voice trace**: category, facts, animation, stage, and the exact wav that played. See [Checking Your Pack](../packs/checking.md#watching-it-happen-in-game). |

### NPC-only scenes

With `enablenpcscenes = 1` (default), SexLab scenes the **player is not in** — two NPCs nearby, a brothel, an orgy mod — also get SLO VE's **ambient voice** (moans / breathing / reactions), **facial expressions**, **body SFX** and **willpower/resistance**. The player-only features stay player-only: the scripted dirty-talk voice engine, `[milk]`, on-screen willpower notifications, and the orgasm volume bus.

Adoption is deliberately bounded so a busy town can't flood the script engine:

- only scenes within **`npcscenedistance`** of the player,
- up to **`maxnpcscenes`** at once.

NPC scenes are adopted **even while you're in a scene of your own** — a follower or nearby couple starting a scene next to you gets voiced too (each scene is driven independently of yours).

Per-actor behavior reuses the existing toggles — `voice.voiceallactors`, `voice.malemoaning`, `voice.creaturebreathing`, `enablemalenpcexpression` / `enablefemalenpcexpression`, and the `[resistance]` NPC switches — there are no separate NPC-scene sub-switches. Works in both the P+ and classic script sets. NPC facial/SFX detail is coarser than a player scene (no velocity-driven physics overlay), which is plenty for background ambience.

### Armor swap

Ported from Hentairim. With `enablearmorswap = 1`, the **player** wears the scene version of an outfit for as long as a scene runs: a bikini top becomes its pulled-aside version, a skirt its lifted one, and at scene end the original is back on. Off by default. Works in both the P+ and classic script sets.

What is exchanged for what is a list in **`Data\SKSE\Plugins\StorageUtilData\SLOVE\ArmorSwapping.json`**:

```json
{
   "string": {
      "armorslots": "32,44,38,49,46,52,53,56,42,45"
   },
   "form": {
      "cosplay bikini - frill": "0xe74|[caenarvon] cosplay pack.esp",
      "school vibes top": "0x816|[baku]doaxvv school vibes.esp"
   }
}
```

- **`armorslots`** lists the biped slots that are looked at (32 is the body; the others are slots outfit mods use for underwear, stockings and accessories).
- Each line under **`form`** reads *the name of an armor you wear* : *the armor that replaces it*, written as `0x<form id>|<plugin file>`. The form id is the armor's id inside that plugin, without the load-order prefix: `0x000E74` and `0xe74` are the same.
- The left side is the armor's **name as your inventory shows it**; upper and lower case do not matter. A renamed or translated armor needs a line under the name you see.
- A line whose plugin is not installed is skipped, so one list can cover many outfit mods. The shipped list is Hentairim's, about 500 lines for popular outfit packs.

The file is in Hentairim's format: to keep a list you already maintain, copy your `HentairimDirector\ArmorSwapping.json` over it.

How it behaves:

- The swap runs **after SexLab has stripped**. An armor SexLab takes off is not there to be swapped, so leave the slots you want swapped unstripped in SexLab's strip options.
- The original armor stays in your inventory during the scene. One copy of the replacement is added for the scene and removed again afterwards; a copy you own yourself is not touched.
- A save made mid-scene is safe: the swap is remembered on the character, and the armor goes back on when that scene ends, or on loading if it ended meanwhile.
- The original goes back on by its base item. If you carry two of the same armor with different enchantments or tempering, the game picks which of the two is worn.
- Player only. An NPC re-equips an armor lying loose in their inventory, which would undo the swap.

!!! warning "Still running Hentairim?"
    Hentairim has the same feature (`enablearmorswap` in its Director config). Turn one of the two off, or each will swap what the other just put on.

!!! tip "Try a list without a scene"
    `slovetest armorswap` swaps what you are wearing right now and prints, per listed slot, the armor found there and what the file gives for it, or that it has no entry. Run it again to put everything back. It reads the file afresh from disk each time, so you can edit the list and try again without restarting the game. It works with `enablearmorswap = 0`. Needs ConsoleUtil Extended.

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
| `chanceformaletocomment` | `30` | Percent chance a male line fires when his turn comes up. |
| `voiceallactors` | `1` | `1` = **every** participant is voiced (male rotation + female NPC bystanders); `0` = only the PC and the lead partner. A **female** lead partner keeps her voice at `0` — she *is* the lead partner. |
| `npcdepthintense` | `6.0` | With **Accurate Penetration**: an NPC's *own* measured penetration depth at/above this plays her intense pools instead of tracking the scene-wide (PC-driven) intensity. PPA's working range is roughly 2 (shallow) – 10 (deep). `0` = off. |
| `npccommentchance` | `0.35` | `0–1`: fraction of NPC voice beats allowed to be full **spoken** lines (femdom / anal / DP / foreplay comments) rather than non-verbal sounds. A failed roll falls back to the grunt/breath, never silence. `0` = NPCs never speak, moans only. |
| `creaturebreathing` | `1` | Creature partners pant/growl through the scene (the `Breathing` category on `C*` slots). |
| `creaturebreathmininterval` | `3` | Seconds between creature breaths, minimum. **Halved on intense stages.** |
| `creaturebreathmaxinterval` | `8` | Seconds between creature breaths, maximum. **Halved on intense stages.** |
| `malemoaning` | `1` | Ambient male-partner moaning — the male mirror of `creaturebreathing`. Non-PC males moan on a cadence in **every** scene (between dirty-talk lines, and the only male sound under `moanonly`). Male packs are spoken-only, so this uses SexLab's stock male moans (`vMaleMoan01`–`04`, four distinct voices) via the `M0`–`M0D` slot fallback. Needs `enablemalevoice = 1`. |
| `malemoanmininterval` | `5` | Seconds between a male's moans, minimum. **Halved on intense stages.** |
| `malemoanmaxinterval` | `12` | …maximum. |

### Volume

| Key | Default | Meaning |
|---|---|---|
| `pcvolume` | `60` | `0` to `100`, applied to the `pc_low`/`pc_high` audio groups (moans + comments). |
| `orgasmvolume` | `70` | `0` to `100`, applied to the dedicated `pc_orgasm` group: the PC's climax/orgasm cries only. Independent of `pcvolume`, so you can raise or lower orgasm cries without touching ordinary moans/comments. (If the key is removed entirely it falls back to `pcvolume`.) |
| `partnervolume` | `60` | `0` to `100`, applied to the `partner_low`/`partner_high` groups: partners **in your own scene**. |
| `npcscenevolume` | `60` | `0` to `100`, applied to the dedicated `npc_low`/`npc_high` groups: **NPC-only scenes** (moans/breathing/reactions *and* their orgasm cries). Lets you make nearby NPC scenes quieter than your own without touching `partnervolume`. Falls back to `partnervolume` if the key is removed. AudioUtil's distance `voice_attenuation` still applies on top. |
| `printdebug` | `0` | Log the voice engine's own reasoning to `SLOVE.0.log`: the beat chosen for each cadence, and lines dropped (busy speaker, scene ended, game frozen behind a menu) with the reason. The played-file trace is `[director] printdebug`, above. |

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
| `enabletongue` | `1` | **P+ variant only.** The contact tongue, shown during cunnilingus and blowjobs. It needs SexLab P+'s oral contact detection; classic SexLab has none, so the classic variant never shows this tongue whatever the setting. Ahegao and its tongue are not affected. |
| `tonguetype` | `1` | HALO HDT tongue model `1–10`; `0` = random per actor. |
| `tonguetypekhajiit` | `-1` | The tongue model for Khajiit, who wear their own copies fitted to the muzzle: `-1` follows `tonguetype`, `0` = random per actor, `1` to `10` = that model. A named entry in `NPCTongue.json` still wins for that NPC. |
| `tonguetypeargonian` | `-1` | The same for Argonians. |
| `removetongueonblowjob` | `1` | Unequip the tongue during oral stages. |
| `cunusetongue` | `1` | Use the tongue during cunnilingus stages — and (P+) during **rimjob** scenes: in a scene tagged `rimjob`/`rimming`/`anilingus` the licker shows the tongue too (there is no collision signal for a rim lick, so this rides the scene tags; in mixed scenes only a female licker is inferred). |
| `enableahegao` | `1` | Huge partners trigger the ahegao face while penetrating (needs MFEE for the extended version). |
| `ahegaoitems` | `""` | Comma-separated `Plugin.esp\|FormID` (hex local id, `0x` optional; plugin names may contain spaces), up to 16. While an actor wears any listed item, SLO VE **pauses its own expression writes** for that actor — a second yield alongside the built-in SexLab Survival (`_SLS_AhegaoStateChange`) hook, for any mod that signals ahegao by equipping an item. Empty = off. |
| `ahegaostoragekeys` | `"TongueOn"` | Same yield, keyed on **StorageUtil int keys** instead of items: while any listed key reads `> 0` on an actor, expression writes pause. The robust way to detect a mod whose many tongue/face variants all set one key — the default catches the Artsick **Ahegao** mod (`AhegaoTongues.esp`), which sets `TongueOn` per actor while its tongue is on. Comma-separated key names, up to 16; harmless (reads `0`) when the mod isn't installed. Empty = off. |
| `chancetostickouttongueduringintense` | `30` | Percent roll per update, intense stages. |
| `chancetostickouttongueduringattacking` | `10` | Percent roll per update, attacking stages (givers incl. male partners, cowgirl riders). |
| `tonguemouthopenthreshold` | `0.4` | *(float)* **Jaw gate** - minimum measured mouth-open before a tongue is allowed to show, so it never clips through a closed mouth. The shape the mouth is *held* in while the tongue is out is not a TOML key - see the note below. |
| `tongueretractgraceseconds` | `2.0` | *(float)* **P+ variant only.** Seconds the tongue stays out after its trigger drops. Oral contact flickers as the head moves, and without the grace the tongue would pop in and out. Raise it to hold the tongue through longer gaps; `0` retracts at once. |
| `printdebug` | `0` | Print expression decisions. |

!!! note "Tongue open-mouth shape"
    While a tongue is out, SLO VE holds the mouth in the `tongueoutphonemeoverride` preset of the actor's expressions JSON (`PCExpressions.json` for the player, `MaleExpressions.json` / `FemaleExpressions.json` for NPCs, under `SKSE\Plugins\StorageUtilData\SLOVE\`). The first 16 comma-separated values are the MFG phonemes 0-15 (`Aah, BigAah, BMP, ChJSh, DST, Eee, Eh, FV, I, K, N, Oh, OohQ, R, Th, W`) as `0-100`; the rest of the line is ignored. Every **non-zero** channel is forced to its value for as long as the tongue shows, zero channels are left to the face. The default, `75,75,0,0,0,100,100,100,0,68,...`, is SexLab's own open mouth. Keep `BigAah` at `40` or above (or `Aah` at `60`+): below that SexLab P+ reads the mouth as closed and re-applies its own shape over yours, and the jaw gate retracts the tongue once the widest jaw channel drops under `tonguemouthopenthreshold`. A missing key falls back to the default shape.

!!! note "Khajiit and Argonians"
    A beast muzzle carries the mouth further forward and higher than a human face, so since 0.7.1 Khajiit and Argonians (and their vampire forms) wear their own copies of the ten tongues, moved to where their mouth is. The game picks the copy from the wearer's race. Which of the ten models they wear follows `tonguetype` unless you set `tonguetypekhajiit` / `tonguetypeargonian`. Up to 0.7.0 they wore the human fit, which came out through the underside of the jaw.

!!! tip "Adjusting the fit in BodySlide"
    Head shapes differ, so SLO VE ships BodySlide projects for its tongues (since 0.7.1). In BodySlide, type `SLOVE` into the outfit filter: there is one set per tongue model, **SLOVE Tongue 01** to **10**, in the group *SLOVE Tongues*, and the same ten for Khajiit, for Argonians and, with the UBE option, for UBE heads, each in a group of its own. The sliders move the tongue (**Forward / Back / Up / Down**, 3 game units at 100%), resize it (**Bigger / Smaller**, **Longer / Shorter**, **Wider / Narrower**, **Thicker / Thinner**, 30% at 100%) and **Tilt** it up or down (15 degrees at 100%). Set the sliders, save them as a preset, then *Batch Build* the group; build the model you actually use (`tonguetype`), or all ten.

    Three things to know. The built mesh has to **win over SLO VE's own file** in your mod manager, like any BodySlide output. An update of SLO VE that changes the tongue meshes needs a **rebuild**, or your older build keeps overriding it. And the sliders move the mesh but not its physics bones, so use them for a nudge of a unit or two; if BodySlide reports that a folder could not be created during a batch build, build once more.

    **Seeing the fit against a head.** BodySlide's own preview shows the tongue alone. To see it on a head, use Outfit Studio (the button at the bottom right of BodySlide):

    1. *File > Load Project...*, open `SliderSets\SLOVE Tongues.osp` (or `SLOVE Tongues UBE.osp`) and pick the set, for example *SLOVE Tongue 01*.
    2. *File > Import > From NIF...* and pick a head: `meshes\actors\character\character assets\femalehead.nif` for a human or mer, `femaleheadkhajiit.nif` / `femaleheadargonian.nif` in the same folder for the beast sets (the vanilla ones sit inside `Skyrim - Meshes0.bsa`, so extract them first unless a head replacer ships them loose), `meshes\!UBE\Head\FemaleHead_tangent.nif` for UBE, or your own character's head from RaceMenu (*Sculpt > Export Head*).
    3. Drag the tongue sliders in the panel on the right; the tongue moves against the head. Note the values.
    4. Close Outfit Studio **without saving** (saving would write the head into the project), set the same values in BodySlide and build. If you saved anyway, that set now contains the head and BodySlide would build it into the tongue mesh: reinstall SLO VE, which puts back `SliderSets\SLOVE Tongues.osp` and the set's file under `ShapeData\SLOVE Tongues`, and delete the `.osd` named after the set that Outfit Studio added to your BodySlide output.

    The head is shown with its mouth closed, and the game opens the mouth when a tongue is out, so judge against the lips and the chin. The tongue is drawn where the game will put it relative to the head, including the Khajiit and Argonian fit; a mouth or teeth mesh imported the same way lands on the floor, which is how those files are stored and can be ignored. A **head** that lands on the floor, far below the tongue, is a head file saved without its height (some replacers do this; the vanilla files carry it): select it in the mesh list and use *Shape > Move...* with Y `-1.55` and Z `120.34`, or import the vanilla head instead.

    The BodySlide projects that exist for the original tongues (*HALOS Human HDT Tongueslide*, and the one in Fill Her Up) build into another folder and do not reach SLO VE's copies.

!!! note "UBE bodies (custom races)"
    The tongue armors render only on the races listed in their Armor Addon, so on [UBE 2.0](https://www.nexusmods.com/skyrimspecialedition/mods/92989) custom-race actors the equipped tongue is **invisible** out of the box. The FOMOD's *UBE Body -> UBE tongue support* option fixes that with race-specific tongues: it installs ten UBE-fitted meshes (`meshes\!UBE\SLOVE\tongues`) and `SLOVE_UBE_Support.esp`, an ESL patch that gives each of the 10 tongue armors a second Armor Addon listing only the 18 UBE races. The game picks the addon from the wearer's race, so a UBE actor wears the UBE-fitted tongue and everyone else the standard one, with no setting involved. Requires `UBE_AllRace.esp`; load the patch after it and after `SLOVE.esp`. Up to 0.6.27 the same option only made the standard meshes visible on UBE heads.

!!! tip "Lowering script load"
    The four `*expressionupdateinseconds` values and `breathingupdateinseconds` are the expression engine's whole cost. Raising them to e.g. `3.0` / `1.0` noticeably cuts Papyrus work at the price of coarser faces.

## `[sfx]`

The body-SFX engine (`SLOVE_SFX`). Sound names resolve as categories of the [`SFX0` slot](../packs/slots.md#the-sfx-slot-sfx0); audio ships under `Sound\fx\SloveSFX`.

| Key | Default | Meaning |
|---|---|---|
| `enable` | `1` | Master switch — applies the SFX effect to scene actors. |
| `volume` | `60` | `0–100`, startup level for the `sfx` audio group. |
| `usevelocity` | `1` | The switch for thrust sounds timed from measured motion. With Accurate Penetration connected they follow its depth (`useppathrust`). Otherwise they are thrust-paced by SLPP contact speed instead of fixed pacing (P+ 2.19+; on an older P+ this reads as `0` and the scene labels pace the sounds). The sound **rate** follows the animation, including AnimSpeed overrides; the exact moment of impact is not known, so on a slow stage a clap can land between two visible impacts. |
| `thruststroke` | `16.0` | *(float)* World units one full thrust (in + out) travels. A beat fires each time the contact has travelled this far. Lower = more beats per thrust. An estimate, **not yet calibrated in game**; `printdebug = 1` logs each beat as a `Thrust beat` line with the speed it saw. |
| `useppathrust` | `1` | Time the thrust sounds off **Accurate Penetration** when its bridge measures the scene: the clap lands as the measured depth turns at its deepest, and on non-intense stages a slush marks the re-entry. Works on every SexLab build (P+ of any version, and classic), outranks the pacing above, and needs `usevelocity = 1`. Where PPA reports no depth for 1.5 s the stage falls back to the build's own pacing. PPA plays thrust sounds of its own: see [Hentairim & PPA](../hentairim-and-ppa.md#thrust-sounds) for hearing one set only. |
| `ppathrustturn` | `1.0` | *(float)* How far the depth must come back from its extreme to count as the thrust turning around (PPA depth runs roughly 2 to 10). Lower = reacts sooner but can clap on jitter; higher = ignores shallow strokes. An estimate, **not yet calibrated in game**; `printdebug = 1` logs each `PPA thrust: impact` line with its stroke. |
| `useadaptivevelocity` | `0` | SOSBend **calibration search** when a scene reports no velocity data. |
| `timestosearch` | `0` | Max calibration attempts per stage. `0` = never search. |
| `usecontactsfx` | `1` | One-shots on contact edges: insertion, pull-out gape, kiss, oral. The insertion, kiss and oral one-shots need SexLab P+ 2.19+. On an older P+ and on classic there is no contact data, so only what the labels can stand in for remains: the pull-out gape, and the forced-insertion trauma of `[resistance]`. |
| `usecontactvictimreactions` | `1` | Suppress tender kiss cues when a victim is involved. |
| `velocitypoll` | `0.1` | *(float)* Seconds between speed samples for the thrust pacing. A coarser step adds jitter to each beat. |
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
| `pcmaxresistance` | `600` | PC drain denominator. **Higher = slower drain.** NPCs use `ResistanceRaceBase.json` instead. |
| `pcnonvictimmult` | `60` | Percent multiplier — PC, willing. |
| `npcnonvictimmult` | `30` | …NPC, willing. |
| `pcvictimmult` | `120` | …PC, victim/submissive (drains faster). |
| `npcvictimmult` | `130` | …NPC, victim/submissive. |
| `hugeppmult` | `200` | Extra multiplier when the PC's partner is huge. |
| `pcrecoverperhour` | `10` | Percent of willpower regained per game-hour without sex (PC). |
| `npcrecoverperhour` | `5` | …NPC. |
| `pcbrokenpoints` | `60` | Game-hours-to-recover set when the PC breaks. |
| `npcbrokenpoints` | `40` | …NPC. |
| `victiminsertiontrauma` | `5` | Extra willpower hit when a submissive is forcibly entered. `0` = off. |
| `pcnotifyinterval` | `25` | **PC only.** *"Your resolve weakens…"* notification each time the player's willpower **drains** down through this percent band (e.g. `75`/`50`/`25`), once per band per scene. Draining only — recovery is announced by `scenestartnotification`. `0` = off. |
| `scenestartnotification` | `1` | **PC only.** Announce break status: *"You are still broken (N hours to recover)"* at scene start while a break persists, and *"You have recovered your composure"* when it ends (since 0.7.3 at the moment its hours have passed). `0` = off. |
| `brokenblockenjkeys` | `1` | **PC only, P+ variant only.** While the PC is broken, SexLab P+'s enjoyment-game hotkeys are disabled (and the *"game required on high enjoyment"* gate is lifted so she can still reach orgasm). The P+ MCM toggles are saved and restored at scene end — or on the next game load after a crash. `0` = off. |
| `brokenpartnerenjmult` | `10` | **P+ variant only.** While an actor is broken, every scene partner's enjoyment grows this percent faster (P+ enjoyment engine; effective in player scenes). `0` = off. |

## `[milk]`

Optional nipple squirts during scenes via **Oninus Lactis NG** (player only, driven by the Director). Stays off unless the mod is present.

| Key | Default | Meaning |
|---|---|---|
| `enable` | `1` | Master switch. Does nothing unless Oninus Lactis NG is installed. |
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
