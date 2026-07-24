Scriptname SLOVE_Hentairim_Tags Hidden
{Label engine (classic SexLab 1.63): classifies scene stages into Hentairim-
 convention label codes read from animation tags.

 REQUIRES SLATE plus a Hentairim-convention tag database (e.g. "Hentairim
 tags.json" under SKSE/Plugins/SLATE). SLATE applies per-stage/per-position
 codes such as 1ASVP / 5BENI as real SexLab animation tags - that is what
 gives the classic build the same label fidelity as the P+ registry path.
 Without a tag database every label falls back to LDI (lead-in).

 Ported from HentaiRimTags; the JSON tag
 store paths are kept for compatibility with existing tag databases.
 The name carries the annotation scheme on purpose: an OStim backend would
 ship its own *_Tags script for its scheme (see docs\framework-adapter.md).}

string Function GetLabel(sslBaseAnimation anim , int stage , String actorpos = "0" ) Global

string ActorPosition = ""
	
	if ActorPos == 0
		ActorPosition = "A"
	elseif ActorPos == 1
		ActorPosition = "B"
	elseif ActorPos == 2
		ActorPosition = "C"
	elseif ActorPos == 3
		ActorPosition = "D"
	elseif ActorPos == 4
		ActorPosition = "E"
	endif


	if HasASLTag(anim, stage+"LI") || HasASLTag(anim, stage+ActorPosition+"LDI")
		return "LI"
	elseif HasASLTag(anim, stage+"FA") || HasASLTag(anim, stage+ActorPosition+"FAP")
		return "FA"
	elseif HasASLTag(anim, stage+"SA") || HasASLTag(anim, stage+ActorPosition+"SAP")
		return "SA"
	elseif HasASLTag(anim, stage+"BA") 
		return "BA"
	elseif HasASLTag(anim, stage+"BV")
		return "BV"
	elseif HasASLTag(anim, stage+"FV") || HasASLTag(anim, stage+ActorPosition+"FVP")
		return "FV"	
	elseif HasASLTag(anim, stage+"SV") || HasASLTag(anim, stage+ActorPosition+"SVP")
		return "SV"	
	elseif HasASLTag(anim, stage+"DP") || HasASLTag(anim, stage+ActorPosition+"SDP") || HasASLTag(anim, stage+ActorPosition+"FDP")
		return "DP"
	elseif HasASLTag(anim, stage+"FB") || HasASLTag(anim, stage+ActorPosition+"FBJ")
		return "FB"
	elseif HasASLTag(anim, stage+"SB") || HasASLTag(anim, stage+ActorPosition+"SBJ")
		return "SB"	
	elseif HasASLTag(anim, stage+"EN") || HasASLTag(anim, stage+ActorPosition+"ENO") || HasASLTag(anim, stage+ActorPosition+"ENI")
		return "EN"
	elseif HasASLTag(anim, stage+"TP") || ((HasASLTag(anim, stage+ActorPosition+"SDP") || HasASLTag(anim, stage+ActorPosition+"FDP")) && (HasASLTag(anim, stage+ActorPosition+"SBJ") || HasASLTag(anim, stage+ActorPosition+"FBJ")))
		return "TP"
	elseif HasASLTag(anim, stage+"SR") || (HasASLTag(anim, stage+ActorPosition+"SVP") && HasASLTag(anim, stage+ActorPosition+"SBJ")) || (HasASLTag(anim, stage+ActorPosition+"FVP") && HasASLTag(anim, stage+ActorPosition+"FBJ")) || (HasASLTag(anim, stage+ActorPosition+"FAP") && HasASLTag(anim, stage+ActorPosition+"FBJ"))  || (HasASLTag(anim, stage+ActorPosition+"SAP") && HasASLTag(anim, stage+ActorPosition+"SBJ"))   
		return "SR"
	else
		return "LI" ;default lead in if no stimulating actions
	endif

endfunction


string Function StimulationLabel(sslBaseAnimation anim , int stage , Int ActorPos) Global

		string ActorPosition = ""
	
	if ActorPos == 0
		ActorPosition = "A"
	elseif ActorPos == 1
		ActorPosition = "B"
	elseif ActorPos == 2
		ActorPosition = "C"
	elseif ActorPos == 3
		ActorPosition = "D"
	elseif ActorPos == 4
		ActorPosition = "E"
	endif
	
	if HasASLTag(anim, stage+ActorPosition + "SST")
		return "SST"	
	elseif HasASLTag(anim, stage+ActorPosition + "FST")
		returN "FST"	
	elseif HasASLTag(anim, stage+ActorPosition + "BST")
		return "BST"	
	endif
	;no per-position tag; the ASL scheme has no stimulation code, so lead-in
	return "LDI"

endfunction

string Function PenetrationLabel(sslBaseAnimation anim , int stage , Int ActorPos) Global

	string ActorPosition = ""
	
	if ActorPos == 0
		ActorPosition = "A"
	elseif ActorPos == 1
		ActorPosition = "B"
	elseif ActorPos == 2
		ActorPosition = "C"
	elseif ActorPos == 3
		ActorPosition = "D"
	elseif ActorPos == 4
		ActorPosition = "E"
	endif
	
	if HasASLTag(anim, stage+ ActorPosition + "SVP")
		return "SVP"
	elseif HasASLTag(anim, stage+ActorPosition + "SAP")
		return "SAP"
	elseif HasASLTag(anim, stage+ActorPosition + "FVP")
		return "FVP"
	elseif HasASLTag(anim, stage+ActorPosition + "FAP")
		return "FAP"
	elseif HasASLTag(anim, stage+ActorPosition + "SCG")
		return "SCG"
	elseif HasASLTag(anim, stage+ActorPosition + "FCG")
		return "FCG"
	elseif HasASLTag(anim, stage+ActorPosition + "SAC")
		return "SAC"
	elseif HasASLTag(anim, stage+ActorPosition + "FAC")
		return "FAC"
	elseif HasASLTag(anim, stage+ActorPosition + "SDP")
		return "SDP"
	elseif HasASLTag(anim, stage+ActorPosition + "FDP")
		return "FDP"
	endif
	return ASLPenetrationFallback(anim, stage, ActorPos)
endfunction

string Function PenisActionLabel(sslBaseAnimation anim , int stage , Int ActorPos) Global
	
	string ActorPosition = ""
	
	if ActorPos == 0
		ActorPosition = "A"
	elseif ActorPos == 1
		ActorPosition = "B"
	elseif ActorPos == 2
		ActorPosition = "C"
	elseif ActorPos == 3
		ActorPosition = "D"
	elseif ActorPos == 4
		ActorPosition = "E"
	endif
	
	if HasASLTag(anim, stage+ActorPosition + "SDV")
		return "SDV"
	elseif HasASLTag(anim, stage+ActorPosition + "FDV")
		return "FDV"	
	elseif HasASLTag(anim, stage+ActorPosition + "SDA")
		retuRN "SDA"
	elseif HasASLTag(anim, stage+ActorPosition + "FDA")
		return "FDA"
	elseif HasASLTag(anim, stage+ActorPosition + "SHJ")
		reTURN "SHJ"
	elseif HasASLTag(anim, stage+ActorPosition + "FHJ")
		return "FHJ"
	elseif HasASLTag(anim, stage+ActorPosition + "STF")
		reTURN "STF"
	elseif HasASLTag(anim, stage+ActorPosition + "FTF")
		return "FTF"
	elseif HasASLTag(anim, stage+ActorPosition + "SMF")
		RETURN "SMF"
	elseif HasASLTag(anim, stage+ActorPosition + "FMF")
		return "FMF"
	elseif HasASLTag(anim, stage+ActorPosition + "SFJ")
		reTURN "SFJ"
	elseif HasASLTag(anim, stage+ActorPosition + "FFJ")
		returN "FFJ"
	endif
	return ASLPenisActionFallback(anim, stage, ActorPos)
endfunction


String Function OralLabel(sslBaseAnimation anim , int stage , Int ActorPos) Global
	
	string ActorPosition = ""
	
	if ActorPos == 0
		ActorPosition = "A"
	elseif ActorPos == 1
		ActorPosition = "B"
	elseif ActorPos == 2
		ActorPosition = "C"
	elseif ActorPos == 3
		ActorPosition = "D"
	elseif ActorPos == 4
		ActorPosition = "E"
	endif
	
	if HasASLTag(anim, stage+ ActorPosition + "KIS")
		return "KIS"
	elseif HasASLTag(anim, stage+ ActorPosition + "CUN")
		return "CUN"
	elseif HasASLTag(anim, stage+ ActorPosition + "FBJ")
		return "FBJ"
	elseif HasASLTag(anim, stage+ ActorPosition + "SBJ")
		returN "SBJ"
	endif
	return ASLOralFallback(anim, stage, ActorPos)

endfunction

String Function EndingLabel(sslBaseAnimation anim , int stage , Int ActorPos) Global
	;Labels that identify actions on partners
	
	string ActorPosition = ""
	
	if ActorPos == 0
		ActorPosition = "A"
	elseif ActorPos == 1
		ActorPosition = "B"
	elseif ActorPos == 2
		ActorPosition = "C"
	elseif ActorPos == 3
		ActorPosition = "D"
	elseif ActorPos == 4
		ActorPosition = "E"
	endif
	
	if HasASLTag(anim, stage+ ActorPosition + "ENO")
		return "ENO"
	elseif HasASLTag(anim, stage+ ActorPosition + "ENI")
		return "ENI"
	endif
	return ASLEndingFallback(anim, stage, ActorPos)

endfunction



string Function GetSFX(sslBaseAnimation anim , int stage) Global
	;SFX tag for the body-SFX engine (SLOVE_SFX): claps SC/MC/FC, slushes
	;SS/MS/FS/RS, NA = explicitly silent. Ported from HentaiRimTags.GetSFX.
	if HasASLTag(anim, stage+"SC")
		return "SC"
	elseif HasASLTag(anim, stage+"MC")
		return "MC"
	elseif HasASLTag(anim, stage+"FC")
		return "FC"
	elseif HasASLTag(anim, stage+"SS")
		return "SS"
	elseif HasASLTag(anim, stage+"MS")
		return "MS"
	elseif HasASLTag(anim, stage+"FS")
		return "FS"
	elseif HasASLTag(anim, stage+"RS")
		return "RS"
	elseif HasASLTag(anim, stage+"NA")
		return "NA"
	endif

endfunction

bool Function HasASLTag(sslBaseAnimation anim, string tag) Global
	;classic: the SLATE tag database applies the Hentairim-convention
	;<stage><POS><LABEL> codes (e.g. "1ASVP") as ordinary SexLab animation
	;tags, so this is a direct equivalent of P+ SexLabRegistry.IsSceneTag.
	return anim != none && anim.HasTag(tag)
EndFunction


string[] Function GetHentairimLabels(string anim) Global
string Path = "HentairimTags/HentairimTags.json"
return papyrusutil.stringsplit(JsonUtil.GetStringValue(Path,anim,""),",")

endfunction



Function AddHentairimLabels(string anim , string Label) Global
string Path = "HentairimTags/HentairimTags.json"
String CurrentLabelstring = JsonUtil.GetStringValue(Path,anim,"")
	if stringutil.Find(CurrentLabelstring , Label) <= -1
		jsonutil.SetStringValue(Path,anim,CurrentLabelstring+","+Label)
	endif
endfunction


String[] Function GetStimulationlabelarr(sslBaseAnimation anim , int stage , actor[] actorlist) Global
	int z
	string[] result
	while z < actorList.length
		result = papyrusutil.pushstring(result , StimulationLabel(anim , stage , z))
		z += 1
	endwhile
	return result
endfunction

String[] Function GetPenisActionlabelarr(sslBaseAnimation anim , int stage , actor[] actorlist) Global
	int z
	string[] result
	while z < actorList.length
		result = papyrusutil.pushstring(result , PenisActionLabel(anim , stage , z))
		z += 1
	endwhile
	return result
endfunction

String[] Function GetOrallabelarr(sslBaseAnimation anim , int stage , actor[] actorlist) Global
	int z
	string[] result
	while z < actorList.length
		result = papyrusutil.pushstring(result , OralLabel(anim , stage , z))
		z += 1
	endwhile
	return result
endfunction

String[] Function GetPenetrationLabelarr(sslBaseAnimation anim , int stage , actor[] actorlist) Global
	int z
	string[] result
	while z < actorList.length
		result = papyrusutil.pushstring(result , PenetrationLabel(anim , stage , z))
		z += 1
	endwhile
	return result
endfunction

String[] Function GetEndingLabelarr(sslBaseAnimation anim , int stage , actor[] actorlist) Global
	int z
	string[] result
	while z < actorList.length
		result = papyrusutil.pushstring(result , EndingLabel(anim , stage , z))
		z += 1
	endwhile
	return result
endfunction

;================= ASL (SLAnimStageLabels) fallback layer =================
;The Hentairim tag database annotates <stage><POS><LABEL> (1ASVP, 1BSDV, 5AENO).
;The older/broader ASL database from SLAnimStageLabels annotates only
;<stage><CODE> (3SV, 1LI, 6EN) - scene-wide, with no position letter. When an
;animation has ASL data but no per-position Hentairim data, these helpers derive
;a per-position label from the scene-wide code using the same convention the
;Hentairim database itself follows: position A (0) is the RECEIVER, positions
;B and later (1+) are the GIVERS.
;Returns "" when the animation carries no ASL code for this stage either.

string Function ASLStageCode(sslBaseAnimation anim, int stage) Global
	if HasASLTag(anim, stage+"LI")
		return "LI"
	elseif HasASLTag(anim, stage+"FA")
		return "FA"
	elseif HasASLTag(anim, stage+"SA")
		return "SA"
	elseif HasASLTag(anim, stage+"FV")
		return "FV"
	elseif HasASLTag(anim, stage+"SV")
		return "SV"
	elseif HasASLTag(anim, stage+"DP")
		return "DP"
	elseif HasASLTag(anim, stage+"TP")
		return "TP"
	elseif HasASLTag(anim, stage+"SR")
		return "SR"
	elseif HasASLTag(anim, stage+"FB")
		return "FB"
	elseif HasASLTag(anim, stage+"SB")
		return "SB"
	elseif HasASLTag(anim, stage+"EN")
		return "EN"
	endif
	return ""
EndFunction

;receiver view - only position A is penetrated under the ASL convention
string Function ASLPenetrationFallback(sslBaseAnimation anim, int stage, int ActorPos) Global
	if ActorPos != 0
		return "LDI"
	endif
	string c = ASLStageCode(anim, stage)
	if c == "SV" || c == "SR"
		return "SVP"
	elseif c == "FV"
		return "FVP"
	elseif c == "SA"
		return "SAP"
	elseif c == "FA"
		return "FAP"
	elseif c == "DP" || c == "TP"
		return "SDP"
	endif
	return "LDI"
EndFunction

;giver view - positions B+ deliver under the ASL convention
string Function ASLPenisActionFallback(sslBaseAnimation anim, int stage, int ActorPos) Global
	if ActorPos == 0
		return "LDI"
	endif
	string c = ASLStageCode(anim, stage)
	if c == "SV" || c == "DP" || c == "TP" || c == "SR"
		return "SDV"
	elseif c == "FV"
		return "FDV"
	elseif c == "SA"
		return "SDA"
	elseif c == "FA"
		return "FDA"
	elseif c == "SB"
		return "SMF"
	elseif c == "FB"
		return "FMF"
	endif
	return "LDI"
EndFunction

;mouth view - position A performs the oral action (incl. the spitroast case)
string Function ASLOralFallback(sslBaseAnimation anim, int stage, int ActorPos) Global
	if ActorPos != 0
		return "LDI"
	endif
	string c = ASLStageCode(anim, stage)
	if c == "SB" || c == "SR"
		return "SBJ"
	elseif c == "FB"
		return "FBJ"
	endif
	return "LDI"
EndFunction

;ASL has a single scene-wide EN with no inside/outside distinction and no
;position letter, so every position reads as ending; ENI is the common case.
string Function ASLEndingFallback(sslBaseAnimation anim, int stage, int ActorPos) Global
	if ASLStageCode(anim, stage) == "EN"
		return "ENI"
	endif
	return "LDI"
EndFunction
