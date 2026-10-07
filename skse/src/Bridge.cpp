#include "Bridge.h"

#include "Env.h"

namespace Bridge
{
	namespace
	{
		using Clock = std::chrono::steady_clock;

		constexpr auto kConfigFile = "SKSE/Plugins/SLOVE/SLOVE.toml"sv;  // as SLOVE_Config.File() spells it
		constexpr auto kResend = 5s;  // no answer for this long: the call is taken as lost

		std::atomic<bool>          g_dirty{ false };     // AudioUtil's cache is behind the file
		std::atomic<bool>          g_inFlight{ false };  // a reload is queued or running
		std::atomic<std::uint32_t> g_generation{ 0 };    // bumped when the VM resets
		std::atomic<std::int64_t>  g_sentAt{ 0 };        // Clock ticks of the last send
		std::atomic<std::int64_t>  g_dirtySince{ 0 };    // Clock ticks when the debt began

		std::int64_t Now()
		{
			return Clock::now().time_since_epoch().count();
		}

		Clock::duration Since(std::int64_t a_ticks)
		{
			return Clock::duration{ Now() - a_ticks };
		}

		// The answer of a Papyrus call that returns a Bool. Runs on a VM thread, so
		// it touches atomics only.
		class BoolResult : public RE::BSScript::IStackCallbackFunctor
		{
		public:
			explicit BoolResult(std::uint32_t a_generation) :
				_generation(a_generation) {}

			void operator()(RE::BSScript::Variable a_result) override
			{
				if (_generation != g_generation.load()) {
					return;  // from before a load: not about the VM that is running now
				}
				const bool ok = a_result.IsBool() && a_result.GetBool();
				if (!ok) {
					// AudioUtil kept its old cache (it read the file mid-write, or the
					// file does not parse): the debt stands
					g_dirty.store(true);
				} else if (!g_dirty.load()) {
					g_dirtySince.store(0);
				}
				g_inFlight.store(false);
			}

			void SetObject(const RE::BSTSmartPointer<RE::BSScript::Object>&) override {}

		private:
			std::uint32_t _generation;
		};

		void Send()
		{
			const auto* tasks = SKSE::GetTaskInterface();
			if (!tasks) {
				return;
			}
			g_inFlight.store(true);
			g_sentAt.store(Now());
			const auto generation = g_generation.load();
			tasks->AddTask([generation]() {
				auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
				if (!vm || generation != g_generation.load()) {
					g_inFlight.store(false);
					return;
				}
				// the debt is paid by THIS read of the file; a write after this point
				// sets dirty again and is answered by its own reload
				g_dirty.store(false);
				RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback{ new BoolResult(generation) };
				// never deleted here: who owns the arguments after the call is not
				// documented, and a few bytes per reload is the only safe side of that
				auto* args = RE::MakeFunctionArguments(RE::BSFixedString{ kConfigFile });
				if (!vm->DispatchStaticCall("TomlUtil"sv, "Reload"sv, args, callback)) {
					g_dirty.store(true);
					g_inFlight.store(false);
				}
			});
		}

		// SLOVE.toml key -> AudioUtil volume buses. The scripts push these once, at
		// scene start; keep this in step with them (scripts\check-config.ps1 compares
		// the bus names):
		//   SLOVE_Voice.psc     pcvolume -> pc_low, pc_high; partnervolume -> partner_low,
		//                       partner_high; orgasmvolume -> pc_orgasm
		//   SLOVE_NpcScene.psc  npcscenevolume -> npc_low, npc_high
		//   SLOVE_SFX.psc       sfx.volume -> sfx
		// Two keys fall back to another while the file does not hold them
		// (orgasmvolume -> pcvolume, npcscenevolume -> partnervolume), so a change of
		// the fallback then moves their buses as well.
		struct Volume
		{
			std::string_view              key;
			std::vector<std::string_view> buses;
		};

		const std::array<Volume, 5>& Volumes()
		{
			static const std::array<Volume, 5> table{ {
				{ "voice.pcvolume"sv, { "pc_low"sv, "pc_high"sv } },
				{ "voice.partnervolume"sv, { "partner_low"sv, "partner_high"sv } },
				{ "voice.orgasmvolume"sv, { "pc_orgasm"sv } },
				{ "voice.npcscenevolume"sv, { "npc_low"sv, "npc_high"sv } },
				{ "sfx.volume"sv, { "sfx"sv } },
			} };
			return table;
		}

		void SetGroupVolume(std::string_view a_bus, float a_volume)
		{
			const auto* tasks = SKSE::GetTaskInterface();
			if (!tasks) {
				return;
			}
			tasks->AddTask([bus = std::string{ a_bus }, a_volume]() {
				auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
				if (!vm) {
					return;
				}
				RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback;
				auto* args = RE::MakeFunctionArguments(RE::BSFixedString{ bus }, static_cast<float>(a_volume));
				vm->DispatchStaticCall("AudioUtil"sv, "SetGroupVolume"sv, args, callback);
			});
		}
	}

	void RequestReload()
	{
		if (!g_dirty.exchange(true)) {
			std::int64_t none = 0;
			g_dirtySince.compare_exchange_strong(none, Now());
		}
		Pump();
	}

	void Pump()
	{
		if (!g_dirty.load() || !Env::Get().audioUtil) {
			return;  // nothing owed, or nobody to tell (without AudioUtil the scripts read nothing)
		}
		if (g_inFlight.load() && Since(g_sentAt.load()) < kResend) {
			return;
		}
		Send();
	}

	void OnVmReset()
	{
		g_generation.fetch_add(1);
		g_inFlight.store(false);
	}

	bool ReloadPending()
	{
		return Env::Get().audioUtil && (g_dirty.load() || g_inFlight.load());
	}

	float PendingSeconds()
	{
		const auto since = g_dirtySince.load();
		if (!ReloadPending() || since == 0) {
			return 0.0f;
		}
		return std::chrono::duration<float>(Since(since)).count();
	}

	bool IsVolume(std::string_view a_key)
	{
		const auto& table = Volumes();
		return std::any_of(table.begin(), table.end(), [&](const Volume& v) { return v.key == a_key; });
	}

	void PushVolume(std::string_view a_key, std::int64_t a_percent, bool a_orgasmInFile, bool a_npcSceneInFile)
	{
		if (!Env::Get().audioUtil) {
			return;
		}
		const float volume = static_cast<float>(std::clamp<std::int64_t>(a_percent, 0, 100)) / 100.0f;
		const auto  push = [&](std::string_view a_which) {
			for (const auto& entry : Volumes()) {
				if (entry.key == a_which) {
					for (const auto bus : entry.buses) {
						SetGroupVolume(bus, volume);
					}
				}
			}
		};
		push(a_key);
		if (a_key == "voice.pcvolume"sv && !a_orgasmInFile) {
			push("voice.orgasmvolume"sv);
		}
		if (a_key == "voice.partnervolume"sv && !a_npcSceneInFile) {
			push("voice.npcscenevolume"sv);
		}
	}
}
