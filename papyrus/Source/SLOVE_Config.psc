Scriptname SLOVE_Config Hidden
{Settings access for SLO VE. All settings live in
 Data\SKSE\Plugins\SLOVE\SLOVE.toml, read through AudioUtil's TomlUtil API.
 Keys are dotted paths ("voice.pcvolume"). When the AudioUtil DLL is missing
 or too old, every getter serves the caller's default (fail-open) - the one
 warning is logged by whoever calls Available() first.}

String Function File() Global
	;forward slashes: Papyrus escapes backslashes in string literals, and
	;TomlUtil normalizes separators anyway
	return "SKSE/Plugins/SLOVE/SLOVE.toml"
EndFunction

;True when the TomlUtil API is present. Callers should log their own single
;warning when this is false at init; getters below stay safe regardless.
Bool Function Available() Global
	return TomlUtil.GetAPIVersion() > 0
EndFunction

Int Function GetInt(String asKey, Int def = 0) Global
	return TomlUtil.GetInt(File(), asKey, def)
EndFunction

Float Function GetFloat(String asKey, Float def = 0.0) Global
	return TomlUtil.GetFloat(File(), asKey, def)
EndFunction

String Function GetString(String asKey, String def = "") Global
	return TomlUtil.GetString(File(), asKey, def)
EndFunction

Bool Function GetBool(String asKey, Bool def = false) Global
	return TomlUtil.GetBool(File(), asKey, def)
EndFunction

;Live tuning: edit SLOVE.toml, then console cgf "SLOVE_Config.Reload"
Bool Function Reload() Global
	return TomlUtil.Reload(File())
EndFunction
