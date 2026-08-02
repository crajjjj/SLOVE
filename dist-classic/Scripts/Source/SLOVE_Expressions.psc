Scriptname SLOVE_Expressions extends ActiveMagicEffect
{Per-actor facial expressions for SLO VE scenes. Ported from
 HentairimExpressions; driven by SLOVE_Director labels and JSON face presets.}

SLOVE_Director Property MasterScript Auto
SexLabFramework Property SexLab Auto
sslThreadController CurrentThread = None
actor Actorref
int position
string role = "c"
int Phase = 1
string LabelGroup

Event OnEffectStart(Actor akTarget, Actor akCaster)
	Actorref = akTarget
	PrintDebug("Effect Start for " + Actorref.getdisplayname() )
	;start from a known-clean marker so a fresh instance (LipSyncBlockedForFace
	;defaults false) never inherits a stale 1 left by an abnormal prior teardown
	StorageUtil.SetIntValue(Actorref, "SLOVE_FaceOwnsMouth_Expr", 0)
	PerformInitialization()

EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
	;last-resort cleanup: fires whenever the spell is removed, even if the
	;OnUpdate chain died and RemoveExpressions never ran for this instance
	ApplyFaceMouthOwnership(false) ;release any lipsync block we placed
	resetexpressions()
	RemoveTongue()
	CleanupTongueItem()
EndEvent

Function PerformInitialization()
	PrintDebug("Perform Initialization")

	CurrentThread = Sexlab.GetActorController(Actorref)
	if CurrentThread == none
		;the spell landed as the scene was already dying (or on the wrong actor) -
		;bail cleanly instead of limping on with a half-initialized instance
		PrintDebug("no SexLab thread for this actor - removing expressions spell")
		SceneEnded = true
		RemoveExpressions()
		return
	endif
	;establish positions
	position = currentthread.Positions.Find(actorref)

	RegisterForTheEventsWeNeed()

	;Base Hentairim Preparation
	InitializeConfigandForms()
	;roll this scene's expression group (a/b/c) and look direction. Without this
	;call the group letter stays "a" forever and the b/c preset groups shipped in
	;the expression JSONs are unreachable (the function existed but was never
	;called - dead in Hentairim too)
	ResetHentaiExpressionGroup()
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
;true while the orgasm / huge-partner ahegao face owns the open mouth and we've
;told AudioUtil to block this actor's lipsync so a playing line can't flap the
;jaw over the climax face (see ApplyFaceMouthOwnership)
bool LipSyncBlockedForFace = false

;-----------------------External ahegao yield-----------------------
;signals that ANOTHER mod is driving this actor's ahegao face, so we pause our
;own expression writes (like the SLS yield above) while it is active. Two
;signals, both configurable and empty-safe (zero cost when unset):
;  - expressions.ahegaoitems: worn item forms (Plugin.esp|FormID)
;  - expressions.ahegaostoragekeys: StorageUtil int keys > 0 on the actor (e.g.
;    the Artsick Ahegao mod's "TongueOn"), which catches a mod's whole tongue
;    set in one check instead of listing every armor variant.
Form[] AhegaoItems
int AhegaoItemCount = 0
string[] AhegaoStorageKeys
int AhegaoStorageKeyCount = 0
bool ExternalAhegaoYieldActive = false

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
		;the Director owns the mouth marker during the SLS ahegao. Clear our own
		;contribution so PlaySound sees only the Director's; the next full pass on
		;resume re-asserts it if a climax face is still up.
		LipSyncBlockedForFace = false
		StorageUtil.SetIntValue(actorref, "SLOVE_FaceOwnsMouth_Expr", 0)
	else
		SLSAhegaoActive = false
		printdebug("SLS ahegao ended - resuming Hentairim expressions")
		CachedLabelGroup = "" ;force a fresh full pass on resume
	endif
EndEvent

Function ApplyFaceMouthOwnership(bool faceOwnsMouth)
	;while the orgasm / huge-partner ahegao face owns the open mouth, mark this
	;actor so PlaySound plays voice lines with blockLipSync=true - a line can't
	;then move the jaw over the climax face. Cleared when the face ends. No-op
	;while the state hasn't changed. The Director ORs this with its own SLS flag.
	if faceOwnsMouth == LipSyncBlockedForFace
		return
	endif
	LipSyncBlockedForFace = faceOwnsMouth
	StorageUtil.SetIntValue(actorref, "SLOVE_FaceOwnsMouth_Expr", faceOwnsMouth as int)
	if faceOwnsMouth && AudioUtil.IsLipSyncActive(actorref)
		;blockLipSync gates only lines started from now on - also stop the
		;in-flight envelope so the currently playing line can't keep flapping
		;the jaw over the face that just claimed the mouth
		AudioUtil.StopLipSync(actorref)
	endif
	printdebug("Climax/ahegao face mouth ownership - lipsync blocked = " + faceOwnsMouth)
EndFunction

bool SceneEnded = false
Event ExpressionsSceneEnd(string eventName, string argString, float argNum, form sender)
	;event-driven cleanup: don't depend on the OnUpdate chain surviving to its
	;next tick - a dropped update used to leave face and tongue stuck forever
	if argString as Int == ThreadID
		SceneEnded = true
		RemoveExpressions()
	endif
EndEvent


Event ExpressionsOnStageStart(string eventName, string argString, float argNum, form sender)
	if argString as Int == ThreadID
		position = currentthread.Positions.Find(actorref)
	endif
EndEvent

float LastOrgasmtime

Event ExpressionsOrgasm(Form akactor, Int thread)
	If akactor != actorRef
		Return
	EndIf
	IsOrgasming = true
	LastOrgasmtime =  currentthread.TotalTime

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

	;poll for an external ahegao (another mod owning this actor's face) - a worn
	;item or a StorageUtil key. The SLS yield is event-driven and player-only;
	;this covers any mod that signals ahegao by an item or a per-actor key, on
	;any actor. Transition once so we drop the tongue / hand back the mouth on
	;enter and force a fresh pass on exit.
	bool extAhegao = ExternalAhegaoActive()
	if extAhegao && !ExternalAhegaoYieldActive
		ExternalAhegaoYieldActive = true
		printdebug("External ahegao (worn item or storage key) - pausing expressions")
		RemoveTongue()
		LipSyncBlockedForFace = false
		StorageUtil.SetIntValue(actorref, "SLOVE_FaceOwnsMouth_Expr", 0)
	elseif !extAhegao && ExternalAhegaoYieldActive
		ExternalAhegaoYieldActive = false
		CachedLabelGroup = ""
		printdebug("External ahegao ended - resuming expressions")
	endif

	if SLSAhegaoActive || extAhegao
		;an external ahegao owns the face right now - don't fight it. Keep the loop
		;ticking so we pick straight back up once it ends.
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

	;Ends if actor is no longer in scene but magic stuck for some reason. AnimationisEnding
	;is the PC scene's teardown flag - honor it only for a PC-scene actor, else a concurrent
	;PC scene ending would wrongly end this NPC-scene effect. NPC scenes end on their own
	;controller going away.
	if !Sexlab.GetActorController(actorref) || (OnPCThread() && MasterScript.AnimationisEnding())
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
		if MFEEAddAhegao
			MFEEAddAhegao = false
			;retract the painted ahegao - clearing the flag alone leaves the MFEE
			;morph at 100 until scene-end RevertExpression
			MuFacialExpressionExtended.SetExpressionByNumber(actorref, 0, 0, 0)
		endif
	endif

	;a gag locked on mid-scene owns the mouth - retract any tongue already out.
	;AddTongue is gag-gated so a fresh tongue never appears while gagged, but a gag
	;equipped AFTER the tongue showed needs this. Doubly so now the tongue shares the
	;DD gag biped slot (44): a worn tongue and the gag would otherwise fight for the
	;slot, and the MFEE morph tongue (no slot) is only cleared by this explicit retract.
	bool gagged = HasDeviousGag(actorref)
	if gagged && (FHUTongueShown || MFEEAddTongue || EquippedTongue())
		printdebug("Gag equipped mid-scene - retracting tongue")
		RemoveTongue()
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

	;double-tongue guard: FHU equips its armor tongues on its own (inflation
	;ahegao), which the MFEE morph tongue can't see - if one shows up while the
	;MFEE tongue is painted, retract ours and let the armor tongue stand
	;(unequipping FHU's would just fight its re-equip)
	bool tonguearmorworn = EquippedTongue()
	if MFEEAddTongue && tonguearmorworn
		printdebug("Double tongue: FHU armor tongue worn while MFEE tongue painted - retracting MFEE tongue")
		RemoveTongue()
	endif

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

	bool mouthblowjob = IsSuckingoffOther() || gagged
	;enableahegao gates only the hugePP arm; a broken actor always gets the broken
	;face. The hugePP ahegao is measurement-gated: the labels decide penetration,
	;and MeasuredPenetrationActive() suppresses it when the PPA bridge reports the
	;partner isn't actually inserted (returns true when no bridge, so labels alone
	;drive it then)
	bool brokenface = (enableahegao == 1 && ishugepp && IsgettingPenetrated() && MeasuredPenetrationActive()) || (IsBroken() && (PenisActionlabel != "LDI" || Penetrationlabel != "LDI" || StimulationLabel != "LDI" || OralLabel != "LDI"))

	;the orgasm / huge-partner ahegao face owns the open mouth this pass - hand it
	;the jaw by blocking lipsync (else a playing line lipsyncs over the climax
	;face). Released automatically once neither is active any more.
	ApplyFaceMouthOwnership(IsOrgasming || brokenface || MFEEAddAhegao || MFEEAddTongue || tonguearmorworn)

	float[] result = BuildTickPreset(GetCachedPhase(Phase), varPct, mouthblowjob, brokenface)

	;MFEE side effects, hoisted out of the per-cell loops so they run once per cycle
	if MFEEAddAhegao
		if MuFacialExpressionExtended.GetExpressionValueByNumber(actorref,0,0) != 100
			MuFacialExpressionExtended.SetExpressionByNumber(actorref,0,0,100) ;ahegao 1
		endif
		;make sure tongue out and tongue down is not applied as ahegao already has tongue out and down
		if MuFacialExpressionExtended.GetExpressionValueByNumber(actorref,8,0) != 0 || MuFacialExpressionExtended.GetExpressionValueByNumber(actorref,8,2) != 0
			MuFacialExpressionExtended.SetExpressionByNumber(actorref,8,0,0) ;tongueout
			MuFacialExpressionExtended.SetExpressionByNumber(actorref,8,2,0) ;tongue down
		endif
		if MfgConsoleFunc.GetModifier(actorref, 11) != 50
			MfgConsoleFunc.SetModifier(actorref, 11, ahegaolookupmodifier) ;look up 50
		endif
	else
		if !mouthblowjob && MFEEAddTongue
			;apply MFEE tongue out and down
			if MuFacialExpressionExtended.GetExpressionValueByNumber(actorref,8,0) != 100 || MuFacialExpressionExtended.GetExpressionValueByNumber(actorref,8,2) != 100
				MuFacialExpressionExtended.SetExpressionByNumber(actorref,8,0,100) ;tongueout
				MuFacialExpressionExtended.SetExpressionByNumber(actorref,8,2,100) ;tongue down
			endif
		endif
		;enableahegao is the master switch for the MFEE mood-ahegao overlay: with it
		;off, a broken actor still gets the broken-face PRESET (built above), just not
		;the MFEE expression-0 ahegao painted on top here
		if enableahegao == 1 && brokenface && HasMFEEVanillaRace && MuFacialExpressionExtended.GetExpressionValueByNumber(actorref,0,0) != 100
			MuFacialExpressionExtended.SetExpressionByNumber(actorref,0,0,100) ;ahegao 1
		elseif HasMFEEVanillaRace && (!brokenface || enableahegao != 1) && MuFacialExpressionExtended.GetExpressionValueByNumber(actorref,0,0) != 0
			;the broken face ended mid-scene - retract the painted ahegao (it
			;otherwise persists until scene-end RevertExpression)
			MuFacialExpressionExtended.SetExpressionByNumber(actorref,0,0,0)
		endif
	endif

	;baseline for the cheap breathing ticks between full passes - taken from the
	;preset BEFORE any lipsync yield below overwrites the mouth channels
	BreathBase0 = (result[0] * 100.0) as int

	;lipsync yield (AudioUtil contract): while the DLL drives this actor's mouth
	;from the playing clip's envelope, don't fight it over the jaw - retarget the
	;two channels it owns (0 Aah / 1 BigAah) to their CURRENT values so the smooth
	;apply is a no-op on them while the rest of the face still updates. Skipped when
	;the climax face owns the mouth (lipsync is blocked): apply the face's mouth in full.
	if AudioUtil.IsLipSyncActive(actorref) && !LipSyncBlockedForFace
		int curAah = MfgConsoleFunc.GetPhoneme(actorref, 0)
		int curBigAah = MfgConsoleFunc.GetPhoneme(actorref, 1)
		if curAah >= 0
			result[0] = curAah / 100.0
		endif
		if curBigAah >= 0
			result[1] = curBigAah / 100.0
		endif
	endif

	;A visible tongue needs the mouth held open. We used to get that for free from the
	;licker's moan lipsync, but an oral giver's lines are now lipsync-blocked (the Director's
	;FaceOwnsMouth/IsOralGiver fix), and some tongue branches leave the jaw shut - the MFEE
	;tongue path when tonguephonemebigaah is unconfigured (0), or a cun/blowjob mislabel that
	;falls through the tongue-out branch - so the tongue would poke through a closed mouth.
	;Floor BigAah (the jaw opener GetMeasuredMouthOpen keys on, so this also keeps the jaw
	;gate from retracting the tongue) to the tongue-out preset's own open value whenever a
	;tongue is out and lipsync isn't actively driving the mouth. No-op when the tongue-out
	;branch already set it, and (classic) inert while tongues stay gated off. Shape channels
	;(e.g. MFEE's 'oh') left untouched.
	if (EquippedTongue() || MFEEAddTongue) && !(AudioUtil.IsLipSyncActive(actorref) && !LipSyncBlockedForFace)
		if TongueOutOverrideF.Length > 1 && result[1] < TongueOutOverrideF[1]
			result[1] = TongueOutOverrideF[1]
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
	ApplyFaceMouthOwnership(false) ;release any lipsync block we placed
	resetexpressions()
	RemoveTongue()
	CleanupTongueItem()
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
	fhutonguetype = SLOVE_Config.GetInt("expressions.tonguetype", 0) ;config key renamed to tonguetype; the var keeps its FHU* name for save-compat
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

	LoadAhegaoItems()
	LoadAhegaoStorageKeys()
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
	;semantic: a tongue is visibly OUT via worn armor. The tongue is equipped
	;on demand (worn = shown), so ANY worn variant counts - ours, or one FHU
	;equipped on its own (inflation ahegao) - via their shared worn slot
	if FHUTongueShown
		return true
	endif
	if FHUTongueSlotMask == 0
		return false
	endif
	Form worn = actorref.GetWornForm(FHUTongueSlotMask)
	if !worn
		return false
	endif
	int i = 0
	while i < 10
		if worn == FHUAllTongues[i]
			return true
		endif
		i += 1
	endwhile
	return false
EndFunction

Function AddTongue()
	;CLASSIC: the contact tongue (shown during cunnilingus/blowjob) is P+-only - classic
	;has no oral-contact detection to time it, so it stays off. This no-ops BOTH backends
	;(the MFEE morph tongue and the FHU armor tongue) and the mid-scene fallback AddItem,
	;so NPCs never receive a tongue armor here either (no redress). Ahegao is unaffected:
	;MFEEAddAhegao is set from the broken/orgasm path and carries its own tongue-out, and
	;it already blocks this function anyway. (Body-only gate; function kept for save-compat.)
	return

	;one mask scan per call: WearingMask walks worn slots with externals, and a
	;printdebug ARGUMENT is evaluated even when debug is off - the old code built
	;the debug string (scanning once) and then scanned again in the gate below
	Armor wornMask = WearingMask(actorref)
	if enableprintdebug == 1
		printdebug("AddTongue: Starting. MFEEAddAhegao=" + MFEEAddAhegao + " WearingMask=" + (wornMask != none) + " IsSuckingoffOther=" + IsSuckingoffOther() + " EnableTongue=" + EnableTongue + " HasDeviousGag=" + HasDeviousGag(actorref) + " IsUnconcious=" + IsUnconcious() + " EquippedTongue=" + EquippedTongue())
	endif

	if MFEEAddAhegao || wornMask != none || IsSuckingoffOther() || EnableTongue != 1 || HasDeviousGag(actorref) || IsUnconcious() || EquippedTongue()
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
		if FHUTongueTypeArmor
			printdebug("AddTongue: Equipping FHUTongueTypeArmor=" + FHUTongueTypeArmor)
			;show = plain EquipItem. The armor is already in the inventory:
			;the Director pre-adds every variant in the AnimationStarting
			;presex window (before SexLab strips), and equipment traffic on
			;an already-carried item does not wake the NPC outfit AI - only
			;inventory ADDs do. The AddItem below is a fallback for scenes
			;adopted without the presex hook (mid-scene reload, missed event)
			if actorref.GetItemCount(FHUTongueTypeArmor) == 0
				actorref.AddItem(FHUTongueTypeArmor, abSilent = true)
			endif
			;the tongues are flagged NonPlayable - plain EquipItem is a
			;silent no-op on the PLAYER for non-playable items; EquipItemEx
			;bypasses the playable filter and is used for everyone (uniform
			;path, preventUnequip on, no equip sound)
			actorref.EquipItemEx(FHUTongueTypeArmor, 0, true, false)
			FHUTongueShown = true
		else
			printdebug("AddTongue: FHUTongueTypeArmor not defined (tongue disabled or not rolled), skipping equip.")
		endif
	endif
EndFunction

Function RemoveTongue()

	if HasMFEE && MFEEAddTongue
		MFEEAddTongue = false
		;clearing the flag only stops re-asserting the tongue - the painted MFEE
		;morphs persist until scene-end RevertExpression, so retract them now
		;(blowjob, jaw gate and the ahegao yields all expect it actually gone)
		MuFacialExpressionExtended.SetExpressionByNumber(actorref, 8, 0, 0) ;tongue out
		MuFacialExpressionExtended.SetExpressionByNumber(actorref, 8, 2, 0) ;tongue down
	else
		if FHUTongueShown
			;hide = plain UnequipItem: equipment traffic on a carried item does
			;not wake the NPC outfit AI (only inventory ADDs do, and those all
			;happen in the presex window). CleanupTongueItem stays as the
			;scene-end backstop
			if FHUTongueTypeArmor && actorref.IsEquipped(FHUTongueTypeArmor)
				actorref.UnequipItemEx(FHUTongueTypeArmor, 0, false) ;Ex mirrors the NonPlayable-safe equip, uniform for everyone
			endif
			FHUTongueShown = false
		endif
	endif
endfunction

;scene-end teardown for the FHU tongue: unequip our worn variant only. The
;item REMOVAL is the Director's job (RemoveTongueItems in DirectorEndScene) -
;the tongues must not persist between scenes, and at scene end the inventory
;traffic is harmless (the actors are redressing anyway)
Function CleanupTongueItem()
	FHUTongueShown = false
	if FHUTongueTypeArmor && actorref.IsEquipped(FHUTongueTypeArmor)
		actorref.UnequipItemEx(FHUTongueTypeArmor, 0, false) ;Ex mirrors the NonPlayable-safe equip, uniform for everyone
	endif
endfunction

;=====================================================================
;SAVE-COMPAT ONLY - do NOT call these from new code, do NOT delete them.
;These three functions are kept BYTE-IDENTICAL to the old node-toggle build
;purely so a save made on that build can restore a suspended call stack parked
;inside them (WaitForTongueNode/EquipTongueBase contain Utility.Wait). Deleting
;a function that a save has a live/suspended stack in makes that save fail to
;load. New scenes never reach these (EquipTongueBase is no longer called from
;PerformInitialization); the tongue is driven by presex preload + EquipItemEx.
;=====================================================================

;Equip the rolled FHU tongue ONCE at scene start and park it hidden. All
;mid-scene show/hide is then a PO3 node-visibility toggle with zero
;inventory/equip traffic - the NPC outfit AI (which re-dresses stripped NPCs
;on inventory changes) never wakes up mid-scene.
Function EquipTongueBase()
	FHUTongueShown = false
	if !FHUTongueTypeArmor || FHUTongueNodeName == ""
		return
	endif
	if HasMFEE && EnabledMFEETongue == 1
		return ;MFEE tongue is a morph, the armor is never used
	endif
	bool addedNow = false
	if actorref.GetItemCount(FHUTongueTypeArmor) == 0
		actorref.AddItem(FHUTongueTypeArmor, abSilent = true)
		addedNow = true
	endif
	actorref.EquipItem(FHUTongueTypeArmor, true, true) ;abPreventRemoval - SexLab strapon pattern
	WaitForTongueNode()
	HideTongueNode()
	if enableprintdebug == 1
		printdebug("EquipTongueBase: added=" + addedNow + " equipped=" + actorref.IsEquipped(FHUTongueTypeArmor) + " node(" + FHUTongueNodeName + ")=" + NetImmerse.HasNode(actorref, FHUTongueNodeName, false))
	endif
	if addedNow && !isplayer
		;the AddItem inventory change can wake the NPC outfit AI (redress) - ask
		;SexLab to re-strip with the scene's own settings. Re-stripped gear is
		;merged into the alias equipment list, so it comes back at scene end;
		;the tongue survives the strip (NonPlayable items are never stripped).
		;Only ever fires on the actor's FIRST tongue scene: the item stays in
		;the inventory across scenes now
		if CurrentThread
			sslActorAlias slAlias = CurrentThread.ActorAlias(actorref)
			if slAlias
				slAlias.Strip()
				;Strip() queues a NiNode rebuild - the rebuilt tongue node spawns
				;visible, so park it again
				WaitForTongueNode()
				HideTongueNode()
				printdebug("EquipTongueBase: post-add re-strip done")
			endif
		endif
	endif
EndFunction

;3D attach after EquipItem (and rebuilds after QueueNiNodeUpdate) is async -
;wait for the tongue shape to exist before toggling it (up to ~1.5s)
Function WaitForTongueNode()
	int tries = 0
	while tries < 15 && !NetImmerse.HasNode(actorref, FHUTongueNodeName, false)
		Utility.Wait(0.1)
		tries += 1
	endwhile
EndFunction

;hidden-flag re-assert lives in its own helper: also called per gate tick while
;parked, because an actor 3D rebuild (armor swap, RaceMenu) resets node flags
Function HideTongueNode()
	if FHUTongueNodeName != "" && FHUTongueTypeArmor && actorref.IsEquipped(FHUTongueTypeArmor)
		PO3_SKSEFunctions.ToggleChildNode(actorref, FHUTongueNodeName, true)
	endif
endfunction

Function unequipmask(actor char)
	Armor Mask = wearingmask(char)
	if Mask
		char.unEquipItem(Mask, abSilent=true)
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
		;(read the EXCLUDE list - this indexed Masks[] by the exclude counter since
		;Hentairim, so the exclusion feature never actually worked)
		while excludeindex < excludelength
			if stringutil.find(Maskname ,exclude[excludeindex]) > -1
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
	;same gag source as SLOVE_Voice: the Director's IsWearingGag (AudioUtil GagState -
	;DD keyword families + [gag].items markers), so face and voice always agree on
	;"gagged". The old check here saw only the DD-Integration gag magic effect.
	return MasterScript.IsWearingGag(char)
EndFunction

;-----------------------External ahegao-item detection-----------------------

;Resolve expressions.ahegaoitems - a comma-separated list of "Plugin.esp|FormID"
;(hex local form id, 0x optional; plugin names may contain spaces) - into forms
;once at init. WearingAhegaoItem() then polls IsEquipped cheaply each pass.
Function LoadAhegaoItems()
	AhegaoItems = new Form[16]
	AhegaoItemCount = 0
	string raw = SLOVE_Config.GetString("expressions.ahegaoitems", "")
	if raw == ""
		return
	endif
	string[] entries = StringUtil.Split(raw, ",")
	int i = 0
	while i < entries.length && AhegaoItemCount < 16
		string entry = TrimSpaces(entries[i])
		int bar = StringUtil.Find(entry, "|")
		if entry == ""
			;blank entry (e.g. trailing comma) - ignore
		elseif bar <= 0
			printdebug("Ahegao item missing '|' - skipped: " + entry)
		else
			string plugin = TrimSpaces(StringUtil.Substring(entry, 0, bar))
			string idtext = TrimSpaces(StringUtil.Substring(entry, bar + 1))
			if StringUtil.Find(idtext, "0x") == 0
				idtext = StringUtil.Substring(idtext, 2)
			endif
			int fid = ParseHexId(idtext)
			if plugin == "" || fid < 0
				printdebug("Ahegao item has an invalid form id - skipped: " + entry)
			else
				Form f = Game.GetFormFromFile(fid, plugin)
				if f
					AhegaoItems[AhegaoItemCount] = f
					AhegaoItemCount += 1
					printdebug("Ahegao item resolved: " + entry)
				else
					printdebug("Ahegao item not in the load order - skipped: " + entry)
				endif
			endif
		endif
		i += 1
	endwhile
	printdebug("Ahegao items loaded: " + AhegaoItemCount)
EndFunction

;Resolve expressions.ahegaostoragekeys - comma-separated StorageUtil int key
;names. While any key reads > 0 on the actor, another mod is driving its ahegao.
;e.g. the Artsick Ahegao mod sets "TongueOn" per actor while its tongue is on.
Function LoadAhegaoStorageKeys()
	AhegaoStorageKeys = new string[16]
	AhegaoStorageKeyCount = 0
	string raw = SLOVE_Config.GetString("expressions.ahegaostoragekeys", "")
	if raw == ""
		return
	endif
	string[] keys = StringUtil.Split(raw, ",")
	int i = 0
	while i < keys.length && AhegaoStorageKeyCount < 16
		string k = TrimSpaces(keys[i])
		if k != ""
			AhegaoStorageKeys[AhegaoStorageKeyCount] = k
			AhegaoStorageKeyCount += 1
		endif
		i += 1
	endwhile
	printdebug("Ahegao storage keys loaded: " + AhegaoStorageKeyCount)
EndFunction

;True while any configured StorageUtil key reads > 0 on this actor. Free when
;none are configured, so it is safe to poll every OnUpdate.
bool Function AhegaoStorageKeyActive()
	if AhegaoStorageKeyCount == 0
		return false
	endif
	int i = 0
	while i < AhegaoStorageKeyCount
		if StorageUtil.GetIntValue(actorref, AhegaoStorageKeys[i], 0) > 0
			return true
		endif
		i += 1
	endwhile
	return false
EndFunction

;Any external ahegao signal on this actor: a worn item form or a StorageUtil key.
bool Function ExternalAhegaoActive()
	return WearingAhegaoItem() || AhegaoStorageKeyActive()
EndFunction

;True while this actor wears any configured ahegao item. Free when none are
;configured (AhegaoItemCount == 0), so it is safe to poll every OnUpdate.
bool Function WearingAhegaoItem()
	if AhegaoItemCount == 0
		return false
	endif
	int i = 0
	while i < AhegaoItemCount
		if AhegaoItems[i] && actorref.IsEquipped(AhegaoItems[i])
			return true
		endif
		i += 1
	endwhile
	return false
EndFunction

;Parse a hex string (no 0x prefix) to an int. Returns -1 on empty input or any
;non-hex character. Papyrus strings are case-insensitive, so both a-f and A-F
;are accepted regardless of how GetNthChar reports the character's case.
int Function ParseHexId(string s)
	int len = StringUtil.GetLength(s)
	if len == 0
		return -1
	endif
	int result = 0
	int i = 0
	while i < len
		int c = StringUtil.AsOrd(StringUtil.GetNthChar(s, i))
		int d = -1
		if c >= 48 && c <= 57			; 0-9
			d = c - 48
		elseif c >= 97 && c <= 102		; a-f
			d = c - 87
		elseif c >= 65 && c <= 70		; A-F
			d = c - 55
		endif
		if d < 0
			return -1
		endif
		result = result * 16 + d
		i += 1
	endwhile
	return result
EndFunction

;Strip leading/trailing spaces only - internal spaces are preserved so plugin
;names like "Devious Devices - Assets.esm" survive a split on ", ".
string Function TrimSpaces(string s)
	int start = 0
	int last = StringUtil.GetLength(s) - 1
	while start <= last && StringUtil.GetNthChar(s, start) == " "
		start += 1
	endwhile
	while last >= start && StringUtil.GetNthChar(s, last) == " "
		last -= 1
	endwhile
	if last < start
		return ""
	endif
	return StringUtil.Substring(s, start, last - start + 1)
EndFunction


Bool Function IsUnconcious()
	;faint/sleep/necro dead-face (and the tongue/effect gates that read this) apply to
	;the VICTIM only, never the aggressor. position == 0 was wrong - the aggressor can be
	;position 0, so they got the dead face too. IsVictim is set per actorref in
	;HentairimPrepare (SexLab submissive/victim), matching the voice-suppression target.
	;NecroTargetByPosition is the fallback for necro scenes that flag no victim at all
	;(the FunnyBizness necro pack does this) - it reinstates Hentairim's position-0 rule,
	;but only when nothing is flagged, so the aggressor-at-position-0 case is unaffected.
	return SceneTagFaint && (IsVictim || NecroTargetByPosition(actorref))
endfunction

;See SLOVE_Voice.NecroTargetByPosition: victim-flag-independent target ID for necro/faint
;scenes that never set a SexLab victim. Falls back to Hentairim's scene-position-0 rule,
;gated on an empty victim list.
Bool Function NecroTargetByPosition(Actor a)
	if !CurrentThread || CurrentThread.Victims.length > 0
		return false
	endif
	return CurrentThread.Positions.Find(a) == 0
EndFunction

;See SLOVE_Voice.SceneHasTag: on classic SexLab the thread's Tags array is start-context
;only (never filled from the chosen animation), so read the active sslBaseAnimation's own
;tag list - what the SLAL json registers and SLATE edits - with the thread check as bonus.
Bool Function SceneHasTag(String asTag)
	if !CurrentThread
		return false
	endif
	sslBaseAnimation anim = CurrentThread.Animation
	return (anim && anim.HasTag(asTag)) || CurrentThread.HasTag(asTag)
EndFunction



Int SLSOReadyCache = 0 ;0 = unknown, 1 = SLSO present, -1 = absent (lazy, cached once)

int function  GetFullEnjoyment()
	;SLSO's minigame pins SexLab's GetEnjoyment() at 0 all scene and keeps the live meter
	;in the alias's GetFullEnjoyment() (the value SLSO's own voice reads). Prefer that when
	;SLSO is present; fall back to GetEnjoyment() when SLSO is absent or the meter is 0.
	int enjoyment = -1
	if SLSOReadyCache == 0
		if Game.GetModByName("SLSO.esp") != 255 && Game.GetModByName("SLSO.esp") != -1
			SLSOReadyCache = 1
		else
			SLSOReadyCache = -1
		endif
	endif
	if SLSOReadyCache == 1
		sslActorAlias al = CurrentThread.ActorAlias(actorref)
		if al
			enjoyment = al.GetFullEnjoyment()
		endif
	endif
	if enjoyment <= 0
		enjoyment = CurrentThread.GetEnjoyment(actorref) as int
	endif
	printdebug("Enjoyment : " + enjoyment)
	return enjoyment
endfunction

bool IsOrgasming

String Function GetHentaiExpression()

	string 	HentaiScenario = StorageUtil.GetStringValue(None, "HentaiScenario", "")
	if !isplayer || HentaiScenario == ""
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
	;check if has MFEE (one native version probe + one race-name read, reused below)
	int mfeeVersion = MuFacialExpressionExtended.GetVersion()
	string raceName = actorref.GetRace().getname()
	if mfeeVersion > 0 && (raceName == "Erin" || raceName == "Elin")
		HasMFEE = true
		EnabledMFEETongue = JsonUtil.GetIntValue(EnableErinMFEE,"enablemfeetongue",0)
		EnabledMFEEAhegao = JsonUtil.GetIntValue(EnableErinMFEE,"enablemfeeahegao",0)
		ahegaophonemebigaah = JsonUtil.GetIntValue(EnableErinMFEE,"ahegaophonemebigaah",0)
		tonguephonemebigaah = JsonUtil.GetIntValue(EnableErinMFEE,"tonguephonemebigaah",0)
		tonguephonemeoh	 = JsonUtil.GetIntValue(EnableErinMFEE,"tonguephonemeoh",0)
		ahegaolookupmodifier = JsonUtil.GetIntValue(EnableErinMFEE,"ahegaolookupmodifier",0)
	elseif mfeeVersion > 0
		HasMFEEVanillaRace = true
	endif
endfunction


Float function GetSecondsSinceLastOrgasm()

	return currentthread.TotalTime - LastOrgasmtime

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

string NPCTongueFile  = "SLOVE/NPCTongue.json"
int enablenpctongue = 0

Function InitializeAddNPCTongue()
	printdebug("enablenpctongue : " + enablenpctongue)
	enablenpctongue = JsonUtil.GetIntValue(NPCTongueFile, "enablenpctongue", 0)

	FHUTongueTypeArmor =  GetTongueType()
	CacheFHUTongues()
endfunction

armor FHUTongueTypeArmor
string FHUTongueNodeName = "" ;SAVE-COMPAT: retained (unused by new code) so a save made on the old node-toggle build keeps a matching script layout - removing a script variable mid-playthrough breaks save loading
bool FHUTongueShown = false   ;we equipped the rolled tongue and it is currently worn

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
		;named entry wins (-1 opts that NPC out); unlisted NPCs fall back to the
		;configured fhutonguetype. The old whitelist-only default (99) existed to
		;contain the equip-driven outfit redress - gone now that the armors are
		;pre-added in the presex window and mid-scene traffic is equip-only
		TongueType = JsonUtil.GetIntValue(NPCTongueFile, name, 0)
		if TongueType == 0
			TongueType = FHUTongueType
		endif
	endif

	;SLOVE tongue armors (bundled HALO HDT lingas) are sequential in SLOVE.esp:
	;SLOVE_Tongue1Armor..10Armor = 0x000813..0x00081C, so type N = 0x000812 + N
	if TongueType >= 1 && TongueType <= 10
		Tongue = Game.GetFormFromFile(0x000812 + TongueType, "SLOVE.esp") as Armor
	endif

	FHUTongueTypeArmor = Tongue
	return Tongue
endfunction

;all ten tongue variants and their shared biped slot mask, cached once so
;EquippedTongue can also spot a tongue another mod equipped (e.g. FHU's own
;inflation ahegao), or a different variant than the one we rolled. Names keep
;the FHU* prefix for save-compat (renaming a script member breaks saves)
Form[] FHUAllTongues
int FHUTongueSlotMask = 0

Function CacheFHUTongues()
	FHUTongueSlotMask = 0
	FHUAllTongues = new Form[10]
	int i = 0
	while i < 10
		;SLOVE_Tongue{i+1}Armor = 0x000813 + i
		FHUAllTongues[i] = Game.GetFormFromFile(0x000813 + i, "SLOVE.esp")
		i += 1
	endwhile
	Armor firstTongue = FHUAllTongues[0] as Armor
	if firstTongue
		FHUTongueSlotMask = firstTongue.GetSlotMask()
	endif
EndFunction


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
	ThreadID = currentthread.tid
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
	bool stagechanged
	if OnPCThread()
		stagechanged = DirectorLastLabelTime != MasterScript.GetDirectorLastLabelTime() || DirectorLastPhysicsLabelTime != MasterScript.GetDirectorLastPhysicsLabelTime()
	else
		;NPC-only scene: the Director tracks only the PC's thread, so its label-time stamp
		;never moves for us. Gate on our OWN thread's animation/stage change instead.
		stagechanged = CurrentSceneID != (CurrentThread.Animation as string) || currentstage != CurrentThread.Stage
	endif
	if stagechanged
		printdebug("Animation, Stage or Physics Labels Different. Updating Stage Data")
		TongueGateBlocked = false ;stale gate-deferred rolls don't survive a label change
		string prevSceneID = CurrentSceneID
		CurrentSceneID = CurrentThread.Animation as string
		currentStageID = CurrentThread.Stage as string
		currentstage = CurrentThread.Stage
		if CurrentSceneID != prevSceneID
			;new scene - refresh the per-scene tag cache
			SceneTagFaint = SceneHasTag("faint") || SceneHasTag("sleep") || SceneHasTag("sleeping") || SceneHasTag("necro") || SceneHasTag("unconscious")
			SceneTagDoggy = SceneHasTag("Doggy") || SceneHasTag("Doggystyle") || SceneHasTag("Doggy Style")
		endif

		UpdateLabels(actorref)

		printdebug("PC Thread Position : " + currentthread.Positions.Find(Actorref))
		printdebug("current Animation : " + CurrentSceneID)
		printdebug("current StageID : " + currentStageID)
		printdebug("current stage number: " + currentstage)


		int rand = Utility.RandomInt(1,100)
		float chancemultiplier = 1
		if IsBroken()
			chancemultiplier = chancemultiplier * 2
		EndIf

		;the three tongue justifications, shared by add and retract so the two
		;can never disagree: cunnilingus (labels), intense receiving, and
		;attacking positions. The chance rolls only gate the ADD
		bool oralTongue = IsCunnilingus() && cunusetongue == 1
		bool intenseTongue = (IsIntense() || isbroken()) && IsGettingPenetrated()
		bool attackingTongue = (IsCowgirl() || IsGivingAnalPenetration() || IsGivingVaginalPenetration()) && !IsVictim

		;full tongue-decision dump: exactly why a tongue does/doesn't appear this
		;stage - the three conditions with their sub-parts, the roll vs thresholds,
		;and the current equipped/shown state. Gated so the string (several external
		;calls) is only built when debugging - printdebug args evaluate even when off
		if enableprintdebug == 1
			printdebug("TONGUE-EVAL actor=" + actorref.GetDisplayName() + " scene=" + CurrentSceneID + " stage=" + currentstage + " equipped=" + EquippedTongue() + " shown=" + FHUTongueShown + " EnableTongue=" + EnableTongue + " cunuse=" + cunusetongue + " || oral=" + oralTongue + " [CUN=" + IsCunnilingus() + "] intense=" + intenseTongue + " [isIntense=" + IsIntense() + " broken=" + IsBroken() + " penetrated=" + IsGettingPenetrated() + "] attacking=" + attackingTongue + " || rand=" + rand + " needIntense<=" + (chancetostickouttongueduringintense * chancemultiplier) + " needAttack<=" + (chancetostickouttongueduringattacking * chancemultiplier))
		endif

		if EquippedTongue()
			;deterministic retract: unequip as soon as NO tongue condition holds
			;anymore (the stage/labels moved on) - no keep/strip roll, a tongue
			;that randomly outlives its trigger reads as weird
			if !(oralTongue || intenseTongue || attackingTongue)
				printdebug("Retracting tongue - no condition holds (oral/intense/attacking all false)")
				RemoveTongue()
			EndIf
		else
			;this branch is the else of "if EquippedTongue()", so no re-check needed
			if EnableTongue == 1
				if oralTongue || (intenseTongue && rand <= chancetostickouttongueduringintense * chancemultiplier) || (attackingTongue && rand <= chancetostickouttongueduringattacking * chancemultiplier)
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

;true when this effect's actor is in the PLAYER's tracked scene - keep the Director's
;labels. False for an NPC-only scene, where the Director tracks a different (or no)
;thread, so we self-compute labels off our own thread.
bool Function OnPCThread()
	return CurrentThread && CurrentThread.Positions.Find(playerref) >= 0
endfunction

Function UpdateLabels(actor char)
	printdebug("--------------------Hentairim Updating Labels START-----------------")

	if OnPCThread()
		Stimulationlabel = MasterScript.GetStimulationlabel(char)
		PenisActionLabel  = MasterScript.GetPenisActionLabel(char)
		OralLabel  = MasterScript.GetOralLabel(char)
		EndingLabel  = MasterScript.GetEndingLabel(char)
		PenetrationLabel = MasterScript.GetPenetrationLabel(char)
	else
		ComputeOwnThreadLabels(char)
	endif

	Labelsconcat = "1" +Stimulationlabel + "1" + PenisActionLabel + "1" + OralLabel + "1" + PenetrationLabel + "1" + EndingLabel
	PrintDebug("Stimulationlabel :" + Stimulationlabel + ", PenisActionLabel :" +  PenisActionLabel  + ", OralLabel :" +  OralLabel  + ", PenetrationLabel :" +  PenetrationLabel  + ", EndingLabel :" +  EndingLabel)

	printdebug("--------------------Hentairim Updating Labels END-----------------")
endfunction

;Base tag labels for an NPC-only scene from our OWN thread (the Director's label arrays
;only cover the player's thread). Classic keys tags off the sslBaseAnimation + stage int.
Function ComputeOwnThreadLabels(actor char)
	Stimulationlabel = ""
	PenisActionLabel = ""
	OralLabel = ""
	EndingLabel = ""
	PenetrationLabel = ""
	if !CurrentThread
		return
	endif
	actor[] al = CurrentThread.Positions
	int idx = al.Find(char)
	if idx < 0
		return
	endif
	sslBaseAnimation anim = CurrentThread.Animation
	int stagenum = CurrentThread.Stage
	string[] stim = SLOVE_Hentairim_Tags.GetStimulationlabelarr(anim, stagenum, al)
	string[] pa = SLOVE_Hentairim_Tags.GetPenisActionlabelarr(anim, stagenum, al)
	string[] orl = SLOVE_Hentairim_Tags.GetOrallabelarr(anim, stagenum, al)
	string[] pen = SLOVE_Hentairim_Tags.GetPenetrationLabelarr(anim, stagenum, al)
	string[] endlbl = SLOVE_Hentairim_Tags.GetEndingLabelarr(anim, stagenum, al)
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


;classic: stages are plain integers - the "legacy stage num" IS the stage.
;asScene is unused (classic has no string scene id); kept for signature parity.
int Function GetLegacyStageNum(String asScene, String asStage)
	return asStage as int
EndFunction




Bool Function IsVictim(actor char)
	return currentthread.IsVictim(char)
endFunction

Bool Function IsBroken()
	;resistance system: broken state is written to StorageUtil by SLOVE_Resistance
	;and read back through the Director (firewall-clean)
	return MasterScript.IsBroken(actorref)
endfunction


Function PrintDebug(string Contents = "")
	if enableprintdebug == 1
		SLOVE_Log.WriteLog(actorref.getdisplayname() + " HentaiRim Expressions " + Contents, 0)
	endif
endfunction


;-----------------------Hentairim Common Utilities END--------------------------------------
function WritetoErrorlogs(string Header = "Not Specified" ,String contents = "")
	SLOVE_Log.WriteLog(Header + " : " + contents, 2)
endfunction
