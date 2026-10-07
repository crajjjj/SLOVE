#pragma once

// What the menu shows: the user's SLOVE.toml joined with the schema (how to
// present a key) and the shipped defaults (what "reset" means). Pure C++ - the
// ImGui side (Menu.cpp) only draws these rows and calls Commit.

#include "core/ConfigDoc.h"
#include "core/Schema.h"

#include <cstddef>
#include <filesystem>
#include <optional>
#include <string>
#include <vector>

namespace Core
{
	struct Row
	{
		std::string key;
		std::string section;
		std::string name;

		// presentation (from the schema, or made up for a key it does not know)
		std::string           label;
		std::string           tip;
		std::string           unit;
		Control               control = Control::Auto;  // resolved: never Auto after Load
		Needs                 needs = Needs::Nothing;
		std::optional<double> min;
		std::optional<double> max;
		std::optional<double> step;
		bool                  known = false;  // the schema describes this key

		// values
		Scalar                saved;  // what the file holds (the default while it holds none)
		Scalar                edit;   // what the widget holds; committed when it differs from saved
		std::optional<Scalar> shipped;  // the shipped default, when there is one
		bool                  inFile = false;  // false: missing from the user's file, shown at its default

		// a value the last write refused, so a failing edit is not retried every frame
		std::optional<Scalar> failed;

		bool Dirty() const { return !Identical(edit, saved); }
		bool AtDefault() const { return !shipped || SameValue(saved, *shipped); }
	};

	struct Group
	{
		std::string              title;
		std::vector<std::size_t> rows;  // indices into Model::Rows()
	};

	struct Page
	{
		std::string        section;
		std::string        title;
		std::string        note;
		std::vector<Group> groups;
	};

	class Model
	{
	public:
		// The three files live side by side in a_dir:
		//   SLOVE.toml           the user's settings (required)
		//   SLOVE.defaults.toml  the shipped values, written by scripts\build.ps1 (optional)
		//   SLOVE_Menu.toml      the schema (optional)
		// False when SLOVE.toml cannot be read or parsed; Error() says why and the
		// model then has no pages.
		bool Load(const std::filesystem::path& a_dir);

		// Re-read SLOVE.toml only (the menu was opened: pick up hand edits). Edits
		// not yet committed are dropped. Returns true when the text on disk is not
		// what this model last read or wrote.
		bool Refresh();

		bool               Ok() const { return _doc.Ok(); }
		const std::string& Error() const { return _doc.Error(); }
		const std::string& SchemaError() const { return _schema.Error(); }
		bool               HasDefaults() const { return _defaults.Ok(); }

		std::vector<Page>&       Pages() { return _pages; }
		const std::vector<Page>& Pages() const { return _pages; }
		std::vector<Row>&        Rows() { return _rows; }
		const std::vector<Row>&  Rows() const { return _rows; }
		Row*                     Find(std::string_view a_key);
		bool                     InFile(std::string_view a_key) const;
		const ConfigDoc&         Doc() const { return _doc; }

		// Write the edit of every listed row to the file, as one exclusive
		// read-splice-write of what is on disk NOW (ConfigDoc::Rewrite), so a change
		// made outside since the menu read the file survives. Each row stands alone:
		// one the file refuses remembers the value that failed (Row::failed) and the
		// others are still written. Rows that are not dirty are skipped - unless
		// a_addMissing is set, which also adds rows the file does not hold yet at
		// the value they show, and leaves a key alone that someone added by hand in
		// the meantime. Adding matters: a key missing from the file does NOT run at
		// the shipped default, the scripts fall back to their own literal (often
		// 0), so "add it at the default" is a real change.
		//
		// Afterwards every row that is not mid-edit shows what the file holds.
		// False when anything listed could not be written.
		bool Commit(const std::vector<std::size_t>& a_rows, bool a_addMissing = false);

		// Set each listed row's edit to its shipped default (rows without one are
		// left alone). Does not write: follow with Commit.
		void ResetToDefault(const std::vector<std::size_t>& a_rows);

		// how many writes reached the disk since Load (tests, and the menu's log)
		std::size_t Writes() const { return _writes; }

	private:
		void Build();
		void Sync();

		std::filesystem::path _dir;
		ConfigDoc             _doc;
		ConfigDoc             _defaults;
		Schema                _schema;
		std::vector<Row>      _rows;
		std::vector<Page>     _pages;
		std::size_t           _writes = 0;
	};

	// "pcvolume" -> "Pcvolume", "intense_from_bar_only" -> "Intense from bar only":
	// the label of a key the schema does not describe
	std::string LabelFromName(std::string_view a_name);
}
