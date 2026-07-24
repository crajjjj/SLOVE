# SexLab Flavours — P+ and Classic

SLO VE ships **two script sets in one download**. The installer asks which SexLab
you run and installs the matching set. Everything else — the plugin, the TOML
presets, the expression JSONs, the bundled audio — is identical either way.

| | **SexLab Framework P+ (2.x)** | **SexLab Framework SE 1.63 (classic)** |
|---|---|---|
| Installer option | *SexLab Framework P+ (2.x)* — recommended | *SexLab Framework SE 1.63 (classic) + SLSO* |
| Extra requirements | none | **SLSO** and **SLATE + a tag database** |
| Stage/position labels | SexLab Scene Builder | SLATE animation tags — **same fidelity** |
| Per-actor orgasm | native | via SLSO |
| Measured thrust intensity | yes | no — intensity comes from the authored tag |
| Adaptive velocity / SOSBend search | yes | no |
| PPA gape + insertion SFX | yes | yes |

!!! tip "Not sure which you have?"
    If your SexLab MCM reports version **2.x** and you have a *Scene Builder*, you
    are on **P+**. If it reports **1.63**, you are on **classic**.

## Choosing at install time

Pick your framework on the installer's **SexLab Framework** page. To switch later,
reinstall and choose the other option — the two sets differ in only six script
files and **no clean save is needed**.

## Classic's extra requirements

Classic needs two things P+ provides natively. Both are hard requirements — SLO VE
will misbehave without them.

### SexLab Separate Orgasm (SLSO)

SLO VE's voice, expression, SFX and `[milk]` triggers all key off **which actor
just climaxed**. Classic SexLab only fires a per-thread orgasm event — it reports
that the scene had an orgasm, not who had it.

[SLSO](https://www.loverslab.com/files/file/5240-sexlab-separate-orgasm/)
republishes the per-actor event that P+ sends natively, with identical arguments,
so with it installed orgasm routing is at full parity.

!!! warning "Let SLSO overwrite SexLab"
    SLSO ships a replacement `sslActorAlias` script. That override is what emits
    the per-actor event, so it **must** win the conflict.

### SLATE and a tag database

This is the one that decides whether SLO VE feels alive or mute.

On P+, per-stage/per-position labels come from the Scene Builder. On classic they
come from **SLATE**, which applies the same Hentairim-convention codes as ordinary
SexLab animation tags:

```
"addtag, Billyy Doggy 5 Sideways,1ASVP"   ; stage 1, position A, slow vaginal penetration
"addtag, Billyy Doggy 5 Sideways,5AENO"   ; stage 5, position A, ending outside
```

SLO VE reads those tags directly, so **label fidelity on classic matches P+**.
Install SLATE together with a Hentairim-convention tag database (the same tag data
Hentairim uses).

!!! danger "Without a tag database, every label falls back to lead-in"
    SLO VE will run, but every actor reads as "lead-in" in every stage — you get
    generic behaviour and none of the stage-aware voices, faces or SFX. Tag data
    quality *is* the experience on classic.

SLO VE also understands the older, shorter **ASL** scheme from
*SLAnimStageLabels* (`3SV`, `6EN` — scene-wide, no position letter). Where an
animation has no per-position data, SLO VE falls back to the ASL code and derives
a per-position label from it. That matters most for **creature and gangbang**
animations, many of which exist only in the ASL database.

### Install order

```
SexLab 1.63  →  SLSO  →  SLATE + tag database  →  AudioUtil  →  voice packs  →  SLO VE (last)
```

## What actually differs on classic

Only one subsystem is genuinely unavailable: **node-collision physics**. Classic
has no per-node contact detection, so:

- **Intensity is authored, not measured.** The fast/slow prefix on a label
  (`FVP` vs `SVP`) comes from the tag database rather than live thrust speed, so
  it does not follow an AnimSpeed override.
- **Thrust-synced velocity SFX and the adaptive SOSBend search are off.**
  `sfx.usevelocity`, `sfx.useadaptivevelocity` and `director.usephysicslabels`
  are ignored on this build.

**Everything else still works**, including the parts people assume are physics:
stage-aware voices, faces, body SFX, the willpower/resistance system, and — via
the framework-independent [Accurate Penetration](authors/integration.md) bridge —
the measured pull-out **gape** sound and the insertion trauma that feeds
willpower. `sfx.usecontactsfx` is honoured on both builds.

## For mod authors

The two sets live side by side in the repository:

```
papyrus/Source/          ← P+ sources (all ten scripts)
papyrus/classic/Source/  ← classic overrides (six framework-facing scripts)
```

Only six scripts touch the framework. `SLOVE_Config`, `SLOVE_Log`, `SLOVE_Test`
and `SLOVE_VoiceCategories` contain no SexLab references and ship once.

```powershell
.\scripts\build.ps1                    # both sets + installer
.\scripts\build.ps1 -Variant Classic   # classic only
```

The full P+ → classic API mapping is recorded in `docs/classic-sexlab-port.md`
in the repository.
