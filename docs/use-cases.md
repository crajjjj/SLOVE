# SLO VE — use-case regression checklist

The **major use cases** SLO VE promises, written as concrete scenarios to walk
**on every release** to catch regressions. Modelled on Being Female NG's
tester scenario list: one row per user-facing capability, each with a setup, a
trigger, the expected in-game result, and the **evidence** that proves it.

This is the *functional* companion to [`smoke-test.md`](smoke-test.md):

| Doc | Question it answers | When |
|---|---|---|
| [`smoke-test.md`](smoke-test.md) | "Did this **change** compile and stay within the architecture?" (build gate, API sync, firewall grep, TOML parse, asset paths) | after any big edit |
| **this file** | "Does every **feature** SLO VE ships still work?" | before tagging a release |

Run `smoke-test.md` §1–§8 first — a release regression pass assumes the build
is green. Then work this list.

## How an AI verifies these

Most rows split into two kinds of evidence:

- **Static / log evidence (AI-checkable).** Config keys, `SLOVE_Test` probe
  output, and log lines the AI can read or ask the user to paste. Grep, TOML
  parse, `housecarl_bsa_list`, and the two logs cover a surprising amount.
- **Audio / visual confirmation (user-only).** Whether a moan *sounds* right or
  a face *looks* like ahegao can only be judged by a human in a live scene. The
  AI's job is to hand the user the exact scene setup and the one line of console
  output that says the code path fired, then collect a yes/no.

**Debug setup for a regression pass** (revert afterwards):

```toml
# SLOVE.toml
[director]     printdebug = 1
[voice]        printdebug = 1
[sfx]          printdebug = 1
[expressions]  printdebug = 1
```

```toml
# AudioUtil.toml
[general]      log_level = "debug"
```

Logs to watch: `Documents\My Games\Skyrim Special Edition\SKSE\AudioUtil.log`
(all audio: slot/category resolution, parse errors) and
`…\Logs\Script\User\SLOVE.0.log` (script/dependency errors). Console diagnostics
(`SLOVE_Test …`, `au reload`) need **ConsoleUtil Extended**. The settings-menu
plugin writes a third, short one: `…\SKSE\SLOVE.log` (section G).

**Baseline scenes to have ready** (most rows reuse these):
- **H-scene** — PC female + one male human NPC.
- **Creature scene** — PC + a dog/husky.
- **Group scene** — PC + two+ human males (participant rotation, overlap).
- **Female-partner scene** — PC + a female NPC partner (FFM, or a male PC + a female NPC) for female-NPC voicing (A14).

---

## A. Voices

| # | Use case | Setup / trigger | Expected | Evidence |
|---|---|---|---|---|
| A1 | **PC female voice + lipsync** | H-scene, `voice.enablevoice=1` | PC moans through stages; lines change with intensity; **mouth moves in time** | `AudioUtil.log` shows `F1`/`F0` slot resolved + category→folder; `voice.printdebug` prints category per line. Lipsync = **visual (user)** |
| A2 | **Female out-of-the-box (no pack)** | Fresh install, no `Sound\fx\SLOVE\F1` pack | PC still moans — falls back to SexLab's stock `F0`/`F0B` moan sets; no silence | `AudioUtil.log`: `Slot F1: 0 category folders … falls back`; audible = user. `SLOVE_Test SampleCategory F0 Moan` → `handle>0` |
| A3 | **Female pack drop-in upgrade** | Drop a Hentairim/IVDT pack into `Sound\fx\SLOVE\F1\<Category>`, `au reload` | New pack plays; any category the pack lacks backfills from stock moans | `AudioUtil.log`: `Slot F1: N category folders scanned`; `SLOVE_Test AuditVoicePack F1` reports high `n/72`, few `MISSING`, and (AudioUtil 0.9.4+) a **non-zero in-pack count** — `0 in-pack` = the pack never actually plays, everything is stock backfill |
| A4 | **Every participant voiced (no lead-only)** | Group scene | Each male rotates his **own** lines; PC + partners all speak. `voice.voiceallactors=0` = only the PC + lead partner speak (silences secondary males **and** female NPC bystanders — the female **partner** still speaks: she *is* the lead partner) | `voice.printdebug` shows `PickSpeakingMale` cycling different actors; each male resolves own `M*` slot in `AudioUtil.log` |
| A5 | **Consistent per-NPC voice** | Same NPC across two scenes | NPC keeps the same voice slot both times | `AudioUtil.log` slot resolution identical for that formid across scenes |
| A6 | **No same-speaker overlap** | Group scene, dense lines | A speaker never talks over himself; a new line cuts the previous on his channel | Voice `PlaySound` carries a `slove_pc`/`slove_np<formid>` channel (grep). Overlap = user's ear |
| A7 | **Male voice packs** | H-scene, male partner | Male comments in a bundled `M1..M8` voice | `SLOVE_Test SampleCategory M1 <cat>` → `handle>0`; log resolves `M*` |
| A8 | **Creature voices from vanilla BSA** | Creature scene | Dog/husky pants/whines on its **own** timing (~3–8 s, halved when intense); **no human lines**; climax whine replaces a running breath | Console: `scene creatures voiced: 1`; `AudioUtil.log` resolves `C*` slot. Note: creature audio is **BSA-packed → no lipsync** (expected). `SLOVE_Test SampleCategory C7 Orgasm` / `C7 Breathing` → `handle>0`. Cadence knobs: `voice.creaturebreathmininterval`/`maxinterval` (default 3/8) |
| A9 | **Orgasm reactions** | Any scene through to climax | Orgasm hype lines for **both** sexes; distinct from mid-scene moans. The **Came-In remarks** (`CameInMouth` / `CameInPussy` / `CameInAss`, VarB `Ending Orgasmed Inside *`) play only when the partner's climax landed **in her** - she was sucking him, or he was inside her - and only for a partner with a cock (man, male creature, schlonged futa). A woman climaxing on a futa lead, or a partner the lead was penetrating, draws **no** Came-In line (the hole is snapshotted at the climax by `CameInHole`, not re-read from the moved-on labels) | `SLOVE_Orgasm` event + `voice.printdebug` orgasm category; a Came-In line in `AudioUtil_Voices.log` carries `theirs` + `giv oral` or `rcv vaginal`/`rcv anal`; audible = user |
| A10 | **Huge-partner scenario (SOS/TNG)** | Scene with a huge-schlong partner | Huge-partner voice variants + broken/ahegao face | `IsHugePP` true in debug; `voice.printdebug` shows the `VarB`/huge variant |
| A11 | **Victim / submissive scenario** | Scene where PC or NPC is the submissive receiver | Victim-flavoured lines | `IsSubmissive` true in debug; victim category in `voice.printdebug` |
| A12 | **Gagged voice + lip handoff** | Speaker wearing a Devious Devices gag | Voice switches to the **muffled gag pool**; lip movement hands to the device (line plays with `blockLipSync`) | `AudioUtil.log` routes through the slot's `gag_slot`; gag detected via `[gag]` markers — a worn **keyword** (whole device family) **or** a specific worn **item** form (`[gag].items`, AudioUtil 0.9.3+). Muffle = user |
| A13 | **Per-voice volume + ducking** | Set `voice.pcvolume` / `voice.partnervolume`; scene | PC vs partner relative loudness follows config; groups duck as designed | Grep the four groups `pc_low/pc_high/partner_low/partner_high` in play calls; relative volume = user |
| A14 | **Female NPC partner voiced** | Scene with a non-PC female partner (F/F, FFM, or a male PC + female NPC) | The female **partner** (the lead's opposite number) voices **her own side of the act** on her `F2–F10` pool slot and channel: kissing sounds while kissing, muffled mouth sounds when her mouth is full (lead labels or her own PPA site), penetration grunts only when she is actually penetrated, heightened breathing while the lead's mouth is on her, breathing otherwise — same act derivation as her tag facts, so folder and facts agree. With **Accurate Penetration** the beat deepens per actor: her *own* depth picks soft vs intense (`voice.npcdepthintense`), her *own* site routes anal (`Penetrated Anal Comments Intense`) and DP (`Penetrated Double Comments`), and PPA's per-receiver classification adds spoken femdom (`Penetrated Comments Femdom`, `Foreplay Femdom Comments`) and boob/hand/foot foreplay comments — all spoken beats behind `voice.npccommentchance`, falling back to grunts/breathing on a failed roll. When SexLab flags **her** the submissive — or PPA classifies her interaction Aggressive — her grunts come from the pack's `Penetrated Grunt Victim` folders (gated by `voice.enablevictimscenario`, falling back to the plain grunt when a pack omits them). A female **bystander** (third+ woman) grunts when PPA measures *her* penetrated, or — with no PPA answer — when the scene has a male/creature to do it (same composition rule as NPC scenes), using the `Victim` grunt folders if SexLab flags her submissive; an all-female scene gets act-neutral breathing instead — the labels never described her, so the old always-grunts behavior was a guess (the "only penetrated grunts" reports). Both stay female even in a male-PC scene; silent if the necro/unconscious target (A17) | Console: `scene females voiced (NPC): N`; `voice.printdebug` shows `PlayFemalePartnerComments` / `PickSpeakingFemale` / `forceFemaleVoice`; her `F*` slot resolves in `AudioUtil.log`. Bystanders gated by `voice.voiceallactors`; the partner is not (she is the lead partner). Audible = user |
| A15 | **Variation A/B pack dispatch** | Install a Variation-**B** pack in F1 (its slot declares `variation="B"`) vs a Variation-**A** pack (no `variation`) | A B pack routes each beat to its **partitioned** folder (victim / broken / femdom / over-the-top); an A pack uses the collapsed set. Decided by the **lead female's (PC's)** resolved slot | `AudioUtil.GetSlotVariation` returns `B`/`A` (AudioUtil 0.9.3+, API v2); `voice.printdebug` shows `VoiceVariation` + the `VarB` category / partition-folder name |
| A16 | **In-pack Variation-B fallback** | A B pack that omits an intense/partition variant folder | The missing variant plays the pack's **own base** line (resolved in-pack) **before** dropping to stock SexLab moans | `AudioUtil.CategoryExists` gate visible in `voice.printdebug`; `AudioUtil.log` resolves the pack's base folder, not `F0`/`F0B` |
| A17 | **Necro / faint / unconscious target silenced** | Scene tagged `necro` / `faint` / `sleep` / `unconscious` | The passive **target** makes **no voice and no lipsync** — the line is *skipped*, not ducked, so AudioUtil never drives the mouth; the dead face (closed eyes / slack jaw) applies to the **victim only**. The **aggressor** speaks and emotes normally. Works for an NPC target of either sex | `voice.printdebug`: `Voice + lipsync suppressed (unconscious target)`; aggressor's lines still logged; face = user |
| A18 | **Cunnilingus `Licking*` pools** | Cunnilingus scene (`CUN` label on the licker), pack with `Licking` / `Licking Intense` / `Licking Comments` / `Licking Forced` folders | The licker plays her pack's own licking pools, mirroring the blowjob split: forced scene/victim → `Licking Forced`; comment chance (`voice.chancetocommentonblowjobstage`, stage > 1, not broken) → `Licking Comments` (spoken — **lipsyncs**); intense → `Licking Intense`; else `Licking`. The three action pools play with **no lipsync** (`[lipsync] block_categories` — the mouth is busy). Intense licking **while also penetrated** still yields to the penetration branches. Missing folders degrade in-pack (alias to the closest `Blowjob*`/`Licking` folder), then to the A/stock analog — pre-Licking behavior. Male-routed (male PC / male-only) degrades to stock male moans | `voice.printdebug`: `Play Cunnilingus` + `(folder Licking …)` vs the degrade folder; `SLOVE_Test AuditVoicePack F1` includes all four (79 female / 64 B categories); audible = user |
| A19 | **Rimjob `Rimjob*` pools + rim voice routing** | Scene tagged `rimjob` / `rimming` / `anilingus` (e.g. Billyy's rimjob sets) with the PC as the licker; or an explicitly authored per-actor `RIM` oral code | The PC voices her pack's `Rimjob*` pools with the same forced/comments/intense/soft split as `Licking*` (comments reuse the blowjob comment chance). Trigger is authored data only — no collision signal exists for a rim lick — so in a rim-tagged scene a mouth-busy oral label (`CUN`, or the converted DB's `KIS` stand-in) routes to `PlayRimjob` instead of kissing/licking; `RIM` wins outright. The three action pools play with **no lipsync** (`[lipsync] block_categories`); `Rimjob Comments` lipsyncs. Missing folders degrade to the pack's `Licking*` pools, then the A/stock analogs; male-routed degrades to stock male moans. Both variants (P+ + classic) | `voice.printdebug`: `Play Rimjob` + `(folder Rimjob …)` vs the degrade folder; `SLOVE_Test AuditVoicePack F1` covers all four (79 female / 64 B categories); audible = user |
| A20 | **Femdom is per actor, not per scene** | A `Femdom`-tagged scene, or the lead (futa / strapon) penetrating her partner; clearest with a woman or futa partner | The lead's `mood` fact is `dom` only when **she** leads the dominant-female scene: a `Femdom` tag with a **male** partner, her riding (`IsCowgirl`), or her inside a partner who is not riding her. When the partner rides her (his own SLSB cowgirl code), or a woman/futa is inside her under a `Femdom` tag while she is not riding, she reads **`sub`** and the partner **`dom`**; a partner SexLab flags submissive keeps her `dom` regardless. The same test gates the `Foreplay Femdom Comments` / `Male Orgasm Soon Femdom` / `Male Orgasmed Inside Femdom` beats. In a non-penetrative stage (licking, hands, kissing, lead-in) under a `Femdom` tag with a woman/futa partner, slot order decides in one direction: the partner in position A and the lead cast elsewhere (SexLab put her in the male role) reads the tag as the partner's, so she is `sub`. Limit: an untagged (physics-only) scene carries no rider code and keeps the old `dom` | `AudioUtil_Voices.log` facts column (`voice_log = player`): `sub` on her lines while ridden, no `dom` with `rcv cock ... futa` in a `Femdom` scene; `slovetest anim` shows the tags and both actors' labels |
| A21 | **No penis labels on a woman** | A woman or futa-less lead licked, fingered or foot-played by another woman (P+ physics on, `usephysicslabels = 1`), or an SLSB stage that tags her with a penis act | P+ raises `pOral` / `pHandJob` / `pFootJob` for a *genital*, not a penis, so a licked, fingered or foot-played woman carries them and the overlay used to give her `SMF`/`SHJ`/`SFJ`: blowjob categories and `rcv strapon oral` / `rcv feet strapon` facts. The Director now drops those flags on a position without a penis (`HasPenis`), the four `IsGetting*` predicates ignore a penis label on a lead with no schlong and no framework strap-on, and the implement fact is `cock`, `strapon` only when SexLab says `IsUsingStrapon`, else absent | `AudioUtil_Voices.log`: no `strapon` on a lead who wears none, no `rcv ... oral` while she is the one licked; `slovetest anim` shows `CUN` on the licker and no `MF`/`HJ`/`FJ` on her |
| A22 | **Measured hole needs two readings to beat the tag** | An anal-tagged stage with P+ physics or PPA reporting the vagina for one sample (the two nodes sit close) | The penetration label and the `place` fact used to flip to `vaginal` for one pass, and the cum/penetration beats dispatched on the label while the fact came from PPA, so a `Male Orgasm Soon Ask For Vaginal Cum` line carried an `anal` fact. The overlay and `PPAPlace` now require the same contradicting hole on two consecutive reads, and `CurrentPenetrationLvl` takes its hole from `PPAPlace` like the facts do | The log's category and `place` fact always agree; a single-sample flicker no longer shows; a PPA redirect-menu switch lands on the next line, not the first |

## B. Facial expressions

| # | Use case | Setup / trigger | Expected | Evidence |
|---|---|---|---|---|
| B1 | **Live breathing + stage faces** | H-scene, `director.enableexpressions=1`, Mfg Fix NG installed | Face breathes subtly, intensifies by stage | `expressions.printdebug` phase; face = **user visual** |
| B2 | **Per-class gates** | Toggle `enablepcexpression` / `enablemalenpcexpression` / `enablefemalenpcexpression` | Only enabled classes get face writes | `DumpState` prints the gates; behaviour = user |
| B3 | **Tongue-out (sr_fillherup) + jaw-gate** | sr_fillherup installed, high intensity | Tongue armor equips **only when the mouth is actually open** (jaw-gate) | equip event in debug; tongue-vs-jaw = user visual |
| B4 | **Ahegao on huge partner** | Huge-partner scene | Ahegao face while huge/broken | B10 marker set; face = user |
| B5 | **MFEE ahegao/tongue (Erin/Elin + vanilla)** | MFEE installed | MFEE ahegao path drives the face | `NPCTongue.json`/MFEE config loaded; face = user |
| B6 | **Mask respected** | Actor wearing a face-covering mask (`Masks.json`) | Expression writes skipped for the masked actor | mask detected in debug; face unchanged = user |
| B7 | **External-ahegao yield** | Equip an `expressions.ahegaoitems` item **or** set an `expressions.ahegaostoragekeys` int `>0` (default `TongueOn`, e.g. Artsick Ahegao `AhegaoTongues.esp`) | SLO VE **pauses** its face writes for that actor while active; other mod owns the face | `expressions.printdebug` shows the yield; do **not** list sr_fillherup forms here (SLO VE equips those itself) |
| B8 | **SLS ahegao yield** | SexLab Survival, arousal ≥ ahegao threshold (`_SLS_AhegaoStateChange`) | Face + moan-lipsync yield to the SLS face; **moans stay audible** (played `blockLipSync=true` so they don't lipsync over it) | Director sets `SLOVE_FaceOwnsMouth_SLS`; moans audible = user |
| B9 | **SLS ahegao survives reload** | Trigger SLS ahegao, save, reload mid-ahegao | Face-owns-mouth state re-adopts; no lipsync fighting the SLS face | Director `Maintenance()` re-seeds `SLOVE_FaceOwnsMouth_SLS` from `_SLS_IsAhegaoing`; user confirms no jitter |
| B10 | **Climax face owns the mouth** | Any scene to orgasm | Orgasm/broken face holds the mouth; the orgasm line plays **without** lipsync (no mouth fighting the open-mouth face) | `SLOVE_FaceOwnsMouth_Expr` marker set via `ApplyFaceMouthOwnership`; `Orgasm` also in `[lipsync] block_categories`; user confirms no twitch |
| B11 | **Cunnilingus detection + contact tongue (P+)** | P+ cunnilingus scene (female oral target), `enabletongue=1` | SexLab's detector reports mouth↔vaginal-opening contact as `aOral` → the `CUN` oral label, and the licker gets a contact tongue. Sensitivity is tuned in **`SexLab.ini`** (`[Interaction]` `fDistanceMouth`, `fAngleCunnilingus`) - not from SLO VE; see [Tuning Cunnilingus Detection](cunnilingus-detection.md) | Needs P+ 2.19+ and a body with the `VaginaDeep1` / `NPC L Pussy02` / `NPC R Pussy02` nodes. `CUN` appears in the physics-label debug (`director.printdebug`); tongue = user visual. (The `director.cunnilingusdistance/angle` TOML keys are inert - the `sslSystemConfig` path they used never worked.) |
| B12 | **Tongue preload, no NPC redress (P+)** | `expressions`/`NPCTongue.json enablenpctongue=1`, start a scene | The `SLOVE_ThreadHook` **blocking** thread hook preloads all ten tongue armors in SexLab's guaranteed **pre-strip** window, so an add-triggered NPC outfit re-dress is undone by the strip; the async `DirectorSceneStarting` remains a fallback | `SLOVE.0.log`: `SLOVE_ThreadHook` registers at load; `PreloadTongueArmors: … items_added=N` fires **before** the strip; NPC stays undressed = user visual |
| B13 | **Rimjob contact tongue (P+)** | P+ scene tagged `rimjob` / `rimming` / `anilingus`, `enabletongue=1`, `cunusetongue=1` | The licker shows the contact tongue during the rim act. No collision signal exists for a rim lick, so the trigger is authored data: an explicit `RIM` oral code (any actor), or — in a rim-tagged scene — a female actor whose oral label is the converted DB's `KIS` stand-in (female-only heuristic: in mixed rim content the receiver carries the same `KIS`, and Billyy's MF rim scenes always have a female licker). Retracts on the usual grace/jaw-gate rules; a `RIM`-labelled mouth uses the licking mouth preset when no tongue is out (both variants) | `expressions.printdebug`: `SceneTagRimScene=True` on scene start + the tongue decision dump; tongue = user visual |
| B14 | **UBE race tongue (P+)** | FOMOD *UBE tongue support* installed, `UBE_AllRace.esp` loaded; one UBE-race actor and one vanilla-race actor in tongue scenes | The UBE actor shows the **UBE-fitted** tongue (`meshes\!UBE\SLOVE\tongues`), the vanilla-race actor the standard one, from the same ten armors: each tongue armor carries a standard addon and a UBE-only addon and the game picks by race. Exactly **one** tongue per mouth, also with the *UBE Armor Race Patcher* DLL installed (it adds the UBE races to the standard addon as well; the UBE addon outranks it) | Static: `SLOVE_UBE_Support.esp` holds 10 `ARMO` overrides + 10 new `ARMA` and no `SLOVE_TongueAA*` override; `build.ps1` fails if a named mesh is not staged. Tongue seated in the mouth, single, both races = user visual |
| B16 | **Tongue fit in BodySlide** | BodySlide installed; filter `SLOVE`, pick *SLOVE Tongue 01*, set *Tongue Forward* and *Tongue Up*, save a preset, Batch Build the group *SLOVE Tongues* (and the Khajiit / Argonian / UBE groups) | The built `meshes\SLOVE\tongues\linga*.nif` (and `khajiit\`, `argonian\`, `!UBE\...`) show the tongue moved by the slider amounts in game, still single, still on slot 44 with physics. With every slider at 0 the build equals the shipped mesh | Static: `python tools\tonguefit\make_bodyslide.py --check` (the projects hold the current meshes). Verified once outside the game by a headless BodySlide 5.7.1 batch build of all 40 sets: every vertex moved by exactly the preset, structure, slot, bones, binds and physics references unchanged. In Outfit Studio (Load Project, then Import > From NIF a head) the tongue sits at the mouth of a human, Khajiit, Argonian or UBE head for the matching set and follows the sliders = user. Look in game and that the output wins over SLO VE's file = user |
| B15 | **Beast race tongue (P+)** | A Khajiit and an Argonian actor in tongue scenes; once with the defaults, once with `tonguetypekhajiit` / `tonguetypeargonian` set to a model other than `tonguetype`, once with `tonguetype = 0` (random) | The tongue comes out of the **mouth** of the muzzle, not through the underside of the jaw, and is single. Each tongue armor carries a Khajiit and an Argonian addon (the two races plus their vampire forms) whose meshes are the standard ten moved forward and up; the standard addon no longer lists those four races | Static: `python tools\tonguefit\fit_tongues.py --check` (the shipped copies are what the offsets produce, every vertex moved by the same amount); `build.ps1` fails if `SLOVE.esp` names a tongue mesh that is missing. `expressions.printdebug`: `AddTongue: Equipping` names the armor (`...813` to `...81C` = model 1 to 10), which follows the per-race key when it is 0 or more, and with random each actor keeps one armor while its effect lives (a save loaded mid-scene restarts the effects and may roll an NPC another model; never two tongues at once). Placement on the muzzle = user visual; the offsets are measured from the vanilla mouth meshes, not tuned in game |

## C. Body SFX

| # | Use case | Setup / trigger | Expected | Evidence |
|---|---|---|---|---|
| C1 | **Core body SFX** | `sfx.enable=1`, `sfx.volume>0`, any scene | Slushing / impact / clap / kissing / blowjob sounds play with the action | `sfx.printdebug` names each SFX; `SLOVE_Test` SFX probe; audible = user |
| C2 | **Thrust-paced (P+ 2.19+ only)** | SexLab **P+**, `sfx.usevelocity=1` | Slush/impact **rate** follows the contact speed (one beat per `sfx.thruststroke` of travel, AnimSpeed overrides included); not phase-locked to the impact; a stage with no speed data plays no thrust sounds (known gap - `sfx.usevelocity=0` paces from labels) | `sfx.printdebug` logs each `Thrust beat` with the speed it saw; **classic build must NOT** attempt this (see [SexLab Flavours](sexlab-flavours.md)) |
| C3 | **Successive-slush replacement** | Dense thrusting | A new slush **replaces** the running one, no pile-up | Each SFX carries a channel (`sfx_main_/sfx_slush_/…<position>`) — grep; overlap = user |
| C4 | **Contact one-shots** | Insertion, pull-out, kiss, oral edges | Insertion thunk, **PPA-measured** pull-out gape, kiss, oral one-shots fire on the contact edge | `sfx.printdebug` contact/edge line; gape needs the PPA bridge (see D1) |
| C5 | **Size-matched ejaculation one-shot** | Male orgasm | One ejaculation SFX at climax, matched to size | `sfx.printdebug` ejac on `SLOVE_Orgasm`; channel `sfx_ejac_<pos>` |
| C6 | **All SFX stop at scene end** | End the scene | Every SFX stream and pending one-shot stops | no lingering SFX in `sfx.printdebug`; silence = user |
| C7 | **Thrust sounds timed off PPA depth** | Accurate Penetration installed (bridge connected), `sfx.usevelocity=1`, `sfx.useppathrust=1`, any SexLab build, a penetration stage | The clap and slush land as the measured depth turns at its deepest; a re-entry slush on non-intense stages; this outranks C2's pacing; a stage where PPA reports no depth for 1.5 s falls back to the build's own pacing | `sfx.printdebug`: `Running PPA thrust SFX on <receiver>`, then one `PPA thrust: impact` line per thrust with its stroke; timing against the animation = user. With PPA's own `[SoundEffects]` on, two sets play (expected, see [Hentairim & PPA](hentairim-and-ppa.md#thrust-sounds)) |

## D. Integrations (soft dependencies)

| # | Use case | Setup / trigger | Expected | Evidence |
|---|---|---|---|---|
| D1 | **Measured penetration (Accurate Penetration / AudioUtilPPA)** | Accurate Penetration installed, scene | Expression & SFX penetration checks use **measured** context+depth (ctx 1=vaginal/2=anal + depth>0) instead of authored labels | `AudioUtilPPA.IsConnected` true; `AudioUtil.log` PPA connect line; depth in `printdebug` |
| D2 | **Graceful without soft deps** | Uninstall MFEE / sr_fillherup / PPA / SLS | No errors; features tied to the missing mod simply don't fire | `SLOVE.0.log` free of unresolved-dependency spam |
| D3 | **Fail-open without AudioUtil** | AudioUtil DLL absent | SLO VE loads; every `SLOVE_Config` getter returns its default; nothing plays; **no crash** | `SKSE\AudioUtil.log` absent + one fail-open warning in `SLOVE.0.log`; game stable = user |
| D4 | **Classic SexLab build** | Install via FOMOD **classic** option (SexLab SE 1.63 + SLSO) | Voices/expressions/gape/insertion work; **thrust-sync is P+-only and stays off**; **the contact tongue is P+-only too** — classic has no oral-contact detector, so `AddTongue` + the tongue preload are gated off (no tongue armor added on any actor, no NPC redress), **ahegao unaffected** | correct script set shipped (`dist-classic`); `SLOVE_ThreadHook` there is the inert `ReferenceAlias` stub; `SLOVE.0.log` clean; see [SexLab Flavours](sexlab-flavours.md) |
| D5 | **External mute events** | In a scene: `slovetest mute stage`, `slovetest mute scene 1`, `slovetest unmute scene`, `slovetest mutes` (crosshair actor, else the player); or a mod sending `SLOVE_Mute_Stage` / `SLOVE_Mute_Scene` | The muted actor goes quiet at once (the line in progress is cut) while everyone else keeps talking; a stage mute ends about 2 seconds into the next stage unless it is sent again, a scene mute with the scene, each unmute ends its own early; with face `1` the actor's expression stops updating and is not reset at scene end; nobody stays muted into the next scene or across a reload; SexLab's own moans do not come back after an unmute | `SLOVE.0.log` has one `Mute :` line per event with actor, caller and thread; `slovetest mutes` lists what is written and whether it is in force; `director.printdebug`: `Voice + lipsync suppressed (muted by '...')` / `Voice line dropped (muted by '...')`; silence and face = user |
| D6 | **SexLab P+ older than 2.19 (2.17 / 2.18)** | P+ build of SLO VE on SexLab P+ 2.18.1, any scene | Voices, expressions and label-paced SFX run from the stage tags, like the classic build: no physics labels, no thrust-paced SFX, no insertion / kiss / oral one-shots; the tongue is timed by the stage tags alone; pull-out gape and insertion trauma come from the labels; **no** `GetInteractionFlags` / `method not found` errors in `Papyrus.0.log` | [smoke test §3a](smoke-test.md) (gate audit + stubbed compile against the 2.18.1 headers); one `has no contact-detection API` line per load in `SLOVE.0.log`; `slovetest dump` prints `contact detection (SexLab P+ 2.19+)=false`; error-free Papyrus log = user |

## E. Gameplay — willpower / resistance (optional)

| # | Use case | Setup / trigger | Expected | Evidence |
|---|---|---|---|---|
| E1 | **Willpower drains under penetration** | `resistance.enable=1`, sustained penetration | Willpower falls with the **rise in enjoyment** × race/victim/huge multipliers | `director.printdebug` logs the per-tick drain; `SLOVE_Test DumpState` |
| E2 | **Break → broken voice + face** | Drain willpower to ≤0 | Actor **breaks**: broken/begging voice lines + broken/ahegao face; willpower frozen at 0 | `IsBroken` true via Director; `brokenface` term; lines/face = user |
| E3 | **Broken-status voice gate** | `resistance.enablebrokenstatus=0` | Broken **face** stays; broken **voice** does not | `ASLIsBroken` gated off; user confirms |
| E4 | **Mid-scene reload doesn't reset drain** | Drain partway, save, reload | Willpower **persists**; no re-recovery, no wipe | `SLOVE_LastSexTime` re-stamped at scene start; `DumpState` shows same willpower |
| E5 | **Disable drops broken state** | `resistance.enable=0` + `SLOVE_Config Reload` | Broken state cleared; drain stops | `DumpState` shows resistance off |
| E6 | **Victim insertion trauma** | Forced insertion onto a submissive receiver | Extra willpower hit via `SLOVE_ResDebt`, drained by that actor's Resistance | `sfx`/`resistance` debug shows `SLOVE_ResDebt` write + drain |
| E7 | **Broken PC loses the enjoyment keys** (P+ only) | P+ MCM "Enjoyment Game" on, `brokenblockenjkeys=1`, break the PC (also with "game required on high enjoyment" on) | Raise/holdback keys go dead the moment she breaks; enjoyment still climbs past 80 to orgasm (no stall); other scene hotkeys unaffected; both MCM toggles read ON again after the scene (or after the next load if the game crashed mid-block) | `printdebug` "enjoyment-game hotkeys disabled/restored"; `SLOVE_EnjGameBlocked`/`SLOVE_EnjHighReqBlocked` markers cleared post-scene; keys = user |
| E8 | **Partners enjoy a broken actor more** (P+ only) | `brokenpartnerenjmult>0`, scene with a broken actor (or break one mid-scene) | Every partner's enjoyment grows `brokenpartnerenjmult`% faster while the broken actor is in the scene; bonus is removed at scene end | `printdebug` "partners gain +N% enjoyment rate"; `slovetest anim` enjoyment dump climbs faster (raise the key to `100` to make it obvious in testing) |
| E9 | **Willpower readable between scenes** | `slovetest willpower 40` outside a scene, wait a few game hours (or `set timescale to 2000` for a moment); with SL Widgets 2.2.6+ its willpower bar is the display | The projected value (stored willpower + whole game hours since the time stamp x `SLOVE_RecoverPerHour`, a break all-or-nothing) climbs by `pcrecoverperhour` per game hour and matches what the next scene starts from; during a scene it equals the stored value | `slovetest willpower` prints the keys it wrote; the formula in [For Mod Authors](authors/integration.md#willpower-between-scenes) is the one `CalculateStartupResistance` applies; the bar = user |

## F. Robustness & lifecycle

| # | Use case | Setup / trigger | Expected | Evidence |
|---|---|---|---|---|
| F1 | **Mid-scene save/load re-adoption** | Save mid-scene, reload | Scene re-adopts within ~3 s; voices/faces/SFX resume; **no orphaned spells** | `director.printdebug` re-adopt line; no duplicate ME in `DumpState` |
| F2 | **Clean scene end** | End any scene | Voices stop, face returns to neutral, SFX stop, SexLab's own moans restore. A climax cry already playing **rings out briefly** on the `*_high` groups before stopping (not clipped — the orgasm line isn't cut the instant the scene ends) | `director.suppresssexlabvoice` self-restores; `DirectorEndScene` stops `*_low`/`sfx`/`oneshot` immediately, `RemoveTracker` rings out `*_high`; silence+neutral = user |
| F3 | **Live TOML reload** | Edit `SLOVE.toml` + `SLOVE_female.toml`, run `SLOVE_Config Reload` + `au reload` | New values take effect **without** a game restart | reload lines in both logs; changed behaviour = user |
| F4 | **SexLab voice/expression suppression** | Any SLO VE scene | No doubled voices; no face jitter (SLO VE silences SexLab's own moans per-scene) | `director.suppresssexlabvoice=1`; single voice = user |
| F5 | **Log hygiene** | After a full multi-scene session | `AudioUtil.log` free of `no slot resolvable` / `unknown slot` / `no readable PCM wav` spam; `SLOVE.0.log` free of errors | grep both logs |

## G. In-game settings menu (SKSE Menu Framework, optional)

`SLOVE.dll` + `SLOVE_Menu.toml`. The file writer and the schema are tested at
build time (`core-tests`, `check-config.ps1`); what only the game can show is
below. The plugin's log is `SKSE\SLOVE.log`.

| # | Use case | Setup / trigger | Expected | Evidence |
|---|---|---|---|---|
| G1 | **Inert without the framework** | Disable SKSE Menu Framework, start the game, run a scene | No error dialog at start; the scene behaves as before | `SLOVE.log`: `Menu disabled: SKSE Menu Framework is not installed`; scene = user |
| G2 | **Pages appear** | Framework enabled, open the Mod Control Panel (F1) | Section **SLO VE** with six pages (Director, Voice, Expressions, SFX, Resistance, Milk); grouped rows; a tooltip with the text, a `Default:` line and the key name | `SLOVE.log`: `117 settings on 6 page(s). Schema: loaded. Defaults: loaded.` and `Menu registered`; layout and wrapping = user |
| G3 | **A change is saved and reaches the scripts** | Untick *Scene voices*, drag *Player voice*, close the menu | Exactly those two lines of `SLOVE.toml` change, comments and neighbours untouched; one write per slider release | file diff; a new `Parsed ...SLOVE.toml` line in `AudioUtil.log` per write; `slovetest dump` prints the new `enablevoice` / `pcvolume` |
| G4 | **Volumes apply at once** | Mid-scene, drag *Player voice* (Voice) and *Volume* (SFX) | Loudness follows while the slider is held, without a new scene | user |
| G5 | **Reset** | Change three settings on one page; press **reset** on one, then **Reset this page to defaults** and confirm | Defaults are back, and the file equals the shipped one again byte for byte | compare `SLOVE.toml` with `SLOVE.defaults.toml` minus its 3-line note; user |
| G6 | **Typed values and text** | Type a number into a number field; edit *Yield on StorageUtil keys*; once leave the field, once close the menu while still typing | Saved in both cases | file; user |
| G7 | **A hand edit is seen** | Game running: change `SLOVE.toml` in an editor, reopen the menu | The page shows the edited value, and it applies at the next scene with no console reload | `SLOVE.log`: `changed on disk`; user |
| G8 | **A broken file is never overwritten** | Break the file's syntax by hand, reopen the menu | A red message names the problem, no settings are shown, nothing is written. Fix the file, **Reload from disk**: the pages return | file unchanged; user |
| G9 | **Variant hints** | Classic SexLab profile, or P+ older than 2.19 | The P+-only (or 2.19-only) settings are dimmed, the tooltip says why, and they can still be changed | `SLOVE.log` `SexLab:` line; user |
| G10 | **Survives a load** | Change a value, load a save without quitting | The new value is live in the loaded game | `slovetest dump` |
| G11 | **NPC-only scenes follow the menu** | No scene of your own running: untick *Process NPC-only scenes*, let NPCs start a scene nearby; tick it again, next NPC scene | Ignored while off, adopted again when on, with no game load or player scene in between | `director.printdebug`: `Adopting NPC scene` present / absent |
| G12 | **A setting missing from the file** | Delete one key line from `SLOVE.toml`, reopen the menu | The row is marked *not in your file*; **add** writes it back under its section | file; user |

---

## Release regression report template

Fill one row per use case touched by the release (or the whole matrix for a
major version). Split verdicts into what the AI checked vs. what the user must
still confirm.

```
Release: SLO VE <version>  (P+ build / classic build)
Build gate (smoke-test.md §1–§8): PASS / FAIL — <notes>

Use case | AI evidence checked        | User in-game confirm | Verdict
A1 PC voice+lipsync | log: F1 resolved, cat logged | mouth moves: ?  | PENDING
A8 creature voices  | creatures voiced: 1          | pant/whine/climax: ? | PENDING
E2 break            | IsBroken=true                | broken lines/face: ? | PENDING
...

Regressions found: <file:line / log evidence>
Handoff to user:   <numbered in-game steps, debug toggles on>
```

**Rule:** do not call a release "verified" on static evidence alone. Every row
whose expected result is audio or visual (marked *user* above) needs a human
yes in a live scene, or an explicit waiver from the user.
