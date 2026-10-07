#include "Env.h"

namespace Env
{
	namespace
	{
		State g_state;

		// Every SKSEMenuFramework.dll export Menu.cpp reaches, by the name the
		// vendored header binds it to. The header's ImGui wrappers call through
		// GetProcAddress with NO null check, so a missing export is a crash at the
		// call site; probing them all here turns that into "menu disabled" at load.
		// Keep in step with Menu.cpp (scripts\check-config.ps1 compares the two).
		constexpr std::array kFrameworkExports{
			"AddSectionItem",
			"RegisterEventPriority",
			"UnregisterEvent",
			"igBeginTooltip",
			"igButton",
			"igCheckbox",
			"igCollapsingHeader_TreeNodeFlags",
			"igEndTooltip",
			"igGetFontSize",
			"igInputFloat",
			"igInputInt",
			"igInputText",
			"igIsItemActive",
			"igIsItemHovered",
			"igPopID",
			"igPopStyleColor",
			"igPopStyleVar",
			"igPopTextWrapPos",
			"igPushID_Int",
			"igPushStyleColor_Vec4",
			"igPushStyleVar_Float",
			"igPushTextWrapPos",
			"igSameLine",
			"igSeparator",
			"igSetNextItemWidth",
			"igSliderFloat",
			"igSliderInt",
			"igSmallButton",
			"igSpacing",
			"igTextUnformatted",
		};

		void ProbeFramework()
		{
			const HMODULE module = ::GetModuleHandleW(L"SKSEMenuFramework");
			if (!module) {
				g_state.frameworkWhy = "SKSE Menu Framework is not installed";
				return;
			}
			std::string missing;
			for (const char* name : kFrameworkExports) {
				if (!::GetProcAddress(module, name)) {
					missing += missing.empty() ? "" : ", ";
					missing += name;
				}
			}
			if (!missing.empty()) {
				g_state.frameworkWhy = "this SKSE Menu Framework lacks: " + missing;
				return;
			}
			g_state.frameworkOk = true;
		}

		// SKSE packs a plugin version as (major << 24) | (minor << 16) | (patch << 4) | build,
		// the same number Papyrus gets from SKSE.GetPluginVersion("SexLabUtil") - see
		// SLOVE_Utils.HasInteractionAPI, which this mirrors.
		void ProbeSexLab(const SKSE::LoadInterface* a_skse)
		{
			// GetPluginInfo joined SKSE's interface after the SKSEVR build was cut,
			// and CommonLib calls it without looking: on VR that would be a call
			// through whatever lies past the struct. The flavour stays unknown there,
			// which only means no setting is dimmed.
			if (REL::Module::IsVR()) {
				return;
			}
			const auto* info = a_skse ? a_skse->GetPluginInfo("SexLabUtil") : nullptr;
			if (!info) {
				return;
			}
			g_state.sexLabVersion = info->version;
			if (info->version >= 0x02130000) {
				g_state.sexLab = SexLab::PPlus219;
			} else if (info->version >= 0x02000000) {
				g_state.sexLab = SexLab::PPlus;
			} else {
				g_state.sexLab = SexLab::Classic;
			}
		}
	}

	void Detect(const SKSE::LoadInterface* a_skse)
	{
		g_state = {};
		g_state.configDir = std::filesystem::path{ "Data" } / "SKSE" / "Plugins" / "SLOVE";
		g_state.audioUtil = ::GetModuleHandleW(L"AudioUtil") != nullptr;
		ProbeFramework();
		ProbeSexLab(a_skse);

		static constexpr std::array kSexLabNames{ "not found", "classic", "P+ (older than 2.19)", "P+ 2.19+" };
		logger::info("SKSE Menu Framework: {}", g_state.frameworkOk ? "ready" : g_state.frameworkWhy);
		logger::info("AudioUtil: {}", g_state.audioUtil ? "loaded" : "not loaded");
		logger::info("SexLab: {} (SexLabUtil version 0x{:08X})",
			kSexLabNames[static_cast<std::size_t>(g_state.sexLab)], g_state.sexLabVersion);
	}

	const State& Get()
	{
		return g_state;
	}

	bool Meets(Core::Needs a_needs)
	{
		switch (a_needs) {
		case Core::Needs::PPlus:
			return g_state.sexLab != SexLab::Classic;
		case Core::Needs::PPlus219:
			return g_state.sexLab == SexLab::PPlus219 || g_state.sexLab == SexLab::Unknown;
		default:
			return true;
		}
	}
}
