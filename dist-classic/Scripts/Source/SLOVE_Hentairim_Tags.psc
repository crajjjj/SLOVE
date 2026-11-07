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
	;no per-position tag = lead-in: the ASL scheme has no stimulation code
	return LabelOf(anim, stage, ActorPos, 0)
endfunction

string Function PenetrationLabel(sslBaseAnimation anim , int stage , Int ActorPos) Global
	;precedence (in the DLL) matches the voice dispatcher's branch order (see the P+
	;copy): double-pen, then cowgirl, then straight vaginal/anal; then the ASL fallback
	return LabelOf(anim, stage, ActorPos, 3)
endfunction

string Function PenisActionLabel(sslBaseAnimation anim , int stage , Int ActorPos) Global
	return LabelOf(anim, stage, ActorPos, 1)
endfunction

String Function OralLabel(sslBaseAnimation anim , int stage , Int ActorPos) Global
	;precedence (in the DLL): RIM, then the genital-oral actions, KIS last; then ASL
	return LabelOf(anim, stage, ActorPos, 2)
endfunction

String Function EndingLabel(sslBaseAnimation anim , int stage , Int ActorPos) Global
	;Labels that identify actions on partners
	return LabelOf(anim, stage, ActorPos, 4)
endfunction

string Function GetSFX(sslBaseAnimation anim , int stage) Global
	;SFX tag for the body-SFX engine (SLOVE_SFX): claps SC/MC/FC, slushes
	;SS/MS/FS/RS, NA = explicitly silent, "" = no SFX tag on this stage
	return LabelOf(anim, stage, 0, 5)
endfunction

;---------------- the classifier (SLOVE.dll, core\Labels.cpp) ----------------
;Since 0.7.10 the ladders that turned tags into labels live in the DLL, the same
;code for both variants; this one asks for the ASL fallback layer (abASLFallback,
;see the SAVE-COMPAT block at the end for what it derives). asTags + asMoreTags =
;every tag of the animation (either may be None). aiKind: 0 stimulation, 1 penis
;action, 2 oral, 3 penetration, 4 ending, 5 the stage's SFX tag (position ignored).
String[] Function ClassifyStage(String[] asTags, String[] asMoreTags, Int aiStage, Int aiPositions, Int aiKind, Bool abASLFallback) native global
String Function ClassifyOne(String[] asTags, String[] asMoreTags, Int aiStage, Int aiPosition, Int aiKind, Bool abASLFallback) native global
;kinds 0-4 of one position, in that order
String[] Function ClassifyPosition(String[] asTags, String[] asMoreTags, Int aiStage, Int aiPosition, Bool abASLFallback) native global

;the SLATE-applied codes are ordinary animation tags (see HasASLTag)
String[] Function AnimTags(sslBaseAnimation anim) Global
	string[] tags
	if anim
		tags = anim.GetTags()
	endif
	return tags
EndFunction

;Without SLOVE.dll (the Director says so at load) every native answers None: the
;helpers then answer lead-in, as an animation without SLATE tags does, so no
;`!= "LDI"` check anywhere takes its branch on nothing.
String Function LabelOf(sslBaseAnimation anim, int stage, int pos, int kind) Global
	string[] noTags
	string label = ClassifyOne(AnimTags(anim), noTags, stage, pos, kind, true)
	if label == "" && kind < 5
		return "LDI"
	endif
	return label
EndFunction

;One kind for every position of actorlist. None for an empty list, as before.
String[] Function LabelsOf(sslBaseAnimation anim, int stage, actor[] actorlist, int kind) Global
	int n = 0
	if actorlist
		n = actorlist.length
	endif
	string[] noTags
	string[] labels = ClassifyStage(AnimTags(anim), noTags, stage, n, kind, true)
	if !labels && n > 0
		return PapyrusUtil.StringArray(n, "LDI")
	endif
	return labels
EndFunction

;One position's five labels, [0] stimulation [1] penis action [2] oral
;[3] penetration [4] ending, from one tag read: what the per-actor effects ask
;for on every update. Always 5 entries.
String[] Function GetPositionLabels(sslBaseAnimation anim, int stage, int pos) Global
	string[] noTags
	string[] labels = ClassifyPosition(AnimTags(anim), noTags, stage, pos, true)
	if !labels || labels.length != 5
		return PapyrusUtil.StringArray(5, "LDI")
	endif
	return labels
EndFunction

;GetLabel (above, uncalled) still asks HasTag one code at a time
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
	return LabelsOf(anim, stage, actorlist, 0)
endfunction

String[] Function GetPenisActionlabelarr(sslBaseAnimation anim , int stage , actor[] actorlist) Global
	return LabelsOf(anim, stage, actorlist, 1)
endfunction

String[] Function GetOrallabelarr(sslBaseAnimation anim , int stage , actor[] actorlist) Global
	return LabelsOf(anim, stage, actorlist, 2)
endfunction

String[] Function GetPenetrationLabelarr(sslBaseAnimation anim , int stage , actor[] actorlist) Global
	return LabelsOf(anim, stage, actorlist, 3)
endfunction

String[] Function GetEndingLabelarr(sslBaseAnimation anim , int stage , actor[] actorlist) Global
	return LabelsOf(anim, stage, actorlist, 4)
endfunction

;================= ASL (SLAnimStageLabels) fallback layer =================
;SAVE-COMPAT ONLY: uncalled since 0.7.10, when this layer moved into SLOVE.dll
;(core\Labels.cpp, abASLFallback); kept for saves that may hold a stack in it.
;What it derives still reads as below.
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
