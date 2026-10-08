#include "HudBar.h"

#include "Env.h"
#include "core/ConfigDoc.h"

#include <cmath>

// The ONLY include site of the vendored TrueHUD header (extern\TrueHUD\README.txt).
// Its inline RequestPluginAPI hands GetModuleHandle a narrow string, so the macro
// is pinned to the A form while the header is read. The function itself is never
// called: Claim looks the export up and checks the module first.
#pragma warning(push, 0)
#pragma push_macro("GetModuleHandle")
#undef GetModuleHandle
#define GetModuleHandle GetModuleHandleA
#include "TrueHUDAPI.h"
#pragma pop_macro("GetModuleHandle")
#pragma warning(pop)

namespace HudBar
{
	namespace
	{
		using Clock = std::chrono::steady_clock;
		using Api = TRUEHUD_API::IVTrueHUD1;
		using Result = TRUEHUD_API::APIResult;

		constexpr auto  kConfigName = "SLOVE.toml"sv;
		constexpr float kFull = 100.0f;  // willpower runs 0-100, and full is also "nothing to show"
		// An actor not heard of for this long is taken as out of its scene (the
		// scripts send every 3-5 s). Counted in Tick's time, not the clock's.
		constexpr std::int64_t kSilenceMs = 30'000;
		constexpr std::int64_t kFrameCapMs = 100;

		struct Heard
		{
			float        willpower;
			std::int64_t at;  // g_drawn when the last event came
		};

		std::mutex                            g_lock;
		std::unordered_map<RE::FormID, Heard> g_actors;  // the actors in a scene, by form id
		std::atomic<Api*>                     g_api{ nullptr };  // set once the bar is ours
		std::atomic<bool>                     g_pending{ false };  // the bar is wanted and not asked for yet
		std::atomic<std::int64_t>             g_lastAsked{ 0 };
		std::atomic<std::int64_t>             g_drawn{ 0 };

		// g_drawn: the milliseconds TrueHUD has spent asking for values while the
		// game ran. It asks once a frame for every bar it draws, and a paused game
		// is left out, because that is when the scripts stop sending too. Silence
		// measured in this time means the scene is gone, not that the journal was
		// open for a minute.
		void Tick()
		{
			const auto now = std::chrono::duration_cast<std::chrono::milliseconds>(Clock::now().time_since_epoch()).count();
			const auto last = g_lastAsked.exchange(now);
			auto*      ui = RE::UI::GetSingleton();
			if (last != 0 && !(ui && ui->GameIsPaused())) {
				g_drawn.fetch_add(std::clamp<std::int64_t>(now - last, 0, kFrameCapMs));
			}
		}

		// The two functions TrueHUD calls, on its own update, for every actor it
		// draws a bar for. Anyone not in a scene reads as full, which TrueHUD's
		// "dynamic" display mode hides.
		float Current(RE::Actor* a_actor) noexcept
		{
			try {
				Tick();
				if (!a_actor) {
					return kFull;
				}
				const std::scoped_lock lock{ g_lock };
				const auto             it = g_actors.find(a_actor->GetFormID());
				if (it == g_actors.end()) {
					return kFull;
				}
				if (g_drawn.load() - it->second.at > kSilenceMs) {
					g_actors.erase(it);
					return kFull;
				}
				return it->second.willpower;
			} catch (...) {
				return kFull;
			}
		}

		float Max(RE::Actor*) noexcept
		{
			return kFull;
		}

		// The bar has just run out: the long flash TrueHUD has for that. The call
		// reaches into its HUD menu, so it is made from the game thread.
		void Flash(RE::FormID a_actor)
		{
			const auto* tasks = SKSE::GetTaskInterface();
			if (!tasks) {
				return;
			}
			tasks->AddTask([a_actor]() {
				try {
					auto* api = g_api.load();
					auto* actor = RE::TESForm::LookupByID<RE::Actor>(a_actor);
					if (api && actor) {
						api->FlashActorSpecialBar(SKSE::GetPluginHandle(), actor->GetHandle(), true);
					}
				} catch (...) {
				}
			});
		}

		void OnWillpower(RE::FormID a_actor, float a_value)
		{
			if (!std::isfinite(a_value)) {
				return;
			}
			const float value = std::clamp(a_value, 0.0f, kFull);
			bool        broke = false;
			{
				const std::scoped_lock lock{ g_lock };
				const Heard            heard{ value, g_drawn.load() };
				const auto [it, added] = g_actors.try_emplace(a_actor, heard);
				if (!added) {
					broke = it->second.willpower > 0.0f && value <= 0.0f;
					it->second = heard;
				}
			}
			if (broke) {
				Flash(a_actor);
			}
		}

		void OnEnd(RE::FormID a_actor)
		{
			const std::scoped_lock lock{ g_lock };
			g_actors.erase(a_actor);
		}

		// Every mod event of the game passes through here, on the thread that sent
		// it (a Papyrus one, as a rule): two compares of interned strings and out.
		class Sink final : public RE::BSTEventSink<SKSE::ModCallbackEvent>
		{
		public:
			RE::BSEventNotifyControl ProcessEvent(const SKSE::ModCallbackEvent* a_event, RE::BSTEventSource<SKSE::ModCallbackEvent>*) override
			{
				try {
					if (a_event && a_event->sender) {
						if (a_event->eventName == _willpower) {
							if (a_event->sender->Is(RE::FormType::ActorCharacter)) {
								OnWillpower(a_event->sender->GetFormID(), a_event->numArg);
							}
						} else if (a_event->eventName == _end) {
							OnEnd(a_event->sender->GetFormID());
						}
					}
				} catch (...) {
				}
				return RE::BSEventNotifyControl::kContinue;
			}

		private:
			RE::BSFixedString _willpower{ "SLOVE_Willpower" };
			RE::BSFixedString _end{ "SLOVE_WillpowerEnd" };
		};

		// A flag the way the scripts take one: SLOVE_Config.GetInt(key) == 1, with
		// TomlUtil's conversions (true reads as 1, 1.0 as 1). A missing key, or a
		// file that does not parse, is the fallback: the scripts run on theirs then.
		// scripts\check-config.ps1 finds the keys this plugin reads by this call.
		bool Flag(const Core::ConfigDoc& a_doc, std::string_view a_key, bool a_fallback)
		{
			const auto* entry = a_doc.Ok() ? a_doc.Find(a_key) : nullptr;
			if (!entry) {
				return a_fallback;
			}
			if (const auto* number = std::get_if<std::int64_t>(&entry->value)) {
				return *number == 1;
			}
			if (const auto* truth = std::get_if<bool>(&entry->value)) {
				return *truth;
			}
			if (const auto* real = std::get_if<double>(&entry->value)) {
				return *real == 1.0;
			}
			return a_fallback;
		}

		void Claim()
		{
			const HMODULE module = ::GetModuleHandleW(L"TrueHUD");
			const auto    request = module ? reinterpret_cast<TRUEHUD_API::_RequestPluginAPI>(::GetProcAddress(module, "RequestPluginAPI")) : nullptr;
			auto*         api = request ? static_cast<Api*>(request(TRUEHUD_API::InterfaceVersion::V1)) : nullptr;
			if (!api) {
				logger::warn("TrueHUD willpower bar: off - this TrueHUD hands out no plugin API");
				return;
			}

			const auto self = SKSE::GetPluginHandle();
			const auto asked = api->RequestSpecialResourceBarsControl(self);
			if (asked != Result::OK && asked != Result::AlreadyGiven) {
				logger::info("TrueHUD willpower bar: off - TrueHUD has one special bar and another plugin uses it (SKSE plugin handle {})",
					api->GetSpecialResourceBarControlOwner());
				return;
			}

			auto* events = SKSE::GetModCallbackEventSource();
			// true: full is the resting state and empty is where the bar flashes,
			// the mode every stun and poise meter registers with.
			if (!events || api->RegisterSpecialResourceFunctions(self, Current, Max, true, true) != Result::OK) {
				api->ReleaseSpecialResourceBarControl(self);
				logger::warn("TrueHUD willpower bar: off - TrueHUD did not take the bar's functions");
				return;
			}
			static Sink sink;
			events->AddEventSink(&sink);
			g_api.store(api);
			logger::info("TrueHUD willpower bar: on (the special bar was free)");
		}

		void ClaimOnce()
		{
			if (!g_pending.exchange(false)) {
				return;
			}
			try {
				Claim();
			} catch (...) {
				logger::error("TrueHUD willpower bar: asking for the special bar failed");
			}
		}
	}

	void Install()
	{
		try {
			if (!::GetModuleHandleW(L"TrueHUD")) {
				logger::info("TrueHUD willpower bar: TrueHUD is not installed");
				return;
			}
			Core::ConfigDoc doc;
			if (!doc.Load(Env::Get().configDir / kConfigName)) {
				logger::warn("TrueHUD willpower bar: SLOVE.toml could not be read ({}), going by the defaults", doc.Error());
			}
			if (!Flag(doc, "resistance.enable"sv, true) || !Flag(doc, "resistance.truehudbar"sv, true)) {
				logger::info("TrueHUD willpower bar: switched off in SLOVE.toml (resistance.enable / resistance.truehudbar)");
				return;
			}
			// Not now: the plugins after this one have not had kDataLoaded yet, and a
			// stun or poise meter that asks for the bar there must find it free. The
			// task runs on the next frame - every plugin has had its turn, and TrueHUD
			// has not built a widget yet (it reads the bar's mode when it builds one).
			// Should the task not have run by the first game load, Reset asks then.
			g_pending.store(true);
			if (const auto* tasks = SKSE::GetTaskInterface()) {
				tasks->AddTask([]() { ClaimOnce(); });
			}
		} catch (...) {
			logger::error("TrueHUD willpower bar: setting it up failed");
		}
	}

	void Reset()
	{
		ClaimOnce();
		const std::scoped_lock lock{ g_lock };
		g_actors.clear();
	}
}
