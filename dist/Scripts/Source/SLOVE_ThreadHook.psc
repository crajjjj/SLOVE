ScriptName SLOVE_ThreadHook extends SexLabThreadHook
{P+ blocking thread hook. Preloads the FHU tongue armors in SexLab's DETERMINISTIC
 pre-strip window: OnAnimationStarting maps to HOOKID_STARTING, which fires inside
 StartThread() before UndressAndStripActors() - so an AddItem here is guaranteed to
 precede the strip (and thus any add-triggered NPC outfit redress is cleaned up by it).
 The async "AnimationStarting" mod event that SLOVE_Director also listens to only
 *usually* wins that race; this hook closes it.

 Kept deliberately thin - it only bridges the SexLab hook to
 SLOVE_Director.PreloadTongueArmors (a framework-free Actor[] helper), so the tongue
 logic lives in one place. Player scenes only; every other thread is skipped on the
 first line because this hook BLOCKS the thread until it returns.

 P+ ONLY. Classic SexLab SE 1.63 has no SexLabThreadHook (and no tongues) - the
 classic variant ships an inert stub of this script that extends ReferenceAlias and
 does nothing, so the shared SLOVE.esp alias binds cleanly on both.}

SLOVE_Director MasterScript
Actor PlayerRef

; OnAnimationStarting = HOOKID_STARTING: all thread data is set, before the active
; animation is chosen and before the strip. Auto-registration is handled by the base
; SexLabThreadHook.OnInit (bAutoegisterOnInit defaults true), so no OnInit override.
Function OnAnimationStarting(SexLabThread akThread)

EndFunction
