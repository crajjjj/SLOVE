Scriptname SLOVE_NpcScene extends ActiveMagicEffect
{SLO VE NPC-only scene driver (CLASSIC SexLab 1.63 variant). Applied by SLOVE_Director
 to ONE anchor actor of a SexLab scene the player is NOT in (near the player, under the
 concurrency cap). Drives light ambient voice (moans / breathing / reactions) for that
 scene through AudioUtil. The per-actor expressions / SFX / resistance spells are applied
 separately by the Director and self-terminate on their own thread, so this driver only
 owns the ambient voice + the scene's SexLab-voice suppression, and self-terminates when
 the scene ends. Self-contained: resolves its own controller from the anchor, never
 touches the PC voice engine. No dirty-talk protagonist, no milk, no notifications.}

SLOVE_Director Property MasterScript Auto ;runtime-resolved (no CK property) - alias 0 of SLOVE main quest
SexLabFramework Property SexLab Auto      ;runtime-resolved (SexLab.esm quest 0x0D62)
sslThreadController CurrentThread = None

Actor anchor
Actor[] sceneMales
Actor[] sceneFemales
Actor[] sceneCreatures

; ---- config ([voice]/[director] in SLOVE.toml) ----
int enablevoice
int suppresssexlabvoice
int voiceAllActors
int enablemalevoice
int enablemalemoaning
int enablecreaturebreathing
float malemoanmininterval
float malemoanmaxinterval
float creaturebreathmininterval
float creaturebreathmaxinterval
int intenseenjoyment
int enableprintdebug

float lastMaleMoanTime
float maleMoanCooldown
float lastCreatureBreathTime
float creatureBreathCooldown
float lastFemaleLineTime
float femaleLineCooldown

Event OnEffectStart(Actor akTarget, Actor akCaster)
	anchor = akTarget
	PerformInitialization()
EndEvent

Function PerformInitialization()
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
		RemoveSelf()
		return
	endif
	CurrentThread = SexLab.GetActorController(anchor)
	if CurrentThread == None
		RemoveSelf()
		return
	endif
	InitializeConfig()
	BucketActors()
	SuppressSexLabVoice()
	lastMaleMoanTime = 0.0
	maleMoanCooldown = Utility.RandomFloat(2.0, 5.0)
	lastCreatureBreathTime = 0.0
	creatureBreathCooldown = Utility.RandomFloat(2.0, 5.0)
	lastFemaleLineTime = 0.0
	femaleLineCooldown = Utility.RandomFloat(6.0, 14.0)
	printdebug("NPC-scene driver start: males=" + sceneMales.length + " females=" + sceneFemales.length + " creatures=" + sceneCreatures.length)
	RegisterForSingleUpdate(1.0)
EndFunction

Function InitializeConfig()
	enablevoice             = SLOVE_Config.GetInt("director.enablevoice", 1)
	suppresssexlabvoice     = SLOVE_Config.GetInt("director.suppresssexlabvoice", 1)
	voiceAllActors          = SLOVE_Config.GetInt("voice.voiceallactors", 1)
	enablemalevoice         = SLOVE_Config.GetInt("voice.enablemalevoice", 1)
	enablemalemoaning       = SLOVE_Config.GetInt("voice.malemoaning", 1)
	enablecreaturebreathing = SLOVE_Config.GetInt("voice.creaturebreathing", 1)
	malemoanmininterval     = SLOVE_Config.GetInt("voice.malemoanmininterval", 5) as float
	malemoanmaxinterval     = SLOVE_Config.GetInt("voice.malemoanmaxinterval", 12) as float
	creaturebreathmininterval = SLOVE_Config.GetInt("voice.creaturebreathmininterval", 5) as float
	creaturebreathmaxinterval = SLOVE_Config.GetInt("voice.creaturebreathmaxinterval", 12) as float
	intenseenjoyment        = SLOVE_Config.GetInt("voice.femaleorgasmhypeenjoyment", 75)
	enableprintdebug        = SLOVE_Config.GetInt("director.printdebug", 0)
EndFunction

; Bucket the scene's actors by kind (PC-free - no actor here is the player). Females /
; creatures only count when they resolve to an AudioUtil slot.
Function BucketActors()
	sceneMales = PapyrusUtil.ActorArray(0)
	sceneFemales = PapyrusUtil.ActorArray(0)
	sceneCreatures = PapyrusUtil.ActorArray(0)
	Actor[] actorList = CurrentThread.Positions
	int i = 0
	while i < actorList.length
		Actor a = actorList[i]
		if a
			int g = SexLab.GetGender(a)
			if g > 1
				if AudioUtil.GetSlotForActor(a) != ""
					sceneCreatures = PapyrusUtil.PushActor(sceneCreatures, a)
				endif
			elseif g == 0
				sceneMales = PapyrusUtil.PushActor(sceneMales, a)
			elseif AudioUtil.GetSlotForActor(a) != ""
				sceneFemales = PapyrusUtil.PushActor(sceneFemales, a)
			endif
		endif
		i += 1
	endwhile
EndFunction

; Mirror the Director: silence SexLab's own moans for the scene actors so AudioUtil's
; ambient is the sole voice (no doubling). Classic silences per-actor via the alias.
; ForceSilence auto-resets when SexLab clears the aliases at scene end.
Function SuppressSexLabVoice()
	if enablevoice != 1 || suppresssexlabvoice != 1 || !SLOVE_Config.Available()
		return
	endif
	Actor[] actorList = CurrentThread.Positions
	int i = 0
	while i < actorList.length
		if actorList[i]
			sslActorAlias a = CurrentThread.ActorAlias(actorList[i])
			if a
				a.SetVoice(none, true)
			endif
		endif
		i += 1
	endwhile
EndFunction

Event OnUpdate()
	; scene ended -> self-remove (the per-actor module spells self-terminate too)
	if CurrentThread == None || !SexLab.GetActorController(anchor)
		RemoveSelf()
		return
	endif
	if enablevoice == 1
		bool intense = SceneIsIntense()
		PlayMaleMoaning(intense)
		PlayFemaleNPCComments(intense)
		PlayCreatureBreathing(intense)
	endif
	RegisterForSingleUpdate(1.0)
EndEvent

; Coarse intensity for ambient cadence: the anchor (position 0) crossing the SexLab
; enjoyment hype threshold. Classic has no physics overlay; NPC scenes get light ambient.
bool Function SceneIsIntense()
	return CurrentThread.GetEnjoyment(anchor) >= intenseenjoyment
EndFunction

Function PlayMaleMoaning(bool intense)
	if enablemalevoice != 1 || enablemalemoaning != 1 || sceneMales.length == 0
		return
	endif
	float now = CurrentThread.TotalTime
	if now - lastMaleMoanTime < maleMoanCooldown
		return
	endif
	Actor m = sceneMales[Utility.RandomInt(0, sceneMales.length - 1)]
	if m == None
		return
	endif
	lastMaleMoanTime = now
	float minPause = malemoanmininterval
	float maxPause = malemoanmaxinterval
	if intense
		minPause = minPause / 2.0
		maxPause = maxPause / 2.0
	endif
	maleMoanCooldown = Utility.RandomFloat(minPause, maxPause)
	PlayAmbient(m, intense)
EndFunction

Function PlayFemaleNPCComments(bool intense)
	if voiceAllActors != 1 || sceneFemales.length == 0
		return
	endif
	float now = CurrentThread.TotalTime
	if now - lastFemaleLineTime < femaleLineCooldown
		return
	endif
	Actor f = sceneFemales[Utility.RandomInt(0, sceneFemales.length - 1)]
	if f == None
		return
	endif
	lastFemaleLineTime = now
	femaleLineCooldown = Utility.RandomFloat(6.0, 14.0)
	PlayAmbient(f, intense)
EndFunction

Function PlayCreatureBreathing(bool intense)
	if enablecreaturebreathing != 1 || sceneCreatures.length == 0
		return
	endif
	float now = CurrentThread.TotalTime
	if now - lastCreatureBreathTime < creatureBreathCooldown
		return
	endif
	Actor c = sceneCreatures[Utility.RandomInt(0, sceneCreatures.length - 1)]
	if c == None
		return
	endif
	lastCreatureBreathTime = now
	float minPause = creaturebreathmininterval
	float maxPause = creaturebreathmaxinterval
	if intense
		minPause = minPause / 2.0
		maxPause = maxPause / 2.0
	endif
	creatureBreathCooldown = Utility.RandomFloat(minPause, maxPause)
	MasterScript.PlaySound("Breathing", c, False, "partner_low", "slove_np" + c.GetFormID())
EndFunction

; Route a human ambient line through the Director's PlaySound (partner group + own
; channel, FaceOwnsMouth handled). The actor's own slot resolves male vs female audio.
; Distance falloff for far NPC scenes is handled by AudioUtil ([general]
; voice_attenuation), not here.
Function PlayAmbient(Actor a, bool intense)
	string cat = "PenetrativeGrunts"
	if intense
		cat = "NearOrgasmNoises"
	endif
	MasterScript.PlaySound(cat, a, False, "partner_low", "slove_np" + a.GetFormID())
EndFunction

Function RemoveSelf()
	Spell s = Game.GetFormFromFile(0x81E, "SLOVE.esp") as Spell
	if s && anchor
		anchor.RemoveSpell(s)
	endif
EndFunction

Function printdebug(string contents = "")
	if enableprintdebug == 1
		SLOVE_Log.WriteLog("SLOVE NPC-scene " + contents, 0)
	endif
EndFunction
