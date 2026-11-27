#pragma once

// Procedural stripping, the game side: which of the armors an actor wears lie on
// a body zone (core/Strip.h says what "lie on" means). Read from the actor's
// loaded 3D: every worn armor's shapes, their skin bones and their vertex buffers,
// the copy the engine keeps for skinning. Nothing is changed and nothing is
// cached; the scripts ask once per actor when a zone first comes into play.
//
// What is never reported, whatever it covers:
//   - the body itself (the actor's skin armor, and any shape drawn with the skin
//     shader: an outfit mesh carries its own copy of the body)
//   - a schlong or a strap-on (anything weighted to the penis shaft bones)
//   - a tongue (anything weighted to tongue bones: it belongs in the mouth)
//   - an item with no name (schlongs, skin patches, effect meshes)
//   - an item with the SexLabNoStrip keyword, or a Devious Devices device
//   - an item in a slot the caller asked to keep
//   - HDT-SMP collision proxies inside an outfit ("Virtual..." shapes) and culled
//     shapes do not count towards their item

#include "core/Strip.h"

namespace Strip
{
	struct Item
	{
		RE::TESObjectARMO*  armor = nullptr;
		Core::Strip::Counts counts;
		std::uint32_t       covered = 0;  // Core::Strip::Zone bits
		bool                shaft = false;
		const char*         kept = nullptr;  // why it is never stripped, nullptr = it may be
	};

	// Every armor the actor's 3D shows, with what it covers. Empty when the 3D is
	// not loaded. a_reach <= 0 = bone weights only.
	std::vector<Item> Survey(RE::Actor* a_actor, float a_reach, std::uint32_t a_keepSlots);

	// The armors to take off for a_zones.
	std::vector<RE::TESForm*> FindBlocking(RE::Actor* a_actor, std::uint32_t a_zones, float a_reach, std::uint32_t a_keepSlots);

	// One line per worn armor, for the console (slovetest strip).
	std::vector<std::string> Describe(RE::Actor* a_actor, float a_reach, std::uint32_t a_keepSlots);
}
