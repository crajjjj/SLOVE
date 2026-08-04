# Hentairim / SLSB scene-tag reference

Source: *Hentairim P+ Guide* by Shimizu ("Hentairim Tags", "Change/Find Animation"
and "Stage Maker" sections). Kept in-repo as the porting reference for the SLSB scene-tag
scheme that **`SLOVE_Hentairim_Tags`** classifies — SLO VE's label engine reads these tags
via `SexlabRegistry.IsSceneTag` and turns them into the label codes the Voice / Expressions /
SFX effects consume. This is the annotation scheme SLO VE ports from Hentairim/IVDT; the
external scene tags themselves live in the SLSB data (loaded with SexLab P+), not in this repo.

An OStim backend would need its **own** tag classifier — labels are annotation-scheme-specific
(see [framework-adapter.md](framework-adapter.md)), so this reference is P+/SexLab-tag only.
Excluded from the published docs site (implementation reference, not user-facing).

## Tag structure — `3ASCG`

A full scene tag is `<stage><ActorLetter><code>`:

| Part | Example | Meaning |
|------|---------|---------|
| Stage | `3` | Stage number of the scene (Stage 3). |
| Position | `A` | Actor position, `A`–`E` = index `0`–`4`. `A` = first actor position. |
| Action | `SCG` | Action code (see below). |

So `3ASCG` = *Slow Cowgirl* by the actor in position 0, in Stage 3. This is exactly the
`<stage><ActorLetter><code>` convention `SLOVE_Hentairim_Tags` documents (e.g. `3A SVP` =
stage 3, pos 0, slow vaginal penetration).

## Action codes

These are the raw Hentairim/IVDT codes. SLO VE's own **label-code vocabulary** (`LDI`, `ENI`/`ENO`,
the `1F` "intense" marker, etc. — see the CLAUDE.md script table) is derived from them by the
label engine; the codes below are what appears in the SLSB scene tags.

### Stimulation — actor is being stimulated (licking, cunnilingus, fingering)

| Code | Meaning |
|------|---------|
| `SST` | Getting soft/slow stimulation |
| `FST` | Getting fast/intense stimulation |
| `BST` | Getting huge stimulation (fisting / huge non-penile insertion) |

### Penetration — actor is receiving penile penetration

| Code | Meaning |
|------|---------|
| `SVP` | Getting soft/slow vaginal penetration |
| `FVP` | Getting fast/intense vaginal penetration |
| `SAP` | Getting soft/slow anal penetration |
| `FAP` | Getting fast/intense anal penetration |
| `SCG` | Soft/slow vaginal cowgirl |
| `FCG` | Fast/intense vaginal cowgirl |
| `SAC` | Soft/slow anal cowgirl |
| `FAC` | Fast/intense anal cowgirl |
| `SDP` | Getting soft/slow double penetration |
| `FDP` | Getting fast/intense double penetration |

### Penis action — what the actor's penis is doing

| Code | Meaning |
|------|---------|
| `SDV` | Giving soft/slow vaginal penetration |
| `FDV` | Giving fast/intense vaginal penetration |
| `SDA` | Giving soft/slow anal penetration |
| `FDA` | Giving fast/intense anal penetration |
| `SHJ` | Getting soft/slow handjob |
| `FHJ` | Getting fast/intense handjob |
| `STF` | Getting soft/slow titfuck |
| `FTF` | Getting fast/intense titfuck |
| `SMF` | Getting soft/slow blowjob |
| `FMF` | Getting fast/intense blowjob |
| `SFJ` | Getting soft/slow footjob |
| `FFJ` | Getting fast/intense footjob |

### Oral — what the actor's mouth is doing

| Code | Meaning |
|------|---------|
| `KIS` | Kissing |
| `CUN` | Cunnilingus |
| `FBJ` | Giving fast/intense blowjob |
| `SBJ` | Giving soft/slow blowjob |
| `RIM` | Performing a rimjob — **SLO VE extension**, not in the original Hentairim/IVDT set. No converter emits it; author it by hand. Without it, SLO VE detects rim acts from the `rimjob`/`rimming`/`anilingus` **scene** tags plus a mouth-busy oral label (`CUN`, or the converted DB's `KIS` stand-in) |

## Tag-string syntax (Change/Find Animation, Stage Maker)

Tag strings follow the SexLab P+ format, comma-delimited within a stage:

- No prefix → the stage **must** have the tag.
- `-` prefix → **exclude** the tag (e.g. `-aggressive`).
- `~` prefix → **either/or** with other `~` tags (e.g. `~standing,~kneeling`).
- Contents in JSON config files must be **lowercase**.

Stage Maker specifics (Hentairim P+ only — SLO VE strips the stage-advance/choreography
systems, so this is background for reading Hentairim configs, not a SLO VE feature):

- A custom stage's tag list is `|`-delimited; the first item is the **lookup criteria**,
  the rest are per-stage tags.
- The **action tag must be the first tag** in a custom stage's list
  (e.g. `2asvp, standing, -aggressive`).
- A stage with **one** tag inherits the lookup-criteria tags; a stage with **two or
  more** tags uses only its own.
- `@` prefix targets a specific scene by name and requires a stage number
  (e.g. `@Billyy Standing 2,3` = Stage 3 of "Billyy Standing 2").
