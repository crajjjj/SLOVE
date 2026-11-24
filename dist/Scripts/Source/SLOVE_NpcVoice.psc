Scriptname SLOVE_NpcVoice Hidden
{The female-NPC beat DECISION, as one pure table: act + measurements in,
 (A-name category, B-folder debugtext) out. Extracted from SLOVE_Voice so the
 dispatch reads as data and the engine keeps only the play step - the caller
 owns every stateful input (her PPA reading, the intensity pick, the victim
 flag, the comment-chance knob) and plays the returned pick through its own
 PlaySound. A-name/debugtext pairs are the ones the PC's own dispatch uses for
 the same folders, so an A/stock slot degrades the same way hers does.}

;Decide the beat for one female NPC line.
;  act            - her side of the act (SLOVE_Voice.ResolveSpeakerAct):
;                   [0] dir giv/rcv/"", [1] place, [2] implement
;  intense        - her pool intensity (measured depth, else the scene beat)
;  ctx            - her PPA context bitmask (0 = none measured)
;  victim         - she is the coerced party (SexLab flag or Aggressive ctx)
;  compositionGrunt - unmeasured bystander in a scene with a penetrator:
;                   the plausible-grunt rule decided by the caller
;  commentChance  - fraction of beats allowed to be full SPOKEN lines; a
;                   failed roll falls to the non-verbal beat, never silence
;Returns String[2]: [0] = A-name category, [1] = B-folder debugtext.
String[] Function Decide(String[] act, Bool intense, Int ctx, Bool victim, Bool compositionGrunt, Float commentChance) Global
	;her mouth is full - muffled action sounds, not open moans. Always a cock
	;or a strapon: giv/oral only arises from the lead's PenisActionLabel or
	;from HER site reading Mouth, and the label set has no "being licked"
	;state, so there is no cunnilingus-giving case to route to Licking pools.
	if act[0] == "giv" && act[1] == "oral"
		if intense
			return Pick("BlowjobActionIntense", "Blowjob Action Intense")
		endif
		return Pick("BlowjobActionSoft", "Blowjob Action")
	endif
	;penetrated - by her own measured site, the inverted lead labels, or the
	;caller's composition rule
	if (act[0] == "rcv" && (act[1] == "vaginal" || act[1] == "anal" || act[1] == "dp")) || compositionGrunt
		return DecideGrunt(intense, ctx, act[1], victim, commentChance)
	endif
	;not penetrated: a foreplay act she is giving (spoken, chance-gated) ...
	String[] foreplay = TryForeplay(act, ctx, commentChance)
	if foreplay[0] != ""
		return foreplay
	endif
	;... else the breathing floor; the lead's mouth on her is arousing whatever
	;the scene-wide beat says, so rcv/oral forces the intense pool
	if intense || (act[0] == "rcv" && act[1] == "oral")
		return Pick("BreathyIntense", "Breathing Intense")
	endif
	return Pick("BreathySoft", "Breathing")
EndFunction

;The penetrated beat, partitioned by tone and hole. Victim first (the Victim
;folders were the single biggest B-pack family an NPC could never reach), then
;the femdom / DP / anal SPOKEN comments behind the comment roll, so an NPC
;stays mostly non-verbal; a failed roll falls to the plain grunt.
String[] Function DecideGrunt(Bool intense, Int ctx, String place, Bool victim, Float commentChance) Global
	if victim
		if intense
			return Pick("CumTogetherTease", "Penetrated Grunt Victim Intense")
		endif
		return Pick("Unamused", "Penetrated Grunt Victim")
	endif
	if Math.LogicalAnd(ctx, 16) == 16 && Roll(commentChance)
		;FemDom-classified and she is penetrated - the dominant woman riding
		if intense
			return Pick("SensitivePleasure", "Penetrated Comments Femdom Intense")
		endif
		return Pick("PenetrativeCommentsIntense", "Penetrated Comments Femdom")
	endif
	if place == "dp" && Roll(commentChance)
		return Pick("TeaseAnal", "Penetrated Double Comments")
	endif
	if place == "anal" && intense && Roll(commentChance)
		;no soft-anal pair exists anywhere in the engine - soft anal stays a grunt
		return Pick("IntenseAnal", "Penetrated Anal Comments Intense")
	endif
	if intense
		return Pick("NearOrgasmNoises", "Penetrated Grunt Intense")
	endif
	return Pick("PenetrativeGrunts", "Penetrated Grunt")
EndFunction

;Foreplay acts she is GIVING - boob/hand/foot from her act (site- or
;context-derived) or straight from PPA's classification bits, plus the femdom
;foreplay tone. All spoken comment folders, so each sits behind the comment
;roll; an empty result = nothing fits or the roll failed, and Decide falls to
;breathing. The act's dir gate matters: rcv/hand is her being fingered, not
;her giving a handjob - only giv routes to the giver's lines. Returns a pick
;whose [0] is "" when nothing fits - never a None array.
String[] Function TryForeplay(String[] act, Int ctx, Float commentChance) Global
	if Math.LogicalAnd(ctx, 16) == 16 && Roll(commentChance)
		return Pick("Satisfied", "Foreplay Femdom Comments")
	endif
	if ((act[0] == "giv" && act[1] == "chest") || Math.LogicalAnd(ctx, 128) == 128) && Roll(commentChance)
		return Pick("ForeplayIntense", "Foreplay BoobJob Comments")
	endif
	if ((act[0] == "giv" && act[1] == "hand") || Math.LogicalAnd(ctx, 256) == 256) && Roll(commentChance)
		return Pick("ForeplaySoft", "Foreplay Handjob Comments")
	endif
	if ((act[0] == "giv" && act[1] == "feet") || Math.LogicalAnd(ctx, 512) == 512) && Roll(commentChance)
		return Pick("MadeMeCumSoMuch", "Foreplay FootJob Comments")
	endif
	;nothing fits, or every roll failed: an empty A-name is the sentinel. A
	;declared-but-unassigned array is None, and reading .length on it is a VM
	;error - on the COMMON path, since most beats fail the comment roll.
	return Pick("", "")
EndFunction

;Is she the scene's coerced party? One rule for every engine; the caller passes
;SexLab's answers from its own thread. The flag names the victim outright, and
;when it names someone else she is not it. Only a scene that flags nobody falls
;back to PPA classifying HER interaction Aggressive (ctx bit 8), and not when it
;is also FemDom (bit 16): there the aggressive woman is the one forcing.
Bool Function IsVictim(Bool flagged, Bool anyFlagged, Int ctx) Global
	if flagged
		return true
	endif
	if anyFlagged
		return false
	endif
	return Math.LogicalAnd(ctx, 8) == 8 && Math.LogicalAnd(ctx, 16) == 0
EndFunction

String[] Function Pick(String aName, String bFolder) Global
	String[] p = new String[2]
	p[0] = aName
	p[1] = bFolder
	return p
EndFunction

Bool Function Roll(Float chance) Global
	return Utility.RandomFloat(0.0, 1.0) < chance
EndFunction
