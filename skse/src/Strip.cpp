#include "Strip.h"

namespace Strip
{
	namespace
	{
		using namespace Core::Strip;

		Xform ToXform(const RE::NiTransform& a_t)
		{
			Xform out;
			for (int r = 0; r < 3; ++r) {
				for (int c = 0; c < 3; ++c) {
					out.rot[r][c] = a_t.rotate.entry[r][c];
				}
			}
			out.t = { a_t.translate.x, a_t.translate.y, a_t.translate.z };
			out.scale = a_t.scale;
			return out;
		}

		bool StartsWithNoCase(std::string_view a_text, std::string_view a_prefix)
		{
			return a_text.size() >= a_prefix.size() && EqualsNoCase(a_text.substr(0, a_prefix.size()), a_prefix);
		}

		// The body, drawn inside an outfit mesh or as the skin armor's own shape.
		bool IsSkinShape(RE::BSGeometry* a_geometry)
		{
			const auto* property = a_geometry->GetGeometryRuntimeData().shaderProperty.get();
			if (!property || !property->material) {
				return false;
			}
			const auto feature = property->material->GetFeature();
			return feature == RE::BSShaderMaterial::Feature::kFaceGenRGBTint ||
			       feature == RE::BSShaderMaterial::Feature::kFaceGen;
		}

		// One shape's vertices, counted into a_out. Every pointer on the way is
		// checked: a shape we cannot read simply counts for nothing.
		void CountShape(RE::BSGeometry* a_geometry, float a_reach, Counts& a_out)
		{
			if (!a_geometry || a_geometry->GetAppCulled()) {
				return;
			}
			if (StartsWithNoCase(a_geometry->name.c_str(), "Virtual"sv)) {
				return;  // an HDT-SMP collision proxy, never drawn
			}
			if (IsSkinShape(a_geometry)) {
				return;
			}

			// held for the length of the read: the 3D can be rebuilt on another thread
			const RE::NiPointer<RE::NiSkinInstance> skin = a_geometry->GetGeometryRuntimeData().skinInstance;
			if (!skin) {
				return;  // a rigid part hangs on one node; its place is not known from a bind
			}
			const RE::NiPointer<RE::NiSkinData>      data = skin->skinData;
			const RE::NiPointer<RE::NiSkinPartition> partition = skin->skinPartition;
			if (!data || !partition || !skin->bones || partition->numPartitions == 0) {
				return;
			}
			// every partition holds the whole vertex buffer; the first is the master copy
			auto&       first = partition->partitions[0];
			const auto* buffer = first.buffData;
			if (!buffer || !buffer->rawVertexData || partition->vertexCount == 0) {
				return;
			}

			// the buffer's own description of its vertices
			auto desc = buffer->vertexDesc;
			if (!desc.HasFlag(RE::BSGraphics::Vertex::VF_VERTEX)) {
				return;
			}
			ShapeView shape;
			shape.vertices = buffer->rawVertexData;
			shape.count = partition->vertexCount;
			shape.stride = desc.GetSize();
			shape.skinOffset = desc.HasFlag(RE::BSGraphics::Vertex::VF_SKINNED) ?
			                       static_cast<std::int32_t>(desc.GetAttributeOffset(RE::BSGraphics::Vertex::VA_SKINNING)) :
			                       -1;

			const std::uint32_t        bones = std::min<std::uint32_t>(data->GetBoneCount(), 256);  // a vertex names its bones in one byte each
			std::vector<std::uint8_t> boneZones(bones, 0);
			Xform                     pelvis;
			Xform                     spine2;
			Xform                     head;
			for (std::uint32_t b = 0; b < bones; ++b) {
				const auto* node = skin->bones[b];
				if (!node) {
					continue;
				}
				const std::string_view name = node->name.c_str();
				boneZones[b] = BoneZones(name);
				if (!shape.pelvis && EqualsNoCase(name, kPelvisBone)) {
					pelvis = ToXform(data->GetBoneDataSkinToBone(b));
					shape.pelvis = &pelvis;
				} else if (!shape.spine2 && EqualsNoCase(name, kSpine2Bone)) {
					spine2 = ToXform(data->GetBoneDataSkinToBone(b));
					shape.spine2 = &spine2;
				} else if (!shape.head && EqualsNoCase(name, kHeadBone)) {
					head = ToXform(data->GetBoneDataSkinToBone(b));
					shape.head = &head;
				}
			}
			shape.boneZones = boneZones;

			Count(shape, a_reach, a_out);
		}

		// Why an armor is left alone no matter what it covers; nullptr = it may go.
		const char* KeptBecause(RE::Actor* a_actor, RE::TESObjectARMO* a_armor, std::uint32_t a_keepSlots)
		{
			const auto* base = a_actor->GetActorBase();
			const auto* race = a_actor->GetRace();
			if ((base && base->skin == a_armor) || (race && race->skin == a_armor)) {
				return "skin";
			}
			const char* name = a_armor->GetName();
			if (!name || !*name) {
				return "no name";
			}
			if ((a_armor->GetSlotMask().underlying() & a_keepSlots) != 0) {
				return "kept slot";
			}
			for (const auto keyword : { "SexLabNoStrip"sv, "zad_Lockable"sv, "zad_InventoryDevice"sv, "zad_QuestItem"sv }) {
				if (a_armor->HasKeywordString(keyword)) {
					return "keyword";
				}
			}
			return nullptr;
		}
	}

	std::vector<Item> Survey(RE::Actor* a_actor, float a_reach, std::uint32_t a_keepSlots)
	{
		std::vector<Item> items;
		if (!a_actor) {
			return items;
		}
		// a copy of the smart pointer: the biped can be swapped while we walk it
		const RE::BSTSmartPointer<RE::BipedAnim> biped = a_actor->GetBiped(false);
		if (!biped) {
			return items;
		}
		for (std::uint32_t slot = 0; slot < RE::BIPED_OBJECTS::kEditorTotal; ++slot) {
			const auto& object = biped->objects[slot];
			auto*       armor = object.item ? object.item->As<RE::TESObjectARMO>() : nullptr;
			if (!armor) {
				continue;
			}
			const RE::NiPointer<RE::NiAVObject> part = object.partClone;
			if (!part) {
				continue;
			}
			// one armor fills several slots, each with its own addon mesh
			auto found = std::ranges::find_if(items, [&](const Item& a_item) { return a_item.armor == armor; });
			if (found == items.end()) {
				Item item;
				item.armor = armor;
				item.kept = KeptBecause(a_actor, armor, a_keepSlots);
				items.push_back(item);
				found = items.end() - 1;
			}
			if (found->kept && std::string_view{ found->kept } == "skin"sv) {
				continue;  // nothing to learn from the body
			}
			Counts counts;
			RE::BSVisit::TraverseScenegraphGeometries(part.get(), [&](RE::BSGeometry* a_geometry) {
				CountShape(a_geometry, a_reach, counts);
				return RE::BSVisit::BSVisitControl::kContinue;
			});
			found->counts.Add(counts);
		}
		for (auto& item : items) {
			item.shaft = IsShaft(item.counts);
			item.covered = Covered(item.counts);
			if (!item.kept && item.shaft) {
				item.kept = "schlong or strap-on";
			}
			if (!item.kept && IsTongue(item.counts)) {
				item.kept = "tongue";
			}
		}
		return items;
	}

	std::vector<RE::TESForm*> FindBlocking(RE::Actor* a_actor, std::uint32_t a_zones, float a_reach, std::uint32_t a_keepSlots)
	{
		std::vector<RE::TESForm*> out;
		if ((a_zones & kAllZones) == 0) {
			return out;
		}
		const auto items = Survey(a_actor, a_reach, a_keepSlots);
		bool       penisFreed = false;
		for (const auto& item : items) {
			if (!item.kept && (item.covered & a_zones) != 0) {
				out.push_back(item.armor);
				penisFreed = penisFreed || (item.covered & kPenis) != 0;
			}
		}
		// A penis in use with nothing found on it: a schlong is hidden for as long
		// as the body slot is covered (SOS and TNG both go by the slot, not by the
		// mesh), so a rigid or oddly rigged cuirass would leave it hidden. The body
		// slot's armor goes then.
		if ((a_zones & kPenis) != 0 && !penisFreed) {
			const auto body = static_cast<std::uint32_t>(RE::BGSBipedObjectForm::BipedObjectSlot::kBody);
			for (const auto& item : items) {
				if (!item.kept && (item.armor->GetSlotMask().underlying() & body) != 0 &&
					std::ranges::find(out, static_cast<RE::TESForm*>(item.armor)) == out.end()) {
					out.push_back(item.armor);
				}
			}
		}
		return out;
	}

	std::vector<std::string> Describe(RE::Actor* a_actor, float a_reach, std::uint32_t a_keepSlots)
	{
		std::vector<std::string> out;
		for (const auto& item : Survey(a_actor, a_reach, a_keepSlots)) {
			if (item.kept && std::string_view{ item.kept } == "skin"sv) {
				continue;
			}
			const char* name = item.armor->GetName();
			std::string line = std::format("{} [{:08X}]", name && *name ? name : "(no name)", item.armor->GetFormID());
			bool        any = false;
			for (int z = 0; z < kZoneCount; ++z) {
				if (item.counts.weighted[z] == 0 && item.counts.reached[z] == 0) {
					continue;
				}
				// weighted / within reach, and * where that is enough to count
				line += std::format(" {}{}={}w/{}n", kZones[z].name, (item.covered & kZones[z].bit) ? "*" : "",
					item.counts.weighted[z], item.counts.reached[z]);
				any = true;
			}
			if (!any) {
				line += " covers nothing";
			}
			if (item.kept) {
				line += std::format(" - kept ({})", item.kept);
			}
			out.push_back(std::move(line));
		}
		return out;
	}
}
