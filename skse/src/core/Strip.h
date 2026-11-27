#pragma once

// Procedural stripping, the pure part: which body zones does one skinned shape
// cover? No game types in here, so core-tests can feed it made-up vertex buffers.
//
// A shape covers a zone when enough of its vertices
//   - are WEIGHTED to the zone's bones (a mesh fitted to a 3BA / UBE / BHUNP body
//     carries the labia, anus, genital or breast bones exactly where it lies on
//     them), or
//   - lie WITHIN REACH of the zone's probe points, measured in the bind space of
//     the zone's anchor bone (pelvis, the upper spine for the chest, the head for
//     the mouth, which has no bones of its own). That is
//     the test for a mesh with no such bones: a vanilla cuirass, a male outfit.
// Bind space, not the posed mesh: both the vertex and the probe are taken where
// they sit on the anchor bone at rest, so no skinning is done and nothing here
// depends on the animation playing.
//
// The vertex layout is the engine's own (BSGraphics::VertexDesc): position as
// three floats at the start of every vertex, and for a skinned shape four half
// float weights followed by four byte bone indices at the skinning offset. The
// indices count through the skin instance's bone list.

#include <array>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <span>
#include <string_view>

namespace Core::Strip
{
	// Zone bits, as the scripts pass them (SLOVE_Strip.psc holds the same numbers).
	enum Zone : std::uint32_t
	{
		kVagina = 1,
		kAnus = 2,
		kPenis = 4,
		kBreasts = 8,
		kMouth = 16,
	};
	inline constexpr std::uint32_t kAllZones = kVagina | kAnus | kPenis | kBreasts | kMouth;
	inline constexpr int           kZoneCount = 5;

	// Not a zone: a bone of the penis shaft. A shape weighted to those is a schlong
	// or a strap-on, which is never clothing in the way.
	inline constexpr std::uint8_t kShaftBone = 0x80;
	// Not a zone either: a bone of a tongue mesh. A tongue sits in the mouth by
	// design (SLO VE's own, Fill Her Up's, any HALO-rigged one: "tong1 2"...) and
	// must survive the mouth being uncovered.
	inline constexpr std::uint8_t kTongueBone = 0x40;

	// A vertex counts for a bone from this weight up. Copied weights fade out over
	// a few vertices around the bone; the faint end of that is not "lies on it".
	inline constexpr float kMinWeight = 0.1f;
	// A shape covers a zone from this many vertices up (one stray vertex is noise).
	inline constexpr std::uint32_t kMinVertices = 4;

	struct Vec3
	{
		float x = 0.0f;
		float y = 0.0f;
		float z = 0.0f;
	};

	// p' = rot * p * scale + t, the layout of NiTransform.
	struct Xform
	{
		float rot[3][3] = { { 1.0f, 0.0f, 0.0f }, { 0.0f, 1.0f, 0.0f }, { 0.0f, 0.0f, 1.0f } };
		Vec3  t;
		float scale = 1.0f;
	};

	inline Vec3 Apply(const Xform& a_m, const Vec3& a_p)
	{
		return {
			(a_m.rot[0][0] * a_p.x + a_m.rot[0][1] * a_p.y + a_m.rot[0][2] * a_p.z) * a_m.scale + a_m.t.x,
			(a_m.rot[1][0] * a_p.x + a_m.rot[1][1] * a_p.y + a_m.rot[1][2] * a_p.z) * a_m.scale + a_m.t.y,
			(a_m.rot[2][0] * a_p.x + a_m.rot[2][1] * a_p.y + a_m.rot[2][2] * a_p.z) * a_m.scale + a_m.t.z
		};
	}

	enum class Anchor : std::uint8_t
	{
		Pelvis,
		Spine2,
		Head,
	};
	inline constexpr std::string_view kPelvisBone = "NPC Pelvis [Pelv]";
	inline constexpr std::string_view kSpine2Bone = "NPC Spine2 [Spn2]";
	inline constexpr std::string_view kHeadBone = "NPC Head [Head]";

	// Probe points in the anchor bone's own space (x right, y forward, z up, game
	// units). The two openings are where Accurate Penetration puts its entry points
	// (accurate-penetration.toml, [Vagina.Position] / [Anus.Position] Offset); the
	// penis and breast points are the bones' rest positions in the XPMSSE skeleton;
	// the mouth is the top of the lower front teeth of the vanilla human mouth
	// (tools\tonguefit\measure_mouth.py: forward 8.77, up -3.89 on the head bone).
	// Checked on installed meshes at reach 3: face masks have 28 to 250 vertices in
	// reach, an open-faced helmet and a hood none.
	inline constexpr std::array<Vec3, 1> kVaginaProbes{ { { 0.07f, -1.37f, -3.34f } } };
	inline constexpr std::array<Vec3, 1> kAnusProbes{ { { 0.0f, -4.95f, -1.17f } } };
	inline constexpr std::array<Vec3, 2> kPenisProbes{ { { 0.0f, 2.59f, -0.89f }, { 0.0f, 4.02f, -2.10f } } };
	inline constexpr std::array<Vec3, 1> kMouthProbes{ { { 0.0f, 8.8f, -3.9f } } };
	inline constexpr std::array<Vec3, 4> kBreastProbes{ {
		{ -5.45f, 7.83f, 6.54f },
		{ 5.45f, 7.83f, 6.54f },
		{ -6.78f, 11.54f, 6.51f },
		{ 6.78f, 11.54f, 6.51f },
	} };

	struct ZoneDef
	{
		Zone                  bit;
		std::string_view      name;
		Anchor                anchor;
		std::span<const Vec3> probes;
		float                 reachScale;  // the chest is a wider target than an opening
	};

	inline constexpr std::array<ZoneDef, kZoneCount> kZones{ {
		{ kVagina, "vagina", Anchor::Pelvis, kVaginaProbes, 1.0f },
		{ kAnus, "anus", Anchor::Pelvis, kAnusProbes, 1.0f },
		{ kPenis, "penis", Anchor::Pelvis, kPenisProbes, 1.0f },
		{ kBreasts, "breasts", Anchor::Spine2, kBreastProbes, 1.5f },
		{ kMouth, "mouth", Anchor::Head, kMouthProbes, 1.0f },
	} };

	inline char Lower(char a_c)
	{
		return a_c >= 'A' && a_c <= 'Z' ? static_cast<char>(a_c - 'A' + 'a') : a_c;
	}

	inline bool EqualsNoCase(std::string_view a_a, std::string_view a_b)
	{
		if (a_a.size() != a_b.size()) {
			return false;
		}
		for (std::size_t i = 0; i < a_a.size(); ++i) {
			if (Lower(a_a[i]) != Lower(a_b[i])) {
				return false;
			}
		}
		return true;
	}

	inline bool ContainsNoCase(std::string_view a_text, std::string_view a_word)
	{
		if (a_word.empty() || a_text.size() < a_word.size()) {
			return false;
		}
		for (std::size_t at = 0; at + a_word.size() <= a_text.size(); ++at) {
			if (EqualsNoCase(a_text.substr(at, a_word.size()), a_word)) {
				return true;
			}
		}
		return false;
	}

	// The zones a skin bone belongs to, by its name. Substrings, because every body
	// names these bones its own way around the same words: "NPC L Pussy02",
	// "VaginaB1", "Vagina_L 1", "Clitoral1", "NPC LB Anus2", "Anus_Top_L 1",
	// "NPC Genitals03 [Gen03]", "L Breast02", "NPC L Breast".
	inline std::uint8_t BoneZones(std::string_view a_name)
	{
		std::uint8_t zones = 0;
		if (ContainsNoCase(a_name, "pussy") || ContainsNoCase(a_name, "vagina") || ContainsNoCase(a_name, "clitoral")) {
			zones |= kVagina;
		}
		if (ContainsNoCase(a_name, "anus")) {
			zones |= kAnus;
		}
		if (ContainsNoCase(a_name, "genitals")) {
			zones |= kPenis;
			// base, 01 and 02 sit at the body, where trousers are weighted too; from
			// 03 outward only the penis itself is
			for (const std::string_view shaft : { "genitals03", "genitals04", "genitals05", "genitals06" }) {
				if (ContainsNoCase(a_name, shaft)) {
					zones |= kShaftBone;
				}
			}
		}
		if (ContainsNoCase(a_name, "breast") && !ContainsNoCase(a_name, "magic")) {
			zones |= kBreasts;
		}
		if (ContainsNoCase(a_name, "tong")) {
			zones |= kTongueBone;
		}
		return zones;
	}

	// IEEE half -> float (the engine stores skin weights as halves).
	inline float HalfToFloat(std::uint16_t a_half)
	{
		const std::uint32_t sign = (a_half & 0x8000u) << 16;
		const std::uint32_t exponent = (a_half >> 10) & 0x1Fu;
		const std::uint32_t mantissa = a_half & 0x3FFu;
		std::uint32_t       bits = 0;
		if (exponent == 0) {
			if (mantissa == 0) {
				bits = sign;
			} else {
				// subnormal: shift the mantissa up until its top bit is set
				std::uint32_t m = mantissa;
				std::uint32_t e = 113;  // 127 - 15 + 1
				while ((m & 0x400u) == 0) {
					m <<= 1;
					--e;
				}
				bits = sign | (e << 23) | ((m & 0x3FFu) << 13);
			}
		} else if (exponent == 31) {
			bits = sign | 0x7F800000u | (mantissa << 13);
		} else {
			bits = sign | ((exponent + 112) << 23) | (mantissa << 13);
		}
		float out = 0.0f;
		std::memcpy(&out, &bits, sizeof(out));
		return out;
	}

	// One skinned shape as the engine holds it.
	struct ShapeView
	{
		const std::uint8_t* vertices = nullptr;
		std::uint32_t       count = 0;
		std::uint32_t       stride = 0;
		std::int32_t        skinOffset = -1;  // byte offset of the weights in a vertex, -1 = none

		// per skin bone: BoneZones() of its name
		std::span<const std::uint8_t> boneZones;

		// skin space -> the anchor bone's space, when the shape is skinned to that bone
		const Xform* pelvis = nullptr;
		const Xform* spine2 = nullptr;
		const Xform* head = nullptr;
	};

	struct Counts
	{
		std::array<std::uint32_t, kZoneCount> weighted{};  // vertices weighted to the zone's bones
		std::array<std::uint32_t, kZoneCount> reached{};      // vertices within reach of a probe
		std::uint32_t                         shaft = 0;   // vertices weighted to the penis shaft
		std::uint32_t                         tongue = 0;  // vertices weighted to tongue bones

		void Add(const Counts& a_other)
		{
			for (int z = 0; z < kZoneCount; ++z) {
				weighted[z] += a_other.weighted[z];
				reached[z] += a_other.reached[z];
			}
			shaft += a_other.shaft;
			tongue += a_other.tongue;
		}
	};

	// Count a shape's vertices per zone into a_out. a_reach <= 0 skips the reach
	// test (weights only).
	inline void Count(const ShapeView& a_shape, float a_reach, Counts& a_out)
	{
		if (!a_shape.vertices || a_shape.count == 0 || a_shape.stride < 3 * sizeof(float)) {
			return;
		}
		const bool skinned = a_shape.skinOffset >= 0 && !a_shape.boneZones.empty() &&
		                     static_cast<std::uint32_t>(a_shape.skinOffset) + 12 <= a_shape.stride;

		for (std::uint32_t v = 0; v < a_shape.count; ++v) {
			const std::uint8_t* at = a_shape.vertices + static_cast<std::size_t>(v) * a_shape.stride;

			if (skinned) {
				std::uint16_t halves[4];
				std::uint8_t  bones[4];
				std::memcpy(halves, at + a_shape.skinOffset, sizeof(halves));
				std::memcpy(bones, at + a_shape.skinOffset + sizeof(halves), sizeof(bones));
				std::uint8_t zones = 0;
				for (int k = 0; k < 4; ++k) {
					if (bones[k] < a_shape.boneZones.size() && a_shape.boneZones[bones[k]] != 0 &&
						HalfToFloat(halves[k]) >= kMinWeight) {
						zones |= a_shape.boneZones[bones[k]];
					}
				}
				for (int z = 0; z < kZoneCount; ++z) {
					if (zones & kZones[z].bit) {
						++a_out.weighted[z];
					}
				}
				if (zones & kShaftBone) {
					++a_out.shaft;
				}
				if (zones & kTongueBone) {
					++a_out.tongue;
				}
			}

			if (a_reach > 0.0f && (a_shape.pelvis || a_shape.spine2 || a_shape.head)) {
				Vec3 skin;
				std::memcpy(&skin, at, sizeof(skin));
				if (!std::isfinite(skin.x) || !std::isfinite(skin.y) || !std::isfinite(skin.z)) {
					continue;
				}
				const Vec3 atPelvis = a_shape.pelvis ? Apply(*a_shape.pelvis, skin) : Vec3{};
				const Vec3 atSpine = a_shape.spine2 ? Apply(*a_shape.spine2, skin) : Vec3{};
				const Vec3 atHead = a_shape.head ? Apply(*a_shape.head, skin) : Vec3{};
				for (int z = 0; z < kZoneCount; ++z) {
					const auto& zone = kZones[z];
					const Xform* anchor = zone.anchor == Anchor::Pelvis ? a_shape.pelvis :
					                      zone.anchor == Anchor::Spine2 ? a_shape.spine2 : a_shape.head;
					if (!anchor) {
						continue;
					}
					const Vec3& p = zone.anchor == Anchor::Pelvis ? atPelvis : zone.anchor == Anchor::Spine2 ? atSpine : atHead;
					const float reach = a_reach * zone.reachScale;
					for (const auto& probe : zone.probes) {
						const float dx = p.x - probe.x;
						const float dy = p.y - probe.y;
						const float dz = p.z - probe.z;
						if (dx * dx + dy * dy + dz * dz <= reach * reach) {
							++a_out.reached[z];
							break;
						}
					}
				}
			}
		}
	}

	// A schlong or a strap-on: never stripped, whatever it lies on.
	inline bool IsShaft(const Counts& a_counts)
	{
		return a_counts.shaft >= kMinVertices;
	}

	// A tongue: it belongs in the mouth and is never stripped.
	inline bool IsTongue(const Counts& a_counts)
	{
		return a_counts.tongue >= kMinVertices;
	}

	// The zones an item covers, as a Zone bitmask.
	inline std::uint32_t Covered(const Counts& a_counts)
	{
		std::uint32_t zones = 0;
		for (int z = 0; z < kZoneCount; ++z) {
			if (a_counts.weighted[z] >= kMinVertices || a_counts.reached[z] >= kMinVertices) {
				zones |= kZones[z].bit;
			}
		}
		return zones;
	}
}
