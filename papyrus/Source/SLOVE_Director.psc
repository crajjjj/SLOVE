Scriptname SLOVE_Director extends ReferenceAlias
{SLO VE scene director. Slim port of Hentairim's IVDTControllerScript: the ONLY
 script in SLO VE allowed to touch SexLabFramework / SexLabThread / SexlabRegistry
 or raw SLPP mod events. Tracks the player scene, owns the label state (tags +
 physics overlay), applies the voice/expressions module spells, and re-broadcasts
 SLOVE-owned mod events for consumers. Attached to the PlayerAlias of
 SLOVE_MainQuest in SLOVE.esp.}

SexLabFramework Property SexLab Auto ;CK-filled - the only CK property on this script

actor playerref
Bool PlayerInScene = false
string currentSceneID
string currentStageID
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
SexLabThread CurrentThread
int CurrentThreadid
int CurrentStageNum
Bool isAlmostFinalStage
Bool IsFinalStage
Bool IsEnding
Bool PCInSex

;SLO VE: cached SLOVE.toml [director] settings (re-read on load and per scene start)
int enablevoice
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
	while !Sexlab.GetThreadByActor(PlayerRef) && tries < 10
		Utility.Wait(0.3)
		tries = tries + 1
	endwhile
	if Sexlab.GetThreadByActor(PlayerRef)
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
	if actorList == None
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
	miscutil.printconsole("SLO VE Director Registered For Events")

	RegisterForModEvent("AnimationStart", "DirectorSceneStart")
	RegisterForModEvent("SexLabOrgasmSeparate", "DirectorOnOrgasm")
	RegisterForModEvent("StageStart", "DirectorStageStart")
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
	if argString as Int == CurrentThread.GetThreadID()

		while CurrentThread.GetStatus() == 2
			utility.wait(0.1)
		endwhile

		actorlist = currentthread.Getpositions()
		;SLO VE: re-broadcast for consumers; label refresh happens in OnUpdate via the id comparison
		SendModEvent("SLOVE_StageStart", argString)
	endif
EndEvent

;Director reacts when a sexlab scene start
Event DirectorSceneStart(string eventName, string argString, float argNum, form sender)
	;SLO VE is for handling player scenes only.

	printdebug("Sexlab Scene Detected")


	if PlayerInScene && !Sexlab.GetThreadByActor(PlayerRef)
		PlayerInScene = false
	endif

	if PlayerInScene || !Sexlab.GetThreadByActor(PlayerRef)
		printdebug("Sexlab Scene Does not Involve Player.Ignored")
		Return
	endIf

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
	CurrentThread = Sexlab.GetThreadByActor(PlayerRef) ;CURRENT THREAD
	CurrentThreadID = CurrentThread.GetThreadID()
	CurrentSceneID = CurrentThread.GetActiveScene()
	CurrentStageID = CurrentThread.GetActiveStage()
	CurrentStageNum = GetLegacyStageNum(CurrentSceneID, CurrentStageID)
	isAlmostFinalStage = isAlmostFinalStage()
	IsFinalStage = IsFinalStage()
	LastLabelUpdateTime = CurrentThread.GetTimeTotal()
	LastPhysicsLabelTime = 0
	actorList = CurrentThread.GetPositions()
	PCPosition = CurrentThread.GetPositionIdx(Playerref)
	;SLO VE: no foreplay / linear-scene / custom-scene / orgasm choreography - dropped
	PlayerInScene = true
	UpdateLabelsArr(CurrentSceneID , CurrentStageNum )
	;initialize variables
	PCisAggressor = PCisAggressor()
	AllFemale = AllFemale()
	PCisReceiving = playerref == actorList[0]
	PCisVictim = PCisVictim()

	int statusfailsafe = 0
	while CurrentThread.GetStatus() == 2 && statusfailsafe < 100 ;cap: a thread stuck registering must not pin UpdateNow true forever
		utility.wait(0.1)
		statusfailsafe = statusfailsafe + 1
	endwhile

	ApplySpells()
	SendModEvent("SLOVE_SceneStart", CurrentThreadID as string)
	printdebug("CurrentThread :" + CurrentThread)
	printdebug("CurrentSceneID :" + CurrentSceneID)
	printdebug("CurrentStageID :" + CurrentStageID)
	printdebug("actorList :" + actorList)
	printdebug("Scene start")
	NextMilkRollTime = CurrentThread.GetTimeTotal() + milkrollinterval
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


Function DirectorEndScene()
	;SLO VE: no StopAnimation/armor/scaling/speed restore - the only end path here is
	;the OnUpdate poll after the thread already ended
	isEnding = true
	;mute on scene end: a moan/line/SFX started just before the scene ended would
	;otherwise keep playing over the aftermath. Hard-stop every SLO VE sound (voice,
	;partner, creature, SFX) the moment the scene is gone.
	AudioUtil.StopAllAudio()
	PCInSex = false
	LastLabelUpdateTime = 0
	LastPhysicsLabelTime = 0
	int endedThreadID = CurrentThreadID

	CurrentThread = none
	CurrentSceneID = ""
	CurrentStageID = ""
	CurrentStageNum = 0
	PlayerInScene = false
	updaterate = 0.5

	SendModEvent("SLOVE_SceneEnd", endedThreadID as string)

	;SLO VE: expressions module resets faces itself (OnEffectFinish); keep the original
	;3s end-window so consumers can observe the AnimationisEnding() latch, then clear it
	utility.wait(3)
	isEnding = false

	printdebug("SLO VE Director Scene END")

endfunction

Bool Function AnimationisEnding()
	return isEnding
EndFunction

Event OnUpdate()


	if	!Sexlab.GetThreadByActor(PlayerRef) ;CURRENT THREAD
		printdebug("-------------End Scene-------------------.")
		DirectorEndScene()
		return
	endif

	printdebug("---Updating---")
	;SLO VE: hotkeys, stage advancing, linear/extend/counter-rape choreography dropped

	;=== Scene or Stage update check ===
	if UpdateNow || currentSceneID != CurrentThread.GetActiveScene() || CurrentStageID != CurrentThread.GetActiveStage()
		printdebug("Updating labels: Scene or Stage changed.")
		currentSceneID = CurrentThread.GetActiveScene()
		CurrentStageID = CurrentThread.GetActiveStage()
		CurrentStageNum = GetLegacyStageNum(CurrentSceneID, CurrentStageID)
		isAlmostFinalStage = isAlmostFinalStage()
		IsFinalStage = IsFinalStage()
		updatelabelsarr(CurrentSceneID, CurrentStageNum)

		if enablesfx == 1
			LoadSchlongAdjustment() ;reapply saved SOSBend calibrations (SLOVE_SFX adaptive velocity)
		endif

		LastLabelUpdateTime = CurrentThread.GetTimeTotal()
		UpdateNow = false
	elseif usephysicslabels == 1 && CurrentThread.GetStatus() == 3 && CurrentThread.IsInteractionRegistered()
		;contacts and thrust speed change mid-stage - refresh labels from physics and
		;signal opted-in consumers through the physics-time bump; the stage latch
		;(LastLabelUpdateTime) must only move on real stage changes
		if ApplyPhysicsLabels()
			LastPhysicsLabelTime = CurrentThread.GetTimeTotal()
		endif
	endif

	;=== milk: periodic lactation roll while the PC is being penetrated ===
	;(physics-aware for free: the penetration label read here is the overlaid
	;array, so the intense/soft split follows measured thrust speed when SLPP
	;interactions are registered, tags otherwise)
	if milkenable == 1 && CurrentThread.GetTimeTotal() >= NextMilkRollTime
		NextMilkRollTime = CurrentThread.GetTimeTotal() + milkrollinterval
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

float function GetDirectorLastLabelTime()
	return LastLabelUpdateTime
endfunction

float function GetDirectorLastPhysicsLabelTime()
	return LastPhysicsLabelTime
endfunction

Function ApplySpells()
	;SLO VE: trimmed AddTrackerToSceneIfApplicable - no thread control, no
	;sslVoiceSlots voice wipe (AudioUtil owns voices), no SFX/resistance modules

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

Function RegisterThatSceneIsEnding(Bool maleOnlyScene)
	;SLO VE: no-op kept for consumer-port compatibility (original body was already disabled)
EndFunction

Function PlaySound(String theSound, Actor actorMakingSound, Bool waitForCompletion = True, String group = "", String channel = "")
	;theSound is a AudioUtil category name; slot is resolved from the actor by the DLL.
	;blockLipSync per line when a face (SLS ahegao or our own climax face) owns the
	;actor's mouth, so the moan can't flap the jaw over it. Decided per call - there
	;is no standing block in AudioUtil.
	AudioUtil.Play(theSound, actorMakingSound, waitForCompletion, 1.0, group, channel, FaceOwnsMouth(actorMakingSound))
EndFunction

;true while any SLO VE face owns this actor's mouth - the Director's SLS ahegao
;marker OR SLOVE_Expressions' climax-face marker. Either being set means a voice
;line should play without driving the mouth.
bool Function FaceOwnsMouth(Actor a)
	return StorageUtil.GetIntValue(a, "SLOVE_FaceOwnsMouth_SLS", 0) == 1 || StorageUtil.GetIntValue(a, "SLOVE_FaceOwnsMouth_Expr", 0) == 1
EndFunction

bool function IsMale(actor char)
	return sexlab.GetGender((char)) == 0
endfunction

;---------------------------Stage Control FUNCTIONS (trimmed)------------------------

Function DisableOrgasm(Actor char)

    CurrentThread.DisableOrgasm(char, true)

    if char
        PrintDebug("DisableOrgasm - Orgasm disabled for: " + char.GetDisplayName())
    else
        PrintDebug("DisableOrgasm - Orgasm disabled for NONE actor")
    endif
EndFunction

Function EnableOrgasm(Actor char)
	;SLO VE: no linear scenes, so this always enables
	PrintDebug("EnableOrgasm - " + char.GetDisplayName() + " orgasm ENABLED.")
	CurrentThread.DisableOrgasm(char, false)
EndFunction

Bool Function AllFemale()

	if sexlab.CountFemale(actorlist) == actorlist.length
		return true
	else
		return false
	endIf
endfunction

function printdebug(string contents = "")
	if enableprintdebug == 1
		miscutil.PrintConsole ("SLO VE Director : "+ contents)
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
Function UpdateLabelsArr(string anim , int stage)

	Stimulationlabelarr = SLOVE_Hentairim_Tags.GetStimulationlabelarr(anim , stage , actorlist)
	PenisActionLabelarr  = SLOVE_Hentairim_Tags.GetPenisActionLabelarr(anim , stage , actorlist)
	OralLabelarr  = SLOVE_Hentairim_Tags.GetOralLabelarr(anim , stage , actorlist)
	PenetrationLabelarr = SLOVE_Hentairim_Tags.GetPenetrationLabelarr(anim , stage , actorlist)
	EndingLabelarr  =SLOVE_Hentairim_Tags.GetEndingLabelarr(anim , stage , actorlist)

	ApplyClimaxAnnotations(anim)

	;snapshot the tag-derived labels so the physics overlay can revert when contact ends
	BaseStimulationlabelarr = CopyStringArray(Stimulationlabelarr)
	BasePenisActionLabelarr = CopyStringArray(PenisActionLabelarr)
	BaseOralLabelarr = CopyStringArray(OralLabelarr)
	BasePenetrationLabelarr = CopyStringArray(PenetrationLabelarr)

	ApplyPhysicsLabels()

	Labelsconcat = "1" +Stimulationlabelarr[0] + "1" + PenisActionLabelarr[0] + "1" + OralLabelarr[0] + "1" + PenetrationLabelarr[0] + "1" + EndingLabelarr[0]

	printdebug("Stimulationlabelarr : " + Stimulationlabelarr)
	printdebug("PenisActionLabelarr : " + PenisActionLabelarr)
	printdebug("OralLabelarr : " + OralLabelarr)
	printdebug("PenetrationLabelarr : " + PenetrationLabelarr)
	printdebug("EndingLabelarr : " + EndingLabelarr)
endfunction

Function ApplyClimaxAnnotations(string anim)
	;SLSB climax annotations fill EN labels for stages the Hentairim tags don't cover
	if CurrentStageID == ""
		return
	endif
	int[] climaxers = SexlabRegistry.GetClimaxingActors(anim, CurrentStageID)
	if !climaxers || climaxers.Length == 0
		return
	endif
	int z = 0
	while z < EndingLabelarr.Length
		if EndingLabelarr[z] == "LDI" && climaxers.Find(z) > -1
			EndingLabelarr[z] = "ENI" ;registry doesn't distinguish inside/outside; ENI is the common case
		endif
		z += 1
	endwhile
endfunction

;--------------------------------PHYSICS LABEL BRIDGE START--------------------------------;
;When SLPP node-collision detection is registered for the thread, overlay the tag-derived
;labels with what is physically happening. Tags stay as fallback for anything physics
;cannot see (titfuck, posture nuance like cowgirl, ending inside/outside) and for scenes
;where detection is unavailable. The F/S prefix comes from live contact velocity, so
;intensity tracks the real animation speed including user AnimSpeed overrides.
float[] PhysVelEnvelope
bool[] PhysVelFast
;tag-derived baselines, snapshotted per stage in UpdateLabelsArr; the overlay always
;derives from these so labels revert when contact ends and posture info survives
string[] BaseStimulationlabelarr
string[] BasePenisActionLabelarr
string[] BaseOralLabelarr
string[] BasePenetrationLabelarr

string[] Function CopyStringArray(string[] src)
	string[] dst = PapyrusUtil.StringArray(src.Length)
	int i = 0
	while i < src.Length
		dst[i] = src[i]
		i += 1
	endwhile
	return dst
EndFunction

Bool Function ApplyPhysicsLabels()
	if usephysicslabels != 1 || CurrentThread == none || !CurrentThread.IsInteractionRegistered()
		return false
	endif
	if BasePenetrationLabelarr.Length != actorlist.Length || PenetrationLabelarr.Length != actorlist.Length
		return false
	endif
	if PhysVelEnvelope.Length != actorlist.Length || PhysVelFast.Length != actorlist.Length
		PhysVelEnvelope = PapyrusUtil.FloatArray(actorlist.Length)
		PhysVelFast = PapyrusUtil.BoolArray(actorlist.Length)
	endif

	bool changed = false
	int z = 0
	while z < actorlist.Length
		actor pos = actorlist[z]
		if pos != none
			bool recvVag = false
			bool recvAnal = false
			bool recvGrind = false
			bool givesVag = false
			bool givesAnal = false
			bool penisSucked = false
			bool penisDeep = false
			bool penisHJ = false
			bool penisFJ = false
			bool mouthKis = false
			bool mouthDeep = false
			bool mouthOral = false
			bool mouthShaft = false
			actor oralTarget = none
			float maxVel = 0.0

			;one flags call per position replaces the pairwise GetInteractionTypes sweep;
			;partner lookups and velocity reads only for the types the flags say are active
			bool[] f = CurrentThread.GetCurrentInteractionFlags(pos)
			if f.Length >= 28
				recvVag = f[15] ;pVaginal
				recvAnal = f[16] ;pAnal
				recvGrind = f[4] ;pGrinding
				mouthOral = f[12] ;aOral
				mouthDeep = f[14] ;aDeepthroat
				mouthShaft = f[13] ;aLickingShaft
				mouthKis = f[9] ;bKissing
				givesVag = f[26] ;aVaginal
				givesAnal = f[27] ;aAnal
				penisSucked = f[23] ;pOral
				penisDeep = f[24] ;pDeepthroat
				penisHJ = f[19] ;pHandJob
				penisFJ = f[20] ;pFootJob

				actor prt
				if recvVag
					prt = CurrentThread.GetPartnerByTypeRev(pos, 1) ;whoever penetrates pos
					if prt != none
						maxVel = MaxAbsVelocity(maxVel, CurrentThread.GetVelocity(pos, prt, 1))
					endif
				endif
				if recvAnal
					prt = CurrentThread.GetPartnerByTypeRev(pos, 2)
					if prt != none
						maxVel = MaxAbsVelocity(maxVel, CurrentThread.GetVelocity(pos, prt, 2))
					endif
				endif
				if recvGrind
					prt = CurrentThread.GetPartnerByTypeRev(pos, 4)
					if prt != none
						maxVel = MaxAbsVelocity(maxVel, CurrentThread.GetVelocity(pos, prt, 4))
					endif
				endif
				if mouthOral
					oralTarget = CurrentThread.GetPartnerByTypeRev(pos, 3) ;whom pos licks/sucks
					if oralTarget != none
						maxVel = MaxAbsVelocity(maxVel, CurrentThread.GetVelocity(pos, oralTarget, 3))
					endif
				endif
				if givesVag
					prt = CurrentThread.GetPartnerByType(pos, 1) ;receiver pos penetrates
					if prt != none
						maxVel = MaxAbsVelocity(maxVel, CurrentThread.GetVelocity(prt, pos, 1))
					endif
				endif
				if givesAnal
					prt = CurrentThread.GetPartnerByType(pos, 2)
					if prt != none
						maxVel = MaxAbsVelocity(maxVel, CurrentThread.GetVelocity(prt, pos, 2))
					endif
				endif
				if penisSucked
					prt = CurrentThread.GetPartnerByType(pos, 3) ;whoever sucks pos off
					if prt != none
						maxVel = MaxAbsVelocity(maxVel, CurrentThread.GetVelocity(prt, pos, 3))
					endif
				endif
				if penisHJ
					prt = CurrentThread.GetPartnerByType(pos, 9)
					if prt != none
						maxVel = MaxAbsVelocity(maxVel, CurrentThread.GetVelocity(prt, pos, 9))
					endif
				endif
			endif

			;velocity envelope: a single sample can land on a thrust reversal (~0),
			;so decay the previous peak instead of trusting the instantaneous value
			float env = PhysVelEnvelope[z] * 0.7
			if maxVel > env
				env = maxVel
			endif
			PhysVelEnvelope[z] = env
			;hysteresis: rise to F at the threshold, fall back to S only well below it,
			;so a sub-second thrust cycle sampled at 0.5s does not flap the prefix
			if !PhysVelFast[z] && env >= physicsfastvelocity
				PhysVelFast[z] = true
			elseif PhysVelFast[z] && env < physicsfastvelocity * physicsslowfactor
				PhysVelFast[z] = false
			endif
			string sp = "S"
			if PhysVelFast[z]
				sp = "F"
			endif

			;each label derives from the immutable tag baseline: overlays apply on top,
			;and when contact ends newlbl falls back to the baseline, reverting the array

			;Penetration label (receiver view)
			string base = BasePenetrationLabelarr[z]
			string newlbl = base
			if recvVag && recvAnal
				newlbl = sp + "DP"
			elseif recvVag
				if base == "SCG" || base == "FCG"
					newlbl = sp + "CG" ;keep cowgirl posture from tags
				else
					newlbl = sp + "VP"
				endif
			elseif recvAnal
				if base == "SAC" || base == "FAC"
					newlbl = sp + "AC"
				else
					newlbl = sp + "AP"
				endif
			endif
			if newlbl != PenetrationLabelarr[z]
				PenetrationLabelarr[z] = newlbl
				changed = true
			endif

			;Penis action label (giver view)
			base = BasePenisActionLabelarr[z]
			newlbl = base
			if givesVag
				newlbl = sp + "DV"
			elseif givesAnal
				newlbl = sp + "DA"
			elseif penisDeep
				newlbl = "FMF"
			elseif penisSucked
				newlbl = sp + "MF"
			elseif penisHJ
				newlbl = sp + "HJ"
			elseif penisFJ
				newlbl = sp + "FJ"
			endif
			if newlbl != PenisActionLabelarr[z]
				PenisActionLabelarr[z] = newlbl
				changed = true
			endif

			;Oral label (mouth view) - same priority order as the tag version
			base = BaseOralLabelarr[z]
			newlbl = base
			if mouthKis
				newlbl = "KIS"
			elseif mouthDeep
				newlbl = "FBJ"
			elseif mouthOral
				if oralTarget != none && Sexlab.GetGender(oralTarget) % 2 == 1
					newlbl = "CUN"
				elseif sp == "F"
					newlbl = "FBJ"
				else
					newlbl = "SBJ"
				endif
			elseif mouthShaft
				newlbl = "SBJ"
			endif
			if newlbl != OralLabelarr[z]
				OralLabelarr[z] = newlbl
				changed = true
			endif

			;Stimulation label - grinding is the only physical signal for it
			base = BaseStimulationlabelarr[z]
			newlbl = base
			if recvGrind && base != "BST"
				newlbl = sp + "ST"
			endif
			if newlbl != Stimulationlabelarr[z]
				Stimulationlabelarr[z] = newlbl
				changed = true
			endif
		endif
		z += 1
	endwhile

	if changed
		Labelsconcat = "1" +Stimulationlabelarr[0] + "1" + PenisActionLabelarr[0] + "1" + OralLabelarr[0] + "1" + PenetrationLabelarr[0] + "1" + EndingLabelarr[0]
		printdebug("Physics labels applied - Stim: " + Stimulationlabelarr + " PenisAction: " + PenisActionLabelarr + " Oral: " + OralLabelarr + " Penetration: " + PenetrationLabelarr)
	endif
	return changed
EndFunction

float Function MaxAbsVelocity(float current, float candidate)
	float a = Math.abs(candidate)
	if a > current
		return a
	endif
	return current
EndFunction
;--------------------------------PHYSICS LABEL BRIDGE END--------------------------------;

bool Function SceneisIntense()
	return stringutil.find(Labelsconcat ,"1F") > -1
endfunction

;----------------LABEL GETTERS===============
string function GetStimulationlabel(actor char)
	if !CurrentThread
		return ""
	endif
	int idx = CurrentThread.GetPositionIdx(char)
	if idx < 0
		return ""
	endif
	return Stimulationlabelarr[idx]
endfunction

string function GetPenisActionLabel(actor char)
	if !CurrentThread
		return ""
	endif
	int idx = CurrentThread.GetPositionIdx(char)
	if idx < 0
		return ""
	endif
	return PenisActionLabelarr[idx]
endfunction

string function GetOralLabel(actor char)
	if !CurrentThread
		return ""
	endif
	int idx = CurrentThread.GetPositionIdx(char)
	if idx < 0
		return ""
	endif
	return OralLabelarr[idx]
endfunction

string function GetPenetrationLabel(actor char)
	if !CurrentThread
		return ""
	endif
	int idx = CurrentThread.GetPositionIdx(char)
	if idx < 0
		return ""
	endif
	return PenetrationLabelarr[idx]
endfunction

string function GetEndingLabel(actor char)
	if !CurrentThread
		return ""
	endif
	int idx = CurrentThread.GetPositionIdx(char)
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

int Function GetLegacyStageNum(String asScene, String asStage)


	string[] all_stages = SexlabRegistry.GetAllStages(asScene)

	if SexlabRegistry.StageExists(asScene, asStage)
		int stage_num = all_stages.find(asStage) + 1
		return stage_num
	else

		return 0
	endif
EndFunction

int Function GetLegacyStagesCount(String asScene)
	int stages_count = SexlabRegistry.GetAllStages(asScene).Length
	return stages_count
EndFunction

bool Function isFinalStage()

		return CurrentStageNum >= GetFinalStageNum()
EndFunction

int Function GetFinalStageNum()
	;SLO VE: custom-scene branch dropped

	string[] AllStages = SexlabRegistry.GetAllStages(currentsceneid)

	;look for ending

	Bool Foundending
	int FinalStageNum = AllStages.length
	int z = AllStages.length
	while z > 0 && !Foundending
		string tmpendinglabel = SLOVE_Hentairim_Tags.EndingLabel(CurrentSceneid , z , 0)
		if tmpendinglabel == "ENO" || tmpendinglabel == "ENI"
			Foundending = true
			FinalStageNum = z
		endif
		z -= 1
	endwhile

	if !Foundending
		;no EN tags - fall back to SLSB climax annotations from the registry
		string[] climaxstages = SexlabRegistry.GetClimaxStages(currentsceneid, -1)
		if climaxstages && climaxstages.Length > 0
			int maxidx = -1
			int c = 0
			while c < climaxstages.Length
				int idx = AllStages.Find(climaxstages[c])
				if idx > maxidx
					maxidx = idx
				endif
				c += 1
			endwhile
			if maxidx > -1
				FinalStageNum = maxidx + 1
			endif
		endif
	endif

	return FinalStageNum
EndFunction

bool Function isAlmostFinalStage()

	return CurrentStageNum >= GetFinalStageNum() - 1
EndFunction

bool Function PCisVictim()
	return CurrentThread.GetSubmissive(playerref)
EndFunction

bool Function isVictim(actor char)
	return CurrentThread.GetSubmissive(char)
EndFunction

bool Function PCisAggressor()
	 actor[] victimlist = CurrentThread.GetSubmissives()
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
	return sexlab.CountCreatures(actorList) > 0
endfunction

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

	Int Sex = Sexlab.GetSex(char)

	if Sex == 1
		return -1
	endif

	if Sex >= 3 ; creature
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
	Int Sex = Sexlab.GetSex(char)
	if Sex <= 2
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
;The SFX module's SOSBend calibration search records the bend that produced
;SLPP collision data, keyed per scene|stage|position; the director reapplies
;it on every stage change so the search doesn't repeat.

Function SaveSchlongAdjustment(int schlongposition, int value)
	string sceneName = SexlabRegistry.GetSceneName(CurrentSceneID)
	string strkey = sceneName + "|" + CurrentStageNum + "|" + schlongposition
	printdebug("SaveSchlongAdjustment: " + strkey + " = " + value)
	jsonutil.SetIntValue("SLOVE/SchlongAdjustment.json", strkey, value)
endFunction

Function LoadSchlongAdjustment()
	int z
	string sceneName = SexlabRegistry.GetSceneName(CurrentSceneID)

	while z < actorList.Length
		Int Adjustment = jsonutil.GetIntValue("SLOVE/SchlongAdjustment.json", sceneName + "|" + CurrentStageNum + "|" + z, 0)
		if Adjustment != 0
			Debug.SendAnimationEvent(actorList[z], "SOSBend" + Adjustment as string)
			printdebug("LoadSchlongAdjustment: position " + z + " -> SOSBend" + Adjustment)
		endIf
		z += 1
	endwhile
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
	return CurrentThread.GetPositions()
EndFunction

int Function GetPositionIdx(actor char)
	if !CurrentThread
		return -1
	endif
	return CurrentThread.GetPositionIdx(char)
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
	return CurrentThread.GetTimeTotal()
EndFunction

bool Function HasSceneTag(string asTag)
	if !CurrentThread
		return false
	endif
	return CurrentThread.HasSceneTag(asTag)
EndFunction

bool Function IsSubmissive(actor char)
	if !CurrentThread
		return false
	endif
	return CurrentThread.GetSubmissive(char)
EndFunction

string Function GetActiveSceneId()
	return currentSceneID
EndFunction

int Function GetStageNum()
	return CurrentStageNum
EndFunction

int Function GetStagesCount()
	if currentSceneID == ""
		return 0
	endif
	return GetLegacyStagesCount(currentSceneID)
EndFunction

int Function GetGender(actor char)
	return sexlab.GetGender(char)
EndFunction

Bool Function PCInSex()
	return PCInSex
EndFunction
