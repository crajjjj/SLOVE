Scriptname SLOVE_Test Hidden
{Console-callable diagnostics. Examples:
   SLOVE_Test AuditVoicePack M1
   SLOVE_Test SampleCategory M4 Aroused
   SLOVE_Test DumpState}

;Check every category the engines can request against an installed slot.
;Prints missing ones to the console; ends with a found/total summary.
;With AudioUtil API v3+ each resolving category is also attributed to the slot
;that actually supplies it, so a pack that "resolves" everything purely via its
;fallback slot (stock moans) is visible at a glance instead of looking healthy.
;A Variation-B female slot (GetSlotVariation == "B") gets a SECOND pass over the
;partitioned B scene-label folders it actually ships - otherwise only the collapsed
;A names would be checked, and a clean B pack deliberately drops those to fallback,
;so an all-backfill A result would hide a perfectly healthy B pack.
Function AuditVoicePack(String slot) Global
	;Guard the classic gotcha: the audit is keyed on the slot id's sex prefix, so a
	;voice-PACK folder name (e.g. "Aika") silently fell through to the male branch and
	;reported a meaningless "0/15" - the #1 support confusion. Reject anything that
	;isn't a recognised voice slot id and point the user at the right argument.
	String first = StringUtil.Substring(slot, 0, 1)
	bool isFemale = first == "F" || first == "f"
	bool isMaleOrCreature = first == "M" || first == "m" || first == "C" || first == "c"
	if !isFemale && !isMaleOrCreature
		MiscUtil.PrintConsole("SLOVE audit: '" + slot + "' is not a voice slot id. Pass the SLOT ID (e.g. F1, M1, C1) - NOT the voice-pack folder name. See docs\\packs\\slots.md for the slot scheme.")
		SLOVE_Log.WriteLog("SLOVE audit: '" + slot + "' is not a voice slot id (pass F1/M1/C1, not the pack name).", 1)
		return
	endif
	;Variation B is gated on the scene's lead female, so only female slots carry a
	;B taxonomy. The pass runs only when the slot actually declares variation = "B".
	bool isVarB = isFemale && AudioUtil.GetSlotVariation(slot) == "B"
	if isFemale
		;For a B pack the A pass is expected to be mostly backfill/MISSING - the
		;collapsed A names a clean B pack deliberately drops to fallback - so print
		;only its one-line summary and keep the per-category detail for the B pass.
		;An A pack (detail = true) keeps the full legacy line-by-line output.
		AuditCategoryList(slot, SLOVE_VoiceCategories.AllFemaleCategories(), "", !isVarB)
	else
		AuditCategoryList(slot, SLOVE_VoiceCategories.AllMaleCategories(), "", true)
	endif
	if isVarB
		AuditCategoryList(slot, SLOVE_VoiceCategories.AllFemaleVariationBCategories(), "Variation-B", true)
	endif
EndFunction

;Audit one category list against a slot (shared by the A and B passes above).
;label "" keeps the legacy line format byte-for-byte; a non-empty label (e.g.
;"Variation-B") tags every line so the two passes are told apart in the console.
;detail = false prints only the final summary line (no per-category MISSING /
;backfill spam) - used for a B pack's expected-noisy A pass; the summary still counts.
Function AuditCategoryList(String slot, String[] cats, String label, bool detail) Global
	String tag = ""
	if label != ""
		tag = " " + label
	endif
	bool haveSource = AudioUtil.GetAPIVersion() >= 3
	int found = 0
	int inPack = 0
	String src = ""
	int i = 0
	while i < cats.length
		if AudioUtil.CategoryExists(slot, cats[i])
			found += 1
			if haveSource
				src = AudioUtil.GetResolvingSlot(slot, cats[i])
				;slot ids are case-insensitive; compare via Find (case-insensitive) not ==
				if StringUtil.GetLength(src) == StringUtil.GetLength(slot) && StringUtil.Find(src, slot) == 0
					inPack += 1
				elseif detail
					MiscUtil.PrintConsole("SLOVE audit " + slot + tag + ": " + cats[i] + " <- backfill from " + src)
				endif
			endif
		elseif detail
			MiscUtil.PrintConsole("SLOVE audit " + slot + tag + ": MISSING " + cats[i])
		endif
		i += 1
	endwhile
	if haveSource
		MiscUtil.PrintConsole("SLOVE audit " + slot + tag + ": " + found + "/" + cats.length + " categories resolve (" + inPack + " in-pack, " + (found - inPack) + " backfilled)")
	else
		MiscUtil.PrintConsole("SLOVE audit " + slot + tag + ": " + found + "/" + cats.length + " categories resolve")
	endif
EndFunction

;Play one clip from an explicit slot/category at the player.
Function SampleCategory(String slot, String category) Global
	int h = AudioUtil.PlayVoiceFromSlot(slot, category, Game.GetPlayer())
	MiscUtil.PrintConsole("SLOVE sample " + slot + "/" + category + " handle=" + h)
EndFunction

;Dump the player's CURRENT SexLab scene - tags, per-actor labels, resolved AudioUtil
;slot, likely voice branch and SFX tag. Delegates to the Director (alias 0 of the
;SLOVE main quest), which owns the live scene state. Re-runnable any time during a scene.
Function DumpAnim() Global
	Quest mq = Game.GetFormFromFile(0x804, "SLOVE.esp") as Quest
	SLOVE_Director dir = none
	if mq
		dir = mq.GetAlias(0) as SLOVE_Director
	endif
	if dir == none
		MiscUtil.PrintConsole("SLO VE: Director not found (SLOVE.esp not loaded?).")
		SLOVE_Log.WriteLog("SLO VE: Director not found (SLOVE.esp not loaded?).", 1)
		return
	endif
	dir.DumpCurrentAnim()
EndFunction

;Force a nipple squirt on the player to tune [milk] settings without playing out a
;scene. Delegates to the Director (alias 0), which owns the milk config + squirt path
;and reports why it was blocked. aiIntense != 0 = milk.levelintense, else levelnonintense.
Function Milk(Int aiIntense) Global
	Quest mq = Game.GetFormFromFile(0x804, "SLOVE.esp") as Quest
	SLOVE_Director dir = none
	if mq
		dir = mq.GetAlias(0) as SLOVE_Director
	endif
	if dir == none
		MiscUtil.PrintConsole("SLO VE: Director not found (SLOVE.esp not loaded?).")
		SLOVE_Log.WriteLog("SLO VE: Director not found (SLOVE.esp not loaded?).", 1)
		return
	endif
	dir.TestMilk(aiIntense != 0)
EndFunction

;Print config + resolution basics for quick sanity checks.
Function DumpState() Global
	MiscUtil.PrintConsole("SLOVE config available=" + SLOVE_Config.Available())
	MiscUtil.PrintConsole("  enablevoice=" + SLOVE_Config.GetInt("director.enablevoice", -1) + " enableexpressions=" + SLOVE_Config.GetInt("director.enableexpressions", -1))
	MiscUtil.PrintConsole("  pcvolume=" + SLOVE_Config.GetInt("voice.pcvolume", -1) + " voiceallactors=" + SLOVE_Config.GetInt("voice.voiceallactors", -1))
	MiscUtil.PrintConsole("  player slot=" + AudioUtil.GetSlotForActor(Game.GetPlayer()))
	MiscUtil.PrintConsole("  esp loaded=" + (Game.GetModByName("SLOVE.esp") != 255))
EndFunction
