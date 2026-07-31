# Tuning Cunnilingus Detection (P+)

Cunnilingus is the one action SLO VE cannot infer from animation tags alone reliably — most animations that involve it are tagged only `Oral` / `Cunnilingus` as a *category*, not as a live, per-frame signal of whose mouth is on whom. On **SexLab P+** the `CUN` label instead comes from SexLab's own **live collision detector**, which measures the licker's mouth against the target's genital nodes each update. SLO VE just reads the result.

This page explains which SexLab settings govern that detection and how to tune them. **These are SexLab settings, not SLO VE settings** — SLO VE has no knob that changes them (see [The SLO VE knobs do nothing](#the-slo-ve-knobs-do-nothing) below).

!!! info "P+ only"
    Classic SexLab 1.63 has no live NiType/collision detector, so `CUN` there can only come from an animation's static tags. Everything on this page applies to **SexLab P+** only. See [SexLab Flavours](sexlab-flavours.md).

## How `CUN` is produced

For SLO VE to voice/express cunnilingus, SexLab must first classify the licker's mouth as an **oral interaction with a female target**:

1. **The detector runs** — SexLab's legacy NiType detector (`GetHeadVaginaInteractions`) measures the licker's mouth node against the **target's `Clitoral1` node** every update.
2. **Two gates must pass** — the mouth must be *close enough* to the clitoris **and** the head must be *aligned enough* with the vaginal axis (both thresholds below).
3. **It emits `aOral`** toward the target — flag `f[12]` in SexLab's interaction flags.
4. **SLO VE reads it** — `aOral` toward a **female** target ⇒ the `CUN` oral label; toward a male it would be a blowjob (`SBJ`/`FBJ`) instead.

If any step fails, no `CUN`: no cunnilingus voice line, no cunnilingus face, and (with `enabletongue=1`) no contact tongue.

## Requirements before tuning helps

Tuning the thresholds only matters once these are true:

- [x] **SexLab P+** (not classic).
- [x] **`bUseLegacyNiType = 1`** in `SexLab.ini` (section `[Legacy_NiType]`). The *modern* detector's "oral" geometry is built from a **penis** — it never evaluates a mouth against a vagina — so with the legacy detector off, cunnilingus is **never** detected from collision, only from static tags. This is on by default in current P+ builds.
- [x] **The target's body exposes a `Clitoral1` node.** 3BA and most modern female bodies have it; a body without it can never be detected as a cunnilingus target no matter how loose the thresholds are.

## The two settings that matter

Both live in **`Data\SKSE\Plugins\SexLab.ini`** and are read **once at load**. They are *not* settable from Papyrus at runtime.

| Setting | INI section | Default | What it gates |
|---|---|---|---|
| **`fDistanceMouth`** | `[NiType]` | `5.4` | Max **clitoris↔mouth distance**. Above this, no oral contact is registered. |
| **`fAngleCunnilingus`** | `[Distance]` | `130.0` | Max **angle (degrees)** between the vaginal axis and the licker's head-forward vector. Above this, the head is judged to be facing the wrong way and no contact is registered. |

Detection succeeds only when **distance ≤ `fDistanceMouth` AND angle ≤ `fAngleCunnilingus`**.

!!! note "`fDistanceCrotch` is *not* the cunnilingus knob"
    `fDistanceCrotch` (`[NiType]`, default `8.0`) governs **vagina↔vagina** (tribbing/grinding) and penis↔crotch penetration proximity — not cunnilingus. Don't reach for it here; `fDistanceMouth` is the clit↔mouth gate.

## How to tune

To make `CUN` fire on **looser** alignment (more animations register as cunnilingus, at the risk of false positives on near-miss poses):

```ini
[NiType]
fDistanceMouth = 8.0      ; was 5.4 — allow the mouth further from the clitoris

[Distance]
fAngleCunnilingus = 150.0 ; was 130 — allow the head less precisely aligned
```

To make it **stricter** (fewer false positives, but some genuine cunnilingus poses may not register), move both the other way.

Then:

1. **Restart the game** (or otherwise force SexLab to re-read the INI). These are load-time settings — there is no live re-read, and no MCM slider for them.
2. Verify in a scene with `director.printdebug = 1`: the oral label reaching `CUN` shows in the physics-label debug output.

!!! warning "Edit the real INI, in load order"
    Edit the `SexLab.ini` your mod manager actually serves (the one that wins in your load order), not a stale copy. With MO2 that is the file under the winning **SexLab Framework P+** mod's `SKSE\Plugins\`.

## The SLO VE knobs do nothing

Older SLO VE builds exposed `director.tunecunnilingus`, `director.cunnilingusdistance` and `director.cunnilingusangle` in `SLOVE.toml`, intending to widen `fDistanceMouth` / `fAngleCunnilingus` from Papyrus via `sslSystemConfig.SetSettingFlt`. **That path never worked and is disabled:**

- `SetSettingFlt`/`GetSettingFlt` only resolve keys registered in SexLab's in-memory **MCM** settings table. `fDistanceMouth` and `fAngleCunnilingus` are **INI-only** settings and are **not** in that table, so `SetSettingFlt("fDistanceMouth", …)` traces *"Unrecognized setting"* and no-ops.
- The `ApplyCunnilingusDetectionTuning()` body in `SLOVE_Director` is commented out for exactly this reason.

So **ignore those TOML keys** — they have no effect. The only supported way to tune cunnilingus detection is editing `SexLab.ini` as above.

## See also

- [SexLab Flavours (P+ / Classic)](sexlab-flavours.md) — why this is P+ only
- [Troubleshooting & Logs](troubleshooting.md) — reading the physics-label debug output
