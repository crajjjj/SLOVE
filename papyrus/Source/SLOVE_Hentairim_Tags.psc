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
	return LabelOf(anim, stage, ActorPos, 0)
endfunction

string Function PenetrationLabel(string anim , int stage , Int ActorPos) Global
	;precedence (in the DLL) matches the voice dispatcher's branch order
	;(SLOVE_Voice.OnUpdate): double-pen, then cowgirl, then straight vaginal/anal
	return LabelOf(anim, stage, ActorPos, 3)
endfunction

string Function PenisActionLabel(string anim , int stage , Int ActorPos) Global
	return LabelOf(anim, stage, ActorPos, 1)
endfunction

String Function OralLabel(string anim , int stage , Int ActorPos) Global
	;precedence (in the DLL): RIM, then the genital-oral actions, KIS last
	return LabelOf(anim, stage, ActorPos, 2)
endfunction

String Function EndingLabel(string anim , int stage , Int ActorPos) Global
	;Labels that identify actions on partners
	return LabelOf(anim, stage, ActorPos, 4)
endfunction

string Function GetSFX(string anim , int stage) Global
	;SFX tag for the body-SFX engine (SLOVE_SFX): claps SC/MC/FC, slushes
	;SS/MS/FS/RS, NA = explicitly silent, "" = no SFX tag on this stage
	return LabelOf(anim, stage, 0, 5)
endfunction

;---------------- the classifier (SLOVE.dll, core\Labels.cpp) ----------------
;Since 0.7.10 the ladders that turned tags into labels live in the DLL, which gets
;the scene's tags once per question instead of one IsSceneTag call per candidate
;code. asTags + asMoreTags = every tag of the scene (either may be None). aiKind:
;0 stimulation, 1 penis action, 2 oral, 3 penetration, 4 ending, 5 the stage's SFX
;tag (position ignored). abASLFallback = derive per-position labels from the
;scene-wide ASL codes, which only the classic variant asks for.
String[] Function ClassifyStage(String[] asTags, String[] asMoreTags, Int aiStage, Int aiPositions, Int aiKind, Bool abASLFallback) native global
String Function ClassifyOne(String[] asTags, String[] asMoreTags, Int aiStage, Int aiPosition, Int aiKind, Bool abASLFallback) native global
;kinds 0-4 of one position, in that order
String[] Function ClassifyPosition(String[] asTags, String[] asMoreTags, Int aiStage, Int aiPosition, Bool abASLFallback) native global

;IsSceneTag sees a scene's tag list AND the annotations a player added in P+'s
;scene editor; GetSceneTags leaves the annotations out, so both lists go over.
;Without SLOVE.dll (the Director says so at load) every native answers None: the
;helpers then answer lead-in, as a scene without any tag database does, so no
;`!= "LDI"` check anywhere takes its branch on nothing.
String Function LabelOf(string anim, int stage, int pos, int kind) Global
	string label = ClassifyOne(SexLabRegistry.GetSceneTags(anim), SexLabRegistry.GetSceneAnnotations(anim), stage, pos, kind, false)
	if label == "" && kind < 5
		return "LDI"
	endif
	return label
EndFunction

;One kind for every position of actorlist. None for an empty list, as before.
String[] Function LabelsOf(string anim, int stage, actor[] actorlist, int kind) Global
	int n = 0
	if actorlist
		n = actorlist.length
	endif
	string[] labels = ClassifyStage(SexLabRegistry.GetSceneTags(anim), SexLabRegistry.GetSceneAnnotations(anim), stage, n, kind, false)
	if !labels && n > 0
		return PapyrusUtil.StringArray(n, "LDI")
	endif
	return labels
EndFunction

;One position's five labels, [0] stimulation [1] penis action [2] oral
;[3] penetration [4] ending, from one tag read: what the per-actor effects ask
;for on every update. Always 5 entries.
String[] Function GetPositionLabels(string anim, int stage, int pos) Global
	string[] labels = ClassifyPosition(SexLabRegistry.GetSceneTags(anim), SexLabRegistry.GetSceneAnnotations(anim), stage, pos, false)
	if !labels || labels.length != 5
		return PapyrusUtil.StringArray(5, "LDI")
	endif
	return labels
EndFunction

;GetLabel (above, uncalled) still asks IsSceneTag one code at a time
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
	return LabelsOf(anim, stage, actorlist, 0)
endfunction

String[] Function GetPenisActionlabelarr(string anim , int stage , actor[] actorlist) Global
	return LabelsOf(anim, stage, actorlist, 1)
endfunction

String[] Function GetOrallabelarr(string anim , int stage , actor[] actorlist) Global
	return LabelsOf(anim, stage, actorlist, 2)
endfunction

String[] Function GetPenetrationLabelarr(string anim , int stage , actor[] actorlist) Global
	return LabelsOf(anim, stage, actorlist, 3)
endfunction

String[] Function GetEndingLabelarr(string anim , int stage , actor[] actorlist) Global
	return LabelsOf(anim, stage, actorlist, 4)
endfunction