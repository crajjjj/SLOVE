# Framework adapter contract (SexLab P+ today, OStim later)

`SLOVE_Director` is the ONLY script allowed to reference `SexLabFramework`,
`SexLabThread`, `SexlabRegistry`, or SLPP mod-event names. Voice and
expressions consume the director's API and the SLOVE-owned mod events below.
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
`SLOVE_Expressions` (pause face writes) and by `SLOVE_Director` (toggle
`AudioUtil.SetLipSyncBlocked(player)` so PC moans don't drive the mouth over the SLS face;
re-seeded from the `_SLS_IsAhegaoing` StorageUtil key in `Maintenance()`).

## Director API consumed by SLOVE_Voice / SLOVE_Expressions

Scene state: `GetPositions()`, `GetPositionIdx(a)`, `GetEnjoyment(a)`,
`GetTimeTotal()`, `HasSceneTag(t)`, `IsSubmissive(a)`, `GetActiveSceneId()`,
`GetStageNum()`, `GetStagesCount()`, `GetGender(a)` / `IsMale(a)`.

Labels: `GetStimulationlabel(a)`, `GetPenisActionLabel(a)`, `GetOralLabel(a)`,
`GetEndingLabel(a)`, `GetPenetrationLabel(a)`; latches
`GetDirectorLastLabelTime()`, `GetDirectorLastPhysicsLabelTime()`.

Lifecycle/services: `AnimationisEnding()`, `isUpdating()`, `SceneisIntense()`,
`IsHugePP(a)`, `PlaySound(category, actor, wait, group)`.

Known leaks (documented, acceptable): `SLOVE_Hentairim_Tags.HasASLTag` calls
`SexlabRegistry.IsSceneTag`; `GetLegacyStageNum` uses
`SexlabRegistry.GetAllStages` (director-internal).
