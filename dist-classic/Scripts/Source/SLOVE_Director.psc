Scriptname SLOVE_Director extends ReferenceAlias
{SLO VE scene director (classic SexLab 1.63 branch). Slim port of Hentairim's
 IVDTControllerScript: the ONLY script in SLO VE allowed to touch SexLabFramework /
 sslThreadController or raw SexLab mod events. Tracks the player scene, owns the
 label state (from the scene's flat tags; classic has no SLSB per-stage tags and no
 node-collision physics), applies the voice/expressions module spells, and
 re-broadcasts SLOVE-owned mod events for consumers. Attached to the PlayerAlias of
 SLOVE_MainQuest in SLOVE.esp. See docs\classic-sexlab-port.md.}

SexLabFramework Property SexLab Auto ;CK-filled - the only CK property on this script

actor playerref
Bool PlayerInScene = false
;classic SexLab has no string scene/stage ids: the scene is identified by the
;sslBaseAnimation on the thread and stages are integers. CurrentAnimation is the
;change-detection handle; CurrentStageNum (below) is the integer stage.
sslBaseAnimation CurrentAnimation
Actor[] actorList
bool PCisAggressor
Bool AllFemale
bool PCisReceiving
bool PCisVictim
int PCposition
;labels and interaction times
float LastLabelUpdateTime
Float LastPhysicsLabelTime ;mid-stage physics label changes; separate from the stage-change latch above
Bool UpdateNow = false
float updaterate = 0.5
;Modules Spells (SLO VE: runtime-resolved from SLOVE.esp, not CK-filled)
Spell ExpressionsSpell
Spell VoiceSpell
Spell SFXSpell
Spell ResistanceSpell
; resistance system enables (SLOVE.toml [resistance]); state itself lives in
; StorageUtil, written by SLOVE_Resistance and read via GetResistance/IsBroken
int enableresistance
int resenablepc
int resenablemalenpc
int resenablefemalenpc
int resenablecreaturenpc
;others
Faction schlongfaction
keyword TNG_Gentlewoman
keyword zad_DeviousGag
sslThreadController CurrentThread
int CurrentThreadid
int CurrentStageNum
Bool isAlmostFinalStage
Bool IsFinalStage
Bool IsEnding
Bool PCInSex

;SLO VE: cached SLOVE.toml [director] settings (re-read on load and per scene start)
int enablevoice
int suppresssexlabvoice
int enablesfx
int enableExpressions
int enablepcexpression
int enablefemalenpcexpression
int enablemalenpcexpression
int usephysicslabels
float physicsfastvelocity
float physicsslowfactor
int enableprintdebug
Bool WarnedConfigMissing = false

;SLO VE: NPC-only scene support ([director] enablenpcscenes/npcscenedistance/maxnpcscenes).
;Scenes the player is NOT in are adopted too when near the player and under the cap,
;getting ambient voice + expressions + SFX + resistance (NOT the PC dirty-talk engine,
;milk, or on-screen notifications). Each adopted NPC scene is driven by an
;SLOVE_NpcScene ability on one anchor actor; the per-actor module spells self-terminate
;with their own thread. NpcSceneAnchors holds the live anchors for the concurrency cap
;(pruned lazily - no decrement handshake to survive save/load).
int enablenpcscenes
float npcscenedistance
int maxnpcscenes
Spell NpcSceneSpell
Actor[] NpcSceneAnchors

;SLO VE: cached SLOVE.toml [milk] settings (Oninus Lactis NG + optional MME).
;Ported from Hentairim IVDTControllerScript (OninusLactislactate family); the
;boob-sensitivity/adventure hooks were dropped - SLO VE has no such systems.
int milkenable
int milkchanceonorgasm
int milkchanceintense
int milkchancenonintense
int milkrollinterval
int milkmintime
int milkmaxtime
int milklevelintense
int milklevelnonintense
int milkrequirebarechest
int milkmmeminfullness
Quest LactisQuest ;OninusLactis.esp 0xD61; cast to OninusLactis at call time
float NextMilkRollTime ;scene time of the next periodic penetration roll

;Called first time ever the mod is loaded
Event OnInit()

	Maintenance()

EndEvent

;Called on subsequent reloads of the save
Event OnPlayerLoadGame()

	Maintenance()
	ReconcileSceneOnLoad()
EndEvent

;RegisterForSingleUpdate does NOT survive save/load, so a save made mid-scene
;reloads with the update loop dead: OnUpdate never re-fires, labels freeze,
;SLOVE_SceneEnd never sends, and the stale PlayerInScene flag then makes
;DirectorSceneStart ignore every future scene. Reconcile the tracked scene
;against reality here.
Function ReconcileSceneOnLoad()
	if !PlayerInScene
		return ;wasn't tracking a scene when the save was made - nothing was dropped
	endif
	;SexLab restores its threads slightly after the load event fires; give it a
	;short window before concluding the scene is really gone
	int tries = 0
	while !Sexlab.GetPlayerController() && tries < 10
		Utility.Wait(0.3)
		tries = tries + 1
	endwhile
	if Sexlab.GetPlayerController()
		printdebug("Reload mid-scene: re-adopting the running player scene")
		AdoptScene() ;re-applies spells (restarting per-actor loops) and restarts OnUpdate
	else
		printdebug("Reload after scene end: clearing stale scene state and orphaned spells")
		ClearSpellsFromTrackedActors()
		DirectorEndScene()
	endif
EndFunction

;Strip our abilities off the last-tracked actors. Used only on the rare reload
;path where the scene ended while the save was unloaded, so the per-actor loops
;can't remove themselves (their event registrations died with the reload).
Function ClearSpellsFromTrackedActors()
	if VoiceSpell && playerref && playerref.HasSpell(VoiceSpell)
		playerref.RemoveSpell(VoiceSpell)
	endif
	if !actorList ;NOT "== None": comparing a None array logs a cast error
		return
	endif
	int z = 0
	while z < actorList.length
		if actorList[z]
			if ExpressionsSpell && actorList[z].HasSpell(ExpressionsSpell)
				actorList[z].RemoveSpell(ExpressionsSpell)
			endif
			if SFXSpell && actorList[z].HasSpell(SFXSpell)
				actorList[z].RemoveSpell(SFXSpell)
			endif
			if ResistanceSpell && actorList[z].HasSpell(ResistanceSpell)
				actorList[z].RemoveSpell(ResistanceSpell)
			endif
		endif
		z = z + 1
	endwhile
EndFunction

;-------- resistance state (written by SLOVE_Resistance in StorageUtil) --------
;consumed by SLOVE_Voice.ASLIsBroken() and SLOVE_Expressions.IsBroken(); both
;stay firewall-clean by reading through the Director rather than StorageUtil.
int Function GetResistance(actor char)
	return StorageUtil.GetIntValue(char, "SLOVE_Resistance", 100)
EndFunction

bool Function IsBroken(actor char)
	; gated on the master switch so disabling resistance also drops any stale
	; broken state (the engine is off, so broken points would never decay)
	return enableresistance == 1 && StorageUtil.GetIntValue(char, "SLOVE_BrokenPoints", 0) > 0
EndFunction

;------------------------- break / recover (the SLOVE_Break / SLOVE_Recover mod events) -------------------------
;A break ends when its hours have passed, scene or no scene, and other mods hear
;of it through SLOVE_Recover (docs/authors/integration.md; the rules and the two
;event names live in SLOVE_Utils). Nothing else of ours runs between scenes, so
;this script holds the clock: ONE game-time update, set for the break that runs
;out first. WatchBreaks runs on every game load (the registration is not trusted
;to survive one), whenever an actor breaks (our own SLOVE_Break) and from the
;update itself.
Function WatchBreaks()
	bool pcWasBroken = StorageUtil.GetIntValue(playerref, "SLOVE_BrokenPoints", 0) > 0
	float hoursLeft = SLOVE_Utils.SweepBroken()
	if pcWasBroken && StorageUtil.GetIntValue(playerref, "SLOVE_BrokenPoints", 0) <= 0 && SLOVE_Config.GetInt("resistance.scenestartnotification", 1) == 1
		Debug.Notification("You have recovered your composure")
	endif
	if hoursLeft >= 0.0
		;a little past the hour, so the update finds the break over
		RegisterForSingleUpdateGameTime(hoursLeft + 0.02)
	endif
EndFunction

Event OnUpdateGameTime()
	WatchBreaks()
EndEvent

Event DirectorOnBreak(string eventName, string argString, float argNum, form sender)
	WatchBreaks()
EndEvent

;------------------------- external mute (the SLOVE_Mute_* mod events) -------------------------
;Public API for other mods (docs/authors/integration.md): take an actor's voice,
;and optionally their face, away from SLO VE for the current stage or for the rest
;of the scene. Sent FROM the actor, with the caller's name as the string:
;  akActor.SendModEvent("SLOVE_Mute_Stage", "MyMod")      until the stage changes
;  akActor.SendModEvent("SLOVE_Mute_Scene", "MyMod")      until the scene ends
;  akActor.SendModEvent("SLOVE_Unmute_Stage", "MyMod")    lift either one early
;  akActor.SendModEvent("SLOVE_Unmute_Scene", "MyMod")
;numArg >= 1 also hands over the face. Every event is written to the SLOVE log
;with its actor and caller, accepted or not.
;This script only receives the events, finds the actor's thread and logs; what a
;mute IS, when it has run out, and every StorageUtil key behind it live in
;SLOVE_Utils (shared by both script variants). The other half of the bookkeeping
;is the three per-thread marks set from the SexLab events below
;(SLOVE_Utils.MarkSceneStart / MarkSceneEnd / MarkStageStart).
Event DirectorOnMute(string eventName, string argString, float argNum, form sender)
	Actor a = sender as Actor
	if a == None
		SLOVE_Log.WriteLog("Mute : " + eventName + " caller='" + argString + "' IGNORED - no actor (send it from the actor: akActor.SendModEvent)", 1)
		return
	endif
	int thread = ActorThreadID(a)
	if thread < 0
		SLOVE_Log.WriteLog("Mute : " + eventName + " actor=" + a.GetDisplayName() + " caller='" + argString + "' IGNORED - the actor is not in a scene", 1)
		return
	endif
	int level = 1
	if argNum >= 1.0
		level = 2
	endif
	SLOVE_Utils.SetMute(a, thread, eventName == "SLOVE_Mute_Scene", level, argString)
	;a mute silences NOW, not from the next line: cut what this actor is in the
	;middle of saying. Stopping the line is all the mouth needs - AudioUtil fades
	;it shut as the line ends, where StopLipSync would freeze it mid-shape
	string channel = SLOVE_Utils.VoiceChannel(a)
	AudioUtil.StopChannel(channel)
	AudioUtil.StopChannel(channel + "_orgasm")
	SLOVE_Log.WriteLog("Mute : " + eventName + " actor=" + a.GetDisplayName() + " caller='" + argString + "' face=" + (level == 2) + " thread=" + thread, 0)
EndEvent

Event DirectorOnUnmute(string eventName, string argString, float argNum, form sender)
	Actor a = sender as Actor
	if a == None
		SLOVE_Log.WriteLog("Mute : " + eventName + " caller='" + argString + "' IGNORED - no actor (send it from the actor: akActor.SendModEvent)", 1)
		return
	endif
	string mutedBy = SLOVE_Utils.MutedBy(a)
	SLOVE_Utils.LiftMute(a, eventName == "SLOVE_Unmute_Scene")
	SLOVE_Log.WriteLog("Mute : " + eventName + " actor=" + a.GetDisplayName() + " caller='" + argString + "' (was muted by '" + mutedBy + "', mute level now " + SLOVE_Utils.MuteLevel(a, ActorThreadID(a)) + ")", 0)
EndEvent

;The id of the SexLab thread this actor is in a LIVE scene on, -1 when in none.
;Classic keeps a finished thread's positions filled for about 10s (its Frozen
;state) and GetActorController returns the first slot that still holds the actor,
;so in back-to-back scenes it can name the dead thread - look past it.
int Function ActorThreadID(Actor a)
	sslThreadController t = Sexlab.GetActorController(a)
	if !t
		return -1
	endif
	if ThreadIsLive(t)
		return t.tid
	endif
	int i = 0
	while i < 15 ;classic SexLab runs 15 thread slots
		sslThreadController other = Sexlab.GetController(i)
		if other && other != t && ThreadIsLive(other) && other.Positions.Find(a) >= 0
			return i
		endif
		i += 1
	endwhile
	return -1
EndFunction

;False for a controller whose scene is over: ending, held for its hooks, or back in the pool
bool Function ThreadIsLive(sslThreadController t)
	string st = t.GetState()
	return st != "Ending" && st != "Frozen" && st != "Unlocked"
EndFunction

;classic can swap the animation without a stage change - for a stage mute that is
;a stage boundary too
Event DirectorOnAnimationChange(string eventName, string argString, float argNum, form sender)
	SLOVE_Utils.MarkStageStart(argString as Int)
EndEvent

Function Maintenance()

	SLOVE_Log.InitLog()  ; open the SLOVE user log (OnInit + every reload)
	;external mutes never survive a game load, and they go FIRST - before anything
	;below can yield to a mute a mod re-sends from its own load handler, which this
	;would then wipe. One bulk clear takes every SLOVE_Mute* value: the mutes on
	;every actor and the per-thread time marks they are judged against (real time
	;restarts with the game, so a mark from the last session means nothing now).
	int leftovermutes = SLOVE_Utils.ClearMutes()
	if leftovermutes > 0
		SLOVE_Log.WriteLog("Mute : game loaded - cleared " + leftovermutes + " leftover mute value(s)", 0)
	endif
	;re-probe AudioUtil's API on every load: this script is a ReferenceAlias, so a
	;cached probe is SAVED, and a player who upgrades AudioUtil mid-save would
	;otherwise keep the untagged fallback forever with nothing in the log to say so
	audioUtilTagAPI = 0
	PerformInitialization()
	;Other Parameters
	InitializeDirectorConfigs()

	;re-seed the face-owns-mouth marker from SLS's saved ahegao state so a save
	;made mid-ahegao keeps PC moans off the mouth after the reload (PlaySound
	;reads this marker per line; nothing is latched in the DLL).
	;Gated on SL Survival being loaded: _SLS_IsAhegaoing lives in the co-save and
	;outlives an SLS uninstall - honoring a stale 1 would permanently block the
	;player's lipsync. Without SLS any stale marker is cleared instead.
	if SLOVE_Utils.isDependencyReady("SL Survival.esp")
		StorageUtil.SetIntValue(playerref, "SLOVE_FaceOwnsMouth_SLS", StorageUtil.GetIntValue(None, "_SLS_IsAhegaoing", 0))
	else
		StorageUtil.UnsetIntValue(playerref, "SLOVE_FaceOwnsMouth_SLS")
	endif

	;fire the Mfg Fix NG round-trip probe in its own event stack (see
	;OnSLOVEMfgFixProbe) - the flag is pre-cleared so a repaired install stops warning
	StorageUtil.SetIntValue(None, "SLOVE_MfgFixBroken", 0)
	SendModEvent("SLOVE_MfgFixProbe")

	;breaks end on time, in a scene or not (see WatchBreaks): pick the clock back
	;up, with the player's break from a save older than 0.7.3 on the list
	SLOVE_Utils.IndexBroken(playerref)
	WatchBreaks()

Endfunction

Function PerformInitialization()
	; Register globally whenever the script is first initialized
	RegisterForTheEventsWeNeed()
	playerref = game.getplayer() ;player

	;Modules (SLO VE: both spells live in our own plugin)
	if SLOVE_Utils.isDependencyReady("SLOVE.esp")
		ExpressionsSpell = Game.GetFormFromFile(0x800, "SLOVE.esp") as Spell
		VoiceSpell = Game.GetFormFromFile(0x802, "SLOVE.esp") as Spell
		SFXSpell = Game.GetFormFromFile(0x805, "SLOVE.esp") as Spell
		ResistanceSpell = Game.GetFormFromFile(0x808, "SLOVE.esp") as Spell
		NpcSceneSpell = Game.GetFormFromFile(0x81E, "SLOVE.esp") as Spell ;anchor ability for NPC-only scenes
	endif

	if !ExpressionsSpell
		SLOVE_Utils.WritetoErrorlogs("Director", "Expressions Spell is Missing! Make Sure the Mod is properly installed and Plugin Enabled")
	endif

	if !VoiceSpell
		SLOVE_Utils.WritetoErrorlogs("Director", "Voice Spell is Missing! Make Sure the Mod is properly installed and Plugin Enabled")
	endif

	if !SFXSpell
		SLOVE_Utils.WritetoErrorlogs("Director", "SFX Spell is Missing! Make Sure the Mod is properly installed and Plugin Enabled")
	endif

	if SLOVE_Utils.isDependencyReady("devious devices - assets.esm")
		zad_DeviousGag = Game.GetFormFromFile(0x7EB8, "devious devices - assets.esm") as Keyword
	endif

	;Others
	if SLOVE_Utils.isDependencyReady("Schlongs of Skyrim.esp")
		schlongfaction = Game.GetFormFromFile(0xAFF8 , "Schlongs of Skyrim.esp") as Faction
	EndIf

	if SLOVE_Utils.isDependencyReady("TheNewGentleman.esp")
		TNG_Gentlewoman = Game.GetFormFromFile(0xFF8, "TheNewGentleman.esp") as Keyword
	endif
EndFunction

Function RegisterForTheEventsWeNeed()
	SLOVE_Log.WriteLog("Director : Registered For Events", 0)

	RegisterForModEvent("AnimationStart", "DirectorSceneStart")
	;presex: fires at the top of sslThreadModel.StartThread(), BEFORE the actors
	;are stripped - the one safe window for tongue-armor AddItem traffic (see
	;DirectorSceneStarting)
	RegisterForModEvent("AnimationStarting", "DirectorSceneStarting")
	RegisterForModEvent("SexLabOrgasmSeparate", "DirectorOnOrgasm")
	RegisterForModEvent("StageStart", "DirectorStageStart")
	;deterministic scene-end: the OnUpdate poll is not a reliable end-detector
	;(RegisterForSingleUpdate dies on save/load and can be starved by script lag, and
	;on classic GetPlayerController() may not go None between scenes), so end on
	;SexLab's own AnimationEnd too - see DirectorSceneEnd
	RegisterForModEvent("AnimationEnd", "DirectorSceneEnd")
	;SexLab Survival owns the player's face during its ahegao. SLOVE_Expressions
	;pauses its own writes, but AudioUtil's lipsync would still drive (and then
	;zero) the mouth phonemes on every PC moan - block it for the duration.
	RegisterForModEvent("_SLS_AhegaoStateChange", "DirectorOnSLSAhegaoStateChange")
	;self-event: the Mfg Fix probe runs in its own stack so a missing script can
	;never disturb Maintenance (fired at the end of Maintenance on every load)
	RegisterForModEvent("SLOVE_MfgFixProbe", "OnSLOVEMfgFixProbe")
	;external mute API (other mods -> us) - see the block above DirectorOnMute
	RegisterForModEvent("SLOVE_Mute_Stage", "DirectorOnMute")
	RegisterForModEvent("SLOVE_Mute_Scene", "DirectorOnMute")
	RegisterForModEvent("SLOVE_Unmute_Stage", "DirectorOnUnmute")
	RegisterForModEvent("SLOVE_Unmute_Scene", "DirectorOnUnmute")
	;an actor broke: set the clock for the end of that break - see WatchBreaks
	RegisterForModEvent("SLOVE_Break", "DirectorOnBreak")
	RegisterForModEvent("AnimationChange", "DirectorOnAnimationChange")

EndFunction

Event DirectorOnSLSAhegaoStateChange(string eventName, string argString, float argNum, form sender)
	;mark the player while SLS owns the face; PlaySound reads this per line
	StorageUtil.SetIntValue(playerref, "SLOVE_FaceOwnsMouth_SLS", (argNum >= 0.5) as int)
EndEvent

bool MfgFixConsoleWarned = false ;one console notice per session (log warns every load)

;Mfg Fix NG functional probe: write a phoneme through the exact API every SLO VE
;face write uses (MfgConsoleFuncExt) and read it back through what the jaw gate
;reads (MfgConsoleFunc). Catches Mfg Fix NG missing entirely, its DLL failing to
;load, and the OLD non-NG Mfg Fix - which HAS MfgConsoleFunc but not the Ext
;script, so mouths still move (lipsync is native) yet faces are never driven or
;reset. Runs in its own mod-event stack so a missing script only degrades this
;probe, never Maintenance.
;NG's GetPhoneme reads the mod-written TARGET bank (phoneme2), so a successful
;write reads back within a frame - no interpolation wait. What CAN produce a
;bogus 0 is contention on the player's face: a facegen rebuild right after load
;(RaceMenu-heavy setups) or another player-mouth mod (DBVO / PC-head-tracking
;voice systems) writing over the probe channel. Hence: probe phoneme 15 (W -
;nothing touches it outside a playing line), and require THREE zero reads
;before declaring the API broken - a dead install fails all three, a stomp or
;rebuild race passes a retry. (The v1 probe - channel 0, one attempt - false-
;alarmed on a working install in the field.) A 3% write is invisible.
Event OnSLOVEMfgFixProbe(string eventName, string argString, float argNum, form sender)
	Utility.Wait(2.0) ;let the load + post-load facegen rebuilds settle
	Actor probeActor = Game.GetPlayer()
	int attempt = 0
	bool sawZero = false
	while attempt < 3
		if attempt > 0
			Utility.Wait(1.5) ;fresh sample well clear of whatever stomped the last one
		endif
		MfgConsoleFuncExt.SetPhoneme(probeActor, 15, 3, 0.1) ;0.1 = near-instant per the API docs
		Utility.Wait(0.3) ;the write lands via a queued frame task
		int readBack = MfgConsoleFunc.GetPhoneme(probeActor, 15)
		;classic 3-arg restore: instant, and its speed-0 path also clears the
		;smooth-mode flag the Ext write set on the player
		MfgConsoleFunc.SetPhoneme(probeActor, 15, 0)
		if readBack >= 1
			StorageUtil.SetIntValue(None, "SLOVE_MfgFixBroken", 0)
			SLOVE_Log.WriteLog("Mfg Fix NG probe OK (phoneme round-trip = " + readBack + ", attempt " + (attempt + 1) + "/3)", 0)
			return
		endif
		sawZero = sawZero || readBack == 0
		attempt += 1
	endwhile
	if sawZero
		StorageUtil.SetIntValue(None, "SLOVE_MfgFixBroken", 1)
		SLOVE_Log.WriteLog("Mfg Fix NG is missing or not working: phoneme writes through MfgConsoleFuncExt did not read back (3 attempts). Faces cannot be driven or reset (stuck/deformed faces, tongues through closed lips). Install/update Mfg Fix NG and let it win its file conflicts.", 2)
	endif
	;every read negative = the player's face data was unreadable - no verdict
EndEvent

Function InitializeDirectorConfigs()

	enableprintdebug = SLOVE_Config.GetInt("director.printdebug", 0)
	if !SLOVE_Config.Available() && !WarnedConfigMissing
		;SLO VE: one warning per session, then run on defaults (fail-open getters)
		WarnedConfigMissing = true
		SLOVE_Utils.WritetoErrorlogs("Director", "TomlUtil API not found - SLOVE.toml cannot be read, running on defaults. Check the AudioUtil/TomlUtil installation.")
	endif

	enablevoice = SLOVE_Config.GetInt("director.enablevoice", 1)
	suppresssexlabvoice = SLOVE_Config.GetInt("director.suppresssexlabvoice", 1)
	enablesfx = SLOVE_Config.GetInt("sfx.enable", 0)
	enableExpressions = SLOVE_Config.GetInt("director.enableexpressions", 1)
	enablepcexpression = SLOVE_Config.GetInt("director.enablepcexpression", 1)
	enablefemalenpcexpression = SLOVE_Config.GetInt("director.enablefemalenpcexpression", 1)
	enablemalenpcexpression = SLOVE_Config.GetInt("director.enablemalenpcexpression", 1)
	enableresistance = SLOVE_Config.GetInt("resistance.enable", 1)
	resenablepc = SLOVE_Config.GetInt("resistance.enablepc", 1)
	resenablemalenpc = SLOVE_Config.GetInt("resistance.enablemalenpc", 1)
	resenablefemalenpc = SLOVE_Config.GetInt("resistance.enablefemalenpc", 1)
	resenablecreaturenpc = SLOVE_Config.GetInt("resistance.enablecreaturenpc", 1)
	usephysicslabels = SLOVE_Config.GetInt("director.usephysicslabels", 1)
	physicsfastvelocity = SLOVE_Config.GetFloat("director.physicsfastvelocity", 25.0)
	physicsslowfactor = SLOVE_Config.GetFloat("director.physicsslowfactor", 0.65)
	if physicsslowfactor > 1.0
		physicsslowfactor = 1.0
	elseif physicsslowfactor < 0.1
		physicsslowfactor = 0.1
	endif

	;NPC-only scene support. Default ON with conservative limits (near-player + capped).
	enablenpcscenes = SLOVE_Config.GetInt("director.enablenpcscenes", 1)
	npcscenedistance = SLOVE_Config.GetFloat("director.npcscenedistance", 2048.0)
	maxnpcscenes = SLOVE_Config.GetInt("director.maxnpcscenes", 3)
	printdebug(" enablenpcscenes :" + enablenpcscenes + " npcscenedistance :" + npcscenedistance + " maxnpcscenes :" + maxnpcscenes)

	printdebug(" enablevoice :" + enablevoice)
	printdebug(" enablesfx :" + enablesfx)
	printdebug(" enableExpressions :" + enableExpressions)
	printdebug(" enablepcexpression :" + enablepcexpression)
	printdebug(" enablefemalenpcexpression :" + enablefemalenpcexpression)
	printdebug(" enablemalenpcexpression :" + enablemalenpcexpression)
	printdebug(" usephysicslabels :" + usephysicslabels)
	printdebug(" physicsfastvelocity :" + physicsfastvelocity)
	printdebug(" physicsslowfactor :" + physicsslowfactor)

	;[milk] - Oninus Lactis NG nipple squirts (optional; off unless the mod is
	;present AND milk.enable = 1). MME is a further optional layer inside Lactate().
	milkenable = SLOVE_Config.GetInt("milk.enable", 0)
	if milkenable == 1 && SLOVE_Utils.isDependencyReady("OninusLactis.esp")
		if LactisQuest == none
			LactisQuest = Game.GetFormFromFile(0xD61, "OninusLactis.esp") as Quest
		endif
		if LactisQuest == none
			SLOVE_Utils.WritetoErrorlogs("Director", "OninusLactis.esp loaded but quest 0xD61 not found - milk disabled. Reinstall Oninus Lactis NG.")
			milkenable = 0
		endif
	else
		milkenable = 0
	endif
	if milkenable == 1
		milkchanceonorgasm = SLOVE_Config.GetInt("milk.chanceonorgasm", 50)
		milkchanceintense = SLOVE_Config.GetInt("milk.chanceintense", 20)
		milkchancenonintense = SLOVE_Config.GetInt("milk.chancenonintense", 8)
		milkrollinterval = SLOVE_Config.GetInt("milk.rollinterval", 10)
		milkmintime = SLOVE_Config.GetInt("milk.mintime", 4)
		milkmaxtime = SLOVE_Config.GetInt("milk.maxtime", 10)
		milklevelintense = SLOVE_Config.GetInt("milk.levelintense", 2)
		milklevelnonintense = SLOVE_Config.GetInt("milk.levelnonintense", 1)
		milkrequirebarechest = SLOVE_Config.GetInt("milk.requirebarechest", 1)
		milkmmeminfullness = SLOVE_Config.GetInt("milk.mmeminfullness", 20)
		printdebug(" milk enabled: orgasm=" + milkchanceonorgasm + "% intense=" + milkchanceintense + "% nonintense=" + milkchancenonintense + "%")
	endif
endfunction

Event DirectorStageStart(string eventName, string argString, float argNum, form sender)
	SLOVE_Utils.MarkStageStart(argString as Int) ;EVERY thread's stage start - what stage mutes are judged against, so before anything that can yield
	printdebug("Director Stage Start Fired")
	if CurrentThread == none ;SLO VE: guard - stage events from scenes we never adopted
		return
	endif
	if argString as Int == CurrentThread.tid
		;classic: no GetStatus()==2 registering-wait; the controller is already set up
		actorlist = currentthread.Positions
		;SLO VE: re-broadcast for consumers; label refresh happens in OnUpdate via the id comparison
		SendModEvent("SLOVE_StageStart", argString)
	endif
EndEvent

;Presex hook: AnimationStarting fires before SexLab strips/undresses the actors.
;ALL inventory ADDs for the FHU tongue armors happen here: if an add wakes the
;NPC outfit AI (redress), the strip that follows moments later re-normalizes it.
;Mid-scene show/hide in SLOVE_Expressions is then plain EquipItem/UnequipItem -
;equipment traffic on an already-carried item never wakes the outfit AI. All
;ten variants are pre-added (the per-scene roll happens later in Expressions):
;they are NonPlayable, weightless, invisible in menus, and are removed again at
;scene end (RemoveTongueItems) so nothing lingers between scenes.
Event DirectorSceneStarting(string eventName, string argString, float argNum, form sender)
	SLOVE_Utils.MarkSceneStart(argString as Int) ;EVERY thread's scene start (mute bookkeeping, see SLOVE_Utils)
	;CLASSIC: tongues are P+-only. Classic SexLab SE 1.63 has no live oral/cunnilingus
	;detection (no NiType collision detector), so a contact tongue could only be timed
	;from coarse authored tags - it pops at stage boundaries and misses real contact,
	;which reads as a bug. So we never preload the tongue armors here: no AddItem means
	;no NPC outfit-AI redress, and AddTongue() is gated to a no-op to match. Ahegao is a
	;separate, resistance/orgasm-driven path and is unaffected. `expressions.enabletongue`
	;is honoured only by the P+ variant. (Body-only gate; the function is kept for save-compat.)
	return

	if SLOVE_Config.GetInt("expressions.enabletongue", 0) != 1
		return
	endif
	sslThreadController startingThread = Sexlab.GetPlayerController()
	if !startingThread
		return ;player scenes only, same as DirectorSceneStart
	endif
	int npcTongue = JsonUtil.GetIntValue("SLOVE/NPCTongue.json", "enablenpctongue", 0)
	Actor[] scenePositions = startingThread.Positions
	int added = 0
	int i = 0
	while i < scenePositions.Length
		Actor pos = scenePositions[i]
		if pos && (pos == PlayerRef || npcTongue == 1)
			int t = 0
			while t < 10
				;SLOVE tongue armors (bundled HALO HDT) are sequential in SLOVE.esp:
				;SLOVE_Tongue{t+1}Armor = 0x000813 + t
				Form tongueItem = Game.GetFormFromFile(0x000813 + t, "SLOVE.esp")
				if tongueItem && pos.GetItemCount(tongueItem) == 0
					pos.AddItem(tongueItem, abSilent = true)
					added += 1
				endif
				t += 1
			endwhile
		endif
		i += 1
	endwhile
	printdebug("PRESEX preload: npcTongue=" + npcTongue + " positions=" + scenePositions.Length + " items_added=" + added)
EndEvent

;Director reacts when a sexlab scene start
Event DirectorSceneStart(string eventName, string argString, float argNum, form sender)
	SLOVE_Utils.MarkSceneStart(argString as Int) ;EVERY thread; AnimationStarting marked it already unless that event was lost
	;SLO VE is for handling player scenes only.

	printdebug("Sexlab Scene Detected")

	;faces are about to be driven - if the load-time Mfg Fix probe failed, say so
	;where the user is looking, once per session (scene start is safely past the
	;load path, where console printing is forbidden - see SLOVE_printdebug notes)
	if !MfgFixConsoleWarned && StorageUtil.GetIntValue(None, "SLOVE_MfgFixBroken", 0) == 1
		MfgFixConsoleWarned = true
		MiscUtil.PrintConsole("SLO VE: Mfg Fix NG is missing or not working - faces will stick or deform. Install/update Mfg Fix NG (details in SLOVE.0.log).")
	endif

	;Route THIS event by its OWN thread. An NPC-only scene is adopted for its ambient
	;voice / expressions / SFX / resistance even when the player is busy in a DIFFERENT
	;scene (e.g. a follower starts a scene nearby) - so concurrent NPC scenes are voiced
	;too. Only a thread that actually contains the player falls through to the
	;player-scene engine below.
	sslThreadController evThread = Sexlab.GetController(argString as Int)
	if evThread && evThread.Positions.Find(playerref) < 0
		TryAdoptNpcScene(argString as Int)
		printdebug("NPC-only scene - handled via NPC-scene path")
		Return
	endif

	sslThreadController newThread = Sexlab.GetPlayerController()
	if !newThread
		printdebug("Scene does not involve player and no NPC thread resolved - ignored")
		Return
	endif

	;self-heal: if we still think a scene is running, decide whether this is a
	;duplicate AnimationStart for the SAME thread (ignore) or a NEW scene whose end
	;we missed. The OnUpdate poll can die (save/load, script lag, back-to-back
	;scenes) and classic GetPlayerController() may not go None between scenes,
	;latching PlayerInScene true forever - the old guard only cleared it when NO
	;controller existed, so at a real new scene it never cleared and every future
	;scene was ignored. Re-adopting on a thread-id change is the safety net.
	if PlayerInScene
		if CurrentThread && newThread.tid == CurrentThreadID
			printdebug("Same scene already adopted - ignoring duplicate AnimationStart")
			Return
		endif
		printdebug("Stale scene state (missed end) - reconciling before adopting the new scene")
		SkipTongueRemovalOnce = true ;the new scene's presex preload already ran - don't strip its tongue items
		DirectorEndScene()
	endif

	AdoptScene()
EndEvent

;Full scene setup: label init, spell (re)application, and the OnUpdate loop kick.
;Extracted so a mid-scene reload can re-run it - RegisterForSingleUpdate and the
;per-actor ability loops do not survive save/load. ApplySpells removes-then-adds
;each ability, so re-adopting restarts every actor's OnEffectStart cleanly.
Function AdoptScene()
	UpdateNow = true

	;Initialize Configs
	InitializeDirectorConfigs() ;SLO VE: cheap toml-cache reads; keeps live edits + Reload() effective per scene
	isEnding = false
	PCInSex = true
	CurrentThread = Sexlab.GetPlayerController() ;CURRENT THREAD (classic)
	CurrentThreadID = CurrentThread.tid
	CurrentAnimation = CurrentThread.Animation
	CurrentSceneName = CurrentAnimation.Name
	CurrentStageNum = CurrentThread.Stage
	isAlmostFinalStage = isAlmostFinalStage()
	IsFinalStage = IsFinalStage()
	LastLabelUpdateTime = CurrentThread.TotalTime
	LastPhysicsLabelTime = 0
	actorList = CurrentThread.Positions
	PCPosition = CurrentThread.Positions.Find(Playerref)
	;SLO VE: no foreplay / linear-scene / custom-scene / orgasm choreography - dropped
	PlayerInScene = true
	UpdateLabelsArr()
	;initialize variables
	PCisAggressor = PCisAggressor()
	AllFemale = AllFemale()
	PCisReceiving = playerref == actorList[0]
	PCisVictim = PCisVictim()

	;classic: GetPlayerController() hands back a fully set-up controller, so the
	;P+ GetStatus()==2 (still-registering) busy-wait has no equivalent and is dropped

	SwapSceneArmor()
	ApplySpells()
	SendModEvent("SLOVE_SceneStart", CurrentThreadID as string)
	printdebug("CurrentThread :" + CurrentThread)
	printdebug("CurrentAnimation :" + CurrentAnimation)
	printdebug("CurrentStageNum :" + CurrentStageNum)
	printdebug("actorList :" + actorList)
	printdebug("Scene start")
	NextMilkRollTime = CurrentThread.TotalTime + milkrollinterval
	UpdateNow = false
	RegisterForSingleUpdate(0.1)
EndFunction

Event DirectorOnOrgasm(Form actorRef, Int thread)
	;SLO VE: re-broadcast only. Current consumers (voice/expressions ports) still
	;register the raw SexLabOrgasmSeparate event themselves; SLOVE_Orgasm exists so
	;future framework adapters (OStim) can feed consumers without raw SLPP events.
	if CurrentThread && thread == CurrentThreadID
		float actorid = 0.0
		if actorRef
			actorid = actorRef.GetFormID() as float
		endif
		SendModEvent("SLOVE_Orgasm", thread as string, actorid)

		;milk: any orgasm in the player's scene may trigger a nipple squirt.
		;Orgasm squirts are always the intense level (ported Hentairim behavior).
		;After the re-broadcast - PlayNippleSquirt is latent and must not delay it.
		if milkenable == 1 && Utility.RandomInt(1, 100) <= milkchanceonorgasm
			Lactate(true)
		endif
	endif
endevent


;deterministic scene-end: end the tracked scene the moment SexLab fires
;AnimationEnd instead of waiting for the OnUpdate poll to notice the controller is
;gone (the poll can be dropped by save/load or script lag, and on classic
;GetPlayerController() may not go None between scenes - either way PlayerInScene
;stays true and blocks every future scene). Guarded to our thread; DirectorEndScene
;is re-entry safe so the poll can't double-fire behind this.
Event DirectorSceneEnd(string eventName, string argString, float argNum, form sender)
	SLOVE_Utils.MarkSceneEnd(argString as Int) ;EVERY thread's end: a mute older than this is not the next scene's
	if PlayerInScene && argString as Int == CurrentThreadID
		printdebug("AnimationEnd for tracked scene - ending")
		DirectorEndScene()
	endif
EndEvent

;one-shot flag consumed by DirectorEndScene: set true by the stale-scene reconcile
;path so that teardown skips tongue-item removal (the next scene's presex preload
;already ran for shared actors). A script bool instead of a function parameter -
;changing DirectorEndScene's SIGNATURE mid-playthrough breaks loading a save that
;has a suspended stack in it, so the signature must stay () forever.
bool SkipTongueRemovalOnce = false
Function DirectorEndScene()
	;re-entry guard: both the OnUpdate poll and the AnimationEnd hook can reach here.
	;Clear PlayerInScene FIRST - before any external call. The StopGroup calls below
	;unlock the script, so a second caller (OnUpdate poll vs AnimationEnd hook) must
	;find the flag already down; otherwise it slips past the guard mid-teardown and
	;double-fires (double 3s end-window, duplicate SLOVE_SceneEnd). Read-then-clear
	;with no external call between is atomic, so exactly one caller wins.
	if !PlayerInScene
		return
	endif
	PlayerInScene = false
	bool removeTongues = !SkipTongueRemovalOnce ;consume the one-shot skip flag (set by the stale-scene reconcile path)
	SkipTongueRemovalOnce = false
	;SLO VE: no StopAnimation/armor/scaling/speed restore - the only end path here is
	;the OnUpdate poll after the thread already ended
	isEnding = true
	;mute on scene end: a moan/line/SFX started just before the scene ended would
	;otherwise keep playing over the aftermath. Stop the ambient/mundane groups
	;immediately, but leave the *_high voice groups (orgasm lines play there at
	;priority>1) for SLOVE_Voice.RemoveTracker to ring out briefly - cutting the
	;climax cry the instant the scene ends is why the Orgasm folder seemed silent.
	AudioUtil.StopGroup("pc_low")
	AudioUtil.StopGroup("partner_low")
	AudioUtil.StopGroup("sfx")
	AudioUtil.StopGroup("oneshot")
	PCInSex = false
	LastLabelUpdateTime = 0
	LastPhysicsLabelTime = 0
	int endedThreadID = CurrentThreadID
	SLOVE_Utils.MarkSceneEnd(endedThreadID) ;the poll path gets here without an AnimationEnd event

	;take the pre-added tongue armors back off - they must not persist between
	;scenes. RemoveItem is inventory traffic, but at scene end that is harmless
	;(the actors are redressing anyway). Skipped (false) only on the stale-scene
	;reconcile path, where the NEXT scene's presex preload has already run for
	;shared actors (the player always is one)
	if removeTongues
		RemoveTongueItems()
	endif
	RestoreSceneArmor()

	CurrentThread = none
	CurrentAnimation = none
	CurrentSceneName = ""
	CurrentStageNum = 0
	updaterate = 0.5

	SendModEvent("SLOVE_SceneEnd", endedThreadID as string)

	;SLO VE: expressions module resets faces itself (OnEffectFinish); keep the original
	;3s end-window so consumers can observe the AnimationisEnding() latch, then clear it
	utility.wait(3)
	isEnding = false

	printdebug("SLO VE Director Scene END")

endfunction

;scene-end counterpart of DirectorSceneStarting: remove ALL ten pre-added SLOVE
;tongue armors from the scene's actors (worn ones are auto-unequipped by
;RemoveItem; SLOVE_Expressions has already unequipped ours in OnEffectFinish)
Function RemoveTongueItems()
	if !actorList ;NOT "== None": comparing a None array logs a cast error
		return
	endif
	int removed = 0
	int z = 0
	while z < actorList.Length
		Actor pos = actorList[z]
		if pos
			int t = 0
			while t < 10
				;SLOVE_Tongue{t+1}Armor = 0x000813 + t
				Form tongueItem = Game.GetFormFromFile(0x000813 + t, "SLOVE.esp")
				if tongueItem
					int cnt = pos.GetItemCount(tongueItem)
					if cnt > 0
						pos.RemoveItem(tongueItem, cnt, abSilent = true)
						removed += cnt
					endif
				endif
				t += 1
			endwhile
		endif
		z += 1
	endwhile
	printdebug("SCENE-END tongue cleanup: items_removed=" + removed)
EndFunction

;-------- armor swap (director.enablearmorswap; port of Hentairim's RunThreadControl step) --------
;The player wears the scene version of every armor SLOVE/ArmorSwapping.json
;lists, from scene start to scene end. The exchange itself, its file and its
;state are SLOVE_Utils.SwapArmor / RestoreArmor (shared by both variants); this
;block only decides WHEN. The two functions are the same in both variants.
;
;Called from AdoptScene once the scene is set up: the framework has stripped by
;then, so what the player still wears is what the scene leaves on, and a listed
;armor the strip took off is simply not there to swap. A scene adopted again
;after a game load finds the swap written on the player and does nothing.
Function SwapSceneArmor()
	if SLOVE_Config.GetInt("director.enablearmorswap", 0) != 1
		return
	endif
	int swapped = SLOVE_Utils.SwapArmor(playerref)
	printdebug("Armor swap : " + swapped + " armor(s) exchanged for the scene")
	if !PlayerInScene
		;the scene ended while the swap was running (every equip call lets other
		;events in): its restore has come and gone, so undo what was swapped since
		SLOVE_Utils.RestoreArmor(playerref)
	endif
EndFunction

;Called from DirectorEndScene. Not behind the switch: whatever is swapped goes
;back, also when the option was turned off mid-scene. The armor taken off at
;scene start was never on the framework's strip list, so its redress and this
;do not undo each other. A stand-in that a later stage stripped comes back with
;that redress and is replaced here, when this runs after it. That holds on the
;AnimationEnd path (the framework sends the event once every actor is reset),
;NOT on the P+ OnUpdate poll: GetThreadByActor stops answering the moment the
;thread starts ending, so the poll can get here before or during the redress
;(open, see the armor swap entry in CLAUDE.md).
Function RestoreSceneArmor()
	int restored = SLOVE_Utils.RestoreArmor(playerref)
	if restored > 0
		printdebug("Armor swap : " + restored + " armor(s) put back on")
	endif
EndFunction

Bool Function AnimationisEnding()
	return isEnding
EndFunction

Event OnUpdate()


	if	!Sexlab.GetPlayerController() ;CURRENT THREAD
		printdebug("-------------End Scene-------------------.")
		DirectorEndScene()
		return
	endif

	printdebug("---Updating---")
	;SLO VE: hotkeys, stage advancing, linear/extend/counter-rape choreography dropped

	;=== Scene or Stage update check ===
	;classic: a "scene change" = the sslBaseAnimation swapped; a "stage change" = the
	;integer stage moved. There is no mid-stage physics overlay on classic (the SLPP
	;node-collision bridge does not exist), so labels only refresh on stage/anim change.
	if UpdateNow || CurrentAnimation != CurrentThread.Animation || CurrentStageNum != CurrentThread.Stage
		printdebug("Updating labels: Scene or Stage changed.")
		CurrentAnimation = CurrentThread.Animation
		CurrentSceneName = CurrentAnimation.Name
		CurrentStageNum = CurrentThread.Stage
		isAlmostFinalStage = isAlmostFinalStage()
		IsFinalStage = IsFinalStage()
		updatelabelsarr()

		LastLabelUpdateTime = CurrentThread.TotalTime
		UpdateNow = false
	endif

	;=== an external mute was just lifted: keep SexLab's own voice silenced ===
	;(why, and for how long: SLOVE_Utils.MuteJustLifted)
	if SLOVE_Utils.MuteJustLifted()
		SuppressSexLabVoice()
	endif

	;=== milk: periodic lactation roll while the PC is being penetrated ===
	;(classic: the penetration label is tag-derived, so the intense/soft split
	;follows the animation's own tags - there is no measured-thrust overlay)
	if milkenable == 1 && CurrentThread.TotalTime >= NextMilkRollTime
		NextMilkRollTime = CurrentThread.TotalTime + milkrollinterval
		string milklbl = GetPenetrationLabel(playerref)
		if milklbl != "LDI" && milklbl != ""
			;the Hentairim original compared this prefix against lowercase "f" -
			;case-sensitive ==, so its penetration rolls always read as non-intense
			bool milkintense = StringUtil.Substring(milklbl, 0, 1) == "F"
			int milkchance = milkchancenonintense
			if milkintense
				milkchance = milkchanceintense
			endif
			if Utility.RandomInt(1, 100) <= milkchance
				Lactate(milkintense)
			endif
		endif
	endif

	;=== Continue Scene or End ===

	RegisterForSingleUpdate(updaterate)

endEvent

bool function isUpdating()
	return updatenow
endfunction

;------------------------------ MILK (Oninus Lactis NG + optional MME) ------------------------------
;Player-only, like the Hentairim original (its per-actor trigger spell also
;always squirted the player). Triggers: any orgasm in the scene (intense), and
;the periodic penetration roll in OnUpdate above.

Bool Function HasMME()
	return SLOVE_Utils.isDependencyReady("MilkModNEW.esp")
endfunction

Bool Function CanLactate()
	if milkenable != 1 || LactisQuest == none
		return false
	endif
	;bare-chest gate: biped slot 32 (body) occupied counts as covered. Simpler
	;than Hentairim's BoobCovers.json slot/name lists; toggle via the toml.
	if milkrequirebarechest == 1 && playerref.GetWornForm(0x4) != none
		return false
	endif
	return true
endfunction

Function Lactate(Bool IsIntense)
	if !CanLactate()
		return
	endif
	int lactatetime = Utility.RandomInt(milkmintime, milkmaxtime)
	int lactatelevel = milklevelnonintense
	if IsIntense
		lactatelevel = milklevelintense
	endif

	;----- Milk Mod Economy (MME) integration -----
	;When MME is installed AND actually tracking this actor, the squirt is driven
	;by the milkmaid's reserve: no squirt when she is nearly empty, and squirting
	;drains what she has. A reserve of milkMax <= 0 means MME is NOT managing this
	;actor (she isn't a registered milkmaid), so the gate must NOT apply - else a
	;player who merely has MME installed would get fullness 0 and never squirt.
	;MME_Storage calls are global functions - they resolve lazily, so this is
	;safe to compile against with MME absent at runtime (guarded by HasMME).
	bool isMME = HasMME()
	if isMME
		float milkMax = MME_Storage.getMilkMaximum(playerref)
		if milkMax > 0.0
			int fullness = Math.Ceiling(MME_Storage.getMilkCurrent(playerref) / milkMax * 100)
			if fullness <= milkmmeminfullness
				printdebug("Milk: MME fullness " + fullness + "% at/below " + milkmmeminfullness + "% - skipping squirt")
				return
			endif
		else
			;MME present but not managing this actor - squirt normally, don't drain
			isMME = false
		endif
	endif

	OninusLactis squirtScript = LactisQuest as OninusLactis
	if squirtScript == none
		SLOVE_Utils.WritetoErrorlogs("Director", "OninusLactis quest script missing - reinstall Oninus Lactis NG")
		return
	endif
	printdebug("Milk: nipple squirt time=" + lactatetime + "s level=" + lactatelevel + " intense=" + IsIntense)
	squirtScript.PlayNippleSquirt(playerref, lactatetime, lactatelevel)

	if isMME
		DrainMMEMilkForSquirt(lactatetime, lactatelevel)
	endif
EndFunction

;Drain the MME reserve proportionally to the squirt: a random 20-50% of current
;milk, scaled down for softer levels and shorter squirts. Ported unchanged from
;Hentairim DrainMMEMilkForSquirt.
Function DrainMMEMilkForSquirt(int lactatetime, int lactatelevel)
	Float curMilk = MME_Storage.getMilkCurrent(playerref)

	Float basePct = Utility.RandomFloat(0.20, 0.50)

	;intensityScale in [0..1]: non-intense squirts drain less than intense ones
	Float intensityScale = 1.0
	if milklevelintense > 0
		intensityScale = (lactatelevel as Float) / (milklevelintense as Float)
		if intensityScale < 0.0
			intensityScale = 0.0
		elseif intensityScale > 1.0
			intensityScale = 1.0
		endif
	endif

	;timeScale in [0.25..1.0]: longer squirts drain more
	Float timeScale = 1.0
	if milkmaxtime > 0
		timeScale = (lactatetime as Float) / (milkmaxtime as Float)
		if timeScale < 0.25
			timeScale = 0.25
		elseif timeScale > 1.0
			timeScale = 1.0
		endif
	endif

	Float drain = curMilk * basePct * intensityScale * timeScale
	if drain > curMilk
		drain = curMilk
	elseif drain < 0.0
		drain = 0.0
	endif

	if drain > 0.0
		MME_Storage.changeMilkCurrent(playerref, 0.0 - drain, false)
		printdebug("Milk: MME drained " + drain + " (was " + curMilk + ")")
	endif
EndFunction

;Console test hook ('slovetest milk [1]'): force a nipple squirt on the player,
;bypassing the scene orgasm/penetration triggers, so [milk] levels and chances can be
;tuned without playing out a scene. Still honours the real gates (milk.enable,
;OninusLactis present, bare-chest) and prints which one blocked it. abIntense picks
;milk.levelintense over milk.levelnonintense. Console-invoked only - never on the load
;path, so the MiscUtil.PrintConsole calls are safe here.
Function TestMilk(Bool abIntense)
	if playerref == none
		playerref = Game.GetPlayer()
	endif
	if milkenable != 1
		MiscUtil.PrintConsole("SLOVE milk: disabled - set milk.enable = 1 (and install Oninus Lactis NG), then 'SLOVE_Config Reload'.")
		return
	endif
	if LactisQuest == none
		MiscUtil.PrintConsole("SLOVE milk: OninusLactis.esp not loaded / quest 0xD61 missing - install Oninus Lactis NG.")
		return
	endif
	if milkrequirebarechest == 1 && playerref.GetWornForm(0x4) != none
		MiscUtil.PrintConsole("SLOVE milk: blocked by the bare-chest gate (body slot occupied). Unequip the chest piece or set milk.requirebarechest = 0.")
		return
	endif
	;MME fullness gate - mirror Lactate's check so the test reports the same skip a live
	;scene would take (else "forcing squirt" prints while Lactate silently no-ops). Only
	;bites when MME actually manages the player (getMilkMaximum > 0).
	if HasMME()
		float milkMax = MME_Storage.getMilkMaximum(playerref)
		if milkMax > 0.0
			int fullness = Math.Ceiling(MME_Storage.getMilkCurrent(playerref) / milkMax * 100)
			if fullness <= milkmmeminfullness
				MiscUtil.PrintConsole("SLOVE milk: MME fullness " + fullness + "% at/below milk.mmeminfullness (" + milkmmeminfullness + "%) - a live scene would SKIP this squirt. Fill up or lower milk.mmeminfullness.")
				return
			endif
			MiscUtil.PrintConsole("SLOVE milk: MME fullness " + fullness + "% (above " + milkmmeminfullness + "%) - the squirt will drain the reserve.")
		else
			MiscUtil.PrintConsole("SLOVE milk: MME present but not managing the player - squirting normally, no drain.")
		endif
	endif
	int lvl = milklevelnonintense
	if abIntense
		lvl = milklevelintense
	endif
	MiscUtil.PrintConsole("SLOVE milk: forcing squirt (intense=" + abIntense + " level=" + lvl + ")")
	Lactate(abIntense)
EndFunction

float function GetDirectorLastLabelTime()
	return LastLabelUpdateTime
endfunction

float function GetDirectorLastPhysicsLabelTime()
	return LastPhysicsLabelTime
endfunction

Function ApplySpells()
	;SLO VE: slim port of AddTrackerToSceneIfApplicable. AudioUtil owns the voices,
	;so we silence SexLab's own moan engine per actor (SuppressSexLabVoice, behind
	;director.suppresssexlabvoice); no SFX/resistance module thread control.
	SuppressSexLabVoice()

	;---------------Applying Voice Spell to Player-------------------
	if VoiceSpell
		if playerref.HasSpell(VoiceSpell)
			playerref.RemoveSpell(VoiceSpell)
		endif
		if enablevoice == 1
			printdebug("playerref added SLO VE Voice Spell")
			playerref.AddSpell(VoiceSpell, abVerbose = False)
		endif
	endif

	;---------------Applying SFX Spell to Actors (all positions, creatures too)------------------
	if enablesfx == 1 && SFXSpell
		int y = 0
		while y < actorList.length
			if actorList[y].HasSpell(SFXSpell)
				actorList[y].RemoveSpell(SFXSpell)
			endif
			printdebug(actorList[y].getdisplayname() + " added SFX Spell")
			actorList[y].AddSpell(SFXSpell, abVerbose = False)
			y += 1
		EndWhile
	endif

	;---------------Applying Expressions Spell to Actors------------------
	if EnableExpressions == 1 && ExpressionsSpell

		int z = 0
		while z < actorList.length
			if sexlab.GetGender(actorList[z]) <= 1 ;not creature
				if actorList[z].HasSpell(ExpressionsSpell)
					actorList[z].RemoveSpell(ExpressionsSpell)
				endif
				if actorList[z] == playerref && enablepcexpression == 1
					printdebug(actorList[z].getdisplayname() + " added Expression Spell")
					actorList[z].AddSpell(ExpressionsSpell, abVerbose = False)
				elseif sexlab.GetGender(actorList[z]) == 0 && enablemalenpcexpression == 1
					printdebug(actorList[z].getdisplayname() + " added Expression Spell")
					actorList[z].AddSpell(ExpressionsSpell, abVerbose = False)
				elseif sexlab.GetGender(actorList[z]) == 1 && enablefemalenpcexpression == 1
					printdebug(actorList[z].getdisplayname() + " added Expression Spell")
					actorList[z].AddSpell(ExpressionsSpell, abVerbose = False)
				endif
			endif
			z += 1
		EndWhile
	EndIf

	;---------------Applying Resistance Spell to Actors (all positions incl. creatures)------------------
	if enableresistance == 1 && ResistanceSpell
		int r = 0
		while r < actorList.length
			bool apply = false
			if actorList[r] == playerref
				apply = resenablepc == 1
			elseif sexlab.GetGender(actorList[r]) == 0
				apply = resenablemalenpc == 1
			elseif sexlab.GetGender(actorList[r]) == 1
				apply = resenablefemalenpc == 1
			else
				apply = resenablecreaturenpc == 1
			endif
			if actorList[r].HasSpell(ResistanceSpell)
				actorList[r].RemoveSpell(ResistanceSpell)
			endif
			if apply
				printdebug(actorList[r].getdisplayname() + " added Resistance Spell")
				actorList[r].AddSpell(ResistanceSpell, abVerbose = False)
			endif
			r += 1
		EndWhile
	EndIf
EndFunction

;--------------------------- NPC-only scene support START ------------------------
;Per-actor module spells (SLOVE_Expressions/SFX/Resistance) tell a PC-scene actor from
;an NPC-scene actor with Positions.Find(playerref) on their OWN thread - no Director call
;needed - so a PC-scene actor keeps the Director's labels while an NPC-scene actor
;self-computes labels off its own thread.

;NPC-only scene adoption. Called from DirectorSceneStart for a thread the player is
;NOT in. Gated by director.enablenpcscenes, a distance-to-player check, and the
;concurrency cap. Applies the per-actor module spells (they self-terminate with their
;own thread) and puts the SLOVE_NpcScene ambient-voice ability on one anchor actor.
Function TryAdoptNpcScene(int tid)
	;An NPC-only scene is a scene start too: re-read the cached settings, or the
	;gates below and the module switches ApplyModuleSpellsToNpcList reads stay as
	;they were at the last game load or player scene, and a change made in the
	;in-game menu (or a hand edit + reload) never reaches NPC-only scenes. Not
	;while a player scene runs: that scene refreshed them when it started, and
	;its update loop is reading them (the refresh writes milkenable twice).
	if !PlayerInScene
		InitializeDirectorConfigs()
	endif
	if enablenpcscenes != 1
		return
	endif
	sslThreadController t = Sexlab.GetController(tid)
	if !t
		return
	endif
	Actor[] positions = t.Positions
	if !positions || positions.length == 0 ;NOT "== None": comparing a None array logs a cast error
		return
	endif
	;player is actually in this thread (concurrent PC scene) -> leave it to the PC path
	if positions.Find(playerref) >= 0
		return
	endif
	Actor anchor = positions[0]
	if !anchor
		return
	endif
	if NpcSceneSpell && anchor.HasSpell(NpcSceneSpell)
		return
	endif
	float dist = playerref.GetDistance(anchor)
	if dist > npcscenedistance
		printdebug("NPC scene ignored - too far (" + (dist as int) + " > " + (npcscenedistance as int) + ")")
		return
	endif
	if PruneNpcSceneAnchors() >= maxnpcscenes
		printdebug("NPC scene ignored - at concurrency cap (" + maxnpcscenes + ")")
		return
	endif

	printdebug("Adopting NPC scene tid=" + tid + " actors=" + positions.length + " anchor=" + anchor.GetDisplayName())
	ApplyModuleSpellsToNpcList(positions)
	if NpcSceneSpell
		anchor.AddSpell(NpcSceneSpell, abVerbose = False)
		if !NpcSceneAnchors ;NOT "== None": comparing a None array logs a cast error
			NpcSceneAnchors = PapyrusUtil.ActorArray(0)
		endif
		NpcSceneAnchors = PapyrusUtil.PushActor(NpcSceneAnchors, anchor)
	endif
EndFunction

;Drop anchors whose NPC scene has ended (no controller, or ability lost); returns the
;count still active. Keeps the concurrency cap honest without a scene-end handshake.
int Function PruneNpcSceneAnchors()
	if !NpcSceneAnchors ;NOT "== None": comparing a None array logs a cast error
		NpcSceneAnchors = PapyrusUtil.ActorArray(0)
		return 0
	endif
	Actor[] live = PapyrusUtil.ActorArray(0)
	int i = 0
	while i < NpcSceneAnchors.length
		Actor a = NpcSceneAnchors[i]
		if a && NpcSceneSpell && a.HasSpell(NpcSceneSpell) && Sexlab.GetActorController(a)
			live = PapyrusUtil.PushActor(live, a)
		endif
		i += 1
	endwhile
	NpcSceneAnchors = live
	return live.length
EndFunction

;Apply the per-actor module spells (SFX / Expressions / Resistance) to an NPC-only
;scene's actors, honoring the same enable + per-gender NPC gating as ApplySpells
;(minus the PC voice spell, milk, and PC-only branches). remove-then-add is idempotent.
;Each spell resolves its own thread from the actor and self-terminates when it ends.
Function ApplyModuleSpellsToNpcList(Actor[] list)
	if enablesfx == 1 && SFXSpell
		int y = 0
		while y < list.length
			if list[y]
				if list[y].HasSpell(SFXSpell)
					list[y].RemoveSpell(SFXSpell)
				endif
				list[y].AddSpell(SFXSpell, abVerbose = False)
			endif
			y += 1
		endwhile
	endif
	if enableExpressions == 1 && ExpressionsSpell
		int z = 0
		while z < list.length
			if list[z] && sexlab.GetGender(list[z]) <= 1
				if list[z].HasSpell(ExpressionsSpell)
					list[z].RemoveSpell(ExpressionsSpell)
				endif
				if sexlab.GetGender(list[z]) == 0 && enablemalenpcexpression == 1
					list[z].AddSpell(ExpressionsSpell, abVerbose = False)
				elseif sexlab.GetGender(list[z]) == 1 && enablefemalenpcexpression == 1
					list[z].AddSpell(ExpressionsSpell, abVerbose = False)
				endif
			endif
			z += 1
		endwhile
	endif
	if enableresistance == 1 && ResistanceSpell
		int r = 0
		while r < list.length
			if list[r]
				bool apply = false
				if sexlab.GetGender(list[r]) == 0
					apply = resenablemalenpc == 1
				elseif sexlab.GetGender(list[r]) == 1
					apply = resenablefemalenpc == 1
				else
					apply = resenablecreaturenpc == 1
				endif
				if list[r].HasSpell(ResistanceSpell)
					list[r].RemoveSpell(ResistanceSpell)
				endif
				if apply
					list[r].AddSpell(ResistanceSpell, abVerbose = False)
				endif
			endif
			r += 1
		endwhile
	endif
EndFunction
;--------------------------- NPC-only scene support END ------------------------

;SLO VE: force SexLab's own voice silent for every scene actor so AudioUtil is the
;sole voice source (restores Hentairim's sslVoiceSlots wipe). ForceSilence auto-resets
;when SexLab clears the aliases at scene end, so no restore hook is needed. Gated on
;enablevoice too - never leave a scene dead silent when SLO VE voice is off.
Function SuppressSexLabVoice()
	;!Available() = AudioUtil DLL missing -> AudioUtil.Play no-ops, so DON'T silence
	;SexLab too (that would be dead silence). Fail open to SexLab's own moans instead.
	;!actorList, NOT "actorList == none": comparing a None array logs a cast error
	if enablevoice != 1 || suppresssexlabvoice != 1 || CurrentThread == none || !actorList || !SLOVE_Config.Available()
		return
	endif
	int i = 0
	while i < actorList.length
		;an actor another mod has muted here (SLOVE_Mute_*) keeps whatever SexLab voice
		;state that mod gave them - it may have muted us to let SexLab's voice play
		if SLOVE_Utils.MuteLevel(actorList[i], CurrentThreadID) == 0
			sslActorAlias a = CurrentThread.ActorAlias(actorList[i])
			if a
				a.SetVoice(none, true) ;ForceSilence -> SexLab plays no moans for this actor
			endif
		endif
		i += 1
	endwhile
	printdebug("SexLab voice silenced for " + actorList.length + " scene actor(s)")
EndFunction

Function RegisterThatSceneIsEnding(Bool maleOnlyScene)
	;SLO VE: no-op kept for consumer-port compatibility (original body was already disabled)
EndFunction

;0 = not probed yet, 1 = AudioUtil supports tagged playback, -1 = it predates it
int audioUtilTagAPI

;the running animation's display name, cached at every scene change so the voice
;trace can name it without a registry lookup per line
string CurrentSceneName

Function PlaySound(String theSound, Actor actorMakingSound, Bool waitForCompletion = True, String group = "", String channel = "", String facts = "")
	;theSound is a AudioUtil category name; slot is resolved from the actor by the DLL.
	;blockLipSync per line when a face (SLS ahegao or our own climax face) owns the
	;actor's mouth, so the moan can't flap the jaw over it. Decided per call - there
	;is no standing block in AudioUtil.
	;PlayTagged with empty facts is byte-for-byte AudioUtil.Play, so every line
	;routes through the tagged path unconditionally - no per-variation branch.
	;The facts only engage tagged pools a Variation-D pack actually ships.
	;PlayTagged and its PlayVoiceTagged native arrived in AudioUtil 0.9.17 (API v6).
	;On an older AudioUtil the call cannot bind and EVERY voice line dies with it -
	;a silent engine on an install that is otherwise fine - so probe the version
	;once and fall back to the untagged Play, which is what PlayTagged reduces to
	;with empty facts anyway. Papyrus resolves global calls lazily, so the tagged
	;branch is never touched on an install that cannot supply it.
	;external mute (SLOVE_Mute_*, see SLOVE_Utils): another mod has taken this actor's
	;voice for the stage or the scene. This is the one door every voice line leaves
	;through - the PC engine, its partner and creature ambience, the NPC-scene
	;driver - so the gate is here; SLOVE_Voice.PlaySound also asks, earlier, only to
	;spare its own ducking and waits. The actor's thread is looked up only when a
	;mute is written on them at all; an actor who resolves to no thread any more
	;(-1, the scene's last moments) is judged on the thread the mute was set in.
	if SLOVE_Utils.MuteWritten(actorMakingSound) && SLOVE_Utils.MuteLevel(actorMakingSound, ActorThreadID(actorMakingSound)) > 0
		printdebug("Voice line dropped (muted by '" + SLOVE_Utils.MutedBy(actorMakingSound) + "') : " + theSound)
		return
	endif
	bool mouthOwned = FaceOwnsMouth(actorMakingSound)
	if audioUtilTagAPI == 0
		if AudioUtil.GetAPIVersion() >= 6
			audioUtilTagAPI = 1
		else
			audioUtilTagAPI = -1
			SLOVE_Log.WriteLog("Voice : AudioUtil API v" + AudioUtil.GetAPIVersion() + " predates tagged playback (v6 / 0.9.17) - Variation-D facts ignored, untagged pools play as before", 0)
		endif
	endif
	int h
	if audioUtilTagAPI == 1
		h = AudioUtil.PlayVoiceTagged(actorMakingSound, theSound, facts, 1.0, group, channel, mouthOwned)
	else
		h = AudioUtil.PlayVoice(actorMakingSound, theSound, 1.0, group, channel, mouthOwned)
	endif
	if enableprintdebug == 1
		TraceVoiceLine(theSound, actorMakingSound, group, channel, facts, h)
	endif
	if waitForCompletion
		AudioUtil.WaitForHandle(h)
	endif
EndFunction

;Resolution trace for the voice log, written AFTER the play so it can state the
;OUTCOME and not just the request. That distinction is the whole point of it:
;the old trace printed `files=` from GetCategoryFileCount, which is a FULL
;resolve - it walks the alias/fallback ladder and the fallback-slot chain - so
;for the thirteen A-name/B-folder mismatches fixed in 0.6.15 it happily reported
;the F0 stock folder's file count and looked healthy while the pack was being
;bypassed entirely. A log of what we ASKED for cannot catch a resolution bug.
;GetHandlePath is ground truth: the exact wav AudioUtil chose, whose path names
;the pack folder it came from. Read right after the play, while the instance is
;alive. `files` survives only on the nothing-played branch, where it still
;separates "the category resolves nowhere" from "it resolves but the line was
;dropped" (scene-end stop, duck, or a busy channel).
Function TraceVoiceLine(String theSound, Actor actorMakingSound, String group, String channel, String facts, Int h)
	string slot = AudioUtil.GetSlotForActor(actorMakingSound)
	string line = "Play '" + theSound + "' actor=" + actorMakingSound.GetDisplayName()
	line = line + " slot=" + slot + " facts=[" + facts + "]"
	line = line + " anim=" + CurrentSceneName + " stage=" + CurrentStageNum
	line = line + " group=" + group + " chan=" + channel
	if h > 0
		line = line + " -> " + AudioUtil.GetHandlePath(h)
	else
		line = line + " -> NOTHING PLAYED (resolved folder holds " + AudioUtil.GetCategoryFileCount(slot, theSound) + " files)"
	endif
	printdebug(line)
	SLOVE_Log.WriteLog("Voice : " + line, 0)
EndFunction

;true while any SLO VE face owns this actor's mouth - the Director's SLS ahegao
;marker OR SLOVE_Expressions' climax-face marker. Either being set means a voice
;line should play without driving the mouth.
bool Function FaceOwnsMouth(Actor a)
	;a marker face (SLS ahegao / our climax face / an equipped tongue) claimed the mouth
	;via the Expressions tick - block this line so a moan can't flap the jaw over it.
	if StorageUtil.GetIntValue(a, "SLOVE_FaceOwnsMouth_SLS", 0) == 1 || StorageUtil.GetIntValue(a, "SLOVE_FaceOwnsMouth_Expr", 0) == 1
		return true
	endif
	;live oral-giver check (race-free): a mouth actively licking must never have its jaw
	;driven by a moan clip. The _Expr marker above is set only once per Expressions tick,
	;so a line firing in that gap would otherwise lipsync and zero the mouth at clip-end.
	;Deciding it here at play time closes that window.
	return IsOralGiver(a)
EndFunction

;True while actor a's own mouth is busy performing oral. Classic SexLab 1.63 has no live
;interaction flags (tongues are P+-only), so the authored oral label is the whole signal
;here - unlike the P+ Director, which also reads the live aOral giver flags. CUN is
;cunnilingus; SBJ/FBJ are soft/forced blowjob (mouth full of cock) - all occupy the mouth,
;so a moan clip must not drive the jaw over any of them (IsSuckingoffOther is SBJ||FBJ).
bool Function IsOralGiver(Actor a)
	string oral = GetOralLabel(a)
	return oral == "CUN" || oral == "RIM" || oral == "SBJ" || oral == "FBJ"
EndFunction

bool function IsMale(actor char)
	return sexlab.GetGender((char)) == 0
endfunction

;---------------------------Stage Control FUNCTIONS (trimmed)------------------------
;SLO VE: dropped - Enable/DisableOrgasm wrappers. They existed only for
;Hentairim's edging system (hold the orgasm during "hype" lines, release it
;later); SLO VE never disables orgasm, so the enables were re-enabling nothing.

Bool Function AllFemale()

	if CountFemale(actorlist) == actorlist.length
		return true
	else
		return false
	endIf
endfunction

function printdebug(string contents = "")
	if enableprintdebug == 1
		SLOVE_Log.WriteLog("SLO VE Director : "+ contents, 0)
	endif
endfunction

;---------------------------Label Engine START------------------------
string[] Stimulationlabelarr
string[] PenisActionLabelarr
string[] OralLabelarr
string[] PenetrationLabelarr
string[] EndingLabelarr
string Labelsconcat
Function UpdateLabelsArr()
	;classic: labels come from SLATE-applied per-stage/per-position animation tags
	;(see SLOVE_Hentairim_Tags) - same fidelity as the P+ registry path. There is
	;no node-collision physics on classic, so there is no mid-stage overlay: one
	;classification per stage is final. The physics label bridge and the
	;SexlabRegistry climax annotations are removed on this branch.
	sslBaseAnimation anim = CurrentThread.Animation
	Stimulationlabelarr = SLOVE_Hentairim_Tags.GetStimulationlabelarr(anim , CurrentStageNum , actorlist)
	PenisActionLabelarr = SLOVE_Hentairim_Tags.GetPenisActionlabelarr(anim , CurrentStageNum , actorlist)
	OralLabelarr = SLOVE_Hentairim_Tags.GetOrallabelarr(anim , CurrentStageNum , actorlist)
	PenetrationLabelarr = SLOVE_Hentairim_Tags.GetPenetrationLabelarr(anim , CurrentStageNum , actorlist)
	EndingLabelarr = SLOVE_Hentairim_Tags.GetEndingLabelarr(anim , CurrentStageNum , actorlist)

	Labelsconcat = "1" + Stimulationlabelarr[0] + "1" + PenisActionLabelarr[0] + "1" + OralLabelarr[0] + "1" + PenetrationLabelarr[0] + "1" + EndingLabelarr[0]

	printdebug("Stimulationlabelarr : " + Stimulationlabelarr)
	printdebug("PenisActionLabelarr : " + PenisActionLabelarr)
	printdebug("OralLabelarr : " + OralLabelarr)
	printdebug("PenetrationLabelarr : " + PenetrationLabelarr)
	printdebug("EndingLabelarr : " + EndingLabelarr)
endfunction

bool Function SceneisIntense()
	return stringutil.find(Labelsconcat ,"1F") > -1
endfunction

;----------------LABEL GETTERS===============
string function GetStimulationlabel(actor char)
	if !CurrentThread
		return ""
	endif
	int idx = CurrentThread.Positions.Find(char)
	if idx < 0
		return ""
	endif
	return Stimulationlabelarr[idx]
endfunction

string function GetPenisActionLabel(actor char)
	if !CurrentThread
		return ""
	endif
	int idx = CurrentThread.Positions.Find(char)
	if idx < 0
		return ""
	endif
	return PenisActionLabelarr[idx]
endfunction

string function GetOralLabel(actor char)
	if !CurrentThread
		return ""
	endif
	int idx = CurrentThread.Positions.Find(char)
	if idx < 0
		return ""
	endif
	return OralLabelarr[idx]
endfunction

string function GetPenetrationLabel(actor char)
	if !CurrentThread
		return ""
	endif
	int idx = CurrentThread.Positions.Find(char)
	if idx < 0
		return ""
	endif
	return PenetrationLabelarr[idx]
endfunction

string function GetEndingLabel(actor char)
	if !CurrentThread
		return ""
	endif
	int idx = CurrentThread.Positions.Find(char)
	if idx < 0
		return ""
	endif
	return EndingLabelarr[idx]
endfunction

Bool Function ActorIsgettingTitfucked(actor char)
	return  Getpenisactionlabel(char) == "STF" || Getpenisactionlabel(char) == "FTF"
endfunction

Bool Function ActorIsgivingtitfuck(actor char)
	if actorlist[0] != char || actorlist.length < 2
		return false
	endif
	if Getpenisactionlabel(actorlist[1]) == "STF" || Getpenisactionlabel(actorlist[1]) == "FTF"
		return true
	endif
	;third position tested only when present (out-of-bounds guard); STF was a copy-paste of FTF before
	if actorlist.length > 2 && (Getpenisactionlabel(actorlist[2]) == "STF" || Getpenisactionlabel(actorlist[2]) == "FTF")
		return true
	endif
	return false
endfunction

Bool Function ActorIsgettingHandjobbed(actor char)
	return  Getpenisactionlabel(char) == "SHJ" || Getpenisactionlabel(char) == "FHJ"
endfunction

Bool Function ActorIsgettingFootjobbed(actor char)
	return  Getpenisactionlabel(char) == "SFJ" || Getpenisactionlabel(char) == "FFJ"
endfunction

Bool Function ActorIsgettingSuckedOff(actor char)
	return  Getpenisactionlabel(char) == "SMF" || Getpenisactionlabel(char) == "FMF"
endfunction

Bool Function IsgettingPenetrated(actor char)
	return IsGettingAnallyPenetrated(char) || IsGettingVaginallyPenetrated(char)
endfunction

Bool Function IsgettingDoublePenetrated(actor char)
	return GetPenetrationLabel(char) == "SDP" || GetPenetrationLabel(char) == "FDP"
endfunction

Bool Function IsLeadIN(actor char)
	return GetStimulationlabel(char) == "LDI" && GetPenisActionlabel(char) == "LDI" && GetPenetrationlabel(char) == "LDI" && GetOralLabel(char) == "LDI" && GetEndingLabel(char) == "LDI"
endfunction

Bool Function IsSuckingoffOther(actor char)
	return GetOralLabel(char) == "SBJ" ||  GetOralLabel(char) == "FBJ"
endfunction

Bool Function IsCowgirl(actor char)
	return GetPenetrationLabel(char) == "SCG" ||  GetPenetrationLabel(char) == "FCG" ||  GetPenetrationLabel(char) == "SAC" ||  GetPenetrationLabel(char) == "FAC"
endfunction

Bool Function IsEnding(actor char)
	return GetEndingLabel( char) == "ENI" || GetEndingLabel( char) == "ENO"
endfunction

Bool Function IsGettingVaginallyPenetrated(actor char)
	return GetPenetrationLabel(char) == "SVP" || GetPenetrationLabel(char) == "FVP" || GetPenetrationLabel(char) == "SCG" || GetPenetrationLabel(char) == "FCG" || GetPenetrationLabel(char) == "SDP" || GetPenetrationLabel(char) == "FDP"
endfunction

Bool Function IsGettingAnallyPenetrated(actor char)
	return GetPenetrationLabel(char) == "SAP" || GetPenetrationLabel(char) == "FAP"  || GetPenetrationLabel(char) == "SAC" || GetPenetrationLabel(char) == "FAC" || GetPenetrationLabel(char) == "SDP" || GetPenetrationLabel(char) == "FDP"
endfunction

Bool Function IsGivingAnalPenetration(actor char)
	return GetPenisActionLabel(char) == "FDA" || GetPenisActionLabel(char) == "SDA"
endfunction

Bool Function IsGivingVaginalPenetration(actor char)
	return GetPenisActionLabel(char) =="FDV" || GetPenisActionLabel(char) == "SDV"
endfunction
;---------------------------Label Engine END------------------------

;---------------------------Director's Utility START------------------------

;classic: stages are integers (1..StageCount) and the final stage is the last one -
;there is no SexlabRegistry, no per-stage string ids, and no climax-stage table.
int Function GetLegacyStagesCount(String asScene)
	if CurrentThread == none || CurrentThread.Animation == none
		return 0
	endif
	return CurrentThread.Animation.StageCount
EndFunction

bool Function isFinalStage()
	return CurrentStageNum >= GetFinalStageNum()
EndFunction

int Function GetFinalStageNum()
	;classic: scan the animation's EN tags for the real ending stage (SLATE data),
	;falling back to the last stage when the animation carries no EN annotation.
	if CurrentThread == none || CurrentThread.Animation == none
		return CurrentStageNum
	endif
	sslBaseAnimation anim = CurrentThread.Animation
	int stagecount = anim.StageCount
	if stagecount < 1
		stagecount = 1
	endif

	int FinalStageNum = stagecount
	Bool Foundending
	int z = stagecount
	while z > 0 && !Foundending
		string tmpendinglabel = SLOVE_Hentairim_Tags.EndingLabel(anim , z , 0)
		if tmpendinglabel == "ENO" || tmpendinglabel == "ENI"
			Foundending = true
			FinalStageNum = z
		endif
		z -= 1
	endwhile

	return FinalStageNum
EndFunction

bool Function isAlmostFinalStage()

	return CurrentStageNum >= GetFinalStageNum() - 1
EndFunction

bool Function PCisVictim()
	return CurrentThread.IsVictim(playerref)
EndFunction

bool Function isVictim(actor char)
	return CurrentThread.IsVictim(char)
EndFunction

bool Function PCisAggressor()
	actor[] victimlist = CurrentThread.Victims
	int z = 0
	while z < victimlist.length
		if victimlist[z] == playerref
			return false
		endif
		z += 1
	endwhile

	if victimlist.length > 0
		return true
	else
		return  false
	endif
EndFunction

Bool Function ScenehasCreatures()
	return CountCreatures(actorList) > 0
endfunction

;classic SexLab has no SexLab.CountFemale / CountCreatures helpers - count locally
;from the SexLab gender (0 male, 1 female, 2 male creature, 3 female creature).
int Function CountFemale(Actor[] list)
	int n = 0
	int z = 0
	while z < list.length
		if list[z] && sexlab.GetGender(list[z]) == 1
			n += 1
		endif
		z += 1
	endwhile
	return n
EndFunction

int Function CountCreatures(Actor[] list)
	int n = 0
	int z = 0
	while z < list.length
		if list[z] && sexlab.GetGender(list[z]) >= 2
			n += 1
		endif
		z += 1
	endwhile
	return n
EndFunction

Bool function IshugePP(actor char)
	int HugePPSchlongSize
	HugePPSchlongSize = SLOVE_Config.GetInt("director.soshugeppsize" ,6)
	Race charRace = char.GetRace()
	String charraceName = charRace.GetName()
	if stringutil.find(charraceName, "Brute") > -1 || stringutil.find(charraceName, "Spider") > -1 || stringutil.find(charraceName, "Lurker") > -1 || stringutil.find(charraceName, "Daedroth") > -1 || stringutil.find(charraceName, "Horse") > -1 || stringutil.find(charraceName, "Bear") > -1 || stringutil.find(charraceName, "Chaurus") > -1 || stringutil.find(charraceName, "Dragon") > -1 || charraceName == "Frost Atronach" || stringutil.find(charraceName, "Giant") > -1 || charraceName == "Mammoth" || charraceName == "Sabre Cat" || stringutil.find(charraceName, "Troll") > -1 || charraceName == "Werewolf" || stringutil.find(charraceName, "Gargoyle") > -1 || charraceName == "Dwarven Centurion" || stringutil.find(charraceName, "Ogre") > -1 || charraceName == "Ogrim" || charraceName == "Nest Ant Flier"
		return True
	else
		;if Schlong is big
		if (SchlongFaction)
			return char.GetFactionRank(SchlongFaction) >= HugePPSchlongSize
		elseif TNG_Gentlewoman
			if char.GetActorBase().GetSex() == 1 && char.HasKeyword(TNG_Gentlewoman) && TNG_PapyrusUtil.GetActorSize(char) == 4
				return true
			else
				return false
			endif
		elseif PO3_SKSEFunctions.IsPluginFound("TheNewGentleman.esp") && TNG_PapyrusUtil.GetActorSize(char) == 4
			return true
		endif
		return false
	endif
EndFunction

Int Function GetNormalizedPenisSize(Actor char)
	;0-4 scale (4 = huge); -1 = female / no sizing mod. Ported from
	;IVDTControllerScript for the SFX module's ejaculation-sound pick.
	int ModPenisSize = -1
	int HugePPSchlongSize = SLOVE_Config.GetInt("director.soshugeppsize", 6)

	Int Sex = Sexlab.GetGender(char)

	if Sex == 1
		return -1
	endif

	if Sex >= 2 ; creature (classic gender scale: 2 = male creature, 3 = female creature)
		if IshugePP(char)
			return 4
		elseif IsSmallPP(Char)
			return 0
		else
			return 2
		endif
	else
		if SchlongFaction
			int SchlongSize = char.GetFactionRank(SchlongFaction) ; 1 - 16
			if SchlongSize < 1
				SchlongSize = 1
			elseif SchlongSize > 16
				SchlongSize = 16
			endif

			if SchlongSize >= HugePPSchlongSize
				ModPenisSize = 4
			else
				; Scale 0 -> 3 for ranks below threshold
				ModPenisSize = Math.Floor((SchlongSize * 3.0) / HugePPSchlongSize)
			endif

		elseif PO3_SKSEFunctions.IsPluginFound("TheNewGentleman.esp")
			ModPenisSize = TNG_PapyrusUtil.GetActorSize(char)
		endif
	endif

	return ModPenisSize
EndFunction

Bool Function IsSmallPP(Actor Char)
	Int Sex = Sexlab.GetGender(char)
	if Sex <= 1 ;classic gender scale: 0/1 human, 2/3 creature (no futa)
		return GetNormalizedPenisSize(Char) <= 0
	else
		String charraceName = char.GetRace().GetName()
		if stringutil.find(charraceName, "rabbit") > -1 || stringutil.find(charraceName, "fox") > -1 || stringutil.find(charraceName, "Skeever") > -1
			return TRUE
		else
			return false
		endIf
	endif

EndFunction

;-----------Schlong alignment memory (SLOVE_SFX adaptive velocity)-----------
;The SFX module's SOSBend calibration search only had a signal to search on when
;SLPP node-collision data existed (P+). Classic has no such physics, so the
;adaptive-velocity search and this memory are inert on this branch - kept as
;no-ops so the Director API surface (SaveSchlongAdjustment) is unchanged.

Function SaveSchlongAdjustment(int schlongposition, int value)
	;no-op on classic (no node-collision calibration to record)
endFunction

Function LoadSchlongAdjustment()
	;no-op on classic (nothing was recorded)
endFunction

Bool Function IsWearingGag(Actor char)
	if !zad_DeviousGag ;SLO VE: Devious Devices not installed
		return false
	endif
	return char.WornHasKeyword(zad_DeviousGag)
endfunction

;---------------------------Director's Utility END------------------------

;---------------------------Scene API pass-throughs START------------------------
;SLO VE: thin wrappers so consumers never touch SexLabThread directly; this plus the
;SLOVE_* mod events is the whole framework seam (see docs\framework-adapter.md)

Actor[] Function GetPositions()
	if !CurrentThread
		Actor[] emptylist
		return emptylist
	endif
	return CurrentThread.Positions
EndFunction

int Function GetPositionIdx(actor char)
	if !CurrentThread
		return -1
	endif
	return CurrentThread.Positions.Find(char)
EndFunction

Int SLSOReadyCache = 0 ;0 = unknown, 1 = SLSO present, -1 = absent (lazy, cached once)

;SLSO's minigame pins SexLab's GetEnjoyment() at 0 for the whole scene and keeps
;the live meter in the alias's GetFullEnjoyment() - the value SLSO's own voice
;reads (SLSO_SpellVoiceScript). Read that meter when SLSO is present; fall back
;to GetEnjoyment() when SLSO is absent or the meter is still 0 (lead-in /
;passive setups). Lived in SLOVE_Voice until the variant unification - it is
;framework truth, not voice policy, so it belongs behind the adapter seam where
;every consumer of GetEnjoyment gets the honest value.
int Function GetEnjoyment(actor char)
	if !CurrentThread
		return 0
	endif
	If SLSOReadyCache == 0
		If SLOVE_Utils.isDependencyReady("SLSO.esp")
			SLSOReadyCache = 1
		Else
			SLSOReadyCache = -1
		EndIf
	EndIf
	If SLSOReadyCache == 1
		sslActorAlias al = CurrentThread.ActorAlias(char)
		If al
			Int full = al.GetFullEnjoyment()
			If full > 0
				Return full
			EndIf
		EndIf
	EndIf
	return CurrentThread.GetEnjoyment(char)
EndFunction

float Function GetTimeTotal()
	if !CurrentThread
		return 0.0
	endif
	return CurrentThread.TotalTime
EndFunction

;On classic SexLab the thread's Tags array is start-context only - stock SexLab never
;copies the chosen animation's tags onto the thread - so the ANIMATION's own tag list
;(what the SLAL json registers and SLATE edits) is the real scene-tag source. The
;thread check stays as a bonus for mods that AddTag() context onto their threads.
bool Function HasSceneTag(string asTag)
	if !CurrentThread
		return false
	endif
	sslBaseAnimation anim = CurrentThread.Animation
	return (anim && anim.HasTag(asTag)) || CurrentThread.HasTag(asTag)
EndFunction

bool Function IsSubmissive(actor char)
	if !CurrentThread
		return false
	endif
	return CurrentThread.IsVictim(char)
EndFunction

;Is classic SexLab animating this actor with a strap-on? Its alias flag (UseStrapon:
;strap-on slot set, not a creature). The voice engine's implement facts ask this
;instead of guessing "strapon" for any woman without a schlong.
Bool Function IsUsingStrapon(Actor char)
	if !CurrentThread || !char
		return false
	endif
	sslActorAlias al = CurrentThread.ActorAlias(char)
	if !al
		return false
	endif
	return al.UseStrapon
EndFunction

;classic has no string scene id: the scene identity is the active sslBaseAnimation.
;Returned as a stable per-animation string for consumers/logging.
string Function GetActiveSceneId()
	return CurrentAnimation as string
EndFunction

int Function GetStageNum()
	return CurrentStageNum
EndFunction

int Function GetStagesCount()
	if CurrentThread == none
		return 0
	endif
	return GetLegacyStagesCount("")
EndFunction

int Function GetGender(actor char)
	return sexlab.GetGender(char)
EndFunction

;The actor's SEX TIER. Classic SexLab has no futa tier, so the gender value IS
;the tier (Male 0 / Female 1); P+ overrides this with GetSex. See the P+ twin.
int Function GetSexTier(actor char)
	return sexlab.GetGender(char)
EndFunction

int Function GetThreadID()
	if !CurrentThread
		return -1
	endif
	return CurrentThread.tid
EndFunction

bool Function HasSubmissives()
	if !CurrentThread
		return false
	endif
	return CurrentThread.Victims.length > 0
EndFunction

;the per-position PenisAction label for the CURRENT scene/stage - what Voice
;reads for actors other than the lead (titfuck/handjob/footjob-others
;detection). Lives here because the SLOVE_Hentairim_Tags signature is
;annotation-scheme-specific (string scene id on P+, sslBaseAnimation on
;classic), which was the last direct label call keeping SLOVE_Voice
;framework-bound.
string Function GetPenisActionLabelAtPos(int position)
	return SLOVE_Hentairim_Tags.PenisActionLabel(CurrentAnimation, CurrentStageNum, position)
EndFunction

Bool Function PCInSex()
	return PCInSex
EndFunction

;================= CONSOLE DIAGNOSTIC: current-anim dump (classic) =====================
;Classic parity of the P+ dump. Same output/helpers - only the scene-id and SFX lookup
;differ (classic keys tags off the sslBaseAnimation CurrentAnimation, not a scene-id
;string). Each line goes to BOTH the console AND the SLOVE user log (SLOVE.0.log) via
;DumpLine. Reached from SLOVE_Test.DumpAnim (`slovetest anim`) - a user-invoked command,
;NOT the load path (console printing on the thaw CTDs the load).
Function DumpCurrentAnim()
	if !PlayerInScene || CurrentThread == none
		DumpLine("SLO VE: no active scene (player not in a tracked SexLab scene).")
		return
	endif
	DumpLine("=== SLO VE anim dump (classic) ===")
	DumpLine("scene " + GetActiveSceneId() + "  stage " + CurrentStageNum + "/" + GetStagesCount() + "  intense=" + SceneisIntense() + "  time=" + (GetTimeTotal() as int) + "s")
	DumpLine("tags: " + DebugPresentTags())
	DumpLine("SFX tag: " + DebugSfxLabel(SLOVE_Hentairim_Tags.GetSFX(CurrentAnimation, CurrentStageNum)))
	Actor[] pos = GetPositions()
	int i = 0
	while i < pos.length
		Actor a = pos[i]
		if a
			string mark = " "
			if a == playerref
				mark = "*"
			endif
			DumpLine(mark + "[" + i + "] " + a.GetDisplayName() + "  sex=" + DebugSexLabel(a) + "  role=" + DebugRoleLabel(a) + "  slot=" + AudioUtil.GetSlotForActor(a) + "  enjoy=" + GetEnjoyment(a))
			DumpLine("     labels: stim=" + GetStimulationlabel(a) + " penis=" + GetPenisActionLabel(a) + " oral=" + GetOralLabel(a) + " pen=" + GetPenetrationLabel(a) + " end=" + GetEndingLabel(a))
			DumpLine("     voice: " + DebugVoiceHint(a))
		endif
		i += 1
	endwhile
	DumpLine("(voice = label-derived branch; runtime also applies gag/orgasm/hype/timing overrides. Use 'slovetest sample <slot> <cat>' to test a folder.)")
EndFunction

;one dump line -> console (immediate, in-game) AND the SLOVE user log (persisted in
;SLOVE.0.log). Only ever called from the user-invoked dump, never the load path.
Function DumpLine(string s)
	MiscUtil.PrintConsole(s)
	SLOVE_Log.WriteLog(s, 0)
EndFunction

string Function DebugSexLabel(actor char)
	int g = GetGender(char)
	if g == 0
		return "M"
	elseif g == 1
		return "F"
	endif
	return "creature"
EndFunction

string Function DebugRoleLabel(actor char)
	if IsSubmissive(char)
		return "victim/receiving"
	endif
	return "-"
EndFunction

;SFX code -> friendly name (mirrors SLOVE_SFX's tag->constant map). "" = no explicit
;SFX tag, so SLOVE_SFX falls back to label-based slush/clap/kissing selection.
string Function DebugSfxLabel(string code)
	if code == "SS"
		return "SS (LightSlushing)"
	elseif code == "MS"
		return "MS (MediumSlushing)"
	elseif code == "FS"
		return "FS (HeavySlushing)"
	elseif code == "RS"
		return "RS (RapidSlushing)"
	elseif code == "SC"
		return "SC (SlowClap)"
	elseif code == "MC"
		return "MC (MediumClap)"
	elseif code == "FC"
		return "FC (FastClap)"
	elseif code == "NA"
		return "NA (explicitly silent)"
	endif
	return "(none - SLOVE_SFX falls back to label-based slush/clap/kissing)"
EndFunction

;one "tag " chip per present scene tag (lowercase - SLSB registries store tags lowercased)
string Function TagChip(string t)
	if HasSceneTag(t)
		return t + " "
	endif
	return ""
EndFunction

string Function DebugPresentTags()
	string r = ""
	r = r + TagChip("aggressive") + TagChip("loving") + TagChip("dirty") + TagChip("lesbian") + TagChip("ff") + TagChip("mf") + TagChip("mm")
	r = r + TagChip("cunnilingus") + TagChip("cun") + TagChip("licking") + TagChip("lick") + TagChip("69") + TagChip("kissing") + TagChip("kiss")
	r = r + TagChip("blowjob") + TagChip("oral") + TagChip("vaginal") + TagChip("anal") + TagChip("cowgirl") + TagChip("doggy") + TagChip("doggystyle")
	r = r + TagChip("standing") + TagChip("kneeling") + TagChip("handjob") + TagChip("footjob") + TagChip("titfuck") + TagChip("boobjob") + TagChip("masturbation")
	r = r + TagChip("faint") + TagChip("sleep") + TagChip("necro") + TagChip("unconscious") + TagChip("creature") + TagChip("forced") + TagChip("rough")
	if r == ""
		return "(none matched the known list)"
	endif
	return r
EndFunction

;Label-derived voice branch for one actor. Label codes are the shared tag scheme, so this
;is identical to the P+ copy. Approximate: the classic voice loop also has gag/orgasm/timing
;branches this cannot see from labels alone. [] shows the representative category where known.
string Function DebugVoiceHint(actor char)
	string oral = GetOralLabel(char)
	string pen = GetPenetrationLabel(char)
	string penis = GetPenisActionLabel(char)
	string stim = GetStimulationlabel(char)
	string ending = GetEndingLabel(char)
	bool intense = SceneisIntense()
	if oral == "KIS"
		return "kissing -> PlayKissing"
	elseif oral == "SBJ" || oral == "FBJ"
		if intense
			return "giving blowjob (intense) -> PlayBlowjob [BlowjobActionIntense]"
		endif
		return "giving blowjob -> PlayBlowjob [BlowjobActionSoft]"
	elseif oral == "RIM"
		return "rimjob -> PlayRimjob [Rimjob]"
	elseif oral == "CUN"
		return "cunnilingus -> PlayCunnilingus (or PlayRimjob in a rim-tagged scene)"
	elseif pen == "SDP" || pen == "FDP"
		return "double penetration -> PlayGettingFuckedDouble"
	elseif pen == "SCG" || pen == "FCG" || pen == "SAC" || pen == "FAC"
		return "cowgirl -> PlayCowgirl"
	elseif pen == "SVP" || pen == "FVP" || pen == "SAP" || pen == "FAP"
		if intense
			return "getting penetrated (intense) -> PlayGettingFucked [NearOrgasmNoises/IntenseAnal]"
		endif
		return "getting penetrated -> PlayGettingFucked [PenetrativeGrunts]"
	elseif penis == "SMF" || penis == "FMF"
		return "getting blowjob (male) -> PlayMaleComments/Moaning"
	elseif penis == "SDV" || penis == "FDV" || penis == "SDA" || penis == "FDA"
		return "penetrating other -> PlayFuckingOthers"
	elseif penis == "STF" || penis == "FTF" || penis == "SHJ" || penis == "FHJ" || penis == "SFJ" || penis == "FFJ"
		return "getting stroked (hj/tf/fj) -> PlayGettingStimulated/StimulatingOthers"
	elseif stim == "SST" || stim == "FST" || stim == "BST"
		return "getting stimulated -> PlayGettingStimulated"
	elseif ending == "ENO" || ending == "ENI"
		return "ending -> PlayEnding"
	elseif oral == "LDI" && pen == "LDI" && penis == "LDI" && stim == "LDI"
		return "lead-in (no action tags yet) -> PlayLeadIn"
	endif
	return "(no primary action matched these labels)"
EndFunction
