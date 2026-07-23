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

SexLabThread CurrentThread = None
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
	CurrentThread = Sexlab.GetThreadByActor(playerref)
	actorlist = CurrentThread.GetPositions()
	Gender = sexlab.GetGender(actorref)
	IsPlayer = actorref == playerref
	isReceiver = actorref == actorlist[0]

	;establish positions
	position = currentthread.getpositionidx(actorref)
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
	if CurrentThread == none || argString as Int != CurrentThread.GetThreadID()
		return
	EndIf

	position = currentthread.getpositionidx(actorref)
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
usevelocity = SLOVE_Config.GetInt("sfx.usevelocity", 0)
useadaptivevelocity = SLOVE_Config.GetInt("sfx.useadaptivevelocity", 0)
usecontactsfx = SLOVE_Config.GetInt("sfx.usecontactsfx", 1)
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
Function CalculateAndPlayVelocitySFX()
    if FuckingPartner == none || FuckingPartnerInteractionType == 0
		UpdateFuckingPartner()
        return
    endif
	Float TimetoThrust = 0
    Float velocity
	Float LastVelocity
	String SlushVelocitySFX = ""
	String ImpactVelocitySFX = ""

	while Currentthread.getstatus() == 3 && DirectorLastLabelTime == MasterScript.GetDirectorLastLabelTime()

			velocity = Currentthread.GetVelocity(FuckingPartner, Actorref, FuckingPartnerInteractionType)
			if velocity == 0
				UpdateFuckingPartner()
				return
			endif

			PrintDebug("lastVelocity=" + lastVelocity as String + " | velocity=" + velocity as String)

			if lastVelocity >= 0 && velocity < 0 ; Reversal From Inside
				Float CurrentReverseOutTIme = CurrentThread.GetTimeTotal()
				PrintDebug("Seconds Since Last Reverse Out : " + (CurrentReverseOutTime - TimeLastReverseOut) as String + " Seconds | CurrentReverseOutTime=" + CurrentReverseOutTime as String + " | TimeLastReverseOut=" + TimeLastReverseOut as String)
				if StageShouldplayClap
					printdebug("playing Impact Velocity")
					ImpactVelocitySFX = GetImpactSoundToPlay(TimetoThrust)
					if ImpactVelocitySFX != ""
						AudioUtil.PlaySFX(ImpactVelocitySFX, FuckingPartner, 1.0, "sfx", "sfx_impact_" + position)
					else
						printdebug("ImpactVelocitySFX : is none!")
					endif
				Endif

					SlushVelocitySFX = GetSlushSoundToPlay(FuckingPartnerInteractionType, TimetoThrust)
					if SlushVelocitySFX != ""
						printdebug("playing Slush Velocity")
						AudioUtil.PlaySFX(SlushVelocitySFX, FuckingPartner, 1.0, "sfx", "sfx_slush_" + position)
					else
						printdebug("SlushVelocitySFX : is none!")
					endif
				TimeLastReverseOut = CurrentReverseOutTIme
				TimetoThrust = 0
			elseif CanPlayReverseIn && lastVelocity <= 0 && velocity > 0 ;reversal from outside
				printdebug("Velocity : " + Velocity + " | lastVelocity : " + LastVelocity + " | FuckingPartnerInteractionType : " + FuckingPartnerInteractionType)
				Float CurrentReverseInTIme = CurrentThread.GetTimeTotal()

				PrintDebug("CurrentReverseInTime=" + CurrentReverseInTime as String + " | TimeLastReverseOut=" + TimeLastReverseOut as String + " | Seconds Since Last Reverse In=" + (CurrentReverseInTime - TimeLastReverseOut) as String + " Seconds")
				SlushVelocitySFX = GetSlushSoundToPlay(FuckingPartnerInteractionType, TimetoThrust)
				if SlushVelocitySFX != ""
					printdebug("playing Slush Velocity")
					AudioUtil.PlaySFX(SlushVelocitySFX, FuckingPartner, 1.0, "sfx", "sfx_slush_" + position)
				else
					printdebug("SlushVelocitySFX : is none!")
				endif
				TimeLastReverseIn = CurrentReverseInTIme
			else
				printdebug("Wait")
				if Velocity > 0
					TimetoThrust += updateRate
				endif
			endif

			ProcessContactEdges()
			Utility.wait(updateRate)

			LastVelocity = velocity
	endwhile

EndFunction

int PenisPosition = 0
Bool StopPenisVelocitySearch

Bool Function PenisSearchForVelocity()
	printdebug("PenisSearchForVelocity: Called for " + ActorRef + " | SceneTag Missionary = " + currentthread.HasSceneTag("Missionary"))
	int SearchTopLimit
	Int SearchBottomLimit
	if currentthread.HasSceneTag("Missionary")
		SearchTopLimit = 4
		SearchBottomLimit = -6
		printdebug("PenisSearchForVelocity: Starting Missionary mode search (-7 to +7 range)")

		PenisPosition = 0
		printdebug("PenisSearchForVelocity: Beginning negative search from 0 to -7")

		While PenisPosition >= SearchBottomLimit && !StopPenisVelocitySearch && DirectorLastLabelTime == MasterScript.GetDirectorLastLabelTime()
			printdebug("PenisSearchForVelocity: Sending SOSBend" + PenisPosition + " | StopSearch=" + StopPenisVelocitySearch)
			Debug.SendAnimationEvent(Actorref, "SOSBend" + PenisPosition as string)
			Utility.wait(0.3)
			UpdateFuckingPartner()
			printdebug("PenisSearchForVelocity: Updated partner | Partner=" + FuckingPartner + " | InteractionType=" + FuckingPartnerInteractionType)

			if FuckingPartner == none || FuckingPartnerInteractionType == 0
				PenisPosition -= 1
				printdebug("PenisSearchForVelocity: No valid partner, decreasing PenisPosition to " + PenisPosition)
				PlayFillerSounds()
				SearchingFoundVelocity = false
			else
				Masterscript.SaveSchlongAdjustment(position, PenisPosition)
				printdebug("PenisSearchForVelocity: FOUND velocity position (Missionary negative loop) = " + PenisPosition)
				StopPenisVelocitySearch = true
				SearchingFoundVelocity = true
			endif
		endwhile

		PenisPosition = 0
		printdebug("PenisSearchForVelocity: Beginning positive search from 0 to +7")

		While PenisPosition <= SearchTopLimit && !StopPenisVelocitySearch && DirectorLastLabelTime == MasterScript.GetDirectorLastLabelTime()
			printdebug("PenisSearchForVelocity: Sending SOSBend" + PenisPosition + " | StopSearch=" + StopPenisVelocitySearch)
			Debug.SendAnimationEvent(Actorref, "SOSBend" + PenisPosition as string)
			Utility.wait(0.3)
			UpdateFuckingPartner()
			printdebug("PenisSearchForVelocity: Updated partner | Partner=" + FuckingPartner + " | InteractionType=" + FuckingPartnerInteractionType)

			if FuckingPartner == none || FuckingPartnerInteractionType == 0
				PenisPosition += 1
				printdebug("PenisSearchForVelocity: No valid partner, increasing PenisPosition to " + PenisPosition)
				PlayFillerSounds()
				SearchingFoundVelocity = false
			else
				Masterscript.SaveSchlongAdjustment(position, PenisPosition)
				printdebug("PenisSearchForVelocity: FOUND velocity position (Missionary positive loop) = " + PenisPosition)
				StopPenisVelocitySearch = true
				SearchingFoundVelocity = true
			endif
		endwhile
	else

		if currentthread.HasSceneTag("Standing")
			SearchTopLimit = 8
			SearchBottomLimit = -1
		elseif currentthread.HasSceneTag("doggystyle") || currentthread.HasSceneTag("doggy style")
			SearchTopLimit = 5
			SearchBottomLimit = -5
		else
			SearchTopLimit = 7
			SearchBottomLimit = -7
		endif
		printdebug("PenisSearchForVelocity: Starting Non-Missionary mode search (+7 to -7 range)")
		PenisPosition = 0

		While PenisPosition <= SearchTopLimit && !StopPenisVelocitySearch && DirectorLastLabelTime == MasterScript.GetDirectorLastLabelTime()
			printdebug("PenisSearchForVelocity: Sending SOSBend" + PenisPosition + " | StopSearch=" + StopPenisVelocitySearch)
			Debug.SendAnimationEvent(Actorref, "SOSBend" + PenisPosition as string)
			Utility.wait(0.3)
			UpdateFuckingPartner()
			printdebug("PenisSearchForVelocity: Updated partner | Partner=" + FuckingPartner + " | InteractionType=" + FuckingPartnerInteractionType)

			if FuckingPartner == none || FuckingPartnerInteractionType == 0
				PenisPosition += 1
				printdebug("PenisSearchForVelocity: No valid partner, increasing PenisPosition to " + PenisPosition)
				PlayFillerSounds()
				SearchingFoundVelocity = false
			else
				Masterscript.SaveSchlongAdjustment(position, PenisPosition)
				printdebug("PenisSearchForVelocity: FOUND velocity position (Non-Missionary positive loop) = " + PenisPosition)
				StopPenisVelocitySearch = true
				SearchingFoundVelocity = true
			endif
		endwhile

		PenisPosition = 0
		printdebug("PenisSearchForVelocity: Starting negative fallback search from 0 to -7")

		While PenisPosition >= SearchBottomLimit && !StopPenisVelocitySearch && DirectorLastLabelTime == MasterScript.GetDirectorLastLabelTime()
			printdebug("PenisSearchForVelocity: Sending SOSBend" + PenisPosition + " | StopSearch=" + StopPenisVelocitySearch)
			Debug.SendAnimationEvent(Actorref, "SOSBend" + PenisPosition as string)
			Utility.wait(0.3)
			UpdateFuckingPartner()
			printdebug("PenisSearchForVelocity: Updated partner | Partner=" + FuckingPartner + " | InteractionType=" + FuckingPartnerInteractionType)

			if FuckingPartner == none || FuckingPartnerInteractionType == 0
				PenisPosition -= 1
				printdebug("PenisSearchForVelocity: No valid partner, decreasing PenisPosition to " + PenisPosition)
				PlayFillerSounds()
				SearchingFoundVelocity = false
			else
				Masterscript.SaveSchlongAdjustment(position, PenisPosition)
				printdebug("PenisSearchForVelocity: FOUND velocity position (Non-Missionary negative fallback) = " + PenisPosition)
				StopPenisVelocitySearch = true
				SearchingFoundVelocity = true
			endif
		endwhile
	endif

EndFunction


Float TimeSinceLastFillerSound
Float FillerTimetoThrustMin
Float FillerTimetoThrustMax
Float FillerIntervals

Function PlayFillerSounds()
	printdebug("PlayFillerSounds: Called | TimeSinceLast=" + TimeSinceLastFillerSound + " | TotalTime=" + CurrentThread.GetTimeTotal() + " | Interval=" + FillerIntervals)

	if CurrentThread.GetTimeTotal() - TimeSinceLastFillerSound >= FillerIntervals
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

		TimeSinceLastFillerSound = CurrentThread.GetTimeTotal()
		printdebug("PlayFillerSounds: Updated TimeSinceLastFillerSound = " + TimeSinceLastFillerSound)
	else
		printdebug("PlayFillerSounds: Interval not reached, skipping sound playback")
	endif
EndFunction


Function RunAdaptiveVelocitySFX()
	int z
    while (FuckingPartner == none || FuckingPartnerInteractionType == 0) && Z < timestosearch
		printdebug("---------------------RunAdaptiveVelocitySFX : START SEARCHING---------------" )
		SearchingFoundVelocity = false
		PenisSearchForVelocity()
		z += 1
    endwhile

	Float TimetoThrust = 0
    Float velocity
	Float LastVelocity
	String SlushVelocitySFX = ""
	String ImpactVelocitySFX = ""

	while !Masterscript.AnimationisEnding() && DirectorLastLabelTime == MasterScript.GetDirectorLastLabelTime() && !UpdateNow
			int TimesNotFoundVelocity
			velocity = Currentthread.GetVelocity(FuckingPartner, Actorref, FuckingPartnerInteractionType)

			if velocity == 0 && !SearchingFoundVelocity
				PlayFillerSounds()
			endif

			if Velocity == 0 && SearchingFoundVelocity
				TimesNotFoundVelocity += 1
				if TimesNotFoundVelocity > 10
					UpdateFuckingPartner()
					return
				endif
			endif

			PrintDebug("lastVelocity=" + lastVelocity as String + " | velocity=" + velocity as String)

			if lastVelocity >= 0 && velocity < 0 ; Reversal From Inside
				TimesNotFoundVelocity = 0
				Float CurrentReverseOutTIme = CurrentThread.GetTimeTotal()
				PrintDebug("Seconds Since Last Reverse Out : " + (CurrentReverseOutTime - TimeLastReverseOut) as String + " Seconds | CurrentReverseOutTime=" + CurrentReverseOutTime as String + " | TimeLastReverseOut=" + TimeLastReverseOut as String)
				if StageShouldplayClap
					printdebug("playing Impact Velocity")
					ImpactVelocitySFX = GetImpactSoundToPlay(TimetoThrust)
					if ImpactVelocitySFX != ""
						AudioUtil.PlaySFX(ImpactVelocitySFX, FuckingPartner, 1.0, "sfx", "sfx_impact_" + position)
					else
						printdebug("ImpactVelocitySFX : is none!")
					endif
				Endif

					SlushVelocitySFX = GetSlushSoundToPlay(FuckingPartnerInteractionType, TimetoThrust)
					if SlushVelocitySFX != ""
						printdebug("playing Slush Velocity")
						AudioUtil.PlaySFX(SlushVelocitySFX, FuckingPartner, 1.0, "sfx", "sfx_slush_" + position)
					else
						printdebug("SlushVelocitySFX : is none!")
					endif
				TimeLastReverseOut = CurrentReverseOutTIme
				TimetoThrust = 0
			elseif CanPlayReverseIn && lastVelocity <= 0 && velocity > 0 ;reversal from outside
				TimesNotFoundVelocity = 0
				printdebug("Velocity : " + Velocity + " | lastVelocity : " + LastVelocity + " | FuckingPartnerInteractionType : " + FuckingPartnerInteractionType)
				Float CurrentReverseInTIme = CurrentThread.GetTimeTotal()

				PrintDebug("CurrentReverseInTime=" + CurrentReverseInTime as String + " | TimeLastReverseOut=" + TimeLastReverseOut as String + " | Seconds Since Last Reverse In=" + (CurrentReverseInTime - TimeLastReverseOut) as String + " Seconds")
				SlushVelocitySFX = GetSlushSoundToPlay(FuckingPartnerInteractionType, TimetoThrust)
				if SlushVelocitySFX != ""
					printdebug("playing Slush Velocity")
					AudioUtil.PlaySFX(SlushVelocitySFX, FuckingPartner, 1.0, "sfx", "sfx_slush_" + position)
				else
					printdebug("SlushVelocitySFX : is none!")
				endif
				TimeLastReverseIn = CurrentReverseInTIme
			else
				printdebug("Wait")
				if Velocity > 0
					TimetoThrust += updateRate
				endif
			endif

			ProcessContactEdges()
			Utility.wait(updateRate)

			LastVelocity = velocity
	endwhile

EndFunction


Bool Function UpdateFuckingPartner()
    PrintDebug(actorname + " UpdateFuckingPartner - Starting partner search.")

    if currentthread == None || !currentthread.IsInteractionRegistered()
        PrintDebug(actorname + " UpdateFuckingPartner - Interaction not registered, skipping.")
        return false
    endif

    FuckingPartner = None
    FuckingPartnerInteractionType = 0
    int[] Interactionarr

    int z = 0
    while z < actorList.length
        Actor candidate = actorList[z]

        if candidate != actorref ; skip self

            Interactionarr = currentthread.GetInteractionTypes(candidate, actorref)

            if Interactionarr && Interactionarr.length > 0

                ; Vaginal interaction
                if findint(Interactionarr, 1) > -1
                    FuckingPartner = candidate
                    FuckingPartnerInteractionType = 1
                    z = actorList.length
                ; Anal interaction
                elseif findint(Interactionarr, 2) > -1
                    FuckingPartner = candidate
                    FuckingPartnerInteractionType = 2
                    z = actorList.length
                endif
            endif
        endif

        z += 1
    endwhile

    ; Final result
    if FuckingPartner
		SearchingFoundVelocity = true
        PrintDebug(actorname + " UpdateFuckingPartner - Final partner: " + FuckingPartner.GetDisplayName() + " | Type=" + FuckingPartnerInteractionType)
		return true
    else
		SearchingFoundVelocity = false
        PrintDebug(actorname + " UpdateFuckingPartner - No valid partner found.")
		return false
    endif
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
	if usecontactsfx != 1 || position <= 0 || CurrentThread == none || !CurrentThread.IsInteractionRegistered()
		return
	endif
	bool[] f = CurrentThread.GetCurrentInteractionFlags(actorref)
	if f.Length < 28
		return
	endif
	;falling edges are debounced by elapsed scene time, not poll count - callers
	;poll anywhere between 0.05s and 3s, so counting polls made the window wildly
	;inconsistent; 0.5s tolerates brief detection dropouts at every cadence
	float now = CurrentThread.GetTimeTotal()

	;--- penetration edges (actorref as giver) ---
	bool pen = f[26] || f[27] ;aVaginal / aAnal
	if pen
		ContactPenLastSeen = now
		if !PrevContactPenetrating
			PrevContactPenetrating = true
			ContactPenStartTime = now
			LastPenReceiver = CurrentThread.GetPartnerByType(actorref, 1)
			if LastPenReceiver == none
				LastPenReceiver = CurrentThread.GetPartnerByType(actorref, 2)
			endif
			;resistance system: a forced insertion onto a submissive receiver deposits
			;trauma their SLOVE_Resistance drains into willpower loss on its next tick
			if LastPenReceiver != none && victiminsertiontrauma > 0 && MasterScript.IsSubmissive(LastPenReceiver)
				StorageUtil.AdjustFloatValue(LastPenReceiver, "SLOVE_ResDebt", victiminsertiontrauma as float)
			endif
			;insertion one-shot only when the label system hasn't classified this as penetration yet
			if LastPenReceiver != none && !IsGivingVaginalPenetration() && !IsGivingAnalPenetration()
				printdebug("Contact edge: insertion detected")
				String InsertionSFX = GetSlushSoundToPlay(1, 0.5)
				if InsertionSFX != ""
					PlayContactSound(InsertionSFX, LastPenReceiver)
				endif
			endif
		endif
	elseif PrevContactPenetrating && now - ContactPenLastSeen >= 0.5
		PrevContactPenetrating = false
		;pull-out gape after sustained penetration, measured to the last confirmed
		;contact so the debounce window doesn't inflate the requirement
		if LastPenReceiver != none && ContactPenLastSeen - ContactPenStartTime >= 4.0
			;prefer the actual measured openings from the AudioUtil PPA bridge over
			;the partner-size guess: right after pull-out the opening is still
			;elevated, so it reflects what really happened to the receiver. Each
			;orifice is judged against its own scale (anal rests wider than
			;vaginal ever stretches), and the stronger result wins
			float vagopening = 0.0
			float analopening = 0.0
			if AudioUtilPPA.IsConnected()
				vagopening = AudioUtilPPA.GetVaginalOpening(LastPenReceiver)
				analopening = AudioUtilPPA.GetAnalOpening(LastPenReceiver)
			endif
			printdebug("Contact edge: pull-out detected, vagopening=" + vagopening + " analopening=" + analopening)
			if vagopening > 0.0 || analopening > 0.0
				if (vagopening >= gapevaginalhuge || analopening >= gapeanalhuge) && GapeHuge != ""
					PlayContactSound(GapeHuge, LastPenReceiver)
				elseif (vagopening >= gapevaginalaverage || analopening >= gapeanalaverage) && GapeAverage != ""
					PlayContactSound(GapeAverage, LastPenReceiver)
				endif
				;below both average thresholds: barely stretched, no gape sound
			elseif IsHugePP && GapeHuge != ""
				PlayContactSound(GapeHuge, LastPenReceiver)
			elseif GapeAverage != ""
				PlayContactSound(GapeAverage, LastPenReceiver)
			endif
		endif
	endif

	;--- kissing start (fire from the higher position of the pair so it plays once) ---
	bool kis = f[9] ;bKissing
	if kis
		ContactKisLastSeen = now
		if !PrevContactKissing
			PrevContactKissing = true
			if !IsKissing()
				Actor kisPartner = CurrentThread.GetPartnerByTypeRev(actorref, 10)
				if kisPartner != none && CurrentThread.GetPositionIdx(kisPartner) < position && Kissing != ""
					;no tender kiss cue when either side is a victim - aggressive
					;animations bring faces together without it being romantic
					if usecontactvictimreactions == 1 && (IsVictim || IsVictim(kisPartner))
						printdebug("Contact edge: kissing suppressed, victim in pair")
					else
						printdebug("Contact edge: kissing started")
						PlayContactSound(Kissing, actorref)
					endif
				endif
			endif
		endif
	elseif PrevContactKissing && now - ContactKisLastSeen >= 0.5
		PrevContactKissing = false
	endif

	;--- blowjob/deepthroat start (actorref getting sucked) ---
	bool deep = f[24] ;pDeepthroat
	bool suck = deep || f[23] ;pOral
	if suck
		ContactSuckLastSeen = now
		if !PrevContactSucked
			PrevContactSucked = true
			if !IsGettingSuckedoff()
				Actor sucker = CurrentThread.GetPartnerByType(actorref, 3)
				if sucker == none
					sucker = CurrentThread.GetPartnerByType(actorref, 5)
				endif
				if sucker != none
					printdebug("Contact edge: oral started")
					if deep && FastBlowjob != ""
						PlayContactSound(FastBlowjob, sucker)
					elseif SlowBlowjob != ""
						PlayContactSound(SlowBlowjob, sucker)
					endif
				endif
			endif
		endif
	elseif PrevContactSucked && now - ContactSuckLastSeen >= 0.5
		PrevContactSucked = false
	endif
EndFunction
;-------------------------------Contact Edge SFX END---------------------------------

Function SFXRefreshSound()
;refreshing

	SFXTag = SLOVE_Hentairim_Tags.GetSFX(CurrentSceneID, currentstage)
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

	ThreadID = CurrentThread.GetThreadID()
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

		CurrentSceneID = CurrentThread.GetActiveScene()
		currentStageID = CurrentThread.GetActiveStage()
		currentstage = GetLegacyStageNum(CurrentSceneID, currentStageID)

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
		StageShouldplayClap = EndingLabel != "ENO" && EndingLabel != "ENI" && (SFXTag == "FC" || SFXTag == "MC" || SFXTag == "SC" || CurrentThread.HasStageTag("Doggy") || CurrentThread.HasStageTag("DoggyStyle")) && (IsGivingVaginalPenetration() || IsGivingAnalPenetration())

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

int Function GetLegacyStageNum(String asScene, String asStage)
	string[] all_stages = SexlabRegistry.GetAllStages(asScene)
	if SexlabRegistry.StageExists(asScene, asStage)
		int stage_num = all_stages.find(asStage)+1
		return stage_num
	endif
	return 0
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
  return CurrentThread.GetSubmissive(char)
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

	return sexlab.CountCreatures(actorList) > 0
endfunction

function WritetoErrorlogs(string Header = "Not Specified" ,String contents = "")
	JsonUtil.StringListAdd("ErrorLog.json", Header, " : " + contents, TRUE)
endfunction
;-----------------------Hentairim Common Utilities END--------------------------------------
