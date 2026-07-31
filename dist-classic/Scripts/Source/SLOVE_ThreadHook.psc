ScriptName SLOVE_ThreadHook extends ReferenceAlias
{CLASSIC inert stub of the P+ thread hook.

 The P+ variant's SLOVE_ThreadHook extends SexLabThreadHook; it once preloaded tongue
 armors in SexLab's pre-strip window and is now inert (that preload was retired in 0.4.6,
 but the registered hook is kept for save-compat). Classic SexLab SE 1.63 has NO
 SexLabThreadHook type (and classic gates tongues off entirely - see
 AddTongue/DirectorSceneStarting), so the real hook cannot exist here. But the shared
 SLOVE.esp carries the hook's ReferenceAlias for both variants, so classic needs a
 same-named script to bind to it. This stub extends plain ReferenceAlias and does
 nothing - no SexLab dependency, no tongue traffic.

 Keep this in sync with the P+ copy only structurally (both stay empty); the two are a
 genuine framework-specific divergence.}
