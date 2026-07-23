# Framework adapter contract (SexLab P+ today, OStim later)

`SLOVE_Director` is the ONLY script allowed to reference `SexLabFramework`,
`SexLabThread`, `SexlabRegistry`, or SLPP mod-event names. Voice, expressions
and SFX consume the director's API and the SLOVE-owned mod events below.
An OStim backend = an alternative director (`SLOVE_DirectorOStim`) providing
the same surface, plus a replacement `SLOVE_Hentairim_Tags` (labels are
annotation-scheme-specific).

## Mod events (re-broadcast by the director)

| Event | args |
|---|---|
| `SLOVE_SceneStart` | strArg = thread/scene id |
| `SLOVE_StageStart` | strArg = thread id |
| `SLOVE_Orgasm` | sender = orgasming Actor, numArg = thread id |
| `SLOVE_SceneEnd` | strArg = thread id |

Third-party events consumed raw (framework-independent): `_SLS_AhegaoStateChange` — by
`SLOVE_Expressions` (pause face writes) and by `SLOVE_Director` (set the
`SLOVE_FaceOwnsMouth_SLS` marker on the player so `PlaySound` plays PC moans with
`blockLipSync=true` and they don't drive the mouth over the SLS face; re-seeded from the
`_SLS_IsAhegaoing` StorageUtil key in `Maintenance()`). `PlaySound` blocks lipsync per line
when `FaceOwnsMouth(actor)` — the union of the SLS marker and `SLOVE_Expressions`'
`SLOVE_FaceOwnsMouth_Expr` marker — is set; AudioUtil has no standing per-actor block.

## Director API consumed by SLOVE_Voice / SLOVE_Expressions / SLOVE_SFX

Scene state: `GetPositions()`, `GetPositionIdx(a)`, `GetEnjoyment(a)`,
`GetTimeTotal()`, `HasSceneTag(t)`, `IsSubmissive(a)`, `GetActiveSceneId()`,
`GetStageNum()`, `GetStagesCount()`, `GetGender(a)` / `IsMale(a)`.

Labels: `GetStimulationlabel(a)`, `GetPenisActionLabel(a)`, `GetOralLabel(a)`,
`GetEndingLabel(a)`, `GetPenetrationLabel(a)`; latches
`GetDirectorLastLabelTime()`, `GetDirectorLastPhysicsLabelTime()`.

Lifecycle/services: `AnimationisEnding()`, `isUpdating()`, `SceneisIntense()`,
`IsHugePP(a)`, `IsSmallPP(a)`, `PlaySound(category, actor, wait, group)`,
`SaveSchlongAdjustment(pos, val)` (SFX adaptive-velocity SOSBend memory; the
director replays it via `LoadSchlongAdjustment()` on stage change).

Known leaks (documented, acceptable): `SLOVE_Hentairim_Tags.HasASLTag` calls
`SexlabRegistry.IsSceneTag`; `GetLegacyStageNum` uses
`SexlabRegistry.GetAllStages` (director-internal). Pragmatic port leaks:
`SLOVE_Voice` and `SLOVE_SFX` still hold their own `SexLabThread` handle for
high-frequency reads (positions, velocity, interaction flags/partners, stage
tags) — an OStim backend must give their director-equivalents the same data
or these reads must move behind the director API first.
