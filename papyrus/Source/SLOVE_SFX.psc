Scriptname SLOVE_SFX extends ActiveMagicEffect
{SLO VE body-SFX engine: per-actor magic
 effect that plays slushing / impact / clap / kissing / blowjob body sounds
 through AudioUtil, driven by scene labels, SFX scene tags, and (optionally)
 SLPP contact speed for thrust-paced playback. Settings come from
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
	;resolve OUR OWN thread from the actor, not the player's - this effect runs on NPC
	;scene actors too (NPC-only scenes), where the player isn't present. For a PC-scene
	;actor this is identical (the actor is in the player's thread).
	CurrentThread = Sexlab.GetThreadByActor(actorref)
	actorlist = CurrentThread.GetPositions()
	Gender = sexlab.GetGender(actorref)
	IsPlayer = actorref == playerref
	isReceiver = actorref == actorlist[0]

	;establish positions
	position = currentthread.getpositionidx(actorref)
	IsSmallPP = Masterscript.IsSmallPP(actorref)
	RegisterForTheEventsWeNeed()

	if sexlab == none
		SLOVE_Utils.WritetoErrorlogs("SFX", "Sexlab Not Found!")
	endif

	if CurrentThread == none
		SLOVE_Utils.WritetoErrorlogs("SFX", "Sexlab Thread Not Found!")
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
	elseif !IsPlayer
		;NPC-on-NPC climax (NPC-only scene): play the ejaculation SFX on the receiver
		AudioUtil.PlaySFX(EjacSound, actorlist[0], 1.0, "sfx", "sfx_ejac_" + position)
	endif

EndEvent



Event OnUpdate()

	;hold while a menu has the scene frozen (see GamePaused) - slaps and squelches
	;shouldn't keep firing over an animation that isn't moving
	if SLOVE_Utils.GamePaused()
		RegisterForSingleUpdate(0.5)
		return
	endif

	HentairimUpdateStageData()
	;Ends if the actor is no longer in scene but the magic stuck for some reason.
	;AnimationisEnding is the PC scene's teardown flag - honor it only for a PC-scene
	;actor, else a concurrent PC scene ending would wrongly end this NPC-scene SFX. NPC
	;scenes end on their own thread going away.
	if !Sexlab.GetThreadByActor(actorref) || (OnPCThread() && Masterscript.AnimationisEnding())
		PrintDebug("Ending Animation. remove SLO VE SFX")
		RemoveSFX()
		;RemoveSFX dispels this spell, so the effect is already unbound - falling
		;through to RegisterForSingleUpdate below would fire on a [None] instance
		return
	endif

	ProcessContactEdges()

	if position > 0

		;set the poll BEFORE the spinner so its internal Utility.wait uses it.
		;Velocity paths poll tight (they integrate the thrust speed); the label/tag
		;path polls at normalpoll - it was needlessly churning GetInteractionFlags
		;at 10Hz for a sound whose own clip length already paces it.
		if (IsGivingAnalPenetration() || IsGivingVaginalPenetration()) && !isEnding() && RunPPAThrustSFX()
			;timed off Accurate Penetration's measured depth, which outranks every other
			;pacing: it is the only source that sees the moment of impact
		elseif (IsGivingAnalPenetration() || IsGivingVaginalPenetration() || (EndingLabel != "LDI" && PrevIsGivingAnalOrVaginalPenetration()) ) && useadaptivevelocity == 1 && usevelocity == 1 && !HasCreature() && !isEnding()
			printdebug("Running Adaptive Velocity SFX")
			updateRate = velocitypoll
			RunAdaptiveVelocitySFX()
		elseif (IsGivingAnalPenetration() || IsGivingVaginalPenetration()) && usevelocity == 1 && !HasCreature() && !isEnding() ;only use velocityfx for non creatures scene as no data is available
			printdebug("Running Velocity SFX")
			updateRate = velocitypoll
			CalculateAndPlayVelocitySFX() ;thrust-paced SFX from contact speed
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

bool HasInteractions ;SexLab P+ 2.19+ interaction API is there (SLOVE_Utils.HasInteractionAPI), probed once in InitializeConfigandForms
int usevelocity
int useadaptivevelocity
int usecontactsfx
int victiminsertiontrauma
int usecontactvictimreactions
int timestosearch
;poll intervals (seconds). velocitypoll is the speed-sampling step of the thrust
;pacing spinners (a coarse step adds jitter to each beat); normalpoll paces the
;label/tag-driven loop, which is otherwise a needless 10Hz churn of
;GetInteractionFlags
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
	;thrust sounds timed off Accurate Penetration's measured depth (RunPPAThrustSFX).
	;sfx.usevelocity is the user's switch for measured thrust timing as a whole;
	;sfx.useppathrust turns off this source alone. It reads no SexLab contact data,
	;so the bridge being connected is all it needs.
	useppathrust = 0
	if SLOVE_Config.GetInt("sfx.usevelocity", 0) == 1 && SLOVE_Config.GetInt("sfx.useppathrust", 1) == 1 && AudioUtilPPA.IsConnected()
		useppathrust = 1
	endif
	ppathrustturn = SLOVE_Config.GetFloat("sfx.ppathrustturn", 1.0)
	if ppathrustturn < 0.1
		ppathrustturn = 0.1
	endif
	HasInteractions = SLOVE_Utils.HasInteractionAPI() ;once per scene - it cannot change while the game runs
	if !HasInteractions
		;SexLab P+ older than 2.19 has no contact speed to pace thrusts by, and the
		;velocity loops play nothing without one - hand the pacing to the label/tag
		;loop (PlaySFX), exactly as sfx.usevelocity = 0 does
		usevelocity = 0
		useadaptivevelocity = 0
	endif
	usecontactsfx = SLOVE_Config.GetInt("sfx.usecontactsfx", 1)
	usecontactvictimreactions = SLOVE_Config.GetInt("sfx.usecontactvictimreactions", 1)
	victiminsertiontrauma = SLOVE_Config.GetInt("resistance.victiminsertiontrauma", 5)
	timestosearch = SLOVE_Config.GetInt("sfx.timestosearch", 0)
	thruststroke = SLOVE_Config.GetFloat("sfx.thruststroke", 16.0)
	if thruststroke < 1.0
		thruststroke = 1.0 ;it is a divisor (see AdvanceThrust)
	endif
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
;------------------------------ thrust pacing ------------------------------
;SexLab P+ 2.19 reports contact motion as a SPEED: never negative, and low-pass
;filtered over ~0.25s. The signed velocity of 2.18 and older, whose sign flip
;marked each thrust reversal, is gone - a reversal can no longer be observed.
;Distance travelled still can (speed x time), and one full thrust, in plus out,
;covers about thruststroke world units. So the engine integrates the speed and
;fires a beat for every stroke's worth of travel. The sound RATE follows the
;animation, AnimSpeed overrides included; the PHASE is not locked to it, so on
;a slow stage a clap can land between two visible impacts.
float thruststroke
float ThrustPhase ;share of the current stroke already travelled, 0..1
bool ThrustHalfPlayed ;the mid-stroke slush already fired for this stroke
float ThrustLastSample ;real time of the previous speed sample, 0 = none yet

;FuckingPartnerInteractionType keeps the 1 = vaginal / 2 = anal meaning the
;sound pickers key on; P+ 2.19 wants the giver's own flag index instead.
int Function ThrustInterType()
	if FuckingPartnerInteractionType == 2
		return 25 ;aAnal
	endif
	return 23 ;aVaginal
EndFunction

;Credits one speed sample (must be > 0) to the stroke and plays what falls due:
;the bottom-out beat - impact plus slush - at a full stroke, and on a non-intense
;stage the re-entry slush at the half. These are the two events the old code
;read off the velocity sign ("reversal from inside" / "from outside").
Function AdvanceThrust(float speed)
	float now = Utility.GetCurrentRealTime()
	float dt = now - ThrustLastSample
	ThrustLastSample = now
	;the first sample of a run only sets the clock, and a gap this long is a
	;stage change or a stall - there is no travel to credit for either
	if dt <= 0.0 || dt > 1.0
		return
	endif
	ThrustPhase += speed * dt / thruststroke

	bool beat = ThrustPhase >= 1.0
	bool half = !beat && CanPlayReverseIn && !ThrustHalfPlayed && ThrustPhase >= 0.5
	if !beat && !half
		return
	endif
	if beat
		ThrustPhase -= 1.0
		if ThrustPhase >= 1.0
			ThrustPhase = 0.0 ;the poll is slower than the thrust - never owe beats
		endif
		ThrustHalfPlayed = false
	else
		ThrustHalfPlayed = true
	endif
	;a frozen scene keeps reporting its last speed, so the stroke keeps filling
	;behind an overlay menu: the beat is consumed above, the sound is not played
	if SLOVE_Utils.GamePaused()
		return
	endif

	;what the pickers call TimetoThrust is the length of the inward half of the
	;stroke; at this speed that is half a stroke's travel time
	float timetothrust = 0.5 * thruststroke / speed
	PrintDebug("Thrust beat=" + beat + " | speed=" + speed + " | TimetoThrust=" + timetothrust)
	PlayThrustBeat(FuckingPartner, FuckingPartnerInteractionType, timetothrust, beat)
EndFunction

;------------------------------ thrust sync from PPA depth ------------------------------
;Accurate Penetration reports, through AudioUtil's bridge, how deep the receiver is
;penetrated right now. Depth rising is the thrust going in, depth falling is the
;pull-out, and the turn between the two is the moment of impact - the reversal
;SexLab P+ 2.19's unsigned speed can no longer show. No SexLab contact data is read,
;so this block is the same in both script variants and works on every P+ version.
;A turn counts once the depth has come back by ppathrustturn from its extreme. That
;hysteresis keeps jitter around a held-deep pose from firing claps, at the price of
;hearing each turn that much late. GetDepth is the receiver's DEEPEST partner, so
;two partners on one receiver share one signal and both play its beats.
int useppathrust ;sfx.usevelocity and sfx.useppathrust are on and the PPA bridge is connected
float ppathrustturn
bool PPAThrustNoData ;PPA measured nothing on this stage - not asked again until the next one
bool PPAThrustRising
float PPAThrustPeak
float PPAThrustTrough
float PPAThrustPeakAt ;real time the current extreme was reached
float PPAThrustTroughAt
float PPAThrustLastTime ;how long the last inward stroke took

;One thrust beat on akOn: the impact (when asked for and the stage calls for claps)
;and the slush, both picked by how long the inward stroke took.
Function PlayThrustBeat(Actor akOn, int aiType, float afTimeToThrust, bool abImpact)
	if abImpact && StageShouldplayClap
		String ImpactVelocitySFX = GetImpactSoundToPlay(afTimeToThrust)
		if ImpactVelocitySFX != ""
			AudioUtil.PlaySFX(ImpactVelocitySFX, akOn, 1.0, "sfx", "sfx_impact_" + position)
		endif
	endif
	String SlushVelocitySFX = GetSlushSoundToPlay(aiType, afTimeToThrust)
	if SlushVelocitySFX != ""
		AudioUtil.PlaySFX(SlushVelocitySFX, akOn, 1.0, "sfx", "sfx_slush_" + position)
	endif
EndFunction

;Feeds one depth sample to the turn detector and plays what it finds: the full beat
;when the thrust turns at its deepest, and on a non-intense stage a slush when it
;turns back in. These are the two events SLO VE read off the velocity sign up to
;0.6.25 ("reversal from inside" / "from outside").
Function PPAThrustStep(Actor akReceiver, int aiType, float afDepth, float afNow)
	if PPAThrustRising
		if afDepth > PPAThrustPeak
			PPAThrustPeak = afDepth
			PPAThrustPeakAt = afNow
		elseif PPAThrustPeak - afDepth >= ppathrustturn
			;turned at the peak. The stroke that led there began at the trough; the
			;first samples of a run have none, and then there is nothing to sound yet
			float stroke = PPAThrustPeak - PPAThrustTrough
			PPAThrustLastTime = PPAThrustPeakAt - PPAThrustTroughAt
			PPAThrustRising = false
			PPAThrustTrough = afDepth
			PPAThrustTroughAt = afNow
			if stroke >= ppathrustturn
				PrintDebug("PPA thrust: impact | stroke=" + stroke + " | TimetoThrust=" + PPAThrustLastTime + " | depth=" + afDepth)
				PlayThrustBeat(akReceiver, aiType, PPAThrustLastTime, true)
			endif
		endif
	elseif afDepth < PPAThrustTrough
		PPAThrustTrough = afDepth
		PPAThrustTroughAt = afNow
	elseif afDepth - PPAThrustTrough >= ppathrustturn
		;heading back in
		PPAThrustRising = true
		PPAThrustPeak = afDepth
		PPAThrustPeakAt = afNow
		if CanPlayReverseIn
			PlayThrustBeat(akReceiver, aiType, PPAThrustLastTime, false)
		endif
	endif
EndFunction

;Times the thrust sounds off PPA's depth for as long as this stage lasts and PPA
;keeps measuring. True = it did, and the caller's tick is spent. False = PPA has
;nothing for this actor's receiver, and the caller paces the stage its own way.
Bool Function RunPPAThrustSFX()
	if useppathrust != 1 || PPAThrustNoData
		return false
	endif
	;whom this actor is penetrating: the contact detector's answer when there is
	;one (P+ 2.19), else the labels'
	Actor receiver = FuckingPartner
	if receiver == none
		receiver = ResolvePenetrationReceiver()
	endif
	float depth = 0.0
	if receiver != none
		depth = AudioUtilPPA.GetDepth(receiver)
	endif
	if receiver == none || (depth <= 0.0 && AudioUtilPPA.GetContext(receiver) == 0)
		;nobody to read, or PPA is not tracking them at all
		PPAThrustNoData = true
		return false
	endif
	PrintDebug("Running PPA thrust SFX on " + receiver.GetDisplayName() + " | depth=" + depth)
	int type = 1 ;the 1 = vaginal / 2 = anal the sound pickers key on
	if IsGivingAnalPenetration()
		type = 2
	endif
	updateRate = velocitypoll
	float now = Utility.GetCurrentRealTime()
	float seenAt = now ;when PPA last measured a depth above zero - the grace starts here
	PPAThrustRising = true
	PPAThrustPeak = depth
	PPAThrustTrough = depth
	PPAThrustPeakAt = now
	PPAThrustTroughAt = now
	while !MasterScript.AnimationisEnding() && DirectorLastLabelTime == MasterScript.GetDirectorLastLabelTime() && DirectorLastPhysicsLabelTime == MasterScript.GetDirectorLastPhysicsLabelTime() && !UpdateNow
		depth = AudioUtilPPA.GetDepth(receiver)
		now = Utility.GetCurrentRealTime()
		if depth > 0.0
			seenAt = now
		elseif now - seenAt > 1.5
			;out for this long is not part of a thrust: PPA lost the pair, or the
			;labels name a penetration that is not happening. Hand the stage back.
			PrintDebug("PPA thrust: no depth for 1.5s - back to the stage's own pacing")
			PPAThrustNoData = true
			return false
		endif
		PPAThrustStep(receiver, type, depth, now)
		ProcessContactEdges()
		Utility.Wait(updateRate)
	endwhile
	return true
EndFunction

;Calculate play sound
Function CalculateAndPlayVelocitySFX()
;the velocity/impact streams play straight through AudioUtil, so the voice
;engine's freeze hold never reached them: held here at the entry point.
	If SLOVE_Utils.GamePaused()
		Return
	EndIf
	if FuckingPartner == none || FuckingPartnerInteractionType == 0
		UpdateFuckingPartner()
		return
	endif
	Float velocity
	ThrustLastSample = 0.0 ;a fresh run of samples

	while Currentthread.getstatus() == 3 && DirectorLastLabelTime == MasterScript.GetDirectorLastLabelTime()

		;a P+ 2.19-only call with no gate of its own: only UpdateFuckingPartner sets
		;FuckingPartner, and it is version-gated (InteractionsLive)
		velocity = Currentthread.GetInteractionVelocity(Actorref, FuckingPartner, ThrustInterType())
		if velocity <= 0
			;no contact tracked, or one that only just (re)started: look again
			;and let the next update tick retry
			UpdateFuckingPartner()
			return
		endif

		AdvanceThrust(velocity)

		ProcessContactEdges()
		Utility.wait(updateRate)
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

	;the search's real output is the SearchingFoundVelocity member; the declared
	;Bool had NO return on any path (it fell off the end, returning None). The one
	;call site discards the value, so nothing broke - return the member so the
	;signature means what it says
	return SearchingFoundVelocity
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
	If SLOVE_Utils.GamePaused()
		Return
	EndIf
	int z
	while (FuckingPartner == none || FuckingPartnerInteractionType == 0) && Z < timestosearch
		printdebug("---------------------RunAdaptiveVelocitySFX : START SEARCHING---------------" )
		SearchingFoundVelocity = false
		PenisSearchForVelocity()
		z += 1
	endwhile

	Float velocity
	ThrustLastSample = 0.0 ;a fresh run of samples

	while !Masterscript.AnimationisEnding() && DirectorLastLabelTime == MasterScript.GetDirectorLastLabelTime() && !UpdateNow
		int TimesNotFoundVelocity
		velocity = 0.0
		if FuckingPartner != none && FuckingPartnerInteractionType != 0
			;P+ 2.19-only, guarded by the partner like the read in CalculateAndPlayVelocitySFX
			velocity = Currentthread.GetInteractionVelocity(Actorref, FuckingPartner, ThrustInterType())
		endif

		if velocity <= 0 && !SearchingFoundVelocity
			PlayFillerSounds()
		endif

		if velocity <= 0 && SearchingFoundVelocity
			TimesNotFoundVelocity += 1
			if TimesNotFoundVelocity > 10
				UpdateFuckingPartner()
				return
			endif
		endif

		if velocity > 0
			TimesNotFoundVelocity = 0
			AdvanceThrust(velocity)
		else
			;no travel to credit across a gap in the data
			ThrustLastSample = 0.0
		endif

		ProcessContactEdges()
		Utility.wait(updateRate)
	endwhile

EndFunction


;True when this actor's scene has live contact data this build can read: SexLab P+
;2.19 or newer AND its detector registered for the thread. The version answer comes
;FIRST - GetInteractionFlags / GetPartnerByInteractionType / GetInteractionVelocity
;do not exist on an older P+ (see SLOVE_Utils.HasInteractionAPI; HasInteractions is
;that probe, taken at init), so every one of those calls sits behind this or behind
;a partner only this can find.
bool Function InteractionsLive()
	return HasInteractions && CurrentThread != none && CurrentThread.IsInteractionRegistered()
EndFunction

Bool Function UpdateFuckingPartner()
	PrintDebug(actorname + " UpdateFuckingPartner - Starting partner search.")

	if !InteractionsLive()
		PrintDebug(actorname + " UpdateFuckingPartner - Interaction not registered, skipping.")
		return false
	endif

	FuckingPartner = None
	FuckingPartnerInteractionType = 0

	;P+ 2.19 answers "whom is actorref penetrating" directly, keyed by actorref's
	;own giver flag - no sweep over the positions. Vaginal first, then anal;
	;FuckingPartnerInteractionType keeps its 1 / 2 meaning (see ThrustInterType).
	Actor receiver = CurrentThread.GetPartnerByInteractionType(actorref, 23) ;aVaginal
	if receiver != none
		FuckingPartner = receiver
		FuckingPartnerInteractionType = 1
	else
		receiver = CurrentThread.GetPartnerByInteractionType(actorref, 25) ;aAnal
		if receiver != none
			FuckingPartner = receiver
			FuckingPartnerInteractionType = 2
		endif
	endif

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
		if SLOVE_Utils.GamePaused()
			;the loop's pacing IS PlaySound's blocking wait; while the scene is frozen
			;that wait returns instantly, so hold here instead of spinning through
			;ProcessContactEdges and the three Director externals every poll
			utility.wait(0.5)
		else
			ProcessContactEdges()
			PlaySound( SFXtoPlay , actorlist[0] , true) ;PlaySFXAndWait - blocks for the clip, so the loop is already paced by clip length
			utility.wait(normalpoll)
		endif
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
Bool PrevContactCunni
Float ContactPenStartTime
Float ContactPenLastSeen
Float ContactKisLastSeen
Float ContactSuckLastSeen
Float ContactCunniLastSeen
Actor LastPenReceiver

;edge one-shots get their own instance slot: PlaySound()'s channel is the lane
;for the continuous body SFX, and sharing it would cut those off
Function PlayContactSound(String theSound, Actor actorMakingSound)
	If SLOVE_Utils.GamePaused()
		Return
	EndIf
	;the channel natively stops the previous contact one-shot (per actor, so the
	;effect instances don't cut each other's edges)
	AudioUtil.PlaySFX(theSound, actorMakingSound, 1.0, "sfx", "sfx_contact_" + position)
EndFunction

;The gape one-shot on a pull-out. Shared by the two edge detectors:
;ProcessContactEdges (contact flags) and ProcessLabelEdges (labels).
Function PlayPullOutGape()
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
EndFunction

;SexLab P+ older than 2.19 has no contact flags, so there the penetration edge is
;taken from the LABEL system instead, as the classic variant does. It keeps the two
;things an edge feeds that need no detector: the forced-insertion trauma deposit,
;and the pull-out gape (measured by the AudioUtil PPA bridge, which is
;framework-independent). The insertion / kiss / oral one-shots are NOT here: they
;exist to catch what the labels miss, and an edge that comes from the labels can
;never be one of those.
Function ProcessLabelEdges()
	bool pen = IsGivingVaginalPenetration() || IsGivingAnalPenetration()
	Actor receiver = none
	if pen && !PrevContactPenetrating
		receiver = ResolvePenetrationReceiver()
	endif
	PenetrationEdge(pen, CurrentThread.GetTimeTotal(), receiver, false)
EndFunction

;The penetration edge itself, for both detectors (ProcessContactEdges on contact
;flags, ProcessLabelEdges on labels). pen: actorref is penetrating right now.
;akReceiver: whom - the caller looks it up, and it is read on the rising edge only.
;abInsertionShot: the insertion one-shot may play; it is for an insertion the
;labels have not classified, so only a detector that is not the labels asks for it.
Function PenetrationEdge(bool pen, float now, Actor akReceiver, bool abInsertionShot)
	if pen
		ContactPenLastSeen = now
		if !PrevContactPenetrating
			PrevContactPenetrating = true
			ContactPenStartTime = now
			LastPenReceiver = akReceiver
			;resistance system: a forced insertion onto a submissive receiver deposits
			;trauma their SLOVE_Resistance drains into willpower loss on its next tick
			if LastPenReceiver != none && victiminsertiontrauma > 0 && MasterScript.IsSubmissive(LastPenReceiver)
				StorageUtil.AdjustFloatValue(LastPenReceiver, "SLOVE_ResDebt", victiminsertiontrauma as float)
			endif
			;insertion one-shot only when the label system hasn't classified this as penetration yet
			if abInsertionShot && LastPenReceiver != none && !IsGivingVaginalPenetration() && !IsGivingAnalPenetration()
				printdebug("Contact edge: insertion detected")
				String InsertionSFX = GetSlushSoundToPlay(1, 0.5)
				if InsertionSFX != ""
					PlayContactSound(InsertionSFX, LastPenReceiver)
				endif
			endif
		endif
	elseif PrevContactPenetrating && now - ContactPenLastSeen >= 0.5
		PrevContactPenetrating = false
		PlayPullOutGape()
	endif
EndFunction

;The actor this one is penetrating, going by the labels: whichever OTHER position
;carries a penetration label right now. Exact for the usual single-receiver scene;
;in a group scene it takes the first such position. Read from this effect's OWN
;thread, the way ComputeOwnThreadLabels does: the Director's labels are the
;player's scene, and this effect runs on NPC-only scenes as well.
Actor Function ResolvePenetrationReceiver()
	if !CurrentThread
		return none
	endif
	string sceneid = CurrentThread.GetActiveScene()
	actor[] al = CurrentThread.GetPositions()
	string[] pen = SLOVE_Hentairim_Tags.GetPenetrationLabelarr(sceneid, GetLegacyStageNum(sceneid, CurrentThread.GetActiveStage()), al)
	int z = 0
	while z < al.Length && z < pen.Length
		if al[z] != none && al[z] != actorref && pen[z] != "" && pen[z] != "LDI"
			return al[z]
		endif
		z += 1
	endwhile
	return none
EndFunction

Function ProcessContactEdges()
	if usecontactsfx != 1 || position <= 0 || CurrentThread == none
		return
	endif
	if !HasInteractions
		;SexLab P+ older than 2.19: no contact flags to read - the labels stand in
		;for the penetration edge, as they do in the classic variant
		ProcessLabelEdges()
		return
	endif
	if !InteractionsLive()
		return
	endif
	;P+ 2.19 flags (27, InterType order); partners are looked up by actorref's own flag
	bool[] f = CurrentThread.GetInteractionFlags(actorref)
	if f.Length < 27
		return
	endif
	;falling edges are debounced by elapsed scene time, not poll count - callers
	;poll anywhere between 0.05s and 3s, so counting polls made the window wildly
	;inconsistent; 0.5s tolerates brief detection dropouts at every cadence
	float now = CurrentThread.GetTimeTotal()

	;--- penetration edges (actorref as giver) ---
	bool pen = f[23] || f[25] ;aVaginal / aAnal
	Actor receiver = none
	if pen && !PrevContactPenetrating
		receiver = CurrentThread.GetPartnerByInteractionType(actorref, 23)
		if receiver == none
			receiver = CurrentThread.GetPartnerByInteractionType(actorref, 25)
		endif
	endif
	PenetrationEdge(pen, now, receiver, true)

	;--- kissing start (fire from the higher position of the pair so it plays once) ---
	bool kis = f[0] ;bKissing
	if kis
		ContactKisLastSeen = now
		if !PrevContactKissing
			PrevContactKissing = true
			if !IsKissing()
				Actor kisPartner = CurrentThread.GetPartnerByInteractionType(actorref, 0)
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
	bool deep = f[20] ;pDeepthroat
	bool suck = deep || f[18] ;pOral
	if suck
		ContactSuckLastSeen = now
		if !PrevContactSucked
			PrevContactSucked = true
			if !IsGettingSuckedoff()
				Actor sucker = CurrentThread.GetPartnerByInteractionType(actorref, 18)
				if sucker == none
					sucker = CurrentThread.GetPartnerByInteractionType(actorref, 20)
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

	;--- cunnilingus start (actorref licking a female partner) ---
	;aOral with a FEMALE oral target = cunnilingus; a male target is a blowjob
	;(handled by the oral edge above), so the gender gate keeps the two apart -
	;the same rule the Director's OralLabel bridge uses to assign "CUN". No SLPP
	;cunnilingus flag exists, so it shares the kiss SFX (a wet mouth sound).
	bool cun = false
	if f[17] ;aOral - actorref's mouth is active on a partner
		Actor lickTarget = CurrentThread.GetPartnerByInteractionType(actorref, 17)
		cun = lickTarget != none && Sexlab.GetGender(lickTarget) % 2 == 1
	endif
	if cun
		ContactCunniLastSeen = now
		if !PrevContactCunni
			PrevContactCunni = true
			;same guard as the kiss/oral edges: only fire when the label system has
			;NOT already classified the act - once OralLabel is CUN the steady-state
			;cadence loops this same sound, and the one-shot would stack on top
			if !IsCunnilingus() && Kissing != ""
				printdebug("Contact edge: cunnilingus started (kiss SFX)")
				PlayContactSound(Kissing, actorref)
			endif
		endif
	elseif PrevContactCunni && now - ContactCunniLastSeen >= 0.5
		PrevContactCunni = false
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
		SFXtoPlay = Kissing ; cunnilingus shares the kiss (wet mouth) SFX
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

	bool stagechanged
	bool physicschanged
	if OnPCThread()
		stagechanged = DirectorLastLabelTime != MasterScript.GetDirectorLastLabelTime() || UpdateNow
		physicschanged = DirectorLastPhysicsLabelTime != MasterScript.GetDirectorLastPhysicsLabelTime()
	else
		;NPC-only scene: the Director's label-time stamp tracks the player's thread, not
		;ours. Gate on UpdateNow (set by our own thread's StageStart) or a direct
		;scene/stage change. No physics overlay for NPC scenes (coarse ambient SFX).
		stagechanged = UpdateNow || CurrentSceneID != CurrentThread.GetActiveScene() || currentStageID != CurrentThread.GetActiveStage()
		physicschanged = false
	endif
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
			PPAThrustNoData = false
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
;true when this effect's actor is in the PLAYER's tracked scene - keep the Director's
;rich physics-overlaid labels. False for an NPC-only scene, where we self-compute base
;labels off our own thread (the Director's arrays only cover the player's thread).
bool Function OnPCThread()
	return CurrentThread && CurrentThread.HasPlayer()
endfunction

Function UpdateLabels(actor char)
	printdebug("Updating Labels")
	PrevPenisActionLabel = PenisActionLabel
	if OnPCThread()
		Stimulationlabel = MasterScript.GetStimulationlabel(char)
		PenisActionLabel = MasterScript.GetPenisActionLabel(char)
		OralLabel = MasterScript.GetOralLabel(char)
		EndingLabel = MasterScript.GetEndingLabel(char)
		PenetrationLabel = MasterScript.GetPenetrationLabel(char)
	else
		ComputeOwnThreadLabels(char)
	endif

	Labelsconcat = "1" +Stimulationlabel + "1" + PenisActionLabel + "1" + OralLabel + "1" + PenetrationLabel + "1" + EndingLabel
	PrintDebug("Stimulationlabel :" + Stimulationlabel + ", PenisActionLabel :" + PenisActionLabel + ", OralLabel :" + OralLabel + ", PenetrationLabel :" + PenetrationLabel + ", EndingLabel :" + EndingLabel)

endfunction

;Base tag labels for an NPC-only scene, computed from our OWN thread (no physics
;overlay - coarse but correct). Same stateless tag helpers the Director uses.
Function ComputeOwnThreadLabels(actor char)
	Stimulationlabel = ""
	PenisActionLabel = ""
	OralLabel = ""
	EndingLabel = ""
	PenetrationLabel = ""
	if !CurrentThread
		return
	endif
	int idx = CurrentThread.GetPositionIdx(char)
	if idx < 0
		return
	endif
	string sceneid = CurrentThread.GetActiveScene()
	int stagenum = GetLegacyStageNum(sceneid, CurrentThread.GetActiveStage())
	actor[] al = CurrentThread.GetPositions()
	string[] stim = SLOVE_Hentairim_Tags.GetStimulationlabelarr(sceneid, stagenum, al)
	string[] pa = SLOVE_Hentairim_Tags.GetPenisActionLabelarr(sceneid, stagenum, al)
	string[] orl = SLOVE_Hentairim_Tags.GetOralLabelarr(sceneid, stagenum, al)
	string[] pen = SLOVE_Hentairim_Tags.GetPenetrationLabelarr(sceneid, stagenum, al)
	string[] endlbl = SLOVE_Hentairim_Tags.GetEndingLabelarr(sceneid, stagenum, al)
	if idx < stim.length
		Stimulationlabel = stim[idx]
	endif
	if idx < pa.length
		PenisActionLabel = pa[idx]
	endif
	if idx < orl.length
		OralLabel = orl[idx]
	endif
	if idx < pen.length
		PenetrationLabel = pen[idx]
	endif
	if idx < endlbl.length
		EndingLabel = endlbl[idx]
	endif
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


;--------------------------- menu freeze ------------------------------------
Function PlaySound(String theSound, Actor actorMakingSound, Bool waitForCompletion = True)
	;a spinner's own wait can span a menu opening - don't let the sound land after it
	If SLOVE_Utils.GamePaused()
		Return
	EndIf
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
		SLOVE_Log.WriteLog(actorname + " - SLO VE SFX " + Contents, 0)
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

;-----------------------Hentairim Common Utilities END--------------------------------------
