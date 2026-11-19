"""Recipes for hull fittings, weapons, engines and heavy structure.

Each takes (p, s): the Part being built and its catalogue size (w across, h up, d deep). A
hull-mounted part (`hull_mount` in its catalogue entry) has its mounting plate at z = +d / 2,
against the hull, and stands out from it towards -Z; anything it points (a barrel, a nozzle, an
emitter) points out along -Z. Parts that stand in rooms face -Z as usual.
"""

import math

GUN = (0.36, 0.4, 0.38)
ENGINE = (0.42, 0.45, 0.48)
HULL = (0.56, 0.58, 0.6)


def mount_plate(p, s, depth=0.08, material="gunmetal", bolts=True):
    """The plate a hull fitting is bolted to the hull with, at +Z."""
    w, h, d = s
    p.box((w, h, depth), (0, h * 0.5, d * 0.5 - depth * 0.5), material, 0.012)
    if bolts:
        for sx in (-1, 1):
            for sy in (-1, 1):
                p.cyl(0.02, 0.02, (sx * (w * 0.5 - 0.06), h * 0.5 + sy * (h * 0.5 - 0.06), d * 0.5 - depth - 0.005),
                      "z", "chrome", 6, 0.0)


def barrel(p, base, length, r, material="dark", brake=True):
    """A barrel from `base` out along -Z."""
    x, y, z = base
    p.cyl(r, length, (x, y, z - length * 0.5), "z", material, 16)
    p.cyl(r * 1.5, length * 0.25, (x, y, z - length * 0.15), "z", "gunmetal", 16)
    if brake:
        p.cyl(r * 1.35, length * 0.08, (x, y, z - length + length * 0.04), "z", "gunmetal", 12)


# --- weapons ---

def r_gatling_gun(p, s):
    w, h, d = s
    p.box((w, h, 0.1), (0, h * 0.5, d * 0.5 - 0.05), "gunmetal", 0.01)
    p.cyl(w * 0.42, 0.25, (0, h * 0.5, d * 0.5 - 0.2), "z", GUN, 20)
    for i in range(6):
        t = i * math.pi / 3
        x, y = math.cos(t) * w * 0.17, h * 0.5 + math.sin(t) * w * 0.17
        p.cyl(0.03, d - 0.35, (x, y, -0.175 + 0.0 - (d * 0.5 - 0.35) + (d - 0.35) * 0.5 - 0.0 + 0.0), "z", "dark", 10)
    for z in (-d * 0.2, -d * 0.45):
        p.cyl(w * 0.27, 0.04, (0, h * 0.5, z), "z", "gunmetal", 20)
    p.cyl(0.04, d - 0.35, (0, h * 0.5, d * 0.5 - 0.35 - (d - 0.35) * 0.5), "z", "gunmetal", 12)
    p.lamp(0.02, (0, h - 0.06, d * 0.5 - 0.33), "-z", "lamp_amber")


def turret_base(p, s, r):
    w, h, d = s
    mount_plate(p, s, 0.08)
    p.cyl(r, 0.2, (0, h * 0.5, d * 0.5 - 0.18), "z", "gunmetal", 28)
    p.torus(r, 0.03, (0, h * 0.5, d * 0.5 - 0.28), "z", "dark", 28, 6)


def r_point_defence(p, s):
    w, h, d = s
    turret_base(p, s, w * 0.42)
    p.sphere(w * 0.38, (0, h * 0.5, d * 0.5 - 0.35), GUN, 24, 12, squash=1.0)
    for sx in (-1, 1):
        barrel(p, (sx * 0.06, h * 0.5, d * 0.5 - 0.6), d - 0.6 - 0.0, 0.025)
    p.box((0.14, 0.08, 0.06), (0, h * 0.5 + w * 0.3, d * 0.5 - 0.45), "dark", 0.01)
    p.box((0.1, 0.05, 0.01), (0, h * 0.5 + w * 0.3, d * 0.5 - 0.485), "lamp_red", 0.0)


def r_decoy_launcher(p, s):
    w, h, d = s
    mount_plate(p, s, 0.08)
    p.box((w - 0.08, h - 0.08, d - 0.2), (0, h * 0.5, -0.06), GUN, 0.02)
    for i in range(3):
        for j in range(2):
            p.cyl(0.08, 0.04, (-w * 0.28 + i * w * 0.28, h * 0.3 + j * h * 0.4, -d * 0.5 + 0.03), "z", "gunmetal", 16)
            p.cyl(0.06, 0.02, (-w * 0.28 + i * w * 0.28, h * 0.3 + j * h * 0.4, -d * 0.5 + 0.01), "z", "hazard", 16)
            p.cyl(0.035, 0.01, (-w * 0.28 + i * w * 0.28, h * 0.3 + j * h * 0.4, -d * 0.5 + 0.0), "z", "dark", 12)
    p.box((w - 0.1, 0.03, 0.01), (0, h - 0.07, -d * 0.5 + 0.035), "hazard", 0.0)


def r_missile_rack(p, s):
    w, h, d = s
    mount_plate(p, s, 0.1)
    p.box((w, h * 0.2, d - 0.1), (0, h * 0.1, -0.05), GUN, 0.02)
    for i in range(3):
        x = -w * 0.33 + i * w * 0.33
        p.box((0.06, h * 0.1, d - 0.3), (x, h * 0.25, -0.05), "gunmetal", 0.006)
        r = min(w / 3 * 0.32, h * 0.3)
        y = h * 0.3 + r + 0.02
        p.cyl(r, d - 0.5, (x, y, -0.0), "z", "white", 16)
        p.cyl(r, d * 0.18, (x, y, -d * 0.5 + 0.2 - 0.0), "z", "red", 16, r2=0.02)
        p.objects[-1].rotation_euler[0] = -math.pi / 2
        for k in range(4):
            t = k * math.pi / 2 + math.pi / 4
            p.box((0.008, r * 1.1, 0.15), (x + math.cos(t) * r * 0.9, y + math.sin(t) * r * 0.9, d * 0.5 - 0.35), "dark", 0.0, rot_z=t)


def r_mining_laser(p, s):
    w, h, d = s
    mount_plate(p, s, 0.1)
    r = min(w, h) * 0.42
    p.cyl(r, d * 0.45, (0, h * 0.5, d * 0.5 - 0.1 - d * 0.225), "z", "hazard", 24)
    for i in range(6):
        p.torus(r, 0.025, (0, h * 0.5, d * 0.5 - 0.15 - i * d * 0.07), "z", "gunmetal", 24, 6)
    p.cyl(r * 0.7, d * 0.3, (0, h * 0.5, -d * 0.5 + d * 0.3 * 0.5 + 0.08), "z", "gunmetal", 24, r2=None)
    p.cyl(r * 0.5, 0.1, (0, h * 0.5, -d * 0.5 + 0.05), "z", "dark", 24, r2=r * 0.35)
    p.cyl(r * 0.3, 0.02, (0, h * 0.5, -d * 0.5 + 0.01), "z", "lamp_red", 20)
    p.box((0.1, 0.12, d * 0.3), (r + 0.03, h * 0.5, d * 0.1), "dark", 0.01)


def r_tractor_beam(p, s):
    w, h, d = s
    mount_plate(p, s, 0.1)
    r = min(w, h) * 0.45
    p.cyl(r * 0.6, d * 0.5, (0, h * 0.5, d * 0.5 - 0.1 - d * 0.25), "z", ENGINE, 20)
    p.cyl(r, d * 0.4, (0, h * 0.5, -d * 0.5 + d * 0.2), "z", "gunmetal", 28, r2=None)
    p.cyl(r * 0.9, 0.03, (0, h * 0.5, -d * 0.5 + 0.04), "z", "dark", 28)
    for i in range(3):
        p.torus(r * (0.3 + i * 0.22), 0.02, (0, h * 0.5, -d * 0.5 + 0.02), "z", "lamp_cyan", 28, 6)
    for i in range(4):
        t = i * math.pi / 2
        p.box((0.05, 0.05, d * 0.45), (math.cos(t) * r * 0.85, h * 0.5 + math.sin(t) * r * 0.85, d * 0.05), "dark", 0.006)


def r_railgun(p, s):
    w, h, d = s
    mount_plate(p, s, 0.12)
    p.box((w, h * 0.5, d * 0.35), (0, h * 0.3, d * 0.5 - 0.12 - d * 0.175), GUN, 0.03)
    for sx in (-1, 1):
        p.box((0.12, 0.26, d * 0.7), (sx * 0.12, h * 0.55, -d * 0.5 + d * 0.35), "gunmetal", 0.01)
        p.box((0.02, 0.2, d * 0.65), (sx * 0.06, h * 0.55, -d * 0.5 + d * 0.33), "lamp_blue", 0.0)
    for i in range(6):
        p.box((0.4, 0.34, 0.05), (0, h * 0.55, -d * 0.5 + 0.2 + i * d * 0.1), "dark", 0.006)
    p.cyl(0.08, d * 0.25, (w * 0.32, h * 0.3, d * 0.1), "z", "copper", 16)


# --- engines ---

def nozzle(p, at, r, length, paint=ENGINE):
    """An engine bell from `at` (its throat) out along -Z."""
    x, y, z = at
    p.cyl(r * 0.45, length * 0.25, (x, y, z - length * 0.125), "z", "gunmetal", 24)
    p.cyl(r * 0.5, length * 0.75, (x, y, z - length * 0.25 - length * 0.375), "z", "dark", 28, r2=None)
    p.objects[-1].data  # keep
    bell = p.cyl(r, length * 0.75, (x, y, z - length * 0.625), "z", paint, 28, r2=r * 0.5)
    bell.rotation_euler[0] += math.pi
    p.cyl(r * 0.85, 0.02, (x, y, z - length + 0.01), "z", "lamp_amber", 28)
    for i in range(3):
        p.torus(r * (0.65 + i * 0.12), 0.015, (x, y, z - length * (0.4 + i * 0.18)), "z", "steel", 28, 6)


def r_stern_thruster(p, s):
    w, h, d = s
    mount_plate(p, s, 0.1)
    p.box((w * 0.7, h * 0.7, d * 0.25), (0, h * 0.5, d * 0.5 - 0.1 - d * 0.125), ENGINE, 0.03)
    nozzle(p, (0, h * 0.5, d * 0.5 - 0.1 - d * 0.25), min(w, h) * 0.45, d * 0.65)


def r_engine_pod(p, s):
    w, h, d = s
    mount_plate(p, s, 0.12)
    p.box((w * 0.3, h * 0.3, 0.6), (0, h * 0.5, d * 0.5 - 0.42), "gunmetal", 0.02)
    r = min(w, h) * 0.46
    zc = -0.2
    p.cyl(r, d * 0.55, (0, h * 0.5, zc + 0.3), "z", ENGINE, 32)
    p.cyl(r * 0.85, 0.3, (0, h * 0.5, zc + 0.3 + d * 0.275 + 0.15), "z", "dark", 32, r2=r * 0.4)
    for i in range(4):
        p.torus(r + 0.01, 0.03, (0, h * 0.5, zc + 0.3 - d * 0.2 + i * d * 0.13), "z", "gunmetal", 32, 8)
    p.cyl(r * 0.95, 0.1, (0, h * 0.5, zc + 0.3 - d * 0.275 - 0.05), "z", "steel", 32)
    nozzle(p, (0, h * 0.5, zc + 0.3 - d * 0.275 - 0.1), r * 0.9, d * 0.3)
    p.box((w * 0.5, 0.04, 0.01), (0, h * 0.5 + r - 0.02, zc), "hazard", 0.0)


def r_afterburner_ring(p, s):
    w, h, d = s
    r = min(w, h) * 0.45
    p.floor_box((w * 0.8, 0.12, d), (0, 0, 0), "dark", 0.01)
    p.torus(r - 0.08, 0.08, (0, h * 0.5, 0), "z", "gunmetal", 40, 10)
    p.cyl(r, d * 0.8, (0, h * 0.5, 0), "z", ENGINE, 40)
    p.cyl(r - 0.12, d * 0.85, (0, h * 0.5, 0), "z", "dark", 40)
    for i in range(12):
        t = i * math.pi / 6
        p.cyl(0.03, 0.06, (math.cos(t) * (r - 0.14), h * 0.5 + math.sin(t) * (r - 0.14), -d * 0.43), "z", "lamp_amber", 8)
    for sx in (-1, 1):
        p.bar((sx * w * 0.3, 0.1, 0), (sx * r * 0.7, h * 0.5 - r * 0.7, 0), 0.08, "gunmetal")
    p.pipe_run([(r, h * 0.5, 0), (r + 0.05, h * 0.5, 0), (r + 0.05, 0.15, 0)], 0.035, "copper")


# --- sensors and lights on the hull ---

def r_radar_array(p, s):
    w, h, d = s
    p.box((0.5, h, 0.08), (0, h * 0.5, d * 0.5 - 0.04), "gunmetal", 0.01)
    p.cyl(0.1, d * 0.6, (0, h * 0.5, d * 0.5 - 0.08 - d * 0.3), "z", "gunmetal", 16)
    p.cyl(0.18, 0.15, (0, h * 0.5, -d * 0.5 + 0.55), "z", "dark", 20)
    # The phased array: a wide flat panel on the end of the boom, a grid of emitters on its face.
    p.box((w, h, 0.14), (0, h * 0.5, -d * 0.5 + 0.38), (0.82, 0.84, 0.82), 0.02)
    p.box((w - 0.08, h - 0.08, 0.02), (0, h * 0.5, -d * 0.5 + 0.3), "dark", 0.004)
    for i in range(8):
        for j in range(3):
            p.box((w / 8 - 0.04, h / 3 - 0.06, 0.012), (-w * 0.5 + 0.04 + (w - 0.08) / 8 * (i + 0.5),
                  0.04 + (h - 0.08) / 3 * (j + 0.5), -d * 0.5 + 0.285), "gunmetal", 0.002)
    p.lamp(0.02, (w * 0.5 - 0.06, h - 0.06, -d * 0.5 + 0.3), "-z", "lamp_red")
    p.box((0.06, h * 0.6, 0.25), (0, h * 0.5, -d * 0.5 + 0.12), "dark", 0.01)

def r_nav_lights(p, s):
    w, h, d = s
    p.box((w, h, 0.06), (0, h * 0.5, d * 0.5 - 0.03), "gunmetal", 0.008)
    p.cyl(w * 0.35, d * 0.4, (0, h * 0.5, d * 0.5 - 0.06 - d * 0.2), "z", "dark", 16)
    p.sphere(w * 0.3, (0, h * 0.5, -d * 0.5 + w * 0.3), "lamp_green", 16, 8)
    p.torus(w * 0.3, 0.012, (0, h * 0.5, -d * 0.5 + w * 0.32), "z", "chrome", 16, 6)


# --- doors and structure ---

def r_docking_port(p, s):
    w, h, d = s
    r = min(w, h) * 0.5
    p.cyl(r, 0.12, (0, h * 0.5, d * 0.5 - 0.06), "z", "gunmetal", 40)
    p.cyl(r * 0.85, d - 0.2, (0, h * 0.5, 0.0), "z", HULL, 40)
    p.torus(r * 0.85, 0.06, (0, h * 0.5, -d * 0.5 + 0.1), "z", "hazard", 40, 8)
    p.cyl(r * 0.7, 0.06, (0, h * 0.5, -d * 0.5 + 0.03), "z", "steel", 40)
    for i in range(8):
        t = i * math.pi / 4
        p.box((0.12, 0.08, 0.1), (math.cos(t) * r * 0.75, h * 0.5 + math.sin(t) * r * 0.75, -d * 0.5 + 0.05), "dark", 0.01, rot_z=t)
    p.cyl(r * 0.3, 0.03, (0, h * 0.5, -d * 0.5 + 0.015), "z", "dark", 24)
    for i in range(4):
        t = i * math.pi / 2 + math.pi / 4
        p.lamp(0.025, (math.cos(t) * r * 0.92, h * 0.5 + math.sin(t) * r * 0.92, d * 0.5 - 0.12), "-z", "lamp_green")


def r_blast_door(p, s):
    w, h, d = s
    for sx in (-1, 1):
        p.floor_box((0.25, h, d), (sx * (w * 0.5 - 0.125), 0, 0), "gunmetal", 0.02)
        for i in range(6):
            p.box((0.04, 0.04, 0.02), (sx * (w * 0.5 - 0.125), 0.2 + i * (h - 0.4) / 5, -d * 0.5 - 0.005), "chrome", 0.004)
    p.floor_box((w, 0.3, d), (0, h - 0.3, 0), "gunmetal", 0.02)
    lw = (w - 0.5) * 0.5
    for sx in (-1, 1):
        x = sx * lw * 0.5
        p.floor_box((lw - 0.01, h - 0.32, d * 0.6), (x, 0.02, 0), HULL, 0.015)
        for i in range(6):
            y = 0.1 + i * (h - 0.5) / 5
            p.box((lw * 0.4, 0.08, 0.02), (x - sx * lw * 0.2, y, -d * 0.3 - 0.01), "hazard", 0.0, rot_z=sx * 0.6)
        p.box((lw * 0.8, 0.2, 0.03), (x, h * 0.55, -d * 0.3 - 0.015), "dark", 0.006)
    p.box((w, 0.06, d), (0, 0.03, 0), "dark", 0.004)
    p.lamp(0.04, (0, h - 0.15, -d * 0.5), "-z", "lamp_red")
    p.lamp(0.04, (w * 0.3, h - 0.15, -d * 0.5), "-z", "lamp_amber")


def r_bulkhead_plating(p, s):
    w, h, d = s
    p.floor_box((w, h, d * 0.5), (0, 0, d * 0.25), HULL, 0.01)
    rows, cols = 3, 2
    for i in range(cols):
        for j in range(rows):
            x = -w * 0.5 + w / cols * (i + 0.5)
            y = h / rows * (j + 0.5)
            p.box((w / cols - 0.04, h / rows - 0.04, d * 0.5), (x, y, -d * 0.25), (0.48, 0.5, 0.52), 0.02)
            for sx in (-1, 1):
                for sy in (-1, 1):
                    p.cyl(0.02, 0.02, (x + sx * (w / cols * 0.5 - 0.08), y + sy * (h / rows * 0.5 - 0.08), -d * 0.5 - 0.0), "z", "chrome", 6, 0.0)
    p.box((w, 0.08, 0.02), (0, 0.3, -d * 0.5 - 0.01), "hazard", 0.0)


def r_landing_gear(p, s):
    # A hull fitting: plate at +Z, the leg out along -Z... a landing leg stands down instead, so
    # it hangs from the plate down to a foot pad at the floor, the pad's middle under the plate.
    w, h, d = s
    p.box((w * 0.8, 0.3, d * 0.5), (0, h - 0.15, d * 0.25), "gunmetal", 0.02)
    p.cyl(0.12, h * 0.5, (0, h * 0.62, 0.0), "y", "gunmetal", 20)
    p.cyl(0.08, h * 0.45, (0, h * 0.3, 0.0), "y", "chrome", 20)
    for sx in (-1, 1):
        p.rod((sx * 0.25, h - 0.3, d * 0.3), (sx * 0.08, h * 0.35, 0.0), 0.04, "gunmetal")
    p.rod((0, h - 0.3, -0.1), (0, h * 0.45, -d * 0.35), 0.04, "gunmetal")
    p.rod((0, h * 0.45, -d * 0.35), (0, h * 0.15, 0.0), 0.035, "hazard")
    p.cyl(0.12, 0.2, (0, 0.12, 0), "x", "gunmetal", 16)
    p.floor_box((w, 0.08, d * 0.9), (0, 0, -d * 0.0), "dark", 0.02)
    p.floor_box((w * 0.8, 0.04, d * 0.7), (0, 0.08, 0), "rubber", 0.01)
    p.box((0.16, 0.04, 0.01), (0, h * 0.7, -0.125), "hazard", 0.0)


def r_drill(p, s):
    w, h, d = s
    mount_plate(p, s, 0.12)
    r = min(w, h) * 0.42
    p.cyl(r, d * 0.4, (0, h * 0.5, d * 0.5 - 0.12 - d * 0.2), "z", "hazard", 28)
    for i in range(3):
        p.torus(r, 0.03, (0, h * 0.5, d * 0.5 - 0.2 - i * d * 0.13), "z", "gunmetal", 28, 6)
    cone = p.cyl(r * 0.85, d * 0.45, (0, h * 0.5, -d * 0.5 + d * 0.225), "z", "steel", 24, r2=0.04)
    cone.rotation_euler[0] += math.pi
    for i in range(5):
        t = i * 2 * math.pi / 5
        p.rod((math.cos(t) * r * 0.8, h * 0.5 + math.sin(t) * r * 0.8, -d * 0.5 + d * 0.43),
              (math.cos(t + 1.2) * 0.06, h * 0.5 + math.sin(t + 1.2) * 0.06, -d * 0.5 + 0.03), 0.03, "dark", 6)


def r_name_board(p, s):
    # A lit sign on the hull: a dark board on stand-offs, a steel frame, the company's letters
    # standing proud in pale capitals, a light channel at each end.
    w, h, d = s
    for sx in (-0.4, 0.0, 0.4):
        p.cyl(0.05, d * 0.5, (sx * w, h * 0.5, d * 0.25), "z", "gunmetal", 12)
    p.box((w, h, d * 0.5), (0, h * 0.5, -d * 0.25 + 0.0), "dark", 0.03)
    for sy in (-1, 1):
        p.box((w, 0.08, d * 0.55), (0, h * 0.5 + sy * (h * 0.5 - 0.04), -d * 0.25), "steel", 0.01)
        for i in range(12):
            p.cyl(0.018, 0.02, (-w * 0.46 + i * w * 0.92 / 11, h * 0.5 + sy * (h * 0.5 - 0.04), -d * 0.5 - 0.01), "z", "chrome", 6, 0.0)
    for sx in (-1, 1):
        p.box((0.06, h - 0.3, 0.02), (sx * (w * 0.5 - 0.12), h * 0.5, -d * 0.5 - 0.005), "lamp_white", 0.0)
        p.grille(0.3, h - 0.4, (sx * (w * 0.5 - 0.4), h * 0.5, -d * 0.5), "-z", 6)
    p.text("BSX LTD", h * 0.55, (0, h * 0.5, -d * 0.5), 0.04, "white")


RECIPES = {
    "gatling_gun": r_gatling_gun, "point_defence": r_point_defence,
    "decoy_launcher": r_decoy_launcher, "missile_rack": r_missile_rack,
    "mining_laser": r_mining_laser, "tractor_beam": r_tractor_beam, "railgun": r_railgun,
    "stern_thruster": r_stern_thruster, "engine_pod": r_engine_pod,
    "afterburner_ring": r_afterburner_ring, "radar_array": r_radar_array, "nav_lights": r_nav_lights,
    "docking_port": r_docking_port, "blast_door": r_blast_door, "bulkhead_plating": r_bulkhead_plating,
    "landing_gear": r_landing_gear, "drill": r_drill, "name_board": r_name_board,
}
