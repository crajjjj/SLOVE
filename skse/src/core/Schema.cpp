#include "core/Schema.h"

#include <toml++/toml.hpp>

#include <fstream>
#include <iterator>
#include <sstream>

namespace Core
{
	namespace
	{
		std::string Str(const toml::table& a_table, std::string_view a_key)
		{
			if (const auto value = a_table[a_key].value<std::string>()) {
				return *value;
			}
			return {};
		}

		// min / max / step may be written as an int or a float
		std::optional<double> Num(const toml::table& a_table, std::string_view a_key)
		{
			return a_table[a_key].value<double>();
		}

		Control ParseControl(std::string_view a_name)
		{
			if (a_name == "flag") {
				return Control::Flag;
			}
			if (a_name == "int") {
				return Control::Int;
			}
			if (a_name == "percent") {
				return Control::Percent;
			}
			if (a_name == "float") {
				return Control::Float;
			}
			if (a_name == "text") {
				return Control::Text;
			}
			return Control::Auto;  // unknown word: fall back to the value's type
		}

		Needs ParseNeeds(std::string_view a_name)
		{
			if (a_name == "pplus") {
				return Needs::PPlus;
			}
			if (a_name == "pplus219") {
				return Needs::PPlus219;
			}
			return Needs::Nothing;
		}
	}

	const char* ControlName(Control a_control)
	{
		switch (a_control) {
		case Control::Flag:
			return "flag";
		case Control::Int:
			return "int";
		case Control::Percent:
			return "percent";
		case Control::Float:
			return "float";
		case Control::Text:
			return "text";
		default:
			return "auto";
		}
	}

	bool Schema::Load(const std::filesystem::path& a_file)
	{
		std::ifstream in{ a_file, std::ios::binary };
		if (!in) {
			_pages.clear();
			_settings.clear();
			_byKey.clear();
			_error = "the file cannot be read";
			return false;
		}
		const std::string text{ std::istreambuf_iterator<char>{ in }, std::istreambuf_iterator<char>{} };
		return LoadText(text);
	}

	bool Schema::LoadText(std::string_view a_text)
	{
		_pages.clear();
		_settings.clear();
		_byKey.clear();
		_error.clear();
		try {
			const auto root = toml::parse(a_text);
			if (const auto* pages = root["page"].as_array()) {
				for (const auto& node : *pages) {
					const auto* table = node.as_table();
					if (!table) {
						continue;
					}
					PageSpec page;
					page.section = Str(*table, "section");
					page.title = Str(*table, "title");
					page.note = Str(*table, "note");
					if (page.section.empty()) {
						continue;
					}
					if (page.title.empty()) {
						page.title = page.section;
					}
					_pages.push_back(std::move(page));
				}
			}
			if (const auto* settings = root["setting"].as_array()) {
				for (const auto& node : *settings) {
					const auto* table = node.as_table();
					if (!table) {
						continue;
					}
					SettingSpec spec;
					spec.key = Str(*table, "key");
					if (spec.key.empty() || _byKey.contains(spec.key)) {
						continue;  // the first entry for a key wins
					}
					spec.group = Str(*table, "group");
					spec.label = Str(*table, "label");
					spec.tip = Str(*table, "tip");
					spec.unit = Str(*table, "unit");
					spec.control = ParseControl(Str(*table, "control"));
					spec.needs = ParseNeeds(Str(*table, "requires"));
					spec.min = Num(*table, "min");
					spec.max = Num(*table, "max");
					spec.step = Num(*table, "step");
					_byKey.emplace(spec.key, _settings.size());
					_settings.push_back(std::move(spec));
				}
			}
			return true;
		} catch (const toml::parse_error& e) {
			std::ostringstream oss;
			oss << e.description() << " (line " << e.source().begin.line << ")";
			_error = oss.str();
		} catch (...) {
			_error = "the file does not parse as TOML";
		}
		_pages.clear();
		_settings.clear();
		_byKey.clear();
		return false;
	}

	const SettingSpec* Schema::Find(std::string_view a_key) const
	{
		const auto it = _byKey.find(std::string{ a_key });
		return it != _byKey.end() ? &_settings[it->second] : nullptr;
	}
}
