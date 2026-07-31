ScriptName SLOVE_ThreadHook extends SexLabThreadHook
{P+ SexLab thread hook - now INERT. It formerly preloaded the FHU tongue armors in
 SexLab's DETERMINISTIC pre-strip window (OnAnimationStarting = HOOKID_STARTING, which
 fires inside StartThread() before UndressAndStripActors(), so an AddItem here beat the
 strip and any add-triggered NPC redress was cleaned up by it). That bulk pre-add was
 retired in 0.4.6: the player's single rolled tongue is now pre-added by
 SLOVE_Expressions.InitializeAddNPCTongue, and NPCs auto-add their tongue on the
 mid-scene EquipItem - so nothing needs the guaranteed pre-strip window anymore.

 The script is KEPT (registered as a live SexLabThreadHook, bound to the shared
 SLOVE.esp alias) rather than deleted: removing a registered thread hook and its alias
 mid-playthrough CTDs existing saves. Emptying the body is the save-safe way to retire
 it. If a future feature again needs the guaranteed pre-strip window, it goes here.

 P+ ONLY. Classic SexLab SE 1.63 has no SexLabThreadHook (and no tongues) - the
 classic variant ships an inert stub of this script that extends ReferenceAlias and
 does nothing, so the shared SLOVE.esp alias binds cleanly on both.}

SLOVE_Director MasterScript ;SAVE-COMPAT: unused since the preload retired; retained so the script layout matches saves made on the 0.4.6-dev blocking-hook build
Actor PlayerRef             ;SAVE-COMPAT: as above

; Retained as the hook's entry point (empty). OnAnimationStarting = HOOKID_STARTING:
; all thread data is set, before the active animation is chosen and before the strip -
; the one guaranteed pre-strip window, kept available for any future need. The base
; SexLabThreadHook auto-registers this on init, so there is no OnInit override.
Function OnAnimationStarting(SexLabThread akThread)

EndFunction
