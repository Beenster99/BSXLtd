"""Recipes for fittings in rooms: furniture, galley, crew, storage, medical, lighting, cargo.

Each takes (p, s): the Part being built and its catalogue size (w across, h up, d deep). The
front (the side a person uses) is at z = -d / 2.
"""

import math

GREY = (0.6, 0.62, 0.64)
CREAM = (0.82, 0.8, 0.74)
NAVY = (0.2, 0.26, 0.36)
OLIVE = (0.42, 0.45, 0.32)
ORANGE = (0.8, 0.42, 0.12)
MEDWHITE = (0.88, 0.9, 0.9)


def cupboard(p, s, doors=2, paint=GREY, plinth=0.08):
    w, h, d = s
    p.floor_box((w - 0.04, plinth, d - 0.06), (0, 0, 0.02), "dark", 0.005)
    p.floor_box((w, h - plinth, d), (0, plinth, 0), paint, 0.015)
    p.doors(w - 0.04, h - plinth - 0.04, (0, plinth + (h - plinth) * 0.5, -d * 0.5), doors, "-z", paint)
    p.box((w + 0.01, 0.02, d + 0.01), (0, h - 0.01, 0), "gunmetal", 0.004)


def r_cupboard(p, s):
    cupboard(p, s, 2, CREAM)


def r_wardrobe(p, s):
    w, h, d = s
    cupboard(p, s, 2, (0.5, 0.42, 0.34))
    # A mirror strip on the left leaf.
    p.box((w * 0.18, h * 0.55, 0.004), (-w * 0.25, h * 0.55, -d * 0.5 - 0.022), "chrome", 0.0)


def r_wall_cupboard(p, s):
    w, h, d = s
    p.floor_box((w, h, d), (0, 0, 0), CREAM, 0.012)
    p.doors(w - 0.03, h - 0.03, (0, h * 0.5, -d * 0.5), 2, "-z", CREAM)
    p.box((w - 0.04, 0.03, 0.02), (0, 0.02, -d * 0.5 + 0.02), "lamp_white", 0.0)


def r_drawer_unit(p, s):
    w, h, d = s
    p.floor_box((w - 0.04, 0.06, d - 0.04), (0, 0, 0.0), "dark", 0.005)
    p.floor_box((w, h - 0.06, d), (0, 0.06, 0), GREY, 0.012)
    rows = 4
    ih = (h - 0.1) / rows
    for i in range(rows):
        y = 0.08 + ih * (i + 0.5)
        p.box((w - 0.04, ih - 0.012, 0.02), (0, y, -d * 0.5 - 0.01), GREY, 0.004)
        p.handle((0, y + ih * 0.15, -d * 0.5 - 0.02), w * 0.35, "-z", False, "chrome")
    p.box((w + 0.01, 0.025, d + 0.01), (0, h - 0.0125, 0), "wood", 0.004)


def r_medicine_cabinet(p, s):
    w, h, d = s
    p.floor_box((w, h, d), (0, 0, 0), MEDWHITE, 0.012)
    # Two glass doors on a frame; shelves of boxes behind them.
    for y in (h * 0.3, h * 0.55, h * 0.8):
        p.box((w - 0.06, 0.012, d - 0.06), (0, y, 0.0), "steel", 0.0)
        for i in range(4):
            col = ["white", "red", "fabric_blue", "hazard"][i % 4]
            p.floor_box((0.1, 0.12, 0.12), (-w * 0.32 + i * w * 0.2, y + 0.006, 0.0), col, 0.004)
    for sx in (-1, 1):
        p.box((w * 0.5 - 0.02, h - 0.06, 0.008), (sx * w * 0.25, h * 0.5, -d * 0.5 - 0.004), "glass", 0.0)
        p.handle((sx * 0.05, h * 0.55, -d * 0.5 - 0.01), 0.12, "-z", True, "chrome")
    # A green cross on top.
    p.box((0.16, 0.05, 0.01), (0, h - 0.05, -d * 0.5 - 0.006), "lamp_green", 0.0)
    p.box((0.05, 0.16, 0.01), (0, h - 0.05, -d * 0.5 - 0.006), "lamp_green", 0.0)


def r_spares_cage(p, s):
    w, h, d = s
    # A steel frame, mesh sides (rows of bars), shelves of parts.
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.bar((sx * (w * 0.5 - 0.025), 0, sz * (d * 0.5 - 0.025)), (sx * (w * 0.5 - 0.025), h, sz * (d * 0.5 - 0.025)), 0.05, "hazard")
    for y in (0.05, h * 0.36, h * 0.68, h - 0.03):
        p.box((w, 0.04, d), (0, y, 0), "steel", 0.004)
    for i in range(12):
        x = -w * 0.5 + 0.05 + (w - 0.1) * i / 11
        p.rod((x, 0.05, -d * 0.5 + 0.01), (x, h - 0.03, -d * 0.5 + 0.01), 0.006, "steel", 6)
        p.rod((x, 0.05, d * 0.5 - 0.01), (x, h - 0.03, d * 0.5 - 0.01), 0.006, "steel", 6)
    for (x, y, col) in [(-0.3, 0.07, "copper"), (0.25, 0.07, "gunmetal"), (-0.2, h * 0.38, "red"),
                        (0.3, h * 0.38, "dark"), (0.0, h * 0.7, "hazard")]:
        p.floor_box((0.32, 0.22, d * 0.6), (x * w, y, 0), col, 0.01)
    p.cyl(0.12, d * 0.6, (0.05 * w, h * 0.38 + 0.14, 0), "z", "steel")


def r_weapons_locker(p, s):
    w, h, d = s
    p.floor_box((w, h, d), (0, 0, 0), OLIVE, 0.015)
    p.doors(w - 0.03, h - 0.1, (0, h * 0.5 + 0.02, -d * 0.5), 2, "-z", OLIVE)
    p.grille(w * 0.6, 0.12, (0, h * 0.85, -d * 0.5 - 0.02), "-z", 4)
    p.screen(0.14, 0.08, (0, h * 0.62, -d * 0.5 - 0.03), "-z", "screen_amber")
    p.box((w * 0.8, 0.05, 0.01), (0, 0.1, -d * 0.5 - 0.02), "hazard", 0.0)


def r_tool_rack(p, s):
    w, h, d = s
    # A pegboard on legs over a bench shelf, tools hung on it.
    p.box((w, h * 0.7, 0.04), (0, h * 0.6, d * 0.5 - 0.04), "gunmetal", 0.008)
    for sx in (-1, 1):
        p.bar((sx * (w * 0.5 - 0.03), 0, d * 0.5 - 0.03), (sx * (w * 0.5 - 0.03), h, d * 0.5 - 0.03), 0.05, "dark")
        p.bar((sx * (w * 0.5 - 0.03), 0, -d * 0.5 + 0.03), (sx * (w * 0.5 - 0.03), h * 0.25, -d * 0.5 + 0.03), 0.04, "dark")
    p.box((w, 0.04, d), (0, h * 0.25, 0), "steel", 0.005)
    z = d * 0.5 - 0.07
    for i, (kind, col) in enumerate([("wrench", "chrome"), ("hammer", "red"), ("saw", "steel"),
                                     ("wrench", "chrome"), ("drill", "hazard"), ("hammer", "red"),
                                     ("wrench", "chrome"), ("grinder", "fabric_blue")]):
        x = -w * 0.42 + i * w * 0.12
        y = h * 0.72
        if kind == "wrench":
            p.box((0.03, 0.3, 0.012), (x, y, z), col, 0.004)
            p.cyl(0.035, 0.012, (x, y + 0.16, z), "z", col, 12)
        elif kind == "hammer":
            p.box((0.03, 0.28, 0.02), (x, y, z), "wood", 0.004)
            p.box((0.12, 0.05, 0.04), (x, y + 0.15, z), "gunmetal", 0.006)
        elif kind == "saw":
            p.box((0.08, 0.32, 0.006), (x, y, z), col, 0.0)
        else:
            p.box((0.07, 0.14, 0.08), (x, y + 0.08, z - 0.02), col, 0.01)
            p.cyl(0.02, 0.1, (x, y - 0.03, z - 0.02), "y", "dark", 10)
    p.floor_box((0.5, 0.18, 0.3), (-w * 0.25, h * 0.27, 0), "red", 0.01)
    p.floor_box((0.4, 0.12, 0.25), (w * 0.25, h * 0.27, 0), "hazard", 0.01)


def r_desk(p, s):
    w, h, d = s
    top_y = 0.76
    p.box((w, 0.04, d), (0, top_y, 0), "wood", 0.008)
    # A pedestal of drawers on the right, a panel leg on the left.
    p.floor_box((0.42, top_y - 0.02, d - 0.06), (w * 0.5 - 0.24, 0, 0.0), GREY, 0.01)
    for i in range(3):
        y = 0.06 + i * 0.23 + 0.1
        p.box((0.38, 0.2, 0.02), (w * 0.5 - 0.24, y, -d * 0.5 + 0.02), GREY, 0.004)
        p.handle((w * 0.5 - 0.24, y + 0.05, -d * 0.5 + 0.01), 0.14, "-z", False)
    p.floor_box((0.04, top_y - 0.02, d - 0.06), (-w * 0.5 + 0.04, 0, 0), GREY, 0.006)
    p.box((w - 0.5, 0.3, 0.02), (-0.2, top_y - 0.2, d * 0.5 - 0.05), GREY, 0.004)
    # A monitor, keyboard and a lamp on top, under the catalogue height.
    p.box((0.08, 0.02, 0.18), (-0.15, top_y + 0.03, 0.2), "dark", 0.004)
    p.box((0.03, 0.1, 0.03), (-0.15, top_y + 0.08, 0.22), "dark", 0.004)
    p.box((0.5, 0.26, 0.03), (-0.15, top_y + 0.2, 0.2), "plastic", 0.006)
    p.box((0.46, 0.22, 0.004), (-0.15, top_y + 0.2, 0.183), "screen", 0.0)
    p.box((0.42, 0.015, 0.14), (-0.15, top_y + 0.028, -0.12), "plastic", 0.003)
    p.cyl(0.07, 0.02, (w * 0.5 - 0.2, top_y + 0.03, 0.2), "y", "dark", 16)
    p.rod((w * 0.5 - 0.2, top_y + 0.04, 0.2), (w * 0.5 - 0.22, top_y + 0.24, 0.1), 0.01, "chrome", 8)
    p.cyl(0.06, 0.06, (w * 0.5 - 0.22, top_y + 0.26, 0.08), "y", "dark", 16, r2=0.03)
    p.cyl(0.055, 0.01, (w * 0.5 - 0.22, top_y + 0.23, 0.08), "y", "lamp_white", 16)


def r_captains_cabin(p, s):
    w, h, d = s
    # A bed along the back, a desk at its foot, a shelf over it.
    bed_w, bed_d = 1.0, d
    bx = -w * 0.5 + bed_w * 0.5
    p.floor_box((bed_w, 0.35, bed_d), (bx, 0, 0), "wood", 0.01)
    p.floor_box((bed_w - 0.06, 0.18, bed_d - 0.06), (bx, 0.35, 0), "fabric_grey", 0.03)
    p.floor_box((bed_w - 0.04, 0.06, bed_d * 0.62), (bx, 0.53, 0.18), NAVY, 0.025)
    p.floor_box((bed_w - 0.2, 0.12, 0.35), (bx, 0.53, -bed_d * 0.5 + 0.25), "white", 0.04)
    p.floor_box((bed_w, h - 0.02, 0.06), (bx, 0, -bed_d * 0.5 + 0.03), "wood", 0.01)
    dx = w * 0.5 - 0.55
    p.box((1.1, 0.04, 0.6), (dx, 0.74, d * 0.5 - 0.3), "wood", 0.008)
    p.floor_box((0.4, 0.72, 0.56), (dx + 0.32, 0, d * 0.5 - 0.3), "wood", 0.01)
    p.floor_box((0.04, 0.72, 0.56), (dx - 0.52, 0, d * 0.5 - 0.3), "wood", 0.006)
    p.box((0.4, 0.26, 0.02), (dx - 0.2, 0.92, d * 0.5 - 0.1), "plastic", 0.004)
    p.box((0.36, 0.22, 0.004), (dx - 0.2, 0.92, d * 0.5 - 0.112), "screen", 0.0)
    # The chair, pulled out.
    cx, cz = dx - 0.15, d * 0.5 - 0.85
    p.cyl(0.22, 0.03, (cx, 0.02, cz), "y", "dark", 5)
    p.cyl(0.03, 0.4, (cx, 0.22, cz), "y", "chrome", 10)
    p.floor_box((0.46, 0.08, 0.44), (cx, 0.42, cz), "leather", 0.03)
    p.floor_box((0.46, 0.5, 0.08), (cx, 0.5, cz - 0.2), "leather", 0.03)
    p.box((w - bed_w, 0.03, 0.25), (bed_w * 0.5, h - 0.015, d * 0.5 - 0.125), "wood", 0.005)
    for i in range(6):
        p.floor_box((0.04, 0.16, 0.18), (0.0 + i * 0.06, h - 0.2 + 0.0, d * 0.5 - 0.12),
                    ["red", "fabric_blue", "leather", "felt", "hazard", "fabric_tan"][i], 0.003)


def r_laundry(p, s):
    w, h, d = s
    p.floor_box((w, h, d), (0, 0, 0), "white", 0.03)
    p.box((w - 0.04, 0.14, 0.02), (0, h - 0.09, -d * 0.5 - 0.005), "plastic", 0.004)
    p.screen(0.14, 0.05, (-0.12, h - 0.09, -d * 0.5 - 0.015), "-z", "screen")
    p.cyl(0.025, 0.03, (0.15, h - 0.09, -d * 0.5 - 0.025), "z", "chrome", 12)
    p.torus(0.2, 0.03, (0, h * 0.42, -d * 0.5 - 0.01), "z", "chrome", 32, 8)
    p.cyl(0.19, 0.012, (0, h * 0.42, -d * 0.5 - 0.005), "z", "glass_dark", 32)
    p.box((0.24, 0.04, 0.02), (0, 0.06, -d * 0.5 - 0.005), "plastic", 0.004)


def r_briefing_screen(p, s):
    w, h, d = s
    p.box((w, h, d * 0.9), (0, h * 0.5, d * 0.05), "plastic", 0.01)
    p.box((w - 0.08, h - 0.08, 0.01), (0, h * 0.5, -d * 0.4 - 0.005), "screen", 0.0)
    # A map on the screen: lit lines over the panel.
    for i in range(5):
        p.box((w * 0.7, 0.01, 0.004), (0, h * 0.25 + i * h * 0.12, -d * 0.4 - 0.012), "lamp_cyan", 0.0)
    p.box((0.4, 0.4, 0.004), (w * 0.25, h * 0.6, -d * 0.4 - 0.013), "screen_amber", 0.0)
    p.box((w * 0.98, 0.05, d * 0.9), (0, 0.025, d * 0.05), "gunmetal", 0.006)


def r_wall_screen(p, s):
    w, h, d = s
    p.box((w, h, d * 0.6), (0, h * 0.5, d * 0.2), "plastic", 0.008)
    p.box((w - 0.06, h - 0.06, 0.006), (0, h * 0.5, -d * 0.1), "screen", 0.0)
    p.box((w * 0.4, h * 0.06, 0.004), (-w * 0.2, h * 0.8, -d * 0.1 - 0.004), "lamp_white", 0.0)
    p.box((w * 0.5, h * 0.3, 0.004), (w * 0.12, h * 0.4, -d * 0.1 - 0.004), "screen_green", 0.0)
    p.lamp(0.01, (w * 0.45, 0.04, -d * 0.1), "-z", "lamp_green")


def r_whiteboard(p, s):
    w, h, d = s
    p.box((w, h, d * 0.4), (0, h * 0.5, d * 0.3), "steel", 0.006)
    p.box((w - 0.06, h - 0.06, 0.01), (0, h * 0.5, d * 0.1 - 0.005), "white", 0.0)
    p.box((w * 0.9, 0.03, 0.06), (0, 0.05, 0.0), "steel", 0.004)
    for i, col in enumerate(["red", "fabric_blue", "plastic"]):
        p.cyl(0.01, 0.12, (-0.3 + i * 0.15, 0.075, -0.01), "x", col, 8)
    # Notes drawn on it.
    for i in range(4):
        p.box((w * (0.3 + 0.1 * i), 0.008, 0.002), (-w * 0.15, h * 0.75 - i * 0.12, d * 0.1 - 0.012), "fabric_blue", 0.0)
    p.box((0.35, 0.25, 0.002), (w * 0.28, h * 0.55, d * 0.1 - 0.012), "red", 0.0)


def r_sofa(p, s):
    w, h, d = s
    seat_h = 0.42
    p.floor_box((w - 0.1, 0.1, d - 0.1), (0, 0, 0), "dark", 0.01)
    p.floor_box((w, seat_h - 0.1, d), (0, 0.1, 0), "fabric_blue", 0.04)
    arm = 0.18
    for sx in (-1, 1):
        p.floor_box((arm, 0.62 - 0.1, d), (sx * (w * 0.5 - arm * 0.5), 0.1, 0), "fabric_blue", 0.05)
    p.floor_box((w - arm * 2, h - seat_h, 0.22), (0, seat_h, d * 0.5 - 0.11), "fabric_blue", 0.05)
    n = 3
    cw = (w - arm * 2) / n
    for i in range(n):
        x = -w * 0.5 + arm + cw * (i + 0.5)
        p.floor_box((cw - 0.02, 0.12, d - 0.26), (x, seat_h, -0.1), "fabric_grey", 0.045)
        p.box((cw - 0.06, h - seat_h - 0.18, 0.12), (x, seat_h + 0.12 + (h - seat_h - 0.18) * 0.5, d * 0.5 - 0.27),
              "fabric_grey", 0.045, rot_x=-0.12)


def r_captains_chair(p, s):
    w, h, d = s
    p.cyl(w * 0.45, 0.06, (0, 0.03, 0), "y", "gunmetal", 8)
    p.cyl(0.07, 0.4, (0, 0.26, 0), "y", "chrome", 16)
    p.floor_box((0.6, 0.12, 0.6), (0, 0.46, -0.02), "leather", 0.04)
    p.box((0.6, h - 0.62, 0.14), (0, 0.58 + (h - 0.62) * 0.5, d * 0.5 - 0.1), "leather", 0.05, rot_x=-0.12)
    p.box((0.34, 0.16, 0.12), (0, h - 0.1, d * 0.5 - 0.08), "leather", 0.05)
    for sx in (-1, 1):
        p.box((0.1, 0.08, 0.6), (sx * (w * 0.5 - 0.05), 0.72, -0.02), "gunmetal", 0.02)
        p.box((0.06, 0.2, 0.06), (sx * (w * 0.5 - 0.05), 0.6, 0.2), "gunmetal", 0.01)
        # Arm consoles with lit keys.
        p.box((0.08, 0.02, 0.22), (sx * (w * 0.5 - 0.05), 0.77, -d * 0.5 + 0.2), "screen", 0.0)


def r_games_table(p, s):
    w, h, d = s
    top = 0.82
    p.floor_box((w * 0.7, top - 0.1, d * 0.5), (0, 0, 0), "wood", 0.02)
    p.box((w, 0.1, d), (0, top - 0.05, 0), "wood", 0.03)
    p.box((w - 0.16, 0.02, d - 0.16), (0, top + 0.005, 0), "felt", 0.0)
    for sx in (-1, 0, 1):
        for sz in (-1, 1):
            p.cyl(0.05, 0.03, (sx * (w * 0.5 - 0.08), top + 0.0, sz * (d * 0.5 - 0.08)), "y", "dark", 12)
    for (x, z, col) in [(-0.3, 0.1, "white"), (0.2, -0.15, "red"), (0.45, 0.2, "hazard"), (0.0, 0.0, "fabric_blue")]:
        p.sphere(0.03, (x, top + 0.045, z), col, 12, 8)
    p.rod((-0.6, top + 0.03, -0.3), (0.3, top + 0.03, -0.2), 0.012, "wood", 8)
    # A score board on a post at one end.
    p.rod((w * 0.5 - 0.05, 0, d * 0.5 - 0.05), (w * 0.5 - 0.05, h - 0.06, d * 0.5 - 0.05), 0.012, "steel", 8)
    p.box((0.22, 0.12, 0.03), (w * 0.5 - 0.05, h - 0.06, d * 0.5 - 0.05), "plastic", 0.006)
    p.box((0.18, 0.08, 0.004), (w * 0.5 - 0.05, h - 0.06, d * 0.5 - 0.067), "screen_amber", 0.0)


def r_gym_rig(p, s):
    w, h, d = s
    # A rack: two uprights, a pull-up bar, a bench, weight plates, a treadmill alongside.
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.bar((sx * 0.45 - 0.45, 0, sz * (d * 0.5 - 0.05)), (sx * 0.45 - 0.45, h, sz * (d * 0.5 - 0.05)), 0.06, "gunmetal")
        p.bar((sx * 0.45 - 0.45, h - 0.03, -d * 0.5 + 0.05), (sx * 0.45 - 0.45, h - 0.03, d * 0.5 - 0.05), 0.06, "gunmetal")
    p.rod((-0.95, h - 0.2, -d * 0.5 + 0.05), (0.05, h - 0.2, -d * 0.5 + 0.05), 0.018, "chrome", 12)
    p.rod((-1.0, 1.2, 0.0), (0.1, 1.2, 0.0), 0.016, "chrome", 12)
    for x in (-0.85, -0.05):
        p.cyl(0.2, 0.05, (x, 1.2, 0.0), "x", "rubber", 24)
    p.floor_box((0.3, 0.42, 1.1), (-0.45, 0, 0), "dark", 0.01)
    p.floor_box((0.3, 0.08, 1.1), (-0.45, 0.42, 0), "leather", 0.03)
    # Treadmill.
    tx = w * 0.5 - 0.4
    p.floor_box((0.7, 0.18, d - 0.1), (tx, 0, 0), "dark", 0.02)
    p.floor_box((0.5, 0.02, d - 0.3), (tx, 0.18, 0), "rubber", 0.0)
    for sx in (-1, 1):
        p.rod((tx + sx * 0.32, 0.18, -d * 0.5 + 0.2), (tx + sx * 0.32, 1.2, -d * 0.5 + 0.1), 0.025, "steel")
    p.box((0.7, 0.12, 0.2), (tx, 1.25, -d * 0.5 + 0.1), "plastic", 0.02)
    p.box((0.4, 0.08, 0.004), (tx, 1.25, -d * 0.5 + 0.0), "screen_green", 0.0)


def r_cooker(p, s):
    w, h, d = s
    top = h - 0.08
    p.floor_box((w, top, d), (0, 0, 0), "steel", 0.012)
    p.box((w, 0.03, d), (0, top + 0.015, 0), "dark", 0.004)
    for sx in (-1, 1):
        for sz in (-1, 1):
            c = (sx * w * 0.24, top + 0.035, sz * d * 0.22)
            p.cyl(0.11, 0.01, c, "y", "dark", 24)
            p.torus(0.08, 0.008, c, "y", "lamp_amber" if sx * sz > 0 else "gunmetal", 24, 6)
    p.box((w, 0.12, 0.04), (0, h - 0.06, d * 0.5 - 0.02), "steel", 0.006)
    # The oven: a dark glass door, a handle, knobs above it.
    p.box((w - 0.12, top * 0.55, 0.02), (0, top * 0.38, -d * 0.5 - 0.01), "glass_dark", 0.004)
    p.box((w - 0.2, 0.02, 0.004), (0, top * 0.58, -d * 0.5 - 0.022), "lamp_amber", 0.0)
    p.handle((0, top * 0.72, -d * 0.5 - 0.01), w * 0.6, "-z", False)
    for i in range(4):
        p.cyl(0.025, 0.03, (-w * 0.3 + i * w * 0.2, top * 0.86, -d * 0.5 - 0.015), "z", "dark", 12)


def r_kitchen_sink(p, s):
    w, h, d = s
    top = h - 0.04
    p.floor_box((w - 0.04, 0.08, d - 0.06), (0, 0, 0.02), "dark", 0.005)
    p.floor_box((w, top - 0.08, d), (0, 0.08, 0), CREAM, 0.012)
    p.doors(w - 0.04, top - 0.14, (0, 0.08 + (top - 0.08) * 0.5, -d * 0.5), 2, "-z", CREAM)
    p.box((w + 0.02, 0.04, d + 0.02), (0, top + 0.02, 0), "steel", 0.006)
    p.box((0.5, 0.03, 0.4), (-0.15, top + 0.026, 0), "dark", 0.0)
    p.box((0.46, 0.02, 0.36), (-0.15, top + 0.034, 0), "steel", 0.0)
    p.box((0.35, 0.01, 0.38), (0.32, top + 0.045, 0), "steel", 0.0)
    for i in range(6):
        p.box((0.33, 0.008, 0.01), (0.32, top + 0.052, -0.15 + i * 0.06), "chrome", 0.0)
    p.cyl(0.025, 0.08, (-0.15, top + 0.08, d * 0.5 - 0.08), "y", "chrome", 12)
    p.rod((-0.15, top + 0.11, d * 0.5 - 0.08), (-0.15, top + 0.11, d * 0.5 - 0.26), 0.012, "chrome", 10)


def r_fridge(p, s):
    w, h, d = s
    p.floor_box((w, h, d), (0, 0, 0), "steel", 0.03)
    split = h * 0.68
    p.box((w - 0.02, h - split - 0.03, 0.03), (0, split + (h - split) * 0.5, -d * 0.5 - 0.01), "steel", 0.008)
    p.box((w - 0.02, split - 0.06, 0.03), (0, split * 0.5 + 0.01, -d * 0.5 - 0.01), "steel", 0.008)
    p.handle((w * 0.38, split + 0.2, -d * 0.5 - 0.02), 0.3, "-z", True)
    p.handle((w * 0.38, split - 0.25, -d * 0.5 - 0.02), 0.4, "-z", True)
    p.screen(0.12, 0.16, (-w * 0.2, split - 0.25, -d * 0.5 - 0.025), "-z", "screen")
    p.box((w * 0.3, 0.06, 0.02), (-w * 0.2, split - 0.5, -d * 0.5 - 0.03), "dark", 0.004)
    p.box((w - 0.1, 0.05, 0.02), (0, 0.04, -d * 0.5 - 0.0), "dark", 0.004)


def r_food_store(p, s):
    w, h, d = s
    # Open shelving of tins, sacks and crates behind a mesh door on one side.
    for sx in (-1, 1):
        p.floor_box((0.04, h, d), (sx * (w * 0.5 - 0.02), 0, 0), GREY, 0.006)
    p.floor_box((w, 0.04, d), (0, h - 0.04, 0), GREY, 0.006)
    p.box((w, h, 0.02), (0, h * 0.5, d * 0.5 - 0.01), GREY, 0.0)
    shelves = [0.05, 0.5, 0.95, 1.4]
    for y in shelves:
        p.box((w - 0.08, 0.03, d - 0.04), (0, y, 0), "steel", 0.004)
    for si, y in enumerate(shelves):
        for i in range(5):
            x = -w * 0.5 + 0.15 + i * (w - 0.3) / 4
            k = (si + i) % 4
            if k == 0:
                for j in range(2):
                    p.cyl(0.05, 0.12, (x, y + 0.075, -0.1 + j * 0.2), "y", "chrome", 14)
            elif k == 1:
                p.floor_box((0.18, 0.25, d * 0.6), (x, y + 0.015, 0), "fabric_tan", 0.04)
            elif k == 2:
                p.floor_box((0.2, 0.18, d * 0.7), (x, y + 0.015, 0), "wood", 0.01)
            else:
                p.floor_box((0.16, 0.3, 0.16), (x, y + 0.015, -0.1), "red", 0.01)
                p.floor_box((0.16, 0.3, 0.16), (x, y + 0.015, 0.1), "white", 0.01)
    p.box((w - 0.04, 0.04, 0.03), (0, h * 0.5, -d * 0.5 + 0.015), "hazard", 0.004)


def r_food_printer(p, s):
    w, h, d = s
    p.floor_box((w, h, d), (0, 0, 0), "white", 0.04)
    p.box((w - 0.12, 0.42, 0.06), (0, 0.85, -d * 0.5 + 0.02), "dark", 0.01)
    p.box((w - 0.18, 0.36, 0.01), (0, 0.85, -d * 0.5 - 0.012), "glass_dark", 0.0)
    p.box((w - 0.2, 0.02, 0.2), (0, 0.66, -d * 0.5 + 0.12), "lamp_cyan", 0.0)
    p.cyl(0.08, 0.03, (0, 0.69, -d * 0.5 + 0.12), "y", "ceramic", 20)
    p.cyl(0.02, 0.12, (0, 1.02, -d * 0.5 + 0.12), "y", "chrome", 10)
    p.screen(0.3, 0.18, (0, 1.32, -d * 0.5), "-z", "screen")
    for i in range(3):
        p.box((0.08, 0.04, 0.02), (-0.1 + i * 0.1, 1.15, -d * 0.5 - 0.01), "plastic", 0.004)
    for i in range(3):
        p.cyl(0.07, 0.1, (-0.25 + i * 0.25, h + 0.03, d * 0.15), "y", ["red", "hazard", "felt"][i], 16)


def r_drinks_dispenser(p, s):
    w, h, d = s
    p.floor_box((w, h, d), (0, 0, 0), "gunmetal", 0.03)
    p.box((w - 0.08, 0.6, 0.02), (0, h - 0.45, -d * 0.5 - 0.005), "glass", 0.0)
    for i in range(3):
        p.cyl(0.07, 0.45, (-0.15 + i * 0.15, h - 0.45, -d * 0.1), "y", ["lamp_amber", "lamp_red", "lamp_cyan"][i], 16)
    p.box((w - 0.06, 0.4, 0.2), (0, 0.85, -d * 0.5 + 0.08), "dark", 0.01)
    for i in range(3):
        x = -0.15 + i * 0.15
        p.cyl(0.018, 0.06, (x, 0.98, -d * 0.5 + 0.08), "y", "chrome", 10)
        p.cyl(0.035, 0.1, (x, 0.75, -d * 0.5 + 0.08), "y", "glass", 12)
    p.box((w - 0.08, 0.02, 0.18), (0, 0.69, -d * 0.5 + 0.09), "steel", 0.0)
    p.screen(0.25, 0.1, (0, 1.12, -d * 0.5), "-z", "screen_amber")


def r_cryo_pod(p, s):
    w, h, d = s
    p.floor_box((w, 0.3, d), (0, 0, 0), "gunmetal", 0.03)
    p.box((w * 0.7, 0.03, d * 0.9), (0, 0.04, 0), "lamp_cyan", 0.0)
    p.floor_box((w - 0.08, 0.35, d - 0.06), (0, 0.3, 0), MEDWHITE, 0.04)
    # The glass lid: a long half cylinder over the bed, frosted.
    p.cyl(w * 0.46, d - 0.2, (0, 0.65, 0), "z", "glass", 28)
    p.floor_box((w * 0.7, 0.1, d - 0.3), (0, 0.6, 0), "fabric_blue", 0.04)
    for sz in (-1, 1):
        p.cyl(w * 0.48, 0.08, (0, 0.65, sz * (d * 0.5 - 0.1)), "z", MEDWHITE, 28)
    p.box((w, 0.04, d), (0, 0.63, 0), "steel", 0.004)
    p.screen(0.3, 0.12, (0, 0.45, -d * 0.5 - 0.0), "-z", "screen")
    p.rod((w * 0.4, 0.3, d * 0.5 - 0.05), (w * 0.4, 0.3, d * 0.5 + 0.0), 0.04, "steel")
    for i in range(4):
        p.lamp(0.012, (-w * 0.3 + i * 0.06, 0.15, -d * 0.5), "-z", "lamp_cyan" if i < 3 else "lamp_green")


def r_surgery_unit(p, s):
    w, h, d = s
    # A table under a lit arm with a lamp head, a screen tower at its side.
    p.floor_box((0.4, 0.08, 0.8), (0, 0, 0), "gunmetal", 0.01)
    p.cyl(0.1, 0.7, (0, 0.43, 0), "y", "chrome", 16)
    p.floor_box((0.6, 0.12, d - 0.1), (0, 0.78, 0), MEDWHITE, 0.03)
    p.floor_box((0.25, 1.9, 0.3), (w * 0.5 - 0.13, 0, d * 0.5 - 0.16), MEDWHITE, 0.03)
    p.screen(0.18, 0.24, (w * 0.5 - 0.13, 1.35, d * 0.5 - 0.31), "-z", "screen_green")
    p.rod((w * 0.5 - 0.13, 1.9, d * 0.5 - 0.16), (0.0, h - 0.1, 0.0), 0.04, "steel", 12)
    p.cyl(0.32, 0.08, (0.0, h - 0.1, 0.0), "y", MEDWHITE, 24)
    p.cyl(0.28, 0.01, (0.0, h - 0.145, 0.0), "y", "lamp_white", 24)
    p.rod((-w * 0.5 + 0.05, 0.9, -d * 0.5 + 0.1), (-w * 0.5 + 0.05, 1.6, -d * 0.5 + 0.1), 0.012, "chrome", 8)
    p.box((0.3, 0.02, 0.2), (-w * 0.5 + 0.15, 1.0, -d * 0.5 + 0.12), "steel", 0.004)


def r_decon_shower(p, s):
    w, h, d = s
    p.floor_box((w, 0.08, d), (0, 0, 0), "gunmetal", 0.01)
    p.box((w - 0.1, 0.01, d - 0.1), (0, 0.085, 0), "dark", 0.0)
    for sx in (-1, 1):
        p.floor_box((0.06, h - 0.16, d), (sx * (w * 0.5 - 0.03), 0.08, 0), "hazard", 0.01)
    p.floor_box((w - 0.12, h - 0.16, 0.06), (0, 0.08, d * 0.5 - 0.03), "white", 0.006)
    p.floor_box((w, 0.08, d), (0, h - 0.08, 0), "gunmetal", 0.01)
    p.box((w - 0.14, h - 0.24, 0.02), (0, h * 0.5, -d * 0.5 + 0.01), "glass", 0.0)
    for i in range(3):
        p.cyl(0.05, 0.03, (-0.25 + i * 0.25, h - 0.1, 0.0), "y", "chrome", 12)
    p.box((w - 0.14, 0.04, 0.04), (0, h - 0.16, -d * 0.5 + 0.02), "lamp_amber", 0.0)
    p.screen(0.12, 0.08, (w * 0.5 - 0.03, 1.4, -d * 0.5 + 0.2), "-x" if False else "+x", "screen")


def r_ceiling_lamp(p, s):
    w, h, d = s
    p.floor_box((w, h * 0.45, d), (0, h * 0.55, 0), "gunmetal", 0.01)
    p.floor_box((w - 0.06, h * 0.25, d - 0.06), (0, h * 0.3, 0), "steel", 0.006)
    p.floor_box((w - 0.1, 0.03, d - 0.1), (0, 0.0, 0), "lamp_white", 0.0)
    for sx in (-1, 1):
        p.box((0.015, h * 0.25, d - 0.08), (sx * (w * 0.25), h * 0.17, 0), "dark", 0.0)


def r_work_light(p, s):
    w, h, d = s
    p.cyl(0.18, 0.04, (0, 0.02, 0), "y", "dark", 16)
    p.bar((0, 0.04, 0), (0, h * 0.5, 0), 0.04, "hazard")
    p.box((w, 0.05, 0.05), (0, h * 0.5, 0), "hazard", 0.006)
    for sx in (-1, 1):
        x = sx * (w * 0.5 - 0.12)
        p.box((0.22, 0.18, d * 0.5), (x, h - 0.1, 0.0), "dark", 0.01, rot_x=0.3)
        p.box((0.2, 0.16, 0.01), (x, h - 0.12, -d * 0.25 + 0.0), "lamp_white", 0.0, rot_x=0.3)
        p.rod((x, h * 0.5, 0), (x, h - 0.15, 0), 0.015, "hazard", 8)


def r_tech_container(p, s):
    w, h, d = s
    p.floor_box((w, h, d), (0, 0, 0), (0.25, 0.3, 0.36), 0.03)
    for sz in (-1, 1):
        p.box((w + 0.02, 0.06, 0.06), (0, 0.04, sz * (d * 0.5 - 0.04)), "dark", 0.008)
        p.box((w + 0.02, 0.06, 0.06), (0, h - 0.03, sz * (d * 0.5 - 0.04)), "dark", 0.008)
    for i in range(3):
        p.box((w + 0.01, h - 0.15, 0.04), (0, h * 0.5, -d * 0.3 + i * d * 0.3), (0.22, 0.27, 0.33), 0.006)
    p.box((w * 0.6, 0.04, 0.02), (0, h * 0.65, -d * 0.5 - 0.005), "hazard", 0.0)
    p.screen(0.18, 0.1, (0, h * 0.45, -d * 0.5), "-z", "screen_green")
    for sx in (-1, 1):
        p.box((0.06, 0.1, 0.03), (sx * w * 0.35, h * 0.45, -d * 0.5 - 0.015), "chrome", 0.006)


def r_cargo_net(p, s):
    w, h, d = s
    # A floor net: rope grid with ring tie-downs at its corners and edges.
    n = 8
    for i in range(n + 1):
        t = -0.5 + i / n
        p.rod((t * (w - 0.1), 0.03, -d * 0.5 + 0.05), (t * (w - 0.1), 0.03, d * 0.5 - 0.05), 0.012, "fabric_tan", 6)
        p.rod((-w * 0.5 + 0.05, 0.03, t * (d - 0.1)), (w * 0.5 - 0.05, 0.03, t * (d - 0.1)), 0.012, "fabric_tan", 6)
    for sx in (-1, 0, 1):
        for sz in (-1, 0, 1):
            if sx == 0 and sz == 0:
                continue
            c = (sx * (w * 0.5 - 0.05), 0.02, sz * (d * 0.5 - 0.05))
            p.box((0.1, 0.02, 0.1), c, "gunmetal", 0.004)
            p.torus(0.04, 0.01, (c[0], 0.06, c[2]), "x", "chrome", 16, 6)


def r_pallet_lifter(p, s):
    w, h, d = s
    # A hand pallet lifter: forks, a mast, a tiller handle.
    for sx in (-1, 1):
        p.floor_box((0.18, 0.08, d - 0.3), (sx * 0.28, 0.02, 0.15), "hazard", 0.01)
        p.cyl(0.04, 0.05, (sx * 0.28, 0.04, d * 0.5 - 0.08), "x", "rubber", 12)
    p.floor_box((w, 0.3, 0.3), (0, 0.0, -d * 0.5 + 0.15), "hazard", 0.02)
    p.cyl(0.07, 0.12, (0, 0.06, -d * 0.5 + 0.15), "x", "rubber", 16)
    for sx in (-1, 1):
        p.bar((sx * 0.2, 0.3, -d * 0.5 + 0.12), (sx * 0.2, h - 0.15, -d * 0.5 + 0.1), 0.06, "gunmetal")
    p.box((w * 0.6, 0.06, 0.06), (0, h - 0.15, -d * 0.5 + 0.1), "gunmetal", 0.006)
    p.cyl(0.05, 0.4, (0, 0.5, -d * 0.5 + 0.2), "y", "chrome", 12)
    p.rod((0, 0.3, -d * 0.5 + 0.15), (0, h - 0.05, -d * 0.5 + 0.0), 0.02, "dark", 8)
    p.rod((-0.18, h - 0.03, -d * 0.5 + 0.0), (0.18, h - 0.03, -d * 0.5 + 0.0), 0.02, "rubber", 8)
    p.box((0.2, 0.12, 0.06), (0, h - 0.4, -d * 0.5 + 0.13), "dark", 0.01)
    p.box((0.14, 0.06, 0.004), (0, h - 0.4, -d * 0.5 + 0.1), "screen_amber", 0.0)


def r_hold_hopper(p, s):
    w, h, d = s
    # A hopper: a funnel on four legs over a chute with a gate.
    top = h - 0.9
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.bar((sx * (w * 0.5 - 0.06), 0, sz * (d * 0.5 - 0.06)), (sx * (w * 0.5 - 0.06), top + 0.2, sz * (d * 0.5 - 0.06)), 0.1, "gunmetal")
    p.cyl(w * 0.705, 0.9, (0, top + 0.45, 0), "y", "hazard", 4, r2=None)
    p.objects[-1].rotation_euler[2] = math.pi / 4
    p.cyl(w * 0.705 - 0.04, 0.8, (0, top + 0.06, 0), "y", (0.6, 0.5, 0.15), 4, r2=0.18)
    p.objects[-1].rotation_euler[2] = math.pi / 4
    p.box((w, 0.08, d), (0, h - 0.04, 0), "dark", 0.01)
    p.cyl(0.18, top * 0.5, (0, top * 0.5, 0), "y", "steel", 16)
    p.box((0.5, 0.08, 0.5), (0, top * 0.28, 0), "gunmetal", 0.01)
    p.box((0.5, 0.06, 0.04), (0, top * 0.28, -0.26), "hazard", 0.004)
    p.screen(0.2, 0.12, (0, top * 0.6, -d * 0.5 + 0.06), "-z", "screen_amber")
    p.box((0.1, 0.12, 0.06), (0.3, top * 0.28, -0.25), "red", 0.01)


RECIPES = {
    "cupboard": r_cupboard, "wardrobe": r_wardrobe, "wall_cupboard": r_wall_cupboard,
    "drawer_unit": r_drawer_unit, "medicine_cabinet": r_medicine_cabinet, "spares_cage": r_spares_cage,
    "weapons_locker": r_weapons_locker, "tool_rack": r_tool_rack, "desk": r_desk,
    "captains_cabin": r_captains_cabin, "laundry": r_laundry, "briefing_screen": r_briefing_screen,
    "wall_screen": r_wall_screen, "whiteboard": r_whiteboard, "sofa": r_sofa,
    "captains_chair": r_captains_chair, "games_table": r_games_table, "gym_rig": r_gym_rig,
    "cooker": r_cooker, "kitchen_sink": r_kitchen_sink, "fridge": r_fridge, "food_store": r_food_store,
    "food_printer": r_food_printer, "drinks_dispenser": r_drinks_dispenser,
    "cryo_pod": r_cryo_pod, "surgery_unit": r_surgery_unit,
    "decon_shower": r_decon_shower, "ceiling_lamp": r_ceiling_lamp, "work_light": r_work_light,
    "tech_container": r_tech_container, "cargo_net": r_cargo_net, "pallet_lifter": r_pallet_lifter,
    "hold_hopper": r_hold_hopper,
}
