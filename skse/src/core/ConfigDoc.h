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
	// One TOML scalar. SLOVE.toml holds ints (every flag is an int 0/1, by
	// convention: the scripts read flags with GetInt), floats and two strings;
	// bool is here for keys a user added by hand. TomlUtil's getters convert
	// where nothing is lost (true reads as 1, 60.0 as 60) and hand back the
	// script's fallback otherwise (60.5 or "60" read with GetInt).
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

	// Equal as stored: the same type holding the same value. Unlike ==, a NaN is
	// identical to a NaN - "is there anything to write" must not be true for ever
	// for a value that never equals itself.
	bool Identical(const Scalar& a_lhs, const Scalar& a_rhs);

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

	struct Edit
	{
		std::string key;
		Scalar      value;
		// write only when the file does not hold the key (the menu's "add"): a
		// value someone put there in the meantime is theirs and is left alone
		bool ifMissing = false;
	};

	// what Rewrite did with one edit
	enum class Outcome
	{
		Written,  // the file now holds the value
		Kept,     // ifMissing, and the file already had the key
		Refused   // could not be spliced in safely, or the write failed
	};

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

		// Change a file on disk: read it, splice the edits in and write it back
		// through ONE exclusive handle, so the text that is edited is the text that
		// is on disk - never a file another program is half-way through saving, and
		// nobody reads ours half-written. In place, no rename: under Mod Organizer a
		// renamed file could land in Overwrite instead of the mod folder.
		//
		// An existing value is replaced where it stands (comment and spacing stay);
		// a missing key is inserted under its [section] header. Each edit stands
		// alone: one that cannot be made safely is Refused and the others still go
		// in. Before anything is written the result must parse, and every key that
		// was NOT edited must read exactly as before.
		//
		// False when the file could not be opened, read, parsed or written (every
		// outcome is then Refused, the file is as it was and Error() says why).
		// True otherwise, with one outcome per edit; this document then holds what
		// the disk holds.
		bool Rewrite(const std::filesystem::path& a_file, const std::vector<Edit>& a_edits, std::vector<Outcome>& a_outcomes);

		// Splice every edit into the text in memory, all or nothing: on any failure
		// the document is left exactly as it was. (ifMissing is not looked at.)
		bool Apply(const std::vector<Edit>& a_edits);

		// Write the current text back to the file it was loaded from, in place and
		// exclusive. Rewrite is the way to change a file; this is for text that was
		// built in memory.
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
