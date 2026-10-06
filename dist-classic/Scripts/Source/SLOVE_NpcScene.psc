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
bool sceneHasPenetrator ;any male or creature in the raw position list (slot or not)
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
float npcdepthintense ;voice.npcdepthintense: HER measured PPA depth for the intense pools (0 = off)
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
	threadId = CurrentThread.tid
	; climax cries: SexLab fires this per orgasming actor for EVERY scene; we keep only
	; our own thread's (the PC engine + each other NpcScene do the same)
	RegisterForModEvent("SexLabOrgasmSeparate", "NpcSceneOrgasm")
	InitializeConfig()
	; NPC scenes ride their OWN volume bus (npc_low/npc_high) so voice.npcscenevolume
	; tunes them apart from your own scene's partners. Each NpcScene sets it, so it
	; applies even without a PC scene ever having run - the classic SLOVE_Voice only
	; sets pc_*/partner_*, so without this the npc_* groups stay at the toml startup
	; default (1.0) and voice.npcscenevolume is ignored (NPC scenes always full volume).
	AudioUtil.SetGroupVolume("npc_low", npcvolume)
	AudioUtil.SetGroupVolume("npc_high", npcvolume)
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
	npcdepthintense         = SLOVE_Config.GetFloat("voice.npcdepthintense", 6.0)
	; dedicated NPC-scene voice volume (own audio bus), default = partnervolume so it
	; matches the old behavior until set. 0-100 -> 0-1 for SetGroupVolume.
	npcvolume               = SLOVE_Config.GetInt("voice.npcscenevolume", SLOVE_Config.GetInt("voice.partnervolume", 100)) as float / 100
	enableprintdebug        = SLOVE_Config.GetInt("director.printdebug", 0)
EndFunction

; Bucket the scene's actors by kind (PC-free - no actor here is the player). Females /
; creatures only count when they resolve to an AudioUtil slot.
Function BucketActors()
	sceneMales = PapyrusUtil.ActorArray(0)
	sceneFemales = PapyrusUtil.ActorArray(0)
	sceneCreatures = PapyrusUtil.ActorArray(0)
	sceneHasPenetrator = false
	Actor[] actorList = CurrentThread.Positions
	int i = 0
	while i < actorList.length
		Actor a = actorList[i]
		if a
			int g = SexLab.GetGender(a)
			if g > 1
				sceneHasPenetrator = true ;voiced or not - FemaleIsPenetrated cares about anatomy, not slots
				if AudioUtil.GetSlotForActor(a) != ""
					sceneCreatures = PapyrusUtil.PushActor(sceneCreatures, a)
				endif
			elseif g == 0
				sceneHasPenetrator = true
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
		; an actor another mod has muted here (SLOVE_Mute_*) keeps whatever SexLab voice
		; state that mod gave them - it may have muted us to let SexLab's voice play
		if actorList[i] && SLOVE_Utils.MuteLevel(actorList[i], threadId) == 0
			sslActorAlias a = CurrentThread.ActorAlias(actorList[i])
			if a
				a.SetVoice(none, true)
			endif
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
	;same hold as OnUpdate - this one is event-driven, so it needs its own gate
	if SLOVE_Utils.GamePaused()
		return
	endif
	MasterScript.PlaySound("Orgasm", a, False, "npc_high", SLOVE_Utils.VoiceChannel(a), SceneFacts(SceneIsIntense(), "mine"))
EndEvent

Event OnUpdate()
	; scene ended -> self-remove (the per-actor module spells self-terminate too)
	if CurrentThread == None || !SexLab.GetActorController(anchor)
		RemoveSelf()
		return
	endif
	;same hold as the PC engine's OnUpdate: a menu that freezes the scene must not
	;let ambient voice keep walking over an animation that isn't moving. Lines
	;already playing ring out; nothing new starts until the menu closes.
	; SexLab's own voice is silenced once at scene start, but a mod that mutes an actor
	; here (SLOVE_Mute_*) often hands SexLab's voice back with ForceSilence off when it
	; is done, which drops our silence too - re-assert it while that can have happened
	if SLOVE_Utils.MuteJustLifted()
		SuppressSexLabVoice()
	endif
	if enablevoice == 1 && !SLOVE_Utils.GamePaused()
		bool intense = SceneIsIntense()
		PlayMaleMoaning(intense)
		PlayFemaleNPCComments(intense)
		PlayCreatureBreathing(intense)
	endif
	RegisterForSingleUpdate(1.0)
EndEvent

;Variation-D facts for an NPC-scene line. Only what an NPC scene actually knows:
;the ambient intensity beat, plus "mine" on a climax cry. Deliberately no mood -
;this engine has no victim/femdom model - and no LABEL-derived act facts either;
;the one act source it trusts is PPA's per-receiver site, which PlayAmbient
;appends itself when measured ("giv oral" / "rcv anal" / ...). A fact this
;engine cannot stand behind would route the line into a pool that means
;something else; facts it omits simply leave those pools unqualified, so a
;tagged pack falls back to its untagged floor exactly as before.
String Function SceneFacts(bool intense, String extraFacts = "")
	if intense
		return extraFacts + " intense"
	endif
	return extraFacts + " soft"
EndFunction

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
	PlayAmbient(f, intense, true)
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
	MasterScript.PlaySound("Breathing", c, False, "npc_low", SLOVE_Utils.VoiceChannel(c), SceneFacts(intense))
EndFunction

; Route a human ambient line through the Director's PlaySound (partner group + own
; channel, FaceOwnsMouth handled). The actor's own slot resolves male vs female audio.
; Distance falloff for far NPC scenes is handled by AudioUtil ([general]
; voice_attenuation), not here.
; For a FEMALE the beat is act-aware wherever PPA measures HER: her own depth
; picks soft vs intense (voice.npcdepthintense - the same knob as the PC
; engine's NPC beats), her site picks the sound - a full mouth gets muffled
; sucking instead of open moans, a named hole keeps the grunt and states its
; place in the facts - and with no measurement the composition rule stands:
; grunt only when the scene has a male/creature to do it, breathe in an
; all-female scene. Males keep the grunt names: on a male slot they ARE the
; generic moan categories (PlayMaleMoaning requests the same two).
Function PlayAmbient(Actor a, bool intense, bool female = false)
	string cat = "PenetrativeGrunts"
	string actFacts = ""
	if female
		float[] snap = SLOVE_PPA.Read(a)
		;her own measured depth beats the anchor-enjoyment guess (0 = knob off)
		float depth = SLOVE_PPA.DepthOf(snap)
		if npcdepthintense > 0.0 && depth > 0.0
			intense = depth >= npcdepthintense
		endif
		int site = SLOVE_PPA.SiteOf(snap)
		if site == 1
			;a penis in HER mouth - muffled sucking, not open moans
			cat = "BlowjobActionSoft"
			if intense
				cat = "BlowjobActionIntense"
			endif
			actFacts = " giv oral"
		elseif site == 2
			actFacts = " rcv anal"
		elseif site == 3
			actFacts = " rcv vaginal"
		elseif site == 4
			actFacts = " rcv dp"
		elseif site >= 5 || !sceneHasPenetrator
			;her hands are busy, or nothing measured in an all-female scene
			cat = "BreathySoft"
			if intense
				cat = "BreathyIntense"
			endif
		endif
		;site 0 with a penetrator present: the plausible grunt stands unchanged
	endif
	if cat == "PenetrativeGrunts" && intense
		cat = "NearOrgasmNoises"
	endif
	MasterScript.PlaySound(cat, a, False, "npc_low", SLOVE_Utils.VoiceChannel(a), SceneFacts(intense) + actFacts)
EndFunction

;PPA readings live in SLOVE_PPA (shared with the PC voice engine - this used to
;be a second copy of the same reader). Read once per line, never in a loop.

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
