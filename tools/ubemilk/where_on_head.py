"""Where does a leak texture's paint land on a head? (FaceGen .tri: positions + UVs)

    python where_on_head.py <head.tri> <texture.dds> [<texture.dds> ...]

Head-local units: x across (0 = middle), y forward, z up. For scale it prints the head's own box.
"""
import sys

import numpy as np

sys.path.insert(0, r"C:\Playground\Skyrim\mods\Apropos2 SE\tools")
import ube_face_remap as F  # noqa: E402


def main():
    pos, tris, uv = F.read_tri(sys.argv[1])
    print("%s: %d triangles, box x %.1f..%.1f y %.1f..%.1f z %.1f..%.1f" % (
        sys.argv[1], len(tris), pos[:, 0].min(), pos[:, 0].max(), pos[:, 1].min(), pos[:, 1].max(), pos[:, 2].min(), pos[:, 2].max()))
    for path in sys.argv[2:]:
        tex = F.dds_to_rgba(path)
        alpha = tex[..., 3]
        h, w = alpha.shape
        tri_of, _bary = F.rasterize(uv, tris, w, h)
        on = (alpha > 8) & (tri_of >= 0)
        hit = np.unique(tri_of[on])
        if not len(hit):
            print("   %s: clean" % path)
            continue
        p = pos[np.unique(tris[hit])]
        print("   %s: %d painted texels (alpha up to %d) on %d triangles, x %.1f..%.1f y %.1f..%.1f z %.1f..%.1f" % (
            path, int(on.sum()), int(alpha[on].max()), len(hit),
            p[:, 0].min(), p[:, 0].max(), p[:, 1].min(), p[:, 1].max(), p[:, 2].min(), p[:, 2].max()))


if __name__ == "__main__":
    main()
