#include "core/ConfigDoc.h"

#include "core/TomlEdit.h"

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <format>
#include <fstream>
#include <iterator>
#include <optional>
#include <sstream>
#include <unordered_set>

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
					// an inline table (milk = { enable = 0 }) holds settings like any
					// other: hiding them would show the key as missing while the
					// writer can still reach it
					a_sections.push_back({ table->source().begin.line, path });
					Collect(*table, path, a_entries, a_sections);
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

		// Byte offset of a toml++ source position. toml++ counts columns in code
		// points and does not count a byte order mark.
		std::optional<std::size_t> OffsetOf(std::string_view a_text, std::uint32_t a_line, std::uint32_t a_column)
		{
			if (a_line == 0 || a_column == 0) {
				return std::nullopt;
			}
			std::size_t pos = a_text.starts_with("\xEF\xBB\xBF") ? 3 : 0;
			for (std::uint32_t line = 1; line < a_line; ++line) {
				const auto newline = a_text.find('\n', pos);
				if (newline == std::string_view::npos) {
					return std::nullopt;
				}
				pos = newline + 1;
			}
			for (std::uint32_t column = 1; column < a_column; ++column) {
				if (pos >= a_text.size()) {
					return std::nullopt;
				}
				++pos;
				while (pos < a_text.size() && (static_cast<unsigned char>(a_text[pos]) & 0xC0) == 0x80) {
					++pos;  // the rest of a multi-byte character
				}
			}
			return pos;
		}

		// TomlEdit maps a column straight to a byte, so on a line that holds
		// non-ASCII text before the value's end (a plugin name in ahegaoitems) its
		// splice comes out short and its own validation refuses the edit. The same
		// splice with the columns counted as toml++ counts them, under the same
		// guarantee: the result parses and the key reads back as exactly this.
		std::optional<std::string> ReplaceByCodePoints(const std::string& a_text, const std::string& a_key, const std::string& a_literal)
		{
			try {
				const auto table = toml::parse(a_text);
				const auto node = table.at_path(a_key);
				if (!node || !node.node()->is_value()) {
					return std::nullopt;
				}
				const auto& source = node.node()->source();
				const auto  begin = OffsetOf(a_text, source.begin.line, source.begin.column);
				const auto  end = OffsetOf(a_text, source.end.line, source.end.column);
				if (!begin || !end || *end < *begin) {
					return std::nullopt;
				}
				std::string edited = a_text.substr(0, *begin) + a_literal + a_text.substr(*end);
				const auto  check = toml::parse(edited);
				if (TomlEdit::detail::RoundTrip(check, a_key) != a_literal) {
					return std::nullopt;
				}
				return edited;
			} catch (...) {
				return std::nullopt;
			}
		}

		// One edit into the text: TomlEdit first (the splice AudioUtil's own writer
		// makes), the code-point variant only where TomlEdit says no.
		std::optional<std::string> Splice(const std::string& a_text, const Edit& a_edit)
		{
			const auto literal = Literal(a_edit.value);
			if (auto edited = TomlEdit::SetInText(a_text, a_edit.key, literal)) {
				return edited;
			}
			return ReplaceByCodePoints(a_text, a_edit.key, literal);
		}

		// Exclusive: while we hold the file nobody else has it open, so nobody is
		// half-way through writing it and nobody reads it half-written. Whoever is
		// reading it right now (AudioUtil re-parsing, a virus scanner after the last
		// save) is waited out for a moment.
		HANDLE OpenExclusive(const std::filesystem::path& a_file, DWORD a_access, DWORD a_disposition)
		{
			HANDLE file = INVALID_HANDLE_VALUE;
			for (int attempt = 0; attempt < 60; ++attempt) {
				file = ::CreateFileW(a_file.c_str(), a_access, 0, nullptr, a_disposition, FILE_ATTRIBUTE_NORMAL, nullptr);
				if (file != INVALID_HANDLE_VALUE || ::GetLastError() != ERROR_SHARING_VIOLATION) {
					break;
				}
				::Sleep(5);
			}
			return file;
		}

		bool ReadFrom(HANDLE a_file, std::string& a_out)
		{
			LARGE_INTEGER size{};
			if (!::GetFileSizeEx(a_file, &size) || size.QuadPart < 0 || size.QuadPart > (16ll << 20)) {
				return false;  // a config of 16 MB is not a config
			}
			a_out.resize(static_cast<std::size_t>(size.QuadPart));
			std::size_t done = 0;
			while (done < a_out.size()) {
				DWORD      got = 0;
				const auto chunk = static_cast<DWORD>(std::min<std::size_t>(a_out.size() - done, 1u << 20));
				if (!::ReadFile(a_file, a_out.data() + done, chunk, &got, nullptr) || got == 0) {
					return false;
				}
				done += got;
			}
			return true;
		}

		// from the start, then cut the tail: the file is never empty on the way
		bool WriteTo(HANDLE a_file, std::string_view a_text)
		{
			if (!::SetFilePointerEx(a_file, LARGE_INTEGER{}, nullptr, FILE_BEGIN)) {
				return false;
			}
			std::size_t done = 0;
			while (done < a_text.size()) {
				DWORD      written = 0;
				const auto chunk = static_cast<DWORD>(std::min<std::size_t>(a_text.size() - done, 1u << 20));
				if (!::WriteFile(a_file, a_text.data() + done, chunk, &written, nullptr) || written == 0) {
					return false;
				}
				done += written;
			}
			return ::SetEndOfFile(a_file) != 0;
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

	bool Identical(const Scalar& a_lhs, const Scalar& a_rhs)
	{
		const auto* a = std::get_if<double>(&a_lhs);
		const auto* b = std::get_if<double>(&a_rhs);
		if (a && b && std::isnan(*a) && std::isnan(*b)) {
			return true;
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
		for (const auto& edit : a_edits) {
			auto edited = Splice(text, edit);
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

	bool ConfigDoc::Rewrite(const std::filesystem::path& a_file, const std::vector<Edit>& a_edits, std::vector<Outcome>& a_outcomes)
	{
		a_outcomes.assign(a_edits.size(), Outcome::Refused);
		_file = a_file;
		_text.clear();
		_entries.clear();
		_sections.clear();
		_ok = false;

		// OPEN_EXISTING: there is a file to change, or there is nothing to do.
		// Under Mod Organizer an existing file is opened where it lives.
		const HANDLE file = OpenExclusive(a_file, GENERIC_READ | GENERIC_WRITE, OPEN_EXISTING);
		if (file == INVALID_HANDLE_VALUE) {
			_error = "the file cannot be opened for writing (read-only, missing, or held open by another program)";
			return false;
		}
		struct Closer
		{
			HANDLE handle;
			~Closer() { ::CloseHandle(handle); }
		} closer{ file };

		std::string original;
		if (!ReadFrom(file, original)) {
			_error = "the file cannot be read";
			return false;
		}
		_text = original;
		if (!Parse()) {
			return false;  // never "fix" a file the user broke; Parse said why
		}

		const std::vector<Entry>        before = _entries;
		const bool                      crlf = IsCrlf(_text);
		std::string                     text = _text;
		std::unordered_set<std::string> written;
		for (std::size_t i = 0; i < a_edits.size(); ++i) {
			const auto& edit = a_edits[i];
			if (edit.ifMissing && Find(edit.key)) {
				a_outcomes[i] = Outcome::Kept;
				continue;
			}
			if (auto edited = Splice(text, edit)) {
				text = std::move(*edited);
				a_outcomes[i] = Outcome::Written;
				written.insert(edit.key);
			}
		}
		if (written.empty()) {
			return true;  // nothing to write; this document is the file as it stands
		}
		if (crlf) {
			text = LfToCrlf(text);
		}

		const auto giveUp = [&](const char* a_why) {
			_text = original;
			Parse();
			_error = a_why;
			a_outcomes.assign(a_edits.size(), Outcome::Refused);
			return false;
		};

		// the last line of defence, whatever the splices did: the result parses,
		// and every key that was not edited reads exactly as it did
		_text = std::move(text);
		bool sound = Parse();
		for (std::size_t i = 0; sound && i < before.size(); ++i) {
			if (!written.contains(before[i].key)) {
				const auto* now = Find(before[i].key);
				sound = now && Identical(now->value, before[i].value);
			}
		}
		if (!sound) {
			return giveUp("the change would have altered other settings and was not made");
		}

		if (!WriteTo(file, _text)) {
			WriteTo(file, original);  // best effort: put back what was there
			return giveUp("writing the file failed");
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
		const HANDLE file = OpenExclusive(_file, GENERIC_WRITE, OPEN_ALWAYS);
		if (file == INVALID_HANDLE_VALUE) {
			return false;
		}
		const bool ok = WriteTo(file, _text);
		::CloseHandle(file);
		return ok;
	}
}
