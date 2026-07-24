# Getting Started

SLO VE is mostly loose scripts, sounds and TOML config plus one small ESL-flagged plugin. There is nothing to build and no MCM to configure.

## Requirements

**Hard requirements** — SLO VE will not work without these:

| Requirement | Why |
|---|---|
| **SKSE64** | script extender; launch the game through it |
| **SexLab** — either **P+ 2.17+** *or* **SE 1.63 (classic)** | the scene framework SLO VE reads. The installer asks which one you run and installs the matching script set. Classic additionally requires **SLSO** and **SLATE + a tag database** — see [SexLab Flavours](sexlab-flavours.md) |
| **[AudioUtil](https://crajjjj.github.io/AudioUtil/)** | the audio engine: folder-based voice playback, lipsync, and the TOML reader every SLO VE setting is read through. **Without it there is no voice engine.** |
| **PapyrusUtil** | JSON preset data (expression faces) and per-actor state storage |
| **Mfg Fix NG** (MfgConsoleFunc/Ext) | every facial-expression write goes through it |

**Soft requirements** — all auto-detected, all optional, missing ones are simply skipped:

- **MFEE** (Mu Facial Expression Extended) — extended ahegao / tongue faces
- **sr_fillherup** — tongue armors
- **Devious Devices** — gag detection for the [muffled gagged voice](packs/slots.md#the-gag-slot-f1gag)
- **SexLab Survival** — SLO VE yields the mouth to its ahegao state
- **SOS / TNG** — huge-partner detection (the huge-partner voice + face scenario)
- **Accurate Penetration** (via the AudioUtilPPA bridge) — measured penetration depth and gape, used by SFX and expressions instead of authored labels
- **Oninus Lactis NG** (+ **Milk Mod Economy**) — the optional `[milk]` nipple-squirt system

**Recommended:** SexLab Cumshot for visible ejaculation — SLO VE voices, faces and SFX the scene but leaves cum visuals to it.

!!! note "Scene tags"
    Stage/position labels resolve from **Hentairim-convention scene tags** (`3asvp` = stage 3, actor A, slow vaginal penetration) — from the Scene Builder on **P+**, or from **SLATE** animation tags on **classic**. Untagged animations fall back to generic lead-in behaviour, so you get the most out of SLO VE on a tagged setup.

## Installation

SLO VE ships as a **FOMOD installer**. Use a mod manager (MO2 recommended).

1. **Install the hard requirements first**, each per its own instructions.
2. **(Optional) Add female voice packs.** Females already work out of the box on SexLab's stock moans, but any Hentairim/IVDT pack is a drop-in upgrade. See [Installing & Routing Female Packs](packs/female.md). Male packs M1–M8 and the body-SFX library are **already bundled**.
3. **Install SLO VE and pick your SexLab flavour.** The installer's **SexLab Framework** page offers *P+ (2.x)* or *SE 1.63 (classic) + SLSO* — see [SexLab Flavours](sexlab-flavours.md). Then enable `SLOVE.esp`; it is ESL-flagged (ESP-FE), so it costs no regular plugin slot and can sit anywhere in the plugin order.
4. **Set the conflict/priority order so SLO VE wins its files** — see below.
5. **(Optional) Install soft dependencies** for the extra behaviour you want.
6. **Start or load your game.** SLO VE's quest is start-game-enabled and ships a SEQ file, so it registers itself automatically — immediately on a new game, or within a few seconds of loading an existing save. Start any SexLab scene to hear it.

### Install order — this part matters

```
AudioUtil  →  voice-pack assets  →  SLO VE (last)
```

!!! info "On classic SexLab"
    SLSO and SLATE come earlier in the chain — the full order is
    `SexLab 1.63 → SLSO → SLATE + tag database → AudioUtil → voice packs → SLO VE (last)`.
    See [SexLab Flavours](sexlab-flavours.md#install-order).

SLO VE ships its own AudioUtil preset:

- `SKSE\Plugins\AudioUtil\AudioUtil.toml` — engine globals
- `SKSE\Plugins\AudioUtil\config\SLOVE_voices.toml` — voice slots and actor→voice routing

**These must overwrite AudioUtil's neutral defaults** or no actor resolves to a voice. In MO2 that means SLO VE sits **below** AudioUtil in the left pane (higher priority).

Voice packs only add loose WAVs under `Sound\fx\IVDT` and don't conflict with anything, so their position doesn't matter — just keep SLO VE the winner of the `.toml` files.

!!! danger "Mutually exclusive with full Hentairim p+"
    SLO VE is a standalone port of Hentairim's IVDT voice system. Run one or the other, **never both** — they drive the same faces and voices and will fight each other.

## First run — is it working?

Open the console (`~`) and run:

```
SLOVE_Test DumpState
```

This command is provided by [ConsoleUtil Extended](https://www.nexusmods.com/skyrimspecialedition/mods/133569), an optional dependency — SLO VE runs without it, but you need CUE to run the console diagnostics.

You should see the config flags, the player's resolved voice slot (normally `F1`), and `esp loaded=True`. If the slot line is empty or `esp loaded=False`, go to [Troubleshooting](troubleshooting.md).

Then start a scene. Expected out of the box: the player and female NPCs moan with SexLab's stock moan sets, males speak the bundled M1–M8 packs, creatures pant, faces move, and body SFX play.

## Updating

Install the new version over the old one and let it overwrite. **No clean save is needed** for config or audio-only changes.

If you edited `SLOVE_voices.toml` or `AudioUtil.toml` in place, an update overwrites your edits. To keep customisations across updates, put them in **your own overlay file** instead — see [Keeping your edits across updates](packs/female.md#keeping-your-edits-across-updates).

## Where to next

- Want a better female voice? → [Installing & Routing Female Packs](packs/female.md)
- Want to understand what picks which voice? → [How Voices Work](packs/index.md)
- Want every toggle in one place? → [SLOVE.toml Reference](config/slove.md)
- Something not working? → [Troubleshooting & Logs](troubleshooting.md)
