#pragma once

// The willpower of a scene actor on the "special bar" of TrueHUD - HUD Additions:
// the player's under the player widget, an NPC's on its info bar when TrueHUD
// draws one. Optional twice over: without TrueHUD nothing happens, and TrueHUD
// has ONE special bar for all mods (stun and poise meters use it), so it is taken
// only when it is free after every plugin had its turn at load.
//
// The numbers come from the scripts as mod events, which is all the scripts know
// of this (they send them whether or not anyone listens, see SLOVE_Resistance):
//   SLOVE_Willpower     sender = the actor, numArg = willpower 0-100; sent on
//                       every tick of the actor's resistance effect (3-5 s)
//   SLOVE_WillpowerEnd  sender = the actor: the effect, and so the scene, is over
// An actor nothing was heard of for a while is dropped too, so a lost end event
// cannot leave a bar standing.

namespace HudBar
{
	// kDataLoaded: read resistance.enable / resistance.truehudbar and, when the bar
	// is wanted, ask TrueHUD for its special bar on the next frame.
	void Install();

	// A game is being loaded or started: no scene survives that. (Also the last
	// moment to ask for the bar, should the task queued by Install not have run.)
	void Reset();
}
