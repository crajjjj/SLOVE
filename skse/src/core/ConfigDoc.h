#pragma once

// SLOVE.toml as an editable document: the scalars it holds, in file order, and a
// comment-preserving way to change them. Pure C++ and toml++ - no game, no SKSE -
// so tests\core_tests.cpp can run it against the shipped file at build time.

#include <cstdint>
#include <filesystem>
#include <string>
#include <string_view>
#include <utility>
#include <variant>
#include <vector>

namespace Core
{
	// One TOML scalar. SLOVE.toml holds ints (every flag is an int 0/1, never a
	// boolean - the scripts read them with GetInt and TomlUtil does not convert),
	// floats and two strings; bool is here for keys a user added by hand.
	using Scalar = std::variant<std::int64_t, double, std::string, bool>;

	enum class Kind
	{
		Int,
		Float,
		String,
		Bool
	};

	Kind KindOf(const Scalar& a_value);

	// The exact TOML text for a value, as toml++ writes it (a float keeps its
	// decimal point, so it stays float-typed when read back).
	std::string Literal(const Scalar& a_value);

	// For people: 18.0, 1, TongueOn (no quotes), true.
	std::string Display(const Scalar& a_value);

	// Equal as values; an int and a float compare numerically (a user may have
	// written 18 where the shipped file says 18.0).
	bool SameValue(const Scalar& a_lhs, const Scalar& a_rhs);

	// A float as the person typed or dragged it: the shortest decimal that reads
	// back to the same float, so 0.1f is written as 0.1 and not 0.10000000149.
	double FromFloat(float a_value);

	struct Entry
	{
		std::string   key;      // "voice.pcvolume"
		std::string   section;  // "voice" ("" for a root key)
		std::string   name;     // "pcvolume"
		Scalar        value;
		std::uint32_t line = 0;  // 1-based line of the value in the file
	};

	using Edit = std::pair<std::string, Scalar>;

	class ConfigDoc
	{
	public:
		// Read and parse a file. False (Error() says why) when it cannot be read or
		// does not parse; the document is then empty and must not be saved.
		bool Load(const std::filesystem::path& a_file);

		// The same from text already in hand (tests).
		bool LoadText(std::string a_text);

		bool                            Ok() const { return _ok; }
		const std::string&              Error() const { return _error; }
		const std::string&              Text() const { return _text; }
		const std::filesystem::path&    File() const { return _file; }
		const std::vector<Entry>&       Entries() const { return _entries; }  // file order
		const std::vector<std::string>& Sections() const { return _sections; }  // file order
		const Entry*                    Find(std::string_view a_key) const;

		// Splice every edit into the text, all or nothing: on any failure the
		// document is left exactly as it was. An existing value is replaced in
		// place (its comment and spacing stay); a missing key is inserted under
		// its [section] header. Memory only - call Save to reach the disk.
		bool Apply(const std::vector<Edit>& a_edits);

		// Write the current text back to the file it was loaded from. In place and
		// exclusive: nothing else can read a half-written file, and the file is
		// never renamed over (under Mod Organizer a rename could land the new file
		// in Overwrite instead of the mod folder).
		bool Save();

	private:
		bool Parse();

		std::filesystem::path    _file;
		std::string              _text;
		std::string              _error;
		std::vector<Entry>       _entries;
		std::vector<std::string> _sections;
		bool                     _ok = false;
	};
}
