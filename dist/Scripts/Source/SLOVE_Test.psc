Scriptname SLOVE_Test Hidden
{Console-callable diagnostics. Examples:
   SLOVE_Test AuditVoicePack M1
   SLOVE_Test SampleCategory M4 Aroused
   SLOVE_Test TestCaption F1 Moan 1
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

;One-command caption smoke test: play the dedicated test line
;Sound\fx\SLOVE\Test\01.wav (which ships a .toml caption sidecar next to it)
;at the player. PASS = its caption text prints below AND is on screen as a
;subtitle attributed to the player while the line plays.
Function CaptionLine() Global
	if AudioUtil.GetAPIVersion() < 5
		MiscUtil.PrintConsole("SLOVE caption line: AudioUtil API v5+ required for captions (installed: v" + AudioUtil.GetAPIVersion() + ")")
		return
	endif
	int h = AudioUtil.PlayFileWithLipSync("Sound\\fx\\SLOVE\\Test\\01.wav", Game.GetPlayer())
	if h <= 0
		MiscUtil.PrintConsole("SLOVE caption line: FAILED to play Sound\\fx\\SLOVE\\Test\\01.wav (file not deployed?)")
		return
	endif
	String text = AudioUtil.GetHandleCaption(h)
	MiscUtil.PrintConsole("SLOVE caption line: handle=" + h + " text='" + text + "'")
	if text == ""
		MiscUtil.PrintConsole("SLOVE caption line: no caption resolved - is 01.toml next to the wav, with an 'en' key? (captions enabled=" + AudioUtil.AreCaptionsEnabled() + ")")
	endif
EndFunction

;Fuz playback smoke test: play the dedicated test container
;Sound\fx\SLOVE\Test\0001_You_are_more_honest.fuz at the player via PlayFile.
;PASS = the line is audible with duration > 0 (proves the engine decoded the
;payload AudioUtil extracted to Sound\AudioUtilFuzCache\ - the first run logs
;the extraction in AudioUtil.log) and, if a .toml sidecar sits next to the
;fuz, its caption is on screen too.
Function FuzLine() Global
	int h = AudioUtil.PlayFileWithLipSync("Sound\\fx\\SLOVE\\Test\\0001_You_are_more_honest.fuz", Game.GetPlayer())
	if h <= 0
		MiscUtil.PrintConsole("SLOVE fuz line: FAILED to play Sound\\fx\\SLOVE\\Test\\0001_You_are_more_honest.fuz (not deployed, or extraction failed - see AudioUtil.log)")
		return
	endif
	MiscUtil.PrintConsole("SLOVE fuz line: handle=" + h + " duration=" + AudioUtil.GetHandleDuration(h) + "s caption='" + AudioUtil.GetHandleCaption(h) + "'")
	MiscUtil.PrintConsole("SLOVE fuz line: PASS = audible + duration > 0 (0.0 can be a still-preparing stream - rerun to check the cached copy)")
EndFunction

;Test the AudioUtil caption pipeline (API v5+): play one clip from slot/category
;at the player, then report which wav the shuffle bag picked (GetHandlePath) and
;the caption text its .toml sidecar resolves to (GetHandleCaption). When the
;text resolves, the same line should simultaneously be on screen as a game
;subtitle attributed to the player.
;aiWrite != 0: if the picked wav has NO sidecar, self-provision the test - write
;a throwaway sidecar next to it via TomlUtil (en = test text), ReloadConfig
;(clears AudioUtil's sidecar cache so the new file is seen), replay the SAME
;file and report the caption again. The test sidecar STAYS on disk afterwards -
;the console output names it; delete it (or edit it into a real caption) when done.
Function TestCaption(String slot, String category, Int aiWrite) Global
	int apiVersion = AudioUtil.GetAPIVersion()
	if apiVersion < 5
		MiscUtil.PrintConsole("SLOVE caption: AudioUtil API v5+ required for captions (installed: v" + apiVersion + ")")
		return
	endif
	MiscUtil.PrintConsole("SLOVE caption: captions enabled=" + AudioUtil.AreCaptionsEnabled())
	int h = AudioUtil.PlayVoiceFromSlot(slot, category, Game.GetPlayer())
	if h <= 0
		MiscUtil.PrintConsole("SLOVE caption: nothing played for " + slot + "/" + category + " (unknown slot/category?)")
		return
	endif
	String path = AudioUtil.GetHandlePath(h)
	String text = AudioUtil.GetHandleCaption(h)
	MiscUtil.PrintConsole("SLOVE caption: played " + path)
	if text != ""
		MiscUtil.PrintConsole("SLOVE caption: text='" + text + "' - the subtitle should be on screen now")
		return
	endif
	if aiWrite == 0
		MiscUtil.PrintConsole("SLOVE caption: this wav has no sidecar. Rerun with write=1 to create a test sidecar and replay.")
		return
	endif
	;wav -> sidecar path: same base name, .toml extension
	String sidecar = StringUtil.Substring(path, 0, StringUtil.GetLength(path) - 4) + ".toml"
	if !TomlUtil.SetString(sidecar, "en", "SLOVE caption test - it works!")
		MiscUtil.PrintConsole("SLOVE caption: FAILED to write " + sidecar + " (see AudioUtil.log)")
		return
	endif
	AudioUtil.StopHandle(h)
	AudioUtil.ReloadConfig()
	int h2 = AudioUtil.PlayFile(path, Game.GetPlayer())
	MiscUtil.PrintConsole("SLOVE caption: wrote " + sidecar + ", replayed handle=" + h2 + " text='" + AudioUtil.GetHandleCaption(h2) + "'")
	MiscUtil.PrintConsole("SLOVE caption: if the subtitle is on screen the pipeline works. Delete the test .toml (or fill in real text) when done.")
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
