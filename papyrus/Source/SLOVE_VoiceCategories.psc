Scriptname SLOVE_VoiceCategories Hidden
{Static voice-category tables. Category names are AudioUtil folder names;
 the DLL resolves slot + folder at play time, so no Sound forms or voice
 aliases exist anywhere in SLO VE.}

;Male-only scenes: the female voice engine keeps running, but its categories
;must resolve against a MALE pack. This maps each female category to the
;closest male one (ported from IVDTVoiceFemaleScript.SetUpVoiceFromMaleVoice).
;Unmapped categories return unchanged - the AudioUtil [male_only_remap]
;toml layer is the runtime safety net behind this.
String Function MaleOnlyRemap(String femaleCategory) Global
	if femaleCategory == "LoveyDovey"
		return "LoveyDovey"
	elseif femaleCategory == "SensitivePleasure"
		return "StrugglingSubtle"
	elseif femaleCategory == "InsertionGeneric"
		return "StrugglingSubtle"
	elseif femaleCategory == "InsertionAnalExcited"
		return "StrugglingSubtle"
	elseif femaleCategory == "InsertionAnalSlow"
		return "StrugglingSubtle"
	elseif femaleCategory == "PenetrativeCommentsIntense"
		return "Aggressive"
	elseif femaleCategory == "PenetrativeCommentsSoft"
		return "TeaseAggressivePartner"
		;NearOrgasmNoises is a non-verbal MOAN - deliberately NOT remapped to a spoken
		;male line. Left unremapped it resolves against the male slot and falls through
		;its `fallback = "M0"` to the SexLab vMaleMoan stock, so a male PC moans instead
		;of repeating "Struggling Subtle" (see AudioUtil SLOVE_voices.toml [male_only_remap]).
	elseif femaleCategory == "NearOrgasmExclamations"
		return "StrugglingOvert"
	elseif femaleCategory == "CumTogetherTease"
		return "AboutToCum"
	elseif femaleCategory == "MyTurnToCum"
		return "StrugglingOvert"
	elseif femaleCategory == "Orgasm"
		return "Orgasm"
	elseif femaleCategory == "AfterOrgasmRemarks"
		return "PostNutRemark"
	elseif femaleCategory == "AfterOrgasmArouse"
		return "PostNutRemark"
	elseif femaleCategory == "MaleHalfwayIntense"
		return "Aggressive"
	elseif femaleCategory == "TeaseMaleCloseToOrgasmIntense"
		return "Aggressive"
	elseif femaleCategory == "TeaseMaleCloseToOrgasmSoft"
		return "Aggressive"
	elseif femaleCategory == "MaleOrgasmReactionIntense"
		return "AfterFemaleOrgasm"
	elseif femaleCategory == "MaleOrgasmReactionSoft"
		return "AfterFemaleOrgasm"
	elseif femaleCategory == "MaleOrgasmReactionLover"
		return "AfterFemaleOrgasm"
	elseif femaleCategory == "CameInAss"
		return "Aroused"
	elseif femaleCategory == "CameInMouth"
		return "Aroused"
	elseif femaleCategory == "CameInPussy"
		return "Aroused"
	elseif femaleCategory == "WantMore"
		return "Aggressive"
	elseif femaleCategory == "Amused"
		return "JokeAroused"
	elseif femaleCategory == "InAwe"
		return "Aroused"
	elseif femaleCategory == "TeaseAggressivePartner"
		return "TeaseAggressivePartner"
	endif
	return femaleCategory
EndFunction

;All categories the female engine can request - for pack audits
;(SLOVE_Test.AuditVoicePack loops these against AudioUtil.CategoryExists).
String[] Function AllFemaleCategories() Global
	String[] cats = new String[71]
	cats[0] = "GreetLover"
	cats[1] = "GreetFamiliar"
	cats[2] = "GreetLoadedFamiliar"
	cats[3] = "MissMaleLover"
	cats[4] = "WantToBeLover"
	cats[5] = "RomanceMaleThane"
	cats[6] = "LoveyDovey"
	cats[7] = "AppreciatePartner"
	cats[8] = "Satisfied"
	cats[9] = "SensitivePleasure"
	cats[10] = "ForeplayIntense"
	cats[11] = "ForeplaySoft"
	cats[12] = "ReadyToGetGoing"
	cats[13] = "ReadyToResume"
	cats[14] = "BlowjobRemarks"
	cats[15] = "BlowjobActionIntense"
	cats[16] = "BlowjobActionSoft"
	cats[17] = "AssToMouth"
	cats[18] = "InsertionGeneric"
	cats[19] = "InsertionAnalSlow"
	cats[20] = "InsertionAnalExcited"
	cats[21] = "PenetrativeGrunts"
	cats[22] = "PenetrativeCommentsIntense"
	cats[23] = "PenetrativeCommentsSoft"
	cats[24] = "OnTheAttack"
	cats[25] = "AssFlattering"
	cats[26] = "IntenseAnal"
	cats[27] = "BeforeGape"
	cats[28] = "AfterGape"
	cats[29] = "AskForPacingBreak"
	cats[30] = "NearOrgasmNoises"
	cats[31] = "NearOrgasmExclamations"
	cats[32] = "CumTogetherTease"
	cats[33] = "MyTurnToCum"
	cats[34] = "Orgasm"
	cats[35] = "AfterOrgasmArouse"
	cats[36] = "AfterOrgasmExclamations"
	cats[37] = "AfterOrgasmRemarks"
	cats[38] = "MadeMeCumSoMuch"
	cats[39] = "MaleHalfwayIntense"
	cats[40] = "MaleCloseAlready"
	cats[41] = "MaleCloseNotice"
	cats[42] = "TeaseMaleCloseToOrgasmIntense"
	cats[43] = "TeaseMaleCloseToOrgasmSoft"
	cats[44] = "AskForVaginalCum"
	cats[45] = "AskForAnalCum"
	cats[46] = "AskForOralCum"
	cats[47] = "PullOut"
	cats[48] = "MaleOrgasmOral"
	cats[49] = "MaleOrgasmNonOral"
	cats[50] = "SurprisedByMaleOrgasm"
	cats[51] = "MaleOrgasmReactionIntense"
	cats[52] = "MaleOrgasmReactionSoft"
	cats[53] = "MaleOrgasmReactionLover"
	cats[54] = "CameInAss"
	cats[55] = "CameInMouth"
	cats[56] = "CameInPussy"
	cats[57] = "WantMore"
	cats[58] = "RefractoryPeriod"
	cats[59] = "NoticeMaleWantsMore"
	cats[60] = "BreathyIntense"
	cats[61] = "BreathySoft"
	cats[62] = "Amused"
	cats[63] = "Unamused"
	cats[64] = "UnamusedEnd"
	cats[65] = "InAwe"
	cats[66] = "Oh"
	cats[67] = "TeaseAggressivePartner"
	cats[68] = "TeaseAnal"
	cats[69] = "AskForAnal"
	cats[70] = "MCMSampleSounds"
	return cats
EndFunction

;All categories the male engine can request - for pack audits
;(SLOVE_Test.AuditVoicePack loops these against AudioUtil.CategoryExists).
String[] Function AllMaleCategories() Global
	String[] cats = new String[15]
	cats[0] = "Aroused"
	cats[1] = "StrugglingEarly"
	cats[2] = "StrugglingOvert"
	cats[3] = "StrugglingSubtle"
	cats[4] = "AboutToCum"
	cats[5] = "Orgasm"
	cats[6] = "PostNutRemark"
	cats[7] = "JokeAroused"
	cats[8] = "JokeAfterOrgasm"
	cats[9] = "TeaseFemaleOrgasm"
	cats[10] = "AfterFemaleOrgasm"
	cats[11] = "LoveyDovey"
	cats[12] = "Aggressive"
	cats[13] = "TeaseAggressivePartner"
	cats[14] = "MCMSampleSounds"
	return cats
EndFunction

;Variation-B scene-label folders the female engine can request - for pack audits
;of a Variation-B pack (SLOVE_Test.AuditVoicePack runs this extra pass when the
;slot declares variation = "B"). These are the PARTITIONED labels - victim,
;broken, femdom, over-the-top, forced, and breathing filler - passed as debugtext
;and swapped in by the per-line B-remap in SLOVE_Voice, NOT the collapsed A names
;in AllFemaleCategories, which a clean B pack deliberately drops to its fallback.
;Source of truth: the distinct debugtext labels emitted by SLOVE_Voice that are
;real, shippable B folders (Aika's layout, per the A-to-B conversion plan).
;Internal debug-only labels that always fall back (DefaultMaleOrgasm, FemaleOrgasm,
;PullOutGape) and the gag pool (routed via gag_slot, not this slot) are excluded.
;Names match case- and space-insensitively in AudioUtil, so exact casing is cosmetic.
String[] Function AllFemaleVariationBCategories() Global
	String[] cats = new String[56]
	cats[0] = "After Orgasm Comments"
	cats[1] = "After Orgasm Comments Intense"
	cats[2] = "Blowjob Action"
	cats[3] = "Blowjob Comments"
	cats[4] = "Blowjob Comments Intense"
	cats[5] = "Blowjob Forced"
	cats[6] = "Blowjob Forced Comments"
	cats[7] = "Breathing"
	cats[8] = "Breathing Intense"
	cats[9] = "Broken Begging"
	cats[10] = "Ending Broken"
	cats[11] = "Ending Orgasmed Inside Ass"
	cats[12] = "Ending Orgasmed Inside Mouth"
	cats[13] = "Ending Orgasmed Inside Pussy"
	cats[14] = "Ending Victim Comments"
	cats[15] = "Foreplay BoobJob Comments"
	cats[16] = "Foreplay Femdom Comments"
	cats[17] = "Foreplay FootJob Comments"
	cats[18] = "Foreplay Handjob Comments"
	cats[19] = "Foreplay Tease Orgasm"
	cats[20] = "Insertion Over The Top"
	cats[21] = "KneeJerk"
	cats[22] = "KneeJerk Intense"
	cats[23] = "Kissing"
	cats[24] = "Male Orgasm Soon Ask For Anal Cum"
	cats[25] = "Male Orgasm Soon Ask For Oral Cum"
	cats[26] = "Male Orgasm Soon Ask For Vaginal Cum"
	cats[27] = "Male Orgasm Soon Ask For Vaginal Cum Intense"
	cats[28] = "Male Orgasm Soon Femdom"
	cats[29] = "Male Orgasmed Inside"
	cats[30] = "Male Orgasmed Inside Femdom"
	cats[31] = "Male Orgasmed Inside Intense"
	cats[32] = "Male Orgasmed Inside Mouth"
	cats[33] = "Male Orgasmed Inside Victim"
	cats[34] = "Orgasm Soon Comments"
	cats[35] = "Orgasm Soon Comments Intense"
	cats[36] = "Panting"
	cats[37] = "Panting Heavy"
	cats[38] = "Penetrated Anal Comments Intense"
	cats[39] = "Penetrated Broken Comments"
	cats[40] = "Penetrated Broken Comments Intense"
	cats[41] = "Penetrated Comments"
	cats[42] = "Penetrated Comments Femdom"
	cats[43] = "Penetrated Comments Femdom Intense"
	cats[44] = "Penetrated Comments Intense"
	cats[45] = "Penetrated Comments Over The Top"
	cats[46] = "Penetrated Comments Victim"
	cats[47] = "Penetrated Double Comments"
	cats[48] = "Penetrated Grunt"
	cats[49] = "Penetrated Grunt Intense"
	cats[50] = "Penetrated Grunt Over The Top"
	cats[51] = "Penetrated Grunt Victim"
	cats[52] = "Penetrated Grunt Victim Intense"
	cats[53] = "Penetrated Tell Male to Pull Out"
	cats[54] = "Stimulated Comments"
	cats[55] = "Stimulated Victim Comments"
	return cats
EndFunction
