"""Milk leak texture for the UBE body.

Oninus Lactis NG draws its "nipple leak" as an effect shader whose membrane texture
(textures\\lactis\\Milk_Leaking_CBBE.dds) is painted for the CBBE UV layout. The UBE body has its
own layout, so on a UBE actor the drips land beside the nipples. This repaints the texture for
the UBE layout: each UBE texel -> its 3D point on the UBE body -> the closest point on the CBBE
3BA body -> that point's CBBE UV -> the stock texel.

The drips hang from the nipple, and the two bodies' nipples are not in the same place, so the
UBE points are first shifted nipple onto nipple (per side); otherwise the pattern would start
beside the UBE nipple by the distance between the two tips.

    python make_leak_texture.py [--src <Milk_Leaking_CBBE.dds>] [--size 1024] [--preview out.png]

Writes optional\\UBESupport\\textures\\SLOVE\\milk_leaking_ube.dds. Needs numpy, Pillow, texconv
and three scripts outside this repo (paths below): the UBE overlay mapper, its face remap helper
and nifkit.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, r"C:\Playground\Skyrim\tools\ube_overlay_check")
sys.path.insert(0, r"C:\Playground\Skyrim\mods\Apropos2 SE\tools")
sys.path.insert(0, r"C:\Playground\Skyrim\mods\Ovibody UBE")
import check_ube_overlays as C  # noqa: E402
import ube_face_remap as F  # noqa: E402
import nifkit  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = r"E:\nefaram\mods\[NoDelete][3020] Oninus Lactis NG\textures\lactis\Milk_Leaking_CBBE.dds"
OUT = os.path.join(ROOT, r"optional\UBESupport\textures\SLOVE\milk_leaking_ube.dds")
BONE = "L Breast03"


def nipple_tip(rel, name):
    """The left nipple tip: the vertex of the breast-tip bone that sits furthest out along Y."""
    n = nifkit.Nif(open(os.path.join(C.MODS, rel), "rb").read())
    for b in n.shapes():
        if n.shape(b)["name"] != name:
            continue
        s = nifkit.SkinnedShape(n, b)
        bi = s.bone_names.index(BONE)
        w = np.zeros(s.n)
        for slot in range(4):
            w += np.where(s.vbones[:, slot] == bi, s.v["weights"][:, slot], 0)
        idx = np.nonzero(w > 0.3)[0]
        tip = idx[np.argmax(s.v["pos"][idx, 1])]
        return s.v["pos"][tip].astype(np.float64), s.v["uv"][tip].astype(np.float64)
    raise KeyError(name)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=SRC)
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--size", type=int, default=1024)
    ap.add_argument("--preview", default="")
    args = ap.parse_args()

    (srel, sname), (drel, dname) = C.MESH["Body"]
    cbbe_tip, cbbe_uv = nipple_tip(srel, sname)
    ube_tip, ube_uv = nipple_tip(drel, dname)
    shift = cbbe_tip - ube_tip
    print("left nipple: CBBE %s uv %s | UBE %s uv %s | shift %s" % (
        np.round(cbbe_tip, 2), np.round(cbbe_uv, 4), np.round(ube_tip, 2), np.round(ube_uv, 4), np.round(shift, 2)))

    # shift the UBE body nipple onto nipple before the closest-point search; x mirrors per side
    stock_load = C.load_shape

    def load_shape(rel, name):
        p, t, uv = stock_load(rel, name)
        if rel == drel:
            side = np.tanh(p[:, 0] / 1.5)           # -1 on the tip's side (x < 0), +1 on the other
            sx = shift[0] * np.sign(ube_tip[0])
            p = p + np.stack([side * sx, np.full(len(p), shift[1]), np.full(len(p), shift[2])], 1)
        return p, t, uv

    C.load_shape = load_shape
    m = C.Mapping("Body", args.size)
    src = F.dds_to_rgba(args.src)
    out = m.project(src, "Body")
    out = F.dilate(out, out[..., 3] > 0, 8)
    F.rgba_to_dds(out, args.out)
    print("wrote", args.out)

    # where the paint sits against the left nipple, on both layouts (v grows downwards)
    for label, img, uv in (("stock / CBBE", src, cbbe_uv), ("output / UBE", out, ube_uv)):
        h, w = img.shape[:2]
        ys, xs = np.nonzero(img[..., 3] > 8)
        print("  %-13s nipple uv (%.4f, %.4f); paint u %.4f..%.4f v %.4f..%.4f" % (
            label, uv[0], uv[1], xs.min() / w, xs.max() / w, ys.min() / h, ys.max() / h))

    if args.preview:
        S = 1024
        wires = (C.wire(m.SUV, m.ST, S, (120, 120, 120, 110), 2), C.wire(m.DUV, m.DT, S, (120, 120, 120, 110), 2))
        stock_s = np.asarray(Image.fromarray(np.clip(src, 0, 255).astype(np.uint8), "RGBA").resize((S, S), Image.BILINEAR), np.float64)
        out_s = np.asarray(Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA").resize((S, S), Image.BILINEAR), np.float64)
        sheet = np.concatenate([C.panel(stock_s[..., 3] / 255.0, wires[0], S),      # stock on CBBE
                                C.panel(stock_s[..., 3] / 255.0, wires[1], S),      # stock on UBE: the defect
                                C.panel(out_s[..., 3] / 255.0, wires[1], S)], 1)    # output on UBE
        Image.fromarray(sheet.astype(np.uint8)).save(args.preview)
        print("preview", args.preview)


if __name__ == "__main__":
    main()
