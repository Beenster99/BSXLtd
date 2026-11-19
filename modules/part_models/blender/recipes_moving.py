"""Models for the moving-parts test's catalogue entries (and the big empty cargo parts): each
moving one is a fixed base and named moving pieces with their pivots (kit.Part.moving), so the
design room can pose them (PartModels.pose). Shelving and racking are always empty (a new ship)."""

import math

from recipes_hull import mount_plate, HULL
from recipes_detail import GEAR, hose, bolt_row, stripes, oleo_outer, oleo_inner, pad, single_gear

RECIPES = {}

RACK_BLUE = (0.14, 0.3, 0.58)
RACK_ORANGE = (0.92, 0.45, 0.08)
CELL = (0.06, 0.1, 0.28)


def knuckles(p, x0, x1, y, z, r, n, material="gunmetal", axis="x"):
    """A row of hinge knuckles along an axis."""
    for i in range(n):
        t = (i + 0.5) / n
        at = [0.0, y, z] if axis == "x" else [x0, 0.0, z]
        if axis == "x":
            at[0] = x0 + (x1 - x0) * t
            p.cyl(r, (x1 - x0) / n * 0.6, tuple(at), "x", material, 14)
        else:
            at[1] = x0 + (x1 - x0) * t
            at[0] = y
            p.cyl(r, (x1 - x0) / n * 0.6, tuple(at), "y", material, 14)


def ribs(p, w, h, at, n, depth, material, axis="x"):
    for i in range(n):
        t = (i + 0.5) / n
        if axis == "x":
            p.box((w, depth, depth), (at[0], at[1] - h * 0.5 + h * t, at[2]), material, 0.004)
        else:
            p.box((depth, h, depth), (at[0] - w * 0.5 + w * t, at[1], at[2]), material, 0.004)


# --- doors, hatches and ramps ---

def r_belly_hatch(p, s):
    # A belly hatch: a square coaming with a seal and hinge knuckles along the back, two rams, and
    # the hatch that swings down on them: a stiffened plate with a hazard border and lamps.
    w, h, d = s
    t = 0.12
    for sz in (-1, 1):
        p.box((w, h * 0.6, t), (0, h * 0.7, sz * (d * 0.5 - t * 0.5)), "gunmetal", 0.01)
    for sx in (-1, 1):
        p.box((t, h * 0.6, d - 2 * t), (sx * (w * 0.5 - t * 0.5), h * 0.7, 0), "gunmetal", 0.01)
    bolt_row(p, (-w * 0.45, h, d * 0.5 - t * 0.5), (w * 0.45, h, d * 0.5 - t * 0.5), 12, 0.012)
    bolt_row(p, (-w * 0.45, h, -d * 0.5 + t * 0.5), (w * 0.45, h, -d * 0.5 + t * 0.5), 12, 0.012)
    knuckles(p, -w * 0.4, w * 0.4, h * 0.45, d * 0.5 - t * 0.5, 0.05, 5)
    for sx in (-1, 1):
        p.box((0.12, 0.08, 0.12), (sx * w * 0.38, h * 0.85, d * 0.3), "dark", 0.006)
        p.lamp(0.025, (sx * (w * 0.5 - t - 0.01), h * 0.7, -d * 0.4), "-x" if sx > 0 else "x", "lamp_amber")
    p.note(power_kw=15.0, load_kg=8000.0, opening=[round(w - 2 * t - 0.2, 3), round(d - 2 * t - 0.2, 3)])
    p.moving("hatch", (0, h * 0.45, d * 0.5 - t * 0.5), kind="hinge", axis=(1, 0, 0), stowed=0.0, deployed=-95.0,
             seconds=15.0, order=1)
    L = d - t * 1.2
    p.box((w - 2 * t - 0.02, h * 0.4, L), (0, h * 0.25, d * 0.5 - t * 0.5 - L * 0.5), HULL, 0.01)
    for i in range(4):
        x = -w * 0.33 + i * w * 0.22
        p.box((0.08, h * 0.25, L * 0.92), (x, h * 0.32, d * 0.5 - t * 0.5 - L * 0.5), "gunmetal", 0.004)
    for i in range(3):
        p.box((w * 0.8, h * 0.2, 0.06), (0, h * 0.32, d * 0.3 - i * d * 0.3), "gunmetal", 0.004)
    for sx in (-1, 1):
        p.box((0.06, 0.012, L * 0.9), (sx * (w * 0.5 - t - 0.06), 0.044, d * 0.5 - t * 0.5 - L * 0.5), "hazard", 0.0)
    p.box((w * 0.7, 0.012, 0.06), (0, 0.044, -d * 0.5 + t + 0.06), "hazard", 0.0)
    p.handle((0, 0.05, -d * 0.3), 0.4, "-y", vertical=False)
    p.fixed()


def r_undercarriage_doors(p, s):
    # A gear bay's doors: a shallow frame and two leaves hinged along the long sides that swing
    # down and out, each with ribs, a seal edge and the link the leg pushes.
    w, h, d = s
    p.box((w, h * 0.3, 0.06), (0, h * 0.85, d * 0.5 - 0.03), "gunmetal", 0.004)
    p.box((w, h * 0.3, 0.06), (0, h * 0.85, -d * 0.5 + 0.03), "gunmetal", 0.004)
    p.note(power_kw=2.0, load_kg=0.0, opening=[round(w * 0.88, 3), round(d * 0.92, 3)])
    lw = w * 0.5 - 0.01
    for sx, name in ((-1, "leaf_l"), (1, "leaf_r")):
        px = sx * (w * 0.5 - 0.02)
        p.moving(name, (px, h * 0.5, 0), kind="hinge", axis=(0, 0, 1), stowed=0.0, deployed=-90.0 if sx < 0 else 90.0,
                 seconds=4.0, order=1)
        xc = px - sx * lw * 0.5
        p.box((lw, h * 0.6, d * 0.98), (xc, h * 0.4, 0), HULL, 0.006)
        for i in range(4):
            p.box((lw * 0.9, h * 0.3, 0.025), (xc, h * 0.75, -d * 0.4 + i * d * 0.27), "gunmetal", 0.002)
        for i in range(3):
            p.cyl(0.025, d * 0.12, (px, h * 0.5, -d * 0.35 + i * d * 0.35), "z", "gunmetal", 12)
        p.box((0.02, h * 0.3, d * 0.96), (px - sx * lw + sx * 0.01, h * 0.3, 0), "rubber", 0.0)
        p.bar((xc, h * 0.9, 0.1), (xc + sx * 0.05, h * 1.0, 0.25), 0.03, "steel")
        p.box((lw * 0.5, 0.01, 0.05), (xc, 0.1 * h, -d * 0.45), "hazard", 0.0)
    p.fixed()


def r_clamshell_doors(p, s):
    # Clamshell hold doors: a header, sill and posts, and two great leaves on hinges at the outer
    # posts that swing outwards, each ribbed with a window, seals, latches and a ram.
    w, h, d = s
    post = 0.22
    p.floor_box((w, 0.2, d), (0, h - 0.2, 0), "gunmetal", 0.015)
    p.floor_box((w, 0.08, d), (0, 0, 0), "dark", 0.01)
    for sx in (-1, 1):
        p.floor_box((post, h - 0.28, d), (sx * (w * 0.5 - post * 0.5), 0.08, 0), "gunmetal", 0.012)
        bolt_row(p, (sx * (w * 0.5 - post * 0.5), 0.3, -d * 0.5 - 0.005), (sx * (w * 0.5 - post * 0.5), h - 0.4, -d * 0.5 - 0.005), 8, 0.014, "z")
    stripes(p, w * 0.6, 0.1, (0, h - 0.1, -d * 0.5 - 0.006), 12)
    p.lamp(0.04, (-w * 0.2, h - 0.1, -d * 0.5 - 0.01), "-z", "lamp_amber")
    p.lamp(0.04, (w * 0.2, h - 0.1, -d * 0.5 - 0.01), "-z", "lamp_amber")
    p.note(power_kw=30.0, load_kg=0.0, opening=[round(w - 2 * post - 0.1, 3), round(h - 0.3, 3)])
    lw = (w - 2 * post) * 0.5
    lh = h - 0.3
    for sx, name in ((-1, "leaf_l"), (1, "leaf_r")):
        px = sx * (w * 0.5 - post)
        p.moving(name, (px, 0.09, -d * 0.2), kind="hinge", axis=(0, 1, 0), stowed=0.0,
                 deployed=110.0 if sx < 0 else -110.0, seconds=25.0, order=1)
        xc = px - sx * lw * 0.5
        p.floor_box((lw - 0.02, lh, d * 0.5), (xc, 0.1, -d * 0.05), HULL, 0.015)
        for i in range(5):
            p.box((lw * 0.9, 0.08, 0.06), (xc, 0.4 + i * (lh - 0.6) / 4, -d * 0.3 - 0.03), "gunmetal", 0.005)
        p.box((0.08, lh * 0.9, 0.06), (xc, 0.1 + lh * 0.5, -d * 0.3 - 0.03), "gunmetal", 0.005)
        p.box((lw * 0.3, 0.4, 0.03), (xc - sx * lw * 0.2, 0.1 + lh * 0.72, -d * 0.31), "glass_dark", 0.004)
        for i in range(4):
            p.cyl(0.05, 0.3, (px, 0.4 + i * (lh - 0.6) / 3, -d * 0.2), "y", "steel", 14)
        p.box((0.04, lh - 0.1, d * 0.4), (px - sx * (lw - 0.03), 0.15 + (lh - 0.1) * 0.5, -d * 0.05), "rubber", 0.0)
        for i in range(3):
            p.box((0.08, 0.14, 0.06), (px - sx * (lw - 0.1), 0.6 + i * lh * 0.35, -d * 0.32), "chrome", 0.006)
        p.box((lw * 0.5, 0.08, 0.01), (xc, 0.3, -d * 0.33), "hazard", 0.0)
    p.fixed()


def r_side_hold_door(p, s):
    # A gull-wing side door: a frame and a leaf hung from hinges along the top that swings up and
    # out on two gas struts, with ribs, a window, seals, a handle and lamps.
    w, h, d = s
    p.floor_box((w, 0.16, d), (0, h - 0.16, 0), "gunmetal", 0.012)
    for sx in (-1, 1):
        p.floor_box((0.1, h - 0.16, d), (sx * (w * 0.5 - 0.05), 0, 0), "gunmetal", 0.01)
        p.lamp(0.03, (sx * (w * 0.5 - 0.05), h - 0.3, -d * 0.5 - 0.004), "-z", "lamp_amber")
    knuckles(p, -w * 0.42, w * 0.42, h - 0.18, -d * 0.1, 0.045, 6)
    p.note(power_kw=18.0, load_kg=0.0, opening=[round(w - 0.2, 3), round(h - 0.2, 3)])
    p.moving("leaf", (0, h - 0.18, -d * 0.1), kind="hinge", axis=(1, 0, 0), stowed=0.0, deployed=120.0, seconds=18.0, order=1)
    lh = h - 0.22
    p.floor_box((w - 0.24, lh, d * 0.55), (0, 0.02, 0.0), HULL, 0.012)
    for i in range(6):
        p.box((0.06, lh * 0.9, 0.05), (-w * 0.38 + i * w * 0.152, 0.02 + lh * 0.5, -d * 0.3), "gunmetal", 0.004)
    p.box((w * 0.82, 0.06, 0.05), (0, lh * 0.45, -d * 0.3), "gunmetal", 0.004)
    p.box((w * 0.3, lh * 0.25, 0.03), (0, lh * 0.72, -d * 0.31), "glass_dark", 0.004)
    p.handle((0, 0.3, -d * 0.33), 0.5, "-z", vertical=False)
    p.box((w - 0.26, 0.03, d * 0.5), (0, 0.03, 0), "rubber", 0.0)
    for sx in (-1, 1):
        p.rod((sx * w * 0.4, lh * 0.2, -d * 0.3), (sx * w * 0.42, lh * 0.8, -d * 0.3), 0.025, "chrome", 10)
    stripes(p, w * 0.3, 0.06, (0, 0.12, -d * 0.32), 6)
    p.fixed()


def ramp_body(p, w, h, d, top, rails=True):
    """A ramp plate lying from its hinge (y = 0.05) up to `top`, treads on -Z."""
    L = top - 0.1
    p.box((w * 0.96, L, d * 0.6), (0, 0.1 + L * 0.5, d * 0.2), HULL, 0.01)
    for i in range(int(L / 0.25)):
        y = 0.25 + i * 0.25
        p.box((w * 0.84, 0.04, d * 0.35), (0, y, -d * 0.2), "dark", 0.004)
    if rails:
        for sx in (-1, 1):
            p.box((0.1, L, d * 0.9), (sx * (w * 0.5 - 0.05), 0.1 + L * 0.5, 0), "hazard", 0.01)
            for i in range(4):
                p.cyl(0.02, 0.012, (sx * (w * 0.5 - 0.05), 0.4 + i * L * 0.27, -d * 0.46), "z", "chrome", 6, 0.0)


def r_tail_ramp(p, s):
    # A tail ramp: a hinge sill with knuckles and two big rams, the ramp with treads and kerbs,
    # and a toe flap hinged on its end that drops to meet the ground.
    w, h, d = s
    p.cyl(0.06, w, (0, 0.06, 0), "x", "dark", 14)
    for i in range(6):
        p.cyl(0.075, 0.14, (-w * 0.45 + i * w * 0.18, 0.06, 0), "x", "gunmetal", 14)
    for sx in (-1, 1):
        p.box((0.16, 0.3, d), (sx * (w * 0.5 - 0.08), 0.15, 0), "gunmetal", 0.01)
        p.lamp(0.03, (sx * (w * 0.5 - 0.08), 0.28, -d * 0.5 - 0.004), "-z", "lamp_red")
    p.note(power_kw=22.0, load_kg=12000.0, opening=[round(w * 0.95, 3), round(h * 0.94, 3)])
    p.moving("ramp", (0, 0.06, 0), kind="hinge", axis=(1, 0, 0), stowed=0.0, deployed=-105.0, seconds=20.0, order=1)
    top = h - 0.35
    ramp_body(p, w, h, d, top)
    for i in range(5):
        p.cyl(0.075, 0.14, (-w * 0.36 + i * w * 0.18, 0.06, 0), "x", "steel", 14)
    for sx in (-1, 1):
        p.box((0.08, 0.06, 0.06), (sx * w * 0.3, top * 0.6, d * 0.4), "dark", 0.004)
    p.lamp(0.025, (0, top - 0.1, -d * 0.46), "-z", "lamp_amber")
    p.moving("toe", (0, top, 0), parent="ramp", kind="hinge", axis=(1, 0, 0), stowed=0.0, deployed=-20.0, seconds=3.0, order=2)
    p.box((w * 0.9, h - top - 0.02, d * 0.5), (0, top + (h - top) * 0.5, d * 0.1), "gunmetal", 0.008)
    for i in range(7):
        p.cyl(0.035, w * 0.1, (-w * 0.39 + i * w * 0.13, top, 0), "x", "steel", 10)
    for i in range(10):
        p.box((0.03, (h - top) * 0.7, 0.02), (-w * 0.4 + i * w * 0.089, top + (h - top) * 0.5, -d * 0.2), "dark", 0.0)
    p.fixed()


def r_airstair(p, s):
    # A boarding airstair: a sill bracket in the door, and the stair that swings down from it:
    # stringers, grated treads with lit noses, handrails on stanchions and a rubber foot.
    w, h, d = s
    hz = d * 0.5 - 0.1
    p.box((w, 0.16, 0.22), (0, h - 0.08, hz), "gunmetal", 0.01)
    p.cyl(0.05, w * 0.9, (0, h - 0.18, hz), "x", "dark", 14)
    p.box((0.08, 0.24, 0.12), (w * 0.35, h - 0.14, hz + 0.02), "dark", 0.006)
    p.note(power_kw=4.0, load_kg=600.0, opening=[0.9, 2.0])
    p.moving("stair", (0, h - 0.18, hz), kind="hinge", axis=(1, 0, 0), stowed=-40.0, deployed=0.0, seconds=12.0, order=1)
    top = (0, h - 0.18, hz)
    bot = (0, 0.08, -d * 0.5 + 0.12)
    for sx in (-1, 1):
        x = sx * (w * 0.5 - 0.08)
        p.bar((x, top[1], top[2]), (x, bot[1] + 0.05, bot[2]), 0.08, GEAR)
    n = 9
    for i in range(n):
        t = (i + 0.5) / n
        y = top[1] + (bot[1] - top[1]) * t
        z = top[2] + (bot[2] - top[2]) * t
        p.box((w - 0.2, 0.04, d / n * 0.9), (0, y, z), "dark", 0.004)
        for j in range(5):
            p.box((w - 0.24, 0.045, 0.012), (0, y + 0.002, z - d / n * 0.35 + j * d / n * 0.17), "steel", 0.0)
        p.box((w - 0.22, 0.015, 0.02), (0, y + 0.025, z - d / n * 0.45), "lamp_white", 0.0)
    for sx in (-1, 1):
        x = sx * (w * 0.5 - 0.06)
        posts = []
        for i in range(4):
            t = 0.1 + i * 0.27
            y = top[1] + (bot[1] - top[1]) * t
            z = top[2] + (bot[2] - top[2]) * t
            ph = min(0.85, h - 0.04 - y)
            posts.append((x, y + ph, z))
            p.rod((x, y, z), (x, y + ph, z), 0.02, "chrome", 8)
        p.pipe_run(posts, 0.025, "chrome")
    p.floor_box((w - 0.1, 0.06, 0.3), (0, 0.0, -d * 0.5 + 0.18), "rubber", 0.01)
    p.fixed()


# --- legs, pads and jacks ---

def r_landing_foot_pad(p, s):
    # A bolt-on foot pad: a mounting spigot with a ball socket, and the pad that rocks on it.
    w, h, d = s
    p.cyl(w * 0.16, h * 0.25, (0, h - h * 0.125, 0), "y", GEAR, 24)
    p.bolts((0, h - 0.004, 0), w * 0.12, 6, "y", 0.012)
    p.cyl(w * 0.1, h * 0.2, (0, h * 0.62, 0), "y", "dark", 20)
    p.note(power_kw=0.0, load_kg=20000.0)
    p.moving("foot", (0, h * 0.5, 0), kind="hinge", axis=(1, 0, 0), stowed=0.0, deployed=0.0, seconds=0.5, order=1,
             swing=15.0, contact={"at": (0, 0, 0), "radius": round(min(w, d) * 0.45, 3)})
    p.sphere(w * 0.09, (0, h * 0.5, 0), "chrome", 16, 8)
    pad(p, 0, 0, w, d, h / 0.32 * 0.3 * 0.9, lit=False)
    p.fixed()


def r_landing_skid(p, s):
    # A skid: two oleo legs from mounting plates to a long runner with turned-up ends, wear
    # strips and bolts; the runner retracts up into the legs.
    w, h, d = s
    zs = (-d * 0.3, d * 0.3)
    for z in zs:
        p.box((w, 0.08, 0.6), (0, h - 0.04, z), "gunmetal", 0.008)
        bolt_row(p, (-w * 0.4, h - 0.085, z - 0.2), (w * 0.4, h - 0.085, z - 0.2), 4, 0.012)
        bolt_row(p, (-w * 0.4, h - 0.085, z + 0.2), (w * 0.4, h - 0.085, z + 0.2), 4, 0.012)
        oleo_outer(p, 0, h * 0.5, h - 0.08, z, 0.09)
    hose(p, [(w * 0.3, h - 0.09, zs[0] + 0.2), (0.1, h * 0.7, zs[0] + 0.05)], 0.012)
    hose(p, [(w * 0.3, h - 0.09, zs[1] - 0.2), (0.1, h * 0.7, zs[1] - 0.05)], 0.012)
    p.note(power_kw=6.0, load_kg=30000.0)
    p.moving("skid", (0, h * 0.5, 0), kind="slide", axis=(0, 1, 0), stowed=0.8 * h / 1.2 * 0.5, deployed=0.0,
             seconds=8.0, order=1, contact={"at": (0, 0, 0), "radius": round(w * 0.5, 3)})
    for z in zs:
        oleo_inner(p, 0, 0.16, h * 0.5 + 0.05, z, 0.06)
        p.box((w * 0.5, 0.1, 0.2), (0, 0.18, z), GEAR, 0.008)
    p.floor_box((w * 0.8, 0.14, d * 0.86), (0, 0.0, 0), GEAR, 0.02)
    for sz in (-1, 1):
        p.prism([(sz * d * 0.43, 0.0), (sz * d * 0.5, 0.12), (sz * d * 0.5, 0.2), (sz * d * 0.43, 0.14)], w * 0.8, (0, 0, 0), "x", GEAR, 0.01)
    p.floor_box((w * 0.7, 0.03, d * 0.8), (0, 0.0, 0), "rubber", 0.005)
    bolt_row(p, (w * 0.3, 0.14, -d * 0.4), (w * 0.3, 0.14, d * 0.4), 12, 0.012)
    bolt_row(p, (-w * 0.3, 0.14, -d * 0.4), (-w * 0.3, 0.14, d * 0.4), 12, 0.012)
    p.box((0.01, 0.06, d * 0.3), (w * 0.4 + 0.004, 0.07, 0), "hazard", 0.0)
    p.fixed()


def r_stabiliser_jack(p, s):
    # A screw stabiliser jack: a top plate, gearbox and motor, an outer tube, the inner leg that
    # runs down out of it, and a swivel foot.
    w, h, d = s
    p.box((w, 0.05, d), (0, h - 0.025, 0), "gunmetal", 0.006)
    p.bolts((0, h - 0.052, 0), w * 0.38, 6, "y", 0.01)
    p.box((w * 0.6, 0.16, d * 0.6), (0, h - 0.13, 0), MINER_Y, 0.01)
    p.cyl(0.07, 0.22, (w * 0.3, h - 0.13, 0), "x", "gunmetal", 16)
    for i in range(5):
        p.torus(0.072, 0.008, (w * 0.25 + i * 0.03, h - 0.13, 0), "x", "dark", 16, 4)
    p.cyl(w * 0.2, h * 0.56, (0, h * 0.61, 0), "y", GEAR, 24)
    p.torus(w * 0.2, 0.01, (0, h * 0.34, 0), "y", "dark", 24, 4)
    p.box((w * 0.3, 0.12, 0.005), (0, h * 0.6, -w * 0.2 - 0.003), "white", 0.0)
    p.note(power_kw=5.0, load_kg=25000.0)
    p.moving("leg", (0, h * 0.33, 0), kind="slide", axis=(0, 1, 0), stowed=h * 0.25, deployed=0.0, seconds=9.0, order=1)
    p.cyl(w * 0.14, h * 0.32, (0, h * 0.2, 0), "y", "chrome", 20)
    for i in range(8):
        p.torus(w * 0.141, 0.004, (0, 0.12 + i * 0.03, 0), "y", "steel", 20, 3)
    p.moving("foot", (0, 0.07, 0), parent="leg", kind="hinge", axis=(1, 0, 0), stowed=0.0, deployed=0.0, seconds=0.5,
             order=1, swing=10.0, contact={"at": (0, 0, 0), "radius": round(w * 0.45, 3)})
    p.sphere(w * 0.1, (0, 0.07, 0), "gunmetal", 14, 8)
    p.cyl(w * 0.48, 0.05, (0, 0.025, 0), "y", "dark", 24)
    p.cyl(w * 0.46, 0.015, (0, 0.0075, 0), "y", "rubber", 24)
    p.fixed()


MINER_Y = (0.86, 0.62, 0.12)


def r_undercarriage_leg(p, s):
    single_gear(p, s, s[1] / 2.4 * 0.85, twin=False, wheels=True)


def r_hydraulic_ram(p, s):
    # A double-acting hydraulic ram: a clevis eye, the barrel with its ports and hoses, a gland,
    # and the chrome rod with its own eye, which slides out.
    w, h, d = s
    r = min(w, h) * 0.42
    cy = h * 0.5
    zb = d * 0.5
    p.cyl(r * 0.6, 0.08, (0, cy, zb - 0.06), "x", "gunmetal", 16)
    p.box((r * 1.2, r * 1.6, 0.1), (0, cy, zb - 0.07), "gunmetal", 0.006)
    L = d * 0.55
    p.cyl(r, L, (0, cy, zb - 0.12 - L * 0.5), "z", GEAR, 24)
    for z in (zb - 0.2, zb - 0.12 - L + 0.08):
        p.cyl(r * 0.18, r * 0.5, (0, cy + r, z), "y", "brass", 10)
    p.cyl(r * 1.1, 0.05, (0, cy, zb - 0.12 - L), "z", "dark", 24)
    p.cyl(r * 1.05, 0.04, (0, cy, zb - 0.14), "z", "dark", 24)
    p.box((r * 0.9, 0.003, L * 0.3), (0, cy + r + 0.001, zb - 0.12 - L * 0.5), "white", 0.0)
    p.note(power_kw=3.0, load_kg=15000.0)
    zr = zb - 0.12 - L
    p.moving("rod", (0, cy, zr), kind="slide", axis=(0, 0, -1), stowed=0.0, deployed=0.8 * d / 1.6, seconds=4.0, order=1)
    back = L * 0.95
    z0, z1 = zr + back, -d * 0.5 + 0.12
    p.cyl(r * 0.5, z0 - z1, (0, cy, (z0 + z1) * 0.5), "z", "chrome", 18)
    p.cyl(r * 0.7, 0.08, (0, cy, -d * 0.5 + 0.1), "z", "gunmetal", 16)
    p.cyl(r * 0.8, r * 1.2, (0, cy, -d * 0.5 + 0.06), "x", "gunmetal", 18)
    p.cyl(r * 0.35, r * 1.3, (0, cy, -d * 0.5 + 0.06), "x", "steel", 12)
    p.fixed()


def r_door_motor(p, s):
    # A door drive: a finned motor, a gearbox with its cover bolts, a brake, a terminal box and
    # the output pinion that turns.
    w, h, d = s
    p.floor_box((w, 0.02, d), (0, 0, 0), "gunmetal", 0.004)
    r = min(h, d) * 0.32
    p.cyl(r, w * 0.5, (-w * 0.2, h * 0.45, 0), "x", "gunmetal", 20)
    for i in range(8):
        p.torus(r * 1.02, r * 0.06, (-w * 0.4 + i * w * 0.055, h * 0.45, 0), "x", "dark", 20, 4)
    p.box((w * 0.32, h * 0.8, d * 0.8), (w * 0.2, h * 0.42, 0), MINER_Y, 0.008)
    for sy in (-1, 1):
        for sz in (-1, 1):
            p.cyl(0.008, 0.01, (w * 0.36 + 0.004, h * 0.42 + sy * h * 0.3, sz * d * 0.3), "x", "chrome", 6, 0.0)
    p.box((w * 0.18, h * 0.2, d * 0.35), (-w * 0.2, h * 0.86, 0), "dark", 0.004)
    p.cyl(0.012, 0.04, (-w * 0.16, h * 0.97, d * 0.1), "y", "brass", 8)
    p.note(power_kw=1.5, load_kg=800.0)
    p.moving("pinion", (w * 0.42, h * 0.42, 0), kind="spin", axis=(1, 0, 0), stowed=0.0, deployed=360.0, seconds=1.0, order=1)
    p.cyl(r * 0.6, w * 0.12, (w * 0.42, h * 0.42, 0), "x", "steel", 12)
    for i in range(12):
        t = i * math.pi / 6
        p.box((w * 0.12, 0.012, 0.012), (w * 0.42, h * 0.42 + math.sin(t) * r * 0.62, math.cos(t) * r * 0.62), "steel", 0.0, rot_x=-t)
    p.fixed()


def r_docking_clamp(p, s):
    # A docking clamp: a housing on the hull with a magnetic pad, and two claws on hinges either
    # side, each worked by a ram, with toothed jaws and status lamps.
    w, h, d = s
    p.floor_box((w, 0.08, d), (0, 0, 0), "gunmetal", 0.01)
    p.floor_box((w * 0.5, h * 0.4, d * 0.7), (0, 0.08, 0), MINER_Y, 0.015)
    p.cyl(w * 0.18, 0.05, (0, h * 0.48 + 0.025, 0), "y", "dark", 24)
    p.cyl(w * 0.15, 0.052, (0, h * 0.48 + 0.026, 0), "y", "steel", 24)
    bolt_row(p, (-w * 0.45, 0.08, -d * 0.45), (w * 0.45, 0.08, -d * 0.45), 6, 0.012)
    bolt_row(p, (-w * 0.45, 0.08, d * 0.45), (w * 0.45, 0.08, d * 0.45), 6, 0.012)
    for sx in (-1, 1):
        p.lamp(0.02, (sx * w * 0.15, h * 0.3, -d * 0.35 - 0.004), "-z", "lamp_green" if sx < 0 else "lamp_red")
        p.cyl(0.04, d * 0.6, (sx * w * 0.3, 0.2, 0), "z", "dark", 14)
        p.rod((sx * w * 0.12, 0.14, d * 0.25), (sx * w * 0.32, h * 0.45, d * 0.25), 0.035, "chrome", 10)
    p.note(power_kw=6.0, load_kg=60000.0)
    for sx, name in ((-1, "jaw_l"), (1, "jaw_r")):
        p.moving(name, (sx * w * 0.3, 0.2, 0), kind="hinge", axis=(0, 0, 1), stowed=-60.0 * sx, deployed=0.0, seconds=6.0, order=1)
        x0 = sx * w * 0.3
        p.prism([(x0 - sx * 0.05, 0.15), (x0 + sx * 0.12, 0.2), (x0 + sx * 0.12, h - 0.05), (x0 - sx * w * 0.18, h),
                 (x0 - sx * w * 0.2, h - 0.12), (x0 - sx * 0.02, h - 0.2)], d * 0.5, (0, 0, 0), "z", GEAR, 0.01)
        for i in range(4):
            p.box((0.04, 0.04, d * 0.1), (x0 - sx * w * 0.17, h - 0.1, -d * 0.18 + i * d * 0.12), "chrome", 0.004)
    p.fixed()


# --- booms, masts, arrays and the gangway ---

def r_crane_boom(p, s):
    # A slewing deck crane: a bolted pedestal, the slewing house with its winch, sheaves and
    # cab, a lattice boom that luffs, and the hook block that lowers on its ropes.
    w, h, d = s
    pz = d * 0.5 - w * 0.5
    p.cyl(w * 0.46, 0.16, (0, 0.08, pz), "y", "gunmetal", 32)
    p.bolts((0, 0.165, pz), w * 0.4, 16, "y", 0.014)
    p.torus(w * 0.42, 0.02, (0, 0.17, pz), "y", "dark", 32, 4)
    p.note(power_kw=20.0, load_kg=8000.0)
    p.moving("turret", (0, 0.17, pz), kind="spin", axis=(0, 1, 0), stowed=0.0, deployed=270.0, seconds=40.0, order=1)
    p.box((w * 0.8, h * 0.42, w * 0.9), (0, 0.17 + h * 0.21, pz + w * 0.02), MINER_Y, 0.03)
    p.box((w * 0.3, h * 0.26, w * 0.3), (w * 0.28, 0.17 + h * 0.42 + h * 0.1, pz - w * 0.2), "gunmetal", 0.02)
    p.box((w * 0.28, h * 0.14, 0.02), (w * 0.28, 0.17 + h * 0.56, pz - w * 0.35 - 0.005), "glass_dark", 0.004)
    p.cyl(h * 0.1, w * 0.5, (-w * 0.1, 0.17 + h * 0.48, pz + w * 0.2), "x", "dark", 20)
    for i in range(6):
        p.torus(h * 0.1, 0.006, (-w * 0.32 + i * w * 0.09, 0.17 + h * 0.48, pz + w * 0.2), "x", "steel", 20, 3)
    p.grille(w * 0.4, h * 0.14, (0, 0.17 + h * 0.2, pz + w * 0.47 + 0.005), "z", 6)
    apex = (0, h - 0.06, pz + w * 0.25)
    for sx in (-1, 1):
        p.rod((sx * w * 0.35, 0.17 + h * 0.42, pz + w * 0.4), apex, 0.03, MINER_Y, 8)
        p.rod((sx * w * 0.35, 0.17 + h * 0.42, pz), apex, 0.03, MINER_Y, 8)
    p.cyl(0.06, 0.08, apex, "x", "steel", 14)
    p.lamp(0.025, (0, h - 0.02, pz + w * 0.25), "y", "lamp_red")
    by = 0.17 + h * 0.3
    bz = pz - w * 0.4
    p.moving("boom", (0, by, bz), parent="turret", kind="hinge", axis=(1, 0, 0), stowed=0.0, deployed=35.0,
             seconds=20.0, order=2)
    L = bz - (-d * 0.5 + 0.25)
    for sx in (-1, 1):
        for yy in (0.0, h * 0.28):
            p.bar((sx * w * 0.22, by + yy, bz), (sx * w * 0.12, by + yy * 0.5 + 0.05, bz - L), 0.06, MINER_Y)
    for i in range(10):
        z0 = bz - L * i / 10
        z1 = bz - L * (i + 1) / 10
        k0 = 1 - 0.45 * i / 10
        for sx in (-1, 1):
            p.rod((sx * w * 0.22 * k0, by + (0 if i % 2 else h * 0.28 * k0), z0), (sx * w * 0.22 * k0, by + (h * 0.28 * k0 if i % 2 else 0), z1), 0.018, "gunmetal", 6)
        p.rod((-w * 0.22 * k0, by + h * 0.28 * k0, z0), (w * 0.22 * k0, by, z1), 0.016, "gunmetal", 6)
    p.cyl(0.12, w * 0.3, (0, by + 0.1, -d * 0.5 + 0.25), "x", "dark", 18)
    p.cyl(0.1, w * 0.32, (0, by + 0.1, -d * 0.5 + 0.25), "x", "steel", 18)
    p.lamp(0.03, (0, by + 0.22, -d * 0.5 + 0.22), "-z", "lamp_red")
    p.moving("hook", (0, by + 0.1, -d * 0.5 + 0.25), parent="boom", kind="slide", axis=(0, -1, 0), stowed=0.0,
             deployed=0.6, seconds=15.0, order=3)
    for sx in (-1, 1):
        p.rod((sx * 0.04, by + 0.05, -d * 0.5 + 0.25), (sx * 0.04, by - 0.35, -d * 0.5 + 0.25), 0.008, "steel", 6)
    p.box((0.18, 0.2, 0.12), (0, by - 0.45, -d * 0.5 + 0.25), MINER_Y, 0.01)
    p.torus(0.07, 0.02, (0, by - 0.62, -d * 0.5 + 0.25), "z", "steel", 16, 6)
    p.fixed()


def r_antenna_mast(p, s):
    # A telescopic mast: a flanged base with its motor and cable gland, three nested sections
    # with collars, and a head with a whip, a small dish and a beacon.
    w, h, d = s
    p.cyl(w * 0.48, 0.04, (0, 0.02, 0), "y", "gunmetal", 24)
    p.bolts((0, 0.042, 0), w * 0.38, 6, "y", 0.01)
    p.cyl(w * 0.3, h * 0.76, (0, 0.04 + h * 0.38, 0), "y", GEAR, 20)
    for i in range(3):
        p.torus(w * 0.31, w * 0.02, (0, 0.2 + i * h * 0.25, 0), "y", "dark", 20, 4)
    p.box((w * 0.3, h * 0.12, w * 0.25), (w * 0.3, 0.1, 0), "dark", 0.006)
    p.cyl(0.02, 0.06, (w * 0.42, 0.1, 0), "x", "brass", 8)
    p.note(power_kw=1.0, load_kg=0.0)
    parent = "base"
    radii = (0.22, 0.16, 0.11)
    y0 = 0.08
    for i, rr in enumerate(radii):
        name = "mast_%d" % (i + 1)
        top = h * (0.8 + i * 0.04)
        p.moving(name, (0, top, 0), parent=parent, kind="slide", axis=(0, 1, 0), stowed=0.0, deployed=0.8, seconds=10.0 / 3,
                 order=i + 1)
        p.cyl(w * rr, top - y0, (0, (top + y0) * 0.5, 0), "y", "steel", 18)
        p.torus(w * rr * 1.08, w * 0.03, (0, top - 0.02, 0), "y", "dark", 18, 4)
        parent = name
        y0 += 0.02
    y = top
    sec = h * 0.05
    hy = y + sec * 0.15
    p.box((w * 0.3, 0.05, w * 0.3), (0, hy, 0), "gunmetal", 0.004)
    p.rod((w * 0.1, hy, 0), (w * 0.1, h, 0), 0.006, "chrome", 6)
    p.cyl(w * 0.22, 0.03, (-w * 0.12, hy + 0.08, 0), "z", "white", 16, 0.0, r2=w * 0.05)
    p.lamp(0.02, (0, hy + 0.04, -w * 0.15), "-z", "lamp_red")
    p.fixed()


def folding_array(p, s, kind):
    # A folding array: a hinge bracket and a fixed first panel, two more panels stacked on it that
    # unfold out to the side one after the other (accordion), each with its own frame.
    w, h, d = s
    p.box((w * 0.3, 0.08, d * 0.12), (-w * 0.3, 0.04, d * 0.44), "gunmetal", 0.006)
    p.cyl(0.04, w * 0.9, (0, 0.1, d * 0.44), "x", "dark", 12)
    pt = 0.04
    gap = (h - 0.1) / 3

    def panel(y0):
        p.box((w * 0.98, pt, d * 0.96), (0, y0 + pt * 0.5, 0), "gunmetal", 0.004)
        if kind == "solar":
            nx, nz = 4, 9
            for i in range(nx):
                for j in range(nz):
                    p.box((w * 0.98 / nx * 0.9, 0.006, d * 0.96 / nz * 0.9),
                          (-w * 0.49 + (i + 0.5) * w * 0.98 / nx, y0 + pt + 0.003, -d * 0.48 + (j + 0.5) * d * 0.96 / nz), CELL, 0.0)
        else:
            for i in range(18):
                p.box((w * 0.9, 0.012, 0.025), (0, y0 + pt + 0.006, -d * 0.44 + i * d * 0.052), "steel", 0.0)
            for sx in (-1, 1):
                p.cyl(0.018, d * 0.92, (sx * w * 0.44, y0 + pt + 0.02, 0), "z", "copper", 10)
        p.box((w * 0.98, 0.012, 0.02), (0, y0 + pt + 0.006, -d * 0.48), "hazard", 0.0)

    panel(0.12)
    p.note(power_kw=2.0, load_kg=0.0)
    p.moving("panel_2", (w * 0.5, 0.12 + gap, 0), kind="hinge", axis=(0, 0, 1), stowed=0.0, deployed=-180.0, seconds=15.0,
             order=1)
    panel(0.12 + gap)
    for z in (-d * 0.3, 0.0, d * 0.3):
        p.cyl(0.03, 0.12, (w * 0.5, 0.12 + gap, z), "z", "steel", 10)
    p.moving("panel_3", (-w * 0.5, 0.12 + gap * 2, 0), parent="panel_2", kind="hinge", axis=(0, 0, 1), stowed=0.0,
             deployed=180.0, seconds=15.0, order=2)
    panel(0.12 + gap * 2)
    for z in (-d * 0.3, 0.0, d * 0.3):
        p.cyl(0.03, 0.12, (-w * 0.5, 0.12 + gap * 2, z), "z", "steel", 10)
    p.fixed()


def r_folding_solar_array(p, s):
    folding_array(p, s, "solar")


def r_folding_radiator(p, s):
    folding_array(p, s, "radiator")


def r_gangway_tube(p, s):
    # A telescopic boarding gangway: a docking frame on the hull around the door, three nested
    # tunnel sections with ribs, window strips and lit floors that run out, and a soft seal.
    w, h, d = s
    zb = d * 0.5
    p.box((w, 0.16, 0.12), (0, h - 0.08, zb - 0.06), "gunmetal", 0.01)
    p.box((w, 0.16, 0.12), (0, 0.08, zb - 0.06), "gunmetal", 0.01)
    for sx in (-1, 1):
        p.box((0.16, h - 0.32, 0.12), (sx * (w * 0.5 - 0.08), h * 0.5, zb - 0.06), "gunmetal", 0.01)
        p.lamp(0.03, (sx * (w * 0.5 - 0.08), h - 0.25, zb - 0.125), "-z", "lamp_green")
    p.note(power_kw=12.0, load_kg=2000.0, opening=[1.4, 2.2])
    parent = "base"
    z = zb - 0.12
    L = (d - 0.12) / 3
    for i in range(3):
        k = 1 - i * 0.07
        sw, sh = w * 0.92 * k, h * 0.92 * k
        name = "tube_%d" % (i + 1)
        p.moving(name, (0, 0, zb - 0.12), parent=parent, kind="slide", axis=(0, 0, -1), stowed=0.0, deployed=round(4.0 / 3, 3),
                 seconds=10.0, order=i + 1)
        L = d - 0.2 - i * 0.04
        zc = zb - 0.12 - L * 0.5
        y0 = (h - sh) * 0.5
        p.box((sw, 0.06, L), (0, y0 + sh - 0.03, zc), HULL, 0.008)
        p.box((sw, 0.06, L), (0, y0 + 0.03, zc), HULL, 0.008)
        for sx in (-1, 1):
            p.box((0.06, sh - 0.12, L), (sx * (sw * 0.5 - 0.03), y0 + sh * 0.5, zc), HULL, 0.008)
            p.box((0.065, sh * 0.15, L * 0.8), (sx * (sw * 0.5 - 0.03), y0 + sh * 0.65, zc), "glass_dark", 0.002)
        for j in range(3):
            zz = zb - 0.12 - 0.05 - j * (L - 0.1) / 2
            p.box((sw + 0.03, 0.04, 0.05), (0, y0 + sh, zz), "gunmetal", 0.004)
            p.box((sw + 0.03, 0.04, 0.05), (0, y0, zz), "gunmetal", 0.004)
            for sx in (-1, 1):
                p.box((0.04, sh, 0.05), (sx * (sw * 0.5 + 0.015), y0 + sh * 0.5, zz), "gunmetal", 0.004)
        p.box((sw * 0.8, 0.012, L * 0.9), (0, y0 + 0.066, zc), "dark", 0.0)
        p.box((sw * 0.6, 0.012, L * 0.9), (0, y0 + sh - 0.066, zc), "lamp_white", 0.0)
        parent = name
        z = 0.0 + z - 0.0
    ze = -d * 0.5 + 0.06
    sw, sh = w * 0.92 * 0.86, h * 0.92 * 0.86
    y0 = (h - sh) * 0.5
    p.box((sw + 0.12, 0.1, 0.1), (0, y0 + sh, ze), "rubber", 0.01)
    p.box((sw + 0.12, 0.1, 0.1), (0, y0, ze), "rubber", 0.01)
    for sx in (-1, 1):
        p.box((0.1, sh, 0.1), (sx * (sw * 0.5 + 0.06), y0 + sh * 0.5, ze), "rubber", 0.01)
        for j in range(2):
            p.box((0.06, 0.12, 0.08), (sx * (sw * 0.5 + 0.05), y0 + sh * (0.3 + j * 0.4), ze - 0.06), "chrome", 0.006)
    p.fixed()


# --- cargo fittings: always empty ---

def upright_frame(p, x, h, d, colour, holes=True):
    """A rack upright frame: two punched columns, braced, with base plates."""
    for sz in (-1, 1):
        z = sz * (d * 0.5 - 0.05)
        p.floor_box((0.09, h, 0.07), (x, 0, z), colour, 0.006)
        if holes:
            for i in range(int(h / 0.1)):
                p.box((0.02, 0.04, 0.072), (x, 0.08 + i * 0.1, z), "dark", 0.0)
        p.floor_box((0.16, 0.012, 0.14), (x, 0, z), "steel", 0.002)
        p.cyl(0.008, 0.008, (x + 0.05, 0.016, z), "y", "chrome", 6, 0.0)
    n = max(2, int(h / 0.6))
    for i in range(n):
        y0 = 0.15 + i * (h - 0.3) / n
        y1 = 0.15 + (i + 1) * (h - 0.3) / n
        sz = 1 if i % 2 else -1
        p.rod((x, y0, sz * (d * 0.5 - 0.09)), (x, y1, -sz * (d * 0.5 - 0.09)), 0.012, colour, 6)
        p.rod((x, y0, -(d * 0.5 - 0.09)), (x, y0, d * 0.5 - 0.09), 0.012, colour, 6)


def beam_level(p, x0, x1, y, d, colour, deck="wire"):
    """A pair of step beams between two frames at y, with empty decking."""
    for sz in (-1, 1):
        p.box((x1 - x0 - 0.09, 0.11, 0.05), ((x0 + x1) * 0.5, y, sz * (d * 0.5 - 0.06)), colour, 0.005)
        for x in (x0 + 0.06, x1 - 0.06):
            p.box((0.02, 0.13, 0.05), (x, y, sz * (d * 0.5 - 0.06)), "steel", 0.0)
    if deck == "wire":
        span = x1 - x0 - 0.1
        for i in range(int(span / 0.1)):
            p.box((0.008, 0.008, d - 0.16), (x0 + 0.1 + i * 0.1, y + 0.06, 0), "steel", 0.0)
        for j in range(3):
            p.box((span, 0.02, 0.02), ((x0 + x1) * 0.5, y + 0.05, -d * 0.3 + j * d * 0.3), "steel", 0.0)
    elif deck == "board":
        span = x1 - x0 - 0.1
        p.box((span, 0.022, d - 0.14), ((x0 + x1) * 0.5, y + 0.066, 0), "wood", 0.002)


def r_pallet_racking(p, s):
    # Empty pallet racking: blue punched upright frames, orange step beams at three levels with
    # wire decking, column guards and a row-end barrier. Nothing on it (a new ship).
    w, h, d = s
    bays = 3
    xs = [-w * 0.5 + 0.06 + i * (w - 0.12) / bays for i in range(bays + 1)]
    for x in xs:
        upright_frame(p, x, h, d, RACK_BLUE)
        p.floor_box((0.18, 0.4, 0.12), (x, 0, -d * 0.5 + 0.03), "hazard", 0.01)
    for i in range(bays):
        for y in (0.15, h * 0.36, h * 0.68):
            beam_level(p, xs[i], xs[i + 1], y, d, RACK_ORANGE, "wire" if y > 0.2 else "none")
    for sx in (-1, 1):
        p.floor_box((0.08, 0.5, d), (sx * (w * 0.5 - 0.04), 0, 0), "hazard", 0.01)
    p.box((0.3, 0.12, 0.01), (xs[0] + 0.25, h * 0.36 + 0.14, -d * 0.5 + 0.03), "white", 0.0)


def r_longspan_shelving(p, s):
    # Empty long-span shelving: steel angle uprights, boxed beams and chipboard decks at four
    # levels, label strips and back ties. Empty (a new ship).
    w, h, d = s
    bays = 2
    xs = [-w * 0.5 + 0.05 + i * (w - 0.1) / bays for i in range(bays + 1)]
    for x in xs:
        upright_frame(p, x, h, d, (0.55, 0.57, 0.6), holes=True)
    for i in range(bays):
        for k in range(4):
            y = 0.12 + k * (h - 0.3) / 3
            beam_level(p, xs[i], xs[i + 1], y, d, (0.55, 0.57, 0.6), "board")
            p.box((xs[i + 1] - xs[i] - 0.2, 0.04, 0.005), ((xs[i] + xs[i + 1]) * 0.5, y, -d * 0.5 + 0.03), "white", 0.0)
        p.rod((xs[i], h * 0.3, d * 0.5 - 0.05), (xs[i + 1], h * 0.7, d * 0.5 - 0.05), 0.008, "steel", 6)
        p.rod((xs[i], h * 0.7, d * 0.5 - 0.05), (xs[i + 1], h * 0.3, d * 0.5 - 0.05), 0.008, "steel", 6)


def r_mezzanine_racking(p, s):
    # An empty racking mezzanine: shelving bays underneath, a steel deck on beams and columns at
    # head height with a mesh floor, kick plates and handrails, a fixed ladder and a gate.
    w, h, d = s
    deck = h * 0.55
    for x in (-w * 0.48, -w * 0.16, w * 0.16, w * 0.48):
        for z in (-d * 0.45, d * 0.45):
            p.floor_box((0.12, deck, 0.12), (x, 0, z), "gunmetal", 0.008)
            p.floor_box((0.25, 0.015, 0.25), (x, 0, z), "steel", 0.002)
    for z in (-d * 0.45, d * 0.45):
        p.box((w, 0.2, 0.1), (0, deck - 0.1, z), "gunmetal", 0.008)
    for i in range(7):
        p.box((0.08, 0.16, d * 0.9), (-w * 0.48 + i * w * 0.16, deck - 0.1, 0), "gunmetal", 0.006)
    p.box((w, 0.04, d), (0, deck + 0.02, 0), "dark", 0.004)
    for i in range(30):
        p.box((0.01, 0.042, d * 0.98), (-w * 0.49 + i * w / 30, deck + 0.022, 0), "steel", 0.0)
    for z in (-d * 0.5 + 0.03, d * 0.5 - 0.03):
        p.box((w, 0.12, 0.012), (0, deck + 0.1, z), "hazard", 0.0)
    rail_y = h - 0.05
    posts = [(-w * 0.49 + i * w * 0.98 / 6) for i in range(7)]
    for x in posts:
        for z in (-d * 0.48, d * 0.48):
            p.rod((x, deck + 0.04, z), (x, rail_y, z), 0.02, "hazard", 8)
    for z in (-d * 0.48, d * 0.48):
        p.rod((-w * 0.49, rail_y, z), (w * 0.49, rail_y, z), 0.025, "hazard", 8)
        p.rod((-w * 0.49, (deck + rail_y) * 0.5, z), (w * 0.49, (deck + rail_y) * 0.5, z), 0.018, "hazard", 8)
    for sx in (-1, 1):
        p.rod((sx * w * 0.49, rail_y, -d * 0.48), (sx * w * 0.49, rail_y, d * 0.48), 0.025, "hazard", 8)
    for sx in (-1, 1):
        x = -w * 0.38 + sx * 0.22
        p.rod((x, 0, -d * 0.5 + 0.06), (x, h - 0.1, -d * 0.5 + 0.06), 0.022, "hazard", 8)
    for i in range(int(deck / 0.3)):
        p.rod((-w * 0.38 - 0.22, 0.3 + i * 0.3, -d * 0.5 + 0.06), (-w * 0.38 + 0.22, 0.3 + i * 0.3, -d * 0.5 + 0.06), 0.014, "steel", 6)
    xs = [-w * 0.3, -w * 0.05, w * 0.2, w * 0.45]
    for x in xs:
        upright_frame(p, x, deck - 0.25, d * 0.7, RACK_BLUE, holes=False)
    for i in range(len(xs) - 1):
        for y in (0.12, deck * 0.45):
            beam_level(p, xs[i], xs[i + 1], y, d * 0.7, RACK_ORANGE, "board")


def r_container_mounting(p, s):
    # A container mounting: two long base rails and cross members bolted to the deck, with ISO
    # corner castings and twist locks at the ends and mid-points, and lashing points.
    w, h, d = s
    for sx in (-1, 1):
        p.floor_box((0.22, h * 0.5, d), (sx * (w * 0.5 - 0.11), 0, 0), "gunmetal", 0.01)
        bolt_row(p, (sx * (w * 0.5 - 0.11), h * 0.5, -d * 0.45), (sx * (w * 0.5 - 0.11), h * 0.5, d * 0.45), 14, 0.014)
    for i in range(6):
        z = -d * 0.45 + i * d * 0.18
        p.floor_box((w - 0.44, h * 0.35, 0.14), (0, 0, z), "gunmetal", 0.008)
    for sx in (-1, 1):
        for z in (-d * 0.5 + 0.12, d * 0.5 - 0.12, 0.0):
            x = sx * (w * 0.5 - 0.11)
            p.floor_box((0.2, h * 0.3, 0.2), (x, h * 0.5, z), "hazard", 0.008)
            p.cyl(0.05, h * 0.2, (x, h * 0.8 + h * 0.1, z), "y", "chrome", 12, 0.005, r2=0.03)
            p.box((0.12, 0.02, 0.03), (x + sx * 0.12, h * 0.6, z), "steel", 0.0)
    for sx in (-1, 1):
        for z in (-d * 0.3, d * 0.3):
            p.torus(0.05, 0.012, (sx * (w * 0.5 - 0.03), h * 0.5, z), "x", "steel", 12, 6)


def r_tie_down_rails(p, s):
    # Flush tie-down rails: five L-track rails along the deck with their slotted channels, bolt
    # heads, and D-rings fitted at intervals.
    w, h, d = s
    for i in range(5):
        x = -w * 0.45 + i * w * 0.225
        p.floor_box((0.08, h * 0.6, d), (x, 0, 0), "steel", 0.004)
        for j in range(int(d / 0.1)):
            p.box((0.03, h * 0.62, 0.05), (x, h * 0.3, -d * 0.5 + 0.05 + j * 0.1), "dark", 0.0)
        bolt_row(p, (x + 0.032, h * 0.6, -d * 0.48), (x + 0.032, h * 0.6, d * 0.48), 10, 0.006)
        for z in (-d * 0.3, 0.0, d * 0.3):
            p.box((0.06, h * 0.4, 0.06), (x, h * 0.6 + h * 0.2, z), "gunmetal", 0.004)
            p.torus(0.04, 0.008, (x, h * 0.75, z - 0.04), "x", "chrome", 12, 6)


RECIPES.update({
    "belly_hatch": r_belly_hatch, "undercarriage_doors": r_undercarriage_doors, "clamshell_doors": r_clamshell_doors,
    "side_hold_door": r_side_hold_door, "tail_ramp": r_tail_ramp, "airstair": r_airstair,
    "landing_foot_pad": r_landing_foot_pad, "landing_skid": r_landing_skid, "stabiliser_jack": r_stabiliser_jack,
    "undercarriage_leg": r_undercarriage_leg, "hydraulic_ram": r_hydraulic_ram, "door_motor": r_door_motor,
    "docking_clamp": r_docking_clamp, "crane_boom": r_crane_boom, "antenna_mast": r_antenna_mast,
    "folding_solar_array": r_folding_solar_array, "folding_radiator": r_folding_radiator,
    "gangway_tube": r_gangway_tube, "pallet_racking": r_pallet_racking, "longspan_shelving": r_longspan_shelving,
    "mezzanine_racking": r_mezzanine_racking, "container_mounting": r_container_mounting,
    "tie_down_rails": r_tie_down_rails,
})
