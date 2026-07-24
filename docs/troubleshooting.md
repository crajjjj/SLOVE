# Troubleshooting & Logs

Two log files and four console commands answer almost everything.

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

## Console diagnostics

```
cgf "SLOVE_Test.DumpState"                       ; config flags, the player's slot, esp loaded?
cgf "SLOVE_Test.AuditVoicePack" "F1"             ; which categories a slot resolves / is MISSING
cgf "SLOVE_Test.SampleCategory" "F1" "Orgasm"    ; play one clip now (handle=0 means nothing resolved)
cgf "SLOVE_Config.Reload"                        ; re-read SLOVE.toml
cgf "AudioUtil.ReloadConfig"                     ; re-read the AudioUtil TOMLs and rescan folders
```

`SLOVE_Test` needs **ConsoleUtil** to print. `AuditVoicePack` picks the female or male category list from the slot id's first letter (`F…` → female, otherwise male).

## Nothing happens at all

1. **Is `SLOVE.esp` enabled?** `cgf "SLOVE_Test.DumpState"` prints `esp loaded=`. If it's `False`, the plugin isn't active.
2. **Is AudioUtil installed and loading?** If `SKSE\AudioUtil.log` doesn't exist, the DLL never loaded — check `skse64.log` for why (usually a game-version or Address Library mismatch). SLO VE fails *open*: without the DLL every setting falls back to its default and nothing plays.
3. **Are you launching through SKSE?**
4. **Did the quest start?** SLO VE's quest is start-game-enabled and ships `Seq\SLOVE.seq`. On an existing save give it a few seconds after load. If the SEQ file is missing from your install, the quest won't auto-start.
5. **Is full Hentairim p+ also installed?** They are mutually exclusive and will fight over the same faces and voices. Disable one.
6. **Is the scene actually a player scene?** The voice engine is player-scene driven; NPC-only scenes elsewhere in the world aren't adopted.

## Nobody is talking

Work down the resolution chain:

1. `cgf "SLOVE_Test.DumpState"` — does the player have a slot? An **empty** slot line means the routing config never loaded.
2. **Check the TOML conflict winner.** The most common cause of an empty slot is AudioUtil's SFW-neutral `AudioUtil.toml` winning over SLO VE's. SLO VE must sit **below** AudioUtil in MO2's left pane. `AudioUtil.log` will show zero slots parsed.
3. `cgf "AudioUtil.ReloadConfig"` then read `AudioUtil.log` — a parse error names the file and line. A file that fails to parse is skipped entirely.
4. `cgf "SLOVE_Test.AuditVoicePack" "F1"` — if everything is `MISSING`, the slot resolved but its audio didn't.
5. **Is `voice.enablevoice`/`director.enablevoice` on?** `DumpState` prints them.
6. **Volume:** `voice.pcvolume` / `voice.partnervolume` in `SLOVE.toml`, and `[groups]` startup levels.

## A voice pack I installed isn't playing

1. Are the WAVs **loose** — not inside a BSA? Folder scans cannot see into archives.
2. Are they at exactly `Data\Sound\fx\IVDT\F1\<Category>\*.wav`? A pack that installs one level too deep (`…\F1\F1\…`) scans as nothing.
3. `cgf "AudioUtil.ReloadConfig"` — a fresh install needs a rescan (or a game restart).
4. `cgf "SLOVE_Test.AuditVoicePack" "F1"` — a healthy pack reports a high `n/71`, because missing categories backfill from the stock moans. **All** missing means the path is wrong.
5. `cgf "SLOVE_Test.SampleCategory" "F1" "Orgasm"` — `handle=0` = nothing resolved for that category.
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

plus your load order and the output of `cgf "SLOVE_Test.DumpState"`. If it's a voice-resolution problem, set `log_level = "debug"`, reproduce, and send the `AudioUtil.log` from that run.
