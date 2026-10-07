#pragma once

// SLOVE_Menu.toml: how the menu presents each SLOVE.toml key (page, group, label,
// tooltip, control). Presentation only - it holds no values and no defaults, and
// the menu works without it (every key then renders as a plain field).

#include <filesystem>
#include <optional>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

namespace Core
{
	enum class Control
	{
		Auto,     // not said: pick from the value's TOML type
		Flag,     // int 0/1 as a checkbox
		Int,
		Percent,  // int 0..100 as a slider
		Float,
		Text
	};

	// "requires" in the schema: the setting only does something on these SexLab
	// builds. A hint for the menu (it dims the row), never a lock.
	enum class Needs
	{
		Nothing,
		PPlus,     // any SexLab P+
		PPlus219   // SexLab P+ 2.19 or newer (the contact-detection API)
	};

	struct SettingSpec
	{
		std::string           key;
		std::string           group;
		std::string           label;
		std::string           tip;
		std::string           unit;  // shown after the number, e.g. "%" or "s"
		Control               control = Control::Auto;
		Needs                 needs = Needs::Nothing;
		std::optional<double> min;
		std::optional<double> max;
		std::optional<double> step;
	};

	struct PageSpec
	{
		std::string section;  // the [table] of SLOVE.toml this page edits
		std::string title;
		std::string note;  // one line under the title, optional
	};

	class Schema
	{
	public:
		// False (Error() says why) when the file is missing or does not parse. The
		// schema is then empty, which is a valid state: nothing is annotated.
		bool Load(const std::filesystem::path& a_file);
		bool LoadText(std::string_view a_text);

		const std::string&              Error() const { return _error; }
		const std::vector<PageSpec>&    Pages() const { return _pages; }
		const std::vector<SettingSpec>& Settings() const { return _settings; }  // file order
		const SettingSpec*              Find(std::string_view a_key) const;

	private:
		std::vector<PageSpec>                        _pages;
		std::vector<SettingSpec>                     _settings;
		std::unordered_map<std::string, std::size_t> _byKey;
		std::string                                  _error;
	};

	const char* ControlName(Control a_control);
}
