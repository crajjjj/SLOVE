"""Where the lower front teeth are while a tongue is out: the measurement behind FITS.

    python tools\\tonguefit\\measure_mouth.py [folder]            print the landmarks and the offsets
    python tools\\tonguefit\\measure_mouth.py [folder] --check    fail if FITS is not what this measures

[folder] holds the morph files of the vanilla mouth head parts (mouthhumanf.tri,
mouthkhajiitfemale.tri, malemouthkhajiit.tri, mouthargonian.tri, from
meshes\\actors\\character\\character assets\\mouth), extracted, or is the game's Data folder:
they are then read out of 'Skyrim - Meshes0.bsa', which needs the python package lz4.
Without [folder] the game is looked for where build.ps1 looks (SKYRIM_GAME_PATH).

What is measured. A tongue hangs on the skull and only shows while SLO VE holds the mouth
in the tongue-out preset (tongueoutphonemeoverride, read here from the shipped expression
JSONs: while a tongue armor is worn BuildTickPreset takes ALL 16 phoneme channels from it).
The one thing a scene still adds to the mouth is the mood of its expression preset
(fields 30 and 31, id and strength). So a face is the tongue-out preset plus one mood, and
there is one face per preset row of the three JSONs. A mouth part's .tri gives its base
shape and one morph per phoneme and mood; a vanilla mouth part is bound to the head bone
with the identity, so its .tri coordinates are head-bone coordinates (x right, y forward,
z up), the ones fit_tongues.py works in.

The landmark is the top of the lower front teeth: of the vertices near the mid-plane that
BigAah moves by more than half of its largest delta (the jaw's half of the part, whatever
the preset), the ones at the front of the posed mouth. An offset is the beast landmark
minus the human female's, both at the median face; the Khajiit one is the mean of the two
sexes, whose teeth stand half a unit apart.

Exit code 0 = measured (and, with --check, FITS agrees), 1 = FITS disagrees, 2 = the files
could not be read (no game here, no lz4): a build treats that as "not checked".

Standard library only, lz4 only for reading the archive.
"""
import json
import os
import statistics
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fit_tongues as ft

MOUTH = "meshes\\actors\\character\\character assets\\mouth"
HUMAN = "mouthhumanf.tri"
PARTS = {"khajiit": ("mouthkhajiitfemale.tri", "malemouthkhajiit.tri"), "argonian": ("mouthargonian.tri",)}
PHONEMES = ("Aah", "BigAah", "BMP", "ChJSh", "DST", "Eee", "Eh", "FV", "I", "K", "N", "Oh", "OohQ", "R", "Th", "W")
MOODS = ("DialogueAnger", "DialogueFear", "DialogueHappy", "DialogueSad", "DialogueSurprise", "DialoguePuzzled",
         "DialogueDisgusted", None, "MoodAnger", "MoodFear", "MoodHappy", "MoodSad", "MoodSurprise", "MoodPuzzled",
         "MoodDisgusted", "CombatAnger", "CombatShout")
PRESETS = os.path.join(ft.ROOT, "dist", "SKSE", "Plugins", "StorageUtilData", "SLOVE")
PRESET_FILES = ("PCExpressions.json", "MaleExpressions.json", "FemaleExpressions.json")
HOLD_KEY = "tongueoutphonemeoverride"
TOLERANCE = 0.06  # FITS is written to 0.05


class CannotMeasure(Exception):
    pass


def from_archive(path, names):
    """The named files of the mouth folder out of a Skyrim SE (v105) archive."""
    try:
        import lz4.frame
    except ImportError:
        raise CannotMeasure("reading %s needs the python package lz4 (pip install lz4)" % os.path.basename(path))
    out = {}
    with open(path, "rb") as f:
        magic, version, _offset, flags, folders, _files, _fl, names_len, _ff = struct.unpack("<4sIIIIIIII", f.read(36))
        if magic != b"BSA\0" or version != 105:
            raise CannotMeasure("%s is not a Skyrim SE archive" % path)
        records = [struct.unpack("<QIIQ", f.read(24)) for _ in range(folders)]
        entries = []
        for _hash, count, _unk, _at in records:
            folder = f.read(f.read(1)[0])[:-1].decode("latin1")
            entries += [(folder,) + struct.unpack("<QII", f.read(16))[1:] for _ in range(count)]
        for (folder, size, offset), name in zip(entries, f.read(names_len).split(b"\0")):
            name = name.decode("latin1")
            if folder != MOUTH or name not in names:
                continue
            packed = bool(flags & 0x4) != bool(size & 0x40000000)
            size &= 0x3FFFFFFF
            f.seek(offset)
            if flags & 0x100:  # the file's path, stored again in front of its data
                skip = f.read(1)[0]
                f.seek(skip, 1)
                size -= skip + 1
            if packed:
                f.seek(4, 1)
                out[name] = lz4.frame.decompress(f.read(size - 4))
            else:
                out[name] = f.read(size)
    return out


def load(folder):
    names = (HUMAN,) + tuple(n for group in PARTS.values() for n in group)
    for sub in ("", MOUTH, os.path.join("Data", MOUTH)):
        if all(os.path.isfile(os.path.join(folder, sub, n)) for n in names):
            return {n: open(os.path.join(folder, sub, n), "rb").read() for n in names}
    for sub in ("", "Data"):
        archive = os.path.join(folder, sub, "Skyrim - Meshes0.bsa")
        if os.path.isfile(archive):
            got = from_archive(archive, names)
            if len(got) == len(names):
                return {n: got[n] for n in names}
            raise CannotMeasure("%s does not hold all of %s" % (archive, ", ".join(names)))
    raise CannotMeasure("no mouth .tri files and no 'Skyrim - Meshes0.bsa' under %s" % folder)


def read_tri(data):
    """base vertices and name -> per-vertex deltas (already scaled) of an FRTRI003 file"""
    if data[:8] != b"FRTRI003":
        raise CannotMeasure("not a .tri morph file")
    nv, nt, nq, _u2, _u3, nuv, flags, nm, _nmod, nmodv = struct.unpack_from("<10i", data, 8)
    p = 64
    flat = struct.unpack_from("<%df" % (nv * 3), data, p)
    verts = [flat[i:i + 3] for i in range(0, nv * 3, 3)]
    p += nv * 12 + nmodv * 12 + nt * 12 + nq * 16
    if flags & 1:
        p += nuv * 8 + nt * 12
    morphs = {}
    for _ in range(nm):
        n, = struct.unpack_from("<i", data, p); p += 4
        name = data[p:p + n].split(b"\0")[0].decode("latin1"); p += n
        scale, = struct.unpack_from("<f", data, p); p += 4
        raw = struct.unpack_from("<%dh" % (nv * 3), data, p); p += nv * 6
        morphs[name] = (scale, raw)
    return verts, morphs


def shifted(points, morph, weight, only):
    """points[i] + weight * the morph's delta, for the vertices in only"""
    if not morph or not weight:
        return {i: points[i] for i in only}
    scale, raw = morph
    k = scale * weight
    return {i: tuple(points[i][c] + k * raw[i * 3 + c] for c in range(3)) for i in only}


def presets():
    """the tongue-out phoneme weights (name -> 0..1) and one (mood id, strength) per face"""
    holds, faces = [], []
    for name in PRESET_FILES:
        rows = json.load(open(os.path.join(PRESETS, name), encoding="utf-8-sig"))["string"]
        holds.append(rows[HOLD_KEY].split(",")[:16])
        for key, value in rows.items():
            if "override" in key.lower():
                continue
            f = value.split(",")
            try:
                faces.append((int(float(f[30])), float(f[31]) / 100.0))
            except ValueError:
                faces.append((7, 0.0))  # N/A: no mood
    if any(h != holds[0] for h in holds):
        raise CannotMeasure("%s differs between %s: one fit cannot follow two shapes" % (HOLD_KEY, ", ".join(PRESET_FILES)))
    return {PHONEMES[i]: float(v) / 100.0 for i, v in enumerate(holds[0]) if float(v) > 0}, faces


def landmark(data, hold, faces):
    """(forward, up) of the lower front teeth: with the bare preset, at the median face, and the up range"""
    verts, morphs = read_tri(data)
    everyone = range(len(verts))
    if "BigAah" not in morphs:
        raise CannotMeasure("a mouth part without a BigAah morph")
    _scale, opener = morphs["BigAah"]
    reach = [sum(opener[i * 3 + c] ** 2 for c in range(3)) for i in everyone]
    jaw = [i for i in everyone if abs(verts[i][0]) < 0.7 and reach[i] > 0.25 * max(reach)]
    posed = verts
    for name, weight in hold.items():
        moved = shifted(posed, morphs.get(name), weight, everyone)
        posed = [moved[i] for i in everyone]
    front_y = max(posed[i][1] for i in jaw)
    front = [i for i in jaw if posed[i][1] > front_y - 0.6]

    def at(points):
        return max(p[1] for p in points.values()), max(p[2] for p in points.values())

    bare = at({i: posed[i] for i in front})
    seen = [at(shifted(posed, morphs.get(MOODS[mood]) if 0 <= mood < len(MOODS) and MOODS[mood] else None,
                       strength, front)) for mood, strength in faces]
    ups = [s[1] for s in seen]
    return bare, (statistics.median(s[0] for s in seen), statistics.median(ups)), (min(ups), max(ups))


def main():
    args = sys.argv[1:]
    check = "--check" in args
    rest = [a for a in args if a != "--check"]
    if len(rest) > 1 or any(a.startswith("-") for a in rest):
        print(__doc__.split("\n\n")[1])
        return 2
    folder = rest[0] if rest else os.path.join(
        os.environ.get("SKYRIM_GAME_PATH", r"C:\SteamLibrary\steamapps\common\Skyrim Special Edition"), "Data")
    try:
        files = load(folder)
        hold, faces = presets()
        marks = {name: landmark(data, hold, faces) for name, data in files.items()}
    except CannotMeasure as e:
        print("not measured: %s" % e)
        return 2
    print("tongue-out preset: %s; %d faces (the preset plus the mood of each expression row)" % (
        ", ".join("%s %.2f" % kv for kv in hold.items()), len(faces)))
    print("%-24s %-16s %-16s %s" % ("lower front teeth", "bare preset", "median face", "up, lowest .. highest"))
    for name, (bare, median, span) in marks.items():
        print("%-24s %5.2f / %5.2f    %5.2f / %5.2f    %5.2f .. %5.2f" % ((name,) + bare + median + span))
    human = marks[HUMAN][1]
    failed = False
    for race, names in PARTS.items():
        forward = sum(marks[n][1][0] for n in names) / len(names) - human[0]
        up = sum(marks[n][1][1] for n in names) / len(names) - human[1]
        fit = ft.FITS[race]
        ok = fit[0] == 0.0 and abs(fit[1] - forward) <= TOLERANCE and abs(fit[2] - up) <= TOLERANCE
        failed = failed or not ok
        print("%-9s measured forward %+.2f up %+.2f   FITS %+.2f %+.2f   %s" % (
            race, forward, up, fit[1], fit[2], "match" if ok else "DIFFERENT"))
    if check and failed:
        print("FAIL  FITS in fit_tongues.py is not what the mouth parts and the shipped presets give")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
