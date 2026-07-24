Scriptname SLOVE_SFX extends ActiveMagicEffect
{SLO VE body-SFX engine: per-actor magic
 effect that plays slushing / impact / clap / kissing / blowjob body sounds
 through AudioUtil, driven by scene labels, SFX scene tags, and (optionally)
 SLPP node-collision velocity for thrust-synced playback. Settings come from
 SLOVE.toml via SLOVE_Config ("sfx." keys). SLO VE drops the Hentairim
 resistance hooks (victim insertion trauma) and the dead animation-speed
 escalation clauses; everything else stays mechanically identical.}

SexLabFramework Property SexLab Auto ;CK-filled
SLOVE_Director Property MasterScript Auto ;CK-filled

sslThreadController CurrentThread = None
actor playerref
actor actorref
string actorname
bool IsSmallPP
actor[] actorlist
Actor FuckingPartner ;Actor who the person with penis is fucking
Int FuckingPartnerInteractionType
int Gender
string SFXTag
int position
bool StageShouldplayClap = false
bool isplayer
bool isReceiver ; position 0
Bool UpdateNow

Event OnEffectStart(Actor akTarget, Actor akCaster)
	actorref = akTarget
	PrintDebug("Effect Start")
	actorname = actorref.getdisplayname()
	PerformInitialization()

EndEvent

Function PerformInitialization()

	PrintDebug("Perform Initialization")
	playerref = game.getplayer()
	CurrentThread = Sexlab.GetActorController(playerref)
	actorlist = currentthread.Positions
	Gender = sexlab.GetGender(actorref)
	IsPlayer = actorref == playerref
	isReceiver = actorref == actorlist[0]

	;establish positions
	position = currentthread.Positions.Find(actorref)
	IsSmallPP = Masterscript.IsSmallPP(actorref)
	RegisterForTheEventsWeNeed()

	if sexlab == none
		WritetoErrorlogs("SFX", "Sexlab Not Found!")
	endif

	if CurrentThread == none
		WritetoErrorlogs("SFX", "Sexlab Thread Not Found!")
	endif

	PrintDebug("actorlist" + actorlist)

	;Base Hentairim Preparation
	InitializeConfigandForms()
	HentairimPrepare()

	;SFX Initialize
	AudioUtil.SetGroupVolume("sfx", volume)
	printdebug("initialized complete")
	RegisterForSingleUpdate(0.1)
EndFunction

Function RegisterForTheEventsWeNeed()
	printdebug("Registering Event")
	RegisterForModEvent("AnimationEnd", "SFXSceneEnd")

	RegisterForModEvent("SexLabOrgasmSeparate", "SFXOrgasm")

	RegisterForModEvent("StageStart", "SFXOnStageStart")

EndFunction

Event SFXSceneEnd(string eventName, string argString, float argNum, form sender)

EndEvent

Event SFXOnStageStart(string eventName, string argString, float argNum, form sender)
	if CurrentThread == none || argString as Int != currentthread.tid
		return
	EndIf

	position = currentthread.Positions.Find(actorref)
	UpdateNow = true
	printdebug("Stage Start Fire")

EndEvent

String EjacSound = ""
Event SFXOrgasm(Form actorhavingorgasm, Int thread)
	if actorref != actorhavingorgasm as actor
		return
	endif
	if !IsGivingAnalPenetration() && !IsGivingVaginalPenetration() && !IsGettingSuckedoff()
		return
	endif

	if FuckingPartner == Playerref || actorlist[0] == Playerref
		AudioUtil.PlaySFX(EjacSound, Playerref, 1.0, "sfx", "sfx_ejac_" + position)
	endif

EndEvent



Event OnUpdate()

	HentairimUpdateStageData()
	;Ends if player is no longer in scene but magic stuck for some reason
	if Masterscript.AnimationisEnding()
		PrintDebug("Ending Animation. remove SLO VE SFX")
		RemoveSFX()
	endif

	ProcessContactEdges()

	if position > 0

		;set the poll BEFORE the spinner so its internal Utility.wait uses it.
		;Velocity paths poll tight (thrust reversals); the label/tag path polls
		;at normalpoll - it was needlessly churning GetCurrentInteractionFlags at
		;10Hz for a sound whose own clip length already paces it.
		if (IsGivingAnalPenetration() || IsGivingVaginalPenetration() || (EndingLabel != "LDI" && PrevIsGivingAnalOrVaginalPenetration()) ) && useadaptivevelocity == 1 && usevelocity == 1 && !HasCreature() && !isEnding()
			printdebug("Running Adaptive Velocity SFX")
			updateRate = velocitypoll
			RunAdaptiveVelocitySFX()
		elseif (IsGivingAnalPenetration() || IsGivingVaginalPenetration()) && usevelocity == 1 && !HasCreature() && !isEnding() ;only use velocityfx for non creatures scene as no data is available
			printdebug("Running Velocity SFX")
			updateRate = velocitypoll
			CalculateAndPlayVelocitySFX() ;Velocity Based SFX from reversal
		elseif UpdateFuckingPartner() && (IsGivingAnalPenetration() || IsGivingVaginalPenetration()) && usevelocity == 1 && !isEnding()
			printdebug("Running Creature Velocity SFX")
			updateRate = velocitypoll
			CalculateAndPlayVelocitySFX()
		else
			updateRate = normalpoll
			PlaySFX()
		endif
	else
		updateRate = 3
	endif
	RegisterForSingleUpdate(updateRate)

EndEvent

float volume
int enableprintdebug
;Velocity Based Sound Forms
String SmallWetSlush = ""
String SmallWetSlush2 = ""
String SmallFastSlush = ""
String SmallFastSlush2 = ""
String MediumSlush = ""
String FastSlush = ""
String BigSlush = ""
String SmallImpact = ""
String MediumImpact1 = ""
String MediumImpact2 = ""
String MediumImpact3 = ""
String MediumImpact4 = ""
String MediumImpact5Wet = ""
String FastImpact1 = ""
String FastImpact2 = ""
String FastImpact3 = ""

;Sound for random selection
String SmallS = ""
String MediumS = ""
String FastS = ""
String Smalli = ""
String MediumI = ""
String FastI = ""

;Normal SFX Sound Forms
String FastClap = ""
String HeavySlushing = ""
String LightSlushing = ""
String MediumClap = ""
String MediumSlushing = ""
String RapidSlushing = ""
String SlowClap = ""
String Kiss1 = ""
String Kiss2 = ""
String Kiss3 = ""
String Kiss4 = ""
String Kiss5 = ""
String Blowjob1 = ""
String Blowjob2 = ""
String Blowjob3 = ""
String Blowjob4 = ""
String Blowjob5 = ""
String Blowjob6 = ""
String FastBlowjob1 = ""
String FastBlowjob2 = ""
String FastBlowjob3 = ""
String FastBlowjob4 = ""
String FastBlowjob5 = ""

;Normal Sound for random selection

String SlowBlowjob = ""
String FastBlowjob = ""
String Kissing = ""
String SFXtoPlay = ""

String EjacHeavy = ""
String EjacHeavySharp = ""
String EjacHeavyWet = ""
String EjacNormal = ""
String EjacNormalDeep = ""
String EjacSharp = ""
String EjacSmall = ""
String EjacSmallDeep = ""
String GapeAverage = ""
String GapeHuge = ""

int usevelocity
int useadaptivevelocity
int usecontactsfx
int victiminsertiontrauma
int usecontactvictimreactions
int timestosearch
;poll intervals (seconds). velocitypoll drives the thrust-reversal spinners
;(needs to stay tight to catch reversals); normalpoll paces the label/tag-driven
;loop, which is otherwise a needless 10Hz churn of GetCurrentInteractionFlags
float velocitypoll
float normalpoll
;measured-gape thresholds. Per the PPA author, openings are "magic unsigned
;numbers" - 0.0 = closed, larger = more open, no defined scale - and the two
;orifices use different internal scales, so each needs its own pair. The
;defaults are EMPIRICAL starting points: calibrate against the values the
;pull-out printdebug line logs in your own scenes. At or above huge ->
;GapeHuge, at or above average -> GapeAverage, below -> barely stretched,
;no gape sound. Used only when the PPA bridge reports a nonzero opening;
;otherwise the old partner-size guess applies
float gapevaginalaverage
float gapevaginalhuge
float gapeanalaverage
float gapeanalhuge

Bool SearchingFoundVelocity
Function InitializeConfigandForms()
volume = SLOVE_Config.GetInt("sfx.volume", 100) as float / 100
;classic: these three drive the node-collision paths, which do not exist here.
;They are forced off regardless of SLOVE.toml so the poll never switches to the
;velocity rate for data that will never arrive. See docs\classic-sexlab-port.md.
usevelocity = 0
useadaptivevelocity = 0
usecontactsfx = 0
usecontactvictimreactions = SLOVE_Config.GetInt("sfx.usecontactvictimreactions", 1)
victiminsertiontrauma = SLOVE_Config.GetInt("resistance.victiminsertiontrauma", 5)
timestosearch = SLOVE_Config.GetInt("sfx.timestosearch", 0)
velocitypoll = SLOVE_Config.GetFloat("sfx.velocitypoll", 0.1)
normalpoll = SLOVE_Config.GetFloat("sfx.normalpoll", 0.5)
updateRate = velocitypoll
enableprintdebug = SLOVE_Config.GetInt("sfx.printdebug", 0)
gapevaginalaverage = SLOVE_Config.GetFloat("sfx.gapevaginalaverage", 2.0)
gapevaginalhuge = SLOVE_Config.GetFloat("sfx.gapevaginalhuge", 2.7)
gapeanalaverage = SLOVE_Config.GetFloat("sfx.gapeanalaverage", 2.8)
gapeanalhuge = SLOVE_Config.GetFloat("sfx.gapeanalhuge", 4.0)


;Velocity SFX (AudioUtil [sfx] names from the AudioUtil.toml preset)
SmallWetSlush = "SmallWetSlush"
SmallWetSlush2 = "SmallWetSlush2"
SmallFastSlush = "SmallFastSlush"
SmallFastSlush2 = "SmallFastSlush2"
MediumSlush = "MediumSlush"
FastSlush = "FastSlush"
BigSlush = "BigSlush"
SmallImpact = "SmallImpact"
MediumImpact1 = "MediumImpact1"
MediumImpact2 = "MediumImpact2"
MediumImpact3 = "MediumImpact3"
MediumImpact4 = "MediumImpact4"
MediumImpact5Wet = "MediumImpact5Wet"
FastImpact1 = "FastImpact1"
FastImpact2 = "FastImpact2"
FastImpact3 = "FastImpact3"

;Normal
FastClap = "FastClap"
HeavySlushing = "HeavySlushing"
LightSlushing = "LightSlushing"
MediumClap = "MediumClap"
MediumSlushing = "MediumSlushing"
RapidSlushing = "RapidSlushing"
SlowClap = "SlowClap"

Kiss1 = "Kiss1"
Kiss2 = "Kiss2"
Kiss3 = "Kiss3"
Kiss4 = "Kiss4"
Kiss5 = "Kiss5"
Blowjob1 = "Blowjob1"
Blowjob2 = "Blowjob2"
Blowjob3 = "Blowjob3"
Blowjob4 = "Blowjob4"
Blowjob5 = "Blowjob5"
Blowjob6 = "Blowjob6"
FastBlowjob1 = "FastBlowjob1"
FastBlowjob2 = "FastBlowjob2"
FastBlowjob3 = "FastBlowjob3"
FastBlowjob4 = "FastBlowjob4"
FastBlowjob5 = "FastBlowjob5"


EjacHeavy        = "EjacHeavy"
EjacHeavySharp   = "EjacHeavySharp"
EjacHeavyWet     = "EjacHeavyWet"
EjacNormal       = "EjacNormal"
EjacNormalDeep   = "EjacNormalDeep"
EjacSharp        = "EjacSharp"
EjacSmall        = "EjacSmall"
EjacSmallDeep    = "EjacSmallDeep"

GapeAverage      = "GapeAverage"
GapeHuge         = "GapeHuge"


printdebug("volume : " + volume)
endfunction

;-------------------------------Hentairim SFX Functions START---------------------------------

Function RandomizeVariousVelocitySounds()

; initiate small slush
int rand = Utility.randomint(1,2)
if rand == 1
	SmallS = SmallWetSlush
elseif rand == 2
	SmallS = SmallWetSlush2
endif

; initiate Medium slush
MediumS = MediumSlush

; initialize fast slush
rand = Utility.randomint(1,3)
if rand == 1
	FastS = SmallFastSlush
elseif rand == 2
	FastS = SmallFastSlush2
elseif rand == 3
	FastS = FastSlush
endif

;initialize small impact
SmallI = SmallImpact

; initialize medium impact
rand = Utility.randomint(1,5)
if rand == 1
	MediumI = MediumImpact1
elseif rand == 2
	MediumI = MediumImpact2
elseif rand == 3
	MediumI = MediumImpact3
elseif rand == 4
	MediumI = MediumImpact4
elseif rand == 5
	MediumI = MediumImpact5Wet
endif


; initialize Fast impact
rand = Utility.randomint(1,3)
if rand == 1
	FastI = FastImpact1
elseif rand == 2
	FastI = FastImpact2
elseif rand == 3
	FastI = FastImpact3
endif

;initialize Kiss
rand = utility.randomint(1,5)
if rand == 1
	Kissing = Kiss1
elseif rand == 2
	Kissing = Kiss2
elseif rand == 3
	Kissing = Kiss3
elseif rand == 4
	Kissing = Kiss4
elseif rand == 5
	Kissing = Kiss5
endif

;initialize blowjob
rand = utility.randomint(1,6)
if rand == 1
	SlowBlowjob = Blowjob1
elseif rand == 2
	SlowBlowjob = Blowjob2
elseif rand == 3
	SlowBlowjob = Blowjob3
elseif rand == 4
	SlowBlowjob = Blowjob4
elseif rand == 5
	SlowBlowjob = Blowjob5
elseif rand == 6
	SlowBlowjob = Blowjob6
endif

;initialize fast blowjob
rand = utility.randomint(1,5)
if rand == 1
	FastBlowjob = Blowjob1
elseif rand == 2
	FastBlowjob = FastBlowjob2
elseif rand == 3
	FastBlowjob = FastBlowjob3
elseif rand == 4
	FastBlowjob = FastBlowjob4
elseif rand == 5
	FastBlowjob = FastBlowjob5

endif

EndFunction

Function RandomizeEjacSound()
	int rand = Utility.randomint(1,3)
	if IsHugePP
		if rand == 1
			EjacSound = EjacHeavy
		elseif rand == 2
			EjacSound = EjacHeavySharp
		else
			EjacSound = EjacHeavyWet
		Endif
	elseif IsSmallPP
		if Rand == 1
			EjacSound = EjacSmallDeep
		else
			EjacSound = EjacSmall
		Endif
	else
		if rand == 1
			EjacSound = EjacNormal
		elseif rand == 2
			EjacSound = EjacNormalDeep
		else
			EjacSound = EjacSharp
		Endif
	endif

endFunction

String Function GetSlushSoundToPlay(int InteractionType, float TimetoThrust)
    PRINTDEBUG("GetSlushSound | TimetoThrust: " + TimetoThrust + " | InteractionType: " + InteractionType)

	if IshugePP && Utility.randomint(1,3) == 1
		PrintDebug("GetSlushSoundToPlay: Using BigSlush (IshugePP triggered)")
		return BigSlush
	Endif

    if InteractionType == 1 ; vaginal
		PrintDebug("GetSlushSoundToPlay: Vaginal | TimetoThrust=" + TimetoThrust)
		if TimetoThrust <= 0.25
			PrintDebug("GetSlushSoundToPlay: Returning FastS")
            return FastS
        elseif TimetoThrust <= 0.45
			PrintDebug("GetSlushSoundToPlay: Returning MediumS")
            return MediumS
        else
			PrintDebug("GetSlushSoundToPlay: Returning SmallS")
            return SmallS
        endif

    elseif InteractionType == 2 ; anal
		PrintDebug("GetSlushSoundToPlay: Anal | TimetoThrust=" + TimetoThrust)
		if TimetoThrust <= 0.25
			PrintDebug("GetSlushSoundToPlay: Returning MediumS")
            return MediumS
        elseif TimetoThrust <= 0.45
			PrintDebug("GetSlushSoundToPlay: Returning SmallS")
            return SmallS
        else
			PrintDebug("GetSlushSoundToPlay: Returning SmallS")
            return SmallS
        endif

    elseif InteractionType == 3 ; oral (TBD)
		PrintDebug("GetSlushSoundToPlay: Oral | Returning none (no sound yet)")
        return "" ; no sound yet
    endif

	PrintDebug("GetSlushSoundToPlay: Returning none (no valid condition met)")
    return ""
EndFunction


String Function GetImpactSoundToPlay(float TimetoThrust)
    if !StageShouldplayClap
		PrintDebug("GetImpactSoundToPlay: StageShouldplayClap is false, returning none")
        return ""
    endif

    PRINTDEBUG("GetImpactSound | TimetoThrust: " + TimetoThrust)
	if TimetoThrust <= 0.25
		PrintDebug("GetImpactSoundToPlay: Returning FastI")
        return FastI
    elseif TimetoThrust <= 0.45
		PrintDebug("GetImpactSoundToPlay: Returning MediumI")
        return MediumI
    elseif TimetoThrust <= 0.75
		PrintDebug("GetImpactSoundToPlay: Returning SmallI")
        return SmallI
	else
		PrintDebug("GetImpactSoundToPlay: Returning none (no range matched)")
		return ""
    endif
EndFunction

float updateRate = 0.1
float TimeLastReverseIn
Float TimeLastReverseOut
Bool CanPlayReverseIn
;Calculate play sound
;--------------------- classic: physics-driven SFX disabled ---------------------
;Classic SexLab has no node-collision detection, so there is no measured thrust
;velocity, no per-actor interaction flags and no partner-by-interaction-type
;lookup. The functions below are inert stubs on this build. Tag- and timer-driven
;body SFX (PlayFillerSounds / PlaySFX / SFXRefreshSound) are unaffected.
;See docs\classic-sexlab-port.md.

Function CalculateAndPlayVelocitySFX()
	;no velocity data on classic
EndFunction

Bool Function PenisSearchForVelocity()
	;no SOSBend calibration search without collision data to search on
	return false
EndFunction

;script-level state kept from the P+ build. The velocity/contact functions above
;are inert stubs on classic, but these are still read/written by the tag- and
;timer-driven filler SFX (and one retained reset), so they must stay declared.
Bool StopPenisVelocitySearch
Float TimeSinceLastFillerSound
Float FillerTimetoThrustMin
Float FillerTimetoThrustMax
Float FillerIntervals

Function PlayFillerSounds()
	printdebug("PlayFillerSounds: Called | TimeSinceLast=" + TimeSinceLastFillerSound + " | TotalTime=" + currentthread.TotalTime + " | Interval=" + FillerIntervals)

	if currentthread.TotalTime - TimeSinceLastFillerSound >= FillerIntervals
		printdebug("PlayFillerSounds: Interval passed, preparing to play filler sounds")
		String FillerSlushSound = ""
		String FillerImpactSound = ""
		Float TimetoThrust

		TimetoThrust = Utility.randomfloat(FillerTimetoThrustMin,FillerTimetoThrustMax)
		printdebug("PlayFillerSounds: Random TimetoThrust=" + TimetoThrust)

		FillerSlushSound = GetSlushSoundToPlay(1, TimetoThrust)
		printdebug("PlayFillerSounds: Slush sound selected = " + FillerSlushSound)
		if FillerSlushSound
			printdebug("PlayFillerSounds: Playing slush sound on actor " + actorlist[0])
			PlaySound(FillerSlushSound , actorlist[0] , false)
		else
			printdebug("PlayFillerSounds: No valid slush sound found")
		endif

		if StageShouldplayClap
			printdebug("PlayFillerSounds: StageShouldplayClap = TRUE, checking impact sound")
			FillerImpactSound = GetImpactSoundToPlay(TimetoThrust)
			printdebug("PlayFillerSounds: Impact sound selected = " + FillerImpactSound)
			if FillerImpactSound
				printdebug("PlayFillerSounds: Playing impact sound on actor " + actorlist[0])
				PlaySound(FillerImpactSound , actorlist[0] , false)
			else
				printdebug("PlayFillerSounds: No valid impact sound found")
			endif
		else
			printdebug("PlayFillerSounds: StageShouldplayClap = FALSE, skipping impact sound")
		Endif

		TimeSinceLastFillerSound = currentthread.TotalTime
		printdebug("PlayFillerSounds: Updated TimeSinceLastFillerSound = " + TimeSinceLastFillerSound)
	else
		printdebug("PlayFillerSounds: Interval not reached, skipping sound playback")
	endif
EndFunction


Function RunAdaptiveVelocitySFX()
	;no velocity data on classic
EndFunction

Bool Function UpdateFuckingPartner()
	;partner-by-interaction-type is a node-collision feature; unavailable on classic
	return false
EndFunction

Function PlaySFX()
	printdebug("Playing Normal Hentairim SFX")
	while !Masterscript.AnimationisEnding() && DirectorLastLabelTime == MasterScript.GetDirectorLastLabelTime() && DirectorLastPhysicsLabelTime == MasterScript.GetDirectorLastPhysicsLabelTime() && SFXtoPlay
		ProcessContactEdges()
		PlaySound( SFXtoPlay , actorlist[0] , true) ;PlaySFXAndWait - blocks for the clip, so the loop is already paced by clip length
		utility.wait(normalpoll)
	endwhile
EndFunction

;-------------------------------Contact Edge SFX START---------------------------------
;One-shot sounds fired the moment SLPP node collision starts or stops a contact,
;instead of waiting for the next stage/label refresh. Labels and velocity loops
;handle the steady state; this covers the transitions they cannot see.
;SLO VE: the Hentairim victim insertion-trauma deposit (ActorResistanceDebt) is
;dropped - there is no resistance system to consume the debt.
Bool PrevContactPenetrating
Bool PrevContactKissing
Bool PrevContactSucked
Float ContactPenStartTime
Float ContactPenLastSeen
Float ContactKisLastSeen
Float ContactSuckLastSeen
Actor LastPenReceiver

;edge one-shots get their own instance slot: PlaySound()'s channel is the lane
;for the continuous body SFX, and sharing it would cut those off
Function PlayContactSound(String theSound, Actor actorMakingSound)
	;the channel natively stops the previous contact one-shot (per actor, so the
	;effect instances don't cut each other's edges)
	AudioUtil.PlaySFX(theSound, actorMakingSound, 1.0, "sfx", "sfx_contact_" + position)
EndFunction

Function ProcessContactEdges()
	;contact one-shots (insertion, pull-out gape, kiss, oral) are driven by
	;collision edges, which classic cannot provide
EndFunction

Function SFXRefreshSound()
;refreshing

	SFXTag = SLOVE_Hentairim_Tags.GetSFX(CurrentThread.Animation, currentstage)
	printdebug("SFXTag :" + SFXTag )
	;Play from Tags If Any. SLO VE: the Hentairim animation-speed escalation
	;clauses were dead code (each plain tag matched an earlier branch of the
	;same chain) and are dropped with the HentairimAnimSpeed dependency.
	if SFXTag != "None" && SFXTag != ""
		if SFXTag == "SS"
			SFXtoPlay = LightSlushing
		elseif SFXTag == "MS"
			SFXtoPlay = MediumSlushing
			FillerTimetoThrustMin = 0.0
			FillerTimetoThrustMax = 0.4
			FillerIntervals = 0.4
		elseif SFXTag == "FS"
			SFXtoPlay = HeavySlushing
			FillerTimetoThrustMin = 0.0
			FillerTimetoThrustMax = 0.4
			FillerIntervals = 0.4
		elseif SFXTag == "RS"
			SFXtoPlay = RapidSlushing
			FillerTimetoThrustMin = 0.0
			FillerTimetoThrustMax = 0.2
			FillerIntervals = 0.2
		elseif SFXTag == "SC"
			SFXtoPlay = SlowClap
			FillerTimetoThrustMin = 0.0
			FillerTimetoThrustMax = 0.4
			FillerIntervals = 0.6
		elseif SFXTag == "MC"
			SFXtoPlay = MediumClap
			FillerTimetoThrustMin = 0.0
			FillerTimetoThrustMax = 0.4
			FillerIntervals = 0.4
		elseif SFXTag == "FC"
			SFXtoPlay = FastClap
			FillerTimetoThrustMin = 0.0
			FillerTimetoThrustMax = 0.2
			FillerIntervals = 0.15
		elseif SFXTag == "KS"
			SFXtoPlay = Kissing ; KISSING SOUND
		endif

	elseif IsGivingAnalPenetration() || IsGivingVaginalPenetration()
	printdebug("Is giving penetration" )
		if	isintense && ishugepp
			SFXtoPlay = HeavySlushing
			FillerTimetoThrustMin = 0.0
			FillerTimetoThrustMax = 0.2
			FillerIntervals = 0.3
		else
			SFXtoPlay = MediumSlushing
			FillerTimetoThrustMin = 0.0
			FillerTimetoThrustMax = 0.4
			FillerIntervals = 0.4
		endif
	elseif IsGettingSuckedoff()
		if isintense
			SFXtoPlay = FastBlowjob
		else
			SFXtoPlay = SlowBlowjob
		endif
	elseif IsStimulatingOthers()
	printdebug("IsGettingStimulated" )
		if isintense
			SFXtoPlay = MediumSlushing
		else
			SFXtoPlay = LightSlushing
		endif

	elseif IsCunnilingus()
	printdebug("IsCunnilingus" )
		SFXtoPlay = LightSlushing
	elseif IsKissing()
		printdebug("IsKissing" )
		SFXtoPlay = Kissing

	elseif !Shouldplaysound()
		printdebug("Dont play sound" )

		SFXtoPlay = none
	endif

endfunction

Bool Function Shouldplaysound()

return IsCunnilingus() || IsKissing() || IsGivingAnalPenetration() || IsGivingVaginalPenetration() || IsGettingStimulated() || IsGettingSuckedoff()

endfunction


Function RemoveSFX()

spell SFXSpell = Game.GetFormFromFile(0x805, "SLOVE.esp") as spell
actorref.RemoveSpell(SFXSpell)

EndFunction

;-------------------------------Hentairim SFX Functions END---------------------------------

;-----------------------BASE HENTAIRIM Update Functions-----------------------------

Bool IsHugePP
string CurrentSceneID = ""
string currentStageID = ""
Int currentStage = -1
Int ThreadID = -1
bool IsVictim

Function HentairimPrepare()

	ThreadID = currentthread.tid
	IsHugePP = IsHugePP()
	HentairimUpdateStageData()
	RandomizeVariousVelocitySounds()
	RandomizeEjacSound()
	IsVictim = IsVictim(actorref)

endfunction
bool isintense
string PrevPenisActionLabel
Function HentairimUpdateStageData()

	bool stagechanged = DirectorLastLabelTime != MasterScript.GetDirectorLastLabelTime() || UpdateNow
	bool physicschanged = DirectorLastPhysicsLabelTime != MasterScript.GetDirectorLastPhysicsLabelTime()
	if stagechanged || physicschanged
		printdebug("Animation, Stage or Physics Labels Different. Updating Stage Data")

		CurrentSceneID = CurrentThread.Animation as string
		currentStageID = CurrentThread.Stage as string
		currentstage = CurrentThread.Stage

		UpdateLabels(actorref)
		isintense = Isintense()
		if stagechanged
			;only a real stage change may re-arm the SOSBend calibration search;
			;physics label changes would otherwise re-trigger it constantly
			StopPenisVelocitySearch = false
			SearchingFoundVelocity = false
		endif
		if isintense
			CanPlayReverseIn = false
		else
			CanPlayReverseIn = true
		endif

		printdebug("current Animation : " + CurrentSceneID)
		printdebug("current StageID : " + currentStageID)
		printdebug("current stage number: " + currentstage)

		SFXRefreshSound()
		UpdateFuckingPartner()
		StageShouldplayClap = EndingLabel != "ENO" && EndingLabel != "ENI" && (SFXTag == "FC" || SFXTag == "MC" || SFXTag == "SC" || currentthread.HasTag("Doggy") || currentthread.HasTag("DoggyStyle")) && (IsGivingVaginalPenetration() || IsGivingAnalPenetration())

		UpdateNow = false
		DirectorLastLabelTime = MasterScript.GetDirectorLastLabelTime()
		DirectorLastPhysicsLabelTime = MasterScript.GetDirectorLastPhysicsLabelTime()
		PrintDebug("Stage Should play Impact : " + StageShouldplayClap)

	endif


endfunction

String Stimulationlabel
String PenisActionLabel
string OralLabel
string EndingLabel
string PenetrationLabel
string Labelsconcat


float DirectorLastLabelTime
float DirectorLastPhysicsLabelTime
Function UpdateLabels(actor char)
 printdebug("Updating Labels")
 PrevPenisActionLabel = PenisActionLabel
 Stimulationlabel = MasterScript.GetStimulationlabel(char)
 PenisActionLabel = MasterScript.GetPenisActionLabel(char)
 OralLabel = MasterScript.GetOralLabel(char)
 EndingLabel = MasterScript.GetEndingLabel(char)
 PenetrationLabel = MasterScript.GetPenetrationLabel(char)

 Labelsconcat = "1" +Stimulationlabel + "1" + PenisActionLabel + "1" + OralLabel + "1" + PenetrationLabel + "1" + EndingLabel
 PrintDebug("Stimulationlabel :" + Stimulationlabel + ", PenisActionLabel :" + PenisActionLabel + ", OralLabel :" + OralLabel + ", PenetrationLabel :" + PenetrationLabel + ", EndingLabel :" + EndingLabel)

endfunction
;-----------------------BASE HENTAIRIM Update Functions END-----------------------------


;-----------------------Hentairim Common Utilities START--------------------------------------

Bool Function Isintense()
	return stringutil.find(Labelsconcat ,"1F") > -1 || stringutil.find(Labelsconcat ,"BST") > -1
endfunction

Bool Function IsGettingStimulated()
	return Stimulationlabel == "SST" || Stimulationlabel == "FST"
endfunction

Bool Function IsStimulatingOthers()
	return MasterScript.GetStimulationlabel(actorlist[0]) == "SST" || MasterScript.GetStimulationlabel(actorlist[0]) == "FST" || MasterScript.GetStimulationlabel(actorlist[0]) == "BST"
endfunction

Bool Function IsSuckingoffOther()
	return OralLabel == "SBJ" || OralLabel == "FBJ"
endfunction

Bool Function IsGettingDoublePenetrated()

return PenetrationLabel == "SDP" || PenetrationLabel == "FDP"
endfunction

Bool Function IsgettingPenetrated()
	return IsGettingAnallyPenetrated() || IsGettingVaginallyPenetrated()
endfunction

Bool Function PrevIsGivingAnalOrVaginalPenetration()
	return PrevPenisActionLabel == "SDV" || PrevPenisActionLabel == "FDV" || PrevPenisActionLabel == "FDA" || PrevPenisActionLabel == "SDA"
EndFunction

Bool Function IsGivingAnalPenetration()
	return PenisActionLabel == "FDA" || PenisActionLabel == "SDA"
endfunction

Bool Function IsGettingSuckedoff()
	return PenisActionLabel == "SMF" || PenisActionLabel == "FMF"
endfunction

Bool Function IsGivingVaginalPenetration()
	return PenisActionLabel == "FDV" || PenisActionLabel == "SDV"
endfunction

Bool Function IsGettingVaginallyPenetrated()
	return PenetrationLabel == "SVP" || PenetrationLabel == "FVP" || PenetrationLabel == "SCG" || PenetrationLabel == "FCG" || PenetrationLabel == "SDP" || PenetrationLabel == "FDP"
endfunction

Bool Function IsGettingAnallyPenetrated()
	return PenetrationLabel == "SAP" || PenetrationLabel == "FAP" || PenetrationLabel == "SAC" || PenetrationLabel == "FAC" || PenetrationLabel == "SDP" || PenetrationLabel == "FDP"
endfunction

Bool Function IsKissing()
	return OralLabel == "KIS"
endfunction

Bool Function IsCunnilingus()
	return OralLabel == "CUN"
endfunction

Bool Function IsLeadIN()
	return stringutil.find(Labelsconcat ,"1F") == -1 && stringutil.find(Labelsconcat ,"1S") == -1
endfunction

Bool Function isEnding()
	return EndingLabel == "ENI" || EndingLabel == "ENO"
endfunction

Bool function IshugePP()

	return MasterScript.ishugepp(actorref)
EndFunction

;classic: stages are plain integers - the "legacy stage num" IS the stage.
;asScene is unused (classic has no string scene id); kept for signature parity.
int Function GetLegacyStageNum(String asScene, String asStage)
	return asStage as int
EndFunction

Function PlaySound(String theSound, Actor actorMakingSound, Bool waitForCompletion = True)
	;per-actor channel: each actor's body-SFX stream replaces only its own previous
	;sound - a shared channel made the actors' loops cut each other off every play
	If waitForCompletion
		AudioUtil.PlaySFXAndWait(theSound, actorMakingSound, 1.0, "sfx", "sfx_main_" + position)
	Else
		AudioUtil.PlaySFX(theSound, actorMakingSound, 1.0, "sfx", "sfx_main_" + position)
	EndIf
EndFunction

Bool Function IsVictim(actor char)
  return currentthread.IsVictim(char)
endFunction

Function PrintDebug(string Contents = "")
if enableprintdebug == 1 && !isplayer
miscutil.printconsole(actorname + " - SLO VE SFX " + Contents)
endif
endfunction

Int Function FindInt(Int[] arr, Int target)
    Int i = 0
    While i < arr.Length
        If arr[i] == target
            Return i ; Found, return index
        EndIf
        i += 1
    EndWhile
    Return -1 ; Not found
EndFunction

Bool Function HasCreature()
	;classic SexLab has no CountCreatures helper - count locally
	;(gender 0 male, 1 female, 2 male creature, 3 female creature)
	int z = 0
	while z < actorList.length
		if actorList[z] && sexlab.GetGender(actorList[z]) >= 2
			return true
		endif
		z += 1
	endwhile
	return false
endfunction

function WritetoErrorlogs(string Header = "Not Specified" ,String contents = "")
	SLOVE_Log.WriteLog(Header + " : " + contents, 2)
endfunction
;-----------------------Hentairim Common Utilities END--------------------------------------
