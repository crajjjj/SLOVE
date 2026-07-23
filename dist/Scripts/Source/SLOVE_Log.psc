Scriptname SLOVE_Log Hidden
{Native Papyrus user-log writer for SLO VE. Writes to
   Documents\My Games\Skyrim Special Edition\Logs\Script\User\SLOVE.0.log
 via Debug.OpenUserLog / Debug.TraceUser - a dedicated, timestamped, per-mod
 log file (no PapyrusUtil, no SKSE plugin needed). Papyrus requires the log to
 be opened once per session before TraceUser writes: the Director calls
 InitLog() from Maintenance() (OnInit + every load). Requires bEnableLogging=1
 under [Papyrus] in the ini (the game's Papyrus-logging master switch).}

Import Debug

; open the user log for this session; call once at startup (Director.Maintenance)
Function InitLog() Global
	if OpenUserLog("SLOVE")
		TraceUser("SLOVE", "[--- SLO VE log started ---]")
	endif
EndFunction

; aiPriority: 0 = info, 1 = warning, 2 = error. Papyrus timestamps each line.
Function WriteLog(String asMessage, Int aiPriority = 0) Global
	String sPrefix = "(i) "
	if aiPriority == 2
		sPrefix = "(!ERROR!) "
	elseif aiPriority == 1
		sPrefix = "(!) "
	endif
	TraceUser("SLOVE", sPrefix + asMessage, aiPriority)
EndFunction
