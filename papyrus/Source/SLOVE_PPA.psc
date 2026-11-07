Scriptname SLOVE_PPA Hidden
{SLO VE's Accurate Penetration readings, from SLOVE.dll's own PPA bridge (since
 0.7.10; SLO VE read AudioUtilPPA before). The natives answer from a cache the
 DLL fills on every PPA frame, so a call is cheap, but keep polls at voice-line
 or SFX-tick cadence, never in a tight loop. Every reading is 0 when nothing is
 measured: PPA absent, the actor unknown, or nothing tracked.
 Read/CtxOf/SiteOf/HasSite/DepthOf are the one-reading-per-voice-line helpers
 shared by the PC voice engine and the NPC-scene driver.}

;---------------- natives (SLOVE.dll) ----------------

;AccuratePenetration.dll is loaded and answered the handshake.
Bool Function IsConnected() native global

;The deepest of anything touching the receiver, self-penetration included.
;PPA's one PHYSICAL signal; working range roughly 2 (shallow) to 10 (deep).
Float Function GetDepth(Actor akReceiver) native global

;PPA's SceneContext bitmask: 1 vaginal, 2 anal, 4 oral, 8 aggressive, 16 femdom,
;32 loving, 64 dirty, 128 boobjob, 256 handjob, 512 footjob, 1024 masturbation.
;Scene CLASSIFICATION like SexLab tags, not contact: for "inserted right now"
;require a bit AND GetDepth > 0.
Int Function GetContext(Actor akReceiver) native global

;Where the receiver's deepest partner is: 0 None, 1 Mouth, 2 Anus, 3 Vagina,
;4 Both, 5 HandL, 6 HandR, 7 Hands.
Int Function GetPenetrationSite(Actor akReceiver) native global

;"Magic unsigned numbers" per the PPA author: 0.0 = closed, larger = more open,
;no defined scale, and the two orifices use different ones.
Float Function GetVaginalOpening(Actor akReceiver) native global
Float Function GetAnalOpening(Actor akReceiver) native global

;The whole reading in one call: [0] depth, [1] context bitmask, [2] penetration
;site, [3] sites bitmask (1 << site per partner), [4] self-penetration site,
;[5] vaginal opening, [6] anal opening. Always 7 slots; all zeros = nothing.
Float[] Function GetSnapshot(Actor akReceiver) native global

;How deep akGiver is inside akReceiver: that partner's own depth when PPA lists
;akGiver among the receiver's partners, else the receiver's deepest (GetDepth).
Float Function GetPairDepth(Actor akGiver, Actor akReceiver) native global

;The thrust watch (SLOVE_SFX). While it runs, the DLL feeds every PPA frame of
;the pair to the turn detector and sends one mod event per turn, sender = akGiver:
;  SLOVE_PPAImpact   numArg = how long the inward stroke took (s), strArg = the
;                    stroke and depth, for the printdebug line
;  SLOVE_PPAReentry  numArg = the last inward stroke's time, strArg = the depth
;afTurn is the hysteresis (sfx.ppathrustturn). One watch per giver: a new one
;replaces the old. A load or a new game drops them all.
Function WatchThrusts(Actor akGiver, Actor akReceiver, Float afTurn) native global
Function UnwatchThrusts(Actor akGiver) native global

;---------------- one reading per voice line ----------------

;The snapshot above; read the slots through the helpers below.
float[] Function Read(Actor a) Global
	return GetSnapshot(a)
EndFunction

;The context bitmask (0 = none measured). Decompose with Math.LogicalAnd.
Int Function CtxOf(float[] snap) Global
	if snap.length > 1
		return snap[1] as int
	endif
	return 0
EndFunction

;The penetration site ordinal (0 = none measured).
Int Function SiteOf(float[] snap) Global
	if snap.length > 2
		return snap[2] as int
	endif
	return 0
EndFunction

Bool Function HasSite(float[] snap) Global
	return SiteOf(snap) != 0
EndFunction

;The measured depth (0.0 = none measured).
Float Function DepthOf(float[] snap) Global
	if snap.length > 0
		return snap[0]
	endif
	return 0.0
EndFunction
