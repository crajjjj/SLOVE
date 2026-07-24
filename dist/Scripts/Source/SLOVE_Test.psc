Scriptname SLOVE_Test Hidden
{Console-callable diagnostics. Examples:
   SLOVE_Test AuditVoicePack M1
   SLOVE_Test SampleCategory M4 Aroused
   SLOVE_Test DumpState}

;Check every category the engines can request against an installed slot.
;Prints missing ones to the console; ends with a found/total summary.
Function AuditVoicePack(String slot) Global
	String[] cats
	if StringUtil.Substring(slot, 0, 1) == "F" || StringUtil.Substring(slot, 0, 1) == "f"
		cats = SLOVE_VoiceCategories.AllFemaleCategories()
	else
		cats = SLOVE_VoiceCategories.AllMaleCategories()
	endif
	int found = 0
	int i = 0
	while i < cats.length
		if AudioUtil.CategoryExists(slot, cats[i])
			found += 1
		else
			MiscUtil.PrintConsole("SLOVE audit " + slot + ": MISSING " + cats[i])
		endif
		i += 1
	endwhile
	MiscUtil.PrintConsole("SLOVE audit " + slot + ": " + found + "/" + cats.length + " categories resolve")
EndFunction

;Play one clip from an explicit slot/category at the player.
Function SampleCategory(String slot, String category) Global
	int h = AudioUtil.PlayVoiceFromSlot(slot, category, Game.GetPlayer())
	MiscUtil.PrintConsole("SLOVE sample " + slot + "/" + category + " handle=" + h)
EndFunction

;Print config + resolution basics for quick sanity checks.
Function DumpState() Global
	MiscUtil.PrintConsole("SLOVE config available=" + SLOVE_Config.Available())
	MiscUtil.PrintConsole("  enablevoice=" + SLOVE_Config.GetInt("director.enablevoice", -1) + " enableexpressions=" + SLOVE_Config.GetInt("director.enableexpressions", -1))
	MiscUtil.PrintConsole("  pcvolume=" + SLOVE_Config.GetInt("voice.pcvolume", -1) + " voiceallactors=" + SLOVE_Config.GetInt("voice.voiceallactors", -1))
	MiscUtil.PrintConsole("  player slot=" + AudioUtil.GetSlotForActor(Game.GetPlayer()))
	MiscUtil.PrintConsole("  esp loaded=" + (Game.GetModByName("SLOVE.esp") != 255))
EndFunction
