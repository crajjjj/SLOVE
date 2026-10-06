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

;=== SexLab Snuff hand-over (SLSnuff.esp, optional) ===
;SLSnuff (strangulation / necro) silences its victim through SexLab's own voice
;and paints its own choke / death faces. Neither reaches SLO VE: AudioUtil is
;the voice here, and the expression engine repaints over a foreign face. So the
;voice and expression engines ask before a line or a face pass. Everything read
;here is state SLSnuff publishes itself, so no script dependency:
;  - Victim<tid> on its main quest: the actor it picked as that thread's
;    strangle victim, kept until the scene ends. Nothing below counts for
;    anyone else - low health alone is ordinary in a defeat scene.
;  - VoiceMuted<tid> on its main quest: 1 while it mutes that victim - during
;    a choke stage, and on through the rest of the scene once the victim is
;    "marked for death". Its own stage-accurate verdict (override list, SLAL
;    flags, tags); animation tags cannot reproduce it.
;  - health, as the fallback for when its choke audio (and so that flag) is
;    switched off: it pins the marked victim at 1 HP until the scene ends. The
;    pin is a 1s damage/restore tick with regen running in between, so test a
;    fraction of max, never == 1.
;  - SLSnuff_NecroThisDeath on the actor: > 0 for the corpse of its necro
;    scenes, which never get a Victim<tid> (counted per dead state, zeroed
;    when it ends).
;Resolve the quest once per scene with GetSnuffQuest and keep it - None (not
;installed, or director.slsnuffyield = 0) makes every check free.
Quest Function GetSnuffQuest() Global
	if SLOVE_Config.GetInt("director.slsnuffyield", 1) != 1 || !isDependencyReady("SLSnuff.esp")
		return None
	endif
	return Game.GetFormFromFile(0xD62, "SLSnuff.esp") as Quest
EndFunction

;True while SLSnuff holds the victim's SexLab voice muted on this thread
Bool Function IsSnuffVoiceMuted(Quest snuffQuest, Int threadID) Global
	return StorageUtil.GetIntValue(snuffQuest, "VoiceMuted" + threadID, 0) == 1
EndFunction

;True for an actor that is dead or pinned at death's door (1 HP plus regen drift)
Bool Function IsNearDeath(Actor a) Global
	return a.IsDead() || a.GetActorValuePercentage("Health") <= 0.05
EndFunction

;True while SLSnuff owns this actor's voice and face (see the block above)
Bool Function IsSnuffSilenced(Quest snuffQuest, Actor a, Int threadID) Global
	if snuffQuest == None || a == None
		return false
	endif
	if StorageUtil.GetIntValue(a, "SLSnuff_NecroThisDeath", 0) > 0
		return true
	endif
	if StorageUtil.GetFormValue(snuffQuest, "Victim" + threadID) != a
		return false
	endif
	return IsSnuffVoiceMuted(snuffQuest, threadID) || IsNearDeath(a)
EndFunction
