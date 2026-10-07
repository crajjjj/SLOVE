"""BodySlide projects for SLO VE's tongue meshes, so a user can nudge the fit to a head.

    python tools\\tonguefit\\make_bodyslide.py            write the projects
    python tools\\tonguefit\\make_bodyslide.py --check    fail if the shipped files are not what this writes

Why SLO VE needs its own: the BodySlide projects that exist for these tongues (HALOS Human
HDT Tongueslide, and the one inside Fill Her Up) build into meshes\\morten\\lingas with the
slot-55 partition. SLO VE equips its own copies under meshes\\SLOVE\\tongues on slot 44, so
neither reaches them, and their output copied across would be invisible.

What is written (all of it generated; never hand-edit, rerun this instead):

  dist\\CalienteTools\\BodySlide\\
    SliderSets\\SLOVE Tongues.osp       30 sets: model 01-10 for humans, Khajiit and Argonians
    SliderGroups\\SLOVE Tongues.xml     one group per fit, so each can have its own preset
    ShapeData\\SLOVE Tongues\\           the base nif of every set + one .osd per model
  optional\\UBESupport\\CalienteTools\\BodySlide\\   the same for the ten UBE-fitted meshes

Each base nif is the mesh the game loads without BodySlide plus one thing only tools read
(the preview transform, below), so a build with every slider at 0 gives the shipped
geometry and rig again (BodySlide also writes the blocks in another order), and --check
fails when a mesh changed and this was not rerun. The Khajiit and Argonian copies differ
from the human mesh in bone and bind data only (fit_tongues.py), not in a single vertex, so
the three sets of a model share one .osd.

The preview transform. To judge a fit one loads the set in Outfit Studio and imports a head
beside it (File > Import > From NIF). OS places every skinned shape by the transform at the
top of its NiSkinData ("global to skin"). The game ignores that transform - a vanilla head
carries (0, 1.55, -120.34) there, the mouth part beside it carries none, and both render on
the same head bone - and the tongue meshes carry none, so OS would draw the tongue from its
raw coordinates: about 1.5 units lower against the head than the game puts it, and with
none of the Khajiit / Argonian shift, which lives in the bones. The base nifs therefore get
the transform that draws the tongue where the game will: its place in head-bone
coordinates (from its own head bind) plus where a head mesh is drawn (HEAD_AT).

The sliders are our own data, computed here from the vertices (no third-party slider files
are shipped). A BodySlide slider is a per-vertex offset scaled by the slider value, in the
nif's own coordinates (x right, y forward, z up, game units):

  Tongue Forward / Back / Up / Down     move the whole tongue, MOVE units at 100%
  Tongue Bigger / Smaller               scale about the root
  Tongue Longer / Shorter               scale along the root-to-tip line
  Tongue Wider / Narrower               scale sideways, about its own centre line
  Tongue Thicker / Thinner              scale across the tongue, about its own centre line
  Tongue Tilt Up / Down                 turn about the root, TILT degrees at 100%

Sliders move the mesh, not the physics bones: fine for a nudge of a unit or two. The large
beast-race offsets stay in the bone-shifted copies; these sliders go on top of them.

Standard library only.
"""
import math
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fit_tongues as ft

ROOT = ft.ROOT
MOVE = 3.0     # game units at 100%
SCALE = 0.30   # fraction at 100%
TILT = 15.0    # degrees at 100%

# Where Outfit Studio draws the origin of the head bone for a head mesh: vanilla-style heads
# (raw vertices around the bone, the offset in their global-to-skin transform) and the UBE /
# High Poly Head style (raw vertices at head height, the offset in the head bind) agree to
# about 0.15 of a unit.
HEAD_AT = {"": (0.0, -1.55, 120.34), "UBE": (0.16, -1.66, 120.34)}

SLIDERS = ("Tongue Forward", "Tongue Back", "Tongue Up", "Tongue Down",
           "Tongue Bigger", "Tongue Smaller", "Tongue Longer", "Tongue Shorter",
           "Tongue Wider", "Tongue Narrower", "Tongue Thicker", "Tongue Thinner",
           "Tongue Tilt Up", "Tongue Tilt Down")


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def scaled(a, k):
    return (a[0] * k, a[1] * k, a[2] * k)


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def unit(a):
    n = math.sqrt(dot(a, a))
    return scaled(a, 1.0 / n) if n > 1e-9 else (0.0, 0.0, 0.0)


def bone_origins(nif, bones):
    """Where each tongue bone sits in skin space: the point its bind transform maps to 0."""
    out = {}
    for name, _block, a, t, _t_at, _bound_at in bones:
        s2 = a[0] * a[0] + a[1] * a[1] + a[2] * a[2]  # the bind matrix is scale * rotation
        inv = [a[c * 3 + r] / s2 for r in range(3) for c in range(3)]
        out[name] = scaled(ft.apply(inv, t), -1.0)
    return out


def closest_on_line(points, v):
    """The closest point to v on the polyline through points, ends extended."""
    best, best_d = points[0], float("inf")
    last = len(points) - 2
    for i in range(len(points) - 1):
        a, b = points[i], points[i + 1]
        ab = sub(b, a)
        k = dot(sub(v, a), ab) / max(dot(ab, ab), 1e-12)
        if i > 0:
            k = max(k, 0.0)
        if i < last:
            k = min(k, 1.0)
        c = ft.add(a, scaled(ab, k))
        d = dot(sub(v, c), sub(v, c))
        if d < best_d:
            best, best_d = c, d
    return best


def slider_data(nif):
    """slider name -> [(vertex index, dx, dy, dz)], for the one shape of this nif."""
    bones, partition = nif.skin(nif.shape()[1])
    verts = nif.vertices(partition)
    at = bone_origins(nif, bones)
    chain = [at[n] for n in ("tong1 2", "tong1 3", "tong1 4", "tong1 5")]
    back = unit(sub(chain[0], chain[1]))
    # the root: on the bone line, as far back as the mesh reaches
    reach = max(dot(sub(v, chain[0]), back) for v in verts)
    root = ft.add(chain[0], scaled(back, reach))
    tip = max(verts, key=lambda v: dot(sub(v, root), sub(v, root)))
    along = unit(sub(tip, root))
    side = (1.0, 0.0, 0.0)
    across = unit(cross(along, side))
    # The tongue's own centre line: centroids of slices along the root-to-tip line.
    # Width and thickness scale about it, so they change the cross-section and do not
    # push the tongue sideways or down (the bones do not run through its middle).
    spans = [dot(sub(v, root), along) for v in verts]
    low, high = min(spans), max(spans)
    slices = [[] for _ in range(14)]
    for v, t in zip(verts, spans):
        slices[min(13, int((t - low) / max(high - low, 1e-9) * 14))].append(v)
    line = [tuple(sum(p[k] for p in s) / len(s) for k in range(3)) for s in slices if s]
    angle = math.radians(TILT)
    cos_a, sin_a = math.cos(angle), math.sin(angle)

    def tilt(v, sign):
        y, z = v[1] - root[1], v[2] - root[2]
        s = sin_a * sign
        return (0.0, (y * cos_a - z * s) - y, (y * s + z * cos_a) - z)

    def about_line(v, direction):
        r = sub(v, closest_on_line(line, v))
        return scaled(direction, dot(r, direction))

    rules = {
        "Tongue Forward": lambda v: (0.0, MOVE, 0.0),
        "Tongue Back": lambda v: (0.0, -MOVE, 0.0),
        "Tongue Up": lambda v: (0.0, 0.0, MOVE),
        "Tongue Down": lambda v: (0.0, 0.0, -MOVE),
        "Tongue Bigger": lambda v: scaled(sub(v, root), SCALE),
        "Tongue Smaller": lambda v: scaled(sub(v, root), -SCALE),
        "Tongue Longer": lambda v: scaled(along, dot(sub(v, root), along) * SCALE),
        "Tongue Shorter": lambda v: scaled(along, dot(sub(v, root), along) * -SCALE),
        "Tongue Wider": lambda v: scaled(about_line(v, side), SCALE),
        "Tongue Narrower": lambda v: scaled(about_line(v, side), -SCALE),
        "Tongue Thicker": lambda v: scaled(about_line(v, across), SCALE),
        "Tongue Thinner": lambda v: scaled(about_line(v, across), -SCALE),
        "Tongue Tilt Up": lambda v: tilt(v, 1.0),     # the tip rises
        "Tongue Tilt Down": lambda v: tilt(v, -1.0),
    }
    out = {}
    for name in SLIDERS:
        rows = []
        for i, v in enumerate(verts):
            d = rules[name](v)
            if max(abs(d[0]), abs(d[1]), abs(d[2])) > 1e-5:
                rows.append((i, d[0], d[1], d[2]))
        out[name] = rows
    return out, len(verts)


def with_preview(mesh, head_at):
    """The mesh with the global-to-skin transform that shows it where the game draws it."""
    nif = ft.Nif(mesh)
    skin_block = nif.shape()[1]
    bones, _partition = nif.skin(skin_block)
    t_at = next(b for b in bones if b[0] == ft.HEAD)[4]
    rot = struct.unpack_from("<9f", mesh, t_at - 36)
    t = struct.unpack_from("<3f", mesh, t_at)
    scale, = struct.unpack_from("<f", mesh, t_at + 12)
    # drawn at: scale * rot * v + t + head_at. The file stores the inverse of that.
    inverse = [rot[c * 3 + r] for r in range(3) for c in range(3)]
    offset = scaled(ft.apply(inverse, ft.add(t, head_at)), -1.0 / scale)
    data_block, = struct.unpack_from("<i", mesh, nif.offsets[skin_block])
    out = bytearray(mesh)
    struct.pack_into("<13f", out, nif.offsets[data_block], *inverse, *offset, 1.0 / scale)
    return bytes(out)


def shape_name(nif):
    shapes = [b for b in range(nif.num_blocks) if nif.kind(b) == "BSTriShape"]
    return nif.av_object(shapes[0])[0]


def osd_bytes(target, data):
    out = bytearray(b"\x00DSO") + struct.pack("<II", 1, len(data))
    for name in SLIDERS:
        key = (target + name).encode("ascii")
        rows = data[name]
        out += struct.pack("<B", len(key)) + key + struct.pack("<H", len(rows))
        for i, x, y, z in rows:
            out += struct.pack("<H3f", i, x, y, z)
    return bytes(out)


def osp_text(sets):
    """sets: (set name, data folder, source nif, output path, output file, shape, osd file)"""
    lines = ['<?xml version="1.0" encoding="UTF-8"?>', '<SliderSetInfo version="1">']
    for name, folder, source, out_path, out_file, shape, osd in sets:
        lines += ['    <SliderSet name="%s">' % name,
                  "        <DataFolder>%s</DataFolder>" % folder,
                  "        <SourceFile>%s</SourceFile>" % source,
                  "        <OutputPath>%s</OutputPath>" % out_path,
                  '        <OutputFile GenWeights="false">%s</OutputFile>' % out_file,
                  '        <Shape target="%s">%s</Shape>' % (shape, shape)]
        for slider in SLIDERS:
            lines += ['        <Slider name="%s" invert="false" default="0">' % slider,
                      '            <Data name="%s%s" target="%s" local="true">%s\\%s%s</Data>'
                      % (shape, slider, shape, osd, shape, slider),
                      "        </Slider>"]
        lines.append("    </SliderSet>")
    lines.append("</SliderSetInfo>")
    return "\r\n".join(lines) + "\r\n"


def groups_text(groups):
    lines = ['<?xml version="1.0" encoding="UTF-8"?>', "<SliderGroups>"]
    for group, members in groups:
        lines.append('    <Group name="%s">' % group)
        lines += ['        <Member name="%s"/>' % m for m in members]
        lines.append("    </Group>")
    lines.append("</SliderGroups>")
    return "\r\n".join(lines) + "\r\n"


def plan():
    """Every file this script owns: path -> bytes."""
    files = {}
    meshes = os.path.join(ROOT, "dist", "meshes", "SLOVE", "tongues")
    core = os.path.join(ROOT, "dist", "CalienteTools", "BodySlide")
    folder = "SLOVE Tongues"
    fits = (("", "", "meshes\\SLOVE\\tongues"),
            (" Khajiit", "khajiit", "meshes\\SLOVE\\tongues\\khajiit"),
            (" Argonian", "argonian", "meshes\\SLOVE\\tongues\\argonian"))
    sets, groups = [], [("SLOVE Tongues" + suffix, []) for suffix, _sub, _out in fits]
    for n in range(1, 11):
        base = open(os.path.join(meshes, "linga%d.nif" % n), "rb").read()
        nif = ft.Nif(base)
        shape = shape_name(nif)
        data, count = slider_data(nif)
        osd = "SLOVE Tongue %02d.osd" % n
        files[os.path.join(core, "ShapeData", folder, osd)] = osd_bytes(shape, data)
        for g, (suffix, subdir, out_path) in enumerate(fits):
            mesh = base if not subdir else open(os.path.join(meshes, subdir, "linga%d.nif" % n), "rb").read()
            if subdir and ft.Nif(mesh).vertices(ft.Nif(mesh).skin(ft.Nif(mesh).shape()[1])[1]) != nif.vertices(nif.skin(nif.shape()[1])[1]):
                raise ValueError("%s\\linga%d.nif no longer shares its vertices with the standard mesh" % (subdir, n))
            name = "SLOVE Tongue %02d%s" % (n, suffix)
            files[os.path.join(core, "ShapeData", folder, name + ".nif")] = with_preview(mesh, HEAD_AT[""])
            sets.append((name, folder, name + ".nif", out_path, "linga%d" % n, shape, osd))
            groups[g][1].append(name)
    sets.sort(key=lambda s: (s[3], s[0]))
    files[os.path.join(core, "SliderSets", "SLOVE Tongues.osp")] = osp_text(sets).encode("utf-8")
    files[os.path.join(core, "SliderGroups", "SLOVE Tongues.xml")] = groups_text(groups).encode("utf-8")

    ube_meshes = os.path.join(ROOT, "optional", "UBESupport", "meshes", "!UBE", "SLOVE", "tongues")
    ube = os.path.join(ROOT, "optional", "UBESupport", "CalienteTools", "BodySlide")
    folder = "SLOVE Tongues UBE"
    sets, members = [], []
    for n in range(1, 11):
        base = open(os.path.join(ube_meshes, "linga%d.nif" % n), "rb").read()
        nif = ft.Nif(base)
        shape = shape_name(nif)
        data, count = slider_data(nif)
        name = "SLOVE Tongue %02d UBE" % n
        files[os.path.join(ube, "ShapeData", folder, name + ".nif")] = with_preview(base, HEAD_AT["UBE"])
        files[os.path.join(ube, "ShapeData", folder, name + ".osd")] = osd_bytes(shape, data)
        sets.append((name, folder, name + ".nif", "meshes\\!UBE\\SLOVE\\tongues", "linga%d" % n, shape, name + ".osd"))
        members.append(name)
    files[os.path.join(ube, "SliderSets", "SLOVE Tongues UBE.osp")] = osp_text(sets).encode("utf-8")
    files[os.path.join(ube, "SliderGroups", "SLOVE Tongues UBE.xml")] = groups_text([("SLOVE Tongues UBE", members)]).encode("utf-8")
    return files


def main():
    check = len(sys.argv) > 1 and sys.argv[1] == "--check"
    files = plan()
    stale = []
    for path, data in files.items():
        if check:
            if not os.path.exists(path) or open(path, "rb").read() != data:
                stale.append(os.path.relpath(path, ROOT))
        else:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            open(path, "wb").write(data)
    if stale:
        print("FAIL  %d BodySlide file(s) are not what this script writes, e.g. %s - rerun it without arguments" % (len(stale), stale[0]))
        return 1
    total = sum(len(d) for d in files.values())
    print("BodySlide tongue projects: %d files, %.1f MB %s" % (len(files), total / 1e6, "match" if check else "written"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
