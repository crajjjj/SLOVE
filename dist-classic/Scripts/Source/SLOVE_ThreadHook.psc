ScriptName SLOVE_ThreadHook extends ReferenceAlias
{CLASSIC inert stub of the P+ blocking thread hook.

 The P+ variant's SLOVE_ThreadHook extends SexLabThreadHook and preloads tongue armors
 in SexLab's pre-strip window. Classic SexLab SE 1.63 has NO SexLabThreadHook type (and
 classic gates tongues off entirely - see AddTongue/DirectorSceneStarting), so the real
 hook cannot exist here. But the shared SLOVE.esp carries the hook's ReferenceAlias for
 both variants, so classic needs a same-named script to bind to it. This stub extends
 plain ReferenceAlias and does nothing - no SexLab dependency, no tongue traffic.

 Keep this in sync with the P+ copy only structurally (it stays empty); the two are a
 genuine framework-specific divergence.}
