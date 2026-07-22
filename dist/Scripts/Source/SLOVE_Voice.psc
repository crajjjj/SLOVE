Scriptname SLOVE_Voice extends ActiveMagicEffect
{SLO VE voice tracker. Port of Hentairim's IVDTSceneTrackerScript: runs on the
 player during a scene, drives the female (PC) voice engine, the male comment
 rotation, the orgasm reaction state machine and the voices-to-expressions sync
 ("HentaiScenario" StorageUtil key). All categories are AudioUtil category
 strings; the DLL resolves the actual voice slot per actor. Settings come from
 SLOVE.toml via SLOVE_Config ("voice." keys).}

;References
SexLabFramework Property SexLab Auto ;CK-filled
SLOVE_Director Property MasterScript Auto ;CK-filled
Spell Property SceneTrackerSpell Auto ;CK-filled

Actor actorWithSceneTrackerSpell = None
Actor mainFemaleActor = None
Actor mainMaleActor = None
;--- voice-all-actors: every male in the scene may speak with his own AudioUtil slot
Actor[] sceneMales                 ;all non-PC males (incl. schlonged females)
Bool mainMaleIsVoiced = false      ;true only when mainMaleActor is a human male/schlonged futa; the partner fallback (e.g. a creature) must stay silent
Actor lastMaleOrgasmActor = None   ;who climaxed last - post-nut lines come from him
Float lastSecondaryLineTime        ;scene time a non-lead male last spoke
Float secondaryLineCooldown        ;randomized pause between non-lead lines
;--- creature ambience: voiced creatures (C-slots via [race_map]) pant/growl on a cadence
Actor[] sceneCreatures
Float lastCreatureBreathTime
Float creatureBreathCooldown
int enablecreaturebreathing
float creaturebreathmininterval
float creaturebreathmaxinterval
Int voiceAllActors = 1             ;SLOVE.toml "voice.voiceallactors"
Actor playerCharacter = None

Int ThreadID = -1
SexLabThread CurrentThread = None
string CurrentSceneid = ""
bool GreetedMalePartner = false

;Config

Bool withMaleLover = False ;SLO VE: never set (the marriage/housecarl chemistry forms were dead weight in the source and are dropped)

Bool maleOnlyScene = False ;SLO VE: PC resolves to a male voice pack - female categories get remapped at the PlaySound boundary
Float hoursSinceLastSex = 0.0 ;For the main female. In game hours. Doesn't include current scene.
Int mainFemaleEnjoyment = 0
Int mainMaleEnjoyment = 0
Int maleOrgasmCount = 0
Int femaleRecordedOrgasmCount = 0
Int locationOfLastMaleOrgasm = 0 ;0 - not set (or other), 1 - oral, 2 - vaginal, 3 = anal
Int currentStage = -1 ;Current stage of the scene that is currently playing
string currentStageID = ""

Float timeOfLastStageStart = 0.0
Float timeOfLastMaleOrgasm = -20.0
Float timeOfLastRecordedFemaleOrgasm = -20.0
Float timeOfLastRomanticRemark = 0.0
Int timesGaped = 0 ;Number of times the female has been gaped for the current scene
Int currentlyPlayingSoundCount = 0
Int currentlyPlayingSoundCountMale = 0
;for new anim stage label
string Primarystagelabel = ""
bool teasedClosetoorgasm = false
bool ASLpreviouslyintense = False
bool commentedcumlocation = false
bool commentedorgasmremark = false
Bool ASLCurrentlyintense = false

int CameInsideCount = 0
Bool ReacttoFemaleOrgasmNext = false
Bool ReacttoMaleOrgasmNext = false

String PreviousSound = ""

Actor[] ActorsInPlay

int	EnableHugePPScenario
int	EnableVictimScenario
float	ChanceToCommentUnamused
float	ChanceToCommentonLeadinStage
float	ChanceToCommentonNonIntenseStage
float	chancetocommentonintensestage
float	ChanceToCommentononAttackingStage
float	ChanceToCommentonBlowjobStage
float	ChanceToCommentWhenCloseToOrgasm
float	ChanceToCommentWhenMaleCloseToOrgasm

int FemaleOrgasmHypeEnjoyment
int MaleOrgasmHypeEnjoyment
int EnableDDGagVoice
Int EnableMaleVoice
float ChanceForMaleToComment

Keyword TNG_Gentlewoman
String VoiceVariation
Bool ShouldInitialize = false
Faction SchlongFaction
int MoanOnly

Float nextUpdateInterval = 1.0

Bool CommentedClosetoOrgasm = false

int gender = 0

int hypebeforeorgasm

Event OnEffectStart(Actor akTarget, Actor akCaster)
	playerCharacter = Game.GetPlayer()
	actorWithSceneTrackerSpell = akTarget
	mainFemaleActor = playerCharacter ;Temporary default until FindActorsAndVoices is called
	PerformInitialization()

EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
	;SLO VE: nothing to release - the Hentairim stage-advance handshake is gone
endevent

int EnablePrintDebug
int useblowjobsoundforkissing
float	pcvolume
float	partnervolume

Function InitializeConfigValues()

ActorsInPlay = CurrentThread.GetPositions()
;SLO VE: dropped - donotadvance* keys (stage-advance handshake), chancetoorgasmsquirt /
;enablebrokenstatus / enablethickcumleak / chancetoleakthickcum (cum shaders + resistance)
EnableHugePPScenario = SLOVE_Config.GetInt("voice.enablehugeppscenario",0)
EnableVictimscenario = SLOVE_Config.GetInt("voice.enablevictimscenario",0)
ChanceToCommentUnamused = SLOVE_Config.GetInt("voice.chancetocommentunamused",0) as float/100
ChanceToCommentonLeadinStage = SLOVE_Config.GetInt("voice.chancetocommentonleadinstage",0) as float/100
ChanceToCommentonNonIntenseStage = SLOVE_Config.GetInt("voice.chancetocommentonnonintensestage",0) as float /100
chancetocommentonintensestage = SLOVE_Config.GetInt("voice.chancetocommentonintensestage",0) as float /100
ChanceToCommentononAttackingStage = SLOVE_Config.GetInt("voice.chancetocommentononattackingstage",0) as float /100
ChanceToCommentonBlowjobStage = SLOVE_Config.GetInt("voice.chancetocommentonblowjobstage",0) as float /100
ChanceToCommentWhenCloseToOrgasm = SLOVE_Config.GetInt("voice.chancetocommentwhenclosetoorgasm",0) as float /100
ChanceToCommentWhenMaleCloseToOrgasm = SLOVE_Config.GetInt("voice.chancetocommentwhenmaleclosetoorgasm",0) as float /100
FemaleOrgasmHypeEnjoyment = SLOVE_Config.GetInt("voice.femaleorgasmhypeenjoyment",0)
MaleOrgasmHypeEnjoyment = SLOVE_Config.GetInt("voice.maleorgasmhypeenjoyment",0)
EnableDDGagVoice = SLOVE_Config.GetInt("voice.enableddgagvoice",0)
EnableMaleVoice = SLOVE_Config.GetInt("voice.enablemalevoice",0)
ChanceForMaleToComment = SLOVE_Config.GetInt("voice.chanceformaletocomment",0) as float /100
enablecreaturebreathing = SLOVE_Config.GetInt("voice.creaturebreathing", 1)
creaturebreathmininterval = SLOVE_Config.GetInt("voice.creaturebreathmininterval", 5) as float
creaturebreathmaxinterval = SLOVE_Config.GetInt("voice.creaturebreathmaxinterval", 12) as float

VoiceVariation = SLOVE_Config.GetString("voice.voicevariation","NA")
MoanOnly  = SLOVE_Config.GetInt("voice.moanonly",0)
hypebeforeorgasm = SLOVE_Config.GetInt("voice.hypebeforeorgasm",0)
useblowjobsoundforkissing = SLOVE_Config.GetInt("voice.useblowjobsoundforkissing",0)
pcvolume = SLOVE_Config.GetInt("voice.pcvolume",0) as float /100
partnervolume = SLOVE_Config.GetInt("voice.partnervolume",0) as float /100
EnablePrintDebug =  SLOVE_Config.GetInt("voice.printdebug",1)

endfunction

Function PerformInitialization()

	ShouldInitialize = false

	;unduck all four voice groups - self-heal in case a previous scene's end
	;was interrupted between its duck and its delayed unduck
	AudioUtil.UnduckGroup("pc_low")
	AudioUtil.UnduckGroup("pc_high")
	AudioUtil.UnduckGroup("partner_low")
	AudioUtil.UnduckGroup("partner_high")
	CurrentThread = Sexlab.GetThreadByActor(actorWithSceneTrackerSpell)
	ThreadID = CurrentThread.GetThreadID()

	FindActorsAndVoices()

	hoursSinceLastSex = SexLab.HoursSinceLastSex(mainFemaleActor)

	RegisterForTheEventsWeNeed()


	InitializeConfigValues()

	;Block Orgasm first if hype first before orgasm is enabled
	if hypebeforeorgasm == 1
		DisableOrgasm()
	else
		EnableOrgasm()
	endif

	;set volume

	AudioUtil.SetGroupVolume("partner_low", partnervolume)
	AudioUtil.SetGroupVolume("partner_high", partnervolume)
	AudioUtil.SetGroupVolume("pc_low", pcvolume)
	AudioUtil.SetGroupVolume("pc_high", pcvolume)


	CurrentSceneid = CurrentThread.GetActiveScene()
	currentStageID = CurrentThread.GetActiveStage()
	currentstage = GetLegacyStageNum(CurrentSceneid, currentStageID)
	timeOfLastStageStart = CurrentThread.GetTimeTotal()

	ishugepp = ishugePP()
	UpdateLabels(CurrentSceneid , currentstage , PCPosition) ;update only for PC

	if stringutil.find(Labelsconcat ,"1F") > -1 || IsGettingInsertedBig()
		ASLCurrentlyintense = true
	else
		ASLCurrentlyintense = false
	endif

	if currentstage <= 2
		ReactedtoFemaleOrgasmThisSession = false
		ReactedtoMaleOrgasmThisSession = false
		teasedClosetoorgasm = false
	endif

	DirectorLastLabelTime = MasterScript.GetDirectorLastLabelTime()
	printdebug("Stage is intense? : " + ASLCurrentlyintense)



	;TNG (only the Gentlewoman keyword - hasSchlong futa check)
	if isDependencyReady("TheNewGentleman.esp") && !TNG_Gentlewoman
		TNG_Gentlewoman = Game.GetFormFromFile(0xFF8, "TheNewGentleman.esp") as Keyword
	endif

	;Set Schlong Faction
	if isDependencyReady("Schlongs of Skyrim.esp")
		schlongfaction = Game.GetFormFromFile(0xAFF8 , "Schlongs of Skyrim.esp") as Faction

		if !schlongfaction
			WritetoErrorlogs("SLOVE" , "Schlong Faction Not Found. Ensure Mod is Properly Installed and Schlongs of Skyrim.esp Plugin Enabled")
		endif
	endif
	;SLO VE: dropped - HentairimResistance faction resolution (resistance module is not part of SLO VE)

	printdebug("initialized complete")

	RegisterForSingleUpdate(Utility.RandomFloat(0.5, 1.0))
EndFunction


int PCPosition
Bool ReactedtoMaleorgasmthissession
Bool ReactedtoFemaleOrgasmThisSession

Function FindActorsAndVoices()


	Actor[] actorList = CurrentThread.GetPositions()
	Int actorCount = actorList.Length
	Int actorIndex = 0

	;SLO VE: no voice aliases - AudioUtil resolves the slot from the actor at play
	;time, so this only identifies actors. The PC is always the "main female".

	;Go through the list of all actors in the scene and get data on their gender
	;PC is always main female
	While actorIndex < actorCount

		Actor actorInQuestion = actorList[actorIndex]
		if actorInQuestion == playerCharacter
			PCPosition = actorIndex
		endif

		If (MasterScript.IsMale(actorInQuestion) || hasSchlong(actorInQuestion)) && actorInQuestion != playerCharacter
			If mainMaleActor == None
				mainMaleActor = actorInQuestion
				mainMaleIsVoiced = true
			EndIf
		EndIf

		actorIndex += 1
	EndWhile

	;fallback keeps the enjoyment/scene logic fed, but a partner picked this way
	;(creature scenes land here) has no human voice - mainMaleIsVoiced stays false
	;so AllowMaleVoice() never gives him lines (Hentairim's mainMaleVoice!=None gate)
	if mainMaleActor == None && actorList.length > 1
		if mainFemaleActor == actorList[0]
			mainMaleActor = actorList[1]
		else
			mainMaleActor = actorList[0]
		endif
	endif

	;SLO VE: replaces the FakeFemaleVoice.SetUpVoiceFromMaleVoice alias hack.
	;When the PC (the "female" voice engine's actor) is male, every female
	;category is remapped to its male counterpart at the PlaySound boundary.
	maleOnlyScene = MasterScript.IsMale(playerCharacter) || hasSchlong(playerCharacter)

	;collect every non-PC male so PickSpeakingMale() can rotate voice lines
	;between them (each resolves his own AudioUtil slot by voicetype/race)
	voiceAllActors = SLOVE_Config.GetInt("voice.voiceallactors", 1)
	int maleCount = 0
	actorIndex = 0
	While actorIndex < actorCount
		If (MasterScript.IsMale(actorList[actorIndex]) || hasSchlong(actorList[actorIndex])) && actorList[actorIndex] != playerCharacter
			maleCount += 1
		EndIf
		actorIndex += 1
	EndWhile
	sceneMales = PapyrusUtil.ActorArray(maleCount)
	int maleIndex = 0
	actorIndex = 0
	While actorIndex < actorCount
		If (MasterScript.IsMale(actorList[actorIndex]) || hasSchlong(actorList[actorIndex])) && actorList[actorIndex] != playerCharacter
			sceneMales[maleIndex] = actorList[actorIndex]
			maleIndex += 1
		EndIf
		actorIndex += 1
	EndWhile
	lastMaleOrgasmActor = None
	lastSecondaryLineTime = 0.0
	secondaryLineCooldown = Utility.RandomFloat(6.0, 14.0)

	;collect voiced creatures (a resolvable AudioUtil slot = C1-C10 via [race_map])
	;for the periodic Breathing ambience - humans are covered by the male rotation
	int creatureCount = 0
	actorIndex = 0
	While actorIndex < actorCount
		If actorList[actorIndex] != playerCharacter && Sexlab.GetGender(actorList[actorIndex]) > 1 && AudioUtil.GetSlotForActor(actorList[actorIndex]) != ""
			creatureCount += 1
		EndIf
		actorIndex += 1
	EndWhile
	sceneCreatures = PapyrusUtil.ActorArray(creatureCount)
	int creatureIndex = 0
	actorIndex = 0
	While actorIndex < actorCount
		If actorList[actorIndex] != playerCharacter && Sexlab.GetGender(actorList[actorIndex]) > 1 && AudioUtil.GetSlotForActor(actorList[actorIndex]) != ""
			sceneCreatures[creatureIndex] = actorList[actorIndex]
			creatureIndex += 1
		EndIf
		actorIndex += 1
	EndWhile
	lastCreatureBreathTime = 0.0
	creatureBreathCooldown = Utility.RandomFloat(2.0, 5.0) ;first breath comes early
	printdebug("scene creatures voiced: " + sceneCreatures.length)

	printdebug("mainfemaleactor :" + mainFemaleActor.getleveledactorbase().GetName())
	printdebug("mainfemaleactor Voice Variation:" + VoiceVariation)
	printdebug("mainmaleactor :" + mainMaleActor.getleveledactorbase().GetName())
	printdebug("scene males voiced: " + sceneMales.length + " | voiceAllActors=" + voiceAllActors + " | maleOnlyScene=" + maleOnlyScene)
EndFunction

;Weighted rotation for regular male lines: the lead speaks most of the time, other
;males chime in occasionally. The randomized cooldown keeps secondary chatter
;spaced out, but it is soft - now and then a secondary line lands inside it
;anyway, so voices can occasionally overlap like a real group would
Actor Function PickSpeakingMale()
	if voiceAllActors != 1 || sceneMales.length <= 1
		return mainMaleActor
	endif
	if Utility.RandomInt(1, 100) <= 60
		return mainMaleActor
	endif
	Float now = CurrentThread.GetTimeTotal()
	if now - lastSecondaryLineTime < secondaryLineCooldown && Utility.RandomInt(1, 100) > 25
		return mainMaleActor
	endif
	Actor pick = sceneMales[Utility.RandomInt(0, sceneMales.length - 1)]
	if pick == None || pick == mainMaleActor
		return mainMaleActor
	endif
	lastSecondaryLineTime = now
	secondaryLineCooldown = Utility.RandomFloat(6.0, 14.0)
	return pick
EndFunction

;Voiced creatures pant/growl on their own randomized cadence (intense stages
;halve the pause). Routed straight to the Director - the human PlaySound
;gating (chemistry, comment counters) is about lines, not ambience. The
;per-speaker channel is the same one the creature's Orgasm line uses, so a
;climax roar replaces a running breath instead of stacking on it.
Function PlayCreatureBreathing()
	if enablecreaturebreathing != 1 || sceneCreatures.length == 0 || TrackerRemoved
		return
	endif
	Float now = CurrentThread.GetTimeTotal()
	if now - lastCreatureBreathTime < creatureBreathCooldown
		return
	endif
	Actor creature = sceneCreatures[Utility.RandomInt(0, sceneCreatures.length - 1)]
	if creature == None
		return
	endif
	lastCreatureBreathTime = now
	Float minPause = creaturebreathmininterval
	Float maxPause = creaturebreathmaxinterval
	if ASLCurrentlyintense
		minPause = minPause / 2.0
		maxPause = maxPause / 2.0
	endif
	creatureBreathCooldown = Utility.RandomFloat(minPause, maxPause)
	printdebug("creature breathing: " + creature.getdisplayname())
	MasterScript.PlaySound("Breathing", creature, False, "partner_low", "slove_np" + creature.GetFormID())
EndFunction

;Post-nut lines belong to whoever actually climaxed
Actor Function LastOrgasmedMale()
	if lastMaleOrgasmActor != None
		return lastMaleOrgasmActor
	endif
	return mainMaleActor
EndFunction

Function RegisterForTheEventsWeNeed()

	RegisterForModEvent("AnimationEnd", "IVDTSceneEnd")

	RegisterForModEvent("SexLabOrgasmSeparate", "IVDTOnOrgasm")

	RegisterForModEvent("StageStart", "IVDTOnStageStart")

EndFunction


Event IVDTSceneEnd(string eventName, string argString, float argNum, form sender);
	If argString as Int != ThreadID ;If true, this isn't our scene that just ended but another scene. So, ignore it.
		Return
	EndIf
	;MasterScript.RegisterThatSceneIsEnding(maleOnlyScene)
	RemoveTracker()

EndEvent

Function ASLEndScene()	;manually end scene

	;MasterScript.RegisterThatSceneIsEnding(maleOnlyScene)
	RemoveTracker()

endfunction
float TimeOfLastKneeJerk

Event IVDTOnOrgasm(Form actorRef, Int thread)

	If thread != ThreadID  || actorWithSceneTrackerSpell != mainFemaleActor
		printdebug("Exiting early: Thread mismatch, wrong actor, or orgasm cooldown active.")
		Return
	EndIf
	Actor actorHavingOrgasm = actorRef as Actor
	printdebug("Actor having orgasm: " + actorHavingOrgasm)
	bool orgasmerIsVoicedMale = actorHavingOrgasm != mainFemaleActor && (MasterScript.IsMale(actorHavingOrgasm) || hasSchlong(actorHavingOrgasm))
	;creatures with a mapped AudioUtil slot (C1-C10 via [race_map]) have a climax
	;line too - but they must NOT become lastMaleOrgasmActor: post-nut talk would
	;try to resolve human categories from a creature slot and come out silent
	bool orgasmerIsVoicedCreature = actorHavingOrgasm != mainFemaleActor && Sexlab.GetGender(actorHavingOrgasm) > 1 && AudioUtil.GetSlotForActor(actorHavingOrgasm) != ""
	if orgasmerIsVoicedMale
		lastMaleOrgasmActor = actorHavingOrgasm ;post-nut lines resolve from his voice slot
	endif

		printdebug("Processing in Non-Linear Scene or Spontaneous Orgasm branch.")

		If actorHavingOrgasm != mainFemaleActor
			printdebug("Male orgasm detected. Recording and reacting.")
			RecordMaleOrgasm()

			if (IsSuckingoffOther() || IsgettingPenetrated()) && (orgasmerIsVoicedMale || orgasmerIsVoicedCreature)
				printdebug("Playing DefaultMaleOrgasm sound.")
				PlaySound("Orgasm", mainFemaleActor, requiredChemistry = 0, soundPriority = 3, waitForCompletion = False, debugtext ="DefaultMaleOrgasm", voiceActor = actorHavingOrgasm)
			endif

			if StorageUtil.GetIntValue(MainFemaleActor, "HandlingMaleOrgasm", 0) != 0
				PrintDebug("[ProcessSpontaneousOrgasm] Skipped because MainFemaleActor is already HandlingMaleOrgasm.")
				return
			EndIf

			if isFemaleOrgasming()
				PrintDebug("[ProcessSpontaneousOrgasm] Skipped because MainFemaleActor is currently orgasming.")
				return
			EndIf

			StorageUtil.setintvalue(MainFemaleActor ,"HandlingMaleOrgasm", 1)

			if mainFemaleEnjoyment <= FemaleOrgasmHypeEnjoyment
				if CurrentPenetrationLvl() > 1
					if ishugepp && (actorHavingOrgasm == mainMaleActor || SexLab.getsex(actorHavingOrgasm) > 2)
						if voicevariation == "B"
							;Insertion Over The Top
							PlaySound("InsertionAnalExcited", mainFemaleActor, requiredChemistry = 0 , debugtext="Insertion Over The Top")
						else
							PlaySound("SurprisedByMaleOrgasm", mainFemaleActor, requiredChemistry = 0 , soundPriority = 3 , debugtext ="SurprisedByMaleOrgasm")
						endif
						ASLAddThickCumleak()
						if Utility.randomint(1,5) == 1
							ASLAddCumPool()
						endif
					else
						if voicevariation == "B" && femaleisvictim()
							;kneejerk intense
							PlaySound("AfterGape", mainFemaleActor, requiredChemistry = 0 , soundPriority = 2 , debugtext = "KneeJerk Intense")
						else
							PlaySound("Oh", mainFemaleActor, requiredChemistry = 0, soundPriority = 3 , debugtext= "KneeJerk")
						endif
					endif

				elseif IsStimulatingOthers()
					printdebug("Playing kneejerk sound.")
					if voicevariation == "B"
						;KneeJerk
						PlaySound("Oh", mainFemaleActor, requiredChemistry = 0, soundPriority = 3 , debugtext= "KneeJerk")
					else
						PlaySound("Oh", mainFemaleActor, requiredChemistry = 0, soundPriority = 3 , debugtext= "MaleOrgasmNonOral")
					endif
				ElseIf IsSuckingoffOther()
					Utility.Wait(Utility.RandomFloat(0.5, 1.5))
					printdebug("Playing MaleOrgasmOral sound.")
					if voicevariation == "B"
						;Male Orgasmed Inside Mouth
						PlaySound("MaleOrgasmOral", mainFemaleActor, requiredChemistry = 0, soundPriority = 3 , debugtext= "Male Orgasmed Inside Mouth")
					else
						PlaySound("MaleOrgasmOral", mainFemaleActor, requiredChemistry = 0, soundPriority = 3 , debugtext= "MaleOrgasmOral")
					endif
				elseif ishugepp
					printdebug("Playing SurprisedByMaleOrgasm sound.")
					if voicevariation == "B"
						;Insertion Over The Top
						PlaySound("InsertionAnalExcited", mainFemaleActor, requiredChemistry = 0 , debugtext="Insertion Over The Top")
					else
						PlaySound("SurprisedByMaleOrgasm", mainFemaleActor, requiredChemistry = 0 , soundPriority = 3 , debugtext ="SurprisedByMaleOrgasm")
					endif
				EndIf
			endif

			if Utility.RandomFloat(0.0, 1.0) <= 0.5 && actorHavingOrgasm == mainMaleActor && !ReactedtoMaleorgasmthissession
				printdebug("Setting ReacttoMaleOrgasmNext to true.")
				ReacttoMaleOrgasmNext = true
				ReactedtoMaleorgasmthissession = true
			endif


			StorageUtil.setintvalue(MainFemaleActor ,"HandlingMaleOrgasm", 0)

		ElseIf actorHavingOrgasm == mainFemaleActor

			if StorageUtil.Getintvalue(MainFemaleActor ,"Orgasming", 0) == 1
				return
			endif

			StorageUtil.setintvalue(MainFemaleActor ,"Orgasming", 1)
			printdebug("Female orgasm detected (Non-linear).")

			ASLAddOrgasmSSquirt()
			printdebug("Added orgasm squirt effect.")

			if !IsUnconcious()
				if CurrentPenetrationLvl() == 1
					printdebug("Playing MaleOrgasmOral sound")
					if VoiceVariation == "B"
						;Male Orgasmed Inside Mouth
						PlaySound("MaleOrgasmOral", mainFemaleActor, requiredChemistry = 0, soundPriority = 3 , debugtext= "Male Orgasmed Inside Mouth")
					else
						PlaySound("MaleOrgasmOral", mainFemaleActor, requiredChemistry = 0, soundPriority = 3 , debugtext= "MaleOrgasmOral")
					endif
				elseif moanonly == 1
					printdebug("Playing simple 'Oh' for female orgasm.")
					PlaySound("Oh", mainFemaleActor, requiredChemistry = 0, soundPriority = 3 , debugtext= "Oh")
				else
					printdebug("Playing FemaleOrgasm sound.")
					PlaySound("Orgasm", mainFemaleActor, requiredChemistry = 0, soundPriority = 3, debugtext ="FemaleOrgasm")
				endif
			endif

			if hypebeforeorgasm == 1 && !isLinearScene()
				printdebug("Disabling orgasm due to hypebeforeorgasm setting.")
				DisableOrgasm()
			endif

			CommentedClosetoOrgasm = false
			printdebug("Recording female orgasm in stats.")
			RecordFemaleOrgasm()
			ASLRemoveOrgasmSSquirt()
			printdebug("Removed orgasm squirt effect.")

			float ChancetoReact = 0.6
			if ASLCurrentlyintense
				ChancetoReact = ChancetoReact / 2
			endif

			if  Utility.RandomFloat(0.0, 1.0) <= ChancetoReact && !ReactedtoFemaleOrgasmThisSession
				printdebug("Setting ReacttoFemaleOrgasmNext to true.")
				ReacttoFemaleOrgasmNext = true
				ReactedtoFemaleOrgasmThisSession = true
			endif
			StorageUtil.setintvalue(MainFemaleActor ,"Orgasming", 0)
		EndIf

EndEvent


Event IVDTOnStageStart(string eventName, string argString, float argNum, form sender)
	;label refresh is driven by the director's label-time latch in IVDTUpdate
EndEvent

Event OnUpdate()
printdebug(" Updating")

if Masterscript.AnimationisEnding()
	EnableOrgasm()
	ASLEndScene()
endif

if actorWithSceneTrackerSpell == mainFemaleActor

	if ShouldInitialize == true && currentstage == 1
		PerformInitialization()
	endif

	;update enjoyment
	mainFemaleEnjoyment = GetActorEnjoyment(mainFemaleActor)
	mainMaleEnjoyment = GetActorEnjoyment(mainMaleActor)
	printdebug(" PC Enjoyment = " + mainFemaleEnjoyment)
	printdebug(" main Male Enjoyment = " + mainMaleEnjoyment)

	if !isShortenedScene() && !isLinearScene()
		ProcessReadytoAdvanceStage()
	else
		SomeoneNeedstoOrgasm = false
	endif

	int failsafe = 0
	while MasterScript.isUpdating() && failsafe < 50 ;wait for director to finish updating
		Utility.wait(0.1)
		failsafe += 1
		printdebug("Waiting for Director to finish Updating")
	endwhile

	if isFemaleOrgasming()
		int orgasmfailsafe = 0
		while isFemaleOrgasming() && orgasmfailsafe < 30 ;cap: a stuck Orgasming flag must not hang the update loop forever
			Utility.wait(1)
			orgasmfailsafe = orgasmfailsafe + 1
		EndWhile
	endif

	printdebug("Director Advance Stage :" + StorageUtil.GetIntValue(None, "DirectorAdvanceStage", 0))
	;usually IVDT is the slowest to be ready. dont do anything until advancing, unless someone really wants to cum first as set in config
	if ReacttoFemaleOrgasmNext || ReacttoMaleOrgasmNext || SomeoneNeedstoOrgasm || StorageUtil.GetIntValue(None, "DirectorAdvanceStage", 0) == 0
		;reactions pending or the stage isn't advancing yet - hold this cycle
	elseif StorageUtil.GetIntValue(None, "DirectorAdvanceStage", 0) == 1
		printdebug("lets Director Advance.")
		;wait for director to update before Continue
		while DirectorLastLabelTime == MasterScript.GetDirectorLastLabelTime() && MasterScript.GetDirectorLastLabelTime() != 0 && StorageUtil.Getintvalue(MainFemaleActor ,"HandlingMaleOrgasm", 0) == 0 && StorageUtil.Getintvalue(MainFemaleActor ,"Orgasming", 0) == 0
			utility.wait(0.3)
			printdebug("Waiting for Director to Advance")
		endwhile
	endif
	IVDTUpdate()

;=========================run Dirty Talk & sex Effects=======================
	nextUpdateInterval = 0.1

	;chance for male voice
	if AllowMaleVoice()
		PlayMaleComments()
	endif
	;creature partners pant/growl on their own cadence
	PlayCreatureBreathing()
	;SLO VE: dropped - the commented-out linear-scene pre/post orgasm choreography block
	;(LinearScenePlay* functions) - dead even in the source, gated by isLinearScene()=false

	;if gagged, override everything else
	if HasDeviousGag(mainFemaleActor)

		EnableOrgasm()
		if EnableDDGagVoice == 1
			PlayGaggedSound()
		endif
	elseif IsKissing()  ;kissing
		if VoiceVariation == "B"
			PlayKissingVarB()
		else
			PlayKissing()
		EndIf

	elseif MoanOnly == 1 || isShortenedScene()
		if VoiceVariation == "B"
			PlayMoanonlyVarB()
		else
			PlayMoanonly()
		endif
	;if reacting to female orgasm
	elseif femaleCloseToOrgasm() && mainFemaleEnjoyment > mainMaleEnjoyment && Utility.RandomFloat(0.0, 1.0) < chancetocommentwhenclosetoorgasm && (!IsFemdom() || (teasedClosetoorgasm && IsFemdom()))
		if VoiceVariation == "B"
			ASLPlayFemaleOrgasmHypeVarB()
		else
			ASLPlayFemaleOrgasmHype()
		endif
	elseif ShouldPlayMaleOrgasmHype() && mainFemaleEnjoyment < mainMaleEnjoyment && Utility.RandomFloat(0.0, 1.0) < ChanceToCommentWhenMaleCloseToOrgasm
		if VoiceVariation == "B"
			ASLPlayMaleClosetoOrgasmCommentsVarB()
		else
			ASLPlayMaleClosetoOrgasmComments()
		endif
	elseif ReacttoFemaleOrgasmNext == true
		if VoiceVariation == "B"
			ASLHandleFemaleOrgasmReactionVarB()
		else
			ASLHandleFemaleOrgasmReaction()
		endif
	;if reacting to male orgasm
	elseif	ReacttoMaleOrgasmNext == true
		if VoiceVariation == "B"
			ASLHandleMaleOrgasmReactionVarB()
		else
			ASLHandleMaleOrgasmReaction()
		Endif
	elseif IsSuckingoffOther() ;blowjob always first because muffled by cock
		if VoiceVariation == "B"
			PlayBlowjobVarB()
		else
			PlayBlowjob()
		Endif
	elseif IsCunnilingus() && !ASLcurrentlyintense ;Cunnilingus
		if VoiceVariation == "B"
			PlayCunnilingusVarB()
		else
			PlayCunnilingus()
		endif
	elseif IsgettingPenetrated() && IshugePP ; Huge pp Penetration
		if VoiceVariation == "B"
			PlayGettingFuckedbyHugePPVarB()
		else
			PlayGettingFuckedbyHugePP()
		endif
	elseif IsGettingDoublePenetrated() ; double penetratino
		if VoiceVariation == "B"
			PlayGettingFuckedDoubleVarB()
		else
			PlayGettingFuckedDouble()
		endif
	elseif IsGettingInsertedBig() ; Fisting or huge objects
		if VoiceVariation == "B"
			PlayStimulatedHardVarB()
		else
			PlayStimulatedHard()
		endif
	elseif ASLisBroken() && VoiceVariation == "B" && !ASLcurrentlyIntense
		if VoiceVariation == "B"
			PlayBrokenVarB()
		else
			PlayBroken()
		Endif
	elseif IsCowgirl() ;cowgirl or femdom
		if VoiceVariation == "B"
			PlayCowgirlVarB()
		else
			PlayCowgirl()
		endif

	elseif IsgettingPenetrated() ; Penetration
		if VoiceVariation == "B"
			PlayGettingFuckedVarB()
		else
			PlayGettingFucked()
		endif
	elseif IsGivingAnalPenetration() || IsGivingVaginalPenetration() ;fucking others with penis
		if VoiceVariation == "B"
			PlayFuckingOthersVarB()
		else
			PlayFuckingOthers()
		endif
	elseif IsGettingStimulated() ;Getting Stimulated like fingering but no penetration
		if VoiceVariation == "B"
			PlayGettingStimulatedVarB()
		else
			PlayGettingStimulated()
		endif

	elseif IsStimulatingOthers() ;Stimulating others with finger handjob footjob titfuck
		if VoiceVariation == "B"
			PlayStimulatingOthersVarB()
		else
			PlayStimulatingOthers()
		endif
	elseif IsEnding()
		if VoiceVariation == "B"
			PlayEndingVarB()
		else
			PlayEnding()
		endif
	elseif IsLeadIN()
		if VoiceVariation == "B"
			PlayLeadInVarB()
		else
			PlayLeadIn()
		endif
	endif


	nextUpdateInterval = NextUpdateInterval()
endif

if actorWithSceneTrackerSpell == mainMaleActor
	nextUpdateInterval = 1.1
endif

RegisterForSingleUpdate(nextUpdateInterval)

EndEvent

bool TrackerRemoved = false
Function RemoveTracker()

	TrackerRemoved = true
	StorageUtil.unSetStringvalue(None, "Scenario")
	;silence voice lines still playing or about to start behind a pre-delay.
	;Instances are tracked natively now, so in-flight lines can simply be stopped;
	;the groups stay ducked for a moment so a line that slips past the
	;TrackerRemoved check plays silent, then everything is restored
	AudioUtil.DuckGroup("pc_low")
	AudioUtil.DuckGroup("pc_high")
	AudioUtil.DuckGroup("partner_low")
	AudioUtil.DuckGroup("partner_high")
	AudioUtil.StopGroup("pc_low")
	AudioUtil.StopGroup("pc_high")
	AudioUtil.StopGroup("partner_low")
	AudioUtil.StopGroup("partner_high")
	ASLRemoveOrgasmSSquirt()
	ASLRemoveThickCumleak()
	ASLRemoveCumPool()
	;Perform needed clean up first
	UnregisterForUpdate()
	StorageUtil.Unsetintvalue(MainFemaleActor ,"HandlingMaleOrgasm")
	StorageUtil.Unsetintvalue(MainFemaleActor ,"Orgasming")
	;keep the silence window briefly for stragglers, then restore the groups
	Utility.Wait(4.0)
	AudioUtil.UnduckGroup("pc_low")
	AudioUtil.UnduckGroup("pc_high")
	AudioUtil.UnduckGroup("partner_low")
	AudioUtil.UnduckGroup("partner_high")
	;Do this very last, but make sure to do it (it's what actually removes the tracker)
	actorWithSceneTrackerSpell.RemoveSpell(SceneTrackerSpell)

EndFunction



Function RecordMaleOrgasm()
	;Ordering of some these statements matter because some depend on the others...

	if IsgettingPenetrated()
		CameInsideCount = CameInsideCount + 1
	endif

	locationOfLastMaleOrgasm = CurrentPenetrationLvl()


	maleOrgasmCount += 1
	timeOfLastMaleOrgasm = CurrentThread.GetTimeTotal()

EndFunction

Function RecordFemaleOrgasm()
	femaleRecordedOrgasmCount += 1
	timeOfLastRecordedFemaleOrgasm = CurrentThread.GetTimeTotal()

EndFunction

Int Function GetActorEnjoyment(Actor actorInQuestion)
	If actorInQuestion == None
		Return -1
	Else
		Return CurrentThread.GetEnjoyment(actorInQuestion)
	EndIf
EndFunction

Function PlaySound(String theSound, Actor actorMakingSound, Int requiredChemistry = 0, Int soundPriority = 0, Float maxQueueDuration = 5.0, Bool waitForCompletion = True , string debugtext = "None" , Bool Force = false , Bool SkipWait = false , Actor voiceActor = None)

	String soundToPlay = thesound

	If soundToPlay == ""
		WritetoErrorlogs("SLOVE","Sound Name :" + debugtext + " is None")
		Return
	EndIf

	;SLO VE: male-only boundary - replaces the FakeFemaleVoice alias hack. When the
	;PC resolves to a male voice pack, female categories are remapped to their male
	;counterparts here (male categories pass through the map unchanged).
	if maleOnlyScene
		soundToPlay = SLOVE_VoiceCategories.MaleOnlyRemap(soundToPlay)
	endif

	;AudioUtil resolves the voice slot from the actor it is handed. Male lines are
	;routed through the female branch on purpose (actorMakingSound = mainFemaleActor,
	;the shipped gating/expression behavior), so voiceActor carries whose voice
	;folders the category resolves against when that differs from the routing actor
	Actor audioActor = voiceActor
	if audioActor == None
		audioActor = actorMakingSound
	endif
	;per-speaker exclusivity channel: AudioUtil natively stops the channel's
	;previous occupant, so two lines from the SAME speaker can never overlay
	;(priority>1 bypasses the counter gates by design, and the orgasm events run
	;on their own threads - both slipped past the counters and stacked lines).
	;Different speakers keep their own channels and still overlap deliberately
	;(male comments over the PC's moans, group chatter between males).
	String voiceChannel = "slove_pc"
	if audioActor != playerCharacter
		voiceChannel = "slove_np" + audioActor.GetFormID()
	endif
	If TrackerRemoved ;scene is over - don't start queued voice lines
		Return
	EndIf
	; male or other playing sound
	if actorMakingSound != mainFemaleActor && (currentlyPlayingSoundCountMale == 0 || soundpriority > 1) ;others playing sound.
		Printdebug("Non PC Playing voice : " + debugtext)
		currentlyPlayingSoundCountMale = currentlyPlayingSoundCountMale + 1

		;lower down voice of female moan when male says something


		if !TrackerRemoved
			String partnerGroup = "partner_low"
			if soundPriority > 1
				partnerGroup = "partner_high"
			endif
			MasterScript.PlaySound(soundToPlay, audioActor, waitForCompletion, partnerGroup, voiceChannel)
		endif

		currentlyPlayingSoundCountMale = currentlyPlayingSoundCountMale - 1



	;female playing sound
	elseif actorMakingSound == mainFemaleActor && (currentlyPlayingSoundCount == 0 || soundpriority > 1)	 ;Female play sound
		Printdebug("PC Playing voice : " + debugtext)
		ChangePCExpressions(debugtext)

		currentlyPlayingSoundCount = currentlyPlayingSoundCount + 1

		if SoundPriority <= 1 && soundToPlay != PreviousSound && SkipWait == false
			if ASLcurrentlyIntense
				utility.wait(utility.randomint(0,1))
			else
				utility.wait(utility.randomint(1,2))
			endif
		endif
		;track previous sound
		PreviousSound = soundToPlay

		if soundPriority >2
			AudioUtil.DuckGroup("pc_low")
		endif

		if IsUnconcious()
			AudioUtil.DuckGroup("pc_low")
			AudioUtil.DuckGroup("pc_high")
		endif

		if !TrackerRemoved ;re-check: the scene may have ended during the pre-delay wait
			String pcGroup = "pc_low"
			if soundPriority > 1
				pcGroup = "pc_high"
			endif
			MasterScript.PlaySound(soundToPlay, audioActor, waitForCompletion, pcGroup, voiceChannel)
		endif

		currentlyPlayingSoundCount = currentlyPlayingSoundCount - 1

		if currentlyPlayingSoundCount ==0
			;TrackerRemoved: don't undo RemoveTracker's end-of-scene silence window
			if !IsUnconcious() && !TrackerRemoved
				AudioUtil.UnduckGroup("pc_low")
				AudioUtil.UnduckGroup("pc_high")
			endif
		endif
	else
		Utility.Wait(Utility.RandomFloat(1, 2))
	EndIf

EndFunction


Bool Function IsEarlyToCum()
	Return currentstage <= 2 && maleOrgasmCount < 2
EndFunction

Bool Function ShouldPlayMaleOrgasmHype()
	;SLO VE: linear-scene/stage-timer arms folded away - enjoyment decides
	if !teasedClosetoorgasm
		return false
	endif
	return mainMaleEnjoyment >= MaleOrgasmHypeEnjoyment
EndFunction

;make romantic comment
Function MakeRomanticCommentIfRightTime(Bool forceComment = False)

	PlaySound("LoveyDovey", mainFemaleActor, requiredChemistry = 0, debugtext="LoveyDovey")

	timeOfLastRomanticRemark = CurrentThread.GetTimeTotal()

EndFunction

Bool Function ShouldMakeRomanticComment()
	if femaleisvictim()
		return false
	elseIf CurrentThread.GetTimeTotal() - timeOfLastRomanticRemark < 60 ;Too soon. Romantic comments should be spaced out and rare
		Return False
	ElseIf !IsgettingPenetrated() && Currentstage <= 2
		Return Utility.RandomFloat(0.0, 1.0) < 0.1
	else
		return false
	EndIf
EndFunction


Bool Function FemaleIsSatisfied()

	Return femaleRecordedOrgasmCount > utility.randomint(2,3)
endfunction

Bool Function MaleIsSatisfied()

	Return maleOrgasmCount >  utility.randomint(2,4)
endfunction


Bool Function PossiblyAskForCumInSpecificLocation()

	if IsGettingDoublePenetrated()
		if Utility.RandomFloat(0.0, 1.0) < 0.3
			PlaySound("AskForAnalCum", mainFemaleActor, requiredChemistry = 3 , debugtext = "AskForAnalCum")
		else
			PlaySound("AskForVaginalCum", mainFemaleActor, requiredChemistry = 4 , debugtext = "AskForVaginalCum")
		endif
	elseif IsGettingVaginallyPenetrated()
		PlaySound("AskForVaginalCum", mainFemaleActor, requiredChemistry = 4 , debugtext = "AskForVaginalCum")
	elseif IsGettingAnallyPenetrated()
		PlaySound("AskForAnalCum", mainFemaleActor, requiredChemistry = 3 , debugtext = "AskForAnalCum")

	elseif IsSuckingoffOther()
		PlaySound("AskForOralCum", mainFemaleActor, requiredChemistry = 2 , debugtext = "AskForOralCum")
	endif

	return false
EndFunction

Function PossiblyRemarkOnCumLocation()
	;Go ahead with remark
	If locationOfLastMaleOrgasm == 1
		PlaySound("CameInMouth", mainFemaleActor, requiredChemistry = 0 , debugtext = "CameInMouth")
		Utility.Wait(Utility.RandomFloat(0.75, 1.75))

	ElseIf locationOfLastMaleOrgasm == 2
		PlaySound("CameInPussy", mainFemaleActor, requiredChemistry = 0 , debugtext = "CameInPussy")
		Utility.Wait(Utility.RandomFloat(0.75, 1.75))

	ElseIf locationOfLastMaleOrgasm == 3
		PlaySound("CameInAss", mainFemaleActor, requiredChemistry = 0 , debugtext = "CameInAss")
		Utility.Wait(Utility.RandomFloat(0.75, 1.75))

	EndIf
EndFunction

Function PossiblyRemarkOnCumLocationVarB()
	;Go ahead with remark
	If locationOfLastMaleOrgasm == 1
		;Ending Orgasmed Inside Mouth
		PlaySound("CameInMouth", mainFemaleActor, requiredChemistry = 0 , debugtext = "Ending Orgasmed Inside Mouth")
		Utility.Wait(Utility.RandomFloat(0.75, 1.75))

	ElseIf locationOfLastMaleOrgasm == 2
		;Ending Orgasmed Inside Pussy
		PlaySound("CameInPussy", mainFemaleActor, requiredChemistry = 0 , debugtext = "Ending Orgasmed Inside Pussy")
		Utility.Wait(Utility.RandomFloat(0.75, 1.75))

	ElseIf locationOfLastMaleOrgasm == 3
		;Ending Orgasmed Inside Ass
		PlaySound("CameInAss", mainFemaleActor, requiredChemistry = 0 , debugtext = "Ending Orgasmed Inside Ass")
		Utility.Wait(Utility.RandomFloat(0.75, 1.75))

	EndIf
EndFunction

bool ishugepp

Bool function IshugePP()

  if EnableHugePPScenario != 1
    return false
  endif
	return MasterScript.IsHugePP(mainMaleActor) ;SLO VE: SOS/TNG/race-name logic lives in the director now
EndFunction


Bool Function IsLeadIN()
	return Stimulationlabel == "LDI" && PenisActionlabel == "LDI" && Penetrationlabel == "LDI" && OralLabel == "LDI" && EndingLabel == "LDI"
endfunction


Bool Function FemaleIsVictim()
return CurrentThread.GetSubmissive(mainFemaleActor) && !ASLisBroken() && EnableVictimScenario == 1
EndFunction

Bool Function MaleIsVictim()
return CurrentThread.GetSubmissive(mainMaleActor) && EnableVictimScenario == 1
EndFunction

Function IVDTUpdate()

	bool StageTransitioning = false

	if DirectorLastLabelTime != MasterScript.GetDirectorLastLabelTime()
		CurrentSceneid = CurrentThread.GetActiveScene()
		currentStageID = CurrentThread.GetActiveStage()
		currentstage = GetLegacyStageNum(CurrentSceneid, currentStageID)
		timeOfLastStageStart = CurrentThread.GetTimeTotal()

		ishugepp = ishugePP()
		printdebug("ishugepp Scenario : " + ishugepp)
		UpdateLabels(CurrentSceneid , currentstage , PCPosition) ;update only for PC
		StageTransitioning = true
		;set intensity
		ASLpreviouslyintense = ASLcurrentlyIntense

		if stringutil.find(Labelsconcat ,"1F") > -1 || IsGettingInsertedBig()
			ASLCurrentlyintense = true
		else
			ASLCurrentlyintense = false
		endif

		if currentstage <= 2
			ReactedtoFemaleOrgasmThisSession = false
			ReactedtoMaleOrgasmThisSession = false
			teasedClosetoorgasm = false
		endif

		DirectorLastLabelTime = MasterScript.GetDirectorLastLabelTime()
		printdebug("Stage is intense? : " + ASLCurrentlyintense)
	endif

;Play advance stage words
	if StageTransitioning && actorWithSceneTrackerSpell == mainFemaleActor && !isShortenedScene() && !IsfinalStage()

		printdebug("Stage Transitioning")
		ASLPlayStageTransition()
	endif

endfunction

Function PlayLeadIn() ;no relevant tags
printdebug("Play Lead In")

if currentstage < 3 && !femaleisvictim() ;greets only on first 2 stages

	if  ShouldMakeRomanticComment()
		MakeRomanticCommentIfRightTime()
	elseif ishugepp && Utility.RandomFloat(0.0, 1.0) < ChanceToCommentonLeadinStage
		PlaySound("GreetLoadedFamiliar", mainFemaleActor, requiredChemistry = 1, debugtext = "GreetLoadedFamiliar")
	;make greeting at 7% chance at 1st stage
	elseif Utility.RandomFloat(0.0, 1.0) < ChanceToCommentonLeadinStage && Currentstage == 1
		ASLMakeGreetingToMalePartner()
	endif
endif

	if PrevEndingLabel == "ENO" || PrevEndingLabel == "ENI"; for some reason if the EN stage was extended into LI
		PlaySound("AfterOrgasmExclamations", mainFemaleActor, requiredChemistry = 0 , debugtext = "AfterOrgasmExclamations")
	elseif Utility.RandomFloat(0.0, 1.0) < ChanceToCommentonLeadinStage * 2 && mainFemaleEnjoyment >= 50 && !FemaleIsVictim()
		PlaySound("ReadyToGetGoing", mainFemaleActor, requiredChemistry = 0 , debugtext = "ReadyToGetGoing")
	else

		PlayBreathyorforeplaysound()

	endif

endfunction

Function PlayLeadInVarB() ;no relevant tags
printdebug("Play Lead In")

if ASLisBroken()
	;Broken Begging
	PlaySound("GreetLover", mainFemaleActor, requiredChemistry = 0 , debugtext = "Broken Begging")
else
	PlayMoanonlyVarB()
endif

endfunction

Function PlayKissing()
printdebug("Play Kissing")

if  ShouldMakeRomanticComment()
	MakeRomanticCommentIfRightTime()
else
;dont say make any noise while kissing. let Enjoyment make the kissing sound
if useblowjobsoundforkissing == 1
	PlaySound("BlowjobActionSoft", mainFemaleActor, requiredChemistry = 0 , debugtext = "BlowjobActionSoft")
else
	Utility.wait(3)
endif


endif
endfunction


Function PlayKissingVarB()
printdebug("Play Kissing")
;Kissing
PlaySound("MaleOrgasmReactionLover", mainFemaleActor, requiredChemistry = 0 , debugtext = "Kissing")
endfunction

Function PlayCunnilingus()
printdebug("Play Cunnilingus")

	PlaySound("BlowjobActionSoft", mainFemaleActor, requiredChemistry = 0 , debugtext = "BlowjobActionSoft")

endfunction

Function PlayCunnilingusVarB()
printdebug("Play Cunnilingus")

	PlaySound("BlowjobActionSoft", mainFemaleActor, requiredChemistry = 0 , debugtext = "BlowjobActionSoft")

endfunction

Function PlayMaleComments()

	if (Primarystagelabel == "LDI" || IsGettingStimulated()) && !IsgettingPenetrated() && Currentstage < 3

		PlaySound("Aroused", mainFemaleActor, requiredChemistry = 0, soundPriority = 2  , voiceActor = PickSpeakingMale())

		if	ASLisBroken()
			PlaySound("AfterOrgasmExclamations", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 , debugtext = "AfterOrgasmExclamations")
		else
			PlaySound("ForeplaySoft", mainFemaleActor, requiredChemistry = 0 , debugtext = "Foreplaysoft")
		endif

	elseif ShouldPlayMaleOrgasmHype()


		PlaySound("AboutToCum", mainFemaleActor, requiredChemistry = 0,  soundPriority = 2 , waitForCompletion = False , debugtext = "AboutToCum" , voiceActor = mainMaleActor)
		;female background moaning

		if IsUnconcious()
			return
		elseif ASLisBroken()
			PlaySound("AfterOrgasmExclamations", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 , debugtext = "AfterOrgasmExclamations")
		else
			if ASLCurrentlyintense

				PlaySound("NearOrgasmNoises", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "NearOrgasmNoises")
				else
				PlaySound("PenetrativeGrunts", mainFemaleActor, requiredChemistry = 0 ,soundPriority = 1 , debugtext = "PenetrativeGrunts")
			endif
		endif

	elseif MaleIsVictim() || IsFemdom()
		;male say something
		PlaySound("TeaseAggressivePartner", mainFemaleActor, soundPriority = 2 , waitForCompletion = False  , voiceActor = PickSpeakingMale())
		;female background moaning
		if IsUnconcious()
			return
		elseif ASLisBroken()
			PlaySound("AfterOrgasmExclamations", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 , debugtext = "AfterOrgasmExclamations")
		else
			PlaySound("PenetrativeGrunts", mainFemaleActor, requiredChemistry = 0 ,soundPriority = 1 , debugtext = "PenetrativeGrunts")

		endif



	elseif  CurrentPenetrationLvl() >= 2 && ASLCurrentlyintense

		;male say something
		if IsUnconcious()
			return
		elseif femaleisvictim()
			PlaySound("Aggressive", mainFemaleActor, requiredChemistry = 0, soundPriority = 2 , waitForCompletion = False  , debugtext="Aggressive" , voiceActor = PickSpeakingMale())
		else
			PlaySound("StrugglingSubtle", mainFemaleActor, requiredChemistry = 0, soundPriority = 2 , waitForCompletion = False  , debugtext="StrugglingSubtle" , voiceActor = PickSpeakingMale())
		endif
		;female background moaning

		PlaySound("NearOrgasmNoises", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "NearOrgasmNoises")

	elseif	CurrentPenetrationLvl() >= 2 && !ASLCurrentlyintense
				;female background moaning
		PlaySound("StrugglingEarly", mainFemaleActor, requiredChemistry = 0, soundPriority = 2 , waitForCompletion = False , debugtext = "StrugglingEarly" , voiceActor = PickSpeakingMale())

		if IsUnconcious()
			return
		elseif ASLisBroken()
			PlaySound("AfterOrgasmExclamations", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 , debugtext = "AfterOrgasmExclamations" )
		else
			PlaySound("PenetrativeGrunts", mainFemaleActor, requiredChemistry = 0 ,soundPriority = 1 , debugtext = "PenetrativeGrunts")

		endif


	endif

endfunction

;SLO VE: dropped - LinearScenePlayFemalePreFinalStage/VarB and
;LinearScenePlayFemalePostOrgasm/VarB (only reachable from the commented-out
;linear-scene block in OnUpdate; isLinearScene() is a director stub = false)

Function PlayBlowjob()


	if VoiceVariation == "A"
		if Utility.RandomFloat(0.0, 1.0) <= ChanceToCommentonBlowjobStage && ASLcurrentlyIntense
			PlaySound("AppreciatePartner", mainFemaleActor, requiredChemistry = 0 , debugtext = "AppreciatePartner")
		elseif Utility.RandomFloat(0.0, 1.0) <= ChanceToCommentonBlowjobStage && !femaleisvictim() && !ASLIsBroken() && !ASLcurrentlyIntense
			PlaySound("BlowjobRemarks", mainFemaleActor, requiredChemistry = 0 , debugtext = "BlowjobRemarks")
		elseif ASLcurrentlyIntense
			PlaySound("BlowjobActionIntense", mainFemaleActor, requiredChemistry = 0 , debugtext = "BlowjobActionIntense")
		else
			PlaySound("BlowjobActionSoft", mainFemaleActor, requiredChemistry = 0 , debugtext = "BlowjobActionSoft")
		endif
	else
		if Utility.RandomFloat(0.0, 1.0) < ChanceToCommentonBlowjobStage && currentstage > 1 && !femaleisvictim() && !ASLIsBroken()
			PlaySound("BlowjobRemarks", mainFemaleActor, requiredChemistry = 0 , debugtext = "BlowjobRemarks")
		elseif ASLcurrentlyIntense
			PlaySound("BlowjobActionIntense", mainFemaleActor, requiredChemistry = 0 , debugtext = "BlowjobActionIntense")
		else
			PlaySound("BlowjobActionSoft", mainFemaleActor, requiredChemistry = 0 , debugtext = "BlowjobActionSoft")
		endif
	endif



endfunction


Function PlayBlowjobVarB()

		if Utility.RandomFloat(0.0, 1.0) < ChanceToCommentonBlowjobStage && currentstage > 1 && !femaleisvictim() && !ASLIsBroken()
			if CurrentThread.HasSceneTag("Forced") || IsgettingPenetrated()
				;Blowjob Forced Comments
				PlaySound("NoticeMaleWantsMore", mainFemaleActor, requiredChemistry = 0 , debugtext = "Blowjob Forced Comments")
			elseif ASLcurrentlyIntense
				;Blowjob Comments Intense
				PlaySound("AppreciatePartner", mainFemaleActor, requiredChemistry = 0 , debugtext = "Blowjob Comments Intense")
			else
				;Blowjob Comments
				PlaySound("BlowjobRemarks", mainFemaleActor, requiredChemistry = 0 , debugtext = "Blowjob Comments")
			endif
		elseif CurrentThread.HasSceneTag("Forced") || IsgettingPenetrated()
			;Blowjob Forced
			PlaySound("AskForAnal", mainFemaleActor, requiredChemistry = 0 , debugtext = "Blowjob Forced")
		elseif ASLcurrentlyIntense
			;Blowjob Action Intense
			PlaySound("BlowjobActionIntense", mainFemaleActor, requiredChemistry = 0 , debugtext = "Blowjob Action Intense")
		else
			;Blowjob Action
			PlaySound("BlowjobActionSoft", mainFemaleActor, requiredChemistry = 0 , debugtext = "Blowjob Action")
		endif

	If femaleCloseToOrgasm() && IsgettingPenetrated() ;When female close to orgasm
		EnableOrgasm()
		CommentedClosetoOrgasm = true
	endif
endfunction

Function PlayStimulatingOthers()
printdebug("Play Stimulating Others")

	;after close to orgasm handling
	if	Utility.RandomFloat(0.0, 1.0) < ChanceToCommentononAttackingStage/3 && !FemaleIsVictim()
		PlaySound("Amused", mainFemaleActor, requiredChemistry = 0 , debugtext = "Amused")
	else
		PlayBreathyorforeplaysound()
	EndIf

EndFunction

Function PlayStimulatingOthersVarB()
printdebug("Play Stimulating Others")

if !femaleisvictim() && Utility.RandomFloat(0.0, 1.0) < ChanceToCommentononAttackingStage
	if ASLisBroken()
		;Broken Begging
		PlaySound("GreetLover", mainFemaleActor, requiredChemistry = 0 , debugtext = "Broken Begging")
	elseif IsFemdom()
		if Utility.RandomInt(1,2) == 1
			;Foreplay Femdom Comments
			PlaySound("Satisfied", mainFemaleActor, requiredChemistry = 0 , debugtext = "Foreplay Femdom Comments")
		else
			;Amused
			PlaySound("Amused", mainFemaleActor, requiredChemistry = 0 , debugtext = "Amused")
		endif
	elseif isTitfuckOthers
		;Foreplay BoobJob Comments
		PlaySound("ForeplayIntense", mainFemaleActor, requiredChemistry = 0 , debugtext = "Foreplay BoobJob Comments")
	elseif isHandjobOthers
		;Foreplay Handjob Comments
		PlaySound("ForeplaySoft", mainFemaleActor, requiredChemistry = 0 , debugtext = "Foreplay Handjob Comments")
	elseif IsFootjobOthers
		;Foreplay FootJob Comments
		PlaySound("MadeMeCumSoMuch", mainFemaleActor, requiredChemistry = 0 , debugtext = "Foreplay FootJob Comments")
	endif
else
	PlayMoanonlyVarB()
EndIf

EndFunction


Function PlayStimulatedHard()
printdebug("Play Stimulated Hard (Huge non Penile insertion)")


if CommentedClosetoOrgasm
	PlaySound("SensitivePleasure", mainFemaleActor, requiredChemistry = 0 , debugtext = "SensitivePleasure")
else
	if Utility.RandomFloat(0.0, 1.0) < 0.8
		PlaySound("SensitivePleasure", mainFemaleActor, requiredChemistry = 0 , debugtext = "SensitivePleasure")
	else
		PlaySound("Oh", mainFemaleActor, requiredChemistry = 0 ,soundPriority = 2 , debugtext = "Oh")
		Utility.Wait(Utility.RandomFloat(1.0, 2.0))
		PlaySound("AfterGape", mainFemaleActor, requiredChemistry = 0 , soundPriority = 2 , debugtext = "AfterGape")
	endif
endif

EndFunction

Function PlayStimulatedHardVarB()
printdebug("Play Stimulated Hard (Huge non Penile insertion) Var B")


if CommentedClosetoOrgasm
	PlayMoanonly()

else
	;Penetrated Grunt Victim Intense
	PlaySound("CumTogetherTease", mainFemaleActor, requiredChemistry = 0 , debugtext = "Penetrated Grunt Victim Intense")

endif

EndFunction

Function PlayGettingStimulated()

printdebug("Play Getting Stimulated")
;------------------INTENSE-------------------
if ASLCurrentlyintense

	if CommentedClosetoOrgasm
		PlaySound("NearOrgasmNoises", mainFemaleActor, requiredChemistry = 0 , debugtext = "NearOrgasmNoises")

	else ;After Handling close to Orgasm
		PlaySound("PenetrativeGrunts", mainFemaleActor, requiredChemistry = 0 , debugtext = "PenetrativeGrunts")
	EndIf

;------------------ NOt INTENSE-------------------
else
	if CommentedClosetoOrgasm
		PlaySound("PenetrativeGrunts", mainFemaleActor, requiredChemistry = 0 , debugtext = "PenetrativeGrunts")
	else
		;after handling close to orgasm
		If femaleisvictim() && Utility.RandomFloat(0.0, 1.0) < ChanceToCommentUnamused
			PlaySound("Unamused", mainFemaleActor, requiredChemistry = 0 , debugtext = "Unamused")
		else
			PlayBreathyorforeplaysound()
		EndIf
	endif
endif

EndFunction

Function PlayGettingStimulatedVarB()

printdebug("Play Getting Stimulated Var B")
;------------------INTENSE-------------------

	if CommentedClosetoOrgasm
		PlayMoanonlyVarB()
	elseif Utility.RandomFloat(0.0, 1.0) < chancetocommentonnonintensestage
		if femaleisvictim()
			;Stimulated Victim Comments
			PlaySound("GreetLoadedFamiliar", mainFemaleActor, requiredChemistry = 0 , debugtext = "Stimulated Victim Comments")
		else
			;Stimulated Comments
			PlaySound("MaleOrgasmNonOral", mainFemaleActor, requiredChemistry = 0 , debugtext = "Stimulated Comments")
		endif
	else
		PlayMoanonlyVarB()
	EndIf


EndFunction



Function PlayFuckingOthers()
printdebug("Play Fucking Others")

if CommentedClosetoOrgasm
	if ASLcurrentlyintense
		PlaySound("PenetrativeGrunts", mainFemaleActor, requiredChemistry = 0 , debugtext = "PenetrativeGrunts")
	else
		PlayBreathyorforeplaysound()
	endif
else
	;after close to orgasm handling
	if	Utility.RandomFloat(0.0, 1.0) < ChanceToCommentononAttackingStage/3
		PlaySound("Amused", mainFemaleActor, requiredChemistry = 0 , debugtext = "Amused")
	else
		if ASLcurrentlyintense
			PlaySound("PenetrativeGrunts", mainFemaleActor, requiredChemistry = 0 , debugtext = "PenetrativeGrunts")
		else
			PlayBreathyorforeplaysound()
		endif
	EndIf

endif

EndFunction


Function PlayFuckingOthersVarB()
printdebug("Play Fucking Others Var B")

if CommentedClosetoOrgasm
	PlayMoanonlyVarB()
elseif Utility.RandomFloat(0.0, 1.0) < ChanceToCommentononAttackingStage
	;Amused
	PlaySound("Amused", mainFemaleActor, requiredChemistry = 0 , debugtext = "Amused")

else
	PlayMoanonlyVarB()
endif

EndFunction

Function PlayBroken()
printdebug("Play Broken")
if CommentedClosetoOrgasm
	PlaySound("PenetrativeGrunts", mainFemaleActor, requiredChemistry = 0 , debugtext = "PenetrativeGrunts")
elseif  Utility.RandomFloat(0.0, 1.0) < 0.15	&& !ASLcurrentlyintense

	PlaySound("AfterOrgasmExclamations", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 , debugtext = "AfterOrgasmExclamations")
elseif IsFemdom() && Utility.RandomFloat(0.0, 1.0) < ChanceToCommentononAttackingStage/2

	PlaySound("OnTheAttack", mainFemaleActor, requiredChemistry = 0 , debugtext = "OnTheAttack")
elseif  Utility.RandomFloat(0.0, 1.0) < ChanceToCommentononAttackingStage/4

	PlaySound("Amused", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 , debugtext = "Amused")
elseif  Utility.RandomFloat(0.0, 1.0) < ChanceToCommentononAttackingStage/4

	PlaySound("InAwe", mainFemaleActor, requiredChemistry = 0 , debugtext = "InAwe")
else

	PlaySound("AfterOrgasmArouse", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "AfterOrgasmArouse")
endif
endfunction


Function PlayBrokenVarB(Bool MustComment = false)
printdebug("Play Broken Var B")
if CommentedClosetoOrgasm
	PlayMoanonlyVarB()
elseif (IsGettingAnallyPenetrated() || IsGettingVaginallyPenetrated()) && (Utility.RandomFloat(0.0, 1.0) < ChanceToCommentonIntenseStage || MustComment)
	if ASLCurrentlyintense
		;Penetrated Broken Comments Intense
		PlaySound("BeforeGape", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "Penetrated Broken Comments Intense")
	else
		;Penetrated Broken Comments
		PlaySound("AfterOrgasmArouse", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "Penetrated Broken Comments")
	endif
else
	PlayMoanonlyVarB()
endif
endfunction

Function PlayCowgirl()

printdebug("Play Cowgirl")

if CommentedClosetoOrgasm
	if ASLcurrentlyintense
		PlaySound("NearOrgasmNoises", mainFemaleActor, requiredChemistry = 0 , debugtext = "NearOrgasmNoises")
	else
		PlaySound("PenetrativeGrunts", mainFemaleActor, requiredChemistry = 0 , debugtext = "PenetrativeGrunts")
	endif
else
	;make greeting
	if Utility.RandomFloat(0.0, 1.0)  < ChanceToCommentonNonIntenseStage && currentstage == 1 && GreetedMalePartner == false && !ASLCurrentlyintense
		ASLMakeGreetingToMalePartner()
		GreetedMalePartner = true
	endif

	If Utility.RandomFloat(0.0, 1.0) < ChanceToCommentononAttackingStage ; femdom comments
		if Utility.RandomInt(1,2) == 1
			PlaySound("OnTheAttack", mainFemaleActor, requiredChemistry = 0 , debugtext = "OnTheAttack")
		else
			PlaySound("Amused", mainFemaleActor, requiredChemistry = 0 , debugtext = "Amused")
		endif
	elseif ishugepp && Utility.RandomFloat(0.0, 1.0)  < ChanceToCommentonNonIntenseStage && !ASLcurrentlyIntense
		PlaySound("InAwe", mainFemaleActor, requiredChemistry = 1 , debugtext = "InAwe")
	elseif Utility.RandomFloat(0.0, 1.0)  < ChanceToCommentonNonIntenseStage && !ASLcurrentlyIntense
		if Utility.randomint(1,2) == 1
			PossiblyAskForCumInSpecificLocation()
		else
			PlaySound("PenetrativeCommentsSoft", mainFemaleActor, requiredChemistry = 0 , debugtext = "PenetrativeCommentssoft")
		endif
	elseif Utility.RandomFloat(0.0, 1.0)  < ChanceToCommentonIntenseStage && ASLcurrentlyIntense
		PlaySound("PenetrativeCommentsIntense", mainFemaleActor, requiredChemistry = 0 , debugtext = "PenetrativeCommentsIntense")
	else
		if ASLcurrentlyintense
			PlaySound("NearOrgasmNoises", mainFemaleActor, requiredChemistry = 0 , debugtext = "NearOrgasmNoises")
		else
			PlaySound("PenetrativeGrunts", mainFemaleActor, requiredChemistry = 0 , debugtext = "PenetrativeGrunts")
		endif
	EndIf

endif

EndFunction


Function PlayCowgirlVarB()

printdebug("Play Cowgirl VarB")

if CommentedClosetoOrgasm
	PlayMoanonlyVarB()
else

	If !ASLCurrentlyintense && Utility.RandomFloat(0.0, 1.0) < ChanceToCommentononAttackingStage ; femdom comments
		;amused
		PlaySound("Amused", mainFemaleActor, requiredChemistry = 0 , debugtext = "Amused")
	endif

	If Utility.RandomFloat(0.0, 1.0) < ChanceToCommentononAttackingStage ; femdom comments
		if ASLCurrentlyintense
			;Penetrated Comments Femdom Intense
			PlaySound("SensitivePleasure", mainFemaleActor, requiredChemistry = 0 , debugtext = "Penetrated Comments Femdom Intense")
		else
			;Penetrated Comments Femdom
			PlaySound("PenetrativeCommentsIntense", mainFemaleActor, requiredChemistry = 0 , debugtext = "Penetrated Comments Femdom")
		endif
	else
		PlayMoanonlyVarB()
	EndIf

endif

EndFunction


Function PlayGettingFuckedbyHugePP() ; when on huge pp scenario
printdebug("Play Getting Fucked by Huge PP")

if CommentedClosetoOrgasm
	PlaySound("SensitivePleasure", mainFemaleActor, requiredChemistry = 0 , debugtext = "SensitivePleasure")
else
	if IsGettingDoublePenetrated()

		PlaySound("SensitivePleasure", mainFemaleActor, requiredChemistry = 0 , debugtext = "SensitivePleasure")

	elseif ASLCurrentlyintense
		if IsGettingAnallyPenetrated() && utility.RandomFloat(0.0, 1.0) < chancetocommentonintensestage
			PlaySound("IntenseAnal", mainFemaleActor, requiredChemistry = 0 , debugtext = "IntenseAnal")
		elseif Utility.RandomFloat(0.0, 1.0) < chancetocommentonintensestage
			PlaySound("TeaseAggressivePartner", mainFemaleActor, requiredChemistry = 0)
		else
			PlaySound("SensitivePleasure", mainFemaleActor, requiredChemistry = 0 , debugtext = "SensitivePleasure")
		endif
	else

		; breath and gape breath and gape. ASL SA FA reserved for large pp creature piston cycle time > 2 seconds
		if Utility.RandomFloat(0.0, 1.0) < 0.5
			PlayBreathyorforeplaysound()
		else
			PlaySound("PenetrativeGrunts", mainFemaleActor, requiredChemistry = 0 , debugtext = "PenetrativeGrunts")
		endif

		if Utility.RandomFloat(0.0, 1.0) < 0.2
			Utility.Wait(Utility.RandomFloat(1.0, 2.0))

			PlaySound("Oh", mainFemaleActor, requiredChemistry = 0 ,soundPriority = 2 , debugtext = "Oh")
			Utility.Wait(1.0)

			PlaySound("AfterGape", mainFemaleActor, requiredChemistry = 0 , soundPriority = 2 , debugtext = "AfterGape")
		endif
	endif
endif

EndFunction

Function PlayGettingFuckedbyHugePPVarB() ; when on huge pp scenario
printdebug("Play Getting Fucked by Huge PP Var B")

if CommentedClosetoOrgasm
	PlayMoanonlyVarB()
else
	if IsGettingDoublePenetrated()
		;Penetrated Comments Over The Top
		PlaySound("TeaseAggressivePartner", mainFemaleActor, requiredChemistry = 0 , debugtext = "Penetrated Comments Over The Top")

	elseif ASLCurrentlyintense && utility.RandomFloat(0.0, 1.0) < chancetocommentonintensestage
		if IsGettingAnallyPenetrated() && utility.RandomFloat(0.0, 1.0) < chancetocommentonintensestage
			;Penetrated Anal Comments Intense
			PlaySound("IntenseAnal", mainFemaleActor, requiredChemistry = 0 , debugtext = "Penetrated Anal Comments Intense")
		else
			;Penetrated Comments Over The Top
			PlaySound("TeaseAggressivePartner", mainFemaleActor, requiredChemistry = 0 , debugtext = "Penetrated Comments Over The Top")
		endif
	elseif !ASLCurrentlyintense && utility.RandomFloat(0.0, 1.0) < chancetocommentonnonintensestage
		;Penetrated Comments VIctim
		PlaySound("RefractoryPeriod", mainFemaleActor, requiredChemistry = 0 ,soundPriority = 2 , debugtext = "Penetrated Comments VIctim")

	else
		PlayMoanonlyVarB()
	endif
endif

EndFunction


Function PlayMoanonly()
printdebug("Play Moan only")

if moanonly == 1
	EnableOrgasm()
endif

if ASLCurrentlyintense
	if IsSuckingoffOther()
		PlaySound("BlowjobActionIntense", mainFemaleActor, requiredChemistry = 0 , debugtext = "BlowjobActionIntense")
	elseif IsgettingPenetrated()
		PlaySound("NearOrgasmNoises", mainFemaleActor, requiredChemistry = 0 , debugtext = "NearOrgasmNoises")
	elseif IsGettingStimulated()
		PlaySound("PenetrativeGrunts", mainFemaleActor, requiredChemistry = 0 , debugtext = "PenetrativeGrunts")
	else
		PlayBreathyorforeplaysound()
	endif

else
	if IsSuckingoffOther()
		PlaySound("BlowjobActionSoft", mainFemaleActor, requiredChemistry = 0 , debugtext = "BlowjobActionSoft")
	elseif IsgettingPenetrated()
		PlaySound("PenetrativeGrunts", mainFemaleActor, requiredChemistry = 0 , debugtext = "PenetrativeGrunts")
	elseif isending()
		PlaySound("AfterOrgasmExclamations", mainFemaleActor, requiredChemistry = 0  , debugtext = "AfterOrgasmExclamations")
	else
		PlayBreathyorforeplaysound()
	endif

endif
endfunction

Function PlayMoanonlyVarB()
printdebug("Play Moan only")
if moanonly == 1
	EnableOrgasm()
endif

if ASLCurrentlyintense
	if IsSuckingoffOther()
		;Blowjob Action Intense
		PlaySound("BlowjobActionIntense", mainFemaleActor, requiredChemistry = 0 , debugtext = "Blowjob Action Intense")
	elseif IsgettingPenetrated()
		if IsGettingDoublePenetrated() || ishugepp()
			;Penetrated Grunt Over The Top
			PlaySound("RomanceMaleThane", mainFemaleActor, requiredChemistry = 0 , debugtext = "Penetrated Grunt Over The Top")
		elseif ASLIsBroken()
			;Penetrated Grunt Intense
			PlaySound("NearOrgasmNoises", mainFemaleActor, requiredChemistry = 0 , debugtext = "Penetrated Grunt Intense")
		elseif femaleisvictim()
			;Penetrated Grunt Victim Intense
			PlaySound("CumTogetherTease", mainFemaleActor, requiredChemistry = 0 , debugtext = "Penetrated Grunt Victim Intense")
		else
			;Penetrated Grunt Intense
			PlaySound("NearOrgasmNoises", mainFemaleActor, requiredChemistry = 0 , debugtext = "Penetrated Grunt Intense")
		endif
	elseif IsStimulatingOthers()
		;Breathing
		PlaySound("BreathySoft", mainFemaleActor, requiredChemistry = 0 , soundPriority = 2 , debugtext = "Breathing")
	else
		;Breathing Intense
		PlaySound("BreathyIntense", mainFemaleActor, requiredChemistry = 0 , debugtext = "Breathing Intense")
	endif

else
	if IsSuckingoffOther()
		;Blowjob Action
		PlaySound("BlowjobActionSoft", mainFemaleActor, requiredChemistry = 0 , debugtext = "Blowjob Action")
	elseif IsgettingPenetrated()
		if ishugepp()
			;Penetrated Grunt Victim
			PlaySound("Unamused", mainFemaleActor, requiredChemistry = 0 , debugtext = "Penetrated Grunt Victim")
		elseif ASLIsBroken()
			;Panting
			PlaySound("AfterOrgasmExclamations", mainFemaleActor, requiredChemistry = 0 , debugtext = "Panting")
		elseif femaleisvictim()
			;Penetrated Grunt Victim
			PlaySound("Unamused", mainFemaleActor, requiredChemistry = 0 , debugtext = "Penetrated Grunt Victim")
		else
			;Penetrated Grunt
			PlaySound("PenetrativeGrunts", mainFemaleActor, requiredChemistry = 0 , debugtext = "Penetrated Grunt")
		endif
	elseif isending()
		if CurrentPenetrationLvl() == 1 ;oral
			;Blowjob Action
			PlaySound("BlowjobActionSoft", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "Blowjob Action")
		elseif CurrentPenetrationLvl() >= 2 ;vaginal anal
			if ishugepp()
				;Panting Heavy
				PlaySound("MyTurnToCum", mainFemaleActor, requiredChemistry = 0 , soundPriority = 2 , debugtext = "Panting Heavy")
			else
				;Panting
				PlaySound("AfterOrgasmExclamations", mainFemaleActor, requiredChemistry = 0 , soundPriority = 2 , debugtext = "Panting")
			endif
		elseif femaleRecordedOrgasmCount > 0 ;orgasm due to stimulation before
			;Panting
			PlaySound("AfterOrgasmExclamations", mainFemaleActor, requiredChemistry = 0 , soundPriority = 2 , debugtext = "Panting")
		else ;no penetration no orgasm no stimulation
			;Breathing
			PlaySound("BreathySoft", mainFemaleActor, requiredChemistry = 0 , soundPriority = 2 , debugtext = "Breathing")
		EndIf
	elseif IsGettingStimulated()
		;Breathing Intense
		PlaySound("BreathyIntense", mainFemaleActor, requiredChemistry = 0 , debugtext = "Breathing Intense")
	else
		;Breathing
		PlaySound("BreathySoft", mainFemaleActor, requiredChemistry = 0 , soundPriority = 2 , debugtext = "Breathing")
	endif

endif
endfunction

Function PlayGettingFucked()
printdebug("Play Getting Fucked")

;------------------ INTENSE-------------------
if ASLCurrentlyintense

	if CommentedClosetoOrgasm
		PlaySound("NearOrgasmNoises", mainFemaleActor, requiredChemistry = 0 , debugtext = "NearOrgasmNoises")
	else ;After Handling close to Orgasm
		if FemaleIsVictim() && Utility.RandomFloat(0.0, 1.0) < chancetocommentonintensestage
			PlaySound("TeaseAggressivePartner", mainFemaleActor, requiredChemistry = 0)
		elseIf IsGettingAnallyPenetrated() && Utility.RandomFloat(0.0, 1.0) < chancetocommentonintensestage
			PlaySound("IntenseAnal", mainFemaleActor, requiredChemistry = 0 , debugtext = "IntenseAnal")
		elseIf IsGettingVaginallyPenetrated() && Utility.RandomFloat(0.0, 1.0) < chancetocommentonintensestage
			PlaySound("PenetrativeCommentsIntense", mainFemaleActor, requiredChemistry = 0 , debugtext = "PenetrativeCommentsIntense")
		else
			PlaySound("NearOrgasmNoises", mainFemaleActor, requiredChemistry = 0 , debugtext = "NearOrgasmNoises")
		endif
	EndIf

;------------------ NOT INTENSE-------------------
else
	if CommentedClosetoOrgasm
		PlaySound("PenetrativeGrunts", mainFemaleActor, requiredChemistry = 0 , debugtext = "PenetrativeGrunts")
	else
		;after handling close to orgasm
		If femaleisvictim() && Utility.RandomFloat(0.0, 1.0) < ChanceToCommentUnamused
			PlaySound("Unamused", mainFemaleActor, requiredChemistry = 0 , debugtext = "Unamused")
		elseIf  Utility.RandomFloat(0.0, 1.0) < ChanceToCommentonNonIntenseStage
			PlaySound("PenetrativeCommentsSoft", mainFemaleActor, requiredChemistry = 0 , debugtext = "PenetrativeCommentssoft")
		else
			PlaySound("PenetrativeGrunts", mainFemaleActor, requiredChemistry = 0 , debugtext = "PenetrativeGrunts")
		EndIf

	endif
endif
endfunction


Function PlayGettingFuckedVarB()
printdebug("Play Getting Fucked Var B")

;------------------ INTENSE-------------------
if ASLCurrentlyintense

	if CommentedClosetoOrgasm
		PlayMoanonlyVarB()
	elseif Utility.RandomFloat(0.0, 1.0) < chancetocommentonintensestage
		if FemaleIsVictim()
			;Penetrated Comments Victim Intense
			PlaySound("MissMaleLover", mainFemaleActor, requiredChemistry = 0 , Debugtext = "Penetrated Comments Victim Intense")
		elseIf IsGettingAnallyPenetrated()
			;Penetrated Anal Comments Intense
			PlaySound("IntenseAnal", mainFemaleActor, requiredChemistry = 0 , debugtext = "Penetrated Anal Comments Intense")
		else
			;Penetrated Comments Intense
			PlaySound("LoveyDovey", mainFemaleActor, requiredChemistry = 0 , debugtext = "Penetrated Comments Intense")
		endif
	else
		PlayMoanonlyVarB()
	EndIf

;------------------ NOT INTENSE-------------------
else
	if CommentedClosetoOrgasm
		PlayMoanonlyVarB()
	elseif Utility.RandomFloat(0.0, 1.0) < chancetocommentonnonintensestage
		If femaleisvictim()
			;Penetrated Comments VIctim
			PlaySound("RefractoryPeriod", mainFemaleActor, requiredChemistry = 0 , debugtext = "Penetrated Comments VIctim")
		else
			;Penetrated Comments
			PlaySound("PenetrativeCommentsSoft", mainFemaleActor, requiredChemistry = 0 , debugtext = "Penetrated Comments")
		EndIf
	else
		PlayMoanonlyVarB()
	endif
endif
endfunction

Function PlayGettingFuckedDouble()
printdebug("Play Getting Double Fucked")

if ASLCurrentlyintense


	if CommentedClosetoOrgasm
		PlaySound("NearOrgasmNoises", mainFemaleActor, requiredChemistry = 0 , debugtext = "NearOrgasmNoises")
	else ;After Handling close to Orgasm
		If IsGettingAnallyPenetrated() && Utility.RandomFloat(0.0, 1.0) < chancetocommentonintensestage
			if Utility.Randomint(1,2) == 1
				PlaySound("IntenseAnal", mainFemaleActor, requiredChemistry = 0 , debugtext = "IntenseAnal")
			else
				PlaySound("PenetrativeCommentsIntense", mainFemaleActor, requiredChemistry = 0 , debugtext = "PenetrativeCommentsIntense")
			endif
		else
			if CurrentThread.HasSceneTag("Tentacles")
				PlaySound("NearOrgasmNoises", mainFemaleActor, requiredChemistry = 0 , debugtext = "NearOrgasmNoises")
			else
				PlaySound("SensitivePleasure", mainFemaleActor, requiredChemistry = 0 , debugtext = "SensitivePleasure")
			endif
		endif
	EndIf

	;Not Intense
else
	if CommentedClosetoOrgasm
		PlaySound("PenetrativeGrunts", mainFemaleActor, requiredChemistry = 0 , debugtext = "PenetrativeGrunts")
	else
		;after handling close to orgasm
		If femaleisvictim() && Utility.RandomFloat(0.0, 1.0) < ChanceToCommentUnamused
			PlaySound("Unamused", mainFemaleActor, requiredChemistry = 0 , debugtext = "Unamused")
		elseIf  Utility.RandomFloat(0.0, 1.0) < ChanceToCommentonNonIntenseStage
			PlaySound("TeaseAggressivePartner", mainFemaleActor, requiredChemistry = 0 , debugtext = "TeaseAggressivePartner")
		else
			if CurrentThread.HasSceneTag("Tentacles")
				PlaySound("PenetrativeGrunts", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "PenetrativeGrunts")
			else
				PlaySound("NearOrgasmNoises", mainFemaleActor, requiredChemistry = 0 , debugtext = "NearOrgasmNoises")
			endif
		EndIf
	endif
endif

endfunction


Function PlayGettingFuckedDoubleVarB()
	printdebug("Play Getting Double Fucked Var B")

	if CommentedClosetoOrgasm
		PlayMoanonlyVarB()
	elseif ASLCurrentlyintense && Utility.RandomFloat(0.0, 1.0) < chancetocommentonintensestage
		PlaySound("TeaseAnal", mainFemaleActor, requiredChemistry = 0 , debugtext = "Penetrated Double Comments")
	elseif !ASLCurrentlyintense && Utility.RandomFloat(0.0, 1.0) < chancetocommentonnonintensestage
		PlaySound("TeaseAnal", mainFemaleActor, requiredChemistry = 0 , debugtext = "Penetrated Double Comments")
	else
		PlayMoanonlyVarB()
	EndIf

endfunction


Function PlayEnding()
printdebug("PLay Ending")
;SLO VE: dropped - sr_fillherup thick cum leak chance (cum shaders are not part of SLO VE)
if !isLinearScene()
	EnableOrgasm()
endif

	if AllowMaleVoice()
		if MaleIsVictim()
			PlaySound("TeaseAggressivePartner", mainFemaleActor, soundPriority = 2 , waitForCompletion = False ,debugtext = "TeaseAggressivePartner" , voiceActor = LastOrgasmedMale())
		else
			PlaySound("PostNutRemark", mainFemaleActor, requiredChemistry = 0, soundPriority = 2 , waitForCompletion = false ,debugtext = "PostNutRemark" , voiceActor = LastOrgasmedMale())
			if	CurrentPenetrationLvl() == 1
				PlaySound("BlowjobActionSoft", mainFemaleActor, requiredChemistry = 0 , debugtext = "BlowjobActionSoft")
			else
				PlaySound("AfterOrgasmExclamations", mainFemaleActor, requiredChemistry = 0 ,debugtext = "AfterOrgasmExclamations")
			endif
		endif
	endif

	Utility.Wait(Utility.RandomFloat(1.0, 2.0))
	PlaySound("AfterOrgasmExclamations", mainFemaleActor, requiredChemistry = 0 ,debugtext = "AfterOrgasmExclamations")

	if commentedcumlocation == false && !femaleisvictim()
		commentedcumlocation = true
		PossiblyRemarkOnCumLocation()
	elseif commentedorgasmremark == false  && Utility.RandomFloat(0.0, 1.0) < ChanceToCommentonNonIntenseStage
		If	femaleisvictim() && Utility.RandomFloat(0, 1.0) < ChanceToCommentUnamused * 3
				PlaySound("UnamusedEnd", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 ,debugtext = "UnamusedEnd")
		elseif	femaleRecordedOrgasmCount > Utility.RandomInt(2, 3) && Utility.RandomFloat(0.0, 1.0) < ChanceToCommentonNonIntenseStage
				PlaySound("MadeMeCumSoMuch", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 , debugtext = "MadeMeCumSoMuch")
		else
			PlaySound("AfterOrgasmExclamations", mainFemaleActor, requiredChemistry = 0 ,debugtext = "AfterOrgasmExclamations")
		EndIf
	elseif CurrentThread.HasSceneTag("femdom") && Utility.RandomFloat(0.0, 1.0) < ChanceToCommentononAttackingStage
		PlaySound("Amused", mainFemaleActor, requiredChemistry = 0 ,debugtext = "Amused")
	else
		PlaySound("AfterOrgasmExclamations", mainFemaleActor, requiredChemistry = 0 ,debugtext = "AfterOrgasmExclamations")
	endif

endfunction


Function PlayEndingVarB()
printdebug("PLay Ending Var B")
;SLO VE: dropped - sr_fillherup thick cum leak chance (cum shaders are not part of SLO VE)
if !isLinearScene()
	EnableOrgasm()
endif

	if AllowMaleVoice()
		if MaleIsVictim()
			PlaySound("TeaseAggressivePartner", mainFemaleActor, soundPriority = 2 , waitForCompletion = False ,debugtext = "TeaseAggressivePartner" , voiceActor = LastOrgasmedMale())
		else
			PlaySound("PostNutRemark", mainFemaleActor, requiredChemistry = 0, soundPriority = 2 , waitForCompletion = false ,debugtext = "PostNutRemark" , voiceActor = LastOrgasmedMale())
		endif
		PlayMoanonlyVarB()
	endif

	Utility.Wait(Utility.RandomFloat(1.0, 2.0))

	if Utility.RandomFloat(0.0, 1.0) < ChanceToCommentonNonIntenseStage	&& commentedcumlocation == false
		if ASLisBroken()
			;Ending Broken
			PlaySound("GreetFamiliar", mainFemaleActor, requiredChemistry = 0 , debugtext = "Ending Broken")

		elseif !femaleisvictim()
			PossiblyRemarkOnCumLocationVarB()
		elseif femaleisvictim()
			;Ending Victim Comments
			PlaySound("UnamusedEnd", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 ,debugtext = "Ending Victim Comments")
		endif
	else
		PlayMoanonlyVarB()
	endif
	commentedcumlocation = true
endfunction

function PlayBreathyorforeplaysound()

	if ASLCurrentlyintense
		if Utility.RandomFloat(0.0, 1.0) <= 0.5
			PlaySound("ForeplayIntense", mainFemaleActor, requiredChemistry = 0 , debugtext ="Foreplayintense")
		else
			PlaySound("BreathyIntense", mainFemaleActor, requiredChemistry = 0 , debugtext ="BreathyIntense")
		endif
	else
		if Utility.RandomFloat(0.0, 1.0) <= 0.5
			PlaySound("ForeplaySoft", mainFemaleActor, requiredChemistry = 0 , debugtext ="Foreplaysoft")
		else
			PlaySound("BreathySoft", mainFemaleActor, requiredChemistry = 0 , debugtext ="BreathySoft")
		endif
	endif

endfunction

function ASLPlayMaleClosetoOrgasmComments()
		;Teasing Male Close to Orgasm
		if IsStimulatingOthers() && !IsgettingPenetrated() && !IsGettingStimulated() && (SexLab.getsex(mainMaleActor) == 0 || SexLab.getsex(mainMaleActor) == 2)

			PlaySound("ReadyToGetGoing", mainFemaleActor, requiredChemistry = 0 , debugtext = "ReadyToGetGoing")

		elseif	mainFemaleEnjoyment > femaleorgasmhypeenjoyment && !femaleisvictim() && IsgettingPenetrated()

			PlaySound("CumTogetherTease", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "CumTogetherTease")

		elseif  FemaleIsVictim() && IsgettingPenetrated()

			PlaySound("PullOut", mainFemaleActor, requiredChemistry = 0, soundPriority = 2 , debugtext = "PullOut")
		elseif IsEarlyToCum()	&& !ASLCurrentlyintense && !femaleisvictim() && IsgettingPenetrated()

			PlaySound("MaleCloseAlready", mainFemaleActor, requiredChemistry = 1, soundPriority = 1 , debugtext = "MaleCloseAlready" )
		elseif IsFemdom() && !ASLCurrentlyintense

			PlaySound("MaleCloseNotice", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 , debugtext = "MaleCloseNotice")

		elseif ASLCurrentlyintense  && IsgettingPenetrated()

			PlaySound("TeaseMaleCloseToOrgasmIntense", mainFemaleActor, requiredChemistry = 1 , soundPriority = 1 , debugtext = "TeaseMaleCloseToOrgasmIntense")
		elseif  IsgettingPenetrated()

			PlaySound("TeaseMaleCloseToOrgasmSoft", mainFemaleActor, requiredChemistry = 1 , soundPriority = 1 , debugtext = "TeaseMaleCloseToOrgasmSoft")

		endif

		if Utility.RandomFloat(0.0, 1.0) < chancetocommentwhenmaleclosetoorgasm && !femaleisvictim()
			Utility.Wait(Utility.RandomFloat(1.0, 3.0))
			PossiblyAskForCumInSpecificLocation()
		endif

		teasedClosetoorgasm = true

endfunction

function ASLPlayMaleClosetoOrgasmCommentsVarB()

	if !FemaleIsVictim() && IsStimulatingOthers() && !IsgettingPenetrated() && (SexLab.getsex(mainMaleActor) == 0 || SexLab.getsex(mainMaleActor) == 2)
		if IsGettingStimulated()
			PlaySound("ReadyToGetGoing", mainFemaleActor, requiredChemistry = 0 , debugtext = "Ready To Get Going")
		else
			;Foreplay Tease Orgasm
			PlaySound("WantMore", mainFemaleActor, requiredChemistry = 0 , debugtext = "Foreplay Tease Orgasm")
		endif

	elseif  FemaleIsVictim() && IsgettingPenetrated()
		;Penetrated Tell Male to Pull Out
		PlaySound("PullOut", mainFemaleActor, requiredChemistry = 0, soundPriority = 2 , debugtext = "Penetrated Tell Male to Pull Out")
	elseif IsFemdom() && IsgettingPenetrated()
		;Male Orgasm Soon Femdom
		PlaySound("MaleCloseNotice", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 , debugtext = "Male Orgasm Soon Femdom")
	elseif	!femaleisvictim() && IsgettingPenetrated()
		if Isintense()
			if CurrentPenetrationLvl() == 1
				;Male Orgasm Soon Ask For Oral Cum
				PlaySound("AskForOralCum", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "Male Orgasm Soon Ask For Oral Cum")
			elseif CurrentPenetrationLvl() == 2
				;Male Orgasm Soon Ask For Vaginal Cum Intense
				PlaySound("TeaseMaleCloseToOrgasmSoft", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "Male Orgasm Soon Ask For Vaginal Cum Intense")
			elseif CurrentPenetrationLvl() == 3
				;Male Orgasm Soon Ask for Anal Cum Intense
				PlaySound("TeaseMaleCloseToOrgasmIntense", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "TeaseMaleCloseToOrgasmIntense")
			EndIf
		else
			if CurrentPenetrationLvl() == 1
				;Male Orgasm Soon Ask For Oral Cum
				PlaySound("AskForOralCum", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "Male Orgasm Soon Ask For Oral Cum")
			elseif CurrentPenetrationLvl() == 2
				;Male Orgasm Soon Ask For Vaginal Cum
				PlaySound("AskForVaginalCum", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "Male Orgasm Soon Ask For Vaginal Cum")
			elseif CurrentPenetrationLvl() == 3
				;Male Orgasm Soon Ask For Anal Cum
				PlaySound("AskForAnalCum", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "Male Orgasm Soon Ask For Anal Cum")
			EndIf
		endif
	elseif !femaleisvictim() && IsStimulatingOthers()
		;Foreplay Tease Orgasm
		PlaySound("WantMore", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "Foreplay Tease Orgasm")
	else
		PlayMoanonlyVarB()
	endif
	teasedClosetoorgasm = true

endfunction

Function ASLPlayFemaleOrgasmHype()
;skip commenting orgasm if orgasm in quick succession
if CurrentThread.GetTimeTotal() - timeOfLastRecordedFemaleOrgasm <= 8
	EnableOrgasm()
	CommentedClosetoOrgasm = true

	return
endif

;-----------------------NOT INTENSE------------------

	if !ASLCurrentlyintense
		if IsSuckingoffOther()
			PlaySound("BlowjobRemarks", mainFemaleActor, requiredChemistry = 0 , debugtext = "BlowjobRemarks")
		elseif (IsStimulatingOthers() || IsGettingStimulated()) && !femaleisvictim() && !IsgettingPenetrated()
			PlaySound("ReadyToGetGoing", mainFemaleActor, requiredChemistry = 0 , debugtext = "ReadyToGetGoing")
		elseif maleOrgasmCount > femaleRecordedOrgasmCount && Utility.RandomFloat(0.0, 1.0) < ChanceToCommentWhenCloseToOrgasm && !FemaleIsVictim()
			PlaySound("MyTurnToCum", mainFemaleActor, requiredChemistry = 3 , soundPriority = 1 , debugtext = "MyTurnToCum")
		Elseif Utility.RandomFloat(0.0, 1.0) < ChanceToCommentWhenCloseToOrgasm  && CommentedClosetoOrgasm == false
			PlaySound("NearOrgasmExclamations", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "NearOrgasmExclamations")
		else
			PlaySound("PenetrativeGrunts", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "PenetrativeGrunts")
		endif
;-----------------------INTENSE------------------
	elseif ASLcurrentlyIntense
		if IsSuckingoffOther()
			PlaySound("AppreciatePartner", mainFemaleActor, requiredChemistry = 0 , debugtext = "AppreciatePartner")
		elseIf IshugePP && IsgettingPenetrated() && Utility.RandomFloat(0.0, 1.0) < ChanceToCommentWhenCloseToOrgasm
			PlaySound("SensitivePleasure", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "SensitivePleasure")

		elseif IsgettingPenetrated() || IsGettingStimulated()

			If Utility.RandomFloat(0.0, 1.0) < ChanceToCommentWhenCloseToOrgasm && CommentedClosetoOrgasm == false
			PlaySound("NearOrgasmExclamations", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "NearOrgasmExclamations")
			Else
				PlaySound("NearOrgasmNoises", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "NearOrgasmNoises")
			EndIf
		endif
	endif
EnableOrgasm()
printdebug("Allow Female Orgasm")
CommentedClosetoOrgasm = true

EndFunction


Function ASLPlayFemaleOrgasmHypeVarB()
	If IshugePP && ASLCurrentlyintense || IsGettingDoublePenetrated()
		;Orgasm Soon Comments Intense
		PlaySound("NearOrgasmExclamations", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "Orgasm Soon Comments Intense")
	else
		;Orgasm Soon Comments
		PlaySound("ReadyToResume", mainFemaleActor, requiredChemistry = 0 , debugtext = "Orgasm Soon Comments")
	EndIf
	CommentedClosetoOrgasm = true

EndFunction


function ASLHandlemaleOrgasmreaction()


	if maleOrgasmCount > 1 && !femaleisvictim() && !IsSuckingoffOther() && Utility.RandomFloat(0.0, 1.0) < chancetocommentonnonintensestage
		PlaySound("InAwe", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "InAwe")
	endif

	;a chance to react to male orgasm

	if CurrentPenetrationLvl() == 1

		if AllowMaleVoice()
			PlaySound("JokeAfterOrgasm", mainFemaleActor, requiredChemistry = 0 , soundPriority = 2, waitForCompletion = false , debugtext = "JokeAfterOrgasm" , voiceActor = LastOrgasmedMale())
		endif

		PlaySound("CameInMouth", mainFemaleActor, requiredChemistry = 0 , soundPriority = 2 , debugtext = "CameInMouth")

	elseif IsCowgirl() || IsGivingAnalPenetration() || IsGivingVaginalPenetration()

		PlaySound("MaleOrgasmReactionSoft", mainFemaleActor, requiredChemistry = 0, soundPriority = 2 , debugtext = "MaleOrgasmReactionSoft")

	elseIf 	ASLCurrentlyintense && IsgettingPenetrated()

		;Chance for male comments
		if AllowMaleVoice()

			PlaySound("JokeAfterOrgasm", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "JokeAfterOrgasm" , voiceActor = LastOrgasmedMale())
			Utility.Wait(Utility.RandomFloat(0.5, 1.0))
		endif

		if Utility.RandomFloat(0.0, 1.0) < chancetocommentonnonintensestage
			PlaySound("MaleOrgasmReactionIntense", mainFemaleActor, requiredChemistry = 0, soundPriority = 2 , debugtext = "MaleOrgasmReactionIntense")
		endif

	Elseif IsgettingPenetrated()
		if AllowMaleVoice()
			PlaySound("JokeAfterOrgasm", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1,waitForCompletion = False , debugtext = "JokeAfterOrgasm" , voiceActor = LastOrgasmedMale())
			PlaySound("AfterOrgasmExclamations", mainFemaleActor, requiredChemistry = 0 , soundPriority = 2 , debugtext = "AfterOrgasmExclamations")
			Utility.Wait(Utility.RandomFloat(0.5, 2.0))
		endif

		if Utility.RandomFloat(0.0, 1.0) <= 0.4
			if femaleisvictim()

				PlaySound("Unamused", mainFemaleActor, requiredChemistry = 0 , debugtext = "Unamused")
			else

				PlaySound("MaleOrgasmReactionSoft", mainFemaleActor, requiredChemistry = 0, soundPriority = 2)
			endif
		endif
	EndIf


	ReacttoMaleOrgasmNext = false


endfunction


function ASLHandlemaleOrgasmreactionVarB()

	;Chance for male comments
	if AllowMaleVoice() && !MaleIsVictim()
		PlaySound("JokeAfterOrgasm", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "JokeAfterOrgasm" ,waitForCompletion = False , voiceActor = LastOrgasmedMale())
	endif

	;Female Panting First
	PlayMoanonlyVarB()

	Utility.Wait(Utility.RandomFloat(0.5, 2.0))
	if IsSuckingoffOther()
		PlayBlowjobVarB()
	elseif Femaleisvictim() && CurrentPenetrationLvl() > 1
		;Male Orgasmed Inside Victim
		if (!ASLCurrentlyintense && Utility.RandomFloat(0.0, 1.0) < chancetocommentonnonintensestage) || (ASLCurrentlyintense || ishugePP) && Utility.RandomFloat(0.0, 1.0) < chancetocommentonintensestage
			PlaySound("MaleOrgasmReactionSoft", mainFemaleActor, requiredChemistry = 0, soundPriority = 2 , debugtext= "Male Orgasmed Inside Victim")
		endif
	elseif (ASLCurrentlyintense || ishugePP) && Utility.RandomFloat(0.0, 1.0) < chancetocommentonintensestage
		if IsFemdom() && IsgettingPenetrated()
			;Male Orgasmed Inside Femdom
			PlaySound("MaleOrgasmReactionIntense", mainFemaleActor, requiredChemistry = 0, soundPriority = 2 , debugtext = "Male Orgasmed Inside Femdom")
		elseif IsGivingAnalPenetration() || IsGivingVaginalPenetration()
			;Amused
			PlaySound("Amused", mainFemaleActor, requiredChemistry = 0, soundPriority = 2 , debugtext = "Amused")
		elseIf IsgettingPenetrated()
			;Male Orgasmed Inside Intense
			PlaySound("MaleCloseAlready", mainFemaleActor, requiredChemistry = 0, soundPriority = 2 , debugtext = "Male Orgasmed Inside Intense")
		endif

	elseif !ASLCurrentlyintense && Utility.RandomFloat(0.0, 1.0) < chancetocommentonnonintensestage
		if femaleisvictim()
			;Penetrated Comments VIctim
			PlaySound("RefractoryPeriod", mainFemaleActor, requiredChemistry = 0 , debugtext = "Penetrated Comments VIctim")
		else
			;Male Orgasmed Inside
			PlaySound("InsertionAnalSlow", mainFemaleActor, requiredChemistry = 0, soundPriority = 2 , debugtext = "Male Orgasmed Inside")
		endif
	else
		PlayMoanonlyVarB()
	EndIf

	ReacttoMaleOrgasmNext = false

endfunction

Function ASLHandleFemaleOrgasmReaction()

;chance to react after orgasm

if IsSuckingoffOther() ;blowjob always first because muffled by cock

	PlayBlowjob()

elseif VoiceVariation == "A"

	if	ASLIsBroken() && mainMaleActor != None

		PlaySound("AfterOrgasmArouse", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext="AfterOrgasmArouse")

	elseif (IsGivingAnalPenetration() || IsGivingVaginalPenetration() ) && mainMaleActor != None

		PlaySound("Amused", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 , debugtext="Amused")

	elseif ASLCurrentlyintense  && Utility.RandomFloat(0.0, 1.0) < chancetocommentonintensestage && mainMaleActor != None
		if IsCowgirl()
			PlaySound("Amused", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext="Amused")
		else
			PlaySound("AskForPacingBreak", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 , debugtext="AskForPacingBreak")
		endif
	elseif !ASLCurrentlyintense && Utility.RandomFloat(0.0, 1.0) < chancetocommentonnonintensestage && mainMaleActor != None

		PlaySound("AfterOrgasmRemarks", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 , debugtext="AfterOrgasmRemarks")
	else
		PlaySound("AfterOrgasmExclamations", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 , debugtext="AfterOrgasmExclamations")
	endif

else
	if	ASLIsBroken()

		PlaySound("AfterOrgasmArouse", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext="AfterOrgasmArouse")
	elseif IsFemdom() && Utility.RandomFloat(0.0, 1.0) < ChanceToCommentononAttackingStage

		PlaySound("Amused", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 , debugtext="Amused")

	elseif !ASLCurrentlyintense && Utility.RandomFloat(0.0, 1.0) < chancetocommentonnonintensestage

		PlaySound("AfterOrgasmRemarks", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 , debugtext="AfterOrgasmRemarks")

	else
		PlaySound("AfterOrgasmExclamations", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 , debugtext="AfterOrgasmExclamations")
	endif
endif

If mainMaleActor != None && Utility.RandomFloat(0.0, 1.0) < 0.5 && !FemaleIsVictim()  && !ASLCurrentlyintense
	If !FemaleIsSatisfied() && IsgettingPenetrated()
			Utility.Wait(Utility.RandomFloat(1.0, 2.0))

			PlaySound("WantMore", mainFemaleActor, requiredChemistry = 1, soundPriority = 1 , debugtext = "WantMore")
	else

		PlaySound("Satisfied", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 , debugtext = "Satisfied")
	EndIf
EndIf

ReacttoFemaleOrgasmNext = false


endfunction

Function ASLHandleFemaleOrgasmReactionVarB()

	;chance to react after orgasm

	if IsSuckingoffOther() ;blowjob always first because muffled by cock

		PlayBlowjobVarB()

	elseif CurrentPenetrationLvl() >= 2
		if	ASLIsBroken() || ASLCurrentlyintense || isHugePP || timesGaped > 8
			;After Orgasm Comments Intense
			PlaySound("AskForPacingBreak", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext="After Orgasm Comments Intense")
		elseif IsFemdom() && Utility.RandomFloat(0.0, 1.0) < ChanceToCommentononAttackingStage
			;After Orgasm Comments
			PlaySound("AfterOrgasmRemarks", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 , debugtext="After Orgasm Comments")

		elseif !ASLCurrentlyintense && Utility.RandomFloat(0.0, 1.0) < chancetocommentonnonintensestage
			;After Orgasm Comments
			PlaySound("AfterOrgasmRemarks", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 , debugtext="After Orgasm Comments")
		endif
	endif

	ReacttoFemaleOrgasmNext = false


endfunction


Function ASLPlayStageTransition()

if currentStage >= 3
	ShouldInitialize = true
endif

if IsgettingPenetrated()
	timesGaped += 1
endif

	Utility.Wait(Utility.RandomFloat(0.5, 1.0)) ; wait up to 1 second for transition to complete before playing voice

	if isShortenedScene() || moanonly == 1
		if !PreviousStageHasPenetration() && IsgettingPenetrated()
			PlaySound("PullOutGape", mainFemaleActor, requiredChemistry = 0, soundPriority = 2, waitForCompletion = false , debugtext="PullOutGape")
			if ishugepp

				PlaySound("AfterGape", mainFemaleActor, requiredChemistry = 0 , soundPriority = 2 , debugtext = "AfterGape")
			else
				PlaySound("Oh", mainFemaleActor, requiredChemistry = 0 , soundPriority = 2 , debugtext = "Oh")
			endif
			Utility.Wait(Utility.RandomFloat(0.5, 1.0))
		endif
		return
	elseif HasDeviousGag(mainFemaleActor)
		EnableOrgasm()
		if EnableDDGagVoice == 1
			PlayGaggedSound()
		endif
	;male fucking somemore  from ending
	elseif	!IsEnding() && PrevEndingLabel == "ENO" && MainMaleCanControl() && timesGaped > 0

			PlaySound("Oh", mainFemaleActor, requiredChemistry = 0 , soundPriority = 2 , SkipWait = true , debugtext="Oh")
			Utility.Wait(Utility.RandomFloat(0.5, 1.5))
			if voicevariation != "B"
				PlaySound("NoticeMaleWantsMore", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 , debugtext="NoticeMaleWantsMore")
			endif
			if !MainFemaleisBurstingAtSeams()
				ASLRemoveThickCumleak()
			endif

	;-------------Transition from no penetration to penetration----------------------
	elseif !PreviousStageHasPenetration() && IsgettingPenetrated()
		printdebug("Stage Transition - No Penetration to Penetration")
		PlaySound("PullOutGape", mainFemaleActor, requiredChemistry = 0, soundPriority = 2, waitForCompletion = false , debugtext="PullOutGape")

		if ishugepp

			PlaySound("AfterGape", mainFemaleActor, requiredChemistry = 0 , soundPriority = 2 , debugtext = "AfterGape")
		else
			PlaySound("Oh", mainFemaleActor, requiredChemistry = 0 , soundPriority = 2 , debugtext = "Oh")
		endif
		Utility.Wait(Utility.RandomFloat(0.5, 1.0))


		if AllowMaleVoice()
			PlaySound("StrugglingEarly", mainFemaleActor, requiredChemistry = 0, soundPriority = 2, debugtext="StrugglingEarly" , voiceActor = PickSpeakingMale())
		endif

		IF !IsSuckingoffOther() && Utility.RandomFloat(0.0, 1.0) < chancetocommentonnonintensestage
			if IsFemdom() && !ishugepp

				PlaySound("Amused", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 , debugtext="Amused")
			elseif ASLCurrentlyintense || ishugePP

				PlaySound("TeaseAggressivePartner", mainFemaleActor, requiredChemistry = 0 , debugtext="TeaseAggressivePartner")

			elseif femaleisvictim() && Utility.RandomFloat(0.5, 1.0) < 0.5

				PlaySound("Unamused", mainFemaleActor, requiredChemistry = 0 , debugtext="Unamused")
			elseif IsGettingAnallyPenetrated()

				PlaySound("InsertionAnalSlow", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 , debugtext="InsertionAnalSlow")

			else

				PlaySound("InsertionGeneric", mainFemaleActor, requiredChemistry = 0 ,  soundPriority = 1 , debugtext="InsertionGeneric")
			endif

		endif

	;------------maintain Fast Penetration during Transition----------------
	elseif ASLpreviouslyintense && ASLCurrentlyintense
		printdebug(" Stage Transition - Maintain Intensity")

			if AllowMaleVoice()
				PlaySound("Aggressive", mainFemaleActor, soundPriority = 2, debugtext="Aggressive"  , voiceActor = PickSpeakingMale())
			endif

			if  !Femaleisvictim() && !IsSuckingoffOther() && IsgettingPenetrated() && Utility.randomfloat(0.0,1.0) < chancetocommentonintensestage
				PlaySound("InAwe", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext="InAwe" )
			endif
	;------------------Transition from Slow Penetration to Fast Penetration-----------------
	elseif !ASLpreviouslyintense && PreviousStageHasPenetration() && ASLcurrentlyintense && IsgettingPenetrated()

		if AllowMaleVoice()
				PlaySound("StrugglingSubtle", mainFemaleActor, soundPriority = 2 , waitForCompletion = false, debugtext="StrugglingSubtle"  , voiceActor = PickSpeakingMale())

		endif


		if ishugepp || IsGettingDoublePenetrated()

			PlaySound("AfterGape", mainFemaleActor, requiredChemistry = 0 , soundPriority = 2 , debugtext="AfterGape")

		elseif !FemaleIsVictim()

			if Utility.randomfloat(0.0,1.0) < chancetocommentonintensestage
				PlaySound("MaleHalfwayIntense", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext="MaleHalfwayIntense")
			endif
		else

			if AllowMaleVoice()
				PlaySound("Aggressive", mainFemaleActor, soundPriority = 2 , debugtext = "Aggressive" , voiceActor = PickSpeakingMale())
			endif

			IF Utility.randomfloat(0.0,1.0) < chancetocommentonintensestage
			Utility.Wait(Utility.RandomFloat(0.5, 1.5))
				PlaySound("TeaseAggressivePartner", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "TeaseAggressivePartner")
			endif

		endif

;----------------------------if non intense after intense penetrative action--------------
	elseif	ASLpreviouslyintense && !ASLcurrentlyIntense
			printdebug(" Stage Transition - Non Intense to Intense")
				PlaySound("AfterOrgasmExclamations", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 , debugtext = "AfterOrgasmExclamations")

	endif

endfunction


Function ASLPlayStageTransitionVarB()

if currentStage >= 3
	ShouldInitialize = true
endif

if IsgettingPenetrated()
	timesGaped += 1
endif

	Utility.Wait(Utility.RandomFloat(0.5, 1.0)) ; wait up to 1 second for transition to complete before playing voice

	if isShortenedScene() || moanonly == 1
		if !PreviousStageHasPenetration() && IsgettingPenetrated()
			PlaySound("PullOutGape", mainFemaleActor, requiredChemistry = 0, soundPriority = 2, waitForCompletion = false , debugtext="PullOutGape")
			if ishugepp
				;KneeJerk Intense
				PlaySound("AfterGape", mainFemaleActor, requiredChemistry = 0 , soundPriority = 2 , debugtext = "KneeJerk Intense")
			else
				;KneeJerk
				PlaySound("Oh", mainFemaleActor, requiredChemistry = 0 , soundPriority = 2 , debugtext = "KneeJerk")
			endif
			Utility.Wait(Utility.RandomFloat(0.5, 1.0))
		endif
		return
	elseif HasDeviousGag(mainFemaleActor)
		EnableOrgasm()
		if EnableDDGagVoice == 1
			PlayGaggedSound()
		endif
	;male fucking somemore  from ending
	elseif	!IsEnding() && PrevEndingLabel == "ENO" && MainMaleCanControl() && timesGaped > 0

		PlayMoanonlyVarB()

		if !MainFemaleisBurstingAtSeams()
			ASLRemoveThickCumleak()
		endif

	;-------------Transition from no penetration to penetration----------------------
	elseif !PreviousStageHasPenetration() && IsgettingPenetrated()
		printdebug("Stage Transition - No Penetration to Penetration")
		PlaySound("PullOutGape", mainFemaleActor, requiredChemistry = 0, soundPriority = 2, waitForCompletion = false , debugtext="PullOutGape")

		if ishugepp
			;KneeJerk Intense
			PlaySound("AfterGape", mainFemaleActor, requiredChemistry = 0 , soundPriority = 2 , debugtext = "KneeJerk Intense")
		else
			;KneeJerk
			PlaySound("Oh", mainFemaleActor, requiredChemistry = 0 , soundPriority = 2 , debugtext = "KneeJerk")
		endif

		if AllowMaleVoice()
			PlaySound("StrugglingEarly", mainFemaleActor, requiredChemistry = 0, soundPriority = 2, debugtext="StrugglingEarly" , voiceActor = PickSpeakingMale())
		endif

		IF !IsSuckingoffOther() && Utility.RandomFloat(0.0, 1.0) < chancetocommentonnonintensestage
			if ASLisBroken()
				PlayBrokenVarB(true)
			elseif IsFemdom() && !ishugepp
				;Amused
				PlaySound("Amused", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 , debugtext="Amused")
			elseif ishugePP
				;Insertion Over The Top
				PlaySound("InsertionAnalExcited", mainFemaleActor, requiredChemistry = 0 , debugtext="Insertion Over The Top")

			elseif femaleisvictim()
				;Penetrated Comments VIctim
				PlaySound("RefractoryPeriod", mainFemaleActor, requiredChemistry = 0 , debugtext="Penetrated Comments VIctim")
			endif
		else
			PlayMoanonlyVarB()
		endif

	;------------maintain Fast Penetration during Transition----------------
	elseif ASLpreviouslyintense && ASLCurrentlyintense
		printdebug(" Stage Transition - Maintain Intensity")

		PlayMoanonlyVarB()
	;------------------Transition from Slow Penetration to Fast Penetration-----------------
	elseif !ASLpreviouslyintense && PreviousStageHasPenetration() && ASLcurrentlyintense && IsgettingPenetrated()

		if AllowMaleVoice()
			PlaySound("StrugglingSubtle", mainFemaleActor, soundPriority = 2 , waitForCompletion = false, debugtext="StrugglingSubtle"  , voiceActor = PickSpeakingMale())
		endif

		if ishugepp || IsGettingDoublePenetrated()

			;KneeJerk Intense
			PlaySound("AfterGape", mainFemaleActor, requiredChemistry = 0 , soundPriority = 2 , debugtext = "KneeJerk Intense")
		endif

		if !IsSuckingoffOther() && Utility.RandomFloat(0.0, 1.0) < chancetocommentonintensestage

			if AllowMaleVoice()
				PlaySound("Aggressive", mainFemaleActor, soundPriority = 2 ,waitForCompletion = false, debugtext = "Aggressive" , voiceActor = PickSpeakingMale())
				PlayMoanonlyVarB()
			endif

			if ASLisBroken()
				PlayBrokenVarB(true)
			elseif !FemaleIsVictim()
				;Intense Transition Comments
				PlaySound("MaleHalfwayIntense", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext="Intense Transition Comments")
			else

				IF Utility.randomfloat(0.0,1.0) < chancetocommentonintensestage
					Utility.Wait(Utility.RandomFloat(0.5, 1.5))
					;Penetrated Comments Victim Intense
					PlaySound("MissMaleLover", mainFemaleActor, requiredChemistry = 0 , soundPriority = 1 , debugtext = "Penetrated Comments Victim Intense")
				endif
			endif
		endif

;----------------------------if non intense after intense penetrative action--------------
	elseif	ASLpreviouslyintense && !ASLcurrentlyIntense
		printdebug(" Stage Transition - Non Intense to Intense")
		;Panting Heavy
		PlaySound("MyTurnToCum", mainFemaleActor, requiredChemistry = 0, soundPriority = 1 , debugtext = "Panting Heavy")

	endif

endfunction

Function ASLMakeGreetingToMalePartner()

	 Bool partnerLoaded = mainMaleEnjoyment > 50

	If hoursSinceLastSex < 5.0
		Return
	EndIf

	if partnerLoaded
		PlaySound("GreetLoadedFamiliar", mainFemaleActor, requiredChemistry = 4 , debugtext = "GreetLoadedFamiliar")
	elseif withMaleLover
		PlaySound("GreetLover", mainFemaleActor, requiredChemistry = 6 , debugtext = "GreetLover")
	else
		PlaySound("GreetFamiliar", mainFemaleActor, requiredChemistry = 4 , debugtext = "GreetFamiliar")
	endif

EndFunction

Function ASLAddOrgasmSSquirt()
	;SLO VE: dropped - sr_fillherup squirt armor (cum shaders are not part of SLO VE)
endfunction

Function ASLRemoveOrgasmSSquirt()
	;SLO VE: dropped - sr_fillherup squirt armor (cum shaders are not part of SLO VE)
endfunction

Function ASLAddThickCumleak()
	;SLO VE: dropped - sr_fillherup thick cum leak armor (cum shaders are not part of SLO VE)
endfunction

Function ASLRemoveThickCumleak()
	;SLO VE: dropped - sr_fillherup thick cum leak armor (cum shaders are not part of SLO VE)
endfunction

Function ASLAddCumPool()
	;SLO VE: dropped - sr_fillherup cum pool armor (cum shaders are not part of SLO VE)
endfunction

Function ASLRemoveCumPool()
	;SLO VE: dropped - sr_fillherup cum pool armor (cum shaders are not part of SLO VE)
endfunction

bool function ASLIsBroken()
	return false ;SLO VE: dropped - HentairimResistance broken status (resistance module is not part of SLO VE)
endfunction

Bool SomeoneNeedstoOrgasm = false

Function ProcessReadytoAdvanceStage()
	;SLO VE: dropped - stage-advance handshake (the director has no stage control);
	;kept as a no-op so the OnUpdate flow stays verbatim
	SomeoneNeedstoOrgasm = false
endfunction

Bool Function MainFemaleisBurstingAtSeams()
	return false ;SLO VE: dropped - sr_fillherup inflation check
endfunction

Bool function femaleCloseToOrgasm()

	;SLO VE: linear-scene arms folded away; victim gate kept (was VictimPCCanOrgasm()=true && Femaleisvictim())
	if !CommentedClosetoOrgasm || Femaleisvictim()
		return false
	endif
	return mainFemaleEnjoyment >= FemaleOrgasmHypeEnjoyment

endfunction

Bool function HasSchlong(Actor char)
  if !char
    return false
  endif
  if sexlab.GetGender(char) > 1 ;creature - the TNG branch below returns true for anything not GetSex()==1, which included dogs
    return false
  endif
  if (schlongfaction)
    return char.isinfaction(schlongfaction)
  elseif (TNG_Gentlewoman)
    if SexLab.GetSex(char) == 1 && !char.HasKeyword(TNG_Gentlewoman)
      return false ; Female
    else
      return true ; Male or Futa
    endif
  else
    return SexLab.GetSex(char) == 0
  endif
endfunction

Bool Function HasDeviousGag(Actor char)
	return MasterScript.IsWearingGag(char)
endfunction

Bool Function AllowMaleVoice()

	return  Utility.RandomFloat(0.0, 1.0) <= ChanceForMaleToComment && EnableMaleVoice == 1 && Gender == 0 && mainMaleIsVoiced ;gender must be male only; fallback partners (creatures) have no human voice

endfunction

Int Function CurrentPenetrationLvl()

		if Primarystagelabel == "LDI" || IsStimulatingOthers()
			return 0
		elseif IsGettingAnallyPenetrated()  ||  IsGivingAnalPenetration()
			return 3
		elseif IsGettingVaginallyPenetrated() || IsGivingVaginalPenetration()
			return 2
		elseif IsSuckingoffOther() || IsGettingSuckedoff()
			return 1
		elseif IsEnding() && (PreviouslyIsSuckingoffOther())
			return 1
		elseif IsEnding() && PreviouslyIsGettingAnallyPenetrated()
			return 3
		elseif IsEnding() && PreviouslyIsGettingVaginallyPenetrated()
			return 2
		else
			return 0
		endif


EndFunction

Bool Function IsUnconcious()
	if	sexlab.getsex(mainMaleActor) > 2
		return false
	elseif (CurrentThread.HasSceneTag("faint") || CurrentThread.HasSceneTag("sleep") || CurrentThread.HasSceneTag("necro") || CurrentThread.HasSceneTag("unconscious"))
		EnableOrgasm()
		Return true
	else
		return false
	endif
endfunction


Bool Function MainMaleCanControl()
	;cowgirl femdom and non forced blowjob -> false
	if (CurrentThread.HasSceneTag("Cowgirl") || CurrentThread.HasSceneTag("femdom") || CurrentThread.HasSceneTag("Amazon") || (IsSuckingoffOther() && !CurrentThread.HasSceneTag("Forced")))  && ActorsInPlay[0] == mainFemaleActor

		return false
	else
		return true
	endif
endfunction

Bool Function Isintense()
		return ASLCurrentlyintense
endfunction

Bool Function IsEnding()
	return EndingLabel == "ENI" || EndingLabel == "ENO"
endfunction

Bool Function IsGivingAnalPenetration()
	return PenisActionLabel == "FDA" || PenisActionLabel == "SDA"
endfunction

Bool Function IsGivingVaginalPenetration()
	return PenisActionLabel =="FDV" || PenisActionLabel == "SDV"
endfunction

Bool Function PreviouslyIsGivingVaginalPenetration()
	return PrevPenisActionLabel =="FDV" || PrevPenisActionLabel == "SDV"
endfunction

Bool Function PreviouslyIsGivingAnalPenetration()
	return PrevPenisActionLabel =="FDA" || PrevPenisActionLabel == "SDA"
endfunction

Bool Function IsgettingPenetrated()
	return IsGettingAnallyPenetrated() || IsGettingVaginallyPenetrated()
endfunction

Bool Function PreviouslyIsgettingPenetrated()
	return PreviouslyIsGettingAnallyPenetrated() || PreviouslyIsGettingVaginallyPenetrated()
endfunction

Bool Function IsGettingDoublePenetrated()

return PenetrationLabel == "SDP" || PenetrationLabel == "FDP"
endfunction

Bool Function IsGettingVaginallyPenetrated()
	return PenetrationLabel == "SVP" || PenetrationLabel == "FVP" || PenetrationLabel == "SCG" || PenetrationLabel == "FCG" || PenetrationLabel == "SDP" || PenetrationLabel == "FDP"
endfunction

Bool Function PreviouslyIsGettingVaginallyPenetrated()
	return PrevPenetrationLabel == "SVP" || PrevPenetrationLabel == "FVP" || PrevPenetrationLabel == "SCG" || PrevPenetrationLabel == "FCG" || PrevPenetrationLabel == "SDP" || PrevPenetrationLabel == "FDP"
endfunction

Bool Function PreviouslyIsFemdom()
	return PrevPenetrationLabel == "SCG" || PrevPenetrationLabel == "FCG"
endfunction

Bool Function IsGettingAnallyPenetrated()
	return PenetrationLabel == "SAP" || PenetrationLabel == "FAP"  || PenetrationLabel == "SAC" || PenetrationLabel == "FAC" || PenetrationLabel == "SDP" || PenetrationLabel == "FDP"
endfunction

Bool Function PreviouslyIsGettingAnallyPenetrated()
	return PrevPenetrationLabel == "SAP" || PrevPenetrationLabel == "FAP"  || PrevPenetrationLabel == "SAC" || PrevPenetrationLabel == "FAC" || PrevPenetrationLabel == "SDP" || PrevPenetrationLabel == "FDP"
endfunction

Bool Function IsGettingInsertedBig()
	return Stimulationlabel == "BST"
endfunction

Bool Function IsGettingSuckedoff()
	return PenisActionLabel == "SMF" ||  PenisActionLabel == "FMF"
endfunction

Bool Function IsGettingStimulated()
	return Stimulationlabel == "SST" ||  Stimulationlabel == "FST"
endfunction

Bool Function IsSuckingoffOther()
	return OralLabel == "SBJ" ||  OralLabel == "FBJ"
endfunction

Bool Function PreviouslyIsSuckingoffOther()
	return PrevOralLabel == "SBJ" ||  PrevOralLabel == "FBJ"
endfunction

Bool Function IsCowgirl()
	return (PenetrationLabel == "SCG" ||  PenetrationLabel == "FCG" ||  PenetrationLabel == "SAC" ||  PenetrationLabel == "FAC") && !femaleisvictim()
endfunction

Bool Function PreviouslyIsCowgirl()
	return (PrevPenetrationLabel == "SCG" ||  PrevPenetrationLabel == "FCG" ||  PrevPenetrationLabel == "SAC" ||  PrevPenetrationLabel == "FAC")&& !femaleisvictim()
endfunction

Bool Function IsKissing()
	return OralLabel == "KIS"
endfunction

;for Femdom or penetrating others
Bool Function IsFemdom()

	if	femaleisvictim()
		return false
	elseif  CurrentThread.HasSceneTag("Femdom") ||  (PCPosition == 0 && CurrentThread.HasSceneTag("Cowgirl") &&  CurrentThread.HasSceneTag("Forced"))
		return TRUE
	elseif IsGivingAnalPenetration() || IsGivingOthersIntenseStimulation || IsGivingVaginalPenetration()
		return TRUE
	else
		return false
	endif
EndFunction


Bool Function IsCunnilingus()
	return OralLabel == "CUN"
endfunction

Bool Function PreviousStageHasPenetration()
	return PreviouslyIsGettingAnallyPenetrated() || PreviouslyIsGettingVaginallyPenetrated()
endfunction

Bool Function IsStimulatingOthers()

 return isTitfuckOthers || isHandjobOthers || IsFootjobOthers || IsCunnilingus()

endfunction

Function PrintDebug(string Contents = "")
if EnablePrintDebug == 1
	miscutil.printconsole("SLO VE Voice : " + Contents)
endif
endfunction

String Stimulationlabel
String PenisActionLabel
string OralLabel
string EndingLabel
string PenetrationLabel
String PrevStimulationlabel
String PrevPenisActionLabel
string PrevOralLabel
string PrevEndingLabel
string PrevPenetrationLabel
string Labelsconcat
Bool isTitfuckOthers = false
Bool isHandjobOthers = false
Bool IsFootjobOthers = false
Bool IsGivingOthersIntenseStimulation = false

Float  DirectorLastLabelTime


Function UpdateLabels(string anim , int stage , int actorpos = 0 )

 PrevStimulationlabel = Stimulationlabel
 PrevPenisActionLabel = PenisActionLabel
 PrevOralLabel = OralLabel
 PrevEndingLabel = EndingLabel
 PrevPenetrationLabel = PenetrationLabel

 ;SLO VE: dropped - SFXTag lookup (SFX module is v2)

 Stimulationlabel = MasterScript.GetStimulationlabel(mainFemaleActor)
 PenisActionLabel  = MasterScript.GetPenisActionLabel(mainFemaleActor)
 OralLabel  = MasterScript.GetOralLabel(mainFemaleActor)
 EndingLabel  = MasterScript.GetEndingLabel(mainFemaleActor)
 PenetrationLabel = MasterScript.GetPenetrationLabel(mainFemaleActor)

 Labelsconcat = "1" +Stimulationlabel + "1" + PenisActionLabel + "1" + OralLabel + "1" + PenetrationLabel + "1" + EndingLabel

 PrintDebug("Stimulationlabel :" + Stimulationlabel + ", PenisActionLabel :" +  PenisActionLabel  + ", OralLabel :" +  OralLabel  + ", PenetrationLabel :" +  PenetrationLabel  + ", EndingLabel :" +  EndingLabel)
 PrintDebug("PrevStimulationlabel :" + PrevStimulationlabel + ", PrevPenisActionLabel :" +  PrevPenisActionLabel  + ", PrevOralLabel :" +  PrevOralLabel  + ", PrevPenetrationLabel :" +  PrevPenetrationLabel  + ", PrevEndingLabel :" +  PrevEndingLabel)

;find NPC getting tit fucked
int counter = 0
string Result
 isTitfuckOthers = false
 isHandjobOthers = false
 IsFootjobOthers = false
 IsGivingOthersIntenseStimulation = false

while counter < ActorsInPlay.length && PCPosition == 0
	if counter != Actorpos ;ignore PC position
		Result = SLOVE_Hentairim_Tags.PenisActionLabel(anim , stage , counter)

		if Result == "STF"
			isTitfuckOthers = true
			printdebug("isTitfuckOthers TRUE")
		elseif Result == "FTF"
			isTitfuckOthers = true
			IsGivingOthersIntenseStimulation = true
			printdebug("isTitfuckOthers TRUE")
			printdebug("IsGivingOthersIntenseStimulation TRUE")
		elseif Result == "SHJ"
			isHandjobOthers = true
			printdebug("isHandjobOthers TRUE")
			printdebug("IsGivingOthersIntenseStimulation TRUE")
		elseif Result == "FHJ"
			isHandjobOthers = true
			IsGivingOthersIntenseStimulation = true

			printdebug("isHandjobOthers TRUE")
			printdebug("IsGivingOthersIntenseStimulation TRUE")
		elseif Result == "SFJ"
			IsFootjobOthers = true
			printdebug("IsFootjobOthers TRUE")
		elseif Result == "FFJ"
			IsFootjobOthers = true
			IsGivingOthersIntenseStimulation = true
			printdebug("IsFootjobOthers TRUE")
			printdebug("IsGivingOthersIntenseStimulation TRUE")
		endif
	endif
	counter += 1
endwhile

endfunction

float function NextUpdateInterval()

if ASLcurrentlyIntense
	return Utility.RandomFloat(0.1, 1.0)
else
	return Utility.RandomFloat(1.0, 2.0)
endif

endfunction

Function PlayGaggedSound()

;intense gag noise
if ASLCurrentlyintense
	PlaySound("AssFlattering", mainFemaleActor, requiredChemistry =0 , debugtext = "AssFlattering")
else; less intense gag noises
	PlaySound("AssToMouth", mainFemaleActor, requiredChemistry = 0, debugtext = "AssToMouth")
endif

endfunction

Function ChangeHentaiExpression(String Scenario)
;voices-to-expressions sync: SLOVE_Expressions reads this key every pass
StorageUtil.SetStringValue(None, "HentaiScenario" ,Scenario)

EndFunction

Function ChangePCExpressions(String debugtext = "")
if debugtext =="Oh" || debugtext =="KneeJerk" || (debugtext == "DefaultMaleOrgasm" && !ishugePP)
	ChangeHentaiExpression("kneejerk")
elseif debugtext =="SurprisedByMaleOrgasm" || debugtext =="AfterGape" || debugtext =="KneeJerk Intense" || (debugtext =="DefaultMaleOrgasm" && ishugePP)
	ChangeHentaiExpression("hugeppgape")
elseif debugtext == "InsertionAnalSlow" || debugtext == "InsertionGeneric" || debugtext == "Insertion Vaginal Comments" || debugtext == "Insertion Anal Comments"
	ChangeHentaiExpression("initialinsertioncomments")
elseif debugtext == "WantMore" || debugtext == "AskForAnalCum" || debugtext == "AskForVaginalCum" || debugtext == "AskForOralCum" || debugtext == "Ending Broken" || debugtext == "Broken Begging" || debugtext == "Male Orgasm Soon Ask For Oral Cum" || debugtext == "Male Orgasm Soon Femdom"
	ChangeHentaiExpression("wantmore")
elseif debugtext =="FemaleOrgasm"
	ChangeHentaiExpression("orgasm")
elseif debugtext =="MaleOrgasmReactionSoft" || debugtext =="Penetrated Anal Comments" || debugtext =="Penetrated Comments" || debugtext =="Penetrated Broken Comments"
	ChangeHentaiExpression("penetrationcomments")
elseif debugtext =="MaleOrgasmReactionIntense"  || debugtext =="MaleHalfwayIntense" || debugtext =="Penetrated Anal Comments Intense" || debugtext =="Penetrated Comments Intense" || debugtext =="Penetrated Broken Comments Intense"
	ChangeHentaiExpression("intensepenetrationcomments")
elseif debugtext == "Amused" || debugtext == "Foreplay Tease Orgasm" ||  debugtext == "Male Orgasmed Inside Femdom"
	ChangeHentaiExpression("Amused")
elseif debugtext == "Ending Orgasmed Inside Pussy" || debugtext == "Ending Orgasmed Inside Mouth" || debugtext == "After Orgasm Comments" || debugtext == "Ending Orgasmed Inside Ass"
	ChangeHentaiExpression("Ending")
elseif debugtext == "PenetrativeCommentsIntense" || debugtext == "AskForPacingBreak" || debugtext == "TeaseAggressivePartner" || debugtext == "IntenseAnal" || debugtext == "Intense Transition Comments"
	ChangeHentaiExpression("intensepenetrationcomments")
elseif debugtext == "Foreplay Handjob Comments" || debugtext == "Foreplay Footjob Comments" || debugtext == "Foreplay BoobJob Comments" || debugtext == "GreetLoadedFamiliar" || debugtext == "GreetFamiliar" || debugtext == "GreetLover"
	ChangeHentaiExpression("Greeting")
elseif debugtext == "CameInAss" || debugtext == "CameInPussy" || debugtext == "CameInMouth"
	ChangeHentaiExpression("penetrationcomments")
elseif debugtext == "PenetrativeCommentssoft" || debugtext == "Male Orgasmed Inside Mouth" || debugtext == "Stimulated Comments"
	ChangeHentaiExpression("penetrationcomments")
elseif  debugtext == "Stimulated Victim Comments" || debugtext == "Penetrated Comments VIctim" || debugtext == "Male Orgasmed Inside Victim" || debugtext == "Unamused" || (debugtext == "NoticeMaleWantsMore" && femaleisvictim())
	ChangeHentaiExpression("unamused")
elseif debugtext == "UnamusedEnd" || debugtext == "Ending Victim Comments"
	ChangeHentaiExpression("unamusedending")
elseif debugtext == "Male Orgasmed Outside" || debugtext == "Male Orgasmed Inside" || debugtext == "ReadyToGetGoing" || debugtext == "Ready To Get Going" || debugtext == "InAwe" || (debugtext == "NoticeMaleWantsMore" && !femaleisvictim())
	ChangeHentaiExpression("inawe")
elseif debugtext == "Penetrated Grunt Over The Top" || debugtext == "Penetrated Double Comments" || debugtext == "Penetrated Comments Victim Intense" || debugtext == "SensitivePleasure" || debugtext == "AfterOrgasmArouse" || debugtext =="Insertion Over The Top" || debugtext =="Orgasm Over The Top" || debugtext =="Penetrated Comments Over The Top"
	ChangeHentaiExpression("overthetop")
elseif debugtext == "OnTheAttack" || debugtext == "Foreplay Femdom Comments" || debugtext == "Penetrated Comments Femdom" || debugtext == "Penetrated Comments Femdom Intense"
	ChangeHentaiExpression("attackingcomments")
elseif debugtext == "PullOut" || debugtext == "Penetrated Tell Male to Pull Out"
	ChangeHentaiExpression("pullout")
elseif debugtext == "TeaseMaleCloseToOrgasmSoft" || debugtext == "MaleCloseNotice" || debugtext == "MaleCloseAlready" || debugtext == "CumTogetherTease" || debugtext == "Male Orgasm Soon Ask For Anal Cum" || debugtext == "Male Orgasm Soon Ask For Vaginal Cum"
	ChangeHentaiExpression("maleclosetoorgasm")
elseif debugtext == "TeaseMaleCloseToOrgasmIntense" || debugtext == "Male Orgasm Soon Ask for Anal Cum Intense" || debugtext == "Male Orgasm Soon Ask For Vaginal Cum Intense"
	ChangeHentaiExpression("maleclosetoorgasmintense")
elseIf debugtext == "MyTurnToCum" || debugtext == "Orgasm Soon Comments"
	ChangeHentaiExpression("closetoorgasm")
elseif debugtext == "NearOrgasmExclamations" || debugtext =="Orgasm Soon Comments Intense"
	ChangeHentaiExpression("closetoorgasmintense")
elseif (debugtext == "AfterOrgasmRemarks" && ASLcurrentlyintense) || debugtext == "After Orgasm Comments Intense" || debugtext == "Male Orgasmed Inside Intense"
	ChangeHentaiExpression("intenseafterorgasmcomments")
elseif debugtext == "AfterOrgasmRemarks" || debugtext == "Satisfied"
	ChangeHentaiExpression("afterorgasmcomments")
elseif IsFemdom()
	ChangeHentaiExpression("attacking")
elseif debugtext == "PenetrativeGrunts" || debugtext == "Penetrated Grunt" || debugtext == "Penetrated Grunt Victim"
	ChangeHentaiExpression("grunt")
elseif debugtext == "NearOrgasmNoises" || debugtext == "Penetrated Grunt Intense" || debugtext == "Penetrated Grunt Victim Intense"
	ChangeHentaiExpression("intensegrunt")
elseif debugtext == "AfterOrgasmExclamations" || debugtext == "Breathing Intense" || debugtext == "Panting" || debugtext == "Panting Heavy"
	ChangeHentaiExpression("Panting")
elseif IsGettingStimulated() && ASLCurrentlyintense
	ChangeHentaiExpression("grunt")
elseif IsGettingStimulated() || debugtext == "BreathySoft" || debugtext == "Foreplaysoft" || debugtext == "Breathing"
    ChangeHentaiExpression("LeadIn")
else
	if !IsSuckingoffOther() && debugtext != "PullOutGape"
		printdebug(" SLOVE " + debugtext + " Has No Expressions conditions ")
	endif
	ChangeHentaiExpression("")
endif

Endfunction

Bool Function IsfinalStage()
	return currentstage == GetLegacyStagesCount(CurrentThread.GetActiveScene())
endfunction


Bool function isDependencyReady(String modname)
  int index = Game.GetModByName(modname)
  if index == 255 || index == -1
    return false
  else
    return true
  endif
endfunction


bool function isFemaleOrgasming()
	return StorageUtil.Getintvalue(MainFemaleActor ,"Orgasming", 0) == 1
Endfunction

bool Function isShortenedScene()
	return false ;SLO VE: no shortened scenes (Hentairim read a StorageUtil timer modifier)
endfunction

bool Function isLinearScene()
	return false ;SLO VE: no linear scenes
endfunction

Function DisableOrgasm()
	MasterScript.DisableOrgasm(MainfemaleActor)
EndFunction

Function EnableOrgasm()
	if !isLinearScene()
		MasterScript.EnableOrgasm(MainfemaleActor)
	endif
EndFunction


function WritetoErrorlogs(string Header = "Not Specified" ,String contents = "")
	JsonUtil.StringListAdd("ErrorLog.json", Header, " : " + contents, TRUE)
endfunction

int Function GetLegacyStageNum(String asScene, String asStage)
	string[] all_stages = SexlabRegistry.GetAllStages(asScene)
	if SexlabRegistry.StageExists(asScene, asStage)
		int stage_num = all_stages.find(asStage)+1
		return stage_num
	endif
	return 0
EndFunction

int Function GetLegacyStagesCount(String asScene)
	int stages_count = SexlabRegistry.GetAllStages(asScene).Length
	return stages_count
EndFunction
