#include "Bridge.h"
#include "Env.h"
#include "Menu.h"
#include "PPA.h"
#include "Papyrus.h"

#include <spdlog/sinks/basic_file_sink.h>
#include <spdlog/sinks/msvc_sink.h>

using namespace SKSE;

// SLOVE.dll - the natives the SLO VE scripts call (the label engine's classifier
// and SLO VE's own Accurate Penetration bridge, see Papyrus.h) and the optional
// in-game settings menu. Nothing in here may take the game down: no
// report_and_fail, and a step that fails only switches its own feature off.

namespace
{
	const LoadInterface* g_skse = nullptr;

	bool InitializeLogging()
	{
		auto path = log::log_directory();
		if (!path) {
			return false;
		}
		*path /= PluginDeclaration::GetSingleton()->GetName();
		*path += L".log";

		std::shared_ptr<spdlog::logger> logger;
		if (IsDebuggerPresent()) {
			logger = std::make_shared<spdlog::logger>(
				"Global", std::make_shared<spdlog::sinks::msvc_sink_mt>());
		} else {
			logger = std::make_shared<spdlog::logger>(
				"Global", std::make_shared<spdlog::sinks::basic_file_sink_mt>(path->string(), true));
		}
		logger->set_level(spdlog::level::info);
		logger->flush_on(spdlog::level::info);

		spdlog::set_default_logger(std::move(logger));
		spdlog::set_pattern("[%Y-%m-%d %H:%M:%S.%e] [%l] %v");
		return true;
	}

	void OnMessage(MessagingInterface::Message* a_msg)
	{
		try {
			switch (a_msg->type) {
			case MessagingInterface::kDataLoaded:
				// every SKSE plugin is loaded by now: what is not here will not come
				Env::Detect(g_skse);
				PPA::TryConnect();  // on the main thread, where PPA wants its listeners registered
				Menu::Register();
				break;
			case MessagingInterface::kPreLoadGame:
				Bridge::OnVmReset();
				PPA::Reset();
				break;
			case MessagingInterface::kPostLoadGame:
				// a reload asked for before the load went down with the old VM
				Bridge::OnVmReset();
				Bridge::Pump();
				break;
			case MessagingInterface::kNewGame:
				Bridge::OnVmReset();
				Bridge::Pump();
				PPA::Reset();
				break;
			default:
				break;
			}
		} catch (...) {
			log::error("message {} failed", a_msg ? a_msg->type : 0);
		}
	}
}

SKSEPluginLoad(const LoadInterface* a_skse)
{
	try {
		InitializeLogging();
	} catch (...) {
		// no log is not a reason to refuse to load
	}

	const auto* plugin = PluginDeclaration::GetSingleton();
	log::info("{} v{} is loading...", plugin->GetName(), plugin->GetVersion());

	// false: SKSE::Init would otherwise set up a logger of its own on top of ours,
	// and that one throws inside a noexcept function when the log cannot be created
	Init(a_skse, false);
	g_skse = a_skse;

	if (const auto* papyrus = GetPapyrusInterface(); !papyrus || !papyrus->Register(Papyrus::Register)) {
		log::error("Papyrus natives could not be registered: the SLO VE scripts will log unbound native calls");
	}

	if (const auto* messaging = GetMessagingInterface()) {
		messaging->RegisterListener(OnMessage);
	}

	log::info("{} loaded.", plugin->GetName());
	return true;
}
