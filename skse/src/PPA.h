#pragma once

// SLO VE's own connection to Accurate Penetration (AccuratePenetration.dll),
// copied from AudioUtil's PPA bridge (src/PPABridge). SLO VE used to read PPA
// through AudioUtilPPA; with the bridge here it also gets what AudioUtil only
// exposed as one number per receiver: every partner's own depth, and the frames
// themselves. PPA calls the listener on Skyrim's main thread, every frame, for
// every actor it tracks, so the per-frame work stays in here and Papyrus only
// sees polls and one event per thrust.
//
// Thrust watches: SLOVE_SFX asks for one giver -> receiver pair while a
// penetration stage plays, and the turn detector (core/Thrust.h) runs on every
// PPA frame of that pair. Each turn is a mod event, sender = the giver:
//   SLOVE_PPAImpact   numArg = how long the inward stroke took (s), strArg = the
//                     stroke and depth, for the sfx.printdebug line
//   SLOVE_PPAReentry  numArg = the last inward stroke's time, strArg = the depth

namespace PPA
{
	struct Snapshot
	{
		std::uint32_t context = 0;   // PPA SceneContext bitmask (scene classification, not contact)
		float         depth = 0.0f;  // deepest of anything touching this receiver, self included

		// WHERE: the deepest partner's PenetrationSite (0 None, 1 Mouth, 2 Anus,
		// 3 Vagina, 4 Both, 5 HandL, 6 HandR, 7 Hands), every partner's as a mask
		// (1 << site), and the receiver's self-penetration site. A narrower pick
		// than depth, which also counts self and site-None partners.
		std::uint8_t  site = 0;
		std::uint32_t siteMask = 0;
		std::uint8_t  selfSite = 0;

		float anusOpening = 0.0f;     // "magic unsigned numbers" per the PPA author: 0 = closed
		float vaginalOpening = 0.0f;
	};

	// Connect to AccuratePenetration.dll. kDataLoaded, on the main thread (PPA
	// wants listeners registered there). Safe to call again.
	void TryConnect();
	bool Connected();

	std::optional<Snapshot> GetFor(RE::Actor* a_receiver);

	// How deep a_giver is inside a_receiver: that partner's own depth when PPA
	// names a_giver among the receiver's partners, else the receiver's deepest
	// (what one number per receiver always gave). 0 = nothing measured.
	float PairDepth(RE::Actor* a_giver, RE::Actor* a_receiver);

	// Start (or restart) the thrust watch of a_giver on a_receiver; a_turn is the
	// hysteresis (sfx.ppathrustturn). One watch per giver.
	void Watch(RE::Actor* a_giver, RE::Actor* a_receiver, float a_turn);
	void Unwatch(RE::Actor* a_giver);

	// A game is loaded or started: every handle we hold is from the old one.
	void Reset();
}
