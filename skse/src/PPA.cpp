#include "PPA.h"

#include "API/AccuratePenetrationAPI.h"
#include "core/Thrust.h"

namespace PPA
{
	namespace
	{
		namespace API = AccuratePenetration::API;

		struct Partner
		{
			std::uint32_t handle = 0;  // native actor handle
			float         depth = 0.0f;
		};

		struct Receiver
		{
			Snapshot             snapshot;
			std::vector<Partner> partners;
		};

		struct Watcher
		{
			RE::ActorHandle   giver;
			std::uint32_t     receiver = 0;  // native actor handle
			Core::ThrustWatch watch;
			std::string       impactEvent;   // SLOVE_PPAImpact_<giver FormID>
			std::string       reentryEvent;  // SLOVE_PPAReentry_<giver FormID>
		};

		struct Beat
		{
			RE::ActorHandle giver;
			std::string     event;
			float           timeToThrust = 0.0f;
			std::string     text;
		};

		const API::InterfaceV1* g_api = nullptr;
		API::ListenerHandle     g_listener = 0;
		std::atomic<bool>       g_connected{ false };

		// Leaked on purpose (as in AudioUtil): PPA can call the listener during
		// static teardown at game exit, and objects that are never freed stay valid
		// for the callback's whole lifetime.
		std::unordered_map<std::uint32_t, Receiver>&    g_receivers = *new std::unordered_map<std::uint32_t, Receiver>();
		std::unordered_map<std::uint32_t, Watcher>&     g_watches = *new std::unordered_map<std::uint32_t, Watcher>();  // giver handle -> watch
		std::mutex&                                     g_lock = *new std::mutex();

		double NowSeconds()
		{
			return std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count();
		}

		std::uint32_t KeyOf(RE::Actor* a_actor)
		{
			return a_actor ? a_actor->GetHandle().native_handle() : 0;
		}

		// Under g_lock. The giver's own depth when PPA lists the giver among the
		// receiver's partners this frame.
		std::optional<float> OwnDepth(const Receiver& a_receiver, std::uint32_t a_giver)
		{
			for (const auto& partner : a_receiver.partners) {
				if (partner.handle == a_giver) {
					return partner.depth;
				}
			}
			return std::nullopt;
		}

		// The event names carry the giver, so a beat reaches only the SFX effect
		// that registered for it (the giver's), not every effect in every scene.
		// Papyrus spells an Int as a signed decimal, so the FormID is printed so.
		std::string EventName(std::string_view a_prefix, const RE::Actor* a_giver)
		{
			return std::format("{}_{}", a_prefix, static_cast<std::int32_t>(a_giver->GetFormID()));
		}

		void SendBeat(const Beat& a_beat)
		{
			auto* tasks = SKSE::GetTaskInterface();
			if (!tasks) {
				return;
			}
			tasks->AddTask([a_beat]() {
				auto giver = a_beat.giver.get();
				auto* source = SKSE::GetModCallbackEventSource();
				if (!giver || !source) {
					return;
				}
				SKSE::ModCallbackEvent event{
					RE::BSFixedString{ a_beat.event },
					RE::BSFixedString{ a_beat.text },
					a_beat.timeToThrust,
					giver.get()
				};
				source->SendEvent(&event);
			});
		}

		void Update(const API::AnimationUpdateEvent* a_event)
		{
			// copy everything before returning: the event data is transient
			Receiver receiver;
			auto&    snapshot = receiver.snapshot;
			snapshot.context = static_cast<std::uint32_t>(a_event->context);
			snapshot.anusOpening = a_event->anusOpening;
			snapshot.vaginalOpening = a_event->vaginalOpening;

			// `site` is a third-party enum: range every value against the ones we
			// know, or a future enumerator would reach Papyrus as an ordinal outside
			// the documented table (and a shift past 31 is UB)
			const auto knownSite = [](API::PenetrationSite a_site) {
				const auto value = static_cast<std::uint32_t>(a_site);
				return a_site != API::PenetrationSite::None &&
				       value <= static_cast<std::uint32_t>(API::PenetrationSite::Hands);
			};

			float depth = 0.0f;
			if (a_event->selfInteraction) {
				depth = std::max(depth, a_event->selfInteraction->penetrationDepth);
				if (knownSite(a_event->selfInteraction->site)) {
					snapshot.selfSite = static_cast<std::uint8_t>(a_event->selfInteraction->site);
				}
			}
			if (a_event->actors) {
				float deepestPartner = -1.0f;
				for (std::uint32_t i = 0; i < a_event->actorCount; ++i) {
					const auto& partner = a_event->actors[i];
					depth = std::max(depth, partner.penetrationDepth);
					if (const auto handle = partner.actor.native_handle(); handle != 0) {
						receiver.partners.push_back({ handle, partner.penetrationDepth });
					}
					if (!knownSite(partner.site)) {
						continue;
					}
					snapshot.siteMask |= 1u << static_cast<std::uint32_t>(partner.site);
					// ">" not ">=": ties keep the first partner, so a steady scene does
					// not flip the reported site between equal-depth partners
					if (partner.penetrationDepth > deepestPartner) {
						deepestPartner = partner.penetrationDepth;
						snapshot.site = static_cast<std::uint8_t>(partner.site);
					}
				}
			}
			snapshot.depth = depth;

			const auto key = a_event->receiver.native_handle();
			const auto now = NowSeconds();

			std::vector<Beat> beats;
			{
				std::scoped_lock lock{ g_lock };
				if (a_event->ending) {
					// "Ending is always sent" (the PPA author). A watch on this receiver
					// stays (SLOVE_SFX ends it), but its next run starts fresh
					g_receivers.erase(key);
					for (auto& [giver, watcher] : g_watches) {
						if (watcher.receiver == key) {
							watcher.watch.Reset();
						}
					}
					return;
				}
				auto& stored = g_receivers[key];
				stored = std::move(receiver);
				for (auto& [giver, watcher] : g_watches) {
					if (watcher.receiver != key) {
						continue;
					}
					const auto result = watcher.watch.Feed(OwnDepth(stored, giver), stored.snapshot.depth, now);
					if (result.beat == Core::ThrustDetector::Beat::None) {
						continue;
					}
					const bool impact = result.beat == Core::ThrustDetector::Beat::Impact;
					const float depthNow = watcher.watch.LastDepth();
					Beat beat;
					beat.giver = watcher.giver;
					beat.event = impact ? watcher.impactEvent : watcher.reentryEvent;
					beat.timeToThrust = result.timeToThrust;
					beat.text = impact ?
					                std::format("stroke={:.2f} | depth={:.2f}", result.stroke, depthNow) :
					                std::format("depth={:.2f}", depthNow);
					beats.push_back(std::move(beat));
				}
			}
			for (const auto& beat : beats) {
				SendBeat(beat);
			}
		}

		void __cdecl OnAnimationUpdate(const API::AnimationUpdateEvent* a_event, void*)
		{
			if (!a_event || a_event->apiVersion != API::kVersion) {
				return;
			}
			// never let an exception cross back into PPA
			try {
				Update(a_event);
			} catch (...) {
			}
		}
	}

	void TryConnect()
	{
		if (g_connected.load()) {
			return;
		}

		const HMODULE module = ::GetModuleHandleW(API::kPluginDLL);
		if (!module) {
			logger::info("AccuratePenetration.dll is not loaded: no PPA measurements");
			return;
		}

		const auto getAPI = reinterpret_cast<API::GetAPIFn>(::GetProcAddress(module, API::kGetAPIFunctionNameV1));
		if (!getAPI) {
			logger::warn("AccuratePenetration.dll has no {} export: no PPA measurements", API::kGetAPIFunctionNameV1);
			return;
		}

		g_api = getAPI();
		if (!g_api || g_api->version != API::kVersion || g_api->size < sizeof(API::InterfaceV1) ||
			!g_api->RegisterAnimationUpdateListener) {
			logger::warn("PPA API mismatch (version {}, size {}): no PPA measurements",
				g_api ? g_api->version : 0, g_api ? g_api->size : 0);
			g_api = nullptr;
			return;
		}

		g_listener = g_api->RegisterAnimationUpdateListener(&OnAnimationUpdate, nullptr);
		if (g_listener == 0) {
			logger::warn("PPA listener registration failed: no PPA measurements");
			g_api = nullptr;
			return;
		}

		g_connected.store(true);
		logger::info("PPA connected (API v{})", API::kVersion);
	}

	bool Connected()
	{
		return g_connected.load();
	}

	std::optional<Snapshot> GetFor(RE::Actor* a_receiver)
	{
		const auto key = KeyOf(a_receiver);
		if (key == 0) {
			return std::nullopt;
		}
		std::scoped_lock lock{ g_lock };
		const auto it = g_receivers.find(key);
		if (it == g_receivers.end()) {
			return std::nullopt;
		}
		return it->second.snapshot;
	}

	float PairDepth(RE::Actor* a_giver, RE::Actor* a_receiver)
	{
		const auto key = KeyOf(a_receiver);
		if (key == 0) {
			return 0.0f;
		}
		std::scoped_lock lock{ g_lock };
		const auto it = g_receivers.find(key);
		if (it == g_receivers.end()) {
			return 0.0f;
		}
		const auto own = OwnDepth(it->second, KeyOf(a_giver));
		return own ? *own : it->second.snapshot.depth;
	}

	void Watch(RE::Actor* a_giver, RE::Actor* a_receiver, float a_turn)
	{
		const auto giver = KeyOf(a_giver);
		const auto receiver = KeyOf(a_receiver);
		if (giver == 0 || receiver == 0) {
			return;
		}
		const float turn = std::max(0.1f, a_turn);  // the script's floor too
		std::scoped_lock lock{ g_lock };
		// The SFX loop asks again every tick, so a watch dropped by a game load
		// (Reset) or by another effect's Unwatch comes back within a tick: the
		// same pair again keeps its run, anything else starts a new one.
		if (const auto it = g_watches.find(giver);
			it != g_watches.end() && it->second.receiver == receiver && it->second.watch.Turn() == turn) {
			return;
		}
		Watcher watcher{
			a_giver->GetHandle(),
			receiver,
			Core::ThrustWatch{ turn },
			EventName("SLOVE_PPAImpact", a_giver),
			EventName("SLOVE_PPAReentry", a_giver)
		};
		g_watches.insert_or_assign(giver, std::move(watcher));
	}

	void Unwatch(RE::Actor* a_giver)
	{
		const auto giver = KeyOf(a_giver);
		if (giver == 0) {
			return;
		}
		std::scoped_lock lock{ g_lock };
		g_watches.erase(giver);
	}

	void Reset()
	{
		std::scoped_lock lock{ g_lock };
		g_watches.clear();
		g_receivers.clear();
	}
}
