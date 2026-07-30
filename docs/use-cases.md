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
(`SLOVE_Test …`, `au reload`) need **ConsoleUtil Extended**.

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
| A3 | **Female pack drop-in upgrade** | Drop a Hentairim/IVDT pack into `Sound\fx\SLOVE\F1\<Category>`, `au reload` | New pack plays; any category the pack lacks backfills from stock moans | `AudioUtil.log`: `Slot F1: N category folders scanned`; `SLOVE_Test AuditVoicePack F1` reports high `n/71`, few `MISSING`, and (AudioUtil 0.9.4+) a **non-zero in-pack count** — `0 in-pack` = the pack never actually plays, everything is stock backfill |
| A4 | **Every participant voiced (no lead-only)** | Group scene | Each male rotates his **own** lines; PC + partners all speak. `voice.voiceallactors=0` = only the PC + lead partner speak (silences secondary males **and** female NPCs) | `voice.printdebug` shows `PickSpeakingMale` cycling different actors; each male resolves own `M*` slot in `AudioUtil.log` |
| A5 | **Consistent per-NPC voice** | Same NPC across two scenes | NPC keeps the same voice slot both times | `AudioUtil.log` slot resolution identical for that formid across scenes |
| A6 | **No same-speaker overlap** | Group scene, dense lines | A speaker never talks over himself; a new line cuts the previous on his channel | Voice `PlaySound` carries a `slove_pc`/`slove_np<formid>` channel (grep). Overlap = user's ear |
| A7 | **Male voice packs** | H-scene, male partner | Male comments in a bundled `M1..M8` voice | `SLOVE_Test SampleCategory M1 <cat>` → `handle>0`; log resolves `M*` |
| A8 | **Creature voices from vanilla BSA** | Creature scene | Dog/husky pants/whines on its **own** timing (~3–8 s, halved when intense); **no human lines**; climax whine replaces a running breath | Console: `scene creatures voiced: 1`; `AudioUtil.log` resolves `C*` slot. Note: creature audio is **BSA-packed → no lipsync** (expected). `SLOVE_Test SampleCategory C7 Orgasm` / `C7 Breathing` → `handle>0`. Cadence knobs: `voice.creaturebreathmininterval`/`maxinterval` (default 3/8) |
| A9 | **Orgasm reactions** | Any scene through to climax | Orgasm hype lines for **both** sexes; distinct from mid-scene moans | `SLOVE_Orgasm` event + `voice.printdebug` orgasm category; audible = user |
| A10 | **Huge-partner scenario (SOS/TNG)** | Scene with a huge-schlong partner | Huge-partner voice variants + broken/ahegao face | `IsHugePP` true in debug; `voice.printdebug` shows the `VarB`/huge variant |
| A11 | **Victim / submissive scenario** | Scene where PC or NPC is the submissive receiver | Victim-flavoured lines | `IsSubmissive` true in debug; victim category in `voice.printdebug` |
| A12 | **Gagged voice + lip handoff** | Speaker wearing a Devious Devices gag | Voice switches to the **muffled gag pool**; lip movement hands to the device (line plays with `blockLipSync`) | `AudioUtil.log` routes through the slot's `gag_slot`; gag detected via `[gag]` markers — a worn **keyword** (whole device family) **or** a specific worn **item** form (`[gag].items`, AudioUtil 0.9.3+). Muffle = user |
| A13 | **Per-voice volume + ducking** | Set `voice.pcvolume` / `voice.partnervolume`; scene | PC vs partner relative loudness follows config; groups duck as designed | Grep the four groups `pc_low/pc_high/partner_low/partner_high` in play calls; relative volume = user |
| A14 | **Female NPC partner voiced** | Scene with a non-PC female partner (FFM, or a male PC + female NPC) | The female NPC speaks her **own** moans/grunts, resolved to her `F2–F10` pool slot and played on her own channel — intensity-aware (grunt when soft, near-orgasm moan when intense). She stays female even in a male-PC scene; silent if she is the necro/unconscious target (A17) | Console: `scene females voiced (NPC): N`; `voice.printdebug` shows `PickSpeakingFemale` / `forceFemaleVoice`; her `F*` slot resolves in `AudioUtil.log`. Gated by `voice.voiceallactors`. **Note:** MVP is scene-intensity ambience, **not** her own position/beat. Audible = user |
| A15 | **Variation A/B pack dispatch** | Install a Variation-**B** pack in F1 (its slot declares `variation="B"`) vs a Variation-**A** pack (no `variation`) | A B pack routes each beat to its **partitioned** folder (victim / broken / femdom / over-the-top); an A pack uses the collapsed set. Decided by the **lead female's (PC's)** resolved slot | `AudioUtil.GetSlotVariation` returns `B`/`A` (AudioUtil 0.9.3+, API v2); `voice.printdebug` shows `VoiceVariation` + the `VarB` category / partition-folder name |
| A16 | **In-pack Variation-B fallback** | A B pack that omits an intense/partition variant folder | The missing variant plays the pack's **own base** line (resolved in-pack) **before** dropping to stock SexLab moans | `AudioUtil.CategoryExists` gate visible in `voice.printdebug`; `AudioUtil.log` resolves the pack's base folder, not `F0`/`F0B` |
| A17 | **Necro / faint / unconscious target silenced** | Scene tagged `necro` / `faint` / `sleep` / `unconscious` | The passive **target** makes **no voice and no lipsync** — the line is *skipped*, not ducked, so AudioUtil never drives the mouth; the dead face (closed eyes / slack jaw) applies to the **victim only**. The **aggressor** speaks and emotes normally. Works for an NPC target of either sex | `voice.printdebug`: `Voice + lipsync suppressed (unconscious target)`; aggressor's lines still logged; face = user |

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
| B11 | **Cunnilingus detection + contact tongue (P+)** | P+ cunnilingus scene (female oral target), `enabletongue=1` | SexLab's legacy detector reports clit↔mouth contact as `aOral` → the `CUN` oral label, and the licker gets a contact tongue. `director.cunnilingusdistance` / `cunnilingusangle` widen SexLab's `fDistanceMouth` / `fAngleCunnilingus` (via `sslSystemConfig`, non-destructive) so `CUN` fires on looser alignment | `director.printdebug`: `Cunnilingus detection widened: fDistanceMouth=… fAngleCunnilingus=…`. Needs `bUseLegacyNiType=1` (else a warning is logged) + a body with a `Clitoral1` node. `CUN` appears in the physics-label debug; tongue = user visual |
| B12 | **Tongue preload, no NPC redress (P+)** | `expressions`/`NPCTongue.json enablenpctongue=1`, start a scene | The `SLOVE_ThreadHook` **blocking** thread hook preloads all ten tongue armors in SexLab's guaranteed **pre-strip** window, so an add-triggered NPC outfit re-dress is undone by the strip; the async `DirectorSceneStarting` remains a fallback | `SLOVE.0.log`: `SLOVE_ThreadHook` registers at load; `PreloadTongueArmors: … items_added=N` fires **before** the strip; NPC stays undressed = user visual |

## C. Body SFX

| # | Use case | Setup / trigger | Expected | Evidence |
|---|---|---|---|---|
| C1 | **Core body SFX** | `sfx.enable=1`, `sfx.volume>0`, any scene | Slushing / impact / clap / kissing / blowjob sounds play with the action | `sfx.printdebug` names each SFX; `SLOVE_Test` SFX probe; audible = user |
| C2 | **Thrust-synced (P+ only)** | SexLab **P+**, `sfx.usevelocity=1` | Slush/impact track collision velocity; falls back to label pacing with no velocity data | `sfx.printdebug` shows velocity it's getting; **classic build must NOT** attempt this (see [SexLab Flavours](sexlab-flavours.md)) |
| C3 | **Successive-slush replacement** | Dense thrusting | A new slush **replaces** the running one, no pile-up | Each SFX carries a channel (`sfx_main_/sfx_slush_/…<position>`) — grep; overlap = user |
| C4 | **Contact one-shots** | Insertion, pull-out, kiss, oral edges | Insertion thunk, **PPA-measured** pull-out gape, kiss, oral one-shots fire on the contact edge | `sfx.printdebug` contact/edge line; gape needs the PPA bridge (see D1) |
| C5 | **Size-matched ejaculation one-shot** | Male orgasm | One ejaculation SFX at climax, matched to size | `sfx.printdebug` ejac on `SLOVE_Orgasm`; channel `sfx_ejac_<pos>` |
| C6 | **All SFX stop at scene end** | End the scene | Every SFX stream and pending one-shot stops | no lingering SFX in `sfx.printdebug`; silence = user |

## D. Integrations (soft dependencies)

| # | Use case | Setup / trigger | Expected | Evidence |
|---|---|---|---|---|
| D1 | **Measured penetration (Accurate Penetration / AudioUtilPPA)** | Accurate Penetration installed, scene | Expression & SFX penetration checks use **measured** context+depth (ctx 1=vaginal/2=anal + depth>0) instead of authored labels | `AudioUtilPPA.IsConnected` true; `AudioUtil.log` PPA connect line; depth in `printdebug` |
| D2 | **Graceful without soft deps** | Uninstall MFEE / sr_fillherup / PPA / SLS | No errors; features tied to the missing mod simply don't fire | `SLOVE.0.log` free of unresolved-dependency spam |
| D3 | **Fail-open without AudioUtil** | AudioUtil DLL absent | SLO VE loads; every `SLOVE_Config` getter returns its default; nothing plays; **no crash** | `SKSE\AudioUtil.log` absent + one fail-open warning in `SLOVE.0.log`; game stable = user |
| D4 | **Classic SexLab build** | Install via FOMOD **classic** option (SexLab SE 1.63 + SLSO) | Voices/expressions/gape/insertion work; **thrust-sync is P+-only and stays off**; **the contact tongue is P+-only too** — classic has no oral-contact detector, so `AddTongue` + the tongue preload are gated off (no tongue armor added on any actor, no NPC redress), **ahegao unaffected** | correct script set shipped (`dist-classic`); `SLOVE_ThreadHook` there is the inert `ReferenceAlias` stub; `SLOVE.0.log` clean; see [SexLab Flavours](sexlab-flavours.md) |

## E. Gameplay — willpower / resistance (optional)

| # | Use case | Setup / trigger | Expected | Evidence |
|---|---|---|---|---|
| E1 | **Willpower drains under penetration** | `resistance.enable=1`, sustained penetration | Willpower falls with the **rise in enjoyment** × race/victim/huge multipliers | `director.printdebug` logs the per-tick drain; `SLOVE_Test DumpState` |
| E2 | **Break → broken voice + face** | Drain willpower to ≤0 | Actor **breaks**: broken/begging voice lines + broken/ahegao face; willpower frozen at 0 | `IsBroken` true via Director; `brokenface` term; lines/face = user |
| E3 | **Broken-status voice gate** | `resistance.enablebrokenstatus=0` | Broken **face** stays; broken **voice** does not | `ASLIsBroken` gated off; user confirms |
| E4 | **Mid-scene reload doesn't reset drain** | Drain partway, save, reload | Willpower **persists**; no re-recovery, no wipe | `SLOVE_LastSexTime` re-stamped at scene start; `DumpState` shows same willpower |
| E5 | **Disable drops broken state** | `resistance.enable=0` + `SLOVE_Config Reload` | Broken state cleared; drain stops | `DumpState` shows resistance off |
| E6 | **Victim insertion trauma** | Forced insertion onto a submissive receiver | Extra willpower hit via `SLOVE_ResDebt`, drained by that actor's Resistance | `sfx`/`resistance` debug shows `SLOVE_ResDebt` write + drain |

## F. Robustness & lifecycle

| # | Use case | Setup / trigger | Expected | Evidence |
|---|---|---|---|---|
| F1 | **Mid-scene save/load re-adoption** | Save mid-scene, reload | Scene re-adopts within ~3 s; voices/faces/SFX resume; **no orphaned spells** | `director.printdebug` re-adopt line; no duplicate ME in `DumpState` |
| F2 | **Clean scene end** | End any scene | Voices stop, face returns to neutral, SFX stop, SexLab's own moans restore. A climax cry already playing **rings out briefly** on the `*_high` groups before stopping (not clipped — the orgasm line isn't cut the instant the scene ends) | `director.suppresssexlabvoice` self-restores; `DirectorEndScene` stops `*_low`/`sfx`/`oneshot` immediately, `RemoveTracker` rings out `*_high`; silence+neutral = user |
| F3 | **Live TOML reload** | Edit `SLOVE.toml` + `SLOVE_voices.toml`, run `SLOVE_Config Reload` + `au reload` | New values take effect **without** a game restart | reload lines in both logs; changed behaviour = user |
| F4 | **SexLab voice/expression suppression** | Any SLO VE scene | No doubled voices; no face jitter (SLO VE silences SexLab's own moans per-scene) | `director.suppresssexlabvoice=1`; single voice = user |
| F5 | **Log hygiene** | After a full multi-scene session | `AudioUtil.log` free of `no slot resolvable` / `unknown slot` / `no readable PCM wav` spam; `SLOVE.0.log` free of errors | grep both logs |

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
