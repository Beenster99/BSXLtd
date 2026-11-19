"""Recipes for machines: power, jump, life support, fluids, flight, sensors, defence, workshop.

Each takes (p, s): the Part being built and its catalogue size (w across, h up, d deep). The
front (the face a crew member works at) is at z = -d / 2.
"""

import math

INDUSTRIAL = (0.6, 0.62, 0.64)
ENGINE = (0.42, 0.45, 0.48)
POWER = (0.72, 0.6, 0.3)
LIFE = (0.42, 0.62, 0.55)
JUMP = (0.38, 0.32, 0.55)
FLIGHT = (0.3, 0.34, 0.4)
SENSOR = (0.55, 0.6, 0.66)
DEFENCE = (0.4, 0.44, 0.38)
WORKSHOP = (0.75, 0.55, 0.2)


def cabinet(p, s, paint, plinth=0.08, rails=True):
    """A machine cabinet: a dark plinth, a painted body with dark edge rails and a cap."""
    w, h, d = s
    p.floor_box((w - 0.04, plinth, d - 0.04), (0, 0, 0), "dark", 0.006)
    p.floor_box((w - 0.03, h - plinth - 0.03, d - 0.03), (0, plinth, 0), paint, 0.015)
    if rails:
        e = min(0.05, min(w, d) * 0.08)
        for sx in (-1, 1):
            for sz in (-1, 1):
                p.floor_box((e, h - plinth, e), (sx * (w * 0.5 - e * 0.5), plinth, sz * (d * 0.5 - e * 0.5)), "gunmetal", 0.004)
    p.box((w, 0.03, d), (0, h - 0.015, 0), "gunmetal", 0.006)


def side_vents(p, s, y=None, hh=None):
    w, h, d = s
    y = h * 0.45 if y is None else y
    hh = h * 0.35 if hh is None else hh
    for sx in (-1, 1):
        p.grille(d * 0.55, hh, (sx * (w * 0.5 - 0.01), y, 0), "+x" if sx > 0 else "-x", max(4, int(hh / 0.06)))


def control_panel(p, s, y, screen="screen", lamps=("lamp_green", "lamp_amber", "lamp_red"), sw=None):
    w, h, d = s
    sw = w * 0.45 if sw is None else sw
    f = -d * 0.5 + 0.015
    p.panel(sw + 0.12, 0.34, (0, y, f), "-z", "dark", 0.012)
    p.screen(sw, 0.2, (0, y + 0.04, f - 0.012), "-z", screen)
    for i, l in enumerate(lamps):
        p.lamp(0.014, (-sw * 0.4 + i * 0.06, y - 0.11, f - 0.012), "-z", l)
    for i in range(4):
        p.box((0.04, 0.025, 0.012), (sw * 0.1 + i * 0.055, y - 0.11, f - 0.016), "plastic", 0.003)


def hazard_band(p, w, y, z, h=0.05):
    p.box((w, h, 0.006), (0, y, z), "hazard", 0.0)


def pipe_stubs(p, s, n=2, y=None, material="steel"):
    w, h, d = s
    y = h * 0.8 if y is None else y
    for i in range(n):
        x = -w * 0.25 + i * w * 0.5 / max(1, n - 1)
        p.cyl(0.05, 0.1, (x, h + 0.0, d * 0.2), "y", material, 16)
        p.cyl(0.07, 0.025, (x, h - 0.01, d * 0.2), "y", "gunmetal", 16)


# --- power ---

def r_breaker_panel(p, s):
    w, h, d = s
    p.box((w, h, d), (0, h * 0.5, 0), (0.55, 0.57, 0.6), 0.012)
    p.box((w - 0.06, h - 0.06, 0.02), (0, h * 0.5, -d * 0.5 - 0.005), (0.5, 0.52, 0.55), 0.004)
    for row in range(4):
        y = h * 0.25 + row * h * 0.17
        p.box((w - 0.14, 0.09, 0.02), (0, y, -d * 0.5 - 0.02), "dark", 0.003)
        for i in range(6):
            x = -w * 0.5 + 0.12 + i * (w - 0.24) / 5
            p.box((0.03, 0.05, 0.02), (x, y, -d * 0.5 - 0.035), "white" if (i + row) % 3 else "red", 0.003)
    p.box((w * 0.5, 0.05, 0.01), (0, h - 0.08, -d * 0.5 - 0.02), "hazard", 0.0)
    p.lamp(0.012, (w * 0.35, h - 0.08, -d * 0.5 - 0.02), "-z", "lamp_green")
    p.cyl(0.03, 0.15, (0, -0.0, 0), "y", "dark", 12)


def r_power_distributor(p, s):
    w, h, d = s
    cabinet(p, s, POWER)
    f = -d * 0.5 + 0.015
    for i in range(5):
        y = 0.3 + i * 0.25
        p.box((w * 0.75, 0.16, 0.02), (0, y, f - 0.01), "dark", 0.003)
        for j in range(5):
            p.box((0.1, 0.04, 0.01), (-w * 0.3 + j * w * 0.15, y, f - 0.022), "lamp_green" if (i * j) % 4 else "lamp_amber", 0.0)
    p.screen(w * 0.5, 0.18, (0, h - 0.22, f), "-z", "screen_green")
    hazard_band(p, w - 0.06, 0.13, -d * 0.5 + 0.0)
    for i in range(4):
        p.cyl(0.03, 0.4, (-w * 0.3 + i * w * 0.2, h + 0.0, d * 0.25), "y", "copper", 10)


def r_fission_pile(p, s):
    w, h, d = s
    r = w * 0.42
    p.floor_box((w, 0.15, d), (0, 0, 0), "dark", 0.02)
    p.cyl(r, h - 0.45, (0, 0.15 + (h - 0.45) * 0.5, 0), "y", (0.52, 0.55, 0.5), 32)
    for y in (0.35, h * 0.5, h - 0.4):
        p.cyl(r + 0.03, 0.08, (0, y, 0), "y", "gunmetal", 32)
        p.bolts((0, y, 0), r + 0.035, 16, "y", 0.012)
    p.cyl(r * 0.85, 0.2, (0, h - 0.2, 0), "y", "gunmetal", 32)
    for i in range(7):
        t = i * 2 * math.pi / 7
        p.cyl(0.05, 0.22, (math.cos(t) * r * 0.55, h - 0.11, math.sin(t) * r * 0.55), "y", "steel", 12)
        p.cyl(0.035, 0.02, (math.cos(t) * r * 0.55, h - 0.0, math.sin(t) * r * 0.55), "y", "lamp_cyan", 12)
    p.box((0.4, 0.5, 0.06), (0, h * 0.5, -r - 0.02), "dark", 0.01)
    p.box((0.32, 0.12, 0.01), (0, h * 0.5 + 0.12, -r - 0.055), "screen_amber", 0.0)
    p.box((0.32, 0.06, 0.01), (0, h * 0.5 - 0.1, -r - 0.055), "hazard", 0.0)
    p.box((0.3, 0.02, 0.006), (0, h * 0.5 - 0.1, -r - 0.06), "dark", 0.0)
    for sx in (-1, 1):
        p.pipe_run([(sx * r * 0.7, h * 0.3, r * 0.7), (sx * (w * 0.5 - 0.06), h * 0.3, d * 0.5 - 0.06),
                    (sx * (w * 0.5 - 0.06), h - 0.3, d * 0.5 - 0.06)], 0.06, "copper")


def generator(p, s, paint, intake="grille"):
    w, h, d = s
    p.floor_box((w, 0.1, d), (0, 0, 0), "dark", 0.01)
    for sx in (-1, 1):
        p.floor_box((0.08, 0.2, d - 0.1), (sx * (w * 0.5 - 0.1), 0.1, 0), "gunmetal", 0.006)
    r = min(h - 0.35, d) * 0.45
    p.cyl(r, w * 0.6, (-w * 0.1, 0.3 + r, 0), "x", paint, 24)
    for i in range(6):
        p.cyl(r + 0.02, 0.02, (-w * 0.35 + i * w * 0.1, 0.3 + r, 0), "x", "gunmetal", 24)
    p.floor_box((w * 0.3, h - 0.32, d * 0.8), (w * 0.33, 0.3, 0), paint, 0.02)
    p.screen(w * 0.18, 0.12, (w * 0.33, h * 0.68, -d * 0.4), "-z", "screen_green")
    p.lamp(0.015, (w * 0.28, h * 0.48, -d * 0.4), "-z", "lamp_green")
    p.lamp(0.015, (w * 0.38, h * 0.48, -d * 0.4), "-z", "lamp_amber")
    p.cyl(r * 0.6, 0.05, (-w * 0.42, 0.3 + r, 0), "x", "dark", 24)
    p.grille(r * 1.0, r * 1.0, (-w * 0.43, 0.3 + r, 0), "-x", 6)
    return r


def r_gas_generator(p, s):
    w, h, d = s
    r = generator(p, s, (0.62, 0.42, 0.2))
    p.pipe_run([(w * 0.33, h - 0.02, d * 0.2), (w * 0.33, h - 0.02, d * 0.42)], 0.05, "gunmetal")
    p.cyl(0.07, 0.14, (-w * 0.1, h - 0.07, d * 0.25), "y", "dark", 16)


def r_hydrogen_generator(p, s):
    w, h, d = s
    generator(p, s, (0.75, 0.78, 0.8))
    for i in range(2):
        p.cyl(0.11, d * 0.85, (w * 0.12 + i * 0.25, h - 0.14, 0), "z", "white", 20)
        p.cyl(0.115, 0.04, (w * 0.12 + i * 0.25, h - 0.14, -d * 0.2), "z", "fabric_blue", 20)
    p.box((w * 0.5, 0.04, 0.01), (-w * 0.1, 0.35, -d * 0.5 + 0.0), "fabric_blue", 0.0)


# --- jump ---

def r_jump_drive(p, s):
    w, h, d = s
    p.floor_box((w, 0.15, d), (0, 0, 0), "dark", 0.02)
    r = min(w, h - 0.2) * 0.42
    cy = 0.15 + (h - 0.15) * 0.5
    p.cyl(r * 0.55, d - 0.2, (0, cy, 0), "z", "gunmetal", 24)
    for i in range(5):
        z = -d * 0.5 + 0.25 + i * (d - 0.5) / 4
        p.torus(r * 0.85, r * 0.13, (0, cy, z), "z", JUMP, 32, 10)
        p.torus(r * 0.85, r * 0.05, (0, cy, z - r * 0.12), "z", "lamp_violet", 32, 6)
    for sx in (-1, 1):
        p.floor_box((0.12, cy, d - 0.3), (sx * (w * 0.5 - 0.08), 0.1, 0), "gunmetal", 0.01)
        p.rod((sx * (w * 0.5 - 0.08), cy, -d * 0.4), (sx * (w * 0.5 - 0.08), cy, d * 0.4), 0.04, "copper", 12)
    p.cyl(r * 0.3, 0.06, (0, cy, -d * 0.5 + 0.03), "z", "lamp_violet", 24)
    p.box((0.5, 0.3, 0.06), (0, 0.35, -d * 0.5 + 0.06), "dark", 0.01)
    p.box((0.4, 0.18, 0.01), (0, 0.37, -d * 0.5 + 0.025), "screen", 0.0)


def r_drive_stabiliser(p, s):
    w, h, d = s
    cabinet(p, s, JUMP)
    for i in range(3):
        y = 0.4 + i * 0.35
        p.cyl(min(w, d) * 0.38, 0.05, (0, y, 0), "y", "gunmetal", 24)
    p.box((w * 0.5, h * 0.55, 0.02), (0, h * 0.5, -d * 0.5 - 0.0), "glass_dark", 0.0)
    p.cyl(0.07, h * 0.55, (0, h * 0.5, -d * 0.2), "y", "lamp_violet", 16)
    p.screen(w * 0.4, 0.12, (0, h - 0.2, -d * 0.5 + 0.015), "-z", "screen")
    side_vents(p, s)


def r_quantum_core(p, s):
    w, h, d = s
    p.floor_box((w, 0.1, d), (0, 0, 0), "dark", 0.01)
    c = h * 0.55
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.bar((sx * (w * 0.5 - 0.04), 0.1, sz * (d * 0.5 - 0.04)), (sx * (w * 0.5 - 0.04), h, sz * (d * 0.5 - 0.04)), 0.06, JUMP)
    p.box((w, 0.06, d), (0, h - 0.03, 0), "gunmetal", 0.01)
    p.sphere(w * 0.25, (0, c, 0), "lamp_violet", 24, 12)
    p.torus(w * 0.32, 0.025, (0, c, 0), "y", "chrome", 32, 8)
    p.torus(w * 0.32, 0.025, (0, c, 0), "z", "chrome", 32, 8)
    p.cyl(0.05, 0.25, (0, 0.22, 0), "y", "chrome", 12)
    p.cyl(0.05, h - c - w * 0.25, (0, c + w * 0.25 + (h - c - w * 0.25) * 0.5, 0), "y", "chrome", 12)


def r_jump_tank(p, s):
    w, h, d = s
    p.floor_box((w, 0.12, d), (0, 0, 0), "dark", 0.01)
    r = min(w, d) * 0.45
    p.cyl(r, h - 0.4, (0, 0.12 + (h - 0.4) * 0.5 + 0.0, 0), "y", (0.75, 0.75, 0.78), 32)
    p.sphere(r, (0, h - 0.28 - 0.0, 0), (0.75, 0.75, 0.78), 32, 12, squash=0.6)
    for y in (0.35, h * 0.55):
        p.cyl(r + 0.02, 0.05, (0, y, 0), "y", JUMP, 32)
    p.box((0.06, h * 0.45, 0.02), (0, h * 0.45, -r - 0.0), "glass", 0.0)
    p.box((0.03, h * 0.3, 0.01), (0, h * 0.38, -r - 0.005), "lamp_violet", 0.0)
    p.cyl(0.05, 0.12, (r * 0.4, h - 0.06, 0), "y", "chrome", 12)
    p.torus(0.08, 0.015, (r * 0.4, h - 0.02, 0), "y", "red", 16, 6)


# --- life support ---

def r_air_scrubber(p, s):
    w, h, d = s
    cabinet(p, s, LIFE)
    p.grille(w * 0.7, h * 0.35, (0, h * 0.62, -d * 0.5 + 0.0), "-z", 10)
    p.cyl(w * 0.28, 0.04, (0, h * 0.3, -d * 0.5 + 0.0), "z", "dark", 24)
    for i in range(4):
        p.box((w * 0.5, 0.02, 0.01), (0, h * 0.3, -d * 0.5 - 0.025), "gunmetal", 0.0, rot_z=i * math.pi / 4)
    p.screen(w * 0.4, 0.08, (0, h * 0.85, -d * 0.5 + 0.0), "-z", "screen_green")
    pipe_stubs(p, s, 2)


def r_oxygen_generator(p, s):
    w, h, d = s
    cabinet(p, s, LIFE)
    for i in range(3):
        p.cyl(0.12, h * 0.6, (-w * 0.3 + i * w * 0.3, h * 0.45, -d * 0.5 + 0.06), "y", "white", 20)
        p.cyl(0.125, 0.05, (-w * 0.3 + i * w * 0.3, h * 0.72, -d * 0.5 + 0.06), "y", "fabric_blue", 20)
        p.box((0.05, h * 0.3, 0.01), (-w * 0.3 + i * w * 0.3, h * 0.42, -d * 0.5 - 0.065), "lamp_cyan", 0.0)
    control_panel(p, s, h * 0.87, "screen", sw=w * 0.5)
    side_vents(p, s)
    pipe_stubs(p, s, 3)


def r_water_recycler(p, s):
    w, h, d = s
    cabinet(p, s, LIFE)
    p.box((w * 0.5, h * 0.4, 0.02), (-w * 0.12, h * 0.5, -d * 0.5 + 0.0), "glass", 0.0)
    p.box((w * 0.46, h * 0.25, 0.08), (-w * 0.12, h * 0.42, -d * 0.5 + 0.06), "water", 0.0)
    p.screen(0.18, 0.12, (w * 0.3, h * 0.75, -d * 0.5 + 0.015), "-z", "screen")
    p.pipe_run([(w * 0.3, h * 0.2, -d * 0.5 - 0.02), (w * 0.3, h * 0.55, -d * 0.5 - 0.02),
                (-w * 0.12, h * 0.55, -d * 0.5 - 0.02)], 0.025, "chrome")
    p.cyl(0.05, 0.04, (w * 0.3, h * 0.2, -d * 0.5 - 0.03), "z", "red", 12)
    pipe_stubs(p, s, 2)


def r_air_tank_rack(p, s):
    w, h, d = s
    p.floor_box((w, 0.06, d), (0, 0, 0), "gunmetal", 0.006)
    p.box((w, h - 0.06, 0.04), (0, 0.06 + (h - 0.06) * 0.5, d * 0.5 - 0.02), "gunmetal", 0.006)
    n = 4
    r = min(w / n * 0.42, d * 0.42)
    for i in range(n):
        x = -w * 0.5 + w / n * (i + 0.5)
        p.cyl(r, h - 0.35, (x, 0.06 + (h - 0.35) * 0.5, 0), "y", "white" if i % 2 else (0.3, 0.55, 0.85), 20)
        p.sphere(r, (x, h - 0.29, 0), "white" if i % 2 else (0.3, 0.55, 0.85), 20, 10, squash=0.6)
        p.cyl(0.03, 0.1, (x, h - 0.12, 0), "y", "brass", 10)
        p.cyl(0.04, 0.03, (x, h - 0.06, 0), "y", "dark", 10)
        for y in (0.4, h * 0.7):
            p.box((w / n * 0.95, 0.04, 0.02), (x, y, -r - 0.01), "dark", 0.003)
    p.rod((-w * 0.45, h - 0.06, -0.05), (w * 0.45, h - 0.06, -0.05), 0.012, "brass", 8)


def r_fire_suppression(p, s):
    w, h, d = s
    p.box((w, h, d * 0.3), (0, h * 0.5, d * 0.35), "red", 0.01)
    for i in range(2):
        x = -w * 0.2 + i * w * 0.4
        z = -d * 0.5 + 0.1
        p.cyl(0.1, h * 0.65, (x, h * 0.38, z), "y", "red", 20)
        p.sphere(0.1, (x, h * 0.7, z), "red", 20, 10, squash=0.6)
        p.cyl(0.03, 0.08, (x, h * 0.78, z), "y", "chrome", 10)
        p.box((0.1, 0.03, 0.03), (x + 0.04, h * 0.82, z), "dark", 0.004)
        p.box((0.12, 0.14, 0.004), (x, h * 0.4, z - 0.102), "white", 0.0)
    p.box((w * 0.8, 0.1, 0.02), (0, h * 0.94, d * 0.2 - 0.0), "white", 0.0)
    p.lamp(0.03, (0, h * 0.94, d * 0.19), "-z", "lamp_red")
    p.pipe_run([(w * 0.35, h * 0.1, 0.0), (w * 0.35, h * 0.85, 0.0)], 0.02, "red")


def r_heater(p, s):
    w, h, d = s
    p.box((w, h, d * 0.8), (0, h * 0.5, d * 0.1), (0.85, 0.85, 0.82), 0.02)
    n = 10
    for i in range(n):
        x = -w * 0.5 + 0.05 + i * (w - 0.1) / (n - 1)
        p.box((0.025, h * 0.75, 0.04), (x, h * 0.5, -d * 0.3 - 0.02), (0.8, 0.8, 0.78), 0.004)
    p.box((w - 0.1, 0.03, 0.01), (0, h * 0.1, -d * 0.32), "lamp_amber", 0.0)
    p.cyl(0.025, 0.03, (w * 0.42, h * 0.85, -d * 0.32), "z", "dark", 12)
    p.lamp(0.01, (w * 0.35, h * 0.85, -d * 0.3), "-z", "lamp_red")


# --- fluids ---

def r_coolant_pump(p, s):
    w, h, d = s
    p.floor_box((w, 0.1, d), (0, 0, 0), "dark", 0.01)
    r = w * 0.32
    p.cyl(r, h * 0.4, (0, 0.1 + h * 0.2, 0), "y", (0.25, 0.45, 0.7), 24)
    p.sphere(r, (0, 0.1 + h * 0.4, 0), (0.25, 0.45, 0.7), 24, 10, squash=0.5)
    m0, m1 = h * 0.47, h - 0.04
    p.cyl(r * 0.6, m1 - m0, (0, (m0 + m1) * 0.5, 0), "y", "gunmetal", 20)
    for i in range(8):
        t = i * math.pi / 4
        p.box((0.015, (m1 - m0) * 0.85, 0.05), (math.cos(t) * r * 0.62, (m0 + m1) * 0.5, math.sin(t) * r * 0.62), "dark", 0.0, rot_y=-t)
    p.cyl(r * 0.4, 0.04, (0, h - 0.02, 0), "y", "hazard", 20)
    for sx in (-1, 1):
        p.cyl(0.07, w * 0.22, (sx * (r + w * 0.08), 0.1 + h * 0.2, 0), "x", "steel", 16)
        p.cyl(0.1, 0.03, (sx * (w * 0.5 - 0.02), 0.1 + h * 0.2, 0), "x", "gunmetal", 16)
        p.bolts((sx * (w * 0.5 - 0.02), 0.1 + h * 0.2, 0), 0.08, 6, "x", 0.01)
    p.box((0.1, 0.08, 0.02), (0, h * 0.4, -r - 0.0), "screen_green", 0.0)


def r_heat_exchanger(p, s):
    w, h, d = s
    p.floor_box((w, 0.1, d), (0, 0, 0), "dark", 0.01)
    for i in range(9):
        z = -d * 0.4 + i * d * 0.1
        p.box((w * 0.85, h - 0.25, 0.03), (0, 0.15 + (h - 0.25) * 0.5, z), "copper", 0.003)
    for sx in (-1, 1):
        p.box((0.06, h - 0.15, d), (sx * (w * 0.5 - 0.03), 0.1 + (h - 0.15) * 0.5, 0), "gunmetal", 0.008)
        for y in (0.4, h - 0.35):
            p.cyl(0.08, 0.1, (sx * (w * 0.5 + 0.0), y, 0), "x", "steel", 16)
    p.box((w, 0.06, d), (0, h - 0.03, 0), "gunmetal", 0.008)
    p.box((0.3, 0.12, 0.01), (0, h * 0.85, -d * 0.5 - 0.0), "hazard", 0.0)


def r_pipe_header(p, s):
    w, h, d = s
    r = min(h, d) * 0.3
    for sx in (-1, 1):
        p.floor_box((0.08, h * 0.45, d), (sx * (w * 0.4), 0, 0), "gunmetal", 0.006)
    p.cyl(r, w - 0.1, (0, h * 0.55, 0), "x", "steel", 24)
    for sx in (-1, 1):
        p.cyl(r + 0.03, 0.06, (sx * (w * 0.5 - 0.06), h * 0.55, 0), "x", "gunmetal", 24)
        p.bolts((sx * (w * 0.5 - 0.06), h * 0.55, 0), r + 0.015, 8, "x", 0.01)
    for i in range(4):
        x = -w * 0.3 + i * w * 0.2
        p.cyl(r * 0.45, h * 0.4, (x, h * 0.55 + h * 0.25, 0), "y", "steel", 16)
        p.cyl(r * 0.6, 0.04, (x, h - 0.02, 0), "y", "gunmetal", 16)
        p.torus(0.06, 0.012, (x, h * 0.8, -r * 0.6), "z", "red", 16, 6)
    p.box((w * 0.3, 0.04, 0.005), (0, h * 0.55, -r - 0.0), "fabric_blue", 0.0)


def r_refuel_port(p, s):
    # A hull fitting: the plate against the hull at +Z, the coupling facing out (-Z).
    w, h, d = s
    p.box((w, h, 0.06), (0, h * 0.5, d * 0.5 - 0.03), "gunmetal", 0.01)
    p.box((w - 0.08, h - 0.08, 0.02), (0, h * 0.5, d * 0.5 - 0.07), "hazard", 0.004)
    r = min(w, h) * 0.3
    p.cyl(r, d - 0.1, (0, h * 0.5, 0.0), "z", "steel", 24)
    p.cyl(r * 0.7, 0.04, (0, h * 0.5, -d * 0.5 + 0.02), "z", "dark", 24)
    p.torus(r * 0.85, 0.02, (0, h * 0.5, -d * 0.5 + 0.06), "z", "chrome", 24, 6)
    p.bolts((0, h * 0.5, -d * 0.5 + 0.08), r * 1.2, 8, "z", 0.012)
    p.lamp(0.02, (w * 0.38, h - 0.08, d * 0.5 - 0.08), "-z", "lamp_green")
    p.lamp(0.02, (-w * 0.38, h - 0.08, d * 0.5 - 0.08), "-z", "lamp_amber")


def r_water_tank(p, s):
    w, h, d = s
    p.floor_box((w, 0.12, d), (0, 0, 0), "gunmetal", 0.01)
    p.floor_box((w - 0.06, h - 0.2, d - 0.06), (0, 0.12, 0), (0.3, 0.45, 0.6), 0.04)
    for y in (0.4, h * 0.5, h - 0.35):
        p.box((w + 0.01, 0.05, d + 0.01), (0, y, 0), "gunmetal", 0.006)
    p.box((0.08, h * 0.6, 0.02), (w * 0.35, h * 0.48, -d * 0.5 - 0.0), "glass", 0.0)
    p.box((0.05, h * 0.35, 0.01), (w * 0.35, h * 0.38, -d * 0.5 - 0.006), "water", 0.0)
    p.cyl(0.18, 0.08, (0, h - 0.04, 0), "y", "gunmetal", 20)
    p.bolts((0, h - 0.0, 0), 0.15, 8, "y", 0.01)
    p.cyl(0.05, 0.15, (-w * 0.35, 0.3, -d * 0.5 - 0.05), "z", "steel", 12)
    p.torus(0.07, 0.012, (-w * 0.35, 0.3, -d * 0.5 - 0.12), "z", "red", 16, 6)


# --- flight ---

def desk_console(p, s, paint, screens=2, glow="screen"):
    """A sloped console: a pedestal, a raked desk of keys and a screen bank behind it."""
    w, h, d = s
    p.floor_box((w * 0.9, 0.7, d * 0.55), (0, 0, d * 0.15), paint, 0.015)
    p.box((w, 0.08, d * 0.75), (0, 0.78, -d * 0.1), paint, 0.015, rot_x=0.25)
    p.box((w * 0.9, 0.01, d * 0.55), (0, 0.83, -d * 0.12), "plastic", 0.0, rot_x=0.25)
    for i in range(12):
        x = -w * 0.38 + (i % 6) * w * 0.15
        z = -d * 0.25 + (i // 6) * 0.12
        p.box((0.06, 0.02, 0.05), (x, 0.84 + (i // 6) * 0.03, z), "lamp_green" if i % 5 == 0 else "dark", 0.004, rot_x=0.25)
    p.box((w, h - 0.85, 0.08), (0, 0.85 + (h - 0.85) * 0.5, d * 0.5 - 0.06), paint, 0.015, rot_x=-0.15)
    sw = (w - 0.1) / screens
    for i in range(screens):
        x = -w * 0.5 + 0.05 + sw * (i + 0.5)
        p.box((sw - 0.06, h - 1.0, 0.01), (x, 0.85 + (h - 0.85) * 0.5, d * 0.5 - 0.11), glow, 0.0, rot_x=-0.15)
    p.box((w * 0.3, 0.12, 0.08), (0, 0.4, -d * 0.12), "dark", 0.006)


def r_helm_console(p, s):
    w, h, d = s
    desk_console(p, s, FLIGHT, 3)
    for sx in (-1, 1):
        p.cyl(0.03, 0.18, (sx * w * 0.25, 0.95, -d * 0.2), "y", "rubber", 12)
        p.sphere(0.04, (sx * w * 0.25, 1.05, -d * 0.2), "dark", 12, 8)


def r_engine_control(p, s):
    w, h, d = s
    desk_console(p, s, ENGINE, 2, "screen_amber")
    for i in range(4):
        p.box((0.03, 0.12, 0.03), (-0.15 + i * 0.1, 0.92, -d * 0.12), "red" if i == 0 else "chrome", 0.004)


def r_fire_control(p, s):
    w, h, d = s
    desk_console(p, s, DEFENCE, 2, "lamp_red" if False else "screen_amber")
    p.box((0.2, 0.03, 0.15), (0, 0.86, -d * 0.25), "hazard", 0.004)
    p.box((0.08, 0.04, 0.06), (0, 0.89, -d * 0.25), "red", 0.006)


def r_flight_computer(p, s):
    w, h, d = s
    cabinet(p, s, FLIGHT)
    for i in range(6):
        y = 0.2 + i * (h - 0.4) / 6
        p.box((w - 0.08, (h - 0.4) / 6 - 0.03, 0.03), (0, y + 0.1, -d * 0.5 + 0.0), "dark", 0.004)
        for j in range(6):
            p.box((0.03, 0.02, 0.01), (-w * 0.35 + j * 0.05, y + 0.1, -d * 0.5 - 0.018), "lamp_green" if (i + j) % 3 else "lamp_amber", 0.0)
        p.grille(w * 0.3, 0.12, (w * 0.22, y + 0.1, -d * 0.5 - 0.015), "-z", 3)
    side_vents(p, s, h * 0.5, h * 0.6)


def r_autopilot_core(p, s):
    w, h, d = s
    cabinet(p, s, FLIGHT)
    p.screen(w * 0.6, h * 0.3, (0, h * 0.62, -d * 0.5 + 0.015), "-z", "screen")
    for i in range(5):
        p.lamp(0.012, (-w * 0.3 + i * w * 0.15, h * 0.25, -d * 0.5 + 0.015), "-z", "lamp_green" if i < 4 else "lamp_blue")
    side_vents(p, s, h * 0.5, h * 0.5)
    p.cyl(0.04, 0.08, (w * 0.3, h + 0.0, d * 0.2), "y", "dark", 12)


# --- sensors ---

def r_comms_suite(p, s):
    w, h, d = s
    cabinet(p, s, SENSOR)
    control_panel(p, s, h * 0.72, "screen_green", sw=w * 0.6)
    p.box((w * 0.6, 0.2, 0.04), (0, h * 0.4, -d * 0.5 + 0.0), "dark", 0.006)
    for i in range(6):
        p.cyl(0.02, 0.03, (-w * 0.24 + i * w * 0.096, h * 0.4, -d * 0.5 - 0.03), "z", "chrome", 10)
    p.box((0.18, 0.06, 0.06), (-w * 0.25, h * 0.2, -d * 0.5 + 0.0), "plastic", 0.01)
    p.box((0.06, 0.16, 0.04), (w * 0.25, h * 0.22, -d * 0.5 - 0.01), "plastic", 0.01)
    side_vents(p, s)


def r_survey_array(p, s):
    w, h, d = s
    cabinet(p, s, SENSOR)
    control_panel(p, s, h * 0.55, "screen", sw=w * 0.6)
    p.cyl(w * 0.35, 0.08, (0, h - 0.0, 0), "y", "gunmetal", 24)
    for i in range(3):
        p.cyl(0.08, 0.04, (-w * 0.25 + i * w * 0.25, h * 0.85, -d * 0.5 - 0.0), "z", "lamp_cyan", 16)
    side_vents(p, s)


# --- defence ---

def r_shield_generator(p, s):
    w, h, d = s
    p.floor_box((w, 0.15, d), (0, 0, 0), "dark", 0.02)
    r = min(w, d) * 0.4
    p.cyl(r, h - 0.6, (0, 0.15 + (h - 0.6) * 0.5, 0), "y", DEFENCE, 24)
    for i in range(4):
        y = 0.35 + i * (h - 0.8) / 3
        p.torus(r + 0.04, 0.035, (0, y, 0), "y", "lamp_blue", 32, 8)
    p.sphere(r * 0.9, (0, h - 0.45, 0), "glass", 24, 12, squash=0.8)
    p.sphere(r * 0.5, (0, h - 0.45, 0), "lamp_blue", 20, 10)
    p.cyl(r * 1.05, 0.06, (0, h - 0.06, 0), "y", "gunmetal", 24)
    for sx in (-1, 1):
        p.floor_box((0.15, h * 0.5, 0.3), (sx * (w * 0.5 - 0.08), 0.15, 0), "gunmetal", 0.01)
        p.lamp(0.015, (sx * (w * 0.5 - 0.08), h * 0.45, -0.15), "-z", "lamp_green")
    p.box((0.3, 0.2, 0.04), (0, 0.5, -r - 0.02), "dark", 0.006)
    p.box((0.24, 0.14, 0.01), (0, 0.5, -r - 0.045), "screen", 0.0)


def r_shield_booster(p, s):
    w, h, d = s
    cabinet(p, s, DEFENCE)
    for i in range(4):
        y = 0.3 + i * (h - 0.5) / 4
        p.box((w * 0.7, 0.04, 0.02), (0, y, -d * 0.5 - 0.0), "lamp_blue", 0.0)
    p.cyl(w * 0.25, 0.1, (0, h + 0.0, 0), "y", "chrome", 20)
    p.sphere(w * 0.15, (0, h + 0.05, 0), "lamp_blue", 16, 8, squash=0.6)
    side_vents(p, s)


def r_signature_damper(p, s):
    w, h, d = s
    cabinet(p, s, (0.2, 0.22, 0.24))
    n = 9
    for i in range(n):
        y = 0.15 + i * (h - 0.3) / n
        p.box((w - 0.05, 0.05, d * 0.9), (0, y + 0.05, 0), "dark", 0.004)
    p.screen(w * 0.45, 0.1, (0, h - 0.12, -d * 0.5 + 0.0), "-z", "screen_green")
    p.box((w * 0.8, 0.02, 0.01), (0, 0.11, -d * 0.5 - 0.0), "lamp_violet", 0.0)


# --- workshop and machinery ---

def r_lathe(p, s):
    w, h, d = s
    for sx in (-1, 1):
        p.floor_box((0.35, 0.8, d * 0.95), (sx * (w * 0.5 - 0.2), 0, 0), WORKSHOP, 0.015)
    p.box((w, 0.12, d * 0.5), (0, 0.86, 0.05), "gunmetal", 0.01)
    p.floor_box((0.45, 0.45, d * 0.5), (-w * 0.5 + 0.25, 0.92, 0.05), WORKSHOP, 0.02)
    p.cyl(0.13, 0.08, (-w * 0.5 + 0.52, 1.12, 0.0), "x", "chrome", 20)
    for i in range(3):
        t = i * 2 * math.pi / 3
        p.box((0.04, 0.05, 0.04), (-w * 0.5 + 0.56, 1.12 + math.sin(t) * 0.09, math.cos(t) * 0.09), "dark", 0.004)
    p.cyl(0.03, w * 0.45, (0.0, 1.12, 0.0), "x", "steel", 16)
    p.floor_box((0.25, 0.3, 0.25), (w * 0.5 - 0.3, 0.92, 0.05), WORKSHOP, 0.015)
    p.cyl(0.04, 0.2, (w * 0.5 - 0.42, 1.12, 0.0), "x", "chrome", 12)
    p.floor_box((0.2, 0.12, 0.2), (0.1, 0.92, -0.05), "gunmetal", 0.01)
    p.box((0.1, 0.04, 0.04), (0.1, 1.08, -0.08), "steel", 0.004)
    p.box((0.2, 0.18, 0.02), (-w * 0.5 + 0.25, 1.15, -d * 0.2), "dark", 0.004)
    p.box((0.16, 0.12, 0.01), (-w * 0.5 + 0.25, 1.17, -d * 0.2 - 0.012), "screen_amber", 0.0)
    p.box((0.06, 0.06, 0.02), (-w * 0.5 + 0.25, 1.36, -d * 0.2), "red", 0.006)
    p.box((w * 0.5, 0.02, 0.4), (0.0, 0.84, -0.05), "steel", 0.0)


def r_crane_hoist(p, s):
    w, h, d = s
    p.box((w, 0.2, 0.25), (0, h - 0.1, 0), "hazard", 0.01)
    for sx in (-1, 1):
        p.box((0.1, 0.3, d), (sx * (w * 0.5 - 0.05), h - 0.15, 0), "gunmetal", 0.01)
    p.floor_box((0.5, 0.35, 0.45), (0.1, h - 0.55, 0), "hazard", 0.02)
    p.cyl(0.14, 0.4, (0.1, h - 0.37, 0), "x", "gunmetal", 20)
    p.rod((0.1, h - 0.55, 0), (0.1, 0.25, 0), 0.012, "steel", 8)
    p.box((0.12, 0.15, 0.08), (0.1, 0.2, 0), "hazard", 0.01)
    p.torus(0.06, 0.018, (0.1, 0.08, 0), "z", "steel", 16, 6)
    p.box((0.08, 0.14, 0.05), (-0.3, 0.6, -0.1), "hazard", 0.01)
    p.rod((-0.3, 0.67, -0.1), (0.05, h - 0.55, 0), 0.005, "dark", 6)
    p.box((0.05, 0.03, 0.01), (-0.3, 0.62, -0.126), "lamp_green", 0.0)


def r_tow_winch(p, s):
    w, h, d = s
    p.floor_box((w, 0.12, d), (0, 0, 0), "gunmetal", 0.01)
    for sx in (-1, 1):
        p.floor_box((0.1, h * 0.8, d * 0.7), (sx * (w * 0.5 - 0.15), 0.12, 0), WORKSHOP, 0.012)
    r = h * 0.3
    p.cyl(r, w - 0.4, (0, 0.12 + h * 0.4, 0), "x", "dark", 28)
    for i in range(10):
        p.torus(r + 0.01, 0.02, (-w * 0.3 + i * (w * 0.6) / 9, 0.12 + h * 0.4, 0), "x", "steel", 24, 6)
    p.cyl(r * 1.4, 0.05, (-(w * 0.5 - 0.25), 0.12 + h * 0.4, 0), "x", "gunmetal", 28)
    p.cyl(r * 1.4, 0.05, ((w * 0.5 - 0.25), 0.12 + h * 0.4, 0), "x", "gunmetal", 28)
    p.floor_box((0.3, 0.35, 0.4), (w * 0.5 - 0.15, 0.12, d * 0.25), ENGINE, 0.02)
    p.box((0.2, 0.08, 0.02), (0, h - 0.1, -d * 0.4), "hazard", 0.004)
    p.rod((0, 0.12 + h * 0.4 - r, -0.1), (0, 0.12, -d * 0.5 + 0.02), 0.02, "steel", 8)
    p.box((0.2, 0.12, 0.04), (0, 0.18, -d * 0.5 + 0.05), "hazard", 0.006)


def r_attractor_coil(p, s):
    w, h, d = s
    r = min(h, d) * 0.45
    p.cyl(r * 0.6, w, (0, h * 0.5, 0), "x", "gunmetal", 20)
    n = 9
    for i in range(n):
        x = -w * 0.42 + i * w * 0.84 / (n - 1)
        p.cyl(r, w * 0.06, (x, h * 0.5, 0), "x", "copper", 20)
    for sx in (-1, 1):
        p.cyl(r * 1.0, 0.04, (sx * (w * 0.5 - 0.02), h * 0.5, 0), "x", "dark", 20)
    p.box((w * 0.7, 0.01, 0.02), (0, h * 0.5 + r + 0.0, 0), "lamp_cyan", 0.0)


def r_scrap_grinder(p, s):
    w, h, d = s
    p.floor_box((w, 0.15, d), (0, 0, 0), "dark", 0.02)
    p.floor_box((w - 0.1, h * 0.55, d - 0.1), (0, 0.15, 0), WORKSHOP, 0.03)
    # The hopper on top, rolls inside it.
    p.cyl(w * 0.705, h * 0.3, (0, h - h * 0.15, 0), "y", "gunmetal", 4, r2=None)
    p.objects[-1].rotation_euler[2] = math.pi / 4
    p.box((w * 0.85, 0.03, d * 0.85), (0, h * 0.72, 0), "dark", 0.0)
    for i in range(3):
        p.cyl(0.14, w * 0.8, (0, h * 0.72 + 0.12, -d * 0.25 + i * d * 0.25), "x", "steel", 12)
    p.box((w * 0.5, 0.25, 0.06), (0, 0.4, -d * 0.5 + 0.02), "dark", 0.01)
    p.box((w * 0.9, 0.06, 0.01), (0, h * 0.6, -d * 0.5 + 0.045), "hazard", 0.0)
    p.screen(0.25, 0.12, (w * 0.3, h * 0.45, -d * 0.5 + 0.05), "-z", "screen_amber")
    p.cyl(0.06, 0.04, (-w * 0.3, h * 0.45, -d * 0.5 + 0.05), "z", "red", 16)
    side_vents(p, (w - 0.1, h, d), h * 0.4, h * 0.3)


def r_smelter(p, s):
    w, h, d = s
    p.floor_box((w, 0.2, d), (0, 0, 0), "dark", 0.02)
    p.floor_box((w - 0.1, h - 0.6, d - 0.1), (0, 0.2, 0), (0.35, 0.3, 0.28), 0.04)
    p.box((w * 0.5, h * 0.35, 0.1), (0, h * 0.45, -d * 0.5 + 0.06), "gunmetal", 0.02)
    p.box((w * 0.3, h * 0.08, 0.01), (0, h * 0.5, -d * 0.5 + 0.005), "lamp_amber", 0.0)
    p.box((w * 0.55, 0.06, 0.06), (0, h * 0.25, -d * 0.5 + 0.0), "chrome", 0.004)
    p.box((w - 0.08, 0.08, 0.01), (0, 0.3, -d * 0.5 + 0.045), "hazard", 0.0)
    p.cyl(w * 0.18, 0.4, (w * 0.2, h - 0.2, d * 0.15), "y", "gunmetal", 20)
    p.cyl(w * 0.2, 0.05, (w * 0.2, h - 0.03, d * 0.15), "y", "dark", 20)
    p.floor_box((w * 0.6, 0.15, d * 0.3), (-w * 0.1, h - 0.4, -d * 0.1), "gunmetal", 0.02)
    p.screen(0.3, 0.15, (-w * 0.35, h * 0.72, -d * 0.5 + 0.05), "-z", "screen_amber")
    side_vents(p, (w - 0.1, h, d), h * 0.4, h * 0.3)


def r_refinery(p, s):
    w, h, d = s
    p.floor_box((w, 0.15, d), (0, 0, 0), "gunmetal", 0.02)
    for (x, z, r, hh) in [(-w * 0.25, d * 0.15, w * 0.2, h - 0.2), (w * 0.22, d * 0.2, w * 0.17, h * 0.75)]:
        p.cyl(r, hh - 0.25, (x, 0.15 + (hh - 0.25) * 0.5, z), "y", (0.7, 0.72, 0.74), 24)
        p.sphere(r, (x, hh - 0.1, z), (0.7, 0.72, 0.74), 24, 10, squash=0.4)
        for y in (0.5, hh * 0.6):
            p.cyl(r + 0.02, 0.04, (x, y, z), "y", "gunmetal", 24)
    p.floor_box((w * 0.4, h * 0.45, d * 0.35), (w * 0.2, 0.15, -d * 0.3), WORKSHOP, 0.02)
    p.screen(w * 0.25, 0.15, (w * 0.2, h * 0.42, -d * 0.5 - 0.0), "-z", "screen_green")
    p.pipe_run([(-w * 0.25, h * 0.6, d * 0.15 - w * 0.2), (-w * 0.25, h * 0.6, -d * 0.3),
                (w * 0.0, h * 0.6, -d * 0.3), (w * 0.0, h * 0.5, -d * 0.3)], 0.05, "copper")
    p.pipe_run([(w * 0.22, h * 0.7, d * 0.2), (w * 0.22, h * 0.82, d * 0.2), (-w * 0.25 + w * 0.2, h * 0.82, d * 0.15)], 0.04, "steel")
    p.bar((-w * 0.5 + 0.05, 0.15, -d * 0.5 + 0.05), (-w * 0.5 + 0.05, h * 0.5, -d * 0.5 + 0.05), 0.04, "hazard")
    p.bar((-w * 0.5 + 0.05, h * 0.5, -d * 0.5 + 0.05), (-w * 0.05, h * 0.5, -d * 0.5 + 0.05), 0.04, "hazard")


RECIPES = {
    "breaker_panel": r_breaker_panel, "power_distributor": r_power_distributor,
    "fission_pile": r_fission_pile, "gas_generator": r_gas_generator,
    "hydrogen_generator": r_hydrogen_generator, "jump_drive": r_jump_drive,
    "drive_stabiliser": r_drive_stabiliser, "quantum_core": r_quantum_core, "jump_tank": r_jump_tank,
    "air_scrubber": r_air_scrubber, "oxygen_generator": r_oxygen_generator,
    "water_recycler": r_water_recycler, "air_tank_rack": r_air_tank_rack,
    "fire_suppression": r_fire_suppression, "heater": r_heater, "coolant_pump": r_coolant_pump,
    "heat_exchanger": r_heat_exchanger, "pipe_header": r_pipe_header, "refuel_port": r_refuel_port,
    "water_tank": r_water_tank, "helm_console": r_helm_console, "engine_control": r_engine_control,
    "fire_control": r_fire_control, "flight_computer": r_flight_computer,
    "autopilot_core": r_autopilot_core, "comms_suite": r_comms_suite, "survey_array": r_survey_array,
    "shield_generator": r_shield_generator, "shield_booster": r_shield_booster,
    "signature_damper": r_signature_damper, "lathe": r_lathe, "crane_hoist": r_crane_hoist,
    "tow_winch": r_tow_winch, "attractor_coil": r_attractor_coil, "scrap_grinder": r_scrap_grinder,
    "smelter": r_smelter, "refinery": r_refinery,
}
