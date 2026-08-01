Scriptname SLOVE_NpcScene extends ActiveMagicEffect
{SLO VE NPC-only scene driver. Applied by SLOVE_Director to ONE anchor actor of a
 SexLab scene the player is NOT in (near the player, under the concurrency cap). Drives
 light ambient voice (moans / breathing / reactions) for that scene through AudioUtil.
 The per-actor expressions / SFX / resistance spells are applied separately by the
 Director and self-terminate on their own thread, so this driver only owns the ambient
 voice + the scene's SexLab-voice suppression, and self-terminates when the scene ends.
 Self-contained: resolves its own thread from the anchor and never touches the PC voice
 engine. No dirty-talk protagonist, no milk, no on-screen notifications. Shared script
 (P+ and classic both apply it) - it uses only generic SexLab / AudioUtil / Director APIs.}

SLOVE_Director Property MasterScript Auto ;runtime-resolved (no CK property) - alias 0 of SLOVE main quest
SexLabFramework Property SexLab Auto      ;runtime-resolved (SexLab.esm quest 0x0D62)
SexLabThread CurrentThread = None

Actor anchor
Actor[] sceneMales
Actor[] sceneFemales
Actor[] sceneCreatures
int threadId

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
float npcvolume
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
	; self-acquire the framework + Director so the effect carries no CK-filled
	; properties (same pattern as SLOVE_Resistance): SexLab quest 0x0D62, and the
	; Director = alias 0 of the SLOVE main quest 0x804
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
	CurrentThread = SexLab.GetThreadByActor(anchor)
	if CurrentThread == None
		RemoveSelf()
		return
	endif
	threadId = CurrentThread.GetThreadID()
	; climax cries: SexLab fires this per orgasming actor for EVERY scene; we keep only
	; our own thread's (the PC engine + each other NpcScene do the same)
	RegisterForModEvent("SexLabOrgasmSeparate", "NpcSceneOrgasm")
	InitializeConfig()
	; NPC scenes ride their OWN volume bus (npc_low/npc_high) so voice.npcscenevolume
	; tunes them apart from your own scene's partners. Each NpcScene sets it, so it
	; applies even without a PC scene ever having run (unlike partner_low).
	AudioUtil.SetGroupVolume("npc_low", npcvolume)
	AudioUtil.SetGroupVolume("npc_high", npcvolume)
	BucketActors()
	SuppressSexLabVoice()
	; seed cooldowns so first ambient comes early
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
	; dedicated NPC-scene voice volume (own audio bus), default = partnervolume so it
	; matches the old behavior until set. 0-100 -> 0-1 for SetGroupVolume.
	npcvolume               = SLOVE_Config.GetInt("voice.npcscenevolume", SLOVE_Config.GetInt("voice.partnervolume", 100)) as float / 100
	enableprintdebug        = SLOVE_Config.GetInt("director.printdebug", 0)
EndFunction

; Bucket the scene's actors by kind, mirroring SLOVE_Voice.FindActorsAndVoices but
; PC-free (no actor here is the player). Females/creatures only count when they
; resolve to an AudioUtil slot, so an unmapped creature stays silent rather than
; erroring; males always resolve (stock M0 fallback).
Function BucketActors()
	sceneMales = PapyrusUtil.ActorArray(0)
	sceneFemales = PapyrusUtil.ActorArray(0)
	sceneCreatures = PapyrusUtil.ActorArray(0)
	Actor[] actorList = CurrentThread.GetPositions()
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

; Mirror the Director: when SLO VE voice is on and suppression is enabled, silence
; SexLab's own moans for the scene actors so AudioUtil's ambient is the sole voice
; (no doubling). ForceSilent auto-resets when SexLab clears the aliases at scene end.
Function SuppressSexLabVoice()
	if enablevoice != 1 || suppresssexlabvoice != 1 || !SLOVE_Config.Available()
		return
	endif
	Actor[] actorList = CurrentThread.GetPositions()
	int i = 0
	while i < actorList.length
		if actorList[i]
			CurrentThread.SetActorVoice(actorList[i], "", true)
		endif
		i += 1
	endwhile
EndFunction

; A scene actor climaxed -> play their orgasm cry (their own pack, partner climax bus,
; their own channel so it cuts any in-flight moan). Filtered to THIS scene's thread.
; Males gated by enablemalevoice, mirroring the ambient path; the category resolves
; per-actor (female / male / creature), so an actor with no orgasm content just no-ops.
Event NpcSceneOrgasm(Form actorRef, Int thread)
	if enablevoice != 1 || thread != threadId
		return
	endif
	Actor a = actorRef as Actor
	if !a
		return
	endif
	if SexLab.GetGender(a) == 0 && enablemalevoice != 1
		return
	endif
	MasterScript.PlaySound("Orgasm", a, False, "npc_high", "slove_np" + a.GetFormID())
EndEvent

Event OnUpdate()
	; scene ended -> self-remove (the per-actor module spells self-terminate too)
	if CurrentThread == None || !SexLab.GetThreadByActor(anchor)
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

; Coarse intensity for ambient cadence: the anchor (position 0 receiver) crossing the
; SexLab enjoyment hype threshold. No physics overlay - that is the PC engine's job;
; NPC scenes get light ambient only.
bool Function SceneIsIntense()
	return CurrentThread.GetEnjoyment(anchor) >= intenseenjoyment
EndFunction

Function PlayMaleMoaning(bool intense)
	if enablemalevoice != 1 || enablemalemoaning != 1 || sceneMales.length == 0
		return
	endif
	float now = CurrentThread.GetTimeTotal()
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
	; gated by voice.voiceallactors, like the PC engine's secondary-female ambience
	if voiceAllActors != 1 || sceneFemales.length == 0
		return
	endif
	float now = CurrentThread.GetTimeTotal()
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
	float now = CurrentThread.GetTimeTotal()
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
	MasterScript.PlaySound("Breathing", c, False, "npc_low", "slove_np" + c.GetFormID())
EndFunction

; Route a human ambient line through the Director's PlaySound (partner group + own
; channel, FaceOwnsMouth handled). The actor's own slot resolves male vs female audio,
; so no forceFemaleVoice is needed (unlike the PC-as-lead engine). Distance falloff for
; far NPC scenes is handled by AudioUtil ([general] voice_attenuation), not here.
Function PlayAmbient(Actor a, bool intense)
	string cat = "PenetrativeGrunts"
	if intense
		cat = "NearOrgasmNoises"
	endif
	MasterScript.PlaySound(cat, a, False, "npc_low", "slove_np" + a.GetFormID())
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
