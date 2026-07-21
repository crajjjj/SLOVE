Scriptname SLOVE_Hentairim_Tags Hidden
{Label engine: classifies SexLab P+ scene stages into Hentairim-convention
 label codes read from scene tags. Ported from HentaiRimTags; the JSON tag
 store paths are kept for compatibility with existing tag databases.
 The name carries the annotation scheme on purpose: an OStim backend would
 ship its own *_Tags script for its scheme (see docs\framework-adapter.md).}

string Function GetLabel(string anim , int stage , String actorpos = "0" ) Global

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


string Function StimulationLabel(string anim , int stage , Int ActorPos) Global

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
	else
		return "LDI" ;default lead in if no stimulating actions
	endif

endfunction

string Function PenetrationLabel(string anim , int stage , Int ActorPos) Global

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
	else
		return "LDI" ;Default lead in if no stimulating actions
	endif
endfunction

string Function PenisActionLabel(string anim , int stage , Int ActorPos) Global
	
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
	else
		reTURN "LDI" ;default lead in if no stimulating actions
	endif
endfunction


String Function OralLabel(string anim , int stage , Int ActorPos) Global
	
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
	else
		reTURN "LDI"
	endif

endfunction

String Function EndingLabel(string anim , int stage , Int ActorPos) Global
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
	else
		Return "LDI"
	endif

endfunction



bool Function HasASLTag(string anim, string tag) Global
	return SexLabRegistry.IsSceneTag(anim, tag)
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


String[] Function GetStimulationlabelarr(string anim , int stage , actor[] actorlist) Global
	int z
	string[] result
	while z < actorList.length
		result = papyrusutil.pushstring(result , StimulationLabel(anim , stage , z))
		z += 1
	endwhile
	return result
endfunction

String[] Function GetPenisActionlabelarr(string anim , int stage , actor[] actorlist) Global
	int z
	string[] result
	while z < actorList.length
		result = papyrusutil.pushstring(result , PenisActionLabel(anim , stage , z))
		z += 1
	endwhile
	return result
endfunction

String[] Function GetOrallabelarr(string anim , int stage , actor[] actorlist) Global
	int z
	string[] result
	while z < actorList.length
		result = papyrusutil.pushstring(result , OralLabel(anim , stage , z))
		z += 1
	endwhile
	return result
endfunction

String[] Function GetPenetrationLabelarr(string anim , int stage , actor[] actorlist) Global
	int z
	string[] result
	while z < actorList.length
		result = papyrusutil.pushstring(result , PenetrationLabel(anim , stage , z))
		z += 1
	endwhile
	return result
endfunction

String[] Function GetEndingLabelarr(string anim , int stage , actor[] actorlist) Global
	int z
	string[] result
	while z < actorList.length
		result = papyrusutil.pushstring(result , EndingLabel(anim , stage , z))
		z += 1
	endwhile
	return result
endfunction