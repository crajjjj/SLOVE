# Category Reference

Every category name the voice engines can request. These names are the **contract between SLO VE and your pack**: a pack supplies a folder per category, and the engine asks for them by name.

The authoritative lists live in `SLOVE_VoiceCategories.psc` (`AllFemaleCategories`, `AllMaleCategories`) and are what `SLOVE_Test.AuditVoicePack` checks against.

!!! tip "Names are normalised"
    `NearOrgasmNoises`, `Near Orgasm Noises` and `near orgasm noises` are the same key. The **On-disk folder** column below shows the conventional Hentairim/IVDT spelling; any spacing or casing works.

## How to read the tables

- **On-disk folder** — what a pack should name the folder. Where an [alias](../config/voices.md#category_aliases) redirects the category to a *differently named* folder, that folder is shown in **bold**.
- **If missing →** — the [category fallback](../config/voices.md#category_fallbacks) SLO VE's preset applies when the slot has no folder for this category. Blank means no fallback: if the slot (and its `fallback` slot) can't resolve it, the line doesn't play.

A pack does **not** need to supply every category. Whatever it lacks resolves through the fallback layer, and then through the slot's `fallback` slot — for `F1`/`F2`/`F3` that is SexLab's stock moans, so coverage is always complete.

## Female categories

71 categories. Requested for the player and for female NPCs.

### Greetings & affection

| Category | On-disk folder | If missing → |
|---|---|---|
| `GreetFamiliar` | Greet Familiar | |
| `GreetLover` | Greet Lover | Greet Familiar |
| `GreetLoadedFamiliar` | Greet Loaded Familiar | Greet Familiar |
| `MissMaleLover` | Miss Male Lover | Greet Familiar |
| `WantToBeLover` | Want To Be Lover | Greet Familiar |
| `RomanceMaleThane` | Romance Male Thane | Greet Familiar |
| `LoveyDovey` | Lovey Dovey | Satisfied |
| `AppreciatePartner` | Appreciate Partner | Satisfied |
| `Satisfied` | Satisfied | |

### Foreplay & lead-in

| Category | On-disk folder | If missing → |
|---|---|---|
| `SensitivePleasure` | Sensitive Pleasure | |
| `ForeplayIntense` | Foreplay Intense | |
| `ForeplaySoft` | Foreplay Soft | |
| `ReadyToGetGoing` | Ready To Get Going | |
| `ReadyToResume` | Ready To Resume | Ready To Get Going |

### Oral

| Category | On-disk folder | If missing → |
|---|---|---|
| `BlowjobRemarks` | Blowjob Remarks | |
| `BlowjobActionIntense` | Blowjob Action Intense | |
| `BlowjobActionSoft` | Blowjob Action Soft | |
| `AssToMouth` | Ass To Mouth | Blowjob Remarks |

!!! note
    `BlowjobActionSoft` / `BlowjobActionIntense` are **oral SFX**, not vocalisation — they are in `[lipsync] block_categories`, so they never move the mouth.

### Insertion & penetration

| Category | On-disk folder | If missing → |
|---|---|---|
| `InsertionGeneric` | Insertion Generic | |
| `InsertionAnalSlow` | Insertion Anal Slow | |
| `InsertionAnalExcited` | Insertion Anal Excited | Insertion Anal Slow |
| `PenetrativeGrunts` | Penetrative Grunts | |
| `PenetrativeCommentsIntense` | Penetrative Comments Intense | |
| `PenetrativeCommentsSoft` | Penetrative Comments Soft | |
| `OnTheAttack` | On The Attack | |
| `AssFlattering` | Ass Flattering | On The Attack |
| `IntenseAnal` | Intense Anal | |
| `BeforeGape` | Before Gape | Intense Anal |
| `AfterGape` | After Gape | |
| `AskForPacingBreak` | Ask For Pacing Break | Penetrative Comments Soft |
| `TeaseAnal` | Tease Anal | Tease Aggressive Partner |
| `AskForAnal` | Ask For Anal | Tease Aggressive Partner |

### Her orgasm

| Category | On-disk folder | If missing → |
|---|---|---|
| `NearOrgasmNoises` | Near Orgasm Noises | |
| `NearOrgasmExclamations` | Near Orgasm Exclamations | |
| `CumTogetherTease` | Cum Together Tease | |
| `MyTurnToCum` | My Turn To Cum | |
| `Orgasm` | Orgasm | |
| `AfterOrgasmArouse` | After Orgasm Arouse | |
| `AfterOrgasmExclamations` | After Orgasm Exclamations | |
| `AfterOrgasmRemarks` | After Orgasm Remarks | |
| `MadeMeCumSoMuch` | Made Me Cum So Much | After Orgasm Remarks |

!!! note
    `Orgasm` is in `[lipsync] block_categories`: while she climaxes, the **climax/ahegao face owns the mouth**, so the line plays without lipsync fighting the expression.

### Reacting to his orgasm

| Category | On-disk folder | If missing → |
|---|---|---|
| `MaleHalfwayIntense` | Male Halfway Intense | Male Close Notice |
| `MaleCloseAlready` | Male Close Already | |
| `MaleCloseNotice` | Male Close Notice | |
| `TeaseMaleCloseToOrgasmIntense` | **Male Close Tease Intense** | |
| `TeaseMaleCloseToOrgasmSoft` | **Male Close Tease Soft** | |
| `AskForVaginalCum` | Ask For Vaginal Cum | |
| `AskForAnalCum` | Ask For Anal Cum | |
| `AskForOralCum` | Ask For Oral Cum | |
| `PullOut` | Pull Out | |
| `MaleOrgasmOral` | Male Orgasm Oral | |
| `MaleOrgasmNonOral` | Male Orgasm Non Oral | |
| `SurprisedByMaleOrgasm` | Surprised By Male Orgasm | |
| `MaleOrgasmReactionIntense` | Male Orgasm Reaction Intense | |
| `MaleOrgasmReactionSoft` | Male Orgasm Reaction Soft | |
| `MaleOrgasmReactionLover` | Male Orgasm Reaction Lover | Male Orgasm Reaction Soft |
| `CameInAss` | Came In Ass | |
| `CameInMouth` | Came In Mouth | |
| `CameInPussy` | Came In Pussy | |

### Afterglow, mood & filler

| Category | On-disk folder | If missing → |
|---|---|---|
| `WantMore` | Want More | |
| `RefractoryPeriod` | Refractory Period | Want More |
| `NoticeMaleWantsMore` | Notice Male Wants More | |
| `BreathyIntense` | Breathy Intense | |
| `BreathySoft` | Breathy Soft | Breathy Intense |
| `Amused` | Amused | |
| `Unamused` | Unamused | |
| `UnamusedEnd` | Unamused End | |
| `InAwe` | In Awe | |
| `Oh` | Oh | |
| `TeaseAggressivePartner` | Tease Aggressive Partner | |
| `MCMSampleSounds` | **Orgasm** | |

## Male categories

15 categories, requested for male NPCs (and a male PC). A complete male pack ships the 11 folders that aren't aliases:

| Category | On-disk folder | Notes |
|---|---|---|
| `Aroused` | Aroused | |
| `Aggressive` | Aggressive | |
| `StrugglingEarly` | Struggling Early | |
| `StrugglingSubtle` | Struggling Subtle | |
| `StrugglingOvert` | Struggling Overt | falls back to **Struggling Early** if the pack lacks it |
| `AboutToCum` | About To Cum | |
| `Orgasm` | Orgasm | |
| `PostNutRemark` | Post Nut Remark | |
| `JokeAfterOrgasm` | Joke After Orgasm | |
| `JokeAroused` | **Joke After Orgasm** | alias — shares the same audio |
| `TeaseFemaleOrgasm` | **Tease Aggressive Partner** | alias |
| `AfterFemaleOrgasm` | **Post Nut Remark** | alias |
| `TeaseAggressivePartner` | Tease Aggressive Partner | |
| `LoveyDovey` | Lovey Dovey | |
| `MCMSampleSounds` | **Orgasm** | alias |

Plus one creature-only category:

| Category | Notes |
|---|---|
| `Breathing` | creature ambience, rolled through the scene. Falls back to `Orgasm` so creature slots that define only `Orgasm` still pant. |

!!! info "Aliases run *after* an exact folder match"
    A pack that *does* ship a `Struggling Overt` folder uses it; only packs without one hit the alias. Same for the other aliased names.

## Male-only scenes — `[male_only_remap]`

In a male-only scene the female voice engine keeps running, but its categories have to resolve against a **male** pack. Each female category is substituted with the closest male one. This layer applies to male slots only.

| Female category | → male category |
|---|---|
| `PenetrativeCommentsIntense` | Aggressive |
| `PenetrativeCommentsSoft` | Tease Aggressive Partner |
| `PenetrativeGrunts` | Aroused |
| `SensitivePleasure` | Struggling Subtle |
| `ForeplayIntense`, `ForeplaySoft` | Aroused |
| `InsertionGeneric` | Struggling Subtle |
| `InsertionAnalExcited`, `InsertionAnalSlow` | Struggling Subtle |
| `NearOrgasmNoises` | Struggling Subtle |
| `NearOrgasmExclamations` | Struggling Early |
| `BreathyIntense`, `BreathySoft` | Aroused |
| `LoveyDovey` | Lovey Dovey |
| `AfterOrgasmRemarks`, `AfterOrgasmExclamations` | Post Nut Remark |
| `AfterOrgasmArouse` | Joke After Orgasm |
| `MaleOrgasmOral`, `MaleOrgasmNonOral` | Orgasm |

The Papyrus layer (`SLOVE_VoiceCategories.MaleOnlyRemap`) does the same mapping ahead of time; the TOML table is the runtime safety net behind it, and the one you can edit.

## Auditing a pack

```
SLOVE_Test AuditVoicePack F1
```

Prints every category that does **not** resolve, then a summary like `SLOVE audit F1: 71/71 categories resolve`. It picks the female or male list from the slot id's first letter (`F…` → female, anything else → male), and it checks resolution **after** aliases, fallbacks and the slot's `fallback` chain — so `71/71` on a small pack means the backfill is working, not that the pack has 71 folders.
