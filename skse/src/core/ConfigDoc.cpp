#include "core/ConfigDoc.h"

#include "core/TomlEdit.h"

#include <algorithm>
#include <cstdlib>
#include <format>
#include <fstream>
#include <iterator>
#include <sstream>

#ifndef WIN32_LEAN_AND_MEAN
#	define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#	define NOMINMAX
#endif
#include <windows.h>

namespace Core
{
	namespace
	{
		// a bare TOML key: the only kind TomlEdit can address by dotted path
		bool IsBareKey(std::string_view a_key)
		{
			if (a_key.empty()) {
				return false;
			}
			return std::all_of(a_key.begin(), a_key.end(), [](unsigned char c) {
				return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == '-';
			});
		}

		struct SectionAt
		{
			std::uint32_t line;
			std::string   path;
		};

		void Collect(const toml::table& a_table, const std::string& a_prefix,
			std::vector<Entry>& a_entries, std::vector<SectionAt>& a_sections)
		{
			for (auto&& [key, node] : a_table) {
				const std::string name{ key.str() };
				if (!IsBareKey(name)) {
					continue;  // quoted or dotted key: shown nowhere, never written
				}
				const std::string path = a_prefix.empty() ? name : a_prefix + "." + name;
				if (const auto* table = node.as_table()) {
					if (!table->is_inline()) {
						a_sections.push_back({ table->source().begin.line, path });
						Collect(*table, path, a_entries, a_sections);
					}
					continue;
				}
				Entry entry;
				entry.key = path;
				entry.section = a_prefix;
				entry.name = name;
				entry.line = node.source().begin.line;
				if (const auto* i = node.as_integer()) {
					entry.value = i->get();
				} else if (const auto* f = node.as_floating_point()) {
					entry.value = f->get();
				} else if (const auto* s = node.as_string()) {
					entry.value = s->get();
				} else if (const auto* b = node.as_boolean()) {
					entry.value = b->get();
				} else {
					continue;  // arrays, dates: not editable here
				}
				a_entries.push_back(std::move(entry));
			}
		}

		// true when every line break in the text is CRLF (and there is at least one)
		bool IsCrlf(std::string_view a_text)
		{
			bool any = false;
			for (std::size_t i = 0; i < a_text.size(); ++i) {
				if (a_text[i] == '\n') {
					if (i == 0 || a_text[i - 1] != '\r') {
						return false;
					}
					any = true;
				}
			}
			return any;
		}

		// TomlEdit inserts a new key line with a bare LF; in a CRLF file give it
		// the file's own ending instead of leaving one odd line behind
		std::string LfToCrlf(const std::string& a_text)
		{
			std::string out;
			out.reserve(a_text.size() + 16);
			for (std::size_t i = 0; i < a_text.size(); ++i) {
				if (a_text[i] == '\n' && (i == 0 || a_text[i - 1] != '\r')) {
					out += '\r';
				}
				out += a_text[i];
			}
			return out;
		}
	}

	Kind KindOf(const Scalar& a_value)
	{
		if (std::holds_alternative<std::int64_t>(a_value)) {
			return Kind::Int;
		}
		if (std::holds_alternative<double>(a_value)) {
			return Kind::Float;
		}
		if (std::holds_alternative<std::string>(a_value)) {
			return Kind::String;
		}
		return Kind::Bool;
	}

	std::string Literal(const Scalar& a_value)
	{
		return std::visit([](const auto& v) { return TomlEdit::Literal(v); }, a_value);
	}

	std::string Display(const Scalar& a_value)
	{
		if (const auto* s = std::get_if<std::string>(&a_value)) {
			return s->empty() ? std::string{ "(empty)" } : *s;
		}
		return Literal(a_value);
	}

	bool SameValue(const Scalar& a_lhs, const Scalar& a_rhs)
	{
		const auto number = [](const Scalar& v, double& out) {
			if (const auto* i = std::get_if<std::int64_t>(&v)) {
				out = static_cast<double>(*i);
				return true;
			}
			if (const auto* f = std::get_if<double>(&v)) {
				out = *f;
				return true;
			}
			return false;
		};
		double a = 0.0;
		double b = 0.0;
		if (number(a_lhs, a) && number(a_rhs, b)) {
			return a == b;
		}
		return a_lhs == a_rhs;
	}

	double FromFloat(float a_value)
	{
		return std::strtod(std::format("{}", a_value).c_str(), nullptr);
	}

	bool ConfigDoc::Load(const std::filesystem::path& a_file)
	{
		_file = a_file;
		_text.clear();
		std::ifstream in{ a_file, std::ios::binary };
		if (!in) {
			_ok = false;
			_entries.clear();
			_sections.clear();
			_error = "the file cannot be read";
			return false;
		}
		_text.assign(std::istreambuf_iterator<char>{ in }, std::istreambuf_iterator<char>{});
		return Parse();
	}

	bool ConfigDoc::LoadText(std::string a_text)
	{
		_text = std::move(a_text);
		return Parse();
	}

	bool ConfigDoc::Parse()
	{
		_entries.clear();
		_sections.clear();
		_error.clear();
		_ok = false;
		try {
			const auto table = toml::parse(_text);
			std::vector<SectionAt> sections;
			Collect(table, {}, _entries, sections);
			std::stable_sort(_entries.begin(), _entries.end(),
				[](const Entry& a, const Entry& b) { return a.line < b.line; });
			std::stable_sort(sections.begin(), sections.end(),
				[](const SectionAt& a, const SectionAt& b) { return a.line < b.line; });
			for (auto& section : sections) {
				_sections.push_back(std::move(section.path));
			}
			_ok = true;
		} catch (const toml::parse_error& e) {
			std::ostringstream oss;
			oss << e.description() << " (line " << e.source().begin.line << ")";
			_error = oss.str();
		} catch (...) {
			_error = "the file does not parse as TOML";
		}
		return _ok;
	}

	const Entry* ConfigDoc::Find(std::string_view a_key) const
	{
		const auto it = std::find_if(_entries.begin(), _entries.end(),
			[&](const Entry& e) { return e.key == a_key; });
		return it != _entries.end() ? &*it : nullptr;
	}

	bool ConfigDoc::Apply(const std::vector<Edit>& a_edits)
	{
		if (!_ok) {
			return false;
		}
		const bool crlf = IsCrlf(_text);
		std::string text = _text;
		for (const auto& [key, value] : a_edits) {
			auto edited = TomlEdit::SetInText(text, key, Literal(value));
			if (!edited) {
				return false;  // _text untouched
			}
			text = std::move(*edited);
		}
		if (crlf) {
			text = LfToCrlf(text);
		}
		const std::string before = std::move(_text);
		_text = std::move(text);
		if (!Parse()) {
			_text = before;  // cannot happen after TomlEdit's own validation; stay safe
			Parse();
			return false;
		}
		return true;
	}

	bool ConfigDoc::Save()
	{
		if (!_ok || _file.empty()) {
			return false;
		}
		// OPEN_ALWAYS: under Mod Organizer an existing file is opened where it
		// lives (the mod folder); only a missing one is created in Overwrite
		HANDLE file = INVALID_HANDLE_VALUE;
		for (int attempt = 0; attempt < 10; ++attempt) {
			file = ::CreateFileW(_file.c_str(), GENERIC_WRITE, 0, nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
			if (file != INVALID_HANDLE_VALUE || ::GetLastError() != ERROR_SHARING_VIOLATION) {
				break;
			}
			::Sleep(2);  // someone is reading it right now
		}
		if (file == INVALID_HANDLE_VALUE) {
			return false;
		}
		// write from the start, then cut the tail: never an empty file on disk
		bool ok = true;
		std::size_t done = 0;
		while (ok && done < _text.size()) {
			const auto  chunk = static_cast<DWORD>(std::min<std::size_t>(_text.size() - done, 1u << 20));
			DWORD       written = 0;
			ok = ::WriteFile(file, _text.data() + done, chunk, &written, nullptr) != 0 && written > 0;
			done += written;
		}
		ok = ok && ::SetEndOfFile(file) != 0;
		::CloseHandle(file);
		return ok;
	}
}
