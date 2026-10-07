# SLO VE — post-change smoke test (AI-runnable)

Procedure for an AI session to run **after any big change** to SLO VE (or to
AudioUtil when SLO VE consumes the change). Every check in §1–§8 is executable
with dev-environment tools — run them all and report pass/fail per section.
§9 is the short in-game handoff for the user: the things that can only be
verified by playing.

Paths below assume the repos at `c:\Playground\Skyrim\mods\SLO VE` and
`c:\Playground\Skyrim\mods\AudioUtil`.

---

## 1. Build gate (always)

Full recompile, not incremental — Pyro skips unchanged sources, which hides
arity breaks when a shared script (AudioUtil.psc) changed signatures:

```
rm "SLO VE/dist/Scripts"/*.pex   # force full recompile
pwsh -NoProfile -File "SLO VE/scripts/build.ps1"
```

**Pass:** `N succeeded, 0 failed` where N = number of .psc files in
`papyrus/Source`. If AudioUtil C++ changed: `xmake` + `xmake build papyrus`
there first (also delete its `dist/Scripts/*.pex` if AudioUtil.psc changed).

The same run checks the settings (section 6), builds the settings-menu plugin
(`skse\` -> `dist\SKSE\Plugins\SLOVE.dll`) and runs its `core-tests` against the
shipped `SLOVE.toml`. **Pass, in addition:** `settings sync check OK`,
`SLOVE.dll <version> OK (x64, core-tests passed)` and, when the FOMOD is
packaged, `release check OK`. The build fails by itself if a folder named
`SLOVE` appears in the live mods directory (`%XSE_TES5_MODS_PATH%`): see the
install trap in `CLAUDE.md`.

## 2. Native API sync (when AudioUtil changed)

Every native declared in `AudioUtil/papyrus/Source/AudioUtil.psc` must have a
matching `REGISTERFUNC(<name>, ...)` in `AudioUtil/src/PapyrusAPI.cpp`, and
vice versa (same for AudioUtilPPA / TomlUtil script names). Grep both lists and
diff the name sets.

**Pass:** sets identical. Also: if any existing native's **parameter list**
changed, confirm §1 was run with the pex-delete (stale consumer pex = runtime
"incorrect number of arguments" failures that compile checks cannot catch).

## 3. Framework firewall (architecture invariant)

`SLOVE_Director` is the only script allowed to make *new* framework
references:

```
grep -n "SexLabFramework\|SexLabThread\|SexlabRegistry" "SLO VE/papyrus/Source"/*.psc
```

**Pass:** every hit outside `SLOVE_Director.psc` belongs to the accepted
baseline (as of 2026-07): in `SLOVE_Voice` / `SLOVE_Expressions` / `SLOVE_SFX`
only the CK-filled `SexLabFramework Property SexLab`, the
`SexLabThread CurrentThread` variable, and the duplicated legacy-stage helper
(`SexlabRegistry.GetAllStages` / `StageExists`); in `SLOVE_Hentairim_Tags`
the two documented leaks (`HasASLTag`, `GetLegacyStageNum`). **Any hit not on
this list = firewall breach** — a new OStim-blocking dependency; see
`docs/framework-adapter.md`. (Note: CLAUDE.md states the rule more strictly
than the code has ever satisfied; judge new code against this baseline, and
shrink the baseline when refactoring allows, never grow it.)

## 3a. SexLab P+ version gate (one build for P+ 2.17+)

The P+ script set is compiled against the 2.19 headers but must also run on
P+ 2.17 / 2.18, where three members do not exist: `GetInteractionFlags`,
`GetPartnerByInteractionType`, `GetInteractionVelocity`. Papyrus binds a
member call when it is dispatched, so each of them has to sit behind
`InteractionsLive()` (version probe first - `SLOVE_Utils.HasInteractionAPI`).

```
powershell scripts\check-pplus-compat.ps1
```

It runs two checks. **Gate audit:** every function in `papyrus\Source` that
calls one of the three checks `InteractionsLive()` before the call; the only
accepted exceptions are the two velocity reads in `SLOVE_SFX`
(`CalculateAndPlayVelocitySFX`, `RunAdaptiveVelocitySFX`), which need a
`FuckingPartner` that only the gated `UpdateFuckingPartner` sets. **Stubbed
compile:** the P+ set is compiled against each older P+'s headers with ONLY
those three functions declared on its `SexLabThread`.

**Pass:** audit clean and every script compiles for each header set. A
compile error names a fourth member an older P+ lacks: gate it the same way
and add it to the script's stub list. In-game confirmation is use case D6.

## 4. Channel hygiene (no stacking regressions)

Every AudioUtil play call that can repeat must carry an exclusivity channel:

```
grep -n 'PlaySFX(.*"sfx")$'  "SLO VE/papyrus/Source"/*.psc   # channel-less SFX
grep -n 'MasterScript.PlaySound(' "SLO VE/papyrus/Source/SLOVE_Voice.psc"
```

**Pass:** first grep returns nothing; every voice `PlaySound` forward includes
a `voiceChannel` / `SLOVE_Utils.VoiceChannel(...)` channel argument (that helper
is the one spelling of the voice channel names - the mute events stop a line by
it, so a play site that builds the name itself can drift). Known-good channel scheme:
`slove_pc` / `slove_np<formid>` (voice), `sfx_main_/sfx_contact_/sfx_impact_/
sfx_slush_/sfx_ejac_<position>` (SFX).

## 5. TOML validity + expected shape

Parse every shipped config (a parse error makes AudioUtil keep prior/neutral
settings silently). The AudioUtil preset is the globals-only base `AudioUtil.toml`
plus four content overlays under `config\`:

```
python -c "import tomllib; tomllib.load(open(r'...\AudioUtil.toml','rb'))"
python -c "import tomllib,glob; [tomllib.load(open(f,'rb')) for f in glob.glob(r'...\config\SLOVE_*.toml')]"
python -c "import tomllib; tomllib.load(open(r'...\SLOVE.toml','rb'))"
```

**Pass:** all parse; the base `AudioUtil.toml` has only `[general]`/`[ppa]`/
`[lipsync]`/`[gag]` (no `[[slot]]`/routing - those are overlay-only); in
`SLOVE_creatures.toml`, creature slots C1-C10 each expose `Orgasm` (plus
`Breathing` where material exists - C8 legitimately has none) and `[race_map]`
contains the creature hints incl. `Husky`; and the `SFX0` slot is present in
`SLOVE_voices.toml`. No slot id may appear in two overlays (a duplicate silently
replaces the whole slot), and no `[[slot]]` may lack both `path` and
`[slot.categories]` (AudioUtil skips those outright).

## 6. Settings sync (scripts ↔ SLOVE.toml ↔ menu ↔ docs)

```
powershell -NoProfile -ExecutionPolicy Bypass -File "SLO VE/scripts/check-config.ps1"
```

`build.ps1` runs it first, so a green section 1 includes it; run it alone after
touching a setting, the menu schema or the settings docs. Getters are fail-open
(a missing key = the script's fallback literal, silently), so drift is invisible
in game. It fails when:

- the keys the scripts read (`SLOVE_Config.Get*`, both trees), the keys in
  `SLOVE.toml` and the `[[setting]]` entries of `SLOVE_Menu.toml` are not the
  same set, or a key is read with a getter of another type than its TOML value;
- a menu control cannot edit its key's type, a shipped value is outside its
  `min`/`max`, or the schema is not plain ASCII;
- a key has no row in `docs\config\slove.md`, or the row's Default is not the
  shipped value;
- the volume buses the scripts set differ from the table in
  `skse\src\Bridge.cpp`, or a tooltip says "Applies at once" for a key that
  table does not hold (or the other way round);
- the SKSE Menu Framework exports `skse\src\Env.cpp` probes differ from the
  ones the menu code calls, or the vendored framework header was edited.

**Pass:** `settings sync check OK`. A warning that `TomlEdit.h` differs from
AudioUtil's means: copy AudioUtil's over the one in `skse\src\core` again
(never edit the copy) and rerun the build, which reruns `core-tests`.

## 7. Asset-path verification (the dog lesson)

File lists and folders in the shipped overlays must point at things that
exist — **never trust a path that wasn't checked**; most creature paths once
shipped fabricated:

- BSA paths (creature slots): list `Skyrim - Sounds.bsa` via
  `housecarl_bsa_list` and verify **every** `Sound\FX\...` entry in the C-slot
  file lists appears in the archive (case-insensitive).
- Loose SFX folders (`[sfx]` table, relative to `Sound\fx\SloveSFX` unless
  a full path is given) and voice-pack roots: verify the folders exist in
  `SLO VE/dist` (or the installed mods dir) where they are expected to ship.

- Tongue meshes: `python tools\tonguefit\fit_tongues.py --check` (the Khajiit and
  Argonian copies under `dist\meshes\SLOVE\tongues` are what the offsets in that
  script produce from the standard ten). `build.ps1` also fails when `SLOVE.esp`
  names a tongue mesh that `dist\meshes` does not hold.

**Pass:** zero missing paths. Any miss = silent in-game silence, exactly like
the original silent-dog bug.

## 8. Category-reference sync (scripts ↔ voice data)

Category strings the engine requests must resolve somewhere: the tables in
`SLOVE_VoiceCategories.psc`, hardcoded requests (`"Orgasm"`, `"Breathing"`,
`"Smack"`, `"PullOutGape"`, SFX names in `SLOVE_SFX.psc`), against slot
folders / `[category_aliases]` / `[male_only_remap]` / `SFX0` in the overlays.
Spot-check any **newly added** category string end-to-end.

**Pass:** every new/changed category resolves by the documented chain
(exact → aliases → male_only_remap → fallbacks → sfx).

---

## 9. In-game handoff (user-run — AI cannot verify audio/visuals)

For a **release** regression pass (verifying every feature still works, not just
that a change compiled), walk the full use-case matrix in
[`use-cases.md`](use-cases.md) instead — it is the functional companion to this
file. The short list below is the minimum in-game handoff after a code change.

Report this list to the user after §1–§8 pass. Debug toggles first:
`director.printdebug=1`, `voice.printdebug=1`, `sfx.printdebug=1` in
SLOVE.toml (back to 0 afterwards). Static probes need ConsoleUtil.

1. **Probes:** `SLOVE_Test DumpState`, `SLOVE_Test SampleCategory F1 Moan`,
   `... C7 Orgasm`, `... C7 Breathing` — each plays audibly.
2. **Human scene:** PC moans + lipsync mouth; male comments in own voice; no
   same-speaker overlap; orgasm lines both sexes; silence + neutral face at end.
3. **Dog/husky scene:** console `scene creatures voiced: 1`; pant/whine every
   ~5–12 s (faster when intense); climax whine replaces a running breath; no
   human lines from the creature.
4. **Body SFX** (`sfx.enable=1`): slush/impact rate follows the thrusting, successive
   slushes replace, ejac one-shot at climax, kiss SFX, all stop at scene end.
5. **SLS ahegao** (SLS ≥ 0.707): face + moan-lipsync yield while active
   (moans stay audible — played with `blockLipSync=true`, so the mouth stays on
   the SLS face); survives save→reload mid-ahegao (Director re-seeds
   `SLOVE_FaceOwnsMouth_SLS` from `_SLS_IsAhegaoing` in `Maintenance()`).
6. **Mid-scene save/load:** scene re-adopts within ~3 s, no orphaned spells.
7. **Resistance** (`resistance.enable=1`; `director.printdebug=1` logs the drain):
   sustained penetration drains willpower and eventually **breaks** the actor →
   broken/begging voice lines + broken/ahegao face. `resistance.enablebrokenstatus=0`
   keeps the broken face but not the broken voice. A mid-scene save→reload does
   **not** reset the drain (willpower persists, no re-recovery); setting
   `resistance.enable=0` + reload drops any broken state.
8. **Log sweep:** `AudioUtil.log` free of `no slot resolvable` / `unknown slot`
   / `no readable PCM wav` spam.
9. **Settings menu** (with SKSE Menu Framework): section G of
   [`use-cases.md`](use-cases.md), at least G1 to G4. `SKSE\SLOVE.log` is the
   plugin's own log (not the script log `SLOVE.0.log`).

---

**Reporting:** summarize as a per-section pass/fail table, list every failing
item with file:line or log evidence, and stop short of declaring the change
"verified" until the user confirms §9 (or explicitly waives it).
