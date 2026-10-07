// Build-time tests of the pure core, run against the SHIPPED files:
//   core-tests <dist\SKSE\Plugins\SLOVE>
// The plugin rewrites the user's config in place, so the property that matters is
// "an edit changes exactly what was asked and nothing else". No test framework:
// CHECK counts failures and main returns non-zero when there are any.

#include "core/ConfigDoc.h"
#include "core/Model.h"
#include "core/Schema.h"

#include <algorithm>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <string>
#include <string_view>
#include <unordered_set>
#include <vector>

namespace fs = std::filesystem;
using namespace Core;

namespace
{
	int g_checks = 0;
	int g_failures = 0;

	void Check(bool a_ok, std::string_view a_what, std::string_view a_detail = {})
	{
		++g_checks;
		if (!a_ok) {
			++g_failures;
			std::cout << "FAIL: " << a_what;
			if (!a_detail.empty()) {
				std::cout << " [" << a_detail << "]";
			}
			std::cout << "\n";
		}
	}

	std::string ReadAll(const fs::path& a_file)
	{
		std::ifstream in{ a_file, std::ios::binary };
		return { std::istreambuf_iterator<char>{ in }, std::istreambuf_iterator<char>{} };
	}

	void WriteAll(const fs::path& a_file, std::string_view a_text)
	{
		std::ofstream out{ a_file, std::ios::binary | std::ios::trunc };
		out.write(a_text.data(), static_cast<std::streamsize>(a_text.size()));
	}

	std::vector<std::string> Lines(std::string_view a_text)
	{
		std::vector<std::string> lines;
		std::size_t              start = 0;
		while (start <= a_text.size()) {
			const auto end = a_text.find('\n', start);
			if (end == std::string_view::npos) {
				lines.emplace_back(a_text.substr(start));
				break;
			}
			lines.emplace_back(a_text.substr(start, end - start));
			start = end + 1;
		}
		return lines;
	}

	std::size_t Count(std::string_view a_text, std::string_view a_what)
	{
		std::size_t n = 0;
		for (auto at = a_text.find(a_what); at != std::string_view::npos; at = a_text.find(a_what, at + a_what.size())) {
			++n;
		}
		return n;
	}

	bool HasBareLf(std::string_view a_text)
	{
		for (std::size_t i = 0; i < a_text.size(); ++i) {
			if (a_text[i] == '\n' && (i == 0 || a_text[i - 1] != '\r')) {
				return true;
			}
		}
		return false;
	}

	// a different value of the same kind
	Scalar Other(const Scalar& a_value)
	{
		if (const auto* i = std::get_if<std::int64_t>(&a_value)) {
			return *i + 1;
		}
		if (const auto* f = std::get_if<double>(&a_value)) {
			return *f + 0.5;
		}
		if (const auto* s = std::get_if<std::string>(&a_value)) {
			return *s + "x";
		}
		return !std::get<bool>(a_value);
	}

	bool Ascii(std::string_view a_text)
	{
		return std::all_of(a_text.begin(), a_text.end(), [](unsigned char c) { return c < 128; });
	}

	// ---------------------------------------------------------------- ConfigDoc

	void TestDocument(const std::string& a_original)
	{
		ConfigDoc doc;
		Check(doc.LoadText(a_original), "SLOVE.toml parses", doc.Error());
		if (!doc.Ok()) {
			return;
		}
		const auto entries = doc.Entries();
		Check(entries.size() >= 100, "SLOVE.toml holds its settings", std::to_string(entries.size()) + " scalars");
		Check(!doc.Sections().empty(), "SLOVE.toml has sections");

		std::unordered_set<std::string> seen;
		for (const auto& entry : entries) {
			Check(seen.insert(entry.key).second, "no key appears twice", entry.key);
		}
		for (std::size_t i = 1; i < entries.size(); ++i) {
			Check(entries[i - 1].line <= entries[i].line, "entries are in file order", entries[i].key);
		}

		const bool        crlf = !HasBareLf(a_original) && Count(a_original, "\r\n") > 0;
		const auto        originalLines = Lines(a_original);
		const std::size_t originalBreaks = Count(a_original, "\n");

		// Strings are the one kind whose text can change without the value changing:
		// toml++ writes 'TongueOn' where the shipped file says "TongueOn", and
		// TomlEdit's validation only accepts toml++'s own spelling. Same value, same
		// as AudioUtil's TomlUtil.SetString does. So the byte-for-byte checks below
		// cover numbers (113 of the 115 keys); strings are checked by value. The
		// menu never writes a row that was not edited, so an untouched string keeps
		// its quotes.
		for (const auto& entry : entries) {
			const bool text = KindOf(entry.value) == Kind::String;
			// 1. writing a key's own value back changes nothing: the literal we
			//    produce is the literal the file already holds
			{
				ConfigDoc copy;
				copy.LoadText(a_original);
				Check(copy.Apply({ { entry.key, entry.value } }), "re-setting a value is accepted", entry.key);
				if (text) {
					const auto* same = copy.Find(entry.key);
					Check(same && same->value == entry.value, "re-setting a string keeps its value", entry.key);
				} else {
					Check(copy.Text() == a_original, "re-setting a value leaves the file byte-identical", entry.key);
				}
			}
			// 2. a real change touches exactly that one line and keeps its comment
			{
				ConfigDoc copy;
				copy.LoadText(a_original);
				const Scalar changed = Other(entry.value);
				Check(copy.Apply({ { entry.key, changed } }), "a changed value is accepted", entry.key);
				const auto lines = Lines(copy.Text());
				Check(lines.size() == originalLines.size(), "a change adds or removes no line", entry.key);
				if (lines.size() == originalLines.size()) {
					std::size_t differing = 0;
					std::size_t at = 0;
					for (std::size_t i = 0; i < lines.size(); ++i) {
						if (lines[i] != originalLines[i]) {
							++differing;
							at = i;
						}
					}
					Check(differing == 1, "a change touches exactly one line", entry.key);
					if (differing == 1) {
						Check(at + 1 == entry.line, "the changed line is the key's line", entry.key);
						const auto hashOld = originalLines[at].find('#');
						const auto hashNew = lines[at].find('#');
						if (hashOld != std::string::npos && KindOf(entry.value) != Kind::String) {
							Check(hashNew != std::string::npos && originalLines[at].substr(hashOld) == lines[at].substr(hashNew),
								"the line's comment survives a change", entry.key);
						}
					}
				}
				Check(Count(copy.Text(), "\n") == originalBreaks, "a change keeps the line count", entry.key);
				Check(!crlf || !HasBareLf(copy.Text()), "a change keeps CRLF line endings", entry.key);
				const auto* now = copy.Find(entry.key);
				Check(now && now->value == changed, "the new value reads back", entry.key);
				Check(now && KindOf(now->value) == KindOf(entry.value), "a change keeps the value's type", entry.key);
				// 3. and changing it back restores the file exactly
				Check(copy.Apply({ { entry.key, entry.value } }), "changing a value back is accepted", entry.key);
				if (text) {
					const auto* back = copy.Find(entry.key);
					Check(back && back->value == entry.value, "changing a string back restores its value", entry.key);
				} else {
					Check(copy.Text() == a_original, "changing a value back restores the file byte for byte", entry.key);
				}
			}
		}

		// 4. a batch (reset page) is one edit: change everything, then everything back
		{
			ConfigDoc         copy;
			std::vector<Edit> forward;
			std::vector<Edit> back;
			copy.LoadText(a_original);
			for (const auto& entry : entries) {
				if (KindOf(entry.value) == Kind::String) {
					continue;  // by value only, see above
				}
				forward.emplace_back(entry.key, Other(entry.value));
				back.emplace_back(entry.key, entry.value);
			}
			Check(copy.Apply(forward), "a batch of changes is accepted");
			Check(copy.Text() != a_original, "a batch of changes changes the file");
			Check(copy.Apply(back) && copy.Text() == a_original, "a batch reset restores the file byte for byte");
		}

		// 5. a key deleted from the file is re-inserted under its own header
		for (const auto& entry : { entries.front(), entries[entries.size() / 2], entries.back() }) {
			auto lines = Lines(a_original);
			lines.erase(lines.begin() + static_cast<std::ptrdiff_t>(entry.line - 1));
			std::string without;
			for (std::size_t i = 0; i < lines.size(); ++i) {
				without += lines[i];
				if (i + 1 < lines.size()) {
					without += '\n';
				}
			}
			ConfigDoc copy;
			Check(copy.LoadText(without) && copy.Find(entry.key) == nullptr, "a deleted key is gone", entry.key);
			Check(copy.Apply({ { entry.key, entry.value } }), "a missing key can be added", entry.key);
			const auto* now = copy.Find(entry.key);
			Check(now && now->value == entry.value, "the added key reads back", entry.key);
			Check(now && now->section == entry.section, "the added key lands in its own section", entry.key);
			Check(!crlf || !HasBareLf(copy.Text()), "an added key gets the file's line ending", entry.key);
			Check(copy.Entries().size() == entries.size(), "adding one key adds exactly one", entry.key);
		}

		// 6. a broken file is never "fixed"
		{
			ConfigDoc broken;
			Check(!broken.LoadText("[voice\npcvolume = 60\n"), "a file that does not parse is refused");
			Check(!broken.Apply({ { "voice.pcvolume", std::int64_t{ 10 } } }), "a refused file accepts no edit");
			Check(!broken.Save(), "a refused file is never written");
		}
	}

	void TestLiterals()
	{
		Check(Literal(Scalar{ 3.0 }) == "3.0", "a whole float keeps its decimal point", Literal(Scalar{ 3.0 }));
		Check(Literal(Scalar{ FromFloat(0.1f) }) == "0.1", "0.1f is written as 0.1", Literal(Scalar{ FromFloat(0.1f) }));
		Check(Literal(Scalar{ FromFloat(0.65f) }) == "0.65", "0.65f is written as 0.65", Literal(Scalar{ FromFloat(0.65f) }));
		Check(Literal(Scalar{ FromFloat(2048.0f) }) == "2048.0", "2048f is written as 2048.0", Literal(Scalar{ FromFloat(2048.0f) }));
		Check(Literal(Scalar{ std::int64_t{ 1 } }) == "1", "a flag is written as an int, never as true");
		Check(SameValue(Scalar{ std::int64_t{ 18 } }, Scalar{ 18.0 }), "18 and 18.0 are the same value");
		Check(!SameValue(Scalar{ std::int64_t{ 1 } }, Scalar{ true }), "1 and true are not the same value");
		ConfigDoc doc;
		doc.LoadText("[a]\nflag = 1\nname = \"x\"\n");
		Check(doc.Apply({ { "a.flag", std::int64_t{ 0 } } }) && doc.Text() == "[a]\nflag = 0\nname = \"x\"\n", "an int edit is a one-character splice");
		Check(doc.Apply({ { "a.name", std::string{ "My Mod.esp|0x12AB, Other.esp|801" } } }), "a list of forms is a plain string");
		const auto* name = doc.Find("a.name");
		Check(name && std::get<std::string>(name->value) == "My Mod.esp|0x12AB, Other.esp|801", "the string reads back");
	}

	// ------------------------------------------------------------------- Schema

	void TestSchema(const fs::path& a_dir, const std::string& a_original)
	{
		const auto file = a_dir / "SLOVE_Menu.toml";
		if (!fs::exists(file)) {
			std::cout << "note: no SLOVE_Menu.toml in " << a_dir.string() << " - schema checks skipped\n";
			return;
		}
		Schema schema;
		Check(schema.Load(file), "SLOVE_Menu.toml parses", schema.Error());
		ConfigDoc doc;
		doc.LoadText(a_original);
		Check(!schema.Pages().empty(), "the schema names its pages");
		for (const auto& page : schema.Pages()) {
			Check(std::find(doc.Sections().begin(), doc.Sections().end(), page.section) != doc.Sections().end(),
				"a schema page is a section of SLOVE.toml", page.section);
			Check(Ascii(page.title) && Ascii(page.note), "page text is ASCII", page.section);
		}
		std::unordered_set<std::string> described;
		for (const auto& spec : schema.Settings()) {
			described.insert(spec.key);
			const auto* entry = doc.Find(spec.key);
			Check(entry != nullptr, "a schema key exists in SLOVE.toml", spec.key);
			if (!entry) {
				continue;
			}
			const auto kind = KindOf(entry->value);
			bool       fits = false;
			switch (spec.control) {
			case Control::Flag:
			case Control::Int:
			case Control::Percent:
				fits = kind == Kind::Int;
				break;
			case Control::Float:
				fits = kind == Kind::Float;
				break;
			case Control::Text:
				fits = kind == Kind::String;
				break;
			default:
				break;
			}
			Check(fits, "a schema control fits the value's type", spec.key + " is " + ControlName(spec.control));
			if (spec.control == Control::Flag) {
				const auto v = std::get<std::int64_t>(entry->value);
				Check(v == 0 || v == 1, "a flag ships as 0 or 1", spec.key);
			}
			double number = 0.0;
			if (const auto* i = std::get_if<std::int64_t>(&entry->value)) {
				number = static_cast<double>(*i);
			} else if (const auto* f = std::get_if<double>(&entry->value)) {
				number = *f;
			}
			if (kind == Kind::Int || kind == Kind::Float) {
				Check(!spec.min || number >= *spec.min, "the shipped value is not below min", spec.key);
				Check(!spec.max || number <= *spec.max, "the shipped value is not above max", spec.key);
				Check(!spec.min || !spec.max || *spec.min < *spec.max, "min is below max", spec.key);
			}
			Check(!spec.label.empty(), "a setting has a label", spec.key);
			Check(!spec.group.empty(), "a setting has a group", spec.key);
			Check(Ascii(spec.label) && Ascii(spec.tip) && Ascii(spec.group) && Ascii(spec.unit), "setting text is ASCII", spec.key);
			Check(spec.label.find("##") == std::string::npos, "a label has no ## (ImGui id marker)", spec.key);
			Check(spec.tip.find('\n') == std::string::npos, "a tip is one line", spec.key);
		}
		for (const auto& entry : doc.Entries()) {
			Check(described.contains(entry.key), "every SLOVE.toml key is described by the schema", entry.key);
		}
	}

	// -------------------------------------------------------------------- Model

	void TestModel(const fs::path& a_dir, const std::string& a_original)
	{
		const auto work = fs::temp_directory_path() / "slove-core-tests";
		std::error_code ec;
		fs::remove_all(work, ec);
		fs::create_directories(work, ec);
		WriteAll(work / "SLOVE.toml", a_original);
		WriteAll(work / "SLOVE.defaults.toml", a_original);  // what build.ps1 generates
		if (fs::exists(a_dir / "SLOVE_Menu.toml")) {
			fs::copy_file(a_dir / "SLOVE_Menu.toml", work / "SLOVE_Menu.toml", fs::copy_options::overwrite_existing, ec);
		}

		Model model;
		Check(model.Load(work), "the model loads", model.Error());
		ConfigDoc doc;
		doc.LoadText(a_original);
		Check(model.Rows().size() == doc.Entries().size(), "one row per key");
		Check(model.HasDefaults(), "the defaults load");

		std::size_t placed = 0;
		for (const auto& page : model.Pages()) {
			for (const auto& group : page.groups) {
				placed += group.rows.size();
				for (const auto index : group.rows) {
					Check(model.Rows()[index].section == page.section, "a row sits on its section's page", model.Rows()[index].key);
				}
			}
		}
		Check(placed == model.Rows().size(), "every row is on exactly one page", std::to_string(placed));
		for (const auto& row : model.Rows()) {
			Check(row.control != Control::Auto, "every row has a control", row.key);
			Check(row.inFile && !row.Dirty() && row.AtDefault(), "a fresh install shows no change", row.key);
			if (row.control == Control::Flag || row.control == Control::Percent) {
				Check(KindOf(row.saved) == Kind::Int, "a flag or percent row holds an int", row.key);
			}
		}

		// one edit -> one write, one changed line, and the row settles
		auto* volume = model.Find("voice.pcvolume");
		Check(volume != nullptr, "voice.pcvolume has a row");
		if (volume) {
			const auto index = static_cast<std::size_t>(volume - model.Rows().data());
			volume->edit = std::int64_t{ 37 };
			Check(volume->Dirty(), "an edited row is dirty");
			Check(model.Commit({ index }), "the edit commits");
			Check(model.Writes() == 1, "one commit is one write");
			Check(!volume->Dirty() && !volume->AtDefault(), "the row settles off its default");
			const auto onDisk = ReadAll(work / "SLOVE.toml");
			Check(onDisk != a_original && onDisk.size() == a_original.size(), "the file changed in place (60 -> 37)");
			Check(model.Commit({ index }) && model.Writes() == 1, "committing a clean row writes nothing");
			Check(!model.Refresh(), "re-reading our own write is not an outside change");

			// a hand edit made while the menu is closed must survive our next write
			auto edited = ReadAll(work / "SLOVE.toml");
			const auto at = edited.find("partnervolume = 60");
			Check(at != std::string::npos, "the fixture still has partnervolume = 60");
			if (at != std::string::npos) {
				edited.replace(at, 18, "partnervolume = 61");
				WriteAll(work / "SLOVE.toml", edited);
				volume = model.Find("voice.pcvolume");
				volume->edit = std::int64_t{ 38 };
				Check(model.Commit({ static_cast<std::size_t>(volume - model.Rows().data()) }), "a commit after an outside edit succeeds");
				const auto after = ReadAll(work / "SLOVE.toml");
				Check(after.find("partnervolume = 61") != std::string::npos, "the outside edit survives our write");
				Check(model.Refresh() == false, "after the commit the model matches the disk");
				const auto* partner = model.Find("voice.partnervolume");
				Check(partner && partner->saved == Scalar{ std::int64_t{ 61 } }, "a refresh shows the outside edit");
			}

			// reset everything -> the shipped file, byte for byte
			std::vector<std::size_t> all(model.Rows().size());
			for (std::size_t i = 0; i < all.size(); ++i) {
				all[i] = i;
			}
			model.ResetToDefault(all);
			Check(model.Commit(all), "reset to defaults commits");
			Check(ReadAll(work / "SLOVE.toml") == a_original, "reset to defaults restores the shipped file byte for byte");
		}

		// a key the user's file lacks: shown at the shipped value, flagged, addable
		{
			auto       lines = Lines(a_original);
			const auto entry = *doc.Find("voice.pcvolume");
			lines.erase(lines.begin() + static_cast<std::ptrdiff_t>(entry.line - 1));
			std::string without;
			for (std::size_t i = 0; i < lines.size(); ++i) {
				without += lines[i];
				if (i + 1 < lines.size()) {
					without += '\n';
				}
			}
			WriteAll(work / "SLOVE.toml", without);
			Model missing;
			Check(missing.Load(work), "the model loads a file with a key missing");
			Check(missing.Rows().size() == doc.Entries().size(), "the missing key still has a row");
			auto* row = missing.Find("voice.pcvolume");
			Check(row && !row->inFile && !row->Dirty(), "the missing key is flagged, not dirty");
			if (row) {
				const auto index = static_cast<std::size_t>(row - missing.Rows().data());
				Check(missing.Commit({ index }) && missing.Writes() == 0, "a plain commit does not add it");
				Check(missing.Commit({ index }, true) && missing.Writes() == 1, "adding it writes once");
				Check(row->inFile, "the row is in the file now");
				ConfigDoc after;
				after.Load(work / "SLOVE.toml");
				const auto* added = after.Find("voice.pcvolume");
				Check(added && added->value == entry.value && added->section == "voice", "the key is back under [voice]");
			}
		}

		// no schema and no defaults: still one plain field per key
		{
			fs::remove(work / "SLOVE_Menu.toml", ec);
			fs::remove(work / "SLOVE.defaults.toml", ec);
			WriteAll(work / "SLOVE.toml", a_original);
			Model bare;
			Check(bare.Load(work), "the model loads without schema and defaults");
			Check(bare.Rows().size() == doc.Entries().size(), "without a schema every key still has a row");
			Check(bare.Pages().size() == doc.Sections().size(), "without a schema there is one page per section");
			for (const auto& row : bare.Rows()) {
				Check(!row.known && row.control != Control::Auto && !row.label.empty(), "an undescribed key renders generically", row.key);
			}
		}

		// a file that does not parse: no pages, nothing written
		{
			WriteAll(work / "SLOVE.toml", "[voice\npcvolume = 60\n");
			Model broken;
			Check(!broken.Load(work) && broken.Pages().empty() && !broken.Error().empty(), "a broken file gives an error and no pages");
		}
		fs::remove_all(work, ec);
	}
}

int main(int argc, char** argv)
{
	if (argc < 2) {
		std::cout << "usage: core-tests <folder holding SLOVE.toml>\n";
		return 2;
	}
	const fs::path dir{ argv[1] };
	const auto     original = ReadAll(dir / "SLOVE.toml");
	if (original.empty()) {
		std::cout << "FAIL: cannot read " << (dir / "SLOVE.toml").string() << "\n";
		return 2;
	}

	TestLiterals();
	TestDocument(original);
	TestSchema(dir, original);
	TestModel(dir, original);

	std::cout << g_checks << " checks, " << g_failures << " failed\n";
	return g_failures == 0 ? 0 : 1;
}
