#pragma once

// The label engine: classifies one stage of a scene into the Hentairim-convention
// label codes the voice, face, SFX and willpower engines key on. It used to be
// Papyrus (SLOVE_Hentairim_Tags), one tag lookup per candidate code; the scripts
// now hand over the scene's whole tag list once and this answers every question.
//
// A tag code is <stage><position letter><action>, e.g. "3ASVP" = stage 3,
// position 0, slow vaginal penetration. Positions 0-4 are the letters A-E; any
// other position has no letter, exactly as the Papyrus original built the string.
// The scene-wide codes (no letter) of the older ASL database, "3SV" etc., are read
// by the classic variant's fallback layer only. docs\hentairim-tags.md has the
// whole scheme.
//
// Tags match ignoring case, the way both SexLab flavours compare them.

#include <string>
#include <string_view>
#include <unordered_set>
#include <vector>

namespace Core::Labels
{
	// The label kinds, in the order the Papyrus wrappers number them.
	enum class Kind
	{
		Stimulation = 0,  // SST/FST/BST
		PenisAction = 1,  // SDV/FDV/SDA/FDA/SHJ/FHJ/STF/FTF/SMF/FMF/SFJ/FFJ
		Oral = 2,         // RIM/CUN/FBJ/SBJ/KIS
		Penetration = 3,  // SDP/FDP/SCG/FCG/SAC/FAC/SVP/SAP/FVP/FAP
		Ending = 4,       // ENO/ENI
		SFX = 5           // the stage's SFX tag (SC/MC/FC/SS/MS/FS/RS/NA), position ignored
	};

	inline constexpr int kKinds = 6;

	class TagSet
	{
	public:
		TagSet() = default;
		void Add(std::string_view a_tag);
		bool Has(std::string_view a_tag) const;
		bool Empty() const { return _tags.empty(); }

	private:
		std::unordered_set<std::string> _tags;  // lower-cased
	};

	// One label. Kinds 0-4 answer "LDI" (lead-in) when no code applies, SFX
	// answers "". a_aslFallback = the classic variant's derivation from the
	// scene-wide ASL codes when a stage carries no per-position code.
	std::string Label(const TagSet& a_tags, Kind a_kind, int a_stage, int a_position, bool a_aslFallback);

	// One kind for positions 0..a_positions-1.
	std::vector<std::string> Labels(const TagSet& a_tags, Kind a_kind, int a_stage, int a_positions, bool a_aslFallback);
}
