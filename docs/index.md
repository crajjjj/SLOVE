# SLO VE — Voices and Expressions

**SLO VE** ("SexLab / OStim — Voices and Expressions") is a standalone enhancement layer for **SexLab** scenes — it supports both **SexLab P+** and **classic SexLab 1.63** (the installer picks the right script set; see [SexLab Flavours](sexlab-flavours.md)). It watches the running animation and drives four things in sync with what is happening on screen: **voices**, **facial expressions**, **body SFX**, and an optional **willpower / resistance** system.

Everything is configured in plain **TOML** files that reload live from the console. **There is no MCM.**

!!! warning "Adult mod — reference documentation"
    SLO VE is a mature (18+) Skyrim mod that adds voices, facial expressions and sound effects to adult animation scenes. **These pages are reference documentation:** they describe the mod's audio slot model, configuration file format, and mod compatibility so players can configure it and authors can integrate with it. They contain no pornographic media and exist to document software behaviour. Install and use the mod only where appropriate for your age and local laws.

!!! info "Built on AudioUtil"
    SLO VE ships no sound-descriptor forms, no voice aliases and no `.lip` files. All audio goes through the [**AudioUtil**](https://crajjjj.github.io/AudioUtil/) SKSE plugin, which plays **loose WAV files by folder path** and lipsyncs them from the waveform. That is what makes voice packs drop-in — a pack is just a folder of `.wav` files. SLO VE decides *what category to play, when, and on whom*; AudioUtil decides *which file*.

## What it does

- **Scene voices** — moans and spoken lines picked per stage, tag and intensity, for the player and NPCs, male and female. Shuffle-bagged so lines don't repeat, with orgasm hype lines, a huge-partner scenario (SOS/TNG), a victim scenario, a moans-only mode and per-voice volume.
- **Every participant is voiced** — not just the lead. Partners rotate through their own lines and each NPC keeps a consistent voice across scenes. Creature partners pant and growl on their own timing, straight out of the vanilla BSAs.
- **Female voices work out of the box** — they default to SexLab's own moan sets. Any Hentairim/IVDT female pack is a drop-in upgrade: install its WAVs and it plays, and any category the pack lacks backfills from the stock moans.
- **Facial expressions** — live breathing, stage-intensity faces, tongue-out (sr_fillherup) and ahegao on huge partners, with a jaw-gate so a tongue only shows when the mouth is actually open.
- **Body SFX** — slushing, impacts, claps, kissing and blowjob sounds, optionally thrust-synced to collision velocity on **SexLab P+**, plus contact one-shots on insertion, pull-out gape, kiss and oral. (The gape and insertion sounds work on classic too; thrust-syncing is P+ only — see [SexLab Flavours](sexlab-flavours.md).)
- **Gagged voice** — a speaker wearing a mouth-owning device switches to a muffled pool automatically, and lip movement hands off to the device.
- **Lipsync** — mouths move in time with the audio, on any loose PCM wav. No `.lip` baking.
- **Willpower / resistance** *(optional)* — the one gameplay system carried over from Hentairim, or switch it off entirely.

## Where to start

- [Getting Started](getting-started.md) — requirements, mod-manager order (SLO VE must win the TOML files), first run, updating
- [SexLab Flavours](sexlab-flavours.md) — P+ vs classic 1.63, what each needs, and what differs
- [How Voices Work](packs/index.md) — the slot model, how an actor picks a voice, and how a category becomes a file
- [Installing & Routing Female Packs](packs/female.md) — the drop-in pack workflow, giving a follower her own voice, adding new slots
- [Male, Creature, Gag & SFX Slots](packs/slots.md) — the bundled male packs, vanilla-BSA creature voices, the gag pool and the body-SFX library
- [Category Reference](packs/categories.md) — every category name the engines request, its on-disk folder, and what it falls back to
- [Configuration Overview](config/index.md) — the three TOML files, which one owns what, and how they merge
- [SLOVE.toml Reference](config/slove.md) — every behaviour key: voice, expressions, sfx, resistance, milk
- [SLOVE_voices.toml Reference](config/voices.md) — every slot and routing table
- [AudioUtil.toml Reference](config/audioutil.md) — the engine globals SLO VE sets: lipsync, gag, PPA
- [Willpower / Resistance](resistance.md) — how the optional break system works and how to tune it
- [Troubleshooting & Logs](troubleshooting.md) — the two log files, the console diagnostics, and "why is nobody talking"
- [For Mod Authors](authors/integration.md) — mod events, StorageUtil keys, and pack-authoring conventions

## The 30-second version

```
Data\
  Sound\fx\IVDT\F1\<Category>\*.wav      ← the player's female voice pack (drop one in)
  Sound\fx\IVDT\F2\<Category>\*.wav      ← a follower / partner pack
  Sound\fx\IVDT\M1..M8\                  ← bundled male packs
  Sound\fx\SloveSFX\                     ← bundled body-SFX library
  SKSE\Plugins\SLOVE\SLOVE.toml                       ← behaviour: voice, expressions, sfx, resistance, milk
  SKSE\Plugins\AudioUtil\config\SLOVE_voices.toml     ← the voice slots + actor→voice routing
  SKSE\Plugins\AudioUtil\AudioUtil.toml               ← engine globals (lipsync, gag, PPA)
```

Reload either side after an edit without leaving the game:

```
SLOVE_Config Reload     ; SLOVE.toml
au reload  ; slots, routing, SFX — also rescans the folders
```

## Credits & license

SLO VE is a standalone port of **ShimizuModding's** Hentairim IVDT scene-voice system and stays compatible with Hentairim/IVDT-convention voice packs — full credit for the original system goes to ShimizuModding and to the community authors of those packs. Built on **AudioUtil**, **CommonLibSSE-NG** and **SexLab**.

**Mutually exclusive with full Hentairim p+** — run one or the other, never both.

The changelog lives on the [GitHub releases page](https://github.com/crajjjj/SLOVE/releases). SLO VE is licensed under **GPLv3**.
