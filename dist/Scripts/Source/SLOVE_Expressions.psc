Scriptname SLOVE_Expressions extends ActiveMagicEffect
{Per-actor facial expressions for SLO VE scenes. Ported from
 HentairimExpressions; driven by SLOVE_Director labels and JSON face presets.}

SLOVE_Director Property MasterScript Auto
SexLabFramework Property SexLab Auto 
SexLabThread CurrentThread = None
actor Actorref
actor[] actorlist
int position
string role = "c"
int Phase = 1
int ExpressionPhase
string LabelGroup

Event OnEffectStart(Actor akTarget, Actor akCaster)
	Actorref = akTarget
	PrintDebug("Effect Start for " + Actorref.getdisplayname() )	
		
	PerformInitialization()
	
EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
	;last-resort cleanup: fires whenever the spell is removed, even if the
	;OnUpdate chain died and RemoveExpressions never ran for this instance
	resetexpressions()
	RemoveTongue()
EndEvent

Function PerformInitialization()
PrintDebug("Perform Initialization")

	CurrentThread = Sexlab.GetThreadByActor(Actorref)
	if CurrentThread == none
		;the spell landed as the scene was already dying (or on the wrong actor) -
		;bail cleanly instead of limping on with a half-initialized instance
		PrintDebug("no SexLab thread for this actor - removing expressions spell")
		SceneEnded = true
		RemoveExpressions()
		return
	endif
	actorlist = CurrentThread.GetPositions()

	;establish positions
	position = CurrentThread.GetPositionIdx(actorref)

	RegisterForTheEventsWeNeed()

	PrintDebug("actor list" + actorlist)

	;Base Hentairim Preparation
	InitializeConfigandForms()
	HentairimPrepare()	
	CheckHasMFEE()
	printdebug("initialized complete")
	RegisterForSingleUpdate(0.1)
EndFunction

Function RegisterForTheEventsWeNeed()
	printdebug("Registering Event")
	RegisterForModEvent("AnimationEnd", "ExpressionsSceneEnd")
	RegisterForModEvent("SexLabOrgasmSeparate", "ExpressionsOrgasm")
	RegisterForModEvent("StageStart", "ExpressionsOnStageStart")
	;SexLab Survival drives the player's face during its ahegao - yield to it while it's on
	RegisterForModEvent("_SLS_AhegaoStateChange", "OnSLSAhegaoStateChange")

EndFunction

;-----------------------SLS ahegao yield-----------------------
bool SLSAhegaoActive = false

Event OnSLSAhegaoStateChange(string eventName, string argString, float argNum, form sender)
	;SLS ahegao is a player-only face; ignore for NPC instances
	if !IsPlayer
		return
	endif
	if argNum >= 0.5
		SLSAhegaoActive = true
		printdebug("SLS ahegao started - pausing Hentairim expressions")
		;drop our own tongue so it doesn't clash with the ahegao face SLS applies
		RemoveTongue()
	else
		SLSAhegaoActive = false
		printdebug("SLS ahegao ended - resuming Hentairim expressions")
		CachedLabelGroup = "" ;force a fresh full pass on resume
	endif
EndEvent

bool SceneEnded = false
Event ExpressionsSceneEnd(string eventName, string argString, float argNum, form sender)
	;event-driven cleanup: don't depend on the OnUpdate chain surviving to its
	;next tick - a dropped update used to leave face and tongue stuck forever
	if threadid == argstring
		SceneEnded = true
		RemoveExpressions()
	endif
EndEvent


Event ExpressionsOnStageStart(string eventName, string argString, float argNum, form sender)
	if threadid == argstring
		position = currentthread.getpositionidx(actorref)
	endif
EndEvent

float LastOrgasmtime

Event ExpressionsOrgasm(Form akactor, Int thread)
	If akactor != actorRef
		Return
	EndIf
	IsOrgasming = true
	LastOrgasmtime =  CurrentThread.GetTimeTotal()

EndEvent

;-----------------------Breathing micro-pass + preset cache state-----------------------
int TicksUntilFull = 0
int UpdateDeferCount = 0 ;bounded retries while the director is mid-update; force-proceed past the cap so a stuck flag can't freeze the face
int BreathBase0 = 0
bool BreathingAllowed = false
int enablebreathing = 1
float breathingupdateinseconds = 0.55
float tonguemouthopenthreshold = 0.4

;per-pass PPA snapshot (see FullExpressionPass) - the penetration checks read
;these instead of calling the bridge natives on every check
int PassPPACtx = 0
float PassPPADepth = 0.0
;intense flag cached at full-pass time so the 0.55s breathing tick doesn't
;re-derive it with StringUtil calls
bool BreathIntense = false

string CachedLabelGroup = ""
float[] CachedPhase1
float[] CachedPhase2
float[] CachedPhase3
float[] CachedPhase4
float[] CachedPhase5
int[] CachedVariance
bool CacheLoadedIntense = false
bool CacheUsedFallback = false
float[] BlowjobOverrideF
float[] BrokenOverrideF
float[] TongueOutOverrideF
float[] KisOverrideF
float[] CunOverrideF

Event OnUpdate()

	if SceneEnded
		RemoveExpressions()
		return
	endif

	if SLSAhegaoActive
		;SLS owns the player's face right now - don't fight it. Keep the loop
		;ticking so we pick straight back up once the ahegao ends.
		float idleinterval = breathingupdateinseconds
		if idleinterval <= 0.0
			idleinterval = 0.5
		endif
		RegisterForSingleUpdate(idleinterval)
		return
	endif

	bool breathingon = enablebreathing == 1 && breathingupdateinseconds > 0.0

	if !breathingon || TicksUntilFull <= 0
		if !FullExpressionPass()
			;director mid-update: retry shortly via the chain instead of pinning
			;this thread in a wait loop (N actor instances would all block at once)
			RegisterForSingleUpdate(0.2)
			return
		endif

		if SceneEnded
			;the scene ended while this cycle was mid-application - the event
			;handler's reset already ran, so re-clean the frame we just applied
			RemoveExpressions()
			return
		endif

		float fullinterval = GetExpressionUpdateSeconds()
		int fullticks = 0
		if breathingon
			fullticks = ((fullinterval / breathingupdateinseconds) + 0.5) as int
		endif
		if fullticks <= 1
			TicksUntilFull = 0
			RegisterForSingleUpdate(fullinterval)
		else
			TicksUntilFull = fullticks - 1
			RegisterForSingleUpdate(breathingupdateinseconds)
		endif
	else
		TicksUntilFull -= 1
		BreathePass()

		if SceneEnded
			RemoveExpressions()
			return
		endif
		RegisterForSingleUpdate(breathingupdateinseconds)
	endif

EndEvent

;returns false when the director is mid-update and the pass should be retried
;shortly by the caller; true when the pass ran (or the scene ended)
Bool Function FullExpressionPass()

	;Ends if actor is no longer in scene but magic stuck for some reason
	if MasterScript.AnimationisEnding() || !Sexlab.GetThreadByActor(actorref)
		SceneEnded = true
		RemoveExpressions()
		return true
	endif

	if MasterScript.isupdating()
		UpdateDeferCount = UpdateDeferCount + 1
		if UpdateDeferCount < 25 ;~5s of 0.2s retries before giving up
			printdebug("Director updating - deferring this expression pass")
			return false
		endif
		printdebug("Director still updating after failsafe - proceeding anyway")
	endif
	UpdateDeferCount = 0

	;one PPA snapshot per pass: the penetration checks below may run several
	;times this cycle, and each native getter takes the bridge's lock
	PassPPACtx = 0
	PassPPADepth = 0.0
	if AudioUtilPPA.IsConnected()
		PassPPACtx = AudioUtilPPA.GetContext(actorref)
		if PassPPACtx > 0
			PassPPADepth = AudioUtilPPA.GetDepth(actorref)
		endif
	endif

	HentairimUpdateStageData()

	;if still orgasming, maintain orgasm face
	if GetSecondsSinceLastOrgasm() > 4
		IsOrgasming = false
	endif

	;set Role
	if IsVictim && !isbroken()
		Role = "v"
	else
		Role = "c"
	endif

	;Check if should add tongue or ahegao
	if !IsBroken() && HasMFEE && EnabledMFEEAhegao == 1
		MFEEAddAhegao = false
	endif

	if IsSuckingoffOther() && removetongueonblowjob == 1
		RemoveTongue()
		printdebug("Removing Tongue during  blowjob")
	elseif IsBroken() && HasMFEE && EnabledMFEEAhegao == 1
		RemoveTongue()
		MFEEAddAhegao = true
		printdebug("Starting MFEE Ahegao")
	endif

	;jaw gate: retry a suppressed tongue, or drop an active one whose mouth stayed closed
	UpdateTongueJawGate()

	if IsUnconcious()
		MfgConsoleFunc.SetModifier(actorref, 0, 100) ;left blink
		MfgConsoleFunc.SetModifier(actorref, 1, 100) ;right blink
		if !AudioUtil.IsLipSyncActive(actorref) ;the DLL owns the jaw while a line plays
			MfgConsoleFunc.SetPhoneme(actorref,0,60) ; aah
		endif
		BreathingAllowed = false
		AdvancePhase()
		return true
	endif

	if !BlowjobOverrideF
		;stale save with an older script version mid-scene - reload config and presets
		InitializeConfigandForms()
	endif

	LabelGroup = Role + GetHentaiExpression() + ExpressionGroup
	string PhaseLookup = LabelGroup + Phase
	printdebug("Expression Looking up : " + PhaseLookup)

	EnsurePhaseCache()

	int varPct = CachedVariance[Phase - 1]
	if varPct < 0
		printdebug(" Expressions : " + PhaseLookup + " missing in " + ExpressionsFile + " even after fallback. Skipping expression this cycle.")
		BreathingAllowed = false
		AdvancePhase()
		return true
	endif

	bool mouthblowjob = IsSuckingoffOther() || HasDeviousGag(actorref)
	;enableahegao gates only the hugePP arm; a broken actor always gets the broken
	;face. The hugePP ahegao is measurement-gated: the labels decide penetration,
	;and MeasuredPenetrationActive() suppresses it when the PPA bridge reports the
	;partner isn't actually inserted (returns true when no bridge, so labels alone
	;drive it then)
	bool brokenface = (enableahegao == 1 && ishugepp && IsgettingPenetrated() && MeasuredPenetrationActive()) || (IsBroken() && (PenisActionlabel != "LDI" || Penetrationlabel != "LDI" || StimulationLabel != "LDI" || OralLabel != "LDI"))

	float[] result = BuildTickPreset(GetCachedPhase(Phase), varPct, mouthblowjob, brokenface)

	;MFEE side effects, hoisted out of the per-cell loops so they run once per cycle
	if MFEEAddAhegao
		if MuFacialExpressionExtended.GetExpressionValueByNumber(actorref,0,1) != 100
			MuFacialExpressionExtended.SetExpressionByNumber(actorref,0,0,100) ;ahegao 1
		endif
		;make sure tongue out and tongue down is not applied as ahegao already has tongue out and down
		if MuFacialExpressionExtended.GetExpressionValueByNumber(actorref,8,0) != 0 || MuFacialExpressionExtended.GetExpressionValueByNumber(actorref,2,0) != 0
			MuFacialExpressionExtended.SetExpressionByNumber(actorref,8,0,0) ;tongueout
			MuFacialExpressionExtended.SetExpressionByNumber(actorref,8,2,0) ;tongue down
		endif
		if MfgConsoleFunc.GetModifier(actorref, 11) != 50
			MfgConsoleFunc.SetModifier(actorref, 11, ahegaolookupmodifier) ;look up 50
		endif
	else
		if !mouthblowjob && MFEEAddTongue
			;apply MFEE tongue out and down
			if MuFacialExpressionExtended.GetExpressionValueByNumber(actorref,8,0) != 100 || MuFacialExpressionExtended.GetExpressionValueByNumber(actorref,2,0) != 100
				MuFacialExpressionExtended.SetExpressionByNumber(actorref,8,0,100) ;tongueout
				MuFacialExpressionExtended.SetExpressionByNumber(actorref,8,2,100) ;tongue down
			endif
		endif
		if brokenface && HasMFEEVanillaRace && MuFacialExpressionExtended.GetExpressionValueByNumber(actorref,0,0) != 100
			MuFacialExpressionExtended.SetExpressionByNumber(actorref,0,0,100) ;ahegao 1
		endif
	endif

	;baseline for the cheap breathing ticks between full passes - taken from the
	;preset BEFORE any lipsync yield below overwrites the mouth channels
	BreathBase0 = (result[0] * 100.0) as int

	;lipsync yield (AudioUtil contract): while the DLL drives this actor's mouth
	;from the playing clip's envelope, don't fight it over the jaw - retarget the
	;two channels it owns (0 Aah / 1 BigAah) to their CURRENT values so the smooth
	;apply is a no-op on them while the rest of the face still updates
	if AudioUtil.IsLipSyncActive(actorref)
		int curAah = MfgConsoleFunc.GetPhoneme(actorref, 0)
		int curBigAah = MfgConsoleFunc.GetPhoneme(actorref, 1)
		if curAah >= 0
			result[0] = curAah / 100.0
		endif
		if curBigAah >= 0
			result[1] = curBigAah / 100.0
		endif
	endif

	MfgConsoleFuncExt.ApplyExpressionPresetSmooth(actorref, result, false)
	BreathIntense = Isintense()
	BreathingAllowed = !(mouthblowjob || MFEEAddTongue || MFEEAddAhegao || EquippedTongue() || IsKissing() || IsCunnilingus())

	AdvancePhase()

	return true
EndFunction

Function AdvancePhase()
	if phase >= 5
		phase = 1
	else
		phase += 1
	endif
EndFunction

Function BreathePass()
	;cheap sub-tick: no MasterScript/SexLab/Json calls, just a mouth nudge around the last applied face
	if !BreathingAllowed
		return
	endif

	;a voice line is moving this mouth right now - breathing would stomp the
	;DLL's per-frame Aah writes at 0.55s cadence. It resumes next tick after
	;the clip ends (lipsync zeroes the mouth, the nudge reopens it naturally)
	if AudioUtil.IsLipSyncActive(actorref)
		return
	endif

	int amp = 8
	if BreathIntense ;cached at full-pass time - no StringUtil calls per tick
		amp = 15
	endif

	int v = BreathBase0 + Utility.RandomInt(0 - amp, amp)
	if v < 0
		v = 0
	elseif v > 100
		v = 100
	endif

	MfgConsoleFuncExt.SetPhoneme(actorref, 0, v, 0.4)
EndFunction

Float[] Function BuildTickPreset(float[] base, int varPct, bool mouthblowjob, bool brokenface)
	;build a fresh preset from the cached base - the cached arrays are shared and must never be written to
	float[] result = new float[32]

	bool mouthtongueout = EquippedTongue()
	bool mouthkis = IsKissing()
	bool mouthcun = IsCunnilingus()
	bool cowgirl = IsCowgirl()
	bool doggy = false
	if !MFEEAddAhegao && !brokenface && !cowgirl
		doggy = SceneTagDoggy && IsgettingPenetrated()
	endif

	;phonemes 0-15
	int i = 0
	while i <= 15
		if MFEEAddAhegao
			if i == 1
				result[i] = ahegaophonemebigaah / 100.0 ;phoneme 1 big aah
			else
				result[i] = 0.0
			endif
		elseif mouthblowjob
			result[i] = BlowjobOverrideF[i]
		elseif MFEEAddTongue
			if i == 1
				result[i] = tonguephonemebigaah / 100.0
			elseif i == 11
				result[i] = tonguephonemeoh / 100.0
			else
				result[i] = 0.0
			endif
		elseif mouthtongueout
			result[i] = TongueOutOverrideF[i]
		elseif mouthkis
			result[i] = KisOverrideF[i]
		elseif mouthcun
			result[i] = CunOverrideF[i]
		else
			float lo = base[i] * (100 - varPct) / 100.0
			float hi = base[i] * (100 + varPct) / 100.0
			if lo < 0.0
				lo = 0.0
			endif
			if hi > 1.0
				hi = 1.0
			endif
			result[i] = Utility.RandomFloat(lo, hi)
		endif
		i += 1
	endwhile

	;modifiers 16-29 (base values pass through unless an override claims them)
	i = 16
	while i <= 29
		if MFEEAddAhegao
			if i == 27
				result[i] = base[i] ;look up is driven separately via SetModifier
			else
				result[i] = 0.0
			endif
			i += 1
		elseif brokenface
			result[i] = BrokenOverrideF[i]
			i += 1
		elseif cowgirl && i == 24
			result[24] = 1.0 ;look downwards if riding
			result[25] = base[25]
			result[26] = base[26]
			result[27] = base[27]
			i = 28
		elseif doggy && i == 24
			result[24] = base[24]
			result[25] = base[25]
			result[26] = base[26]
			result[27] = base[27]
			result[lookdirection + 16] = 1.0
			i = 28
		else
			result[i] = base[i]
			i += 1
		endif
	endwhile

	result[30] = base[30]
	if !MFEEAddAhegao && brokenface ;match indices 16-29, which use brokenface (IsBroken is always false in this port)
		result[31] = BrokenOverrideF[31]
	else
		result[31] = base[31]
	endif

	return result
EndFunction

Function EnsurePhaseCache()
	if CachedLabelGroup == LabelGroup && CachedVariance
		if !CacheUsedFallback || CacheLoadedIntense == Isintense()
			return
		endif
	endif

	CacheUsedFallback = false
	CacheLoadedIntense = Isintense()
	if !CachedVariance
		CachedVariance = new int[5]
	endif

	string fallbackExpr = "grunt"
	if CacheLoadedIntense
		fallbackExpr = "intensegrunt"
	endif

	int p = 1
	while p <= 5
		string lookupkey = LabelGroup + p
		string[] arr = papyrusutil.stringsplit(JsonUtil.GetStringValue(ExpressionsFile, lookupkey, ""), ",")
		if arr.length < 33
			printdebug(" Expressions : " + lookupkey + " missing/malformed in " + ExpressionsFile + " (" + arr.length + " items). Falling back to generic " + fallbackExpr + " face.")
			lookupkey = Role + fallbackExpr + ExpressionGroup + p
			arr = papyrusutil.stringsplit(JsonUtil.GetStringValue(ExpressionsFile, lookupkey, ""), ",")
			CacheUsedFallback = true
		endif
		if arr.length < 33
			printdebug(" Expressions : fallback " + lookupkey + " also missing in " + ExpressionsFile + ".")
			CachedVariance[p - 1] = -1
		else
			CachedVariance[p - 1] = arr[32] as int
			if p == 1
				CachedPhase1 = ConvertPresetToFloats(arr)
			elseif p == 2
				CachedPhase2 = ConvertPresetToFloats(arr)
			elseif p == 3
				CachedPhase3 = ConvertPresetToFloats(arr)
			elseif p == 4
				CachedPhase4 = ConvertPresetToFloats(arr)
			else
				CachedPhase5 = ConvertPresetToFloats(arr)
			endif
		endif
		p += 1
	endwhile

	CachedLabelGroup = LabelGroup
EndFunction

Float[] Function GetCachedPhase(int p)
	;read-only: callers must never write into the returned array
	if p == 1
		return CachedPhase1
	elseif p == 2
		return CachedPhase2
	elseif p == 3
		return CachedPhase3
	elseif p == 4
		return CachedPhase4
	endif
	return CachedPhase5
EndFunction

Float[] Function ConvertPresetToFloats(String[] values)
	float[] result = new float[32]
	int srclen = values.length
	int i = 0
	while i < 32
		if i >= srclen || !values[i]
			result[i] = 0.0
		elseif i == 30
			result[i] = values[i] as float
		else
			result[i] = (values[i] as float) / 100.0
		endif
		i += 1
	endwhile
	return result
EndFunction

Float Function GetMeasuredMouthOpen()
	;max of the mouth-opening phonemes, 0.0-1.0, or -1.0 when unreadable: an
	;all-zero reading is indistinguishable from a failed native read, so 0 is
	;treated as unknown too - callers must fail open on -1.0
	int best = MfgConsoleFunc.GetPhoneme(actorref, 0)
	int p = MfgConsoleFunc.GetPhoneme(actorref, 1)
	if p > best
		best = p
	endif
	p = MfgConsoleFunc.GetPhoneme(actorref, 5)
	if p > best
		best = p
	endif
	p = MfgConsoleFunc.GetPhoneme(actorref, 6)
	if p > best
		best = p
	endif
	p = MfgConsoleFunc.GetPhoneme(actorref, 7)
	if p > best
		best = p
	endif
	p = MfgConsoleFunc.GetPhoneme(actorref, 9)
	if p > best
		best = p
	endif
	if best <= 0
		return -1.0
	endif
	if best > 100
		best = 100
	endif
	return best / 100.0
EndFunction

int TongueClosedTicks = 0
bool TongueGateBlocked = false

Function UpdateTongueJawGate()
	if TongueGateBlocked
		;a tongue roll was suppressed by the jaw gate - the labels (and the
		;winning chance roll) still stand, so retry now that the face moved on
		TongueGateBlocked = false
		printdebug("Tongue jaw gate: retrying suppressed tongue")
		AddTongue()
		return
	endif

	if !(MFEEAddTongue || EquippedTongue())
		TongueClosedTicks = 0
		return
	endif

	float openness = GetMeasuredMouthOpen()
	if openness >= 0.0 && openness < tonguemouthopenthreshold
		;require two consecutive confident readings (~2s apart, past any smooth
		;transition) before stripping the tongue, to avoid churn on a stale read
		TongueClosedTicks += 1
		if TongueClosedTicks >= 2
			printdebug("Tongue jaw gate: mouth measured closed twice (" + openness + "), removing tongue.")
			RemoveTongue()
			TongueClosedTicks = 0
		endif
	else
		TongueClosedTicks = 0
	endif
EndFunction


;-------------------------------Hentairim Expressions Functions START---------------------------------
function RemoveExpressions()
	resetexpressions()
	RemoveTongue()
	Spell ExpressionsSpell = Game.GetFormFromFile(0x800, "SLOVE.esp") as Spell
	actorref.RemoveSpell(ExpressionsSpell)
EndFunction

string ExpressionGroup = "a"
String MasksFile  = "SLOVE/Masks.json"
String ExpressionsFile = ""

String[] Masks
String[] Maskslots
string[] exclude
int lookdirection = 9

bool IsPlayer
int Gender ;sexlab.GetGender: 0 male, 1 female, 2/3 creature - must NOT be bool
actor playerref
int enabletongue
int fhutonguetype
int removetongueonblowjob
int cunusetongue
int enableahegao
int chancetostickouttongueduringintense
int chancetostickouttongueduringattacking
int enableprintdebug
Float pcnonintenseexpressionupdateinseconds
Float pcintenseexpressionupdateinseconds
Float npcnonintenseexpressionupdateinseconds
Float npcintenseexpressionupdateinseconds
	  
Function InitializeConfigandForms()
printdebug("------------------Initialize Hentai Expressions Configs and Forms Start-------------------------")
	playerref = game.getplayer()
	IsPlayer = actorref == playerref
	Gender = sexlab.GetGender(ActorRef)

	;seed the SLS ahegao state in case it's already active when this instance starts
	if IsPlayer
		SLSAhegaoActive = StorageUtil.GetIntValue(None, "_SLS_IsAhegaoing", 0) == 1
	endif
	
	if IsPlayer
		ExpressionsFile = "SLOVE/PCExpressions.json"
	elseif gender == 0	;Male
		ExpressionsFile = "SLOVE/MaleExpressions.json"
	elseif gender == 1	;female
		ExpressionsFile ="SLOVE/FemaleExpressions.json"	
	endif

	BlowjobOverrideF = ConvertPresetToFloats(papyrusutil.stringsplit(JsonUtil.GetStringValue(ExpressionsFile,"blowjobphonemeoverride","") ,","))
	BrokenOverrideF = ConvertPresetToFloats(papyrusutil.stringsplit(JsonUtil.GetStringValue(ExpressionsFile,"brokenmodifieroverride","") ,","))
	TongueOutOverrideF = ConvertPresetToFloats(papyrusutil.stringsplit(JsonUtil.GetStringValue(ExpressionsFile,"tongueoutphonemeoverride","") ,","))
	KisOverrideF = ConvertPresetToFloats(papyrusutil.stringsplit(JsonUtil.GetStringValue(ExpressionsFile,"kisphonemeoverride","") ,","))
	CunOverrideF = ConvertPresetToFloats(papyrusutil.stringsplit(JsonUtil.GetStringValue(ExpressionsFile,"cunphonemeoverride","") ,","))
	CachedLabelGroup = "" ;presets may have changed - force a phase cache reload
	Masks = papyrusutil.stringsplit(JsonUtil.GetStringValue(MasksFile,"masks","") ,",")
	Maskslots = papyrusutil.stringsplit(JsonUtil.GetStringValue(MasksFile,"maskslots","") ,",")
	exclude = papyrusutil.stringsplit(JsonUtil.GetStringValue(MasksFile,"exclude","") ,",")
	enabletongue =  SLOVE_Config.GetInt("expressions.enabletongue", 0)
	fhutonguetype = SLOVE_Config.GetInt("expressions.fhutonguetype", 0)
	removetongueonblowjob = SLOVE_Config.GetInt("expressions.removetongueonblowjob", 0)
	cunusetongue = SLOVE_Config.GetInt("expressions.cunusetongue", 0)
	enableahegao = SLOVE_Config.GetInt("expressions.enableahegao", 0)
	chancetostickouttongueduringintense = SLOVE_Config.GetInt("expressions.chancetostickouttongueduringintense", 0)
	chancetostickouttongueduringattacking = SLOVE_Config.GetInt("expressions.chancetostickouttongueduringattacking", 0)
	enableprintdebug = SLOVE_Config.GetInt("expressions.printdebug", 0)
	
	enablebreathing = SLOVE_Config.GetInt("expressions.enablebreathing", 1)
	breathingupdateinseconds = SLOVE_Config.GetFloat("expressions.breathingupdateinseconds", 0.55)
	tonguemouthopenthreshold = SLOVE_Config.GetFloat("expressions.tonguemouthopenthreshold", 0.4)
	pcnonintenseexpressionupdateinseconds = SLOVE_Config.GetFloat("expressions.pcnonintenseexpressionupdateinseconds", 3.0)
	pcintenseexpressionupdateinseconds = SLOVE_Config.GetFloat("expressions.pcintenseexpressionupdateinseconds", 3.0)
	npcnonintenseexpressionupdateinseconds = SLOVE_Config.GetFloat("expressions.npcnonintenseexpressionupdateinseconds", 3.0)
	npcintenseexpressionupdateinseconds = SLOVE_Config.GetFloat("expressions.npcintenseexpressionupdateinseconds", 3.0)
	
	printdebug("enabletongue : " +enabletongue)
	printdebug("fhutonguetype : " +fhutonguetype)
	printdebug("removetongueonblowjob : " +removetongueonblowjob)
	printdebug("cunusetongue : " + cunusetongue)
	printdebug("enableahegao : "+enableahegao)
	printdebug("chancetostickouttongueduringintense : "+chancetostickouttongueduringintense)
	printdebug("chancetostickouttongueduringattacking : "+chancetostickouttongueduringattacking)
	printdebug("enableprintdebug : "+enableprintdebug)
	printdebug("enablebreathing : "+enablebreathing)
	printdebug("breathingupdateinseconds : "+breathingupdateinseconds)
	printdebug("tonguemouthopenthreshold : "+tonguemouthopenthreshold)
	printdebug("pcnonintenseexpressionupdateinseconds : "+pcnonintenseexpressionupdateinseconds)
	printdebug("pcintenseexpressionupdateinseconds : "+pcintenseexpressionupdateinseconds)
	printdebug("npcnonintenseexpressionupdateinseconds : "+npcnonintenseexpressionupdateinseconds)
	printdebug("npcintenseexpressionupdateinseconds : "+npcintenseexpressionupdateinseconds)
	
	InitializeAddNPCTongue()
printdebug("------------------Initialize Hentai Expressions Configs and Forms END-------------------------")
endfunction

Function ResetHentaiExpressionGroup()
int type
	Type = Utility.Randomint(1,3)	
	if type == 1
		ExpressionGroup = "a"
	elseif type == 2
		ExpressionGroup = "b"
	elseif type == 3
		ExpressionGroup = "c"
	endif

	lookdirection = utility.Randomint(8,10)
	CachedLabelGroup = "" ;group letter is part of the cache key - force reload
endfunction


Bool Function EquippedTongue()
	if !FHUTongueTypeArmor
		return false
	endif
	return actorref.IsEquipped(FHUTongueTypeArmor)
EndFunction

Function AddTongue()

	printdebug("AddTongue: Starting. MFEEAddAhegao=" + MFEEAddAhegao + " WearingMask=" + (WearingMask(actorref) != none) + " IsSuckingoffOther=" + IsSuckingoffOther() + " EnableTongue=" + EnableTongue + " HasDeviousGag=" + HasDeviousGag(actorref) + " IsUnconcious=" + IsUnconcious() + " EquippedTongue=" + EquippedTongue())

	if MFEEAddAhegao || WearingMask(actorref) != none || IsSuckingoffOther() || EnableTongue != 1 || HasDeviousGag(actorref) || IsUnconcious() || EquippedTongue()
		printdebug("AddTongue: Conditions blocked tongue, exiting early.")
		return
	endif

	;jaw gate: don't show a tongue through closed lips. Only a confidently-low
	;nonzero reading blocks (unreadable/zero fails open); a blocked roll is
	;retried by UpdateTongueJawGate on the next full pass
	float openness = GetMeasuredMouthOpen()
	if openness >= 0.0 && openness < tonguemouthopenthreshold
		printdebug("AddTongue: mouth not open enough (" + openness + "), deferring tongue.")
		TongueGateBlocked = true
		return
	endif

	if HasMFEE && EnabledMFEETongue == 1
		printdebug("AddTongue: Using MFEE tongue expression.")
		MFEEAddTongue = true
	else
		if Game.GetModByName("sr_fillherup.esp") != 255
			printdebug("AddTongue: sr_fillherup.esp detected, equipping FHUTongueTypeArmor if available.")
			armor temptongue 
			
			if FHUTongueTypeArmor
				printdebug("AddTongue: Equipping FHUTongueTypeArmor=" + FHUTongueTypeArmor)
				actorref.AddItem(FHUTongueTypeArmor, abSilent = true)
				actorref.EquipItem(FHUTongueTypeArmor, abSilent = true)
			else
				printdebug("AddTongue: FHUTongueTypeArmor not defined, skipping equip.")
			endif
		else
			printdebug("AddTongue: sr_fillherup.esp not detected, skipping FHU tongue.")
		endif
	endif
EndFunction

Function RemoveTongue()

if HasMFEE && MFEEAddTongue
	MFEEAddTongue = false
else
	if EquippedTongue()
	
		actorref.unEquipItem(FHUTongueTypeArmor, abSilent=true)
		actorref.removeItem(FHUTongueTypeArmor , abSilent=true)
	
	endif
endif
endfunction

Function unequipmask(actor char)
Armor Mask = wearingmask(char)
if Mask
	actorref.unEquipItem(Mask, abSilent=true)
endif

endfunction

Armor Function WearingMask(actor char)
if Maskslots.length == 0
	return none
endif

int slotlength = Maskslots.length
int slotindex = 0
int masklength = Masks.length
int maskindex = 0
int excludelength = exclude.length
int excludeindex = 0
Armor Mask
Armor WearingMask = none
string Maskname

	while slotindex < slotlength
		Mask = char.GetWornForm(Armor.GetMaskForSlot(Maskslots[slotindex] as int)) as armor
		if Mask
			Maskname = Mask.getname()
		else
			Maskname = ""
		endif
		excludeindex = 0
		maskindex = 0
		
		;check to see if its excluded opened Mask
		while excludeindex < excludelength
			if stringutil.find(Maskname ,Masks[excludeindex]) > -1
				maskindex = 100
				excludeindex = 100
			endif
			excludeindex += 1
		endwhile
		
		;check to see if its wearing mask
		while maskindex < masklength
			if stringutil.find(Maskname ,Masks[maskindex]) > -1
				WearingMask = Mask
				maskindex = 100
				slotindex = 100
			endif
			maskindex += 1
		endwhile

	slotindex += 1
	endwhile
	printdebug("Wearing Mask :" + WearingMask)
return WearingMask 
endfunction

Bool Function HasDeviousGag(Actor char)
	if has_MagicEffect(char, 0x2b077, "Devious Devices - Integration.esm")
		return true
	endif
	return false
EndFunction

bool function has_MagicEffect(actor a, int id, string filename)
	MagicEffect ME = get_form(id, filename) as MagicEffect
	if !ME
		return false
	endif
	return a.HasMagicEffect(ME)
endfunction


Bool Function IsUnconcious()
	;scene tags are constant per scene - SceneTagFaint refreshes on scene change
	return SceneTagFaint && position == 0
endfunction



int function  GetFullEnjoyment()
	int enjoyment = CurrentThread.GetEnjoyment(actorref) as int
	printdebug("Enjoyment : " + enjoyment)
	return enjoyment
endfunction

bool IsOrgasming

String Function GetHentaiExpression()

string 	HentaiScenario = StorageUtil.GetStringValue(None, "HentaiScenario", "")
if !isplayer || (isplayer && HentaiScenario == "")
	bool giving = IsGivingAnalPenetration() || IsGivingVaginalPenetration() || IsGettingSuckedoff()
	int enj = 0
	if gender == 0
		enj = GetFullEnjoyment() ;one thread call, reused by both branches below
	endif
	if IsOrgasming
		HentaiScenario = "orgasm"
	elseif giving && !Isintense()
		HentaiScenario = "grunt"
	elseif giving && Isintense()
		HentaiScenario = "intensegrunt"
	elseif enj > 70 && !Isintense() && gender == 0
		HentaiScenario = "closetoorgasm"
	elseif enj > 70 && Isintense() && gender == 0
		HentaiScenario = "closetoorgasmintense"
	elseif (IsCowgirl() || IsGivingAnalPenetration() || IsGivingVaginalPenetration() ) && !IsVictim
		HentaiScenario = "attacking"
	elseif IsGettingStimulated()
		if Isintense()
			HentaiScenario = "grunt"
		else
			HentaiScenario = "Leadin"
		endif
	elseif IsEnding()
		if IsVictim
			HentaiScenario = "unamusedending"
		else
			HentaiScenario = "Panting"
		endif
	else
		if Isintense()
			HentaiScenario = "intensegrunt"
		else
			HentaiScenario = "grunt"
		endif
	Endif
endif

return HentaiScenario

EndFunction

function resetexpressions()

;SLS owns the player's face during its ahegao and wants it to persist past the
;scene end - don't wipe it. SLS clears its own face when its ahegao finishes.
if SLSAhegaoActive
	return
endif

;0.1 = near-instant: the default 0.75 makes the reset itself a slow smooth
;transition that a concurrently-interpolating apply can win against
MfgConsoleFuncExt.resetmfg(actorref, 0.1)
if hasmfee || HasMFEEVanillaRace
	MuFacialExpressionExtended.RevertExpression(actorref)
endif

endfunction


Bool HasMFEE = false
Bool HasMFEEVanillaRace = false
int  EnabledMFEETongue = 0
int EnabledMFEEAhegao = 0
bool MFEEAddTongue = false
bool MFEEAddAhegao = false
int ahegaophonemebigaah
int tonguephonemebigaah
int tonguephonemeoh
int ahegaolookupmodifier
String EnableErinMFEE  = "SLOVE/ErinMFEEConfig.json"

Function CheckHasMFEE()
	;check if has MFEE
	if MuFacialExpressionExtended.GetVersion() > 0   &&  (actorref.GetRace().getname() =="Erin" || actorref.GetRace().getname() =="Elin" )
		HasMFEE = true
		EnabledMFEETongue = JsonUtil.GetIntValue(EnableErinMFEE,"enablemfeetongue",0)  
		EnabledMFEEAhegao = JsonUtil.GetIntValue(EnableErinMFEE,"enablemfeeahegao",0)
		ahegaophonemebigaah = JsonUtil.GetIntValue(EnableErinMFEE,"ahegaophonemebigaah",0)
		tonguephonemebigaah = JsonUtil.GetIntValue(EnableErinMFEE,"tonguephonemebigaah",0)
		tonguephonemeoh	 = JsonUtil.GetIntValue(EnableErinMFEE,"tonguephonemeoh",0)	
		ahegaolookupmodifier = JsonUtil.GetIntValue(EnableErinMFEE,"ahegaolookupmodifier",0)
    elseif MuFacialExpressionExtended.GetVersion() > 0
		HasMFEEVanillaRace = true
	endif
endfunction


Float function GetSecondsSinceLastOrgasm()

return CurrentThread.Gettimetotal() - LastOrgasmtime 

endfunction

float function GetExpressionUpdateSeconds()
if IsPlayer
	if Isintense()
		return pcintenseexpressionupdateinseconds
	else
		return pcnonintenseexpressionupdateinseconds
	endif
else
	if Isintense()
		return npcintenseexpressionupdateinseconds
	else
		return npcnonintenseexpressionupdateinseconds
	endif	
endif

EndFunction

Bool function isDependencyReady(String modname)
  int index = Game.GetModByName(modname)
  if index == 255 || index == -1
    return false
  else
    return true
  endif
endfunction

string NPCTongueFile  = "SLOVE/NPCTongue.json"
int enablenpctongue = 0

Function InitializeAddNPCTongue()
printdebug("enablenpctongue : " + enablenpctongue)
enablenpctongue = JsonUtil.GetIntValue(NPCTongueFile, "enablenpctongue", 0)

FHUTongueTypeArmor =  GetTongueType()
endfunction 

armor FHUTongueTypeArmor

Armor function GetTongueType()

	if FHUTongueType == 0
		FHUTongueType = Utility.RandomInt(1, 10)
	endif	
	string name = actorref.getdisplayname()
	int TongueType
	armor Tongue
	if isplayer
		TongueType = FHUTongueType
	elseif enablenpctongue == 1
		TongueType = JsonUtil.GetIntValue(NPCTongueFile, name, 99)
	endif
	
	if TongueType == 1
	Tongue = Game.GetFormFromFile(0x263B2, "sr_fillherup.esp") as Armor
elseif  TongueType == 2
	Tongue = Game.GetFormFromFile(0x263B3, "sr_fillherup.esp") as Armor
elseif  TongueType == 3
	Tongue = Game.GetFormFromFile(0x263B4, "sr_fillherup.esp") as Armor
elseif  TongueType == 4
	Tongue = Game.GetFormFromFile(0x263B5, "sr_fillherup.esp") as Armor
elseif  TongueType == 5
	Tongue = Game.GetFormFromFile(0x263B6, "sr_fillherup.esp") as Armor	
elseif  TongueType == 6
	Tongue = Game.GetFormFromFile(0x263B7, "sr_fillherup.esp") as Armor	
elseif  TongueType == 7
	Tongue = Game.GetFormFromFile(0x263B8, "sr_fillherup.esp") as Armor	
elseif  TongueType == 8
	Tongue = Game.GetFormFromFile(0x263B9, "sr_fillherup.esp") as Armor	
elseif  TongueType == 9
	Tongue = Game.GetFormFromFile(0x263BA, "sr_fillherup.esp") as Armor	
elseif  TongueType == 10
	Tongue = Game.GetFormFromFile(0x263BB, "sr_fillherup.esp") as Armor	
endif

FHUTongueTypeArmor = Tongue
return Tongue
endfunction


;-------------------------------Hentairim Expressions Functions END---------------------------------

;-----------------------BASE HENTAIRIM Update Functions-----------------------------

Bool IsHugePP
;scene tags are constant per scene: queried once on scene/label change instead
;of 3 HasSceneTag externals per expression pass
bool SceneTagFaint = false
bool SceneTagDoggy = false
string CurrentSceneID = ""
string currentStageID = ""
Int currentStage = -1
Int ThreadID = -1
bool IsVictim
float DirectorLastLabelTime
float DirectorLastPhysicsLabelTime

Function HentairimPrepare()
	printdebug("--------------------Hentairim Prepare Initial Data START-----------------")
	ThreadID = CurrentThread.GetThreadID()
	IsHugePP = IsHugePP()
	HentairimUpdateStageData()
	IsVictim = IsVictim(Actorref)
	
	printdebug("ThreadID : " + ThreadID)
	printdebug("Partner IsHugePP : " + IsHugePP)

	printdebug("--------------------Hentairim Prepare Initial Data END-----------------")
endfunction



Function HentairimUpdateStageData()
	printdebug("Updating Labels")

	printdebug("DirectorLastLabelTimeCheck: local=" + DirectorLastLabelTime + " master=" + MasterScript.GetDirectorLastLabelTime())
	if DirectorLastLabelTime != MasterScript.GetDirectorLastLabelTime() || DirectorLastPhysicsLabelTime != MasterScript.GetDirectorLastPhysicsLabelTime()
		printdebug("Animation, Stage or Physics Labels Different. Updating Stage Data")
		TongueGateBlocked = false ;stale gate-deferred rolls don't survive a label change
		string prevSceneID = CurrentSceneID
		CurrentSceneID = CurrentThread.GetActiveScene()
		currentStageID = CurrentThread.GetActiveStage()
		currentstage = GetLegacyStageNum(CurrentSceneID, currentStageID)
		if CurrentSceneID != prevSceneID
			;new scene - refresh the per-scene tag cache
			SceneTagFaint = CurrentThread.HasSceneTag("faint") || CurrentThread.HasSceneTag("sleep") || CurrentThread.HasSceneTag("necro")
			SceneTagDoggy = CurrentThread.HasSceneTag("Doggy") || CurrentThread.HasSceneTag("Doggystyle") || CurrentThread.HasSceneTag("Doggy Style")
		endif
		
		UpdateLabels(actorref)	

		printdebug("PC Thread Position : " + CurrentThread.GetPositionIdx(Actorref))
		printdebug("current Animation : " + CurrentSceneID)
		printdebug("current StageID : " + currentStageID)
		printdebug("current stage number: " + currentstage)
		

		int rand = Utility.RandomInt(1,100)
		float chancemultiplier = 1
		if IsBroken()
			chancemultiplier = chancemultiplier * 2
		EndIf
		
		if EquippedTongue()
			if Utility.RandomInt(1,2) == 1
				RemoveTongue()
			EndIf
		else
			if EnableTongue == 1
				;if !EquippedTongue() && (IsCunnilingus() && cunusetongue == 1) || ((IsIntense() || isbroken()) && IsGettingPenetrated() && rand <= chancetostickouttongueduringintense * chancemultiplier) || ((IsCowgirl() || IsGivingAnalPenetration() || IsGivingVaginalPenetration()) && !IsVictim && rand <= chancetostickouttongueduringattacking * chancemultiplier)
				if !EquippedTongue() && ( (IsCunnilingus() && cunusetongue == 1) || ((IsIntense() || isbroken()) && IsGettingPenetrated() && rand <= chancetostickouttongueduringintense * chancemultiplier) || ((IsCowgirl() || IsGivingAnalPenetration() || IsGivingVaginalPenetration()) && !IsVictim && rand <= chancetostickouttongueduringattacking * chancemultiplier) )
					printdebug("Adding Tongue")
					AddTongue()
				endif
			EndIf
		endif
		
		;remove mask if giving BJ
		if IsSuckingoffOther()
			unequipmask(actorref)
		endif
		DirectorLastLabelTime = MasterScript.GetDirectorLastLabelTime()
		DirectorLastPhysicsLabelTime = MasterScript.GetDirectorLastPhysicsLabelTime()
	endif

endfunction

String Stimulationlabel
String PenisActionLabel
string OralLabel
string EndingLabel
string PenetrationLabel
string Labelsconcat
;sexLabThreadController.ActorAlias(actorInQuestion).GetFullEnjoyment()

Function UpdateLabels(actor char)
 	printdebug("--------------------Hentairim Updating Labels START-----------------")
	
 Stimulationlabel = MasterScript.GetStimulationlabel(char)
 PenisActionLabel  = MasterScript.GetPenisActionLabel(char)
 OralLabel  = MasterScript.GetOralLabel(char)
 EndingLabel  = MasterScript.GetEndingLabel(char)
 PenetrationLabel = MasterScript.GetPenetrationLabel(char)
 
 Labelsconcat = "1" +Stimulationlabel + "1" + PenisActionLabel + "1" + OralLabel + "1" + PenetrationLabel + "1" + EndingLabel
 PrintDebug("Stimulationlabel :" + Stimulationlabel + ", PenisActionLabel :" +  PenisActionLabel  + ", OralLabel :" +  OralLabel  + ", PenetrationLabel :" +  PenetrationLabel  + ", EndingLabel :" +  EndingLabel)

printdebug("--------------------Hentairim Updating Labels END-----------------")
endfunction
;-----------------------BASE HENTAIRIM Update Functions END-----------------------------


;-----------------------Hentairim Common Utilities START--------------------------------------

Bool Function Isintense()
	return stringutil.find(Labelsconcat ,"1F") > -1 || stringutil.find(Labelsconcat ,"BST") > -1
endfunction

Bool Function IsGettingStimulated()
	return Stimulationlabel == "SST" ||  Stimulationlabel == "FST"
endfunction

Bool Function IsSuckingoffOther()
	return OralLabel == "SBJ" ||  OralLabel == "FBJ" 
endfunction


Bool Function IsgettingPenetrated()
	return IsGettingAnallyPenetrated() || IsGettingVaginallyPenetrated()
endfunction

;Which orifice is penetrated is decided by the authored animation LABELS - they
;are the reliable authority and never disagree with themselves mid-thrust. The
;AudioUtilPPA bridge does NOT override them here (it used to, which lost anal
;detection whenever PPA classified a DP as a single act, and flickered off on a
;momentary depth dip). Live measurement is applied separately, only where it is
;actually wanted, via MeasuredPenetrationActive() at the huge-partner ahegao gate.
Bool Function IsGettingVaginallyPenetrated()
	return PenetrationLabel == "SVP" || PenetrationLabel == "FVP" || PenetrationLabel == "SCG" || PenetrationLabel == "FCG" || PenetrationLabel == "SDP" || PenetrationLabel == "FDP"
endfunction

Bool Function IsGettingAnallyPenetrated()
	return PenetrationLabel == "SAP" || PenetrationLabel == "FAP"  || PenetrationLabel == "SAC" || PenetrationLabel == "FAC" || PenetrationLabel == "SDP" || PenetrationLabel == "FDP"
endfunction

;True when the PPA bridge confirms penetration is physically happening on this
;actor right now, OR when the bridge is not tracking this actor at all (nothing
;to gate on, so don't suppress). Checks only the live DEPTH, not PPA's orifice
;classification: the label already established the orifice, so a DP that PPA tags
;as one act still counts. Depth is the "deepest active interaction" value - 0.0
;only when genuinely idle - so this won't strobe between thrusts.
Bool Function MeasuredPenetrationActive()
	if PassPPACtx <= 0
		return true
	endif
	return PassPPADepth > 0.0
endfunction

Bool Function IsKissing()
	return OralLabel == "KIS"
endfunction

Bool Function IsCunnilingus()
	return OralLabel == "CUN"
endfunction

Bool Function IsGivingAnalPenetration()
	return PenisActionLabel == "FDA" || PenisActionLabel == "SDA"
endfunction

Bool Function IsGivingVaginalPenetration()
	return PenisActionLabel =="FDV" || PenisActionLabel == "SDV"
endfunction


Bool Function IsGettingSuckedoff()
	return PenisActionLabel == "SMF" ||  PenisActionLabel == "FMF"	 
endfunction

Bool Function IsCowgirl()
	return PenetrationLabel == "SCG" ||  PenetrationLabel == "FCG" ||  PenetrationLabel == "SAC" ||  PenetrationLabel == "FAC"			
endfunction

Bool Function IsEnding()
	return EndingLabel == "ENI" || EndingLabel == "ENO"
endfunction


Bool function IshugePP()
	if position != 0
		return false
	endif
	return masterscript.ishugepp(actorref)
EndFunction


int Function GetLegacyStageNum(String asScene, String asStage)
	string[] all_stages = SexlabRegistry.GetAllStages(asScene)
	if SexlabRegistry.StageExists(asScene, asStage)
		int stage_num = all_stages.find(asStage)+1
		return stage_num
	endif
	return 0
EndFunction




Bool Function IsVictim(actor char)
  return CurrentThread.GetSubmissive(char)
endFunction

Bool Function IsBroken()
	;SLO VE: no resistance system - never broken
	return false
endfunction


form function get_form(int id, string filename)
	if Game.GetModbyName(filename) == 255 
		return None
	endif
	return Game.GetFormFromFile(id, filename)
endfunction


Function PrintDebug(string Contents = "")
if enableprintdebug == 1
	miscutil.printconsole(actorref.getdisplayname() + " HentaiRim Expressions " + Contents)
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
;-----------------------Hentairim Common Utilities END--------------------------------------
function WritetoErrorlogs(string Header = "Not Specified" ,String contents = "")
	JsonUtil.StringListAdd("ErrorLog.json", Header, " : " + contents, TRUE)
endfunction
