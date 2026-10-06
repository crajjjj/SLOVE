Scriptname SLOVE_Utils Hidden
{Stateless helpers shared across the SLO VE scripts - each used to exist as
 per-script copies (seven of the logging shim, five each of the plugin probe
 and the pause check). Global functions cannot hold state, so anything needing
 a per-instance cache or a config knob (printdebug, the hot API probes) stays
 in its script.}

;True when the plugin is in the load order.
;
;Game.GetModByName, NOT PO3's IsPluginFound: this is the dependency-free
;probe, and it handles light plugins fine (it returns the FE container index
;for them, never 255). SLO VE proves it - SLOVE.esp is itself ESL-flagged and
;the Director gates every one of its spells on this exact call. An earlier
;version of this comment claimed GetModByName "silently fails for ESL-flagged
;plugins"; that was wrong, and routing SLSO/SLS detection through PO3 on the
;strength of it added an undocumented hard dependency to paths that never had
;one. 255 and -1 both mean not found across SKSE versions.
Bool Function isDependencyReady(String modname) Global
	int index = Game.GetModByName(modname)
	return index != 255 && index != -1
EndFunction

;Error-level line into the SLOVE user log (SLOVE.0.log)
Function WritetoErrorlogs(string Header = "Not Specified", String contents = "") Global
	SLOVE_Log.WriteLog(Header + " : " + contents, 2)
EndFunction

;A pack's variation is a consumer label: "D" (tag-shaped) packs dispatch like
;"B" - AudioUtil's tag scoring keys on facts, not on the label
String Function DispatchVariation(String a_variation) Global
	if a_variation == "D"
		return "B"
	endif
	return a_variation
EndFunction

;True while a menu has the scene frozen. SKSE Menu Framework and other ImGui
;overlays freeze the game WITHOUT entering menu mode, so the Papyrus VM keeps
;ticking and Utility.IsInMenuMode() sees a running game; AudioUtil reads the
;engine's freeze flag natively (API v7). Older AudioUtil: always false = the
;previous behavior. Stateless (one extra GetAPIVersion native per call versus
;the old per-instance caches - noise at tick cadence, and a probe can never go
;stale across an AudioUtil upgrade again).
Bool Function GamePaused() Global
	return AudioUtil.GetAPIVersion() >= 7 && AudioUtil.IsGamePaused()
EndFunction

;=== SexLab P+ interaction API (2.19+) ===
;True on SexLab P+ 2.19 or newer - the first version with the interaction API
;the physics paths read (GetInteractionFlags, GetPartnerByInteractionType,
;GetInteractionVelocity). 2.19 replaced its contact detector and renamed and
;re-indexed all of it, so on an older P+ those members do not exist.
;
;Papyrus binds a member call when it is DISPATCHED, not when the script loads:
;a 2.19-only call that is never reached costs nothing on P+ 2.17 / 2.18, while
;one that is reached logs "method not found" on every poll. So this probe comes
;first in front of every one of them (each caller's InteractionsLive), and one
;build serves every P+ version - below 2.19 the scene simply stays on its
;authored stage tags.
;
;P+ loads an SKSE plugin called "SexLabUtil" and packs its version as
;major<<24 | minor<<16 | patch<<4 (its own SexLabUtil.GetVersionPack unpacks it
;that way): 0x02130000 is 2.19.0. -1 = no such plugin.
Bool Function HasInteractionAPI() Global
	return SKSE.GetPluginVersion("SexLabUtil") >= 0x02130000
EndFunction

;The running SexLab P+ version as "major.minor.patch", "" when its plugin is
;missing. For log lines only - gate on HasInteractionAPI.
String Function SexLabPPVersion() Global
	int v = SKSE.GetPluginVersion("SexLabUtil")
	if v == -1
		return ""
	endif
	int major = Math.LogicalAnd(Math.RightShift(v, 24), 0xFF)
	int minor = Math.LogicalAnd(Math.RightShift(v, 16), 0xFF)
	int patch = Math.LogicalAnd(Math.RightShift(v, 4), 0xFFF)
	return major + "." + minor + "." + patch
EndFunction

;=== StorageUtil-backed scene state ===
;The string keys ARE the cross-script contract - these accessors are its one
;spelling (a hand-typed key already leaked once: scene teardown unset
;"Scenario" while everything else read "HentaiScenario", so the value
;survived the scene AND the save).

;"Orgasming" on the actor: her climax window - set by the orgasm state
;machine, polled by the update loop and the wait gates
Bool Function IsOrgasming(Actor a) Global
	return StorageUtil.GetIntValue(a, "Orgasming", 0) == 1
EndFunction

Function SetOrgasming(Actor a, Bool active) Global
	if active
		StorageUtil.SetIntValue(a, "Orgasming", 1)
	else
		StorageUtil.UnsetIntValue(a, "Orgasming")
	endif
EndFunction

;"HandlingMaleOrgasm" on the actor: re-entrancy latch for the partner-orgasm
;reaction thread
Bool Function IsHandlingMaleOrgasm(Actor a) Global
	return StorageUtil.GetIntValue(a, "HandlingMaleOrgasm", 0) != 0
EndFunction

Function SetHandlingMaleOrgasm(Actor a, Bool active) Global
	if active
		StorageUtil.SetIntValue(a, "HandlingMaleOrgasm", 1)
	else
		StorageUtil.UnsetIntValue(a, "HandlingMaleOrgasm")
	endif
EndFunction

;"HentaiScenario" on None: the voices-to-expressions sync - Voice names the
;beat it just voiced, SLOVE_Expressions reads it every pass
Function SetHentaiScenario(String scenario) Global
	StorageUtil.SetStringValue(None, "HentaiScenario", scenario)
EndFunction

String Function GetHentaiScenario() Global
	return StorageUtil.GetStringValue(None, "HentaiScenario", "")
EndFunction

Function ClearHentaiScenario() Global
	StorageUtil.UnsetStringValue(None, "HentaiScenario")
EndFunction

;=== External mute (the SLOVE_Mute_* mod events) ===
;Another mod can take an actor's voice - and optionally their face - away from
;SLO VE for the current stage or for the rest of the scene. The events are sent
;FROM the actor, with the caller's name as the string (docs/authors/integration.md):
;  akActor.SendModEvent("SLOVE_Mute_Stage", "MyMod")      until the stage changes
;  akActor.SendModEvent("SLOVE_Mute_Scene", "MyMod")      until the scene ends
;  akActor.SendModEvent("SLOVE_Unmute_Stage", "MyMod")    lift either one early
;  akActor.SendModEvent("SLOVE_Unmute_Scene", "MyMod")
;numArg >= 1 also hands over the face. SLOVE_Director owns the events, their log
;lines and the expiry; the state it keeps is two StorageUtil ints on the actor,
;so the voice and expression engines read it per line / per tick without a
;cross-script call.

;0 = not muted, 1 = voice muted, 2 = voice muted and face handed over
Int Function MuteLevel(Actor a) Global
	int stageLevel = StorageUtil.GetIntValue(a, "SLOVE_MuteStage", 0)
	int sceneLevel = StorageUtil.GetIntValue(a, "SLOVE_MuteScene", 0)
	if stageLevel > sceneLevel
		return stageLevel
	endif
	return sceneLevel
EndFunction

;The caller name the latest mute on this actor was sent with ("" = none)
String Function MutedBy(Actor a) Global
	return StorageUtil.GetStringValue(a, "SLOVE_MuteBy", "")
EndFunction
