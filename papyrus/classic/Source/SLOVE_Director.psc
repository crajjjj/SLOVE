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

Function Maintenance()

	SLOVE_Log.InitLog()  ; open the SLOVE user log (OnInit + every reload)
	PerformInitialization()
	;Other Parameters
	InitializeDirectorConfigs()

	;re-seed the face-owns-mouth marker from SLS's saved ahegao state so a save
	;made mid-ahegao keeps PC moans off the mouth after the reload (PlaySound
	;reads this marker per line; nothing is latched in the DLL)
	StorageUtil.SetIntValue(playerref, "SLOVE_FaceOwnsMouth_SLS", StorageUtil.GetIntValue(None, "_SLS_IsAhegaoing", 0))

Endfunction

Function PerformInitialization()
	; Register globally whenever the script is first initialized
	RegisterForTheEventsWeNeed()
	playerref = game.getplayer() ;player

	;Modules (SLO VE: both spells live in our own plugin)
	if Game.GetModbyName("SLOVE.esp") != 255
		ExpressionsSpell = Game.GetFormFromFile(0x800, "SLOVE.esp") as Spell
		VoiceSpell = Game.GetFormFromFile(0x802, "SLOVE.esp") as Spell
		SFXSpell = Game.GetFormFromFile(0x805, "SLOVE.esp") as Spell
		ResistanceSpell = Game.GetFormFromFile(0x808, "SLOVE.esp") as Spell
		NpcSceneSpell = Game.GetFormFromFile(0x81E, "SLOVE.esp") as Spell ;anchor ability for NPC-only scenes
	endif

	if !ExpressionsSpell
		WritetoErrorlogs("Director", "Expressions Spell is Missing! Make Sure the Mod is properly installed and Plugin Enabled")
	endif

	if !VoiceSpell
		WritetoErrorlogs("Director", "Voice Spell is Missing! Make Sure the Mod is properly installed and Plugin Enabled")
	endif

	if !SFXSpell
		WritetoErrorlogs("Director", "SFX Spell is Missing! Make Sure the Mod is properly installed and Plugin Enabled")
	endif

	if Game.GetModbyName("devious devices - assets.esm") != 255
		zad_DeviousGag = Game.GetFormFromFile(0x7EB8, "devious devices - assets.esm") as Keyword
	endif

	;Others
	if Game.GetModbyName("Schlongs of Skyrim.esp") != 255
		schlongfaction = Game.GetFormFromFile(0xAFF8 , "Schlongs of Skyrim.esp") as Faction
	EndIf

	if isDependencyReady("TheNewGentleman.esp")
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

EndFunction

Event DirectorOnSLSAhegaoStateChange(string eventName, string argString, float argNum, form sender)
	;mark the player while SLS owns the face; PlaySound reads this per line
	StorageUtil.SetIntValue(playerref, "SLOVE_FaceOwnsMouth_SLS", (argNum >= 0.5) as int)
EndEvent

Function InitializeDirectorConfigs()

	enableprintdebug = SLOVE_Config.GetInt("director.printdebug", 0)
	if !SLOVE_Config.Available() && !WarnedConfigMissing
		;SLO VE: one warning per session, then run on defaults (fail-open getters)
		WarnedConfigMissing = true
		WritetoErrorlogs("Director", "TomlUtil API not found - SLOVE.toml cannot be read, running on defaults. Check the AudioUtil/TomlUtil installation.")
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
	if milkenable == 1 && Game.GetModbyName("OninusLactis.esp") != 255
		if LactisQuest == none
			LactisQuest = Game.GetFormFromFile(0xD61, "OninusLactis.esp") as Quest
		endif
		if LactisQuest == none
			WritetoErrorlogs("Director", "OninusLactis.esp loaded but quest 0xD61 not found - milk disabled. Reinstall Oninus Lactis NG.")
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
	;SLO VE is for handling player scenes only.

	printdebug("Sexlab Scene Detected")

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

	;take the pre-added tongue armors back off - they must not persist between
	;scenes. RemoveItem is inventory traffic, but at scene end that is harmless
	;(the actors are redressing anyway). Skipped (false) only on the stale-scene
	;reconcile path, where the NEXT scene's presex preload has already run for
	;shared actors (the player always is one)
	if removeTongues
		RemoveTongueItems()
	endif

	CurrentThread = none
	CurrentAnimation = none
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
		CurrentStageNum = CurrentThread.Stage
		isAlmostFinalStage = isAlmostFinalStage()
		IsFinalStage = IsFinalStage()
		updatelabelsarr()

		LastLabelUpdateTime = CurrentThread.TotalTime
		UpdateNow = false
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
	return Game.GetModbyName("MilkModNEW.esp") != 255
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
		WritetoErrorlogs("Director", "OninusLactis quest script missing - reinstall Oninus Lactis NG")
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
		sslActorAlias a = CurrentThread.ActorAlias(actorList[i])
		if a
			a.SetVoice(none, true) ;ForceSilence -> SexLab plays no moans for this actor
		endif
		i += 1
	endwhile
	printdebug("SexLab voice silenced for " + actorList.length + " scene actor(s)")
EndFunction

Function RegisterThatSceneIsEnding(Bool maleOnlyScene)
	;SLO VE: no-op kept for consumer-port compatibility (original body was already disabled)
EndFunction

Function PlaySound(String theSound, Actor actorMakingSound, Bool waitForCompletion = True, String group = "", String channel = "")
	;theSound is a AudioUtil category name; slot is resolved from the actor by the DLL.
	;blockLipSync per line when a face (SLS ahegao or our own climax face) owns the
	;actor's mouth, so the moan can't flap the jaw over it. Decided per call - there
	;is no standing block in AudioUtil.
	;resolution trace (before the play) - answers "which folder did this play from?":
	;slot+category maps to a folder in AudioUtil\config\SLOVE_voices.toml. files 0 =
	;the category resolved empty (missing/BSA-packed/misnamed folder) so nothing will
	;play; files>0 but still silent points at the scene-end stop/duck. NB
	;GetCategoryFileCount bypasses gag/sfx routing, so it can differ for a gagged
	;actor. Mirrored to the SLOVE log so it survives past the console.
	if enableprintdebug == 1
		string slot = AudioUtil.GetSlotForActor(actorMakingSound)
		int files = AudioUtil.GetCategoryFileCount(slot, theSound)
		string line = "Play '" + theSound + "' actor=" + actorMakingSound.GetDisplayName() + " slot=" + slot + " files=" + files + " group=" + group + " chan=" + channel
		printdebug(line)
		SLOVE_Log.WriteLog("Voice : " + line, 0)
	endif
	AudioUtil.Play(theSound, actorMakingSound, waitForCompletion, 1.0, group, channel, FaceOwnsMouth(actorMakingSound))
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

function WritetoErrorlogs(string Header = "Not Specified" ,String contents = "")
	SLOVE_Log.WriteLog(Header + " : " + contents, 2)
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

Bool function isDependencyReady(String modname)
	return PO3_SKSEFunctions.IsPluginFound(modname)
endfunction

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

int Function GetEnjoyment(actor char)
	if !CurrentThread
		return 0
	endif
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
