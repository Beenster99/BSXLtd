"""Detailed recipes that replace earlier simpler ones (beenster, 19 Nov: "more detail for the
landing gear and mining heads"): landing gear in four sizes and mining heads in four sizes.
Loaded after the other recipe files, so these ids win."""

import math

from recipes_hull import mount_plate

RECIPES = {}

# Landing gear paint: a pale grey enamel over the forgings.
GEAR = (0.66, 0.68, 0.7)


# --- shared detail ---

def hose(p, points, r, fittings=True):
    """A rubber hydraulic hose along `points`, brass fittings at its ends."""
    p.pipe_run(points, r, "rubber")
    if fittings:
        for q in (points[0], points[-1]):
            p.sphere(r * 1.7, q, "brass", 10, 6)


def bolt_row(p, a, b, n, r, axis="y", material="chrome"):
    """`n` bolt heads in a line from a to b, standing along `axis`."""
    for i in range(n):
        t = i / max(1, n - 1)
        at = tuple(a[j] + (b[j] - a[j]) * t for j in range(3))
        p.cyl(r, r * 0.8, at, axis, material, 6, 0.0)


def stripes(p, w, h, at, n=5, depth=0.01, facing_z=-1):
    """A hazard panel: a dark plate with yellow diagonal bars, on a face looking along z."""
    p.box((w, h, depth), at, "dark", 0.0)
    for i in range(n):
        x = at[0] - w * 0.5 + (i + 0.5) * w / n
        p.box((w / n * 0.45, h * 1.25, depth * 1.1), (x, at[1], at[2] + facing_z * depth * 0.2), "hazard", 0.0,
              rot_z=0.7)


def oleo_outer(p, x, y0, y1, z, r):
    """The outer cylinder of an oleo strut from y0 (gland, bottom) up to y1: ribs, a gland nut,
    grease nipples and a charging valve."""
    p.cyl(r, y1 - y0, (x, (y0 + y1) * 0.5, z), "y", GEAR, 24)
    for i in range(4):
        t = i * math.pi * 0.5 + math.pi * 0.25
        p.box((r * 0.35, (y1 - y0) * 0.7, r * 0.35), (x + math.cos(t) * r * 0.95, y0 + (y1 - y0) * 0.55,
              z + math.sin(t) * r * 0.95), GEAR, 0.004)
    p.cyl(r * 1.18, r * 0.5, (x, y0 + r * 0.25, z), "y", "dark", 24)
    p.bolts((x, y0 + r * 0.52, z), r * 1.05, 8, "y", r * 0.09, "chrome")
    p.torus(r * 1.0, r * 0.08, (x, y1 - r * 0.4, z), "y", "steel", 24, 6)
    p.cyl(r * 0.12, r * 0.5, (x + r * 1.1, y1 - r * 1.2, z), "x", "brass", 8)
    p.sphere(r * 0.12, (x - r * 1.05, y0 + (y1 - y0) * 0.3, z), "brass", 8, 6)
    p.box((r * 1.1, r * 0.7, 0.01), (x, y0 + (y1 - y0) * 0.75, z - r - 0.004), "white", 0.0)


def oleo_inner(p, x, y0, y1, z, r):
    """The chrome piston from y0 (axle end) up into the cylinder at y1, with its dust boot."""
    p.cyl(r, y1 - y0, (x, (y0 + y1) * 0.5, z), "y", "chrome", 24)
    for i in range(4):
        p.torus(r * 1.12, r * 0.14, (x, y1 - r * (0.4 + i * 0.32), z), "y", "rubber", 20, 6)


def trunnion_cheeks(p, w, top, h, d, R):
    """Two gusseted cheeks hanging from the mounting plate either side of the trunnion pin."""
    for sx in (-1, 1):
        x = sx * w * 0.36
        p.prism([(-d * 0.22, h - 0.06 * R), (d * 0.22, h - 0.06 * R), (d * 0.1, top - 0.08 * R),
                 (-d * 0.1, top - 0.08 * R)], 0.05 * R, (x, 0, 0), "x", GEAR, 0.008)
        p.cyl(0.1 * R, 0.07 * R, (x, top, 0), "x", "dark", 20)
        p.bolts((x + sx * 0.036 * R, top, 0), 0.07 * R, 6, "x", 0.012 * R, "chrome")


def pad(p, cx, cz, pw, pd, R, lit=False):
    """An articulated foot pad: a clevis on its axle, a ribbed cast pad with a bolted rim and a
    rubber sole. Built around the axle at (cx, 0.2 R, cz) down to the floor."""
    ya = 0.2 * R
    t = 0.09 * R
    for sx in (-1, 1):
        p.prism([(-0.09 * R, t), (0.09 * R, t), (0.05 * R, ya + 0.06 * R), (-0.05 * R, ya + 0.06 * R)],
                0.035 * R, (cx + sx * 0.09 * R, 0, cz), "x", "gunmetal", 0.004)
    p.cyl(0.045 * R, 0.26 * R, (cx, ya, cz), "x", "steel", 14)
    p.sphere(0.075 * R, (cx, t + 0.04 * R, cz), "gunmetal", 16, 8)
    oct_ = []
    for i in range(8):
        a = (i + 0.5) * math.pi / 4
        oct_.append((cx + math.cos(a) * pw * 0.54, cz + math.sin(a) * pd * 0.54))
    p.prism(oct_, t * 0.55, (0, 0.03 * R + t * 0.275, 0), "y", "dark", 0.01)
    for i in range(8):
        a = i * math.pi / 4
        ex, ez = math.cos(a), math.sin(a)
        p.rod((cx + ex * 0.07 * R, t + 0.02 * R, cz + ez * 0.07 * R),
              (cx + ex * pw * 0.43, 0.05 * R + t * 0.5, cz + ez * pd * 0.43), 0.022 * R, GEAR, 6)
        p.cyl(0.012 * R, 0.01 * R, (cx + ex * pw * 0.47, 0.03 * R + t * 0.56, cz + ez * pd * 0.47), "y", "chrome", 6, 0.0)
    p.floor_box((pw * 0.9, 0.03 * R, pd * 0.9), (cx, 0, cz), "rubber", 0.01)
    p.box((pw * 0.5, 0.012 * R, 0.01), (cx, 0.03 * R + t * 0.3, cz - pd * 0.5), "hazard", 0.0)
    if lit:
        p.lamp(0.02 * R, (cx, t * 0.7, cz - pd * 0.48), "-z", "lamp_amber")


def single_gear(p, s, R, twin=False, light=False):
    """A landing leg hanging from a hull bracket: mounting plate, trunnion cheeks and a rotary
    retract actuator (fixed); the strut that folds back on its trunnion; the oleo that slides up
    into it with a torque link; and the articulated foot pad."""
    w, h, d = s
    top = h - 0.22 * R
    xs = [-w * 0.2, w * 0.2] if twin else [0.0]
    r_out = (0.085 if twin else 0.11) * R
    r_in = r_out * 0.68
    gland = h * 0.42
    ya = 0.2 * R
    # Fixed: the plate in the hull, its bolts, cheeks, the retract actuator, hoses, a lamp.
    p.box((w * 0.92, 0.07 * R, d * 0.62), (0, h - 0.035 * R, 0), "gunmetal", 0.01)
    for sz in (-1, 1):
        bolt_row(p, (-w * 0.4, h - 0.075 * R, sz * d * 0.28), (w * 0.4, h - 0.075 * R, sz * d * 0.28), 6, 0.016 * R)
    trunnion_cheeks(p, w, top, h, d, R)
    p.cyl(0.075 * R, 0.16 * R, (w * 0.5 - 0.08 * R, top, 0), "x", "hazard", 18)
    p.cyl(0.05 * R, 0.04 * R, (w * 0.5 - 0.01 * R, top, 0), "x", "dark", 18)
    p.box((0.12 * R, 0.1 * R, 0.14 * R), (w * 0.4, top + 0.13 * R, d * 0.12), "gunmetal", 0.006)
    hose(p, [(w * 0.4, h - 0.07 * R, d * 0.2), (w * 0.4, top + 0.18 * R, d * 0.2), (w * 0.43, top + 0.06 * R, 0.05 * R)], 0.014 * R)
    hose(p, [(w * 0.3, h - 0.07 * R, d * 0.24), (w * 0.3, top + 0.2 * R, d * 0.18), (w * 0.38, top + 0.08 * R, 0.08 * R)], 0.012 * R)
    p.box((0.1 * R, 0.08 * R, 0.08 * R), (-w * 0.3, h - 0.11 * R, d * 0.24), "dark", 0.006)
    p.lamp(0.02 * R, (-w * 0.3, h - 0.11 * R, d * 0.2), "-z", "lamp_green")
    stripes(p, w * 0.5, 0.05 * R, (0, h - 0.035 * R, -d * 0.31 - 0.006), 6)
    p.note(power_kw=round(4.0 * R * R, 1), load_kg=0.0)
    # The strut: the trunnion pin, a yoke, the outer cylinder(s), braces, the upper torque link.
    p.moving("strut", (0, top, 0.0), kind="hinge", axis=(1, 0, 0), stowed=-90.0, deployed=0.0, seconds=4.0, order=1)
    p.cyl(0.06 * R, w * 0.8, (0, top, 0), "x", "steel", 16)
    p.box((max(w * 0.5, 0.2 * R), 0.16 * R, 0.18 * R), (0, top - 0.06 * R, 0), GEAR, 0.012)
    for x in xs:
        oleo_outer(p, x, gland, top - 0.1 * R, 0.0, r_out)
    if not light:
        p.box((w * 0.12, 0.06 * R, d * 0.36), (0, top - 0.03 * R, -d * 0.2), "gunmetal", 0.006)
    if not light:
        p.rod((0, top - 0.03 * R, -d * 0.36), (xs[0] * 0.5, h * 0.62, -r_out * 0.6), 0.032 * R, "gunmetal", 10)
    for sx in ((-1, 1) if not light else ()):
        p.rod((sx * w * 0.36, top, 0.02 * R), (xs[-1 if sx > 0 else 0] + sx * r_out * 0.8, h * 0.5, 0.0), 0.028 * R, "gunmetal", 10)
        p.sphere(0.04 * R, (xs[-1 if sx > 0 else 0] + sx * r_out * 0.8, h * 0.5, 0.0), "steel", 10, 6)
    if twin:
        p.box((w * 0.4, 0.07 * R, 0.07 * R), (0, gland + 0.12 * R, 0), "gunmetal", 0.006)
    hose(p, [(xs[-1] + r_out * 0.9, top - 0.12 * R, 0.04 * R), (xs[-1] + r_out * 1.05, h * 0.65, 0.05 * R),
             (xs[-1] + r_out * 1.05, gland + 0.12 * R, 0.05 * R)], 0.012 * R)
    for y in (h * 0.75, h * 0.55):
        p.torus(r_out * 0.12, 0.004 * R, (xs[-1] + r_out * 1.05, y, 0.05 * R), "x", "steel", 8, 4)
    zt = -r_out - 0.03 * R
    p.box((0.05 * R, 0.08 * R, 0.06 * R), (0, gland + 0.18 * R, zt), "gunmetal", 0.004)
    p.bar((0, gland + 0.18 * R, zt - 0.02 * R), (0, gland - 0.06 * R, zt - 0.17 * R), 0.035 * R, "steel")
    p.cyl(0.022 * R, 0.07 * R, (0, gland - 0.06 * R, zt - 0.17 * R), "x", "chrome", 10)
    # The oleo: pistons, the axle fork, the lower torque link.
    p.moving("oleo", (0, gland, 0.0), parent="strut", kind="slide", axis=(0, 1, 0), stowed=0.18 * h,
             deployed=0.0, seconds=1.5, order=2)
    for x in xs:
        oleo_inner(p, x, ya + 0.1 * R, gland + 0.05 * R, 0.0, r_in)
    fork_w = (xs[-1] - xs[0]) + 0.26 * R
    p.box((fork_w, 0.1 * R, 0.16 * R), (0, ya + 0.14 * R, 0), GEAR, 0.012)
    for sx in (-1, 1):
        p.box((0.03 * R, 0.14 * R, 0.14 * R), (sx * 0.125 * R, ya + 0.04 * R, 0), "gunmetal", 0.006)
    p.box((0.05 * R, 0.06 * R, 0.06 * R), (0, ya + 0.2 * R, zt + 0.02 * R), "gunmetal", 0.004)
    p.bar((0, ya + 0.2 * R, zt), (0, gland - 0.06 * R, zt - 0.17 * R), 0.035 * R, "steel")
    p.sphere(0.02 * R, (0.06 * R, ya + 0.14 * R, -0.08 * R), "brass", 8, 6)
    if light:
        # A coil spring over the piston between the gland and the fork: a spring-damper leg.
        turns, steps = 7, 140
        y_lo, y_hi, rr = ya + 0.2 * R, gland - 0.04 * R, r_in * 1.9
        for i in range(steps):
            a0, a1 = i / steps, (i + 1) / steps
            t0, t1 = a0 * turns * 2 * math.pi, a1 * turns * 2 * math.pi
            p.rod((math.cos(t0) * rr, y_lo + (y_hi - y_lo) * a0, math.sin(t0) * rr),
                  (math.cos(t1) * rr, y_lo + (y_hi - y_lo) * a1, math.sin(t1) * rr), 0.012 * R, "hazard", 6)
    # The foot.
    p.moving("foot", (0, ya, 0.0), parent="oleo", kind="hinge", axis=(1, 0, 0), stowed=0.0, deployed=0.0,
             seconds=0.5, order=2, swing=12.0, contact={"at": (0, 0, 0), "radius": round(min(w, d) * 0.45, 3)})
    if light:
        p.cyl(0.045 * R, 0.26 * R, (0, ya, 0), "x", "steel", 14)
        p.sphere(0.07 * R, (0, 0.13 * R, 0), GEAR, 16, 8)
        oval = lambda k: [(math.cos(i * math.pi / 12) * w * k, math.sin(i * math.pi / 12) * d * k) for i in range(24)]
        p.prism(oval(0.47), 0.06 * R, (0, 0.06 * R, 0), "y", "dark", 0.01)
        p.prism(oval(0.48), 0.03 * R, (0, 0.015 * R, 0), "y", "rubber", 0.005)
        for i in range(8):
            a = i * math.pi / 4
            p.cyl(0.012 * R, 0.01 * R, (math.cos(a) * w * 0.38, 0.095 * R, math.sin(a) * d * 0.38), "y", "chrome", 6, 0.0)
        for sx in (-1, 1):
            p.rod((0, 0.12 * R, 0), (sx * w * 0.38, 0.09 * R, 0), 0.02 * R, GEAR, 6)
            p.rod((0, 0.12 * R, 0), (0, 0.09 * R, sx * d * 0.4), 0.02 * R, GEAR, 6)
    else:
        pad(p, 0, 0, w, d * 0.9, R, lit=twin)
    p.fixed()


def r_landing_gear_small(p, s):
    single_gear(p, s, s[1] / 2.4, light=True)


def r_landing_gear(p, s):
    single_gear(p, s, s[1] / 2.4)


def r_landing_gear_large(p, s):
    single_gear(p, s, s[1] / 2.4 * 0.9, twin=True)


def r_landing_gear_xl(p, s):
    # A capital-ship bogie: a deep trunnion block in the hull, two main oleos down to a walking
    # beam, four pads each on its own rocking arm, fore and aft drag braces, jacks and hoses.
    w, h, d = s
    R = h / 2.4 * 0.75
    top = h - 0.35 * R
    beam = 0.75 * R
    for sz in (-1, 1):
        bolt_row(p, (-w * 0.42, h - 0.09 * R, sz * d * 0.3), (w * 0.42, h - 0.09 * R, sz * d * 0.3), 9, 0.018 * R)
    p.box((w * 0.94, 0.1 * R, d * 0.66), (0, h - 0.05 * R, 0), "gunmetal", 0.012)
    p.box((w * 0.6, 0.3 * R, d * 0.4), (0, h - 0.25 * R, 0), "gunmetal", 0.02)
    for sx in (-1, 1):
        x = sx * w * 0.36
        p.prism([(-d * 0.3, h - 0.1 * R), (d * 0.3, h - 0.1 * R), (d * 0.12, top - 0.1 * R), (-d * 0.12, top - 0.1 * R)],
                0.07 * R, (x, 0, 0), "x", GEAR, 0.01)
        p.cyl(0.14 * R, 0.1 * R, (x, top, 0), "x", "dark", 24)
        p.bolts((x + sx * 0.05 * R, top, 0), 0.1 * R, 8, "x", 0.014 * R)
        p.cyl(0.1 * R, 0.2 * R, (x + sx * 0.15 * R, top, 0), "x", "hazard", 20)
    for sx in (-1, 1):
        hose(p, [(sx * w * 0.25, h - 0.1 * R, d * 0.28), (sx * w * 0.3, top + 0.25 * R, d * 0.2),
                 (sx * w * 0.42, top + 0.05 * R, 0.1 * R)], 0.018 * R)
        p.lamp(0.035 * R, (sx * w * 0.2, h - 0.2 * R, -d * 0.2 - 0.005), "-z", "lamp_amber")
    stripes(p, w * 0.5, 0.08 * R, (0, h - 0.05 * R, -d * 0.33 - 0.008), 8)
    p.note(power_kw=40.0, load_kg=0.0)
    p.moving("strut", (0, top, 0.0), kind="hinge", axis=(1, 0, 0), stowed=-90.0, deployed=0.0, seconds=8.0, order=1)
    p.cyl(0.09 * R, w * 0.82, (0, top, 0), "x", "steel", 20)
    p.box((w * 0.6, 0.2 * R, 0.3 * R), (0, top - 0.08 * R, 0), GEAR, 0.015)
    xs = (-w * 0.2, w * 0.2)
    r_out = 0.17 * R
    gland = beam + 0.9 * R
    for x in xs:
        oleo_outer(p, x, gland, top - 0.15 * R, 0.0, r_out)
    p.box((w * 0.5, 0.1 * R, 0.1 * R), (0, gland + 0.5 * R, 0), "gunmetal", 0.008)
    for sz in (-1, 1):
        p.rod((0, top - 0.1 * R, sz * d * 0.32), (0, gland + 0.5 * R, sz * 0.05 * R), 0.06 * R, "gunmetal", 12)
        p.box((w * 0.14, 0.1 * R, 0.14 * R), (0, top - 0.1 * R, sz * d * 0.32), "gunmetal", 0.008)
    hose(p, [(xs[1] + r_out, top - 0.2 * R, 0.06 * R), (xs[1] + r_out * 1.1, gland + 0.2 * R, 0.06 * R)], 0.016 * R)
    hose(p, [(xs[0] - r_out, top - 0.2 * R, 0.06 * R), (xs[0] - r_out * 1.1, gland + 0.2 * R, 0.06 * R)], 0.016 * R)
    p.moving("oleo", (0, gland, 0.0), parent="strut", kind="slide", axis=(0, 1, 0), stowed=0.12 * h,
             deployed=0.0, seconds=2.0, order=2)
    for x in xs:
        oleo_inner(p, x, beam + 0.1 * R, gland + 0.05 * R, 0.0, r_out * 0.68)
    p.box((w * 0.7, 0.22 * R, 0.3 * R), (0, beam, 0), GEAR, 0.015)
    p.cyl(0.08 * R, w * 0.9, (0, beam, 0), "x", "steel", 18)
    for sx in (-1, 1):
        p.cyl(0.11 * R, 0.08 * R, (sx * w * 0.45, beam, 0), "x", "hazard", 18)
    feet = []
    for sx in (-1, 1):
        for sz in (-1, 1):
            feet.append((sx * w * 0.27, sz * d * 0.28))
    for sx in (-1, 1):
        x = sx * w * 0.27
        p.bar((x, beam, -d * 0.28), (x, beam, d * 0.28), 0.1 * R, GEAR)
        p.cyl(0.07 * R, 0.16 * R, (x, beam, 0), "x", "dark", 16)
    pw, pd = w * 0.4, d * 0.4
    for i, (x, z) in enumerate(feet):
        p.moving("foot_%d" % (i + 1), (x, 0.2 * R, z), parent="oleo", kind="hinge", axis=(1, 0, 0), stowed=0.0,
                 deployed=0.0, seconds=0.5, order=2, swing=10.0,
                 contact={"at": (x, 0, z), "radius": round(min(pw, pd) * 0.45, 3)})
        pad(p, x, z, pw, pd, R, lit=False)
        p.rod((x, 0.27 * R, z), (x, beam - 0.08 * R, z * 0.92), 0.05 * R, "gunmetal", 10)
    p.fixed()


RECIPES.update({
    "landing_gear_small": r_landing_gear_small,
    "landing_gear": r_landing_gear,
    "landing_gear_large": r_landing_gear_large,
    "landing_gear_xl": r_landing_gear_xl,
})


# --- mining heads ---

MINER = (0.86, 0.62, 0.12)  # mining yellow enamel


def finned_motor(p, r, length, cx, cy, z0, axis="z"):
    """An electric motor along z from z0 towards -Z: a ribbed body, end bells, a terminal box."""
    zc = z0 - length * 0.5
    p.cyl(r, length, (cx, cy, zc), "z", "gunmetal", 28)
    n = max(6, int(length / (r * 0.18)))
    for i in range(n):
        p.torus(r * 1.02, r * 0.05, (cx, cy, z0 - length * (i + 0.5) / n), "z", "dark", 28, 4)
    for zz in (z0 - 0.02, z0 - length + 0.02):
        p.cyl(r * 1.08, 0.04, (cx, cy, zz), "z", MINER, 28)
    p.box((r * 0.7, r * 0.45, length * 0.3), (cx, cy + r * 1.1, zc), "dark", 0.01)
    p.cyl(r * 0.1, r * 0.25, (cx + r * 0.2, cy + r * 1.4, zc + length * 0.08), "y", "brass", 10)
    p.box((r * 0.5, 0.005, length * 0.12), (cx, cy + r * 1.33, zc - length * 0.06), "white", 0.0)


def spray_ring(p, r, cx, cy, z, n=8):
    """A water spray manifold round a shaft: a pipe ring and its nozzles pointing forward."""
    p.torus(r, r * 0.05, (cx, cy, z), "z", "copper", 32, 6)
    for i in range(n):
        t = i * 2 * math.pi / n
        p.cyl(r * 0.05, r * 0.15, (cx + math.cos(t) * r, cy + math.sin(t) * r, z - r * 0.08), "z", "brass", 8, 0.0)


def pick(p, base, out, size):
    """A carbide pick: a holder block on the drum and a shank and tip leaning out along `out`."""
    p.box((size, size * 0.8, size), base, "gunmetal", size * 0.1)
    tip = tuple(base[i] + out[i] * size * 2.2 for i in range(3))
    p.rod(base, tip, size * 0.22, "steel", 8)
    p.sphere(size * 0.2, tip, "chrome", 8, 6)


def r_mining_head_small(p, s):
    # A survey auger: a flange on the hull, a finned gear motor, a stabiliser collar on rollers,
    # a spray ring, and a flighted auger running out to a pilot bit with carbide teeth.
    w, h, d = s
    cy = h * 0.5
    mount_plate(p, s, 0.05)
    zb = d * 0.5 - 0.05
    p.cyl(w * 0.42, 0.04, (0, cy, zb - 0.02), "z", "gunmetal", 28)
    p.bolts((0, cy, zb - 0.045), w * 0.36, 8, "z", 0.012)
    finned_motor(p, w * 0.3, d * 0.22, 0, cy, zb - 0.04)
    z = zb - 0.04 - d * 0.22
    p.box((w * 0.66, w * 0.66, d * 0.08), (0, cy, z - d * 0.04), MINER, 0.015)
    p.cyl(w * 0.05, 0.04, (w * 0.34, cy + w * 0.2, z - d * 0.04), "x", "brass", 8)
    hose(p, [(w * 0.36, cy + w * 0.2, z - d * 0.04), (w * 0.42, cy + w * 0.35, zb - 0.08)], 0.012)
    z -= d * 0.08
    p.cyl(w * 0.24, d * 0.05, (0, cy, z - d * 0.025), "z", "dark", 24)
    for i in range(3):
        t = i * 2 * math.pi / 3 + 0.5
        p.cyl(w * 0.05, w * 0.06, (math.cos(t) * w * 0.26, cy + math.sin(t) * w * 0.26, z - d * 0.025), "z", "chrome", 12)
    z -= d * 0.05
    spray_ring(p, w * 0.22, 0, cy, z - 0.01, 6)
    shaft_l = d * 0.5
    p.cyl(w * 0.06, shaft_l, (0, cy, z - shaft_l * 0.5), "z", "chrome", 16)
    turns, steps = 6, 180
    for i in range(steps):
        a, b = i / steps, (i + 1) / steps
        ta, tb = a * turns * 2 * math.pi, b * turns * 2 * math.pi
        ra = w * 0.33 * (1 - a * 0.35)
        rb = w * 0.33 * (1 - b * 0.35)
        za, zb2 = z - a * shaft_l, z - b * shaft_l
        p.rod((math.cos(ta) * ra, cy + math.sin(ta) * ra, za), (math.cos(tb) * rb, cy + math.sin(tb) * rb, zb2), 0.016, "steel", 6)
        if i % 3 == 0:
            p.rod((math.cos(ta) * w * 0.07, cy + math.sin(ta) * w * 0.07, za), (math.cos(ta) * ra, cy + math.sin(ta) * ra, za),
                  0.012, "steel", 4)
    zt = z - shaft_l
    tip = p.cyl(w * 0.16, d * 0.12, (0, cy, zt - d * 0.06), "z", "dark", 16, r2=0.01)
    tip.rotation_euler[0] += math.pi
    for i in range(4):
        t = i * math.pi / 2
        pick(p, (math.cos(t) * w * 0.12, cy + math.sin(t) * w * 0.12, zt - d * 0.02),
             (math.cos(t) * 0.5, math.sin(t) * 0.5, -0.85), w * 0.06)
    p.lamp(0.018, (w * 0.3, cy - w * 0.3, d * 0.5 - 0.052), "-z", "lamp_amber")


def r_mining_head_medium(p, s):
    # A coring head: flange and slewing ring, a finned motor and gearbox, a rotary water union on
    # its hoses, the drill pipe, a slotted core barrel and a crown of segmented carbide teeth.
    w, h, d = s
    cy = h * 0.5
    mount_plate(p, s, 0.07)
    zb = d * 0.5 - 0.07
    p.torus(w * 0.4, 0.03, (0, cy, zb - 0.02), "z", "dark", 32, 6)
    p.bolts((0, cy, zb - 0.03), w * 0.4, 16, "z", 0.014)
    finned_motor(p, w * 0.3, d * 0.24, 0, cy, zb - 0.05)
    z = zb - 0.05 - d * 0.24
    p.box((w * 0.72, w * 0.62, d * 0.1), (0, cy, z - d * 0.05), MINER, 0.02)
    for sx in (-1, 1):
        p.cyl(w * 0.06, 0.03, (sx * w * 0.37, cy, z - d * 0.05), "x", "dark", 12)
    z -= d * 0.1
    p.cyl(w * 0.14, d * 0.06, (0, cy, z - d * 0.03), "z", "chrome", 20)
    p.cyl(w * 0.18, d * 0.03, (0, cy, z - d * 0.03), "z", "brass", 20)
    for sx in (-1, 1):
        hose(p, [(sx * w * 0.18, cy, z - d * 0.03), (sx * w * 0.38, cy + w * 0.12, z), (sx * w * 0.42, cy + w * 0.3, zb - 0.1)], 0.018)
    z -= d * 0.06
    p.cyl(w * 0.1, d * 0.12, (0, cy, z - d * 0.06), "z", "steel", 18)
    p.torus(w * 0.11, 0.012, (0, cy, z - d * 0.02), "z", "dark", 18, 4)
    z -= d * 0.12
    r = min(w, h) * 0.4
    spray_ring(p, r * 0.75, 0, cy, z - 0.01, 10)
    bl = -d * 0.5 + 0.06 - z
    bl = -bl
    p.cyl(r, bl, (0, cy, z - bl * 0.5), "z", "steel", 36)
    for i in range(6):
        t = i * math.pi / 3
        p.box((0.02, 0.06, bl * 0.55), (math.cos(t) * r * 1.0, cy + math.sin(t) * r * 1.0, z - bl * 0.5), "dark", 0.0,
              rot_z=t)
    for k in (0.15, 0.85):
        p.torus(r * 1.01, 0.015, (0, cy, z - bl * k), "z", MINER, 36, 4)
    p.cyl(r * 0.8, bl * 1.01, (0, cy, z - bl * 0.5), "z", "dark", 32)
    for i in range(16):
        t = i * 2 * math.pi / 16
        p.box((0.06, 0.05, 0.08), (math.cos(t) * r * 0.9, cy + math.sin(t) * r * 0.9, -d * 0.5 + 0.04), "chrome", 0.008,
              rot_z=t)
    p.lamp(0.02, (w * 0.32, cy + w * 0.36, d * 0.5 - 0.072), "-z", "lamp_amber")
    p.lamp(0.02, (-w * 0.32, cy + w * 0.36, d * 0.5 - 0.072), "-z", "lamp_green")


def r_mining_head_large(p, s):
    # A roadheader: a slewing turret on a big bolted bearing, a box-section boom with lightening
    # holes on twin luffing jacks, a gearbox, and a cutter head with picks set on spiral vanes,
    # a spray ring behind them, hoses and a cable chain along the boom.
    w, h, d = s
    cy = h * 0.5
    mount_plate(p, s, 0.1)
    zb = d * 0.5 - 0.1
    p.cyl(w * 0.42, 0.08, (0, cy, zb - 0.04), "z", "dark", 40)
    p.torus(w * 0.42, 0.02, (0, cy, zb - 0.085), "z", "steel", 40, 4)
    p.bolts((0, cy, zb - 0.09), w * 0.38, 20, "z", 0.016)
    zt = zb - 0.08
    p.box((w * 0.66, h * 0.62, d * 0.16), (0, cy, zt - d * 0.08), MINER, 0.04)
    p.grille(w * 0.4, h * 0.16, (0, cy + h * 0.12, zt - d * 0.16), "-z", 6)
    stripes(p, w * 0.5, 0.06, (0, cy - h * 0.24, zt - d * 0.16 - 0.006), 7, 0.008)
    zt -= d * 0.16
    by = cy + h * 0.02
    bl = d * 0.32
    p.box((w * 0.3, h * 0.28, bl), (0, by, zt - bl * 0.5), MINER, 0.025)
    for sx in (-1, 1):
        for i in range(3):
            p.cyl(h * 0.06, 0.01, (sx * (w * 0.15 + 0.003), by, zt - bl * (0.2 + i * 0.3)), "x", "dark", 18, 0.0)
    for sx in (-1, 1):
        a = (sx * w * 0.24, cy - h * 0.26, zt - 0.02)
        b = (sx * w * 0.16, by - h * 0.12, zt - bl * 0.75)
        m = tuple(a[i] + (b[i] - a[i]) * 0.55 for i in range(3))
        p.rod(a, m, 0.05, "gunmetal", 14)
        p.rod(m, b, 0.032, "chrome", 12)
        p.sphere(0.06, a, "dark", 12, 6)
        p.sphere(0.045, b, "dark", 12, 6)
        hose(p, [(sx * w * 0.24, cy - h * 0.2, zt - 0.05), (sx * w * 0.28, cy - h * 0.18, zt - bl * 0.3)], 0.014)
    for i in range(10):
        z = zt - bl * (i + 0.5) / 10
        p.box((0.1, 0.03, bl / 10 * 0.8), (w * 0.17, by + h * 0.16, z), "dark", 0.004)
    zg = zt - bl
    p.cyl(w * 0.16, d * 0.07, (0, by, zg - d * 0.035), "z", "gunmetal", 28)
    p.bolts((0, by, zg - d * 0.07), w * 0.14, 10, "z", 0.012)
    zg -= d * 0.07
    r = min(w, h) * 0.3
    spray_ring(p, r * 0.9, 0, by, zg - 0.02, 12)
    dl = -d * 0.5 + 0.08 - zg
    dl = -dl
    drum = p.cyl(r, dl, (0, by, zg - dl * 0.5), "z", "steel", 32, r2=r * 0.55)
    drum.rotation_euler[0] += math.pi
    vanes, steps = 3, 36
    for v in range(vanes):
        for i in range(steps):
            a = i / steps
            t = v * 2 * math.pi / vanes + a * 1.6 * math.pi
            rr = r * (1 - a * 0.45) * 1.02
            zz = zg - a * dl
            p.box((0.05, 0.05, dl / steps * 1.3), (math.cos(t) * rr, by + math.sin(t) * rr, zz), "gunmetal", 0.004, rot_z=t)
            if i % 4 == 2:
                pick(p, (math.cos(t) * rr * 1.05, by + math.sin(t) * rr * 1.05, zz),
                     (math.cos(t) * 0.75, math.sin(t) * 0.75, -0.6), 0.055)
    nose = p.cyl(r * 0.5, 0.12, (0, by, -d * 0.5 + 0.08), "z", "dark", 20, r2=r * 0.15)
    nose.rotation_euler[0] += math.pi
    for i in range(4):
        t = i * math.pi / 2 + 0.4
        pick(p, (math.cos(t) * r * 0.3, by + math.sin(t) * r * 0.3, -d * 0.5 + 0.1), (math.cos(t) * 0.4, math.sin(t) * 0.4, -0.9), 0.05)
    for sx in (-1, 1):
        p.lamp(0.03, (sx * w * 0.3, cy + h * 0.28, zb - 0.09), "-z", "lamp_white")


def r_mining_head_xl(p, s):
    # A capital twin-drum cutter: a ribbed gear housing on a bolted flange, a ranging arm out to a
    # cross gearbox, two drums each with helical vanes, pick blocks and spray nozzles, end discs,
    # a spoil cowl with a dust curtain, hydraulic jacks, hoses and work lights.
    w, h, d = s
    cy = h * 0.5
    mount_plate(p, s, 0.14)
    zb = d * 0.5 - 0.14
    for sx in (-1, 1):
        bolt_row(p, (sx * w * 0.44, h * 0.1, zb - 0.01), (sx * w * 0.44, h * 0.9, zb - 0.01), 8, 0.022, "z")
    hd = d * 0.26
    p.box((w * 0.62, h * 0.66, hd), (0, cy, zb - hd * 0.5), MINER, 0.05)
    for i in range(7):
        x = -w * 0.27 + i * w * 0.09
        p.box((0.04, h * 0.66, hd * 0.9), (x, cy + 0.005, zb - hd * 0.5 - 0.01), MINER, 0.006)
    p.grille(w * 0.3, h * 0.14, (0, cy + h * 0.18, zb - hd), "-z", 7)
    stripes(p, w * 0.5, 0.08, (0, cy - h * 0.26, zb - hd - 0.008), 9, 0.01)
    za = zb - hd
    al = d * 0.2
    p.box((w * 0.26, h * 0.3, al), (0, cy, za - al * 0.5), "gunmetal", 0.03)
    for sy in (-1, 1):
        a = (-w * 0.24, cy + sy * h * 0.26, za - 0.03)
        b = (-w * 0.1, cy + sy * h * 0.1, za - al * 0.85)
        m = tuple(a[i] + (b[i] - a[i]) * 0.55 for i in range(3))
        p.rod(a, m, 0.07, "gunmetal", 14)
        p.rod(m, b, 0.045, "chrome", 12)
        a2 = (w * 0.24, a[1], a[2])
        b2 = (w * 0.1, b[1], b[2])
        m2 = (w * 0.24 + (w * 0.1 - w * 0.24) * 0.55, m[1], m[2])
        p.rod(a2, m2, 0.07, "gunmetal", 14)
        p.rod(m2, b2, 0.045, "chrome", 12)
    hose(p, [(w * 0.2, cy + h * 0.3, za - 0.05), (w * 0.18, cy + h * 0.25, za - al * 0.7)], 0.02)
    hose(p, [(-w * 0.2, cy + h * 0.3, za - 0.05), (-w * 0.18, cy + h * 0.25, za - al * 0.7)], 0.02)
    zd = za - al
    r = min(h * 0.33, (zd + d * 0.5) * 0.42)
    zc = -d * 0.5 + r * 1.15
    p.box((w * 0.2, h * 0.4, zd - zc + 0.2), (0, cy, (zd + zc) * 0.5), "gunmetal", 0.03)
    p.cyl(0.16, w * 0.96, (0, cy, zc), "x", "chrome", 20)
    for sx in (-1, 1):
        x0 = sx * w * 0.12
        x1 = sx * w * 0.48
        L = abs(x1 - x0)
        xm = (x0 + x1) * 0.5
        p.cyl(r * 0.8, L, (xm, cy, zc), "x", "steel", 32)
        p.cyl(r * 1.0, 0.06, (x1 - sx * 0.03, cy, zc), "x", "dark", 32)
        p.cyl(r * 0.9, 0.05, (x0 + sx * 0.03, cy, zc), "x", "gunmetal", 32)
        steps = 40
        for v in range(2):
            for i in range(steps):
                a = i / steps
                t = v * math.pi + a * 2.2 * math.pi * sx
                x = x0 + sx * L * a
                c, sn = math.cos(t), math.sin(t)
                p.box((L / steps * 1.4, 0.12, 0.12), (x, cy + sn * r * 0.86, zc + c * r * 0.86), "gunmetal", 0.006, rot_x=-t)
                if i % 3 == 1:
                    pick(p, (x, cy + sn * r * 0.95, zc + c * r * 0.95), (0, sn * 0.9, c * 0.9), 0.11)
        for i in range(12):
            t = i * 2 * math.pi / 12
            pick(p, (x1 - sx * 0.02, cy + math.sin(t) * r * 0.95, zc + math.cos(t) * r * 0.95),
                 (sx * 0.5, math.sin(t) * 0.7, math.cos(t) * 0.7), 0.1)
        for i in range(6):
            t = i * math.pi / 3
            p.cyl(0.02, 0.06, (x0 + sx * 0.08, cy + math.sin(t) * r * 0.5, zc + math.cos(t) * r * 0.5), "x", "brass", 8, 0.0)
    p.box((w * 0.92, 0.08, r * 1.6), (0, cy + r * 1.3, zc + r * 0.5), MINER, 0.02)
    for sx in (-1, 1):
        p.box((0.06, r * 1.0, r * 1.4), (sx * w * 0.46, cy + r * 0.85, zc + r * 0.5), MINER, 0.01)
    for i in range(14):
        x = -w * 0.43 + i * w * 0.066
        p.box((w * 0.055, r * 0.5, 0.012), (x, cy + r * 1.0, zc + r * 1.25), "rubber", 0.0)
    for sx in (-1, 1):
        p.lamp(0.05, (sx * w * 0.28, cy + h * 0.3, zb - hd - 0.01), "-z", "lamp_white")
        p.lamp(0.035, (sx * w * 0.42, cy + r * 1.36, zc + r * 0.2), "-z", "lamp_amber")


RECIPES.update({
    "mining_head_small": r_mining_head_small,
    "mining_head_medium": r_mining_head_medium,
    "mining_head_large": r_mining_head_large,
    "mining_head_xl": r_mining_head_xl,
})
