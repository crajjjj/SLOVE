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
;numArg >= 1 also hands over the face.
;
;SLOVE_Director receives the events and writes them down through the functions
;below; this block is the ONLY place the SLOVE_Mute* StorageUtil keys are spelled.
;A mute is never cleared when it runs out. It is stamped with the real time it
;arrived, and MuteLevel judges it on every read against marks the Director keeps
;per SexLab thread:
;  - the thread: a mute set in another thread's scene is stale
;  - scene floor: when the PREVIOUS scene on that thread ended. A mute older than
;    that belongs to an earlier scene - thread ids are reused, and the player's
;    scenes nearly all run on thread 0
;  - stage start: when the current stage began. A stage mute older than that,
;    less a grace, has had its stage
;Nothing sweeps, and nothing reads the framework's own stage state, so there is
;no order in which the muting mod and SLO VE have to hear a StageStart - P+ sends
;it BEFORE it advances the stage, and both mods answer the same event. The grace
;is what lets a mute re-sent in answer to a StageStart count for the stage it
;announced even when it lands a moment before SLO VE marks that stage. Nothing
;flips at scene end either, so an engine tearing its scene down still sees the
;mute (a face that was handed over stays handed over).
;Real time restarts with the game, so none of this means anything after a load:
;the Director bulk-clears the SLOVE_Mute prefix first thing in Maintenance.

;Seconds a stage mute may precede the stage start it answers. Longer = a mute sent
;just before a stage change also covers the next stage; shorter = under script lag
;a re-sent mute can lose the race and miss its stage.
Float Function MuteGrace() Global
	return 2.0
EndFunction

;True when a mute is written on the actor at all - in force or run out. Two
;natives; the cheap first question for a caller that must look the thread up.
Bool Function MuteWritten(Actor a) Global
	return StorageUtil.GetIntValue(a, "SLOVE_MuteScene", 0) > 0 || StorageUtil.GetIntValue(a, "SLOVE_MuteStage", 0) > 0
EndFunction

;0 = not muted, 1 = voice muted, 2 = voice muted and face handed over.
;aiThread: id of the SexLab thread the asking engine has this actor in.
Int Function MuteLevel(Actor a, Int aiThread) Global
	int sceneLevel = StorageUtil.GetIntValue(a, "SLOVE_MuteScene", 0)
	int stageLevel = StorageUtil.GetIntValue(a, "SLOVE_MuteStage", 0)
	if sceneLevel == 0 && stageLevel == 0
		return 0 ;nearly every call ends here
	endif
	if StorageUtil.GetIntValue(a, "SLOVE_MuteThread", 0) != aiThread + 1
		return 0 ;set in a scene on another thread
	endif
	float sceneFloor = StorageUtil.GetFloatValue(None, "SLOVE_MuteFloor" + aiThread, 0.0)
	if sceneLevel > 0 && StorageUtil.GetFloatValue(a, "SLOVE_MuteSceneAt", 0.0) <= sceneFloor
		sceneLevel = 0 ;set in an earlier scene on this thread
	endif
	if stageLevel > 0
		float stageAt = StorageUtil.GetFloatValue(a, "SLOVE_MuteStageAt", 0.0)
		if stageAt <= sceneFloor || stageAt < StorageUtil.GetFloatValue(None, "SLOVE_MuteStageStart" + aiThread, 0.0) - MuteGrace()
			stageLevel = 0 ;an earlier scene, or its stage is over
		endif
	endif
	if stageLevel > sceneLevel
		return stageLevel
	endif
	return sceneLevel
EndFunction

;The caller name the latest mute on this actor was sent with ("" = none)
String Function MutedBy(Actor a) Global
	return StorageUtil.GetStringValue(a, "SLOVE_MuteBy", "")
EndFunction

;Write a mute down. abScene: for the scene, else for the stage. aiLevel: 1 = voice,
;2 = voice and face. aiThread: the thread the actor is in a scene on.
Function SetMute(Actor a, Int aiThread, Bool abScene, Int aiLevel, String asCaller) Global
	float now = Utility.GetCurrentRealTime()
	if StorageUtil.GetIntValue(a, "SLOVE_MuteThread", 0) != aiThread + 1
		;whatever is still written on the actor comes from another thread's scene
		StorageUtil.UnsetIntValue(a, "SLOVE_MuteScene")
		StorageUtil.UnsetIntValue(a, "SLOVE_MuteStage")
		StorageUtil.SetIntValue(a, "SLOVE_MuteThread", aiThread + 1)
	endif
	StorageUtil.SetStringValue(a, "SLOVE_MuteBy", asCaller)
	;the time first, the level last: a reader between the two natives must never
	;find a level whose time is not there yet
	if abScene
		StorageUtil.SetFloatValue(a, "SLOVE_MuteSceneAt", now)
		StorageUtil.SetIntValue(a, "SLOVE_MuteScene", aiLevel)
	else
		StorageUtil.SetFloatValue(a, "SLOVE_MuteStageAt", now)
		StorageUtil.SetIntValue(a, "SLOVE_MuteStage", aiLevel)
	endif
	;an index for DescribeMute only - nothing that decides a mute reads it
	StorageUtil.FormListAdd(None, "SLOVE_MutedActors", a, false)
EndFunction

;Take a mute back. abScene: the scene mute, else the stage mute.
Function LiftMute(Actor a, Bool abScene) Global
	if abScene
		StorageUtil.UnsetIntValue(a, "SLOVE_MuteScene")
	else
		StorageUtil.UnsetIntValue(a, "SLOVE_MuteStage")
	endif
	if !MuteWritten(a)
		StorageUtil.FormListRemove(None, "SLOVE_MutedActors", a, true)
	endif
	StorageUtil.SetFloatValue(None, "SLOVE_MuteLiftedAt", Utility.GetCurrentRealTime())
EndFunction

;True for a few seconds after any unmute. A mod that mutes an actor here has
;usually force-silenced SexLab's own voice for them as well, and hands THAT back
;when it unmutes - with ForceSilence off, which also drops the silence SLO VE set
;at scene start, so SexLab's moans would run under ours from then on. Its restore
;and its unmute arrive in either order, so the scene drivers re-assert the
;silence on every tick this is true (and again on every stage start).
Bool Function MuteJustLifted() Global
	float liftedAt = StorageUtil.GetFloatValue(None, "SLOVE_MuteLiftedAt", 0.0)
	return liftedAt > 0.0 && Utility.GetCurrentRealTime() - liftedAt < 4.0
EndFunction

;The per-thread marks MuteLevel judges against. SLOVE_Director sets them from
;SexLab's AnimationStarting / AnimationStart, AnimationEnd and StageStart events,
;for EVERY thread - adopted or not, a mute can be sent in any of them.
Function MarkSceneStart(Int aiThread) Global
	;the scene starting now is judged against the end of the one before it. The
	;floor stays put until the NEXT scene starts, so this scene's own end does not
	;turn its mutes off under the engines still tearing it down
	StorageUtil.SetFloatValue(None, "SLOVE_MuteFloor" + aiThread, StorageUtil.GetFloatValue(None, "SLOVE_MuteSceneEnd" + aiThread, 0.0))
EndFunction

Function MarkSceneEnd(Int aiThread) Global
	StorageUtil.SetFloatValue(None, "SLOVE_MuteSceneEnd" + aiThread, Utility.GetCurrentRealTime())
EndFunction

Function MarkStageStart(Int aiThread) Global
	StorageUtil.SetFloatValue(None, "SLOVE_MuteStageStart" + aiThread, Utility.GetCurrentRealTime())
EndFunction

;Forget every mute and every mark - one bulk clear of the SLOVE_Mute prefix, on
;all actors and on the None form the per-thread marks live on. Returns how many
;values went. SLOVE_Director calls it first thing on every game load.
Int Function ClearMutes() Global
	return StorageUtil.ClearAllPrefix("SLOVE_Mute")
EndFunction

;How many actors have a mute written on them (see DescribeMute)
Int Function MutedCount() Global
	return StorageUtil.FormListCount(None, "SLOVE_MutedActors")
EndFunction

;Entry aiIndex of that list as one line of text, "" for an actor that is gone.
;The stage / scene numbers are what is WRITTEN; "in force" is MuteLevel's verdict
;on the thread it was set in (a mute that has run out stays written until it is
;lifted or the game is loaded).
String Function DescribeMute(Int aiIndex) Global
	Actor a = StorageUtil.FormListGet(None, "SLOVE_MutedActors", aiIndex) as Actor
	if a == None
		return ""
	endif
	int thread = StorageUtil.GetIntValue(a, "SLOVE_MuteThread", 0) - 1
	string line = a.GetDisplayName() + " stage=" + StorageUtil.GetIntValue(a, "SLOVE_MuteStage", 0) + " scene=" + StorageUtil.GetIntValue(a, "SLOVE_MuteScene", 0)
	return line + " (1 = voice, 2 = voice + face) by '" + MutedBy(a) + "' on thread " + thread + ", in force: " + MuteLevel(a, thread)
EndFunction

;The exclusivity channel an actor's voice lines play on: "slove_pc" for the
;player, "slove_np<FormID>" for anyone else, and the same name with "_orgasm"
;appended for climax cries. SLOVE_Voice.PlaySound and SLOVE_NpcScene build these
;names inline where they play; this is for a caller that has to STOP a line.
String Function VoiceChannel(Actor a) Global
	if a == Game.GetPlayer()
		return "slove_pc"
	endif
	return "slove_np" + a.GetFormID()
EndFunction
