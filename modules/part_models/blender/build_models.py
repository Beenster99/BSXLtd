"""Builds BSX's own part models (modules/part_models/internal/models/<id>.glb) in Blender.

    pip install bpy          # Blender as a Python module (5.3)
    python3 modules/part_models/blender/build_models.py            # every recipe
    python3 modules/part_models/blender/build_models.py fridge desk  # just these

Each recipe (recipes_*.py, RECIPES: catalogue id -> function(part, size)) builds the part to its
catalogue size (modules/design/internal/data/components/<id>.tres `size`), its origin in the
middle of its footprint on the floor, its working face to -Z. Hull-mounted parts (`hull_mount`)
have their mounting face at +Z and stand out from the hull towards -Z. The script scales every
model to its catalogue box exactly and fails if a side needed more than TOLERANCE of it.

The game never runs Blender: the .glb files are committed with these scripts.
"""

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import kit  # noqa: E402
import recipes_rooms  # noqa: E402
import recipes_machines  # noqa: E402
import recipes_hull  # noqa: E402
import recipes_detail  # noqa: E402
import recipes_moving  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
COMPONENTS = os.path.join(ROOT, "modules", "design", "internal", "data", "components")
OUT = os.path.join(ROOT, "modules", "part_models", "internal", "models")
# Every model is scaled to its catalogue size exactly; a recipe whose box needed more than this
# share of stretch or squash on any side is reported (its proportions are off: fix the recipe).
TOLERANCE = 0.12
# ... unless that is no more than this many metres (a handle on a thin cupboard).
SLACK = 0.08

RECIPES = {}
RECIPES.update(recipes_rooms.RECIPES)
RECIPES.update(recipes_machines.RECIPES)
RECIPES.update(recipes_hull.RECIPES)
RECIPES.update(recipes_detail.RECIPES)
RECIPES.update(recipes_moving.RECIPES)


def catalogue_size(pid):
    with open(os.path.join(COMPONENTS, pid + ".tres")) as f:
        text = f.read()
    m = re.search(r"^size = Vector3\(([^)]*)\)", text, re.M)
    return tuple(float(v) for v in m.group(1).split(","))


def build(pid):
    size = catalogue_size(pid)
    kit.reset()
    p = kit.Part(pid)
    RECIPES[pid](p, size)
    p.join()
    k = p.fit(size)
    bad = []
    for i, axis in enumerate("xyz"):
        if abs(k[i] - 1.0) > TOLERANCE and abs(size[i] / k[i] - size[i]) > SLACK:
            bad.append("%s scaled %.2f to fit %.2f m" % (axis, k[i], size[i]))
    os.makedirs(OUT, exist_ok=True)
    p.export(os.path.join(OUT, pid + ".glb"))
    note = p.motion()
    path = os.path.join(OUT, pid + ".motion.json")
    if note:
        with open(path, "w") as f:
            json.dump(note, f, indent=1)
            f.write("\n")
    elif os.path.exists(path):
        os.remove(path)
    return bad


def main():
    ids = sys.argv[1:] or sorted(RECIPES)
    failed = 0
    for pid in ids:
        if pid not in RECIPES:
            print("NO RECIPE", pid)
            failed += 1
            continue
        bad = build(pid)
        if bad:
            failed += 1
            print("SIZE", pid, "; ".join(bad))
        else:
            print("ok", pid)
    print("%d built, %d failed" % (len(ids) - failed, failed))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
