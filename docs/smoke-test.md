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

## 4. Channel hygiene (no stacking regressions)

Every AudioUtil play call that can repeat must carry an exclusivity channel:

```
grep -n 'PlaySFX(.*"sfx")$'  "SLO VE/papyrus/Source"/*.psc   # channel-less SFX
grep -n 'MasterScript.PlaySound(' "SLO VE/papyrus/Source/SLOVE_Voice.psc"
```

**Pass:** first grep returns nothing; every voice `PlaySound` forward includes
a `voiceChannel`/`slove_np...` channel argument. Known-good channel scheme:
`slove_pc` / `slove_np<formid>` (voice), `sfx_main_/sfx_contact_/sfx_impact_/
sfx_slush_/sfx_ejac_<position>` (SFX).

## 5. TOML validity + expected shape

Parse all three shipped configs (a parse error makes AudioUtil keep prior/neutral
settings silently). The AudioUtil preset is two files — the globals-only base
`AudioUtil.toml` and the content overlay `config\SLOVE_voices.toml`:

```
python -c "import tomllib; tomllib.load(open(r'...\AudioUtil.toml','rb'))"
python -c "import tomllib; tomllib.load(open(r'...\config\SLOVE_voices.toml','rb'))"
python -c "import tomllib; tomllib.load(open(r'...\SLOVE.toml','rb'))"
```

**Pass:** all parse; the base `AudioUtil.toml` has only `[general]`/`[ppa]`/
`[lipsync]`/`[gag]` (no `[[slot]]`/routing — those are overlay-only); and in
`SLOVE_voices.toml`, creature slots C1–C10 each expose `Orgasm` (plus
`Breathing` where material exists — C8 legitimately has none), `[race_map]`
contains the creature hints incl. `Husky`, and the `[sfx]` / `SFX0` slot is present.

## 6. Config-key sync (scripts ↔ SLOVE.toml)

Extract every `SLOVE_Config.Get*("<key>", ...)` string from the scripts and
check each dotted key exists in `SLOVE.toml`. Getters are fail-open (missing
key = silent default), so drift here is invisible in-game.

**Pass:** every script key present in the TOML (or consciously documented as
default-only). Flag keys present in TOML but read by no script (dead config).

## 7. Asset-path verification (the dog lesson)

File lists and folders in the shipped SLOVE_voices.toml must point at things that
exist — **never trust a path that wasn't checked**; most creature paths once
shipped fabricated:

- BSA paths (creature slots): list `Skyrim - Sounds.bsa` via
  `housecarl_bsa_list` and verify **every** `Sound\FX\...` entry in the C-slot
  file lists appears in the archive (case-insensitive).
- Loose SFX folders (`[sfx]` table, relative to `Sound\fx\SloveSFX` unless
  a full path is given) and voice-pack roots: verify the folders exist in
  `SLO VE/dist` (or the installed mods dir) where they are expected to ship.

**Pass:** zero missing paths. Any miss = silent in-game silence, exactly like
the original silent-dog bug.

## 8. Category-reference sync (scripts ↔ voice data)

Category strings the engine requests must resolve somewhere: the tables in
`SLOVE_VoiceCategories.psc`, hardcoded requests (`"Orgasm"`, `"Breathing"`,
`"Smack"`, `"PullOutGape"`, SFX names in `SLOVE_SFX.psc`), against slot
folders / `[category_aliases]` / `[male_only_remap]` / `[sfx]` in `SLOVE_voices.toml`.
Spot-check any **newly added** category string end-to-end.

**Pass:** every new/changed category resolves by the documented chain
(exact → aliases → male_only_remap → fallbacks → sfx).

---

## 9. In-game handoff (user-run — AI cannot verify audio/visuals)

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
4. **Body SFX** (`sfx.enable=1`): slush/impact track thrusts, successive
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

---

**Reporting:** summarize as a per-section pass/fail table, list every failing
item with file:line or log evidence, and stop short of declaring the change
"verified" until the user confirms §9 (or explicitly waives it).
