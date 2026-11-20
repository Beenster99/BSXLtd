"""Recipes for the small high-tech parts that beat bigger ones: the plasma drive, the compact
fusion cell and the shield projector.

Each takes (p, s): the Part being built and its catalogue size (w across, h up, d deep). The
plasma drive is hull mounted (plate at z = +d / 2, nozzle out along -Z); the others stand in
rooms and face -Z. They are drawn finer than the plain machines: machined white and chrome
casings, glowing cores behind glass, magnet coils and cable looms.
"""

import math

from recipes_hull import mount_plate

HITECH = (0.86, 0.88, 0.9)
TRIM = (0.24, 0.27, 0.32)


def coil_stack(p, cx, cy, z0, z1, r, n, axis="z", glow="lamp_blue"):
    """Magnet coils wound round a core from z0 to z1, each with a lit gap."""
    for i in range(n):
        t = (i + 0.5) / n
        z = z0 + (z1 - z0) * t
        at = (cx, cy, z) if axis == "z" else (cx, z, cy)
        p.torus(r, r * 0.16, at, axis, "copper", 32, 8)
        p.torus(r * 0.84, r * 0.05, at, axis, glow, 32, 6)


def cable(p, points, r=0.014, material="dark"):
    p.pipe_run(points, r, material)


def r_plasma_drive(p, s):
    w, h, d = s
    cy = h * 0.5
    mount_plate(p, s, 0.07, TRIM)
    zb = d * 0.5 - 0.07
    # Rear housing: a machined white block with chamfered corners and cooling fins.
    hd = d * 0.26
    p.box((w * 0.86, h * 0.86, hd), (0, cy, zb - hd * 0.5), HITECH, 0.05)
    for i in range(7):
        x = -w * 0.33 + i * w * 0.11
        p.box((0.018, h * 0.1, hd * 0.8), (x, cy + h * 0.46, zb - hd * 0.5), "gunmetal", 0.004)
        p.box((0.018, h * 0.1, hd * 0.8), (x, cy - h * 0.46, zb - hd * 0.5), "gunmetal", 0.004)
    for sx in (-1, 1):
        p.grille(hd * 0.7, h * 0.5, (sx * w * 0.432, cy, zb - hd * 0.5), "x" if sx > 0 else "-x", 6)
    # Injector plate and four propellant feeds into the chamber.
    zc = zb - hd
    p.cyl(min(w, h) * 0.36, 0.05, (0, cy, zc - 0.025), "z", "chrome", 32)
    p.bolts((0, cy, zc - 0.05), min(w, h) * 0.32, 12, "z", 0.012)
    for i in range(4):
        t = math.pi * 0.25 + i * math.pi * 0.5
        x, y = math.cos(t) * w * 0.3, cy + math.sin(t) * h * 0.3
        cable(p, [(x, y, zc + 0.02), (x * 0.9, y * 0.9 + cy * 0.1, zc - 0.12), (x * 0.55, cy + (y - cy) * 0.55, zc - 0.22)],
              0.018, "copper")
    # Magnetic chamber: a glass tube with the plasma column inside and coils round it.
    lc = d * 0.34
    rc = min(w, h) * 0.22
    z0, z1 = zc - 0.05, zc - 0.05 - lc
    p.cyl(rc, lc, (0, cy, (z0 + z1) * 0.5), "z", "glass", 32)
    p.cyl(rc * 0.42, lc, (0, cy, (z0 + z1) * 0.5), "z", "lamp_violet", 20)
    p.cyl(rc * 0.2, lc * 1.02, (0, cy, (z0 + z1) * 0.5), "z", "lamp_white", 12)
    coil_stack(p, 0, cy, z0, z1, rc * 1.25, 5, "z", "lamp_blue")
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.rod((sx * rc * 1.15, cy + sy * rc * 1.15, z0), (sx * rc * 1.15, cy + sy * rc * 1.15, z1), 0.012, "chrome")
    # Magnetic nozzle: a short throat ring, then an open lattice bell of coil rings.
    zn = z1
    p.cyl(rc * 1.1, 0.06, (0, cy, zn - 0.03), "z", TRIM, 32)
    ln = zn + d * 0.5 - 0.01
    rmax = min(w, h) * 0.46
    rings = 5
    for i in range(rings):
        t = (i + 1) / rings
        r = rc * 1.05 + (rmax - rc * 1.05) * t * t
        z = zn - 0.06 - ln * 0.95 * t
        p.torus(r, 0.022 + 0.008 * t, (0, cy, z), "z", "gunmetal" if i < rings - 1 else "chrome", 36, 8)
        p.torus(r - 0.03, 0.008, (0, cy, z), "z", "lamp_blue", 36, 6)
    for i in range(6):
        t = i * math.pi / 3
        a = (math.cos(t) * rc * 1.1, cy + math.sin(t) * rc * 1.1, zn - 0.06)
        b = (math.cos(t) * rmax, cy + math.sin(t) * rmax, zn - 0.06 - ln * 0.95)
        p.rod(a, b, 0.014, TRIM)
    # Exhaust glow at the throat, and a status strip and lamps on the housing.
    p.cyl(rc * 0.9, 0.02, (0, cy, zn - 0.08), "z", "lamp_violet", 28)
    p.box((w * 0.5, 0.03, 0.008), (0, cy + h * 0.3, zb - hd - 0.004), "lamp_cyan", 0.0)
    for sx in (-1, 1):
        p.lamp(0.012, (sx * w * 0.32, cy - h * 0.32, zb - hd - 0.004), "-z", "lamp_green" if sx < 0 else "lamp_amber")
    p.box((w * 0.3, 0.035, 0.008), (0, cy - h * 0.3, zb - hd - 0.004), "hazard", 0.0)


def r_compact_fusion_cell(p, s):
    w, h, d = s
    p.floor_box((w, 0.08, d), (0, 0, 0), "dark", 0.012)
    # Four machined corner posts and a top cap: the cell's cage.
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = sx * (w * 0.5 - 0.05), sz * (d * 0.5 - 0.05)
            p.box((0.08, h - 0.08, 0.08), (x, 0.08 + (h - 0.08) * 0.5, z), HITECH, 0.02)
            p.box((0.012, (h - 0.08) * 0.7, 0.084), (x, h * 0.52, z), TRIM, 0.0)
    p.box((w, 0.07, d), (0, h - 0.035, 0), HITECH, 0.02)
    p.box((w * 0.7, 0.02, d * 0.7), (0, h - 0.0, 0), TRIM, 0.006)
    # The toroidal chamber: a fat steel torus on its side with coil windings and a glowing ring.
    c = h * 0.5
    R = min(w, d) * 0.27
    rt = R * 0.48
    p.torus(R, rt, (0, c, 0), "y", (0.62, 0.65, 0.68), 40, 16)
    for i in range(4):
        t = i * math.pi * 0.5
        for k in (-1, 0, 1):
            u = t + k * 0.09
            p.torus(rt * 1.06, 0.014, (math.cos(u) * R, c, math.sin(u) * R), "z" if i % 2 == 0 else "x", "copper", 20, 6)
    p.torus(R, rt * 0.3, (0, c, 0), "y", "lamp_amber", 40, 8)
    # Central solenoid with lit bands, and the window onto the plasma at the front.
    p.cyl(R * 0.38, h * 0.62, (0, c, 0), "y", "chrome", 24)
    for i in range(4):
        p.cyl(R * 0.4, 0.015, (0, c - h * 0.22 + i * h * 0.146, 0), "y", "lamp_amber", 24)
    # Heat-exchanger pipes from the torus down to the base, and power bus bars up to the cap.
    for i in range(4):
        t = math.pi * 0.25 + i * math.pi * 0.5
        x, z = math.cos(t) * R, math.sin(t) * R
        p.pipe_run([(x, c - rt * 0.9, z), (x * 1.5, c - rt * 1.4, z * 1.5), (x * 1.5, 0.1, z * 1.5)], 0.025, "steel")
        p.cyl(0.04, 0.03, (x * 1.5, 0.095, z * 1.5), "y", "gunmetal", 12)
    for sx in (-1, 1):
        p.box((0.05, h * 0.3, 0.02), (sx * R * 0.6, h - 0.07 - h * 0.15, -R * 0.2), "copper", 0.004)
    # Front control plate: screen, gauges, hazard band, lamps.
    zf = -d * 0.5 + 0.02
    p.box((w * 0.62, h * 0.2, 0.03), (0, h * 0.2, zf + 0.01), TRIM, 0.006)
    p.box((w * 0.3, h * 0.12, 0.006), (-w * 0.1, h * 0.2, zf - 0.008), "screen_amber", 0.0)
    for i in range(3):
        p.lamp(0.012, (w * 0.12 + i * 0.045, h * 0.23, zf - 0.006), "-z", ("lamp_green", "lamp_amber", "lamp_red")[i])
    p.box((w * 0.62, 0.03, 0.006), (0, h * 0.09, zf - 0.006), "hazard", 0.0)
    p.box((w * 0.5, 0.03, 0.006), (0, h - 0.11, -d * 0.5 + 0.005), "lamp_amber", 0.0)


def r_shield_projector(p, s):
    w, h, d = s
    # A stepped plinth with a ring of vents.
    p.floor_box((w, 0.06, d), (0, 0, 0), "dark", 0.012)
    r0 = min(w, d) * 0.44
    p.cyl(r0, 0.16, (0, 0.06 + 0.08, 0), "y", HITECH, 36)
    p.cyl(r0 * 0.8, 0.08, (0, 0.22 + 0.04, 0), "y", TRIM, 36)
    for i in range(16):
        t = i * math.pi / 8
        p.box((0.012, 0.09, 0.03), (math.cos(t) * r0, 0.14, math.sin(t) * r0), "gunmetal", 0.0, rot_y=-t)
    # The emitter column: a slim chrome stem in a cage of three arcing ribs.
    top = h - 0.24
    p.cyl(0.05, top - 0.3, (0, 0.3 + (top - 0.3) * 0.5, 0), "y", "chrome", 16)
    for i in range(5):
        y = 0.36 + i * (top - 0.42) / 4
        p.torus(0.075, 0.014, (0, y, 0), "y", "lamp_blue", 20, 6)
    for i in range(3):
        t = i * 2 * math.pi / 3 + math.pi / 2
        pts = []
        for k in range(6):
            u = k / 5
            rr = r0 * 0.7 * math.sin(math.pi * (0.25 + u * 0.6)) + 0.04
            pts.append((math.cos(t) * rr, 0.3 + u * (top - 0.3), math.sin(t) * rr))
        p.pipe_run(pts, 0.022, HITECH)
        p.sphere(0.018, pts[2], "lamp_cyan", 10, 6)
    # The emitter head: a glass dome over a glowing lens, rimmed by a coil ring.
    rh = min(w, d) * 0.34
    p.cyl(rh, 0.06, (0, top + 0.03, 0), "y", TRIM, 32)
    p.torus(rh, 0.03, (0, top + 0.07, 0), "y", "copper", 36, 8)
    p.torus(rh - 0.035, 0.01, (0, top + 0.08, 0), "y", "lamp_blue", 36, 6)
    p.sphere(rh * 0.85, (0, top + 0.06, 0), "glass", 28, 12, squash=0.55)
    p.sphere(rh * 0.42, (0, top + 0.06, 0), "lamp_blue", 20, 10, squash=0.7)
    p.cyl(0.02, 0.06, (0, h - 0.03, 0), "y", "chrome", 10)
    # A small readout on the plinth's front.
    p.box((0.18, 0.08, 0.02), (0, 0.14, -r0 - 0.005), TRIM, 0.004)
    p.box((0.14, 0.05, 0.006), (0, 0.14, -r0 - 0.017), "screen", 0.0)


RECIPES = {
    "plasma_drive": r_plasma_drive,
    "compact_fusion_cell": r_compact_fusion_cell,
    "shield_projector": r_shield_projector,
}
