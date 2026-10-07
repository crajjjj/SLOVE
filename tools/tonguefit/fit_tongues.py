"""Beast-race tongue meshes: the ten standard tongues, moved to where a Khajiit or
Argonian mouth is.

    python tools\\tonguefit\\fit_tongues.py            regenerate both sets from FITS
    python tools\\tonguefit\\fit_tongues.py --check    fail if the shipped sets are not what FITS produces
    python tools\\tonguefit\\fit_tongues.py --report   print where each mesh sits (head-bone coordinates)

Why: the tongue meshes (dist\\meshes\\SLOVE\\tongues\\linga1..10.nif) are fitted to a human
mouth. A beast muzzle carries the mouth further forward and higher, so the human fit comes
out through the underside of the jaw. SLOVE.esp therefore gives every tongue armor a
Khajiit and an Argonian armor addon that point at the copies this script writes, and the
game picks the addon by the wearer's race - no script involved (the same shape as the UBE
option, see optional\\UBESupport\\README.md).

How a copy is made, without touching a vertex. The tongue is skinned to five bones:
'NPC Head [Head]' (the actor's own head bone) and 'tong1 2'..'tong1 5', a chain that
hangs off 'tong1 1', which is a child of the head bone inside the nif. HDT-SMP clones
that chain under the actor's real head bone with the local transforms the nif gives it.
So moving the whole tongue by d, in head-bone coordinates, takes two edits:
  - 'tong1 1' local translation += d      (the chain, and every vertex weighted to it)
  - the head bone's bind translation += d  (the vertices weighted to the head itself)
plus the bounding spheres, for culling. Every vertex then moves by exactly d and the
mesh cannot distort; verify() proves that for each bone of each file written.

The numbers in FITS are measured, not tuned in game: front teeth and tooth line of the
vanilla mouth head parts (MaleMouthKhajiit, MouthKhajiitFemale, MouthArgonian) against
MouthHuman / MouthHumanF, all in head-bone coordinates (x right, y forward, z up, about
one game unit each). Change a number, rerun, look in game. The ten armor addons per race
live in SLOVE.esp and do not change when the numbers do.

Standard library only.
"""
import os
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = os.path.join(ROOT, "dist", "meshes", "SLOVE", "tongues")

# race folder -> (right, forward, up) in head-bone coordinates
FITS = {
    "khajiit": (0.0, 3.0, 0.55),   # teeth 2.8 (m) / 3.1 (f) further forward, tooth line 0.5 higher
    "argonian": (0.0, 5.0, 2.2),   # teeth 4.9 / 5.2 further forward, tooth line 2.0 / 2.5 higher
}
HEAD = "NPC Head [Head]"
CHAIN_ROOT = "tong1 1"


class Nif:
    """Just enough of a Skyrim SE nif: block table, node transforms, one skinned shape."""

    def __init__(self, data):
        self.d = data
        pos = data.index(b"\n") + 1
        pos += 4 + 1 + 4  # version, endian, user version
        self.num_blocks, bs_version = struct.unpack_from("<II", data, pos); pos += 8
        if bs_version != 100:
            raise ValueError("not a Skyrim SE nif (BS version %d)" % bs_version)
        for _ in range(3):  # author, process script, export script
            pos += 1 + data[pos]
        num_types, = struct.unpack_from("<H", data, pos); pos += 2
        self.types = []
        for _ in range(num_types):
            n, = struct.unpack_from("<I", data, pos); pos += 4
            self.types.append(data[pos:pos + n].decode("latin1")); pos += n
        self.type_index = struct.unpack_from("<%dH" % self.num_blocks, data, pos); pos += 2 * self.num_blocks
        sizes = struct.unpack_from("<%dI" % self.num_blocks, data, pos); pos += 4 * self.num_blocks
        num_strings, _longest = struct.unpack_from("<II", data, pos); pos += 8
        self.strings = []
        for _ in range(num_strings):
            n, = struct.unpack_from("<I", data, pos); pos += 4
            self.strings.append(data[pos:pos + n].decode("latin1")); pos += n
        num_groups, = struct.unpack_from("<I", data, pos); pos += 4 + 4 * num_groups
        self.offsets = []
        for size in sizes:
            self.offsets.append(pos); pos += size
        num_roots, = struct.unpack_from("<I", data, pos)  # the footer: root count + root refs
        if pos + 4 + 4 * num_roots != len(data):
            raise ValueError("block table does not add up to the file size")

    def kind(self, block):
        return self.types[self.type_index[block] & 0x7FFF]

    def av_object(self, block):
        """name, offset of the translation, translation, rotation (9), scale, offset after NiAVObject"""
        d, p = self.d, self.offsets[block]
        name_idx, num_extra = struct.unpack_from("<iI", d, p); p += 8 + 4 * num_extra + 4 + 4
        t = struct.unpack_from("<3f", d, p)
        r = struct.unpack_from("<9f", d, p + 12)
        s, = struct.unpack_from("<f", d, p + 48)
        name = self.strings[name_idx] if 0 <= name_idx < len(self.strings) else ""
        return name, p, t, r, s, p + 56

    def nodes(self):
        """block -> (name, translation offset, A = scale * rotation (9), translation, children)"""
        out = {}
        for block in range(self.num_blocks):
            if self.kind(block) in ("NiNode", "BSFadeNode"):
                name, t_at, t, r, s, p = self.av_object(block)
                count, = struct.unpack_from("<I", self.d, p)
                out[block] = (name, t_at, [s * x for x in r], t, struct.unpack_from("<%di" % count, self.d, p + 4))
        return out

    def world(self):
        """block -> (name, A (9), t): p_world = A * p_local + t"""
        nodes = self.nodes()
        children = {c for n in nodes.values() for c in n[4]}
        out = {}
        stack = [(b, [1, 0, 0, 0, 1, 0, 0, 0, 1], (0.0, 0.0, 0.0)) for b in nodes if b not in children]
        while stack:
            block, pa, pt = stack.pop()
            name, _t_at, a, t, kids = nodes[block]
            wa = mul(pa, a)
            wt = add(apply(pa, t), pt)
            out[block] = (name, wa, wt)
            stack.extend((k, wa, wt) for k in kids if k in nodes)
        return out

    def shape(self):
        """The one skinned BSTriShape: bound-centre offset, skin instance block, vertex positions."""
        shapes = [b for b in range(self.num_blocks) if self.kind(b) == "BSTriShape"]
        if len(shapes) != 1:
            raise ValueError("expected one BSTriShape, found %d" % len(shapes))
        _name, _t_at, _t, _r, _s, p = self.av_object(shapes[0])
        skin, = struct.unpack_from("<i", self.d, p + 16)
        return p, skin

    def skin(self, skin_block):
        """bones: (name, node block, bind A = scale * rotation, bind t, offset of bind t, offset of the bone's bound centre)"""
        d, p = self.d, self.offsets[skin_block]
        data_ref, partition, _root, count = struct.unpack_from("<3iI", d, p)
        refs = struct.unpack_from("<%di" % count, d, p + 16)
        q = self.offsets[data_ref] + 52
        num_bones, has_weights = struct.unpack_from("<IB", d, q); q += 5
        bones = []
        for b in range(num_bones):
            rot = struct.unpack_from("<9f", d, q)
            t = struct.unpack_from("<3f", d, q + 36)
            scale, = struct.unpack_from("<f", d, q + 48)
            bones.append((self.av_object(refs[b])[0], refs[b], [scale * x for x in rot], t, q + 36, q + 52))
            q += 52 + 16
            n, = struct.unpack_from("<H", d, q); q += 2 + (n * 6 if has_weights else 0)
        return bones, partition

    def vertices(self, partition):
        d, p = self.d, self.offsets[partition]
        _parts, data_size, vertex_size = struct.unpack_from("<3I", d, p)
        return [struct.unpack_from("<3f", d, p + 20 + i * vertex_size) for i in range(data_size // vertex_size)]


def mul(a, b):
    return [sum(a[r * 3 + k] * b[k * 3 + c] for k in range(3)) for r in range(3) for c in range(3)]


def apply(a, v):
    return tuple(sum(a[r * 3 + c] * v[c] for c in range(3)) for r in range(3))


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def rest(nif, bone, world, v):
    """Where the engine puts skin-space point v through this bone, in the nif's own skeleton."""
    _name, block, bind_a, bind_t, _t_at, _bound_at = bone
    _n, wa, wt = world[block]
    return add(apply(wa, add(apply(bind_a, v), bind_t)), wt)


def fit(data, d_local):
    """The nif with the tongue moved by d_local (head-bone coordinates)."""
    nif = Nif(data)
    out = bytearray(data)
    nodes = nif.nodes()
    world = nif.world()
    bound_at, skin_block = nif.shape()
    bones, _partition = nif.skin(skin_block)
    head = [b for b in bones if b[0] == HEAD]
    roots = [n for n in nodes.values() if n[0] == CHAIN_ROOT]
    if len(head) != 1 or len(roots) != 1:
        raise ValueError("expected one '%s' bind and one '%s' node" % (HEAD, CHAIN_ROOT))
    if {b[0] for b in bones} - {HEAD, "tong1 2", "tong1 3", "tong1 4", "tong1 5"}:
        raise ValueError("unexpected bone in the skin: %s" % sorted(b[0] for b in bones))

    def shift(offset, delta):
        old = struct.unpack_from("<3f", out, offset)
        struct.pack_into("<3f", out, offset, *(o + x for o, x in zip(old, delta)))

    shift(roots[0][1], d_local)   # the chain root, a child of the head bone
    shift(head[0][4], d_local)    # the head bind: skin space -> head bone
    shift(head[0][5], d_local)    # the head bone's own bounding sphere
    d_world = apply(world[head[0][1]][1], d_local)
    shift(bound_at, d_world)      # the shape's bounding sphere, in skin space
    return bytes(out), d_world


def verify(before, after, d_world):
    """Every vertex moves by d_world through every bone: nothing stretches, nothing else changed."""
    a, b = Nif(before), Nif(after)
    if len(before) != len(after):
        return "the file size changed"
    changed = sum(1 for x, y in zip(before, after) if x != y)
    if changed > 4 * 12:
        return "%d bytes changed, more than four vectors" % changed
    wa, wb = a.world(), b.world()
    bones_a, part_a = a.skin(a.shape()[1])
    bones_b, part_b = b.skin(b.shape()[1])
    verts = a.vertices(part_a)
    if verts != b.vertices(part_b):
        return "vertex data changed"
    sample = verts[::37]
    worst = 0.0
    for bone_a, bone_b in zip(bones_a, bones_b):
        for v in sample:
            was = rest(a, bone_a, wa, v)
            now = rest(b, bone_b, wb, v)
            if max(abs(w - x) for w, x in zip(was, v)) > 0.02:
                return "the source mesh is not at rest through %s" % bone_a[0]
            worst = max(worst, max(abs(n - w - x) for n, w, x in zip(now, was, d_world)))
    return None if worst < 0.002 else "moved unevenly (worst error %.4f)" % worst


def head_local(nif):
    """The mesh in head-bone coordinates: (min, max) per axis."""
    bones, partition = nif.skin(nif.shape()[1])
    head = next(b for b in bones if b[0] == HEAD)
    pts = [add(apply(head[2], v), head[3]) for v in nif.vertices(partition)]
    return [(min(p[i] for p in pts), max(p[i] for p in pts)) for i in range(3)]


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    failed = False
    for race, d_local in FITS.items():
        folder = os.path.join(SOURCE, race)
        if mode == "":
            os.makedirs(folder, exist_ok=True)
        for n in range(1, 11):
            name = "linga%d.nif" % n
            before = open(os.path.join(SOURCE, name), "rb").read()
            after, d_world = fit(before, d_local)
            problem = verify(before, after, d_world)
            target = os.path.join(folder, name)
            if problem:
                print("FAIL  %s\\%s: %s" % (race, name, problem))
                failed = True
            elif mode == "--check":
                if not os.path.exists(target) or open(target, "rb").read() != after:
                    print("FAIL  %s\\%s is not what FITS produces - rerun this script without arguments" % (race, name))
                    failed = True
            elif mode == "--report":
                y, z = head_local(Nif(after))[1:]
                print("%-9s %-12s forward %5.2f..%5.2f  up %5.2f..%5.2f" % (race, name, y[0], y[1], z[0], z[1]))
            else:
                open(target, "wb").write(after)
        if not failed and mode in ("", "--check"):
            print("%-9s right %+.2f forward %+.2f up %+.2f: 10 meshes %s"
                  % (race, d_local[0], d_local[1], d_local[2], "written" if mode == "" else "match"))
    if mode == "--report":
        for n in range(1, 11):
            y, z = head_local(Nif(open(os.path.join(SOURCE, "linga%d.nif" % n), "rb").read()))[1:]
            print("%-9s %-12s forward %5.2f..%5.2f  up %5.2f..%5.2f" % ("human", "linga%d.nif" % n, y[0], y[1], z[0], z[1]))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
