#pragma once

// The SLO VE pages in SKSE Menu Framework's Mod Control Panel: one page per
// section of SLOVE.toml, drawn from Core::Model.

namespace Menu
{
	// Called once, at kDataLoaded. Does nothing (and logs why) when the framework
	// is missing or too old; the plugin then stays loaded and inert.
	void Register();
}
