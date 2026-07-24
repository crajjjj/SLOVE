# Classic SexLab port (`classic-sl` branch)

This branch retargets SLO VE from **SexLab Framework P+** (the 2.x SLPP fork,
with SexLab Scene Builder / SexlabRegistry and node-collision physics) to
**classic SexLab Framework SE 1.63**. It is an in-place rewrite: the whole
branch *is* the classic variant. `main` stays on P+.

## Required dependencies (classic build)

- **SexLab Framework SE 1.63** (classic) — not P+.
- **SexLab Separate Orgasm (SLSO)** — *required*. Classic SexLab only fires a
  per-thread `OrgasmStart`; SLSO republishes the per-actor `SexLabOrgasmSeparate`
  event SLO VE's voice / expressions / SFX / milk all key off, with identical
  arguments (`PushForm(actor)`, `PushInt(thread.tid)`). Without it, orgasm
  routing degrades to the whole scene. SLSO ships an `sslActorAlias` override —
  let it overwrite SexLab; that override is what emits the event.
- **SLATE + a Hentairim-convention tag database** — *required*. This is what
  supplies the per-stage/per-position labels the whole label engine reads (see
  below). Without a tag database every label falls back to `LDI` (lead-in), and
  SLO VE will play only generic lead-in behaviour.

Install order: `SexLab 1.63 → SLSO → SLATE + tag database → AudioUtil → voice packs → SLO VE (last)`.

## API mapping (P+ → classic 1.63)

The thread type changes from `SexLabThread` (P+) to **`sslThreadController`**
(classic, extends `sslThreadModel`). `SexlabRegistry` **does not exist** in classic.

| P+ call | Classic 1.63 |
|---|---|
| `SexLab.GetThreadByActor(a)` | `SexLab.GetActorController(a)` (player: `GetPlayerController()`) |
| `SexLab.GetThreadByID` / by tid | `SexLab.GetController(tid)` |
| `thread.GetThreadID()` | `thread.tid` |
| `thread.GetTimeTotal()` | `thread.TotalTime` |
| `thread.GetPositions()` | `thread.Positions` |
| `thread.GetPositionIdx(a)` | `thread.Positions.Find(a)` |
| `thread.GetEnjoyment(a)` | `thread.GetEnjoyment(a)` (unchanged) |
| `thread.GetSubmissive(a)` | `thread.IsVictim(a)` |
| `thread.GetSubmissives()` | `thread.Victims` |
| `thread.HasSceneTag(t)` | `thread.HasTag(t)` |
| `thread.DisableOrgasm(a,b)` | `thread.DisableOrgasm(a,b)` (unchanged) |
| `thread.GetActiveScene()` (string) | *n/a* — classic identifies the scene by the `sslBaseAnimation` on `thread.Animation`; stages are **integers** |
| `thread.GetActiveStage()` (string) | `thread.Stage` (int, 1-based) |
| `thread.GetStatus()` (2/3) | *n/a* — classic uses controller states; the P+ busy-waits are dropped (the controller `GetActorController` hands back is already set up) |
| `SexLab.GetSex(a)` | `SexLab.GetGender(a)` — **different scale, comparisons must be rebased**: P+ `GetSex` is `0 male / 1 female / 2 futa / 3 crt-male / 4 crt-female`; classic `GetGender` is `0 male / 1 female / 2 crt-male / 3 crt-female` (no futa). A creature test of `>= 3` becomes `>= 2`, a human test of `<= 2` becomes `<= 1`, and `== 2` (futa) has no classic equivalent. |
| `SexLab.CountFemale(list)` / `CountCreatures(list)` | computed locally from `GetGender` (no framework helper in classic) |
| `SexlabRegistry.GetAllStages(scene)` | `thread.Animation.StageCount` (count only; no per-stage string IDs) |
| `SexlabRegistry.StageExists(scene,stage)` | `1 <= stage <= StageCount` |
| `SexlabRegistry.GetSceneName(scene)` | `thread.Animation` name (adaptive-velocity JSON key; that system is disabled anyway) |
| `SexlabRegistry.IsSceneTag(scene, "1ASVP")` | `thread.Animation.HasTag("1ASVP")` — equivalent via SLATE-applied tags (see below) |
| `SexlabRegistry.GetClimaxingActors/GetClimaxStages` | *no equivalent* — dropped; ending detection uses the SLATE `EN` tags (scanned by the Director), falling back to the last stage |

## Dropped subsystems (no classic equivalent)

1. **SLPP physics / node-collision bridge.** `GetCurrentInteractionFlags`,
   `IsInteractionRegistered`, `GetVelocity`, `GetPartnerByType`/`Rev` are P+-only.
   The Director's physics-label overlay (`ApplyPhysicsLabels`) and `SLOVE_SFX`'s
   SOSBend adaptive-velocity search are removed; `director.usephysicslabels`,
   `sfx.usevelocity` and `sfx.useadaptivevelocity` are forced to `0` at load
   regardless of `SLOVE.toml`. Practical effect: intensity is no longer *measured*
   from live thrust speed — the F/S prefix comes from the authored SLATE label
   itself (`SVP` vs `FVP`), so it tracks the tag database rather than the real
   animation speed or any AnimSpeed override.

   **`sfx.usecontactsfx` is still honoured.** The PPA bridge (Accurate Penetration
   via AudioUtil) is framework-independent — only the *edge detection* and the
   receiver lookup ever used SLPP. `ProcessContactEdges()` therefore derives its
   penetration edge from the label system (`IsGivingVaginalPenetration` /
   `IsGivingAnalPenetration`) and resolves the receiver via
   `ResolvePenetrationReceiver()` — the other position carrying a penetration
   label — instead of `GetPartnerByType`. That preserves both:

     - the **PPA-measured pull-out gape** SFX, with the existing `IsHugePP`
       fallback when PPA is absent, and
     - the **victim-insertion trauma** hook that writes `SLOVE_ResDebt`, which
       `SLOVE_Resistance` consumes — a gameplay feature, not just audio.

   Not ported: the insertion / kiss / oral contact one-shots. On P+ those fire
   *only when the label system has not already classified the act* — they exist to
   catch what labels miss. Deriving the edge from labels makes that guard
   unreachable by construction, so firing them here would be new behaviour rather
   than a port.

That is the **only** dropped subsystem. In particular, per-stage/per-position
labels are **not** lost — see below.

## Per-stage labels: SLATE replaces the registry (no fidelity loss)

An early draft of this port assumed classic had no per-stage/per-position data and
classified from the flat, whole-animation tag list plus heuristics. **That was
wrong**, and the heuristic engine has been removed.

Classic gets the same data through **SLATE**: a SLATE tag database (e.g.
`SKSE/Plugins/SLATE/Hentairim tags.json`) contains entries of the form

```
"addtag, Billyy Doggy 5 Sideways,1ASVP"     ; stage 1, position A, slow vaginal penetration
"addtag, Billyy Doggy 5 Sideways,1BSDV"     ; stage 1, position B, slow "delivering" vaginal
"addtag, Billyy Doggy 5 Sideways,5AENO"     ; stage 5, position A, ending outside
```

SLATE applies these as **ordinary SexLab animation tags**, so the exact query the
P+ build made against the registry works verbatim against the animation:

| P+ | classic |
|---|---|
| `SexlabRegistry.IsSceneTag(sceneId, "1ASVP")` | `thread.Animation.HasTag("1ASVP")` |

`HasTag` is inherited by `sslBaseAnimation` from `sslBaseObject`
(`Tags.Find(Tag) != -1` — whole-string match, case-insensitive via Papyrus
`Find`). `SLOVE_Hentairim_Tags` is therefore the **P+ source verbatim**, with only
the accessor swapped and `anim` retyped from the scene-id `string` to
`sslBaseAnimation`. Every per-position label function is unchanged, and the
Director's EN-tag ending-stage scan is retained.

The practical consequence is that on classic **tag data quality is the whole
ballgame** — hence SLATE and a tag database being hard requirements above.

### ASL fallback layer

Two tag databases exist in the wild, and the classic build reads both:

| database | scheme | example | animations |
|---|---|---|---|
| Hentairim tags | `<stage><POS><LABEL>` | `1ASVP`, `5BENI` | ~2227 |
| ASL / `SLAnimStageLabels` | `<stage><CODE>` (scene-wide) | `3SV`, `6EN` | ~2008 |

The per-position database always wins. When an animation (or an individual stage)
has **no** per-position tag, the label functions fall back to the scene-wide ASL
code via `ASLStageCode()` and derive a per-position label using the same
convention the Hentairim database itself follows — **position A (0) is the
receiver, positions B+ are the givers**:

| ASL code | receiver (A) | giver (B+) | mouth (A) |
|---|---|---|---|
| `SV` / `FV` | `SVP` / `FVP` | `SDV` / `FDV` | — |
| `SA` / `FA` | `SAP` / `FAP` | `SDA` / `FDA` | — |
| `SB` / `FB` | — | `SMF` / `FMF` | `SBJ` / `FBJ` |
| `DP` / `TP` | `SDP` | `SDV` | — |
| `SR` (spitroast) | `SVP` | `SDV` | `SBJ` |
| `EN` | `ENI` | `ENI` | — |

`LI` and the stimulation labels have no ASL equivalent and stay lead-in. This
matters most for **creature and gangbang** animations: 189 animations are
ASL-only, and before this layer every one of them produced `LDI` for every label.

The two schemes cannot collide — Hentairim codes carry an `A`–`E` position letter
where ASL has the label directly, `HasTag` is a whole-string match, and the
fallback only runs after the per-position lookup has already missed.

`GetSFX()` was already scene-wide (`<stage>SC` / `MS` / `NA` …), so it reads the
ASL SFX codes unchanged.

See [framework-adapter.md](framework-adapter.md) for the seam these changes flow through.
