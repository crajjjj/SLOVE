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
	;"D" is a Variation-B pack that also uses tags - same dispatch, same folder
	;names (see SLOVE_Voice.DispatchVariation). Checked inline to keep this harness
	;free of a dependency on the voice script.
	String slotVar = AudioUtil.GetSlotVariation(slot)
	bool isVarB = isFemale && (slotVar == "B" || slotVar == "D")
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

;PlayFolderWithLipSync smoke test: shuffle-bag one file from the test folder
;(holds a wav AND a fuz, both with caption sidecars) at the player. PASS =
;audible, mouth moves, caption on screen - whichever file the bag picks.
;Run repeatedly to hit both files (no repeats until the bag empties).
Function FolderLine() Global
	int h = AudioUtil.PlayFolderWithLipSync("Sound\\fx\\SLOVE\\Test", Game.GetPlayer())
	if h <= 0
		MiscUtil.PrintConsole("SLOVE folder line: FAILED (Sound\\fx\\SLOVE\\Test empty or not deployed?)")
		return
	endif
	MiscUtil.PrintConsole("SLOVE folder line: handle=" + h + " picked=" + AudioUtil.GetHandlePath(h) + " caption='" + AudioUtil.GetHandleCaption(h) + "'")
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

;Emergency repair for a stuck/deformed face (mouth won't close, teeth through the
;lips, tongue through a closed chin): stops lipsync, clears SLO VE's mouth-ownership
;markers, strips all 10 bundled tongue armors, resets MFG (Mfg Fix NG) and reverts
;MFEE morphs. Targets the PLAYER plus the actor under the crosshair, if any - aim at
;an NPC before opening the console to fix them too. Safe to run any time; during a
;scene the next expression pass simply repaints the face.
Function FaceFix() Global
	Actor[] targets = new Actor[2]
	targets[0] = Game.GetPlayer()
	targets[1] = Game.GetCurrentCrosshairRef() as Actor
	int fixed = 0
	int i = 0
	while i < targets.length
		Actor a = targets[i]
		if a && (i == 0 || a != targets[0])
			fixed += 1
			AudioUtil.StopLipSync(a)
			StorageUtil.SetIntValue(a, "SLOVE_FaceOwnsMouth_Expr", 0)
			StorageUtil.SetIntValue(a, "SLOVE_FaceOwnsMouth_SLS", 0)
			StorageUtil.SetIntValue(a, "SLOVE_TongueEquipped", 0)
			int removed = 0
			int t = 0
			while t < 10
				;SLOVE_Tongue{t+1}Armor = 0x000813 + t (same ids as the Director's RemoveTongueItems)
				Form tongueItem = Game.GetFormFromFile(0x000813 + t, "SLOVE.esp")
				if tongueItem
					int cnt = a.GetItemCount(tongueItem)
					if cnt > 0
						a.RemoveItem(tongueItem, cnt, abSilent = true)
						removed += cnt
					endif
				endif
				t += 1
			endwhile
			;both no-op with a log line when the backing mod is absent
			MfgConsoleFuncExt.resetmfg(a, 0.1)
			MuFacialExpressionExtended.RevertExpression(a)
			MiscUtil.PrintConsole("SLOVE facefix: " + a.GetDisplayName() + " - face reset, " + removed + " tongue item(s) removed")
			SLOVE_Log.WriteLog("facefix: " + a.GetDisplayName() + " - face reset, " + removed + " tongue item(s) removed", 0)
		endif
		i += 1
	endwhile
	if fixed < 2
		MiscUtil.PrintConsole("SLOVE facefix: to fix an NPC, aim the crosshair at them before opening the console and rerun.")
	endif
EndFunction

;Print config + resolution basics for quick sanity checks.
Function DumpState() Global
	MiscUtil.PrintConsole("SLOVE config available=" + SLOVE_Config.Available())
	MiscUtil.PrintConsole("  enablevoice=" + SLOVE_Config.GetInt("director.enablevoice", -1) + " enableexpressions=" + SLOVE_Config.GetInt("director.enableexpressions", -1))
	MiscUtil.PrintConsole("  pcvolume=" + SLOVE_Config.GetInt("voice.pcvolume", -1) + " voiceallactors=" + SLOVE_Config.GetInt("voice.voiceallactors", -1))
	MiscUtil.PrintConsole("  player slot=" + AudioUtil.GetSlotForActor(Game.GetPlayer()))
	MiscUtil.PrintConsole("  esp loaded=" + SLOVE_Utils.isDependencyReady("SLOVE.esp"))
	MiscUtil.PrintConsole("  contact detection (SexLab P+ 2.19+)=" + SLOVE_Utils.HasInteractionAPI() + " - false = stage tags only (no physics labels, thrust-paced SFX, insertion/kiss/oral one-shots or live oral detection)")
EndFunction

;Send one of the SLOVE_Mute_* events the way another mod would, to try the external
;mute API without that mod: the actor under the crosshair (aim before opening the
;console), else the player. scope "scene" = SLOVE_Mute_Scene, anything else =
;SLOVE_Mute_Stage; aiFace != 0 also hands over the face. The Director writes one
;"Mute :" line per event to SLOVE.0.log.
Function Mute(String scope, Int aiFace) Global
	Actor a = Game.GetCurrentCrosshairRef() as Actor
	if a == None
		a = Game.GetPlayer()
	endif
	string ev = "SLOVE_Mute_Stage"
	if scope == "scene"
		ev = "SLOVE_Mute_Scene"
	endif
	float face = 0.0
	if aiFace != 0
		face = 1.0
	endif
	a.SendModEvent(ev, "slovetest", face)
	MiscUtil.PrintConsole("SLO VE: sent " + ev + " for " + a.GetDisplayName() + " (face=" + (aiFace != 0) + ") - 'slovetest mutes' shows the result")
EndFunction

;The matching SLOVE_Unmute_Stage / SLOVE_Unmute_Scene, same target rule as Mute.
Function Unmute(String scope) Global
	Actor a = Game.GetCurrentCrosshairRef() as Actor
	if a == None
		a = Game.GetPlayer()
	endif
	string ev = "SLOVE_Unmute_Stage"
	if scope == "scene"
		ev = "SLOVE_Unmute_Scene"
	endif
	a.SendModEvent(ev, "slovetest")
	MiscUtil.PrintConsole("SLO VE: sent " + ev + " for " + a.GetDisplayName() + " - 'slovetest mutes' shows the result")
EndFunction

;Set the stored willpower of the actor under the crosshair, else the player, to
;try a willpower display (the SL Widgets bar) or the broken voice without
;playing scenes for it. This WRITES the real state: 1-100 sets the value and
;lifts a break, 0 breaks the actor for the configured number of hours. The
;time stamp is set to now, so recovery counts from this moment. A break set or
;lifted here sends SLOVE_Break / SLOVE_Recover like a real one, which makes
;this the way to try a listener for those events.
Function Willpower(Int aiValue) Global
	Actor a = Game.GetCurrentCrosshairRef() as Actor
	if a == None
		a = Game.GetPlayer()
	endif
	int v = aiValue
	if v < 0
		v = 0
	elseif v > 100
		v = 100
	endif
	bool isPC = a == Game.GetPlayer()
	int broken = 0
	int rate = SLOVE_Config.GetInt("resistance.npcrecoverperhour", 5)
	if isPC
		rate = SLOVE_Config.GetInt("resistance.pcrecoverperhour", 10)
	endif
	if v == 0
		broken = SLOVE_Config.GetInt("resistance.npcbrokenpoints", 40)
		if isPC
			broken = SLOVE_Config.GetInt("resistance.pcbrokenpoints", 60)
		endif
	endif
	StorageUtil.SetIntValue(a, "SLOVE_RecoverPerHour", rate)
	;the stamp before the break: the Director counts the break's hours from it
	StorageUtil.SetFloatValue(a, "SLOVE_LastSexTime", Utility.GetCurrentGameTime())
	string sent = ""
	if v == 0
		StorageUtil.SetIntValue(a, "SLOVE_Resistance", 0)
		if SLOVE_Utils.MarkBroken(a, broken)
			sent = ", sent SLOVE_Break"
		endif
	else
		if SLOVE_Utils.MarkRecovered(a)
			sent = ", sent SLOVE_Recover"
		endif
		StorageUtil.SetIntValue(a, "SLOVE_Resistance", v)
	endif
	MiscUtil.PrintConsole("SLO VE: " + a.GetDisplayName() + " willpower=" + v + " brokenhours=" + broken + " recovers " + rate + "% per game hour from now" + sent + " (" + SLOVE_Utils.BrokenCount() + " actor(s) broken)")
EndFunction

;Try the armor swap (director.enablearmorswap) on the player without a scene.
;Reads ArmorSwapping.json afresh from disk, so an edit to it shows without a
;restart; prints what each listed slot holds and what the file gives for it,
;then swaps. Run it again to put everything back. Works with the switch off:
;the switch only decides whether scenes do this by themselves.
Function ArmorSwap() Global
	Actor pc = Game.GetPlayer()
	if SLOVE_Utils.ArmorSwapCount(pc) > 0
		int back = SLOVE_Utils.RestoreArmor(pc)
		MiscUtil.PrintConsole("SLOVE armorswap: " + back + " armor(s) put back on. Run it again to swap.")
		return
	endif
	string file = SLOVE_Utils.ArmorSwapFile()
	if !JsonUtil.JsonExists(file)
		MiscUtil.PrintConsole("SLOVE armorswap: SKSE\\Plugins\\StorageUtilData\\" + file + " is missing - nothing can be swapped.")
		return
	endif
	;drop the cached copy (nothing to save, the scripts only read it) and load the file as it is on disk now
	JsonUtil.Unload(file, false)
	JsonUtil.Load(file)
	string errors = JsonUtil.GetErrors(file)
	if errors != ""
		MiscUtil.PrintConsole("SLOVE armorswap: " + file + " does not parse - " + errors)
		return
	endif
	string[] slots = SLOVE_Utils.ArmorSwapSlots()
	if slots.Length == 0
		MiscUtil.PrintConsole("SLOVE armorswap: 'armorslots' in " + file + " is empty - no slot is looked at.")
		return
	endif
	int i = 0
	while i < slots.Length
		int slot = slots[i] as int
		if slot < 30 || slot > 61
			MiscUtil.PrintConsole("  '" + slots[i] + "' is not a biped slot (30 to 61) - skipped")
		else
			Armor worn = pc.GetWornForm(Armor.GetMaskForSlot(slot)) as Armor
			if worn == None
				MiscUtil.PrintConsole("  slot " + slot + ": nothing worn")
			else
				Armor standIn = SLOVE_Utils.ArmorSwapFor(worn)
				if standIn
					MiscUtil.PrintConsole("  slot " + slot + ": '" + worn.GetName() + "' -> '" + standIn.GetName() + "'")
				else
					MiscUtil.PrintConsole("  slot " + slot + ": '" + worn.GetName() + "' - no entry that resolves (not listed under that name, or the plugin its line names is not installed)")
				endif
			endif
		endif
		i += 1
	endwhile
	int swapped = SLOVE_Utils.SwapArmor(pc)
	MiscUtil.PrintConsole("SLOVE armorswap: " + swapped + " armor(s) swapped. Run it again to put them back. Scenes swap by themselves only with director.enablearmorswap = 1 (it is " + SLOVE_Config.GetInt("director.enablearmorswap", 0) + ").")
EndFunction

;List every actor that has a mute written on it (SLOVE_Mute_* events), with what
;is written and whether it is in force - a mute that has run out stays written
;until it is lifted or the game is loaded.
Function Mutes() Global
	int n = SLOVE_Utils.MutedCount()
	MiscUtil.PrintConsole("SLO VE: " + n + " actor(s) with a mute written on them")
	int i = 0
	while i < n
		string line = SLOVE_Utils.DescribeMute(i)
		if line != ""
			MiscUtil.PrintConsole("  " + line)
		endif
		i += 1
	endwhile
EndFunction
