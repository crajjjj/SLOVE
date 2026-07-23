# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Mod Is

**SLO VE — "SexLab / OStim — Voices and Expressions."** ("SLO" = SexLab / OStim; "VE" = Voices and Expressions.)

A **standalone, Papyrus-only** mod that adds scene **voices** (moans + spoken dirty-talk lines) and **facial expressions** to **SexLab P+ (SexLab Framework PPLUS 2.17+)** scenes. Design points:

- **No gameplay systems, no MCM.** All configuration lives in TOML files, live-reloadable in console.
- It is a **slim port/refactor of Hentairim/IVDT** — the source comments repeatedly say "Port of Hentairim's IVDTControllerScript / IVDTSceneTrackerScript / HentairimExpressions." The gameplay-heavy Hentairim systems (linear scenes, foreplay choreography, resistance/broken, HugePP addiction, stage-advance timers, cum shaders) are **stripped out** and left as no-op compatibility stubs so the ported voice/expression logic stays mechanically identical.
- **Mutually exclusive with full Hentairim P+** — run one or the other, not both.
- v1 is **SexLab P+ only**; an OStim backend is planned via the framework-adapter seam (see below) but not yet present.

**Hard requirements:** SKSE64, SexLab P+ 2.17+, **AudioUtil** (sibling SKSE plugin — voice playback, lipsync, TOML config API), PapyrusUtil (JSON preset data), Mfg Fix NG (all face writes).
**Soft/optional:** MFEE (Mu Facial Expression Extended), sr_fillherup (tongue armors), Devious Devices (gag), SexLab Survival (`_SLS_AhegaoStateChange`), SOS/TNG (huge-partner detection), Accurate Penetration via AudioUtilPPA (measured penetration/gape).

## Build

**No `.vscode` folder.** Build config is `SLOVE.ppj` (Pyro project) + `scripts/build.ps1`.

**After any big change, run `docs/smoke-test.md`** — §1–§8 are AI-executable checks (full rebuild, API sync, firewall grep, channel hygiene, TOML parse, config-key sync, BSA/asset path verification); §9 is the in-game handoff list to give the user.

```
powershell scripts\build.ps1        # run from repo root
```

`build.ps1`:
1. Mirrors `papyrus\Source\*.psc` into `dist\Scripts\Source\` (`Copy-Item -Force`).
2. Runs Pyro on `SLOVE.ppj` with `--game-path`.
3. Because the ppj has `Zip="true"`, also writes `Release\SLO VE.zip`.

- **Pyro discovery:** env `PYRO_EXE`, else auto-found at `%USERPROFILE%\.vscode\extensions\joelday.papyrus-lang-vscode-*\pyro\pyro.exe`.
- **Game path:** env `SKYRIM_GAME_PATH`, else `C:\SteamLibrary\steamapps\common\Skyrim Special Edition`.
- **ppj:** `Game="sse"`, `Output="dist\Scripts"`, `Optimize/Release/Final="false"`, `Flags="TESV_Papyrus_Flags.flg"`, `BuildFolder=C:\Playground\Skyrim\mods\build`.
- **The ESP is NOT built by Pyro** — `SLOVE.esp` is authored/edited externally via **houseCARL**.

### Import paths (from `SLOVE.ppj` — several non-obvious)

- `.\papyrus\Source` (own sources)
- `C:\Playground\stubs` (stub scripts)
- `C:\Playground\Skyrim\mods\AudioUtil\papyrus\Source` — **sibling AudioUtil sources; hard compile-time dependency**
- `@BuildFolder\SexLab Framework PPLUS - V2.17.1\Source\Scripts`
- `@BuildFolder\...` — racemenu, SkyrimLovense, UIExtensions, JContainers SE, powerofthree/Required, Papyrus Extender, Mu Facial Expression Extended (MFEE), The New Gentleman/Core, PapyrusUtil AE SE
- `C:\Playground\Skyrim\mods\SKSE\Mfg-Fix-NG\dist\source\scripts` (absolute)
- `C:\SteamLibrary\...\Skyrim Special Edition\Data\Source\Scripts` (vanilla)

## Script Architecture

Eight scripts in `papyrus/Source/`, all prefixed `SLOVE_`. Pattern: **one framework-aware controller (Director) + three per-actor magic-effect consumers (Voice, Expressions, SFX) + static helper/table scripts.**

| Script | Role |
|---|---|
| `SLOVE_Director` | `extends ReferenceAlias`. **The central controller and ONLY framework-aware script** (see [Framework Adapter](#framework-adapter--the-firewall-rule)). Attached to the PlayerAlias of quest `SLOVE_MainQuest`. Owns player-scene detection, the **label state** (tag labels via `SLOVE_Hentairim_Tags` + a physics-label overlay from SLPP node-collision velocity → Slow/Fast prefix with hysteresis), applies the Voice/Expressions/SFX **spells** to actors (runtime-resolved from `SLOVE.esp`: `0x800`=ExpressionsSpell, `0x802`=VoiceSpell, `0x805`=SFXSpell), re-broadcasts `SLOVE_*` mod events, and hosts SFX services (`IsSmallPP`, `SaveSchlongAdjustment`/`LoadSchlongAdjustment` SOSBend memory). Its only CK property is `SexLab` |
| `SLOVE_Voice` | `extends ActiveMagicEffect`. Port of `IVDTSceneTrackerScript`. **Player only.** Female (PC) voice engine, male comment rotation (`PickSpeakingMale` — every scene male can speak, each resolving his own AudioUtil slot), orgasm reaction state machine, voice↔expression sync via the `"HentaiScenario"` StorageUtil key. Large `OnUpdate` ladder maps labels → voice **category** strings (normal + `VarB` variant). CK props: `SexLab`, `MasterScript`, `SceneTrackerSpell` |
| `SLOVE_Expressions` | `extends ActiveMagicEffect`. Port of `HentairimExpressions`. **Per-actor** (PC / male NPC / female NPC per config gates). Drives faces from Director labels + JSON presets, with a cheap "breathing" micro-pass, a 5-phase cache, MFEE ahegao/tongue (Erin/Elin + vanilla), sr_fillherup tongue-armor equipping, mask detection, an AudioUtilPPA measured-penetration path, a jaw-gate, and an SLS-ahegao yield. While the **climax face owns the mouth** (`IsOrgasming` or the huge-partner `brokenface` ahegao) it sets the `SLOVE_FaceOwnsMouth_Expr` StorageUtil marker on the actor (via `ApplyFaceMouthOwnership`) so the Director's `PlaySound` plays that actor's lines with `blockLipSync=true` and a line can't lipsync over the open-mouth face; cleared when the face ends, on `OnEffectStart`/teardown, and relinquished to the Director's `SLOVE_FaceOwnsMouth_SLS` marker during the SLS ahegao. The Director ORs the two markers in `FaceOwnsMouth()` — AudioUtil has **no** standing per-actor block; blocking is decided per line. Preset file per actor: `SLOVE/PCExpressions.json` / `MaleExpressions.json` / `FemaleExpressions.json`. CK props: `MasterScript`, `SexLab` |
| `SLOVE_SFX` | `extends ActiveMagicEffect`. Port of `HentairimSFX`. **Per-actor** (all positions, creatures too; gated by `sfx.enable`). Body-SFX engine: slushing/impact/clap/kissing/blowjob sounds via `AudioUtil.PlaySFX`, picked from SFX scene tags (`SLOVE_Hentairim_Tags.GetSFX`) or labels; optional thrust-synced mode from SLPP collision velocity (`sfx.usevelocity`) with a SOSBend calibration search (`sfx.useadaptivevelocity`, saved via the Director's schlong-adjustment memory); contact-edge one-shots (insertion, PPA-measured pull-out gape, kiss, oral); size-matched ejaculation one-shot on orgasm. Hentairim's resistance/trauma hooks and dead anim-speed escalations dropped. CK props: `SexLab`, `MasterScript` |
| `SLOVE_Hentairim_Tags` | `Hidden` (globals). The **label engine**: classifies SexLab P+ stages into label **codes** by reading scene tags via `SexlabRegistry.IsSceneTag`. Tag convention `<stage><ActorLetter><code>` (e.g. `3A SVP` = stage 3, pos 0, slow vaginal penetration). Position index → letter A–E |
| `SLOVE_VoiceCategories` | `Hidden`. Static tables: `MaleOnlyRemap`, `AllFemaleCategories` (71), `AllMaleCategories` (15). Category names are AudioUtil folder names — no Sound forms or voice aliases exist anywhere |
| `SLOVE_Config` | `Hidden`. Thin wrapper over **AudioUtil's TomlUtil API**; reads `SKSE/Plugins/SLOVE/SLOVE.toml` with dotted keys (`"voice.pcvolume"`). **Fail-open** — if the AudioUtil DLL is missing every getter returns the caller's default. `Available()` gates one warning; `Reload()` for live tuning |
| `SLOVE_Test` | `Hidden`. Console diagnostics: `cgf "SLOVE_Test.AuditVoicePack" "M1"`, `SampleCategory`, `DumpState` |

**Label code vocabulary** (used throughout): `LDI`=lead-in; `S*`/`F*` prefix = Slow/Fast intensity; `VP/AP/CG/AC/DP` = vaginal/anal/cowgirl/anal-cowgirl/double penetration; `MF/HJ/FJ/TF/DV/DA` = penis actions; `SBJ/FBJ/KIS/CUN` = oral; `ENI/ENO` = ending inside/outside; `SST/FST/BST` = stimulation. "Intense" = the concatenated label string contains `"1F"`.

## Framework Adapter — the firewall rule

`docs/framework-adapter.md` defines the seam that makes a future OStim backend possible. **This is a hard invariant — preserve it in every edit:**

- **`SLOVE_Director` is the ONLY script allowed to reference `SexLabFramework` / `SexLabThread` / `SexlabRegistry` or SLPP mod-event names.** `SLOVE_Voice` and `SLOVE_Expressions` talk **only** to the Director's API and `SLOVE_*` events. An OStim backend would be an alternative director (`SLOVE_DirectorOStim`) with the same API surface + a replacement `SLOVE_Hentairim_Tags` (labels are annotation-scheme-specific).
- **SLOVE-owned mod events** (re-broadcast by the Director, framework-independent): `SLOVE_SceneStart`, `SLOVE_StageStart`, `SLOVE_Orgasm`, `SLOVE_SceneEnd`. Third-party event consumed raw: `_SLS_AhegaoStateChange` — by Expressions (pause face writes) **and** the Director (sets the `SLOVE_FaceOwnsMouth_SLS` StorageUtil marker on the player so `PlaySound` plays PC moans with `blockLipSync=true` and they don't lipsync over the SLS face; re-seeded from the `_SLS_IsAhegaoing` key in `Maintenance()`). The face-owns-mouth marker is the union of the Director's SLS flag and Expressions' `SLOVE_FaceOwnsMouth_Expr` flag, read per line in `PlaySound` via `FaceOwnsMouth()` — AudioUtil has no standing per-actor lipsync block.
- **Director API consumed by Voice/Expressions** (thin pass-throughs so consumers never touch `SexLabThread`): `GetPositions`, `GetPositionIdx`, `GetEnjoyment`, `GetTimeTotal`, `HasSceneTag`, `IsSubmissive`, `GetActiveSceneId`, `GetStageNum`, `GetStagesCount`, `GetGender`/`IsMale`; label getters `GetStimulationlabel`/`GetPenisActionLabel`/`GetOralLabel`/`GetEndingLabel`/`GetPenetrationLabel`; latches `GetDirectorLastLabelTime`/`GetDirectorLastPhysicsLabelTime`; lifecycle `AnimationisEnding`, `isUpdating`, `SceneisIntense`, `IsHugePP`, `PlaySound`.
- **Documented acceptable leaks:** `SLOVE_Hentairim_Tags.HasASLTag` calls `SexlabRegistry.IsSceneTag`; `GetLegacyStageNum` uses `SexlabRegistry.GetAllStages`.

## AudioUtil Relationship (deep, load-bearing)

SLO VE is a thin Papyrus layer over the **AudioUtil SKSE plugin** (sibling repo `c:/Playground/Skyrim/mods/AudioUtil`). **AudioUtil owns all audio + config-file reading + slot resolution + lipsync + the penetration bridge; SLO VE decides *what category* to play *when* and hands it an actor.**

- **Voice playback:** `SLOVE_Director.PlaySound` → `AudioUtil.Play(category, actor, wait, 1.0, group, channel)`. AudioUtil resolves the actor's **voice slot** (voicetype/race/NPC-override). SLO VE ships **no Sound forms and no voice aliases**.
- **Body SFX:** `SLOVE_SFX` calls `AudioUtil.PlaySFX(name, actor, 1.0, "sfx", channel)` — names resolve as categories of the preset's **`SFX0` slot** (`sex = "all"`; audio under `Sound\fx\SloveSFX`), which AudioUtil checks before the flat `[sfx]` table; channels `sfx_main_<pos>` / `sfx_contact_<pos>` keep each actor's stream and one-shots from cutting each other off.
- **Config API:** `SLOVE_Config` reads all settings through AudioUtil's **TomlUtil** (`TomlUtil.GetInt/GetFloat/GetString/GetBool/Reload/GetAPIVersion`).
- **Ducking/volume:** `SLOVE_Voice` calls `AudioUtil.DuckGroup/UnduckGroup/StopGroup/SetGroupVolume` for the four voice groups `pc_low`, `pc_high`, `partner_low`, `partner_high`.
- **Measured penetration (AudioUtilPPA):** `SLOVE_Expressions` calls `AudioUtilPPA.IsConnected/GetContext/GetDepth` — when the Accurate Penetration bridge is tracking an actor, penetration checks use **measured** state (context bitmask 1=vaginal, 2=anal + nonzero depth) instead of authored labels.
- **Diagnostics:** `SLOVE_Test` uses `AudioUtil.CategoryExists/PlayVoiceFromSlot/GetSlotForActor`.
- **Voice-slot preset (two files):** AudioUtil merges a base `AudioUtil.toml` then every `config\*.toml` overlay, with **globals base-only** (see the gotcha below). SLO VE therefore splits its preset in two, both under `SKSE\Plugins\AudioUtil\` (**install SLO VE last** so its base wins): `AudioUtil.toml` = the **globals + routing** (`[general]`/`[ppa]`/`[lipsync]`/`[gag]`, voicetype/race maps, category aliases, `[male_only_remap]`, fallbacks, `[groups]`), and `config\SLOVE_slots.toml` = the **additive content** (all `[[slot]]`, including the `SFX0` sfx slot). Female scheme: **F0/F0B = stock moan slots** (SexLab's own `vFemaleMoan01`/`03` via per-category folder refs into `Sound\fx\SexLab`; F0 is `default_female_slot`), **F1 = player pack slot**, **F2/F3 = partner/follower pack slots** — the pack slots scan `Sound\fx\IVDT\F<n>` and backfill per-category from the stock slots via the slot `fallback` key, so any Hentairim-convention pack dropped in just works. Plus M1–M8 (bundled Hentairim male packs), C1–C10 (creatures from vanilla BSAs; `sex = "all"` so they resolve regardless of the creature's reported sex).

## ESP Plugin

`dist/SLOVE.esp` is **ESL-flagged** (ESP-FE), authored externally via **houseCARL** (not by the build). Masters: Skyrim.esm, SexLab.esm. Records:
- **Quest `SLOVE_MainQuest`** (`0x804`) with a **player ReferenceAlias** carrying `SLOVE_Director` (start-game-enabled → hence `dist/Seq/SLOVE.seq`; regenerate the SEQ if the master list ever changes — the stored prefix shifts).
- **Three spells at fixed FormIDs**, each holding an ActiveMagicEffect: `0x800` → Expressions spell (`SLOVE_Expressions`, ME `0x801`), `0x802` → Voice spell (`SLOVE_Voice`, ME `0x803`, whose `SceneTrackerSpell` points at itself), `0x805` → SFX spell (`SLOVE_SFX`, ME `0x806`). Resolved at runtime via `Game.GetFormFromFile(..., "SLOVE.esp")` — **not CK-filled properties.** Changing these FormIDs in the ESP breaks the scripts.
- **No MCM.**

## Distribution Layout (`dist/`)

```
dist/
  SLOVE.esp                                    ← ESL-flagged plugin (houseCARL-authored)
  Seq/SLOVE.seq                                ← start-enabled quest SEQ
  Scripts/SLOVE_*.pex                          ← 7 compiled scripts (Pyro)
  Scripts/Source/SLOVE_*.psc                   ← generated mirror of papyrus/Source (build.ps1)
  SKSE/Plugins/SLOVE/SLOVE.toml                ← all settings ([director][voice][expressions][sfx][milk])
  SKSE/Plugins/AudioUtil/AudioUtil.toml        ← preset GLOBALS + routing maps (base file; must win load order)
  SKSE/Plugins/AudioUtil/config/SLOVE_slots.toml ← preset CONTENT: [[slot]] voice packs + SFX0 sfx slot (additive overlay)
  SKSE/Plugins/StorageUtilData/SLOVE/*.json    ← PCExpressions / MaleExpressions / FemaleExpressions
                                                  / Masks / NPCTongue / ErinMFEEConfig
  Sound/fx/IVDT/{M1..M8,Sounds}/               ← bundled male voice packs + Smack/PullOutGape one-shots
  Sound/fx/SloveSFX/                           ← bundled body-SFX library (slushing/impacts/claps/etc.);
                                                  mapped as the SFX0 slot's categories, no v1 script driver
                                                  (all audio copied from Hentairim p+ 3.0.4; git-ignored, zipped by Pyro)
```

Female voices default to SexLab's own moan sets (referenced in place, not bundled; F0 = stock default, F1 = player pack slot, F2/F3 = partner/follower pack slots — a Hentairim-convention pack dropped into `Sound\fx\IVDT\F<n>` is a zero-config upgrade). Scene tag data is external.

## Gotchas & Non-obvious Details

- **Edit sources in `papyrus/Source/`.** `dist/Scripts/Source/` is a build-generated mirror (`build.ps1` overwrites it).
- **The Director is the framework firewall** — never add SexLab/SexlabRegistry/SLPP calls to Voice or Expressions (see [Framework Adapter](#framework-adapter--the-firewall-rule)).
- **Spells resolve by hardcoded FormID** (`0x800`/`0x802`/`0x805` in `SLOVE.esp`) at runtime, not via CK properties — changing those FormIDs breaks the scripts.
- **AudioUtil is a hard build-time AND runtime dependency**; the config layer fails open if its DLL is absent.
- **Preset split follows AudioUtil's base-only-globals rule.** AudioUtil reads global sections (`[general]`/`[ppa]`/`[lipsync]`/`[gag]` toggles) **only from the base `AudioUtil.toml`** — an overlay that sets them is ignored + warned. That's why globals live in `AudioUtil.toml` and only the additive `[[slot]]`/`[sfx]` content goes in `config\SLOVE_slots.toml`. `[gag].keywords` is additive so it *could* live in the overlay, but is kept with the rest of `[gag]` in the base for readability. The preset sets **no `voice_root`/`sfx_root`** — every slot `path` and every `[sfx]` value is a full `Sound\...` path, so nothing depends on a shared root global.
- The **ESP is authored/edited through houseCARL**, outside the Pyro build.
- Voice categories are **strings that must match AudioUtil folder names / TOML keys** — the `AllFemale/AllMaleCategories` tables in `SLOVE_VoiceCategories.psc` are the source of truth (audit with `SLOVE_Test.AuditVoicePack`).
- Live config reload in-game: `cgf "SLOVE_Config.Reload"` (SLOVE.toml) and `cgf "AudioUtil.ReloadConfig"` (voice slots).
