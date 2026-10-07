#include "Menu.h"

#include "Bridge.h"
#include "Env.h"
#include "Ui.h"
#include "core/Model.h"

#include <cmath>
#include <limits>

// Everything below RenderPage / OnEvent runs inside a callback SKSE Menu Framework
// invoked, on whichever thread it renders from. So it touches the model under
// g_lock, the files next to SLOVE.toml, and ImGui through Ui.h - and nothing of the
// game: every engine and Papyrus call goes through Bridge, onto the SKSE task queue.

namespace Menu
{
	namespace
	{
		using Clock = std::chrono::steady_clock;

		constexpr std::size_t kMaxPages = 16;
		constexpr std::size_t kNone = static_cast<std::size_t>(-1);
		constexpr auto        kReopenGap = 1s;  // no frame drawn for this long: the menu was closed
		constexpr auto        kVolumePush = 100ms;  // a dragged volume slider moves the bus this often
		constexpr float       kSlowReload = 6.0f;  // seconds before an unconfirmed reload is worth a line
		constexpr auto        kRetryFailed = 2s;  // a value the file refused is tried again this often
		constexpr std::size_t kTextCapacity = 4096;  // bytes a text field can hold, terminator included

		struct RowUi
		{
			std::vector<char> text;  // InputText edits in place; sized on first use, text rows only
			std::string       textFor;  // the value the buffer was last filled from
			bool              textInit = false;
			bool              wasActive = false;
			Core::Scalar      pushed;  // the volume last sent to AudioUtil
			Clock::time_point pushedAt{};
			bool              pushInit = false;
			std::uint64_t     drawn = 0;  // the g_frame this row was last drawn in
			Clock::time_point failedAt{};  // when the file last refused this row's value
		};

		std::mutex               g_lock;
		Core::Model              g_model;
		std::vector<RowUi>       g_ui;  // parallel to g_model.Rows()
		std::vector<std::string> g_registered;  // the section each page thunk draws; "*" = every section
		Clock::time_point        g_lastFrame{};
		std::uint64_t            g_frame = 0;  // counts page draws (and menu closes)
		std::vector<std::size_t> g_commits;  // rows to write once this frame's ImGui calls are done
		std::vector<std::size_t> g_adds;  // rows to add to the file (missing keys)
		std::string              g_writeError;
		std::size_t              g_confirmReset = kNone;  // the thunk whose "reset page" awaits a yes
		bool                     g_reloadAsked = false;
		bool                     g_loggedFault = false;

		const Ui::ImVec4 kWarn{ 1.0f, 0.5f, 0.4f, 1.0f };
		const Ui::ImVec4 kHint{ 0.7f, 0.7f, 0.7f, 1.0f };

		void SyncUi()
		{
			g_ui.assign(g_model.Rows().size(), RowUi{});
			g_commits.clear();
			g_adds.clear();
			g_confirmReset = kNone;
		}

		// The menu was closed and is open again: show what is on disk now. A hand
		// edit made in between also has to reach AudioUtil's cache.
		void Reopened()
		{
			const bool changed = g_model.Refresh();
			SyncUi();
			g_writeError.clear();
			// not for a file that does not parse: AudioUtil would refuse it too and
			// keep what it has, so there is nothing to ask for until it is fixed
			if (changed && g_model.Ok()) {
				logger::info("SLOVE.toml changed on disk since it was last read - asking AudioUtil to re-read it");
				Bridge::RequestReload();
			}
		}

		void Colored(const Ui::ImVec4& a_color, const std::string& a_text)
		{
			Ui::PushStyleColor(Ui::ImGuiCol_Text, a_color);
			Ui::TextUnformatted(a_text.c_str());
			Ui::PopStyleColor();
		}

		const char* NeedsText(Core::Needs a_needs)
		{
			switch (a_needs) {
			case Core::Needs::PPlus:
				return "Only does something on SexLab P+ (not on classic SexLab).";
			case Core::Needs::PPlus219:
				return "Only does something on SexLab P+ 2.19 or newer.";
			default:
				return "";
			}
		}

		void DrawTooltip(const Core::Row& a_row, bool a_met)
		{
			if (!Ui::BeginTooltip()) {
				return;
			}
			Ui::PushTextWrapPos(Ui::GetFontSize() * 30.0f);
			if (!a_row.tip.empty()) {
				Ui::TextUnformatted(a_row.tip.c_str());
			}
			if (a_row.shipped) {
				const std::string line = "Default: " + Core::Display(*a_row.shipped);
				Ui::TextUnformatted(line.c_str());
			}
			if (!a_met) {
				Colored(kWarn, NeedsText(a_row.needs));
			}
			if (!a_row.inFile) {
				Colored(kWarn, "Not in your SLOVE.toml. Until you add it the scripts use their own fallback for it, which is often 0 and not the default shown here.");
			}
			if (a_row.failed) {
				Colored(kWarn, "The last change to this setting could not be written.");
			}
			Colored(kHint, a_row.key);
			Ui::PopTextWrapPos();
			Ui::EndTooltip();
		}

		int ToInt(const Core::Scalar& a_value)
		{
			const auto* i = std::get_if<std::int64_t>(&a_value);
			return i ? static_cast<int>(std::clamp<std::int64_t>(*i, std::numeric_limits<int>::min(), std::numeric_limits<int>::max())) : 0;
		}

		// Changed, and worth a write now. A value the file refused is tried again
		// after a pause, not every frame: the cause may pass by itself (another
		// program held the file for a moment) or may not (the file is read-only).
		bool Writable(std::size_t a_index)
		{
			const auto& row = g_model.Rows()[a_index];
			if (!row.Dirty()) {
				return false;
			}
			if (row.failed && Core::Identical(*row.failed, row.edit)) {
				return Clock::now() - g_ui[a_index].failedAt >= kRetryFailed;
			}
			return true;
		}

		// Queue every changed row that was NOT drawn this frame. A drawn row decides
		// for itself, once its widget is let go of; one that is not drawn cannot be
		// mid-edit - its page was switched away from, its group was collapsed or the
		// menu closed - and no later frame is promised to it.
		// a_lastChance: the rows are about to be re-read from disk, so a value the
		// file refused a moment ago is tried once more without waiting.
		void QueueLeftBehind(bool a_lastChance = false)
		{
			for (std::size_t i = 0; i < g_model.Rows().size() && i < g_ui.size(); ++i) {
				if (g_ui[i].drawn != g_frame && (a_lastChance ? g_model.Rows()[i].Dirty() : Writable(i))) {
					g_commits.push_back(i);
				}
			}
		}

		void DrawRow(std::size_t a_index)
		{
			auto&      row = g_model.Rows()[a_index];
			auto&      ui = g_ui[a_index];
			const bool met = Env::Meets(row.needs);
			ui.drawn = g_frame;

			// What the widget shows. An int key someone wrote as a float (60.0) is
			// shown as the whole number it is meant to be; row.edit only changes when
			// the widget does, so nothing is written that the user did not touch.
			const bool   intLike = row.control == Core::Control::Flag || row.control == Core::Control::Int || row.control == Core::Control::Percent;
			Core::Scalar shown = row.edit;
			if (intLike) {
				if (const auto* f = std::get_if<double>(&row.edit)) {
					shown = std::isfinite(*f) ? static_cast<std::int64_t>(std::llround(std::clamp(*f, -2.0e9, 2.0e9))) : std::int64_t{ 0 };
				}
			}
			const auto kind = Core::KindOf(shown);

			std::string label = row.label;
			if (!row.unit.empty() && row.control != Core::Control::Percent) {
				label += " (" + row.unit + ")";
			}

			Ui::PushID(static_cast<int>(a_index));
			if (!met) {
				Ui::PushStyleVar(Ui::ImGuiStyleVar_Alpha, 0.55f);
			}
			Ui::SetNextItemWidth(Ui::GetFontSize() * 11.0f);

			if (kind == Core::Kind::Bool) {
				// a TOML boolean someone added by hand: keep it a boolean
				bool value = std::get<bool>(row.edit);
				if (Ui::Checkbox(label.c_str(), &value)) {
					row.edit = value;
				}
			} else if (row.control == Core::Control::Flag && kind == Core::Kind::Int) {
				bool value = std::get<std::int64_t>(shown) != 0;
				if (Ui::Checkbox(label.c_str(), &value)) {
					row.edit = std::int64_t{ value ? 1 : 0 };  // an int, never true/false: the scripts read flags with GetInt
				}
			} else if (kind == Core::Kind::Int) {
				int value = ToInt(shown);
				bool changed = false;
				if (row.control == Core::Control::Percent) {
					changed = Ui::SliderInt(label.c_str(), &value, 0, 100, "%d%%", Ui::ImGuiSliderFlags_AlwaysClamp);
				} else if (row.min && row.max) {
					changed = Ui::SliderInt(label.c_str(), &value, static_cast<int>(*row.min), static_cast<int>(*row.max), "%d", Ui::ImGuiSliderFlags_AlwaysClamp);
				} else {
					const int step = row.step ? std::max(1, static_cast<int>(*row.step)) : 1;
					changed = Ui::InputInt(label.c_str(), &value, step, step * 10);
				}
				if (changed) {
					if (row.min) {
						value = std::max(value, static_cast<int>(*row.min));
					}
					if (row.max) {
						value = std::min(value, static_cast<int>(*row.max));
					}
					row.edit = static_cast<std::int64_t>(value);
				}
			} else if (kind == Core::Kind::Float) {
				float value = static_cast<float>(std::get<double>(row.edit));
				bool  changed = false;
				if (row.min && row.max) {
					changed = Ui::SliderFloat(label.c_str(), &value, static_cast<float>(*row.min), static_cast<float>(*row.max), "%.2f", Ui::ImGuiSliderFlags_AlwaysClamp);
				} else {
					const float step = row.step ? static_cast<float>(*row.step) : 0.1f;
					changed = Ui::InputFloat(label.c_str(), &value, step, step * 10.0f, "%.2f");
				}
				if (changed) {
					if (row.min) {
						value = std::max(value, static_cast<float>(*row.min));
					}
					if (row.max) {
						value = std::min(value, static_cast<float>(*row.max));
					}
					row.edit = Core::FromFloat(value);  // only on a real edit: an untouched value is never re-rounded
				}
			} else if (std::get<std::string>(row.edit).size() >= kTextCapacity) {
				// longer than the field can hold: editing it here would cut it short
				Ui::TextUnformatted(label.c_str());
				Ui::SameLine();
				Colored(kHint, "(too long to edit here: change it in SLOVE.toml)");
			} else {
				const auto& current = std::get<std::string>(row.edit);
				if (ui.text.size() != kTextCapacity) {
					ui.text.assign(kTextCapacity, '\0');
					ui.textInit = false;
				}
				if (!ui.textInit || (!ui.wasActive && ui.textFor != current)) {
					std::copy(current.begin(), current.end(), ui.text.begin());  // fits: checked above
					ui.text[current.size()] = '\0';
					ui.textFor = current;
					ui.textInit = true;
				}
				Ui::SetNextItemWidth(Ui::GetFontSize() * 22.0f);
				if (Ui::InputText(label.c_str(), ui.text.data(), ui.text.size())) {
					row.edit = std::string{ ui.text.data() };
					ui.textFor = std::get<std::string>(row.edit);
				}
			}

			const bool active = Ui::IsItemActive();
			const bool hovered = Ui::IsItemHovered(Ui::ImGuiHoveredFlags_ForTooltip);
			ui.wasActive = active;
			if (!met) {
				Ui::PopStyleVar();
			}
			if (hovered) {
				DrawTooltip(row, met);
			}

			if (!row.inFile) {
				Ui::SameLine();
				Colored(kWarn, "not in your file");
				Ui::SameLine();
				if (Ui::SmallButton("add")) {
					g_adds.push_back(a_index);
				}
			} else if (row.shipped && !Core::SameValue(row.edit, *row.shipped)) {
				Ui::SameLine();
				if (Ui::SmallButton("reset")) {
					g_model.ResetToDefault({ a_index });
				}
			}
			Ui::PopID();

			// a volume moves its bus while the slider is still held
			if (Bridge::IsVolume(row.key) && Core::KindOf(row.edit) == Core::Kind::Int) {
				const auto now = Clock::now();
				if (!ui.pushInit) {
					ui.pushed = row.edit;
					ui.pushInit = true;
				} else if (!(ui.pushed == row.edit) && now - ui.pushedAt >= kVolumePush) {
					Bridge::PushVolume(row.key, std::get<std::int64_t>(row.edit),
						g_model.InFile("voice.orgasmvolume"), g_model.InFile("voice.npcscenevolume"));
					ui.pushed = row.edit;
					ui.pushedAt = now;
				}
			}

			// write once the widget is let go of: a slider on release, a typed number
			// or text on leaving the field, a checkbox or step button at once. A value
			// the file refused is not retried until it changes.
			if (!active && Writable(a_index)) {
				g_commits.push_back(a_index);
			}
		}

		void DrawPage(std::size_t a_page)
		{
			auto& page = g_model.Pages()[a_page];
			Ui::PushID(static_cast<int>(1000 + a_page));
			if (!page.note.empty()) {
				Colored(kHint, page.note);
			}
			for (const auto& group : page.groups) {
				if (Ui::CollapsingHeader(group.title.c_str(), Ui::ImGuiTreeNodeFlags_DefaultOpen)) {
					for (const auto index : group.rows) {
						DrawRow(index);
					}
					Ui::Spacing();
				}
			}
			Ui::PopID();
		}

		std::vector<std::size_t> RowsOf(const std::vector<std::size_t>& a_pages)
		{
			std::vector<std::size_t> rows;
			for (const auto page : a_pages) {
				for (const auto& group : g_model.Pages()[page].groups) {
					rows.insert(rows.end(), group.rows.begin(), group.rows.end());
				}
			}
			return rows;
		}

		void DrawStatus()
		{
			const auto& env = Env::Get();
			Ui::PushTextWrapPos(0.0f);
			Ui::TextUnformatted("Saved to SLOVE.toml as you change them. They apply from the next scene; volumes at once.");
			if (!env.audioUtil) {
				Colored(kWarn, "AudioUtil is not loaded. SLO VE reads its settings through AudioUtil, so nothing set here takes effect until it is installed.");
			}
			if (!g_writeError.empty()) {
				Colored(kWarn, g_writeError);
			}
			if (Bridge::PendingSeconds() > kSlowReload) {
				Colored(kWarn, "AudioUtil has not confirmed re-reading the file yet. Your changes ARE saved; they are picked up after a game load, or at once with the console command: sloveconfig reload");
			}
			if (g_model.Ok() && !g_model.HasDefaults()) {
				Colored(kHint, "SLOVE.defaults.toml is missing, so default values and reset are unavailable.");
			}
			Ui::PopTextWrapPos();
			Ui::Separator();
		}

		void DrawFooter(std::size_t a_thunk, const std::vector<std::size_t>& a_pages)
		{
			Ui::Separator();
			Ui::PushID(static_cast<int>(5000 + a_thunk));
			const auto  rows = RowsOf(a_pages);
			std::size_t missing = 0;
			std::size_t changed = 0;
			for (const auto index : rows) {
				const auto& row = g_model.Rows()[index];
				missing += row.inFile ? 0 : 1;
				changed += row.shipped && !Core::SameValue(row.edit, *row.shipped) ? 1 : 0;
			}
			if (g_confirmReset == a_thunk) {
				const std::string ask = "Reset " + std::to_string(changed) + " setting(s) on this page to their defaults?";
				Colored(kWarn, ask);
				Ui::SameLine();
				if (Ui::SmallButton("Yes, reset")) {
					g_model.ResetToDefault(rows);
					g_confirmReset = kNone;
				}
				Ui::SameLine();
				if (Ui::SmallButton("Cancel")) {
					g_confirmReset = kNone;
				}
			} else if (changed > 0) {
				if (Ui::Button("Reset this page to defaults")) {
					g_confirmReset = a_thunk;
				}
				Ui::SameLine();
			}
			if (missing > 0) {
				const std::string label = "Add " + std::to_string(missing) + " missing setting(s) to my file";
				if (Ui::Button(label.c_str())) {
					for (const auto index : rows) {
						if (!g_model.Rows()[index].inFile) {
							g_adds.push_back(index);
						}
					}
				}
				Ui::SameLine();
			}
			if (Ui::Button("Reload from disk")) {
				g_reloadAsked = true;
			}
			Ui::PopID();
		}

		// All file I/O of the frame, before its first or after its last ImGui call.
		// False when a change could not be written.
		bool Flush()
		{
			const auto before = g_model.Writes();
			bool       ok = true;
			if (!g_adds.empty()) {
				ok = g_model.Commit(g_adds, true) && ok;
			}
			if (!g_commits.empty()) {
				ok = g_model.Commit(g_commits) && ok;
			}
			if (g_model.Writes() != before) {
				Bridge::RequestReload();
			}
			if (!ok) {
				// remember when, per row: Writable tries them again after a pause
				const auto now = Clock::now();
				for (const auto* list : { &g_adds, &g_commits }) {
					for (const auto index : *list) {
						if (index < g_model.Rows().size() && index < g_ui.size() && g_model.Rows()[index].failed) {
							g_ui[index].failedAt = now;
						}
					}
				}
				if (g_writeError.empty()) {
					logger::warn("a change could not be written to SLOVE.toml");
				}
				g_writeError = "A change could not be written to SLOVE.toml (is the file read-only, in use by another program, or broken by a hand edit?). It is NOT saved yet; the menu keeps trying while it is open.";
			} else if (g_model.Writes() != before) {
				g_writeError.clear();
			}
			g_commits.clear();
			g_adds.clear();
			if (g_reloadAsked) {
				g_reloadAsked = false;
				Reopened();
				if (g_model.Ok()) {
					Bridge::RequestReload();  // asked for by hand: bring AudioUtil in step too, whatever we think it has
				}
			}
			return ok;
		}

		void RenderPage(std::size_t a_thunk) noexcept
		{
			try {
				std::scoped_lock lock{ g_lock };
				const auto       now = Clock::now();
				++g_frame;
				if (now - g_lastFrame > kReopenGap) {
					// an edit from before the gap goes to the file first: the
					// re-read below would otherwise replace it with what is on disk
					bool lost = false;
					if (g_model.Ok()) {
						QueueLeftBehind(true);
						lost = !Flush();
					}
					Reopened();
					if (lost) {
						// the re-read dropped it, so say so instead of showing nothing
						g_writeError = "A change made before the menu was last closed could not be written to SLOVE.toml (is the file read-only?) and was dropped.";
					}
				}
				g_lastFrame = now;

				DrawStatus();

				std::vector<std::size_t> pages;
				if (g_model.Ok() && a_thunk < g_registered.size()) {
					const bool last = a_thunk + 1 == g_registered.size();
					for (std::size_t i = 0; i < g_model.Pages().size(); ++i) {
						const auto& section = g_model.Pages()[i].section;
						const bool  registered = std::find(g_registered.begin(), g_registered.end(), section) != g_registered.end();
						// a page shows its own section; the last page also takes any
						// section that appeared after the pages were registered
						if (g_registered[a_thunk] == "*" || g_registered[a_thunk] == section || (last && !registered)) {
							pages.push_back(i);
						}
					}
				}
				if (!g_model.Ok()) {
					Ui::PushTextWrapPos(0.0f);
					Colored(kWarn, "SLOVE.toml cannot be used: " + g_model.Error());
					Ui::TextUnformatted("Nothing is written while the file is in this state. Fix it in a text editor, then press Reload from disk.");
					Ui::PopTextWrapPos();
				}
				for (const auto page : pages) {
					if (pages.size() > 1) {
						Colored(kHint, g_model.Pages()[page].title);
					}
					DrawPage(page);
				}
				DrawFooter(a_thunk, pages);

				if (g_model.Ok()) {
					QueueLeftBehind();
				}
				Flush();
				Bridge::Pump();
			} catch (const std::exception& e) {
				if (!g_loggedFault) {
					g_loggedFault = true;
					logger::error("menu page failed: {}", e.what());
				}
			} catch (...) {
				if (!g_loggedFault) {
					g_loggedFault = true;
					logger::error("menu page failed");
				}
			}
		}

		template <std::size_t I>
		void __stdcall PageThunk()
		{
			RenderPage(I);
		}

		template <std::size_t... I>
		constexpr auto MakeThunks(std::index_sequence<I...>)
		{
			return std::array<SKSEMenuFramework::Model::RenderFunction, sizeof...(I)>{ &PageThunk<I>... };
		}

		constexpr auto kThunks = MakeThunks(std::make_index_sequence<kMaxPages>{});

		// The framework's menu opened or closed. Closing with a field still being
		// typed in never draws the frame that would have written it, so write here.
		void __stdcall OnEvent(SKSEMenuFramework::Model::EventType a_event) noexcept
		{
			try {
				if (a_event != SKSEMenuFramework::Model::EventType::kCloseMenu) {
					return;
				}
				std::scoped_lock lock{ g_lock };
				if (!g_model.Ok()) {
					return;
				}
				++g_frame;  // nothing is drawn any more: every changed row is left behind
				QueueLeftBehind();
				Flush();
				Bridge::Pump();
			} catch (...) {
			}
		}
	}

	void Register()
	{
		const auto& env = Env::Get();
		if (!env.frameworkOk) {
			logger::info("Menu disabled: {}. SLO VE itself is unaffected - edit SLOVE.toml by hand.", env.frameworkWhy);
			return;
		}
		try {
			std::scoped_lock lock{ g_lock };
			g_model.Load(env.configDir);
			SyncUi();
			if (g_model.Ok()) {
				logger::info("SLOVE.toml: {} settings on {} page(s). Schema: {}. Defaults: {}.",
					g_model.Rows().size(), g_model.Pages().size(),
					g_model.SchemaError().empty() ? "loaded" : g_model.SchemaError(),
					g_model.HasDefaults() ? "loaded" : "missing");
			} else {
				logger::warn("SLOVE.toml cannot be used: {}", g_model.Error());
			}

			SKSEMenuFramework::SetSection("SLO VE");
			if (!g_model.Ok() || g_model.Pages().empty()) {
				// nothing to name pages after yet: one page that shows the problem,
				// and every section once the file is fixed and reloaded
				g_registered = { "*" };
				SKSEMenuFramework::AddSectionItem("Settings", kThunks[0]);
			} else {
				for (std::size_t i = 0; i < g_model.Pages().size() && i < kMaxPages; ++i) {
					g_registered.push_back(g_model.Pages()[i].section);
					SKSEMenuFramework::AddSectionItem(g_model.Pages()[i].title, kThunks[i]);
				}
			}
			SKSEMenuFramework::AddEvent(&OnEvent, 0.0f);  // lives as long as the game
			logger::info("Menu registered: section \"SLO VE\", {} page(s).", g_registered.size());
		} catch (const std::exception& e) {
			logger::error("menu registration failed: {}", e.what());
		} catch (...) {
			logger::error("menu registration failed");
		}
	}
}
