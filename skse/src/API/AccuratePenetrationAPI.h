#pragma once

// Copied from AudioUtil (include/API). Recreated from https://asdasdduck.github.io/ppa-docs/skse-api.html (API v1).
// The interface is resolved dynamically via GetModuleHandle/GetProcAddress:
// never link against AccuratePenetration.dll.

#include <cstdint>

#include "RE/B/BSPointerHandle.h"

namespace AccuratePenetration::API
{
	inline constexpr std::uint32_t kVersion = 1;
	inline constexpr auto          kPluginDLL = L"AccuratePenetration.dll";
	inline constexpr auto          kGetAPIFunctionNameV1 = "AccuratePenetration_GetAPI_V1";

	enum class SceneContext : std::uint32_t
	{
		None = 0,
		Vaginal = 1u << 0,
		Anal = 1u << 1,
		Oral = 1u << 2,
		Aggressive = 1u << 3,
		FemDom = 1u << 4,
		Loving = 1u << 5,
		Dirty = 1u << 6,
		Boobjob = 1u << 7,
		Handjob = 1u << 8,
		Footjob = 1u << 9,
		Masturbation = 1u << 10
	};

	constexpr SceneContext operator&(SceneContext a_lhs, SceneContext a_rhs) noexcept
	{
		return static_cast<SceneContext>(
			static_cast<std::uint32_t>(a_lhs) & static_cast<std::uint32_t>(a_rhs));
	}

	constexpr bool HasContext(SceneContext a_flags, SceneContext a_check) noexcept
	{
		return (a_flags & a_check) == a_check;
	}

	enum class PenetrationSite : std::uint8_t
	{
		None = 0,
		Mouth,
		Anus,
		Vagina,
		Both,
		HandL,
		HandR,
		Hands,
	};

	struct InteractionPartner
	{
		RE::ActorHandle actor;
		PenetrationSite site = PenetrationSite::None;
		std::uint8_t    position = 0;
		float           penetrationDepth = 0.0f;
		float           penisSize = 0.0f;
		float           penisGirth = 0.0f;
	};

	struct AnimationUpdateEvent
	{
		std::uint32_t             apiVersion;
		std::uint32_t             size;
		RE::ActorHandle           receiver;
		std::uint8_t              position;
		SceneContext              context;
		const InteractionPartner* selfInteraction;
		const InteractionPartner* actors;
		std::uint32_t             actorCount;
		float                     anusOpening;
		float                     vaginalOpening;
		bool                      ending;
	};

	using ListenerHandle = std::uint64_t;
	using AnimationUpdateCallback = void(__cdecl*)(const AnimationUpdateEvent* a_event, void* a_userData);

	using RegisterAnimationUpdateListenerFn = ListenerHandle(__cdecl*)(
		AnimationUpdateCallback a_callback, void* a_userData);
	using UnregisterAnimationUpdateListenerFn = bool(__cdecl*)(ListenerHandle a_handle);

	struct InterfaceV1
	{
		std::uint32_t                       version = kVersion;
		std::uint32_t                       size = sizeof(InterfaceV1);
		RegisterAnimationUpdateListenerFn   RegisterAnimationUpdateListener = nullptr;
		UnregisterAnimationUpdateListenerFn UnregisterAnimationUpdateListener = nullptr;
	};

	using GetAPIFn = const InterfaceV1*(__cdecl*)();
}
