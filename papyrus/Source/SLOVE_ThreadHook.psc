ScriptName SLOVE_ThreadHook extends SexLabThreadHook
{P+ SexLab thread hook. OnAnimationStarting = HOOKID_STARTING fires inside
 StartThread() before UndressAndStripActors(): the one deterministic window before
 SexLab strips.

 Since 0.7.17 it serves procedural stripping (strip.enable + strip.replacesexlab):
 for a scene the player is in, every position gets a custom strip of "no armor,
 weapons only", so SexLab's scene-start strip leaves the clothes on and
 SLOVE_Director's StripPass takes off what an act needs when it begins. NPC-only
 scenes are left to SexLab.

 History: it preloaded the FHU tongue armors here until 0.4.6 (the player's single
 rolled tongue is now pre-added by SLOVE_Expressions.InitializeAddNPCTongue, NPCs
 auto-add theirs on the mid-scene EquipItem) and was an empty body from then to
 0.7.16. It was kept all along, registered and bound to the shared SLOVE.esp alias:
 removing a registered thread hook and its alias mid-playthrough CTDs existing saves.

 P+ ONLY. Classic SexLab SE 1.63 has no SexLabThreadHook - the classic variant ships
 an inert stub of this script that extends ReferenceAlias and does nothing, so the
 shared SLOVE.esp alias binds cleanly on both. Classic users lower SexLab's own
 strip options instead.}

SLOVE_Director MasterScript ;SAVE-COMPAT: unused since the preload retired; retained so the script layout matches saves made on the 0.4.6-dev blocking-hook build
Actor PlayerRef             ;SAVE-COMPAT: as above

; The hook's entry point. It BLOCKS the thread, so it leaves on the first line for
; a scene without the player and does nothing slow: settings are cache reads.
; The base SexLabThreadHook auto-registers this on init, so there is no OnInit override.
Function OnAnimationStarting(SexLabThread akThread)
	if !akThread || !akThread.HasPlayer()
		return
	endif
	if SLOVE_Config.GetInt("strip.enable", 0) != 1 || SLOVE_Config.GetInt("strip.replacesexlab", 1) != 1
		return
	endif
	if !SLOVE_Strip.Available()
		return ;an old SLOVE.dll finds no armor: leave SexLab's strip alone
	endif
	Actor[] cast = akThread.GetPositions()
	int i = 0
	while i < cast.Length
		if cast[i]
			;slots 0 = no armor, weapons still go; false = not now, at SexLab's own strip
			akThread.SetCustomStrip(cast[i], 0, true, false)
		endif
		i += 1
	endwhile
EndFunction
