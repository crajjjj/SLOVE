#pragma once

// Comment-preserving TOML value writer.
//
// toml++ serialization discards comments and formatting, so writing a whole
// document back would wreck hand-authored config files. Instead this edits the
// source TEXT: an existing scalar's characters are spliced out via the node's
// source_region and replaced with the new literal; a new key is inserted right
// under its table's [header] line (or the table is appended at EOF). The edited
// text is then re-parsed and the key must round-trip to exactly the requested
// literal, so an unsafe splice can never reach disk - the edit fails instead.
//
// Pure text/toml++ logic with no game dependencies (unit-testable standalone).
// Limitations (all fail safely with nullopt): bare dotted keys only, scalar
// values only (no arrays/tables), no inline-table insertion, and a table
// created via root-level dotted keys can't have new keys added.

#include <toml++/toml.hpp>

#include <cstddef>
#include <cstdint>
#include <optional>
#include <sstream>
#include <string>
#include <string_view>
#include <vector>

namespace TomlEdit
{
	// serialize one scalar as a TOML literal via toml++'s own formatter, so
	// quoting/escaping and float formatting (decimal point kept -> the value
	// stays float-typed) always match what the validator will read back
	template <class T>
	std::string Literal(const T& a_value)
	{
		std::ostringstream oss;
		oss << toml::value<T>{ a_value };
		return oss.str();
	}

	namespace detail
	{
		inline std::vector<std::size_t> LineStarts(std::string_view a_text)
		{
			std::vector<std::size_t> starts{ 0 };
			for (std::size_t i = 0; i < a_text.size(); ++i) {
				if (a_text[i] == '\n') {
					starts.push_back(i + 1);
				}
			}
			return starts;
		}

		// byte offset of a 1-based toml++ source_position. Columns are counted
		// in codepoints, not bytes, so non-ASCII earlier in the SAME line skews
		// this - the round-trip validation below turns that into a safe failure.
		inline std::optional<std::size_t> ByteOffset(const std::vector<std::size_t>& a_starts,
			std::string_view a_text, std::uint32_t a_line, std::uint32_t a_column)
		{
			if (a_line == 0 || a_column == 0 || a_line > a_starts.size()) {
				return std::nullopt;
			}
			const auto offset = a_starts[a_line - 1] + (a_column - 1);
			return offset <= a_text.size() ? std::optional{ offset } : std::nullopt;
		}

		inline std::string_view Trim(std::string_view a_s)
		{
			while (!a_s.empty() && (a_s.front() == ' ' || a_s.front() == '\t')) {
				a_s.remove_prefix(1);
			}
			while (!a_s.empty() && (a_s.back() == ' ' || a_s.back() == '\t' || a_s.back() == '\r')) {
				a_s.remove_suffix(1);
			}
			return a_s;
		}

		inline std::vector<std::string> SplitDotted(std::string_view a_path)
		{
			std::vector<std::string> parts;
			std::size_t start = 0;
			while (start <= a_path.size()) {
				const auto dot = a_path.find('.', start);
				const auto part = Trim(a_path.substr(start, dot == std::string_view::npos ? std::string_view::npos : dot - start));
				parts.emplace_back(part);
				if (dot == std::string_view::npos) {
					break;
				}
				start = dot + 1;
			}
			return parts;
		}

		// byte offset just past the "[a.b]" header line for a_tablePath, or
		// nullopt when no textual header exists (implicit/dotted table). Bare
		// keys only - a quoted header segment is skipped, never matched.
		inline std::optional<std::size_t> AfterHeaderLine(std::string_view a_text,
			const std::vector<std::size_t>& a_starts, std::string_view a_tablePath)
		{
			const auto want = SplitDotted(a_tablePath);
			for (std::size_t li = 0; li < a_starts.size(); ++li) {
				const auto lineEnd = li + 1 < a_starts.size() ? a_starts[li + 1] : a_text.size();
				const auto line = Trim(a_text.substr(a_starts[li], lineEnd - a_starts[li]));
				if (line.size() < 2 || line.front() != '[' || line.starts_with("[[")) {
					continue;
				}
				const auto close = line.find(']');
				if (close == std::string_view::npos) {
					continue;
				}
				const auto inner = line.substr(1, close - 1);
				if (inner.find('"') != std::string_view::npos || inner.find('\'') != std::string_view::npos) {
					continue;
				}
				if (SplitDotted(inner) == want) {
					return lineEnd;  // start of the next line (== text size on the last line)
				}
			}
			return std::nullopt;
		}

		// the exact literal the parsed key serializes back to, for round-trip
		// validation ("" when missing or not a scalar)
		inline std::string RoundTrip(const toml::table& a_tbl, std::string_view a_key)
		{
			const auto node = a_tbl.at_path(a_key);
			if (!node || !node.node()->is_value()) {
				return {};
			}
			std::ostringstream oss;
			node.node()->visit([&](const auto& el) {
				if constexpr (toml::is_value<std::remove_cvref_t<decltype(el)>>) {
					oss << el;
				}
			});
			return oss.str();
		}
	}

	// Set a_key (bare dotted path) to a_literal inside TOML source a_text,
	// touching as few characters as possible. Returns the edited text, or
	// nullopt when the edit can't be made safely - the result is always
	// re-parsed and the key verified to read back as exactly a_literal, so a
	// returned text is guaranteed valid.
	inline std::optional<std::string> SetInText(const std::string& a_text,
		const std::string& a_key, const std::string& a_literal)
	{
		toml::table tbl;
		try {
			tbl = toml::parse(a_text);
		} catch (...) {
			return std::nullopt;  // never "fix" a file the user broke
		}

		const auto starts = detail::LineStarts(a_text);
		std::string edited;

		if (const auto node = tbl.at_path(a_key); node) {
			// existing key: splice the value's characters out, keep everything else
			if (!node.node()->is_value()) {
				return std::nullopt;
			}
			const auto& src = node.node()->source();
			const auto begin = detail::ByteOffset(starts, a_text, src.begin.line, src.begin.column);
			const auto end = detail::ByteOffset(starts, a_text, src.end.line, src.end.column);
			if (!begin || !end || *end < *begin) {
				return std::nullopt;
			}
			edited = a_text.substr(0, *begin) + a_literal + a_text.substr(*end);
		} else {
			const auto lastDot = a_key.rfind('.');
			const auto tablePath = lastDot == std::string::npos ? std::string{} : a_key.substr(0, lastDot);
			const auto leaf = lastDot == std::string::npos ? a_key : a_key.substr(lastDot + 1);
			if (leaf.empty()) {
				return std::nullopt;
			}
			const auto keyLine = leaf + " = " + a_literal + "\n";
			if (tablePath.empty()) {
				// root keys must precede any [table] header -> insert at the top
				edited = keyLine + a_text;
			} else if (const auto tnode = tbl.at_path(tablePath); tnode) {
				const auto* table = tnode.as_table();
				if (!table || table->is_inline()) {
					return std::nullopt;
				}
				// insert directly under the table's [header] line - always inside
				// the table no matter where it ends
				const auto insertAt = detail::AfterHeaderLine(a_text, starts, tablePath);
				if (!insertAt) {
					return std::nullopt;  // dotted/implicit table, no header to anchor on
				}
				edited = a_text.substr(0, *insertAt);
				if (!edited.empty() && edited.back() != '\n') {
					edited += '\n';  // header was the unterminated last line
				}
				edited += keyLine + a_text.substr(*insertAt);
			} else {
				// no such table yet: append it (parse fails -> safe nullopt if the
				// path collides with something non-table)
				edited = a_text;
				if (!edited.empty() && edited.back() != '\n') {
					edited += '\n';
				}
				edited += "\n[" + tablePath + "]\n" + keyLine;
			}
		}

		// round-trip validation: the edited text must parse and the key must
		// read back as exactly the literal we wrote
		try {
			const auto check = toml::parse(edited);
			if (detail::RoundTrip(check, a_key) != a_literal) {
				return std::nullopt;
			}
		} catch (...) {
			return std::nullopt;
		}
		return edited;
	}
}
