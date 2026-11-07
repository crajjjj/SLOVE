#include "core/Labels.h"

#include <array>

namespace Core::Labels
{
	namespace
	{
		std::string Lower(std::string_view a_text)
		{
			std::string out{ a_text };
			for (auto& c : out) {
				if (c >= 'A' && c <= 'Z') {
					c = static_cast<char>(c - 'A' + 'a');
				}
			}
			return out;
		}

		std::string_view Letter(int a_position)
		{
			static constexpr std::array<std::string_view, 5> kLetters{ "A", "B", "C", "D", "E" };
			return a_position >= 0 && a_position < 5 ? kLetters[static_cast<std::size_t>(a_position)] : std::string_view{};
		}

		// The first code of a_codes the stage carries for this position, else "".
		// Order is precedence: the Papyrus original was an if/elseif ladder, and the
		// order is load-bearing (see the comments at each table).
		template <std::size_t N>
		std::string_view First(const TagSet& a_tags, int a_stage, std::string_view a_letter,
			const std::array<std::string_view, N>& a_codes)
		{
			const auto prefix = std::to_string(a_stage) + std::string{ a_letter };
			for (const auto code : a_codes) {
				if (a_tags.Has(prefix + std::string{ code })) {
					return code;
				}
			}
			return {};
		}

		constexpr std::array<std::string_view, 3> kStimulation{ "SST", "FST", "BST" };

		// double-pen, then cowgirl, then straight vaginal/anal: a DP stage IS
		// vaginal + anal, so if a database co-tags SDP with SVP/SAP, checking the
		// component first would mask the DP (dropping its voice branch); same for
		// cowgirl against straight. Single-tag stages are unaffected.
		constexpr std::array<std::string_view, 10> kPenetration{
			"SDP", "FDP", "SCG", "FCG", "SAC", "FAC", "SVP", "SAP", "FVP", "FAP"
		};

		constexpr std::array<std::string_view, 12> kPenisAction{
			"SDV", "FDV", "SDA", "FDA", "SHJ", "FHJ", "STF", "FTF", "SMF", "FMF", "SFJ", "FFJ"
		};

		// the genital-oral actions win over KIS: many scenes tag a stage with BOTH
		// kissing and the real oral action, and KIS first masked cunnilingus and
		// blowjob (their voice AND the licking tongue). RIM only exists as an
		// explicit authored tag (no converter emits it), so when present it is the
		// most specific signal and goes first.
		constexpr std::array<std::string_view, 5> kOral{ "RIM", "CUN", "FBJ", "SBJ", "KIS" };

		constexpr std::array<std::string_view, 2> kEnding{ "ENO", "ENI" };

		// claps, then slushes, NA = explicitly silent
		constexpr std::array<std::string_view, 8> kSFX{ "SC", "MC", "FC", "SS", "MS", "FS", "RS", "NA" };

		// ---- the classic variant's ASL fallback layer ----
		// The Hentairim database annotates <stage><POS><LABEL> (1ASVP, 1BSDV,
		// 5AENO). The older, broader ASL database (SLAnimStageLabels) annotates only
		// <stage><CODE> (3SV, 1LI, 6EN): scene-wide, no position letter. When an
		// animation has ASL data but no per-position data, a per-position label is
		// derived from the scene-wide code by the convention the Hentairim database
		// itself follows: position A (0) is the RECEIVER, B and later the GIVERS.
		constexpr std::array<std::string_view, 11> kASLStage{
			"LI", "FA", "SA", "FV", "SV", "DP", "TP", "SR", "FB", "SB", "EN"
		};

		std::string_view ASLStageCode(const TagSet& a_tags, int a_stage)
		{
			return First(a_tags, a_stage, {}, kASLStage);
		}

		// receiver view: only position A is penetrated under the ASL convention
		std::string_view ASLPenetration(const TagSet& a_tags, int a_stage, int a_position)
		{
			if (a_position != 0) {
				return "LDI";
			}
			const auto c = ASLStageCode(a_tags, a_stage);
			if (c == "SV" || c == "SR") {
				return "SVP";
			} else if (c == "FV") {
				return "FVP";
			} else if (c == "SA") {
				return "SAP";
			} else if (c == "FA") {
				return "FAP";
			} else if (c == "DP" || c == "TP") {
				return "SDP";
			}
			return "LDI";
		}

		// giver view: positions B+ deliver under the ASL convention
		std::string_view ASLPenisAction(const TagSet& a_tags, int a_stage, int a_position)
		{
			if (a_position == 0) {
				return "LDI";
			}
			const auto c = ASLStageCode(a_tags, a_stage);
			if (c == "SV" || c == "DP" || c == "TP" || c == "SR") {
				return "SDV";
			} else if (c == "FV") {
				return "FDV";
			} else if (c == "SA") {
				return "SDA";
			} else if (c == "FA") {
				return "FDA";
			} else if (c == "SB") {
				return "SMF";
			} else if (c == "FB") {
				return "FMF";
			}
			return "LDI";
		}

		// mouth view: position A performs the oral action (the spitroast case too)
		std::string_view ASLOral(const TagSet& a_tags, int a_stage, int a_position)
		{
			if (a_position != 0) {
				return "LDI";
			}
			const auto c = ASLStageCode(a_tags, a_stage);
			if (c == "SB" || c == "SR") {
				return "SBJ";
			} else if (c == "FB") {
				return "FBJ";
			}
			return "LDI";
		}

		// ASL has one scene-wide EN with no inside/outside and no position letter,
		// so every position reads as ending; ENI is the common case
		std::string_view ASLEnding(const TagSet& a_tags, int a_stage)
		{
			return ASLStageCode(a_tags, a_stage) == "EN" ? "ENI" : "LDI";
		}
	}

	void TagSet::Add(std::string_view a_tag)
	{
		if (!a_tag.empty()) {
			_tags.insert(Lower(a_tag));
		}
	}

	bool TagSet::Has(std::string_view a_tag) const
	{
		return !a_tag.empty() && _tags.contains(Lower(a_tag));
	}

	std::string Label(const TagSet& a_tags, Kind a_kind, int a_stage, int a_position, bool a_aslFallback)
	{
		const auto letter = Letter(a_position);
		std::string_view found;
		switch (a_kind) {
		case Kind::Stimulation:
			// no fallback: the ASL scheme has no stimulation code
			found = First(a_tags, a_stage, letter, kStimulation);
			break;
		case Kind::PenisAction:
			found = First(a_tags, a_stage, letter, kPenisAction);
			if (found.empty() && a_aslFallback) {
				found = ASLPenisAction(a_tags, a_stage, a_position);
			}
			break;
		case Kind::Oral:
			found = First(a_tags, a_stage, letter, kOral);
			if (found.empty() && a_aslFallback) {
				found = ASLOral(a_tags, a_stage, a_position);
			}
			break;
		case Kind::Penetration:
			found = First(a_tags, a_stage, letter, kPenetration);
			if (found.empty() && a_aslFallback) {
				found = ASLPenetration(a_tags, a_stage, a_position);
			}
			break;
		case Kind::Ending:
			found = First(a_tags, a_stage, letter, kEnding);
			if (found.empty() && a_aslFallback) {
				found = ASLEnding(a_tags, a_stage);
			}
			break;
		case Kind::SFX:
			return std::string{ First(a_tags, a_stage, {}, kSFX) };
		default:
			return {};
		}
		return found.empty() ? std::string{ "LDI" } : std::string{ found };
	}

	std::vector<std::string> Labels(const TagSet& a_tags, Kind a_kind, int a_stage, int a_positions, bool a_aslFallback)
	{
		std::vector<std::string> out;
		for (int position = 0; position < a_positions; ++position) {
			out.push_back(Label(a_tags, a_kind, a_stage, position, a_aslFallback));
		}
		return out;
	}
}
