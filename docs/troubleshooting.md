# Troubleshooting & Logs

Two log files and a handful of console commands answer almost everything.

## Where the logs are

Both live under `Documents\My Games\Skyrim Special Edition\`:

| Log | Path | What it tells you |
|---|---|---|
| **SLO VE script log** | `Logs\Script\User\SLOVE.0.log` | Script and dependency errors: a missing mod, an unresolvable spell, a sound that didn't play. Written by SLO VE itself — **not** the general Papyrus log, and it needs no INI changes. |
| **AudioUtil log** | `SKSE\AudioUtil.log` | Everything audio: which slot an actor resolved to, which category resolved to which folder, TOML parse errors and overlay warnings. **This is the file for any voice problem.** |

!!! note "Mod Organizer 2 users"
    Logs go to the real `Documents\My Games\...` folder, **not** into MO2's virtual file system or the Overwrite folder.

For more detail, raise AudioUtil's verbosity in the base `AudioUtil.toml`:

```toml
[general]
log_level = "debug"     # trace | debug | info | warn | error
```

and turn on the live console play-by-play with `printdebug = 1` in the relevant [`SLOVE.toml`](config/slove.md) section (`[director]`, `[voice]`, `[expressions]`, `[sfx]`).

## Enabling Papyrus logging

Papyrus logging is off by default (it adds a little overhead, so it ships disabled). Turn it on only while diagnosing a problem, then turn it back off.

Edit `Skyrim.ini` (in the My Games folder above) and add or update this section:

```ini
[Papyrus]
bEnableLogging=1
bEnableTrace=1
bLoadDebugInformation=1
```

- **`bEnableLogging`** — writes the `Papyrus.0.log` file at all.
- **`bEnableTrace`** — includes `Debug.Trace` lines (what BF and most mods log).
- **`bLoadDebugInformation`** — adds script/line names to errors so they are actually readable.

## Console diagnostics

!!! note "These commands need ConsoleUtil Extended"
    The console commands below are provided by [ConsoleUtil Extended](https://www.nexusmods.com/skyrimspecialedition/mods/133569), an **optional** dependency. SLO VE itself runs fine without it — CUE is only needed to run these diagnostics.

```
SLOVE_Test DumpAnim                        ; dump the current scene: tags, labels, slot, likely voice/SFX
SLOVE_Test DumpState                       ; config flags, the player's slot, esp loaded?
SLOVE_Test AuditVoicePack F1             ; which categories a slot resolves / is MISSING
SLOVE_Test SampleCategory F1 Orgasm    ; play one clip now (handle=0 means nothing resolved)
SLOVE_Test Milk                            ; force one [milk] nipple squirt on the player (add 1 for intense)
SLOVE_Config Reload                        ; re-read SLOVE.toml
au reload                     ; re-read the AudioUtil TOMLs and rescan folders
```

Every `SLOVE_Test` / `SLOVE_Config` command also has a short alias (`slovetest anim`, `slovetest dump`, `slovetest audit F1`, `slovetest sample F1 Orgasm`, `slovetest milk`, `sloveconfig reload`); lipsync has its own `slovelip enable 0` / `slovelip gain 0.8`.

`DumpAnim` (alias `slovetest anim`) is the fastest way to see *why a given animation sounds the way it does*. For the player's live scene it prints the active SexLab scene tags, the SFX tag, and — per actor, the player marked `*` — their sex, role, resolved AudioUtil slot, all five labels (`stim`/`penis`/`oral`/`pen`/`end`) and the voice branch those labels select. Every line goes to **both the console and `SLOVE.0.log`**, so you can run it mid-scene and read it back afterwards. The voice line is the *label-derived* branch (the live engine also applies gag/orgasm/timing overrides), so pair it with `SampleCategory` to confirm a folder actually resolves.

`AuditVoicePack` picks the female or male category list from the slot id's first letter (`F…` → female, otherwise male). With AudioUtil **0.9.4+** it also attributes every resolving category to the slot that actually supplies it — `<- backfill from F0` lines plus an `(n in-pack, m backfilled)` summary — so a pack that only *appears* healthy because everything backfills from the stock moans is visible at a glance.

## Nothing happens at all

1. **Is `SLOVE.esp` enabled?** `SLOVE_Test DumpState` prints `esp loaded=`. If it's `False`, the plugin isn't active.
2. **Is AudioUtil installed and loading?** If `SKSE\AudioUtil.log` doesn't exist, the DLL never loaded — check `skse64.log` for why (usually a game-version or Address Library mismatch). SLO VE fails *open*: without the DLL every setting falls back to its default and nothing plays.
3. **Are you launching through SKSE?**
4. **Did the quest start?** SLO VE's quest is start-game-enabled and ships `Seq\SLOVE.seq`. On an existing save give it a few seconds after load. If the SEQ file is missing from your install, the quest won't auto-start.
5. **Is full Hentairim p+ *driving* at the same time?** SLO VE is a standalone port of Hentairim's voice/face system, so letting both drive at once makes them fight over the same actors. You don't have to uninstall Hentairim, though — keep it for its animation **tag database** with its IVDT / expression / SFX / resistance modules switched **off**, and let SLO VE take over. See [Using with Hentairim & PPA](hentairim-and-ppa.md).
6. **Is it an NPC-only scene that never got adopted?** NPC-only scenes *are* processed since 0.5.x (`enablenpcscenes = 1`, the default). But an NPC scene is still skipped if it's farther than `npcscenedistance` (≈2048 units) from the player, if `maxnpcscenes` concurrent NPC scenes are already running, or if `enablenpcscenes = 0`. See [NPC-only scenes](config/slove.md#npc-only-scenes).

## Doubled voices, or the mouth twitching between two expressions

SLO VE silences SexLab's own **moans** for scene actors automatically (the
`director.suppresssexlabvoice` toggle, on by default), so you should not hear two
voices. If you still do — or the face jitters as both mods write an expression — two
things can cause it:

- **SexLab's facial expressions are still on.** SLO VE drives the face itself, so the
  two stack. In the **SexLab MCM**, disable SexLab's **facial expressions**. See
  [Getting Started](getting-started.md#installation).
- **You turned moan suppression off** (`director.suppresssexlabvoice = 0`), or SLO VE
  isn't adopting the scene (see *Nothing happens at all* above). Leave the toggle at `1`,
  or disable SexLab's **voices/moans** in the SexLab MCM as a fallback.

Suppression is per-scene and self-restoring: SexLab's own moans return automatically in
any scene SLO VE doesn't drive.

## Nobody is talking

Work down the resolution chain:

1. `SLOVE_Test DumpState` — does the player have a slot? An **empty** slot line means the routing config never loaded.
2. **Check the TOML conflict winner.** The most common cause of an empty slot is AudioUtil's SFW-neutral `AudioUtil.toml` winning over SLO VE's. SLO VE must sit **below** AudioUtil in MO2's left pane. `AudioUtil.log` will show zero slots parsed.
3. `au reload` then read `AudioUtil.log` — a parse error names the file and line. A file that fails to parse is skipped entirely.
4. `SLOVE_Test AuditVoicePack F1` — if everything is `MISSING`, the slot resolved but its audio didn't.
5. **Is `voice.enablevoice`/`director.enablevoice` on?** `DumpState` prints them.
6. **Volume:** `voice.pcvolume` / `voice.partnervolume` in `SLOVE.toml`, and `[groups]` startup levels.

## No voices after updating an older install (IVDT → SLOVE folder rename)

!!! warning "Moved your own voice packs by hand? They need to move too."
    In **0.4.0** SLO VE's bundled voice folder was renamed
    `Data\Sound\fx\IVDT\…` → `Data\Sound\fx\SLOVE\…`. The bundled audio and any
    NPC pack installed through its **own** FOMOD/overlay update themselves — but a
    pack **you dropped in by hand** under the old `IVDT` path is now orphaned. The
    usual casualty is the **player pack at `Sound\fx\IVDT\F1`**, which leaves the
    PC on the stock moans (`AudioUtil.log` shows `Slot F1: 0 category folders…`).

    **Fix:** move your hand-placed folders from `Data\Sound\fx\IVDT\…` to the
    matching `Data\Sound\fx\SLOVE\…` — e.g. `…\IVDT\F1` → `…\SLOVE\F1`,
    `…\IVDT\M3` → `…\SLOVE\M3`. Then run `au reload` or restart. The empty
    `Sound\fx\IVDT` can be deleted afterwards.

## A voice pack I installed isn't playing

**First, read `AudioUtil.log`.** Since AudioUtil 0.9.2 it reports the outcome of every pack slot on load — one line usually names the problem faster than the console commands can:

- `Slot F1: 27 category folders scanned under Data\Sound\fx\SLOVE\F1` — the pack **was** picked up. If the count looks low for the pack, some folders are mis-named and fall back to the stock moans one category at a time.
- `Slot F1: 0 category folders under … — folder exists but has no <Category> subfolders` — the pack landed in the wrong place, so the slot silently falls back to the stock `F0` moans (which is why audio still plays but the pack never does). Almost always an **extra nesting level** (`…\F1\F1\…` or `…\F1\<PackName>\…`), **non-standard folder names**, or **BSA-packed audio** a folder scan can't see.
- `Slot F2: has audio but nothing routes to it` — the pack installed fine, but **no actor can reach the slot**. You dropped a follower pack into `F2`/`F3`/`F4` and never routed anyone: pin an NPC in `[npc_overrides]` or map a voicetype in `[voicetype_map]` (see [Give a follower her own voice](packs/female.md#give-a-follower-or-partner-her-own-voice)).

If those lines look healthy and you still hear nothing, work the console commands:

1. Are the WAVs **loose** — not inside a BSA? Folder scans cannot see into archives.
2. Are they at exactly `Data\Sound\fx\SLOVE\F1\<Category>\*.wav`? A pack that installs one level too deep (`…\F1\F1\…`) scans as nothing.
3. `au reload` — a fresh install needs a rescan (or a game restart).
4. `SLOVE_Test AuditVoicePack F1` — a healthy pack reports a high `n/71`, because missing categories backfill from the stock moans. **All** missing means the path is wrong. With AudioUtil **0.9.4+** the summary splits into `(n in-pack, m backfilled)` — **`0 in-pack` is the smoking gun** for "audio plays but it's never the pack": the pack folders aren't being scanned (wrong path / nesting) or the slot lost its pack config (e.g. a Variation-B pack whose `SLOVE_zpack_*.toml` was deleted, so the B folder names never match).
5. `SLOVE_Test SampleCategory F1 Orgasm` — `handle=0` = nothing resolved for that category.
6. Did an update overwrite your `SLOVE_voices.toml` edits? Move them into [your own overlay](packs/female.md#keeping-your-edits-across-updates).

## The wrong actor has the wrong voice

- `[npc_overrides]` beats voicetype and race — check nothing is pinning them.
- For an **ESL-flagged** plugin the form-id key uses the **last 3 hex digits**, not the 8 digits the console shows.
- `[race_map]` is substring-matched, longest hint first — a broad hint can swallow a narrow one you expected to match.
- `pc_female_slot`/`pc_male_slot` are **reserved**: no NPC can ever resolve to them. If you routed an NPC to `F1`, that's why she isn't using it.
- Set `log_level = "debug"` and read the resolution lines in `AudioUtil.log`.

## Mouths don't move

- Lipsync needs a **loose PCM wav**. BSA-packed and compressed audio plays without mouth movement — this is expected for creature slots.
- **Mfg Fix NG** is a hard requirement for every face write.
- The category may be in `[lipsync] block_categories` — `Orgasm` and the two blowjob-action categories deliberately don't move the mouth.
- A **gagged** actor has lipsync suppressed by design (the device owns the mouth).
- While the **climax/ahegao face owns the mouth**, lines play without lipsync so they can't fight the expression.
- SexLab Survival's ahegao takes the mouth over while it's active.

## Faces don't move

- **Mfg Fix NG** (MfgConsoleFunc/Ext) must be installed and winning its file conflicts.
- Check `director.enableexpressions` plus the per-class gates (`enablepcexpression`, `enablemalenpcexpression`, `enablefemalenpcexpression`).
- Creatures without facegen are skipped.
- A mask covering the face is detected and respected (`Masks.json`).

## SFX are wrong or missing

- `sfx.enable = 1`? `sfx.volume` above zero?
- Thrust-synced sounds need velocity data from SLPP interactions — with none, the engine falls back to label pacing. `sfx.printdebug = 1` shows what it's getting.
- **Don't** reach for `useadaptivevelocity` first; it's the heaviest path in the mod and needs `timestosearch > 0` as well.
- Gape one-shots need the Accurate Penetration bridge. The four `gape*` thresholds are unitless — calibrate them from the `printdebug` pull-out line in your own scenes.

## Reporting a problem

Attach both logs:

- `Documents\My Games\Skyrim Special Edition\Logs\Script\User\SLOVE.0.log`
- `Documents\My Games\Skyrim Special Edition\SKSE\AudioUtil.log`

plus your load order and the output of `SLOVE_Test DumpState`. If it's a voice-resolution problem, set `log_level = "debug"`, reproduce, and send the `AudioUtil.log` from that run.
