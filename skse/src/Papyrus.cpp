#include "Papyrus.h"

#include "PPA.h"
#include "core/Labels.h"

namespace Papyrus
{
	namespace
	{
		constexpr auto kPPAScript = "SLOVE_PPA"sv;
		constexpr auto kTagsScript = "SLOVE_Hentairim_Tags"sv;

		// Natives below never throw into the VM: what can fail (an unknown actor,
		// no PPA) answers "nothing measured", and std::bad_alloc is the only
		// exception left, which would take the game down anywhere.

		// ---------- SLOVE_PPA ----------

		bool IsConnected(RE::StaticFunctionTag*)
		{
			return PPA::Connected();
		}

		float GetDepth(RE::StaticFunctionTag*, RE::Actor* a_receiver)
		{
			const auto snapshot = PPA::GetFor(a_receiver);
			return snapshot ? snapshot->depth : 0.0f;
		}

		std::int32_t GetContext(RE::StaticFunctionTag*, RE::Actor* a_receiver)
		{
			const auto snapshot = PPA::GetFor(a_receiver);
			return snapshot ? static_cast<std::int32_t>(snapshot->context) : 0;
		}

		std::int32_t GetPenetrationSite(RE::StaticFunctionTag*, RE::Actor* a_receiver)
		{
			const auto snapshot = PPA::GetFor(a_receiver);
			return snapshot ? static_cast<std::int32_t>(snapshot->site) : 0;
		}

		float GetVaginalOpening(RE::StaticFunctionTag*, RE::Actor* a_receiver)
		{
			const auto snapshot = PPA::GetFor(a_receiver);
			return snapshot ? snapshot->vaginalOpening : 0.0f;
		}

		float GetAnalOpening(RE::StaticFunctionTag*, RE::Actor* a_receiver)
		{
			const auto snapshot = PPA::GetFor(a_receiver);
			return snapshot ? snapshot->anusOpening : 0.0f;
		}

		// The whole reading in one call, the layout AudioUtilPPA.GetSnapshot has:
		//   [0] depth  [1] context bitmask  [2] penetration site
		//   [3] sites bitmask  [4] self-penetration site
		//   [5] vaginal opening  [6] anal opening
		// All zeros = nothing measured, never an empty array: CommonLib hands a
		// zero-length vector to the VM as None, and the script then logs a cast
		// error on every call.
		std::vector<float> GetSnapshot(RE::StaticFunctionTag*, RE::Actor* a_receiver)
		{
			const auto snapshot = PPA::GetFor(a_receiver);
			if (!snapshot) {
				return std::vector<float>(7, 0.0f);
			}
			return {
				snapshot->depth,
				static_cast<float>(snapshot->context),
				static_cast<float>(snapshot->site),
				static_cast<float>(snapshot->siteMask),
				static_cast<float>(snapshot->selfSite),
				snapshot->vaginalOpening,
				snapshot->anusOpening
			};
		}

		float GetPairDepth(RE::StaticFunctionTag*, RE::Actor* a_giver, RE::Actor* a_receiver)
		{
			return PPA::PairDepth(a_giver, a_receiver);
		}

		void WatchThrusts(RE::StaticFunctionTag*, RE::Actor* a_giver, RE::Actor* a_receiver, float a_turn)
		{
			PPA::Watch(a_giver, a_receiver, a_turn);
		}

		void UnwatchThrusts(RE::StaticFunctionTag*, RE::Actor* a_giver)
		{
			PPA::Unwatch(a_giver);
		}

		// ---------- SLOVE_Hentairim_Tags ----------

		// a script hands over the scene's tag list, and on P+ its annotations as a
		// second list (SexlabRegistry.GetSceneTags leaves those out, IsSceneTag sees
		// them); either may be None
		Core::Labels::TagSet ToSet(const std::vector<RE::BSFixedString>& a_tags,
			const std::vector<RE::BSFixedString>& a_moreTags)
		{
			Core::Labels::TagSet set;
			for (const auto& tag : a_tags) {
				set.Add(tag.c_str());
			}
			for (const auto& tag : a_moreTags) {
				set.Add(tag.c_str());
			}
			return set;
		}

		Core::Labels::Kind KindOf(std::int32_t a_kind)
		{
			return a_kind >= 0 && a_kind < Core::Labels::kKinds ? static_cast<Core::Labels::Kind>(a_kind) : Core::Labels::Kind::Stimulation;
		}

		// One kind for positions 0..aiPositions-1. Zero positions = None, as the
		// Papyrus original returned for an empty actor list.
		std::vector<RE::BSFixedString> ClassifyStage(RE::StaticFunctionTag*,
			std::vector<RE::BSFixedString> a_tags, std::vector<RE::BSFixedString> a_moreTags,
			std::int32_t a_stage, std::int32_t a_positions, std::int32_t a_kind, bool a_aslFallback)
		{
			const auto set = ToSet(a_tags, a_moreTags);
			const auto positions = std::clamp(a_positions, 0, 25);  // SexLab has 5; well under the 128 an array may hold
			std::vector<RE::BSFixedString> out;
			for (const auto& label : Core::Labels::Labels(set, KindOf(a_kind), a_stage, positions, a_aslFallback)) {
				out.emplace_back(label.c_str());
			}
			return out;
		}

		RE::BSFixedString ClassifyOne(RE::StaticFunctionTag*,
			std::vector<RE::BSFixedString> a_tags, std::vector<RE::BSFixedString> a_moreTags,
			std::int32_t a_stage, std::int32_t a_position, std::int32_t a_kind, bool a_aslFallback)
		{
			const auto set = ToSet(a_tags, a_moreTags);
			return Core::Labels::Label(set, KindOf(a_kind), a_stage, a_position, a_aslFallback).c_str();
		}
	}

	bool Register(RE::BSScript::IVirtualMachine* a_vm)
	{
		if (!a_vm) {
			return false;
		}
		// true = callable without waiting for the next VM frame: these only read
		// the bridge's mutex-guarded cache or compute, never touch game objects
		a_vm->RegisterFunction("IsConnected"sv, kPPAScript, IsConnected, true);
		a_vm->RegisterFunction("GetDepth"sv, kPPAScript, GetDepth, true);
		a_vm->RegisterFunction("GetContext"sv, kPPAScript, GetContext, true);
		a_vm->RegisterFunction("GetPenetrationSite"sv, kPPAScript, GetPenetrationSite, true);
		a_vm->RegisterFunction("GetVaginalOpening"sv, kPPAScript, GetVaginalOpening, true);
		a_vm->RegisterFunction("GetAnalOpening"sv, kPPAScript, GetAnalOpening, true);
		a_vm->RegisterFunction("GetSnapshot"sv, kPPAScript, GetSnapshot, true);
		a_vm->RegisterFunction("GetPairDepth"sv, kPPAScript, GetPairDepth, true);
		a_vm->RegisterFunction("WatchThrusts"sv, kPPAScript, WatchThrusts, true);
		a_vm->RegisterFunction("UnwatchThrusts"sv, kPPAScript, UnwatchThrusts, true);

		a_vm->RegisterFunction("ClassifyStage"sv, kTagsScript, ClassifyStage, true);
		a_vm->RegisterFunction("ClassifyOne"sv, kTagsScript, ClassifyOne, true);

		logger::info("Papyrus natives registered ({}, {})", kPPAScript, kTagsScript);
		return true;
	}
}
