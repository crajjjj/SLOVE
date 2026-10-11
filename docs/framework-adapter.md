# Framework adapter contract (SexLab P+ and classic 1.63 today, OStim later)

`SLOVE_Director` is the ONLY script allowed to reference `SexLabFramework`,
`SexLabThread` / `sslThreadController`, `SexlabRegistry`, or raw SexLab
mod-event names.

A second backend already exists: the classic SexLab 1.63 script set under
`papyrus/classic/Source` (see `classic-sexlab-port.md`). It is a parallel copy of
the six framework-facing scripts rather than an alternative director, because the
consumers hold their own thread handles (the "pragmatic port leaks" below). Voice, expressions
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

Third-party events consumed raw (framework-independent): `_SLS_AhegaoStateChange` - by
`SLOVE_Expressions` (pause face writes) and by `SLOVE_Director` (set the
`SLOVE_FaceOwnsMouth_SLS` marker on the player so `PlaySound` plays PC moans with
`blockLipSync=true` and they don't drive the mouth over the SLS face; re-seeded from the
`_SLS_IsAhegaoing` StorageUtil key in `Maintenance()`). `PlaySound` blocks lipsync per line
when `FaceOwnsMouth(actor)` - the union of the SLS marker and `SLOVE_Expressions`'
`SLOVE_FaceOwnsMouth_Expr` marker - is set; AudioUtil has no standing per-actor block.

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

Scene identity (0.7.4): `IsRunningScene(threadId)` is true while the scene on
that thread is the player scene the director is running, and `PCInSex()` while
it runs any. `SLOVE_Voice` asks the first on every cycle and ends itself on a
no: its other two end signals (an `AnimationEnd` carrying the thread id it read
at its start, and the 3 s `AnimationisEnding()` window) can both be missed, and
an engine that missed them used to talk on after the scene. It asks the second
before it takes its spell off at the end of its teardown, so that a scene started
in the meantime keeps the copy the director has just given it.

Classic only: `LiveThread(a)` is the controller of the live scene an actor is
in. Classic SexLab keeps a finished thread's actors listed for about 10 s (its
`Frozen` state) and `GetActorController` / `GetPlayerController` return the
first slot that still lists the actor, which in back-to-back scenes is the dead
one. The classic director adopts through `LiveThread`, and the classic
`SLOVE_Expressions` / `SLOVE_SFX` / `SLOVE_Resistance` / `SLOVE_NpcScene` bind
their own thread handle through it. SexLab P+ has no counterpart because its
`GetThreadByActor` already skips threads that are ending.

Resistance state (written by `SLOVE_Resistance` into StorageUtil, read back
through the Director so consumers stay firewall-clean): `GetResistance(a)`,
`IsBroken(a)` - both gated on `resistance.enable`, consumed by
`SLOVE_Voice.ASLIsBroken()` and `SLOVE_Expressions.IsBroken()`.

Known leaks (documented, acceptable): `SLOVE_Hentairim_Tags.HasASLTag` calls
`SexlabRegistry.IsSceneTag`; `GetLegacyStageNum` uses
`SexlabRegistry.GetAllStages` (director-internal). Pragmatic port leaks:
`SLOVE_SFX` and `SLOVE_Resistance` still hold their own
`SexLabThread` handle for high-frequency reads (positions, velocity, interaction
flags/partners, stage tags, enjoyment) - an OStim backend must give their
director-equivalents the same data or these reads must move behind the director
API first. `SLOVE_Resistance` additionally resolves the Director alias and the
SexLab quest by FormID at runtime (no CK-filled properties).

**`SLOVE_Voice` is UNIFIED** (0.6.20): its port leak is resolved - every SexLab
read goes through the director API, one source/one pex serves both variants
from the FOMOD Core, and `papyrus\classic\Source` deliberately carries no copy.
The unification added to both directors: `GetThreadID()`, `HasSubmissives()`,
`GetPenisActionLabelAtPos(pos)` (the per-position label whose
`SLOVE_Hentairim_Tags` signature is annotation-scheme-specific), and folded the
classic SLSO `GetFullEnjoyment()` merge into the classic director's
`GetEnjoyment` - it is framework truth, not voice policy. NOTE this reaches only
consumers that go THROUGH the director (Voice today): `SLOVE_Expressions` keeps
its own SLSO merge and `SLOVE_NpcScene` / `SLOVE_Resistance` still read their own
thread raw, so enjoyment stays 0 for them under the SLSO minigame. They cannot
simply call the director - they run on NPC-scene threads it knows nothing about. The build's `Assert-VariantTypes`
fails if a direct framework type ever reappears in the unified pex, or if a
stale `SLOVE_Voice.pex` shows up in `dist-classic` (it would shadow the Core
copy). `SLOVE_NpcScene` stays duplicated on purpose: it tracks NPC scenes on
its own thread handle, and the director API answers only for the PC's scene.
