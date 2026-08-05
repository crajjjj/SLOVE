Scriptname SLOVE_Resistance extends ActiveMagicEffect
{Willpower -> break system, ported from HentairimResistance. Per-actor spell,
 applied by SLOVE_Director to eligible scene actors. Each tick, while the actor
 is being penetrated (PPA-measured via AudioUtil, SexLab-label fallback),
 willpower drains by the RISE in SexLab enjoyment x config multipliers; at 0 the
 actor "breaks". State lives in StorageUtil (SLOVE_Resistance 0-100,
 SLOVE_BrokenPoints 0-127); config in SLOVE.toml [resistance] plus the two
 SLOVE/Resistance*.json race tables. Firewall: reads SexLab for its own thread
 (like SLOVE_Expressions) but takes stage LABELS from the Director.}

SLOVE_Director Property MasterScript Auto
SexLabFramework Property SexLab Auto
SexLabThread CurrentThread = None

Actor Actorref
Actor Playerref
Actor[] actorlist
int position
bool IsPlayer
string ActorRaceName = ""
string PartnerRaceName = ""

; ---- config ([resistance] in SLOVE.toml) ----
int enable
int pcmaxresistance
int pcnonvictimmult
int npcnonvictimmult
int pcvictimmult
int npcvictimmult
int hugeppmult
int pcrecoverperhour
int npcrecoverperhour
int pcbrokenpoints
int npcbrokenpoints
int soshugeppsize
int pcnotifyinterval
int scenestartnotification
int enableprintdebug

bool IsHugePP
bool IsVictim
float AccumulatedResistanceDamage = 0.0
int LastEnjoyment = 0
; highest interval band the PC has been notified about this scene (100 = none yet);
; seeded from the starting willpower so we never announce a band she began below
int LastNotifiedBand = 100

string RaceBaseFile = "SLOVE/ResistanceRaceBase.json"
string RacePCModFile = "SLOVE/ResistanceRacePCModifier.json"

; ---- stage labels (mirrored from the Director each tick, for the fallback) ----
string StimulationLabel
string PenisActionLabel
string OralLabel
string EndingLabel
string PenetrationLabel

Event OnEffectStart(Actor akTarget, Actor akCaster)
	Actorref = akTarget
	PerformInitialization()
EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
	; stamp scene-end game time so the next scene's lazy recovery has a reference
	StorageUtil.SetFloatValue(Actorref, "SLOVE_LastSexTime", Utility.GetCurrentGameTime())
EndEvent

Function PerformInitialization()
	Playerref = Game.GetPlayer()
	IsPlayer = Actorref == Playerref
	; self-acquire the framework hooks so the magic effect carries NO CK-filled
	; properties (the sibling spells fill these in the CK; we resolve them at
	; runtime instead - SexLab quest 0xD62, and the Director = alias 0 of the
	; SLOVE main quest 0x804)
	if SexLab == None
		SexLab = Game.GetFormFromFile(0x0D62, "SexLab.esm") as SexLabFramework
	endif
	if MasterScript == None
		Quest mq = Game.GetFormFromFile(0x804, "SLOVE.esp") as Quest
		if mq
			MasterScript = mq.GetAlias(0) as SLOVE_Director
		endif
	endif
	if SexLab == None || MasterScript == None
		return
	endif
	CurrentThread = SexLab.GetThreadByActor(Actorref)
	if CurrentThread == None
		printdebug("no SexLab thread - not initializing resistance")
		return
	endif
	actorlist = CurrentThread.GetPositions()
	position = CurrentThread.GetPositionIdx(Actorref)
	ActorRaceName = Actorref.GetRace().GetName()
	if actorlist.length > 1
		PartnerRaceName = actorlist[1].GetRace().GetName()
	endif

	InitializeConfig()

	IsHugePP = IsHugePPPartner()
	; read submissive/enjoyment from OUR OWN thread, not the Director's PC thread - this
	; effect runs on NPC-only scene actors too. Identical to the Director getters for a
	; PC-scene actor (same thread), correct for an NPC scene (the Director tracks another).
	IsVictim = CurrentThread.GetSubmissive(Actorref)
	UpdateLabels(Actorref)
	; seed the enjoyment baseline so the first tick drains the DELTA, not the
	; whole current enjoyment (avoids a spike when the spell lands mid-scene)
	LastEnjoyment = CurrentThread.GetEnjoyment(Actorref)

	; seed on first ever entry
	if StorageUtil.GetIntValue(Actorref, "SLOVE_Resistance", -1) < 0
		StorageUtil.SetIntValue(Actorref, "SLOVE_Resistance", 100)
	endif

	CalculateStartupResistance()

	SeedNotifyBand()

	RegisterForSingleUpdate(0.1)
EndFunction

Function InitializeConfig()
	enable             = SLOVE_Config.GetInt("resistance.enable", 1)
	pcmaxresistance    = SLOVE_Config.GetInt("resistance.pcmaxresistance", 1000)
	pcnonvictimmult    = SLOVE_Config.GetInt("resistance.pcnonvictimmult", 20)
	npcnonvictimmult   = SLOVE_Config.GetInt("resistance.npcnonvictimmult", 30)
	pcvictimmult       = SLOVE_Config.GetInt("resistance.pcvictimmult", 110)
	npcvictimmult      = SLOVE_Config.GetInt("resistance.npcvictimmult", 130)
	hugeppmult         = SLOVE_Config.GetInt("resistance.hugeppmult", 200)
	pcrecoverperhour   = SLOVE_Config.GetInt("resistance.pcrecoverperhour", 10)
	npcrecoverperhour  = SLOVE_Config.GetInt("resistance.npcrecoverperhour", 5)
	pcbrokenpoints     = SLOVE_Config.GetInt("resistance.pcbrokenpoints", 60)
	npcbrokenpoints    = SLOVE_Config.GetInt("resistance.npcbrokenpoints", 40)
	soshugeppsize      = SLOVE_Config.GetInt("director.soshugeppsize", 6)
	pcnotifyinterval   = SLOVE_Config.GetInt("resistance.pcnotifyinterval", 25)
	scenestartnotification = SLOVE_Config.GetInt("resistance.scenestartnotification", 1)
	enableprintdebug   = SLOVE_Config.GetInt("director.printdebug", 0)
EndFunction

Event OnUpdate()
	; scene died with the magic effect stuck -> self-remove. AnimationisEnding is the PC
	; scene's teardown flag - honor it only for a PC-scene actor, else a concurrent PC
	; scene ending would wrongly end this NPC-scene resistance. NPC scenes end when their
	; own thread goes away.
	if CurrentThread == None || !SexLab.GetThreadByActor(Actorref) || (OnPCThread() && MasterScript.AnimationisEnding())
		RemoveResistanceSpell()
		return
	endif

	UpdateActorResistanceDebttoCurrent()

	if GetResistance() > 0 && IsGettingFucked()
		UpdateLabels(Actorref)
		int damagetodo = CurrentThread.GetEnjoyment(Actorref) - LastEnjoyment
		if damagetodo > 0
			LastEnjoyment = CurrentThread.GetEnjoyment(Actorref)
			AddResistanceDamage(damagetodo as float)
		endif
		RegisterForSingleUpdate(3.0)
	else
		RegisterForSingleUpdate(5.0)
	endif
EndEvent

; ---- penetration gate: PPA-measured, SexLab-label fallback ----
; PPA reports "physically inserted right now"; if the bridge isn't tracking this
; actor, fall back to the Director's position/penetration labels (SexLab p+).
bool Function IsGettingFucked()
	if AudioUtilPPA.IsConnected() && AudioUtilPPA.GetContext(Actorref) > 0
		return AudioUtilPPA.GetDepth(Actorref) > 0.0
	endif
	; --- label fallback ---
	if IsVictim
		return true
	elseif IsCowgirl()
		return false
	elseif IsgettingPenetrated() || IsGettingSuckedoff()
		return true
	endif
	return false
EndFunction

Function AddResistanceDamage(float value)
	; NOTE: the Hentairim Adventure anal/vaginal-sensitivity bonus is dropped -
	; SLO VE has no Adventure module to source sensitivity from.
	float Damage = GetPercentageofMaxResistance(value) * GetResistanceDamageMultiplier()

	if GetResistance() < 0
		return
	endif

	AccumulatedResistanceDamage += Damage
	if AccumulatedResistanceDamage >= 0.01
		int before = GetResistance()
		SetResistance(GetResistance() - Math.Floor(AccumulatedResistanceDamage * 100))
		AccumulatedResistanceDamage = 0.0
		if GetResistance() < 0
			SetResistance(0)
		endif
		MaybeNotifyResistance(before, GetResistance())
	endif

	if GetResistance() <= 0 && !IsBroken()
		if IsPlayer
			SetBrokenPoints(pcbrokenpoints)
		else
			SetBrokenPoints(npcbrokenpoints)
		endif
	endif
EndFunction

; ---- willpower-threshold notifications (PC only) ----
; seed the "already announced" band from the willpower the scene actually starts
; draining from (after lazy recovery), rounded UP to the next interval multiple,
; so crossing a band she began below never fires a stale message
Function SeedNotifyBand()
	if !IsPlayer || pcnotifyinterval <= 0
		LastNotifiedBand = 100
		return
	endif
	int cur = GetResistance()
	if cur > 100
		cur = 100
	elseif cur < 0
		cur = 0
	endif
	LastNotifiedBand = Math.Ceiling((cur as float) / (pcnotifyinterval as float)) * pcnotifyinterval
EndFunction

; announce each downward crossing of an interval band (e.g. 75/50/25 for 25),
; once per band per scene; band 0 and the break itself are left to SetBrokenPoints
Function MaybeNotifyResistance(int before, int after)
	if !IsPlayer || pcnotifyinterval <= 0 || after >= before
		return
	endif
	int threshold = Math.Ceiling((after as float) / (pcnotifyinterval as float)) * pcnotifyinterval
	if threshold > 0 && threshold < 100 && threshold < LastNotifiedBand
		LastNotifiedBand = threshold
		Debug.Notification("Your resolve weakens... (" + threshold + "%)")
	endif
EndFunction

Function UpdateActorResistanceDebttoCurrent()
	float debt = StorageUtil.GetFloatValue(Actorref, "SLOVE_ResDebt", 0.0)
	if debt > 0.0
		AddResistanceDamage(debt)
		StorageUtil.SetFloatValue(Actorref, "SLOVE_ResDebt", 0.0)
	endif
EndFunction

; ---- state (StorageUtil) ----
int Function GetResistance()
	return StorageUtil.GetIntValue(Actorref, "SLOVE_Resistance", 100)
EndFunction

Function SetResistance(int value)
	if enable != 1 || IsBroken()   ; frozen at 0 once broken
		return
	endif
	int v = value
	if v > 100
		v = 100
	endif
	StorageUtil.SetIntValue(Actorref, "SLOVE_Resistance", v)
EndFunction

int Function GetBrokenPoints()
	return StorageUtil.GetIntValue(Actorref, "SLOVE_BrokenPoints", 0)
EndFunction

Function SetBrokenPoints(int value)
	int v = value
	if v <= 0
		v = 0
	elseif v > 127
		v = 127
	endif
	if GetBrokenPoints() == 0 && v > 0 && IsPlayer
		Debug.Notification("Your will breaks...")
	endif
	StorageUtil.SetIntValue(Actorref, "SLOVE_BrokenPoints", v)
EndFunction

bool Function IsBroken()
	return GetBrokenPoints() > 0
EndFunction

; ---- damage math ----
float Function GetPercentageofMaxResistance(float value)
	return value / GetMaxResistanceAbsolute()
EndFunction

float Function GetMaxResistanceAbsolute()
	if IsPlayer
		return pcmaxresistance as float
	endif
	return JsonUtil.GetIntValue(RaceBaseFile, ActorRaceName, 100) as float
EndFunction

float Function GetResistanceDamageMultiplier()
	float mult = 1.0
	if IsPlayer
		mult = mult * JsonUtil.GetFloatValue(RacePCModFile, PartnerRaceName, 1.0)
		if IsVictim
			mult = mult * (pcvictimmult / 100.0)
		else
			mult = mult * (pcnonvictimmult / 100.0)
		endif
		if IsHugePP
			mult = mult * (hugeppmult / 100.0)
		endif
	else
		if IsVictim
			mult = mult * (npcvictimmult / 100.0)
		else
			mult = mult * (npcnonvictimmult / 100.0)
		endif
	endif
	return mult
EndFunction

; ---- lazy recovery on scene entry (game-time based; no SexLab call) ----
Function CalculateStartupResistance()
	float nowT = Utility.GetCurrentGameTime()
	float last = StorageUtil.GetFloatValue(Actorref, "SLOVE_LastSexTime", nowT)
	int hoursSince = Math.Floor((nowT - last) * 24.0)
	if hoursSince < 0
		hoursSince = 0
	endif
	; mark this scene as initialized: a mid-scene save/reload re-runs this with
	; last == now (~0 hours), so it neither recovers again nor wipes the drain
	; already taken this scene. OnEffectFinish re-stamps it at scene end.
	StorageUtil.SetFloatValue(Actorref, "SLOVE_LastSexTime", nowT)

	if IsBroken()
		SetBrokenPoints(GetBrokenPoints() - hoursSince)
		if IsBroken()
			; still broken -> pinned at 0 willpower
			StorageUtil.SetIntValue(Actorref, "SLOVE_Resistance", 0)
			if IsPlayer && scenestartnotification == 1
				Debug.Notification("You are still broken (" + GetBrokenPoints() + " hours to recover)")
			endif
		else
			SetResistance(100)
			if IsPlayer && scenestartnotification == 1
				Debug.Notification("You have recovered your composure")
			endif
		endif
		return
	endif

	if IsPlayer
		SetResistance(GetResistance() + hoursSince * pcrecoverperhour)
	else
		SetResistance(GetResistance() + hoursSince * npcrecoverperhour)
	endif
EndFunction

; ---- stage labels (from the Director for PC scenes; self-computed for NPC) + helpers ----
;true when our actor is in the PLAYER's tracked scene - keep the Director's rich
;physics-overlaid labels. False for an NPC-only scene (self-compute base labels).
bool Function OnPCThread()
	return CurrentThread && CurrentThread.HasPlayer()
EndFunction

Function UpdateLabels(actor char)
	if OnPCThread()
		StimulationLabel = MasterScript.GetStimulationlabel(char)
		PenisActionLabel = MasterScript.GetPenisActionLabel(char)
		OralLabel        = MasterScript.GetOralLabel(char)
		EndingLabel      = MasterScript.GetEndingLabel(char)
		PenetrationLabel = MasterScript.GetPenetrationLabel(char)
	else
		ComputeOwnThreadLabels(char)
	endif
EndFunction

;Base tag labels for an NPC-only scene from our OWN thread (no physics overlay - the
;penetration gate mostly rides the PPA bridge anyway; labels are the fallback).
Function ComputeOwnThreadLabels(actor char)
	StimulationLabel = ""
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
	int stagenum = MasterScript.GetLegacyStageNum(sceneid, CurrentThread.GetActiveStage())
	actor[] al = CurrentThread.GetPositions()
	string[] stim = SLOVE_Hentairim_Tags.GetStimulationlabelarr(sceneid, stagenum, al)
	string[] pa = SLOVE_Hentairim_Tags.GetPenisActionLabelarr(sceneid, stagenum, al)
	string[] orl = SLOVE_Hentairim_Tags.GetOralLabelarr(sceneid, stagenum, al)
	string[] pen = SLOVE_Hentairim_Tags.GetPenetrationLabelarr(sceneid, stagenum, al)
	string[] endlbl = SLOVE_Hentairim_Tags.GetEndingLabelarr(sceneid, stagenum, al)
	if idx < stim.length
		StimulationLabel = stim[idx]
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
EndFunction

bool Function IsgettingPenetrated()
	return IsGettingVaginallyPenetrated() || IsGettingAnallyPenetrated()
EndFunction

bool Function IsGettingVaginallyPenetrated()
	return PenetrationLabel == "SVP" || PenetrationLabel == "FVP" || PenetrationLabel == "SCG" || PenetrationLabel == "FCG" || PenetrationLabel == "SDP" || PenetrationLabel == "FDP"
EndFunction

bool Function IsGettingAnallyPenetrated()
	return PenetrationLabel == "SAP" || PenetrationLabel == "FAP" || PenetrationLabel == "SAC" || PenetrationLabel == "FAC" || PenetrationLabel == "SDP" || PenetrationLabel == "FDP"
EndFunction

bool Function IsGettingSuckedoff()
	return PenisActionLabel == "SMF" || PenisActionLabel == "FMF"
EndFunction

bool Function IsCowgirl()
	return PenetrationLabel == "SCG" || PenetrationLabel == "FCG" || PenetrationLabel == "SAC" || PenetrationLabel == "FAC"
EndFunction

; ---- huge-partner check (position-0 receiver only), ported from Hentairim ----
bool Function IsHugePPPartner()
	if position != 0 || actorlist.length < 2
		return false
	endif
	Actor partner = actorlist[1]
	string mr = partner.GetRace().GetName()
	if StringUtil.Find(mr, "Brute") > -1 || StringUtil.Find(mr, "Spider") > -1 || StringUtil.Find(mr, "Lurker") > -1 || StringUtil.Find(mr, "Daedroth") > -1 || StringUtil.Find(mr, "Horse") > -1 || StringUtil.Find(mr, "Bear") > -1 || StringUtil.Find(mr, "Chaurus") > -1 || StringUtil.Find(mr, "Dragon") > -1 || StringUtil.Find(mr, "Giant") > -1 || StringUtil.Find(mr, "Troll") > -1 || StringUtil.Find(mr, "Gargoyle") > -1 || StringUtil.Find(mr, "Ogr") > -1 || mr == "Frost Atronach" || mr == "Mammoth" || mr == "Sabre Cat" || mr == "Werewolf" || mr == "Dwarven Centurion"
		return true
	endif
	;guard the lookup like the TNG branch below: GetFormFromFile on an absent plugin
	;errors in the Papyrus log on every call, and SOS's .esp is missing on any install
	;running TNG (or SOS Core.esm alone) - the TNG keyword branch covers those
	if isDependencyReady("Schlongs of Skyrim.esp")
		Faction sos = Game.GetFormFromFile(0xAFF8, "Schlongs of Skyrim.esp") as Faction
		if sos
			return partner.GetFactionRank(sos) >= soshugeppsize
		endif
	endif
	if isDependencyReady("TheNewGentleman.esp")
		Keyword tngXL = Game.GetFormFromFile(0xFE5, "TheNewGentleman.esp") as Keyword
		if partner.HasKeyword(tngXL)
			return true
		endif
	endif
	return false
EndFunction

Function RemoveResistanceSpell()
	Spell rs = Game.GetFormFromFile(0x808, "SLOVE.esp") as Spell
	if rs
		Actorref.RemoveSpell(rs)
	endif
EndFunction

bool Function isDependencyReady(String modname)
	int index = Game.GetModByName(modname)
	return index != 255 && index != -1
EndFunction

Function printdebug(string contents = "")
	if enableprintdebug == 1
		SLOVE_Log.WriteLog(Actorref.GetDisplayName() + " SLOVE Resistance " + contents, 0)
	endif
EndFunction
