#pragma once

// What this install has, found once at kDataLoaded (every SKSE plugin is loaded
// by then, so a module that is not there now will not appear later).

#include "core/Schema.h"

namespace Env
{
	enum class SexLab
	{
		Unknown,   // no SexLabUtil plugin answered
		Classic,   // SexLab SE 1.6x: also ships a SexLabUtil.dll, so the DLL's name proves nothing
		PPlus,     // SexLab P+ older than 2.19
		PPlus219   // SexLab P+ 2.19+, the contact-detection API
	};

	struct State
	{
		bool          frameworkOk = false;  // SKSE Menu Framework is loaded and has every export the menu calls
		std::string   frameworkWhy;         // why not, for the log
		bool          audioUtil = false;    // AudioUtil.dll is loaded (it owns the config cache and the volume buses)
		SexLab        sexLab = SexLab::Unknown;
		std::uint32_t sexLabVersion = 0;
		std::filesystem::path configDir;  // Data\SKSE\Plugins\SLOVE
	};

	void         Detect(const SKSE::LoadInterface* a_skse);
	const State& Get();

	// True when a setting marked "requires" does something on this install. A
	// hint for dimming a row - an unknown SexLab is given the benefit of the doubt.
	bool Meets(Core::Needs a_needs);
}
