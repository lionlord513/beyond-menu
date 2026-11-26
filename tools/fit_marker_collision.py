"""Fit a small compound collision shape to marker.glb, in glTFRuntime centimetres."""

import json, math, struct
from pathlib import Path
from collections import deque
from itertools import product

ROOT = Path(__file__).resolve().parents[1] / "mod/BeyondMenu"
blob = (ROOT / "assets/paintball/marker.glb").read_bytes()
size = struct.unpack_from("<I", blob, 12)[0]
model = json.loads(blob[20 : 20 + size])
binary = memoryview(blob)[28 + size :]


def read(index):
    a = model["accessors"][index]
    v = model["bufferViews"][a["bufferView"]]
    dims = {"VEC3": 3, "SCALAR": 1}[a["type"]]
    fmt = "<" + {5123: "H", 5125: "I", 5126: "f"}[a["componentType"]] * dims
    start = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    step = v.get("byteStride", struct.calcsize(fmt))
    return [
        struct.unpack_from(fmt, binary, start + i * step) for i in range(a["count"])
    ]


def bounds(points):
    return tuple(min(p[d] for p in points) for d in range(3)), tuple(
        max(p[d] for p in points) for d in range(3)
    )


def volume(lo, hi):
    return math.prod(h - l + 1 for l, h in zip(lo, hi))


# Sample the triangulated surface at sub-voxel intervals; fill interior cells.
cell = 1.0
voxels = set()
all_vertices = []
for primitive in model["meshes"][0]["primitives"]:
    pts = [
        (x * 100, z * 100, y * 100)
        for x, y, z in read(primitive["attributes"]["POSITION"])
    ]
    all_vertices.extend(pts)
    indices = [i[0] for i in read(primitive["indices"])]
    for j in range(0, len(indices), 3):
        a, b, c = (pts[i] for i in indices[j : j + 3])
        n = max(
            1, math.ceil(max(math.dist(a, b), math.dist(b, c), math.dist(c, a)) / 0.55)
        )
        for k in range(n + 1):
            for m in range(n - k + 1):
                voxels.add(
                    tuple(
                        math.floor(
                            (a[d] + (b[d] - a[d]) * k / n + (c[d] - a[d]) * m / n)
                            / cell
                        )
                        for d in range(3)
                    )
                )
lo, hi = bounds(voxels)
outer = set(product(*(range(lo[d] - 1, hi[d] + 2) for d in range(3))))
open_cells = outer - voxels
start = tuple(x - 1 for x in lo)
queue = deque([start])
outside = {start}
while queue:
    p = queue.popleft()
    for d in range(3):
        for s in (-1, 1):
            q = list(p)
            q[d] += s
            q = tuple(q)
            if q in open_cells and q not in outside:
                outside.add(q)
                queue.append(q)
solid = outer - outside


# Split at voxel planes. Choose the split removing the greatest empty volume.
def best_split(group):
    lo, hi = bounds(group)
    best = (0, None)
    for d in range(3):
        columns = [[] for _ in range(hi[d] - lo[d] + 1)]
        for p in group:
            columns[p[d] - lo[d]].append(p)
        ranges = [bounds(c) if c else None for c in columns]
        inf = (math.inf,) * 3

        def costs(seq):
            l = inf
            h = tuple(-x for x in inf)
            result = []
            for r in seq:
                if r:
                    l = tuple(map(min, zip(l, r[0])))
                    h = tuple(map(max, zip(h, r[1])))
                result.append(volume(l, h))
            return result

        left = costs(ranges)
        right = costs(ranges[::-1])[::-1]
        for i in range(len(columns) - 1):
            gain = volume(lo, hi) - left[i] - right[i + 1]
            if gain > best[0]:
                best = gain, (d, i + lo[d])
    return best


regions = [solid]
choices = [best_split(solid)]
while len(regions) < 18:
    i = max(range(len(regions)), key=lambda i: choices[i][0])
    gain, cut = choices.pop(i)
    if gain < 8:
        break
    axis, pos = cut
    group = regions.pop(i)
    low = {p for p in group if p[axis] <= pos}
    high = group - low
    regions.extend([low, high])
    choices.extend([best_split(low), best_split(high)])
raw_lo, raw_hi = bounds(all_vertices)
shapes = []
for group in regions:
    lo, hi = bounds(group)
    shapes.append(
        tuple(round(max(raw_lo[i], lo[i] * cell) - 0.06, 2) for i in range(3))
        + tuple(round(min(raw_hi[i], (hi[i] + 1) * cell) + 0.06, 2) for i in range(3))
    )
for p in all_vertices:
    assert any(
        all(s[d] - 0.001 <= p[d] <= s[d + 3] + 0.001 for d in range(3)) for s in shapes
    ), "Vertex outside body"
print(
    f"{len(shapes)} boxes, {len(all_vertices)} verified vertices, {sum(math.prod(s[d + 3] - s[d] for d in range(3)) for s in shapes) / math.prod(raw_hi[d] - raw_lo[d] for d in range(3)):.1%} of bounding box volume"
)
source = (
    "-- Generated from marker.glb by tools/fit_marker_collision.py in Unreal centimetres.\nreturn {\n"
    + "".join("    {" + ", ".join(map(str, s)) + "},\n" for s in sorted(shapes))
    + "}\n"
)
(ROOT / "Scripts/paintball/collision_boxes.lua").write_text(source, encoding="utf-8")
