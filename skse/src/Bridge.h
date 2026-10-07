#pragma once

// The two things this plugin asks of AudioUtil, both through its Papyrus natives
// (AudioUtil's C API exports neither):
//   TomlUtil.Reload(file)              - re-read SLOVE.toml into AudioUtil's cache, which
//                                        is what the SLO VE scripts actually read
//   AudioUtil.SetGroupVolume(group, v) - move a volume bus now, mid-scene
// The calls are queued on the SKSE task queue and dispatched on the game thread.
// A dispatch can be lost (no save loaded, a load resets the VM), so the reload is
// a state, not an event: "dirty" stays set until AudioUtil confirms, and is sent
// again on the next occasion. The file on disk is right either way - this plugin
// writes it itself.

namespace Bridge
{
	// SLOVE.toml changed on disk: have AudioUtil re-read it. Safe to call often.
	void RequestReload();

	// Send the reload again when one is owed and none is on its way. Called from
	// the menu while it is open, on menu open/close, and after a game load.
	void Pump();

	// A game is being loaded or started: the VM is reset, so a reload that was on
	// its way is gone, and with it the callback.
	void OnVmReset();

	// A reload is owed or on its way, and for how long (seconds) it has been.
	bool  ReloadPending();
	float PendingSeconds();

	// The volume buses a SLOVE.toml key feeds, pushed to AudioUtil at once.
	// a_percent is the key's 0-100 value. Returns false when the key is not a
	// volume. See the table in Bridge.cpp for the buses and the two fallbacks.
	bool IsVolume(std::string_view a_key);
	void PushVolume(std::string_view a_key, std::int64_t a_percent, bool a_orgasmInFile, bool a_npcSceneInFile);
}
