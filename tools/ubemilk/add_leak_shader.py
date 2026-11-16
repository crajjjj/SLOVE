"""Add the UBE milk leak effect shader to optional\\UBESupport\\SLOVE_UBE_Support.esp.

SLOVE_MilkLeakUBE (EFSH 00080A) is Oninus Lactis NG's LactisNippleLeakCBBE with one change:
the texture is textures\\SLOVE\\milk_leaking_ube.dds (make_leak_texture.py), painted for the UBE
body's UV layout. The shader settings are read from the installed OninusLactis.esp, which holds
no form reference in that record, so the patch gains no master.

    python add_leak_shader.py [--lactis <OninusLactis.esp>]

Run once; a second run replaces the record it added. Needs esptree.py (path below).
"""
import argparse
import os
import struct
import sys

sys.path.insert(0, r"C:\Playground\Skyrim\mods\Sexlab Survival\tools\knock")
import esptree as E  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ESP = os.path.join(ROOT, r"optional\UBESupport\SLOVE_UBE_Support.esp")
LACTIS = r"E:\nefaram\mods\[NoDelete][3020] Oninus Lactis NG\OninusLactis.esp"
LOCAL_ID = 0x80A
EDID = b"SLOVE_MilkLeakUBE\x00"
TEXTURE = b"SLOVE\\milk_leaking_ube.dds\x00"       # relative to textures\


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lactis", default=LACTIS)
    args = ap.parse_args()

    _, ltop = E.parse(args.lactis)
    src = [r for g in ltop for r in g.kids if r.sig == "EFSH"]
    if len(src) != 1:
        raise SystemExit("expected one EFSH in %s, found %d" % (args.lactis, len(src)))
    src = src[0]
    subs = []
    for sig, data in src.load_subs():
        if sig == "EDID":
            data = EDID
        elif sig == "ICON":
            data = TEXTURE
        subs.append((sig, data))

    tes4, top = E.parse(ESP)
    masters = [d for s, d in tes4.load_subs() if s == "MAST"]
    fid = (len(masters) << 24) | LOCAL_ID

    hdr = bytearray(src.hdr)
    struct.pack_into("<I", hdr, 8, 0)               # record flags
    rec = E.Rec("EFSH", hdr, b"")
    rec.fid = fid
    rec.set_subs(subs)

    top = [g for g in top if bytes(g.hdr[8:12]) != b"EFSH"]
    ghdr = bytearray(top[0].hdr)
    ghdr[8:12] = b"EFSH"
    top.append(E.Grp(ghdr, [rec]))

    out = []
    for sig, data in tes4.subs:
        if sig == "HEDR":
            ver, _count, next_id = struct.unpack("<fII", data)
            data = struct.pack("<fII", ver, E.count_records_and_groups(top), max(next_id, LOCAL_ID + 1))
        out.append((sig, data))
    tes4.set_subs(out)
    E.write(ESP, tes4, top)
    print("wrote %s: EFSH %08X %s -> textures\\%s" % (ESP, fid, EDID[:-1].decode(), TEXTURE[:-1].decode()))


if __name__ == "__main__":
    main()
