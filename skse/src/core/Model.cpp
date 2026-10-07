#include "core/Model.h"

#include <algorithm>
#include <cctype>
#include <unordered_map>
#include <unordered_set>

namespace Core
{
	namespace
	{
		// the control a value gets when the schema says nothing, or says something
		// that does not fit the value's type
		Control InferControl(const Scalar& a_value)
		{
			switch (KindOf(a_value)) {
			case Kind::Float:
				return Control::Float;
			case Kind::String:
				return Control::Text;
			default:
				return Control::Int;  // a TOML boolean is drawn by kind, see Menu.cpp
			}
		}

		bool Fits(Control a_control, const Scalar& a_value)
		{
			switch (a_control) {
			case Control::Flag:
			case Control::Int:
			case Control::Percent:
				return KindOf(a_value) == Kind::Int;
			case Control::Float:
				// a float key the user wrote as an int still edits as a float
				return KindOf(a_value) == Kind::Float || KindOf(a_value) == Kind::Int;
			case Control::Text:
				return KindOf(a_value) == Kind::String;
			default:
				return false;
			}
		}

		std::string TitleFromSection(std::string_view a_section)
		{
			std::string title{ a_section };
			if (!title.empty()) {
				title[0] = static_cast<char>(std::toupper(static_cast<unsigned char>(title[0])));
			}
			return title;
		}
	}

	std::string LabelFromName(std::string_view a_name)
	{
		std::string label{ a_name };
		std::replace(label.begin(), label.end(), '_', ' ');
		if (!label.empty()) {
			label[0] = static_cast<char>(std::toupper(static_cast<unsigned char>(label[0])));
		}
		return label;
	}

	bool Model::Load(const std::filesystem::path& a_dir)
	{
		_dir = a_dir;
		_writes = 0;
		_schema.Load(a_dir / "SLOVE_Menu.toml");  // optional
		_defaults.Load(a_dir / "SLOVE.defaults.toml");  // optional
		_doc.Load(a_dir / "SLOVE.toml");
		Build();
		return _doc.Ok();
	}

	bool Model::Refresh()
	{
		const std::string before = _doc.Text();
		_doc.Load(_dir / "SLOVE.toml");
		Build();
		return _doc.Text() != before;
	}

	void Model::Build()
	{
		_rows.clear();
		_pages.clear();
		if (!_doc.Ok()) {
			return;
		}

		// every key worth a row: what the user's file holds, then what only the
		// shipped file holds (a key the user deleted, or one added by an update)
		struct Source
		{
			const Entry* live = nullptr;
			const Entry* shipped = nullptr;
		};
		std::vector<std::string>                order;
		std::unordered_map<std::string, Source> sources;
		for (const auto& entry : _doc.Entries()) {
			order.push_back(entry.key);
			sources[entry.key].live = &entry;
		}
		if (_defaults.Ok()) {
			for (const auto& entry : _defaults.Entries()) {
				auto& source = sources[entry.key];
				if (!source.live && !source.shipped) {
					order.push_back(entry.key);
				}
				source.shipped = &entry;
			}
		}

		std::unordered_map<std::string, std::size_t> rowOf;
		for (const auto& key : order) {
			const auto&  source = sources[key];
			const Entry& entry = source.live ? *source.live : *source.shipped;
			Row          row;
			row.key = entry.key;
			row.section = entry.section;
			row.name = entry.name;
			row.inFile = source.live != nullptr;
			row.saved = entry.value;
			if (source.shipped) {
				row.shipped = source.shipped->value;
			}
			if (const auto* spec = _schema.Find(key)) {
				row.known = true;
				row.label = spec->label.empty() ? LabelFromName(entry.name) : spec->label;
				row.tip = spec->tip;
				row.unit = spec->unit;
				row.needs = spec->needs;
				row.min = spec->min;
				row.max = spec->max;
				row.step = spec->step;
				row.control = spec->control != Control::Auto && Fits(spec->control, row.saved) ? spec->control : InferControl(row.saved);
			} else {
				row.label = LabelFromName(entry.name);
				row.control = InferControl(row.saved);
			}
			// a float control always edits a float, also when the file says 18
			if (row.control == Control::Float) {
				if (const auto* i = std::get_if<std::int64_t>(&row.saved)) {
					row.saved = static_cast<double>(*i);
				}
			}
			row.edit = row.saved;
			rowOf.emplace(row.key, _rows.size());
			_rows.push_back(std::move(row));
		}

		// pages: the schema's, in its order, then any section it does not name
		std::unordered_set<std::string> paged;
		const auto                      addPage = [&](std::string a_section, std::string a_title, std::string a_note) {
            if (paged.insert(a_section).second) {
                Page page;
                page.section = std::move(a_section);
                page.title = std::move(a_title);
                page.note = std::move(a_note);
                _pages.push_back(std::move(page));
            }
		};
		for (const auto& spec : _schema.Pages()) {
			addPage(spec.section, spec.title, spec.note);
		}
		for (const auto& row : _rows) {
			addPage(row.section, row.section.empty() ? std::string{ "General" } : TitleFromSection(row.section), {});
		}

		for (auto& page : _pages) {
			const auto group = [&](const std::string& a_title) -> Group& {
				const auto it = std::find_if(page.groups.begin(), page.groups.end(),
					[&](const Group& g) { return g.title == a_title; });
				if (it != page.groups.end()) {
					return *it;
				}
				page.groups.push_back({ a_title, {} });
				return page.groups.back();
			};
			// described keys first, grouped and ordered as the schema lists them
			for (const auto& spec : _schema.Settings()) {
				const auto it = rowOf.find(spec.key);
				if (it == rowOf.end() || _rows[it->second].section != page.section) {
					continue;
				}
				group(spec.group.empty() ? std::string{ "Settings" } : spec.group).rows.push_back(it->second);
			}
			// then whatever the schema does not know, in file order
			for (std::size_t i = 0; i < _rows.size(); ++i) {
				if (_rows[i].section == page.section && !_rows[i].known) {
					group("Other").rows.push_back(i);
				}
			}
		}
		// a schema page for a section the file does not have is not shown
		std::erase_if(_pages, [](const Page& p) { return p.groups.empty(); });
	}

	Row* Model::Find(std::string_view a_key)
	{
		const auto it = std::find_if(_rows.begin(), _rows.end(), [&](const Row& r) { return r.key == a_key; });
		return it != _rows.end() ? &*it : nullptr;
	}

	bool Model::InFile(std::string_view a_key) const
	{
		return _doc.Find(a_key) != nullptr;
	}

	bool Model::Commit(const std::vector<std::size_t>& a_rows, bool a_addMissing)
	{
		std::vector<Edit>        edits;
		std::vector<std::size_t> touched;
		for (const auto index : a_rows) {
			if (index >= _rows.size()) {
				continue;
			}
			if (!_rows[index].Dirty() && !(a_addMissing && !_rows[index].inFile)) {
				continue;
			}
			edits.emplace_back(_rows[index].key, _rows[index].edit);
			touched.push_back(index);
		}
		if (edits.empty()) {
			return true;
		}

		// splice into what is on disk NOW, not into what was read when the menu
		// opened: a hand edit or a console `toml set` made since then survives
		ConfigDoc fresh;
		if (!fresh.Load(_doc.File()) || !fresh.Apply(edits) || !fresh.Save()) {
			for (const auto index : touched) {
				_rows[index].failed = _rows[index].edit;
			}
			return false;
		}
		_doc = std::move(fresh);
		++_writes;
		for (const auto index : touched) {
			auto& row = _rows[index];
			row.saved = row.edit;
			row.inFile = true;
			row.failed.reset();
		}
		return true;
	}

	void Model::ResetToDefault(const std::vector<std::size_t>& a_rows)
	{
		for (const auto index : a_rows) {
			if (index >= _rows.size() || !_rows[index].shipped) {
				continue;
			}
			auto&  row = _rows[index];
			Scalar value = *row.shipped;
			if (row.control == Control::Float) {
				if (const auto* i = std::get_if<std::int64_t>(&value)) {
					value = static_cast<double>(*i);
				}
			}
			row.edit = std::move(value);
			row.failed.reset();
		}
	}
}
