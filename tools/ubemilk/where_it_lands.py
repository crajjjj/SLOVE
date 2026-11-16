"""Where does a leak texture's paint land on each mesh of an actor?

An effect shader draws its texture through the UVs of every mesh the actor wears, not only the
body. For each mesh this lists the triangles whose UVs fall on painted texels and the 3D box they
cover, so a texture that suits the body can be checked against the head, hands and feet.

    python where_it_lands.py <texture.dds> <mesh.nif> [<mesh.nif> ...]
"""
import sys

import numpy as np

sys.path.insert(0, r"C:\Playground\Skyrim\mods\Apropos2 SE\tools")
sys.path.insert(0, r"C:\Playground\Skyrim\mods\Ovibody UBE")
import ube_face_remap as F  # noqa: E402
import nifkit  # noqa: E402


def main():
    tex = F.dds_to_rgba(sys.argv[1])
    alpha = tex[..., 3]
    h, w = alpha.shape
    print("%s: %d painted texels" % (sys.argv[1], int((alpha > 8).sum())))
    for path in sys.argv[2:]:
        n = nifkit.Nif(open(path, "rb").read())
        print(path)
        for b in n.shapes():
            try:
                s = nifkit.SkinnedShape(n, b)
            except Exception as e:                       # unskinned or another vertex layout
                print("   %-28s skipped (%s)" % (n.shape(b)["name"], type(e).__name__))
                continue
            uv = s.v["uv"].astype(np.float64)
            tri_of, _bary = F.rasterize(uv, s.tris.astype(np.int64), w, h)
            hit = np.unique(tri_of[(alpha > 8) & (tri_of >= 0)])
            painted = int(((alpha > 8) & (tri_of >= 0)).sum())
            if not len(hit):
                print("   %-28s clean" % s.name)
                continue
            p = s.v["pos"][np.unique(s.tris[hit])]
            print("   %-28s %5d painted texels on %4d triangles, x %.1f..%.1f y %.1f..%.1f z %.1f..%.1f" % (
                s.name, painted, len(hit), p[:, 0].min(), p[:, 0].max(), p[:, 1].min(), p[:, 1].max(), p[:, 2].min(), p[:, 2].max()))


if __name__ == "__main__":
    main()
