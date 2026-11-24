# What NPCs Do and Don't Voice

The player character can reach **all 79** female voice categories. A female NPC can reach **18**. This page lists exactly which, and why the other 61 are not a bug.

If you are wondering why the woman next to you moans while the PC talks, this is the page.

## Why NPCs voice less

SLO VE reads the animation's **per-position labels**, and it only ever reads them for the player's position. Those labels describe the PC and, by inversion, the actor opposite her. They say nothing about anybody else.

A category name is an *assertion*. `Penetrated Anal Comments` claims a specific act on a specific hole. Playing it for an actor whose act was never measured is a guess, and a wrong guess is worse than a generic moan: you get confident, specific, wrong-tone audio. So the rule is deliberate:

> An NPC voices a beat only when something measured it. Otherwise she gets an act-neutral sound.

Two things measure NPCs. **SexLab's submissive flag** answers "is she the coerced one". **[Accurate Penetration](https://www.nexusmods.com/skyrimspecialedition/mods/136366)** (PPA) measures every actor independently: depth, penetration site, and a per-actor scene classification. Install PPA and NPC voicing gets substantially more specific; without it, NPCs fall back to inference and stay more generic.

## What a female NPC can voice

| Beat | A-name category | Variation-B folder | Needs |
|---|---|---|---|
| Penetration grunt | `PenetrativeGrunts` | `Penetrated Grunt` | measured, inferred, or plausible |
| Penetration grunt, intense | `NearOrgasmNoises` | `Penetrated Grunt Intense` | as above + intensity |
| Coerced grunt | `Unamused` | `Penetrated Grunt Victim` | SexLab submissive flag, or PPA Aggressive (not FemDom) when nobody is flagged |
| Coerced grunt, intense | `CumTogetherTease` | `Penetrated Grunt Victim Intense` | as above |
| Mouth full | `BlowjobActionSoft` | `Blowjob Action` | her mouth on the lead |
| Mouth full, intense | `BlowjobActionIntense` | `Blowjob Action Intense` | as above |
| Breathing | `BreathySoft` | `Breathing` | always available (the floor) |
| Breathing, heightened | `BreathyIntense` | `Breathing Intense` | intensity, or the lead's mouth on her |
| Kissing | `MaleOrgasmReactionLover` | `Kissing` | kiss-labelled scene, partner only |
| Climax | `Orgasm` | `Orgasm` | SexLab orgasm event |
| Anal comments | `IntenseAnal` | `Penetrated Anal Comments Intense` | **PPA** site Anus (or lead giving anal) |
| Double penetration | `TeaseAnal` | `Penetrated Double Comments` | **PPA** site Both |
| Femdom comments | `PenetrativeCommentsIntense` | `Penetrated Comments Femdom` | **PPA** FemDom context |
| Femdom comments, intense | `SensitivePleasure` | `Penetrated Comments Femdom Intense` | as above |
| Femdom foreplay | `Satisfied` | `Foreplay Femdom Comments` | **PPA** FemDom context |
| Breast play | `ForeplayIntense` | `Foreplay BoobJob Comments` | **PPA** context, or the labels |
| Hand play | `ForeplaySoft` | `Foreplay Handjob Comments` | **PPA** context or hand site |
| Foot play | `MadeMeCumSoMuch` | `Foreplay FootJob Comments` | **PPA** context |

The last eight rows are effectively **PPA-only**. Without it, most NPC lines come from the first ten.

Everything spoken (the comment folders) also passes a dice roll, `voice.npccommentchance` (default `0.35`), so NPCs stay mostly non-verbal even when a spoken beat qualifies. A failed roll drops to the grunt or breath - never to silence. Set it to `0` for moans only, or `1` to hear every spoken beat they can reach.

### The partner is not a bystander

The woman **opposite** the PC - the role slot the engine fills in every F/F scene - is the scene's co-star and gets the inverted PC labels, so she reaches the act-specific beats above even without PPA. A **third** woman is a bystander: the labels never described her, so without PPA she gets grunts (when the scene contains someone who could be doing the penetrating), breathing, and her climax. Nothing else.

`voice.voiceallactors = 0` silences bystanders. The partner keeps her voice - she *is* the lead partner.

## What a female NPC never voices

All 61, grouped by why:

**Dirty talk and running commentary** - `PenetrativeCommentsSoft`, `BlowjobRemarks`, `AppreciatePartner`, `AskForPacingBreak`, `Amused`, `OnTheAttack`, `AssFlattering`, `InAwe`, `Oh`, `NoticeMaleWantsMore`, `SensitivePleasure` (as a non-femdom beat), `WantMore`, `ReadyToResume`, `RefractoryPeriod`
*These are a protagonist's lines. There is one protagonist.*

**The orgasm build-up and aftermath** - `MyTurnToCum`, `NearOrgasmExclamations`, `SurprisedByMaleOrgasm`, `MaleCloseNotice`, `MaleCloseAlready`, `MaleHalfwayIntense`, `TeaseMaleCloseToOrgasmSoft`, `TeaseMaleCloseToOrgasmIntense`, `MaleOrgasmReactionSoft`, `MaleOrgasmReactionIntense`, `MaleOrgasmOral`, `MaleOrgasmNonOral`, `AfterOrgasmArouse`, `AfterOrgasmRemarks`, `AfterOrgasmExclamations`, `MadeMeCumSoMuch` (as an aftermath beat), `UnamusedEnd`
*The reaction state machine tracks one climax timeline - the PC's.*

**Where it finished** - `CameInMouth`, `CameInPussy`, `CameInAss`, `AskForVaginalCum`, `AskForAnalCum`, `AskForOralCum`, `PullOut`, `BeforeGape`, `AfterGape`
*Nothing tracks an NPC's ending; PPA reports depth and site, not orgasm destination.*

**Giving oral** - `Licking`, `LickingIntense`, `LickingComments`, `LickingForced`, `Rimjob`, `RimjobIntense`, `RimjobComments`, `RimjobForced`, `AssToMouth`
*Deliberate and unfixable from labels: the label set has no "the lead is being licked" state, so an NPC's mouth is only ever detectable on a cock or a strapon - which `Blowjob Action` already covers. Routing these would be a guess.*

**Insertion and foreplay openers** - `InsertionGeneric`, `InsertionAnalSlow`, `InsertionAnalExcited`, `ForeplaySoft`/`ForeplayIntense` as openers, `ReadyToGetGoing`, `TeaseAnal` (as a tease), `AskForAnal`
*These fire on stage-transition edges the engine only computes for the PC.*

**Romance and social** - `GreetLover`, `GreetFamiliar`, `GreetLoadedFamiliar`, `MissMaleLover`, `WantToBeLover`, `RomanceMaleThane`, `LoveyDovey`
*Driven by the PC's relationship state.*

**Not scene audio** - `MCMSampleSounds` (menu preview).

## Other roles

| Role | Reaches | Notes |
|---|---|---|
| **Male NPC** | 11 of 15 male categories | Dirty talk, struggling, climax, post-nut, plus the two moan pools. `StrugglingOvert`, `JokeAroused`, `TeaseFemaleOrgasm` and `AfterFemaleOrgasm` are wired **nowhere** - dead vocabulary, not an NPC gap. |
| **Creature** | `Breathing`, `Orgasm` | Panting on its own cadence plus a climax roar. No human beats. |
| **NPC-only scenes** (couples near you, not involving the PC) | grunts, `Penetrated Grunt Victim` (+intense), `Blowjob Action` (+intense), breathing, `Orgasm` | The lightest engine: no femdom model and no label data at all, so it uses PPA's site, depth and context. A woman who would grunt (PPA measures her penetrated, or, unmeasured, the scene has a male or creature) and is the scene's victim grunts from the Victim folders on a B or D pack; A and stock packs keep the plain grunt. Victim = SexLab's submissive flag, or, when the scene flags nobody, PPA Aggressive without FemDom: the same test as in your own scenes. Deliberately light - these are ambience for scenes you are not in. |

## What this means for a pack

If you record for an NPC-heavy game, the folders that actually get used are small: **`Penetrated Grunt`** (+`Intense`), **`Penetrated Grunt Victim`** (+`Intense`), **`Breathing`** (+`Intense`), **`Blowjob Action`** (+`Intense`), **`Kissing`**, **`Orgasm`**. Those ten cover almost every line an NPC will ever speak. Add the PPA-gated comment folders if your users run Accurate Penetration.

Everything a pack ships stays useful regardless - the PC reaches all of it, and any folder an NPC cannot reach simply never gets drawn. Nothing is wasted, and no folder needs to exist for NPCs to work: a missing one falls down the normal ladder to stock moans.

## Checking what actually played

Turn on the transcript and read it back:

```
autest voicelog all
```

`<SKSE logs>\AudioUtil_Voices.log` then gets one line per voice line - speaker, the category asked for, her facts, the folder it resolved to, and the exact wav. An NPC row whose facts read `rcv anal` proves PPA measured her; a row with bare `soft` means nothing measured her and the fallback chose the line. See [Troubleshooting & Logs](../troubleshooting.md).
