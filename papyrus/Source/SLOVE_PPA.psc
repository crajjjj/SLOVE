Scriptname SLOVE_PPA Hidden
{One PPA reading per voice line, shared by the PC voice engine and the
 NPC-scene driver (this used to live as three near-identical copies). Wraps
 AudioUtil's PPA bridge: one native on AudioUtil 0.9.22+ (GetSnapshot, API
 v10), assembled from the scalar getters on older builds. Global functions
 cannot cache, so the API level is re-probed per Read - one cheap native at
 voice-line cadence (6-14s per speaker), never in a tight loop.}

;Snapshot slots (match AudioUtilPPA.GetSnapshot; the assembled fallback fills
;the first three): [0] depth, [1] context bitmask, [2] penetration site.
;No measurement (PPA absent, actor unknown, nothing tracked) = every slot 0 on
;AudioUtil 0.9.25+, an EMPTY array on older builds (which the VM handed over as
;None and logged "Cannot cast from None to Float[]" here per call). The helpers
;below read both the same way.
float[] Function Read(Actor a) Global
	if a == None || !AudioUtilPPA.IsConnected()
		return PapyrusUtil.FloatArray(0)
	endif
	int api = AudioUtil.GetAPIVersion()
	if api >= 10
		return AudioUtilPPA.GetSnapshot(a)
	endif
	float[] r = PapyrusUtil.FloatArray(3)
	r[0] = AudioUtilPPA.GetDepth(a)
	r[1] = AudioUtilPPA.GetContext(a) as float
	if api >= 9
		r[2] = AudioUtilPPA.GetPenetrationSite(a) as float
	endif
	return r
EndFunction

;The context bitmask (0 = none measured). Decompose with Math.LogicalAnd.
Int Function CtxOf(float[] snap) Global
	if snap.length > 1
		return snap[1] as int
	endif
	return 0
EndFunction

;The penetration site ordinal (0 = none measured).
Int Function SiteOf(float[] snap) Global
	if snap.length > 2
		return snap[2] as int
	endif
	return 0
EndFunction

Bool Function HasSite(float[] snap) Global
	return SiteOf(snap) != 0
EndFunction

;The measured depth (0.0 = none measured). PPA's one PHYSICAL signal; working
;range roughly 2 (shallow) to 10 (deep).
Float Function DepthOf(float[] snap) Global
	if snap.length > 0
		return snap[0]
	endif
	return 0.0
EndFunction
