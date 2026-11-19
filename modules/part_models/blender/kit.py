"""BSX part models: a small modelling kit over Blender (bpy), so each part is a short recipe.

Coordinates are the game's (Godot): x across, y up, z along, metres, the front of a part at -Z.
The kit turns them into Blender's (x, -z, y), and the glTF exporter turns them back, so a part
built here comes into Godot with its front at -Z and its origin where the recipe put it (the
middle of its footprint, on the floor).

Materials are a fixed palette (MATS) of plain PBR looks; a part's body paint is `paint(rgb)`.
Every box and cylinder gets a small bevel so edges catch the light (the flat-shaded house look).
"""

import math

import bpy
import bmesh
from mathutils import Matrix, Vector

# name -> (base colour sRGB, metallic, roughness, extra)
MATS = {
    "steel": ((0.62, 0.64, 0.66), 0.9, 0.35, {}),
    "chrome": ((0.85, 0.86, 0.88), 1.0, 0.12, {}),
    "dark": ((0.16, 0.17, 0.18), 0.6, 0.5, {}),
    "gunmetal": ((0.28, 0.3, 0.32), 0.8, 0.4, {}),
    "rubber": ((0.05, 0.05, 0.05), 0.0, 0.9, {}),
    "plastic": ((0.12, 0.13, 0.14), 0.0, 0.55, {}),
    "white": ((0.86, 0.87, 0.86), 0.1, 0.45, {}),
    "copper": ((0.78, 0.45, 0.28), 1.0, 0.3, {}),
    "brass": ((0.78, 0.64, 0.32), 1.0, 0.3, {}),
    "hazard": ((0.9, 0.7, 0.1), 0.2, 0.5, {}),
    "red": ((0.7, 0.1, 0.08), 0.2, 0.45, {}),
    "fabric_grey": ((0.35, 0.37, 0.4), 0.0, 0.95, {}),
    "fabric_blue": ((0.18, 0.26, 0.4), 0.0, 0.95, {}),
    "fabric_tan": ((0.55, 0.42, 0.3), 0.0, 0.9, {}),
    "leather": ((0.3, 0.17, 0.1), 0.0, 0.6, {}),
    "wood": ((0.45, 0.3, 0.18), 0.0, 0.6, {}),
    "felt": ((0.08, 0.35, 0.2), 0.0, 0.95, {}),
    "ceramic": ((0.9, 0.91, 0.9), 0.0, 0.2, {}),
    "glass": ((0.6, 0.75, 0.85), 0.0, 0.05, {"alpha": 0.25}),
    "glass_dark": ((0.1, 0.14, 0.18), 0.0, 0.05, {"alpha": 0.6}),
    "screen": ((0.05, 0.08, 0.1), 0.0, 0.3, {"emit": (0.2, 0.6, 0.95), "strength": 1.1}),
    "screen_green": ((0.03, 0.08, 0.04), 0.0, 0.3, {"emit": (0.3, 0.95, 0.45), "strength": 1.1}),
    "screen_amber": ((0.1, 0.06, 0.02), 0.0, 0.3, {"emit": (1.0, 0.6, 0.15), "strength": 1.1}),
    "lamp_white": ((0.95, 0.95, 0.9), 0.0, 0.3, {"emit": (1.0, 0.97, 0.9), "strength": 4.0}),
    "lamp_green": ((0.2, 0.9, 0.3), 0.0, 0.3, {"emit": (0.3, 1.0, 0.4), "strength": 4.0}),
    "lamp_red": ((0.9, 0.15, 0.1), 0.0, 0.3, {"emit": (1.0, 0.2, 0.1), "strength": 4.0}),
    "lamp_amber": ((1.0, 0.6, 0.1), 0.0, 0.3, {"emit": (1.0, 0.6, 0.15), "strength": 4.0}),
    "lamp_blue": ((0.2, 0.5, 1.0), 0.0, 0.3, {"emit": (0.3, 0.6, 1.0), "strength": 4.0}),
    "lamp_violet": ((0.6, 0.3, 1.0), 0.0, 0.3, {"emit": (0.65, 0.35, 1.0), "strength": 4.0}),
    "lamp_cyan": ((0.2, 0.9, 0.9), 0.0, 0.3, {"emit": (0.3, 1.0, 0.95), "strength": 4.0}),
    "plant": ((0.2, 0.45, 0.15), 0.0, 0.8, {}),
    "water": ((0.3, 0.5, 0.65), 0.0, 0.05, {"alpha": 0.5}),
}

_mat_cache = {}


def mat(name):
    """A palette material, or a paint given as an (r, g, b) tuple."""
    if isinstance(name, tuple):
        key = "paint_%02x%02x%02x" % tuple(int(c * 255) for c in name)
        spec = (name, 0.45, 0.5, {})
    else:
        key = name
        spec = MATS[name]
    if key in _mat_cache:
        return _mat_cache[key]
    m = bpy.data.materials.get(key) or bpy.data.materials.new(key)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    col, metal, rough, extra = spec
    lin = tuple(_srgb_to_lin(c) for c in col)
    bsdf.inputs["Base Color"].default_value = (*lin, 1.0)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    if "emit" in extra:
        e = tuple(_srgb_to_lin(c) for c in extra["emit"])
        bsdf.inputs["Emission Color"].default_value = (*e, 1.0)
        bsdf.inputs["Emission Strength"].default_value = extra.get("strength", 2.0)
    if "alpha" in extra:
        bsdf.inputs["Alpha"].default_value = extra["alpha"]
        m.surface_render_method = "BLENDED"
    _mat_cache[key] = m
    return m


def _srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def B(v):
    """Game (x, y up, z) to Blender (x, -z, y)."""
    return Vector((v[0], -v[2], v[1]))


class Part:
    """One part being built: every piece goes into its collection."""

    def __init__(self, pid):
        self.id = pid
        self.objects = []
        # Moving parts: every primitive goes to the current piece ("base" is the fixed one).
        self.piece = "base"
        self.pieces = {}
        self.top = {}

    def moving(self, name, pivot, parent="base", kind="hinge", axis=(1, 0, 0), stowed=0.0, deployed=0.0,
               seconds=2.0, order=1, **extra):
        """From here on, primitives belong to the moving piece `name`, which turns (hinge, degrees)
        or slides (slide, metres) about or along `axis` (part space) through `pivot` (game
        coordinates, as built). The model is built at value 0; `stowed` and `deployed` are the
        values at the two ends of an Operate (0 is the pose as built). `order`: pieces with a lower
        number move first when deploying, the same number together. `extra` (contact=...) goes
        into the motion note; a contact's `at` is in game coordinates as built."""
        self.pieces[name] = dict(name=name, parent=parent, kind=kind, axis=list(axis), stowed=stowed,
                                 deployed=deployed, seconds=seconds, order=order, pivot=Vector(pivot), **extra)
        self.piece = name

    def fixed(self):
        """Back to the fixed base."""
        self.piece = "base"

    def note(self, **kw):
        """Top-level facts for the motion note (power_kw, load_kg, opening)."""
        self.top.update(kw)

    def _add(self, obj, material, bevel):
        obj.data.materials.clear()
        obj.data.materials.append(mat(material))
        if bevel > 0.0:
            mod = obj.modifiers.new("bevel", "BEVEL")
            mod.width = bevel
            mod.segments = 1
            mod.limit_method = "ANGLE"
            mod.harden_normals = False
        for p in obj.data.polygons:
            p.use_smooth = False
        obj["piece"] = self.piece
        self.objects.append(obj)
        return obj

    # --- primitives (game coordinates) ---

    def box(self, size, at=(0, 0, 0), material="steel", bevel=0.012, rot_y=0.0, rot_x=0.0, rot_z=0.0):
        """A box `size` (x, y, z) centred at `at`; turned rot_x, rot_y, rot_z radians (game axes)."""
        bpy.ops.mesh.primitive_cube_add(size=1.0)
        o = bpy.context.active_object
        o.scale = (size[0], size[2], size[1])
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        o.rotation_mode = "XYZ"
        o.matrix_world = Matrix.Translation(B(at)) @ _game_rot(rot_x, rot_y, rot_z)
        bev = min(bevel, min(size) * 0.3)
        return self._add(o, material, bev)

    def floor_box(self, size, at=(0, 0, 0), material="steel", bevel=0.012, rot_y=0.0):
        """A box standing on y = at[1], centred on x and z."""
        return self.box(size, (at[0], at[1] + size[1] * 0.5, at[2]), material, bevel, rot_y)

    def cyl(self, r, length, at=(0, 0, 0), axis="y", material="steel", verts=24, bevel=0.006, r2=None):
        """A cylinder (or a frustum with r2) along a game axis ("x", "y", "z"), centred at `at`."""
        if r2 is None:
            bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=length)
        else:
            bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=length)
        o = bpy.context.active_object
        # Blender's cylinder runs along its Z (the game's y).
        rot = {"y": Matrix.Identity(4), "x": Matrix.Rotation(math.pi / 2, 4, "Y"),
               "z": Matrix.Rotation(math.pi / 2, 4, "X")}[axis]
        o.matrix_world = Matrix.Translation(B(at)) @ rot
        return self._add(o, material, min(bevel, r * 0.2))

    def sphere(self, r, at=(0, 0, 0), material="steel", segs=24, rings=12, squash=1.0):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=r)
        o = bpy.context.active_object
        o.scale = (1, 1, squash)
        o.location = B(at)
        return self._add(o, material, 0.0)

    def torus(self, big, small, at=(0, 0, 0), axis="y", material="steel", segs=32, minor=10):
        bpy.ops.mesh.primitive_torus_add(major_radius=big, minor_radius=small, major_segments=segs,
                                         minor_segments=minor)
        o = bpy.context.active_object
        rot = {"y": Matrix.Identity(4), "x": Matrix.Rotation(math.pi / 2, 4, "Y"),
               "z": Matrix.Rotation(math.pi / 2, 4, "X")}[axis]
        o.matrix_world = Matrix.Translation(B(at)) @ rot
        return self._add(o, material, 0.0)

    def rod(self, a, b, r, material="steel", verts=12):
        """A round bar from point a to point b (game coordinates)."""
        va, vb = B(a), B(b)
        d = vb - va
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d.length)
        o = bpy.context.active_object
        o.matrix_world = Matrix.Translation((va + vb) * 0.5) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        return self._add(o, material, 0.0)

    def bar(self, a, b, w, material="steel"):
        """A square bar w x w from a to b."""
        va, vb = B(a), B(b)
        d = vb - va
        bpy.ops.mesh.primitive_cube_add(size=1.0)
        o = bpy.context.active_object
        o.scale = (w, w, d.length)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        o.matrix_world = Matrix.Translation((va + vb) * 0.5) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        return self._add(o, material, min(0.004, w * 0.2))

    def prism(self, points, depth, at=(0, 0, 0), axis="x", material="steel", bevel=0.01):
        """A 2D outline (u, v pairs) extruded `depth` along `axis`. For axis x the outline is (z, y);
        for z it is (x, y); for y it is (x, z)."""
        bm = bmesh.new()
        vs = []
        for (u, v) in points:
            if axis == "x":
                g = (0.0, v, u)
            elif axis == "z":
                g = (u, v, 0.0)
            else:
                g = (u, 0.0, v)
            vs.append(bm.verts.new(B(g)))
        face = bm.faces.new(vs)
        ext = {"x": (depth, 0, 0), "z": (0, 0, depth), "y": (0, depth, 0)}[axis]
        r = bmesh.ops.extrude_face_region(bm, geom=[face])
        moved = [e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)]
        bmesh.ops.translate(bm, vec=B(ext), verts=moved)
        half = B(tuple(-c * 0.5 for c in ext))
        bmesh.ops.translate(bm, vec=half, verts=bm.verts)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new("prism")
        bm.to_mesh(me)
        bm.free()
        o = bpy.data.objects.new("prism", me)
        bpy.context.scene.collection.objects.link(o)
        o.location = B(at)
        return self._add(o, material, bevel)

    # --- details ---

    def screen(self, w, h, at, facing="-z", material="screen", bezel="plastic"):
        """A screen in a bezel on a face: `at` is the face point, `facing` the face's outward axis."""
        n = _axis_vec(facing)
        d = 0.025
        c = (at[0] + n[0] * d * 0.5, at[1] + n[1] * d * 0.5, at[2] + n[2] * d * 0.5)
        sz = _face_size(facing, w + 0.05, h + 0.05, d)
        self.box(sz, c, bezel, 0.006)
        c2 = (at[0] + n[0] * (d + 0.002), at[1] + n[1] * (d + 0.002), at[2] + n[2] * (d + 0.002))
        self.box(_face_size(facing, w, h, 0.004), c2, material, 0.0)

    def panel(self, w, h, at, facing="-z", material="dark", proud=0.01):
        """A plate standing proud of a face."""
        n = _axis_vec(facing)
        c = tuple(at[i] + n[i] * proud * 0.5 for i in range(3))
        self.box(_face_size(facing, w, h, proud), c, material, 0.003)

    def lamp(self, r, at, facing="-z", material="lamp_green"):
        n = _axis_vec(facing)
        axis = facing[-1]
        c = tuple(at[i] + n[i] * 0.01 for i in range(3))
        self.cyl(r, 0.02, c, axis, material, verts=12, bevel=0.0)

    def grille(self, w, h, at, facing="-z", slats=8, material="dark", frame="gunmetal"):
        """A louvred vent: a frame and horizontal slats."""
        n = _axis_vec(facing)
        self.panel(w, h, at, facing, frame, 0.008)
        pitch = h / slats
        for i in range(slats):
            y = at[1] - h * 0.5 + pitch * (i + 0.5)
            c = (at[0] + n[0] * 0.014, y, at[2] + n[2] * 0.014)
            self.box(_face_size(facing, w * 0.92, pitch * 0.45, 0.012), c, material, 0.0)

    def handle(self, at, length, facing="-z", vertical=True, material="chrome"):
        """A bar handle on two stand-offs."""
        n = _axis_vec(facing)
        off = 0.04
        if vertical:
            a = (at[0], at[1] - length * 0.5, at[2])
            b = (at[0], at[1] + length * 0.5, at[2])
        else:
            u = _face_u(facing)
            a = tuple(at[i] - u[i] * length * 0.5 for i in range(3))
            b = tuple(at[i] + u[i] * length * 0.5 for i in range(3))
        pa = tuple(a[i] + n[i] * off for i in range(3))
        pb = tuple(b[i] + n[i] * off for i in range(3))
        self.rod(pa, pb, 0.012, material, 8)
        self.rod(a, pa, 0.01, material, 8)
        self.rod(b, pb, 0.01, material, 8)

    def bolts(self, centre, radius, count, axis="y", r=0.015, material="chrome"):
        for i in range(count):
            t = 2 * math.pi * i / count
            if axis == "y":
                p = (centre[0] + math.cos(t) * radius, centre[1], centre[2] + math.sin(t) * radius)
            elif axis == "z":
                p = (centre[0] + math.cos(t) * radius, centre[1] + math.sin(t) * radius, centre[2])
            else:
                p = (centre[0], centre[1] + math.cos(t) * radius, centre[2] + math.sin(t) * radius)
            self.cyl(r, 0.02, p, axis, material, verts=6, bevel=0.0)

    def legs(self, w, d, h, r=0.025, inset=0.06, material="steel", feet=True):
        """Four legs from the floor to h under a w x d top."""
        for sx in (-1, 1):
            for sz in (-1, 1):
                x = sx * (w * 0.5 - inset)
                z = sz * (d * 0.5 - inset)
                self.cyl(r, h, (x, h * 0.5, z), "y", material, 10, 0.0)
                if feet:
                    self.cyl(r * 1.6, 0.02, (x, 0.01, z), "y", "rubber", 10, 0.0)

    def doors(self, w, h, at, count=2, facing="-z", material="steel", handle="chrome", gap=0.008):
        """`count` door leaves side by side across a face with handles."""
        n = _axis_vec(facing)
        u = _face_u(facing)
        lw = w / count
        for i in range(count):
            off = -w * 0.5 + lw * (i + 0.5)
            c = tuple(at[k] + u[k] * off + n[k] * 0.01 for k in range(3))
            self.box(_face_size(facing, lw - gap, h - gap, 0.02), c, material, 0.004)
            hx = off + (lw * 0.35 if i % 2 == 0 else -lw * 0.35) if count > 1 else off + lw * 0.38
            hc = tuple(at[k] + u[k] * hx + n[k] * 0.02 for k in range(3))
            self.handle(hc, min(0.25, h * 0.3), facing, True, handle)

    def text(self, words, size, at, depth=0.03, material="white"):
        """Block letters `size` tall standing `depth` proud of a face at `at`, centred on it,
        reading left to right for someone standing in front of the part (at -Z, so along -X)."""
        bpy.ops.object.text_add()
        o = bpy.context.active_object
        o.data.body = words
        o.data.size = size
        o.data.extrude = depth * 0.5
        o.data.align_x = "CENTER"
        o.data.align_y = "CENTER"
        # Blender's text lies in its XY plane facing +Z (the game's up): stand it up facing -Z,
        # turned half round so it reads the right way from the front.
        o.matrix_world = (Matrix.Translation(B((at[0], at[1], at[2] - depth * 0.5))) @ Matrix.Rotation(math.pi, 4, "Z")
                          @ Matrix.Rotation(math.pi / 2, 4, "X"))
        bpy.ops.object.convert(target="MESH")
        o = bpy.context.active_object
        return self._add(o, material, 0.0)

    def pipe_run(self, points, r, material="steel"):
        for a, b in zip(points, points[1:]):
            self.rod(a, b, r, material, 12)
        for p in points[1:-1]:
            self.sphere(r * 1.05, p, material, 12, 8)

    # --- finishing ---

    def join(self):
        """Applies the bevels and joins the primitives into one mesh (one surface a material, so a
        part is a handful of draw calls); a moving part into one mesh a piece."""
        groups = {}
        for o in self.objects:
            groups.setdefault(o.get("piece", "base"), []).append(o)
        joined = []
        for name in ["base"] + [n for n in self.pieces if n in groups]:
            objs = groups.get(name, [])
            if not objs:
                continue
            bpy.ops.object.select_all(action="DESELECT")
            for o in objs:
                o.select_set(True)
            bpy.context.view_layer.objects.active = objs[0]
            bpy.ops.object.convert(target="MESH")
            bpy.ops.object.join()
            o = bpy.context.view_layer.objects.active
            o.name = self.id if not self.pieces else name
            o.data.name = o.name
            o["piece"] = name
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
            joined.append(o)
        self.objects = joined

    def fit(self, size):
        """Scales the joined part along each axis to exactly `size` (game x, y, z), its footprint
        centred on the origin and its foot on the floor, then sets each moving piece's origin on its
        pivot, parented as declared. Returns the scale used per axis."""
        lo, hi = self.bounds()
        got = hi - lo
        k = [size[i] / got[i] if got[i] > 1e-6 else 1.0 for i in range(3)]
        mid = (lo + hi) * 0.5

        def tx(g):
            return Vector(((g.x - mid.x) * k[0], (g.y - lo.y) * k[1], (g.z - mid.z) * k[2]))

        for o in self.objects:
            for v in o.data.vertices:
                v.co = B(tx(Vector((v.co.x, v.co.z, -v.co.y))))
            o.data.update()
        self.scale = k
        by_name = {o["piece"]: o for o in self.objects}
        for name, pc in self.pieces.items():
            pc["pivot"] = tx(pc["pivot"])
            if "contact" in pc:
                pc["contact"]["at"] = tx(Vector(pc["contact"]["at"])) - pc["pivot"]
            if pc["kind"] == "slide":
                f = sum(abs(pc["axis"][i]) * k[i] for i in range(3)) / max(1e-6, sum(abs(a) for a in pc["axis"]))
                pc["stowed"] *= f
                pc["deployed"] *= f
        for name, pc in self.pieces.items():
            o = by_name.get(name)
            if o is None:
                continue
            shift = B(pc["pivot"])
            for v in o.data.vertices:
                v.co -= shift
            o.data.update()
            par = pc["parent"]
            ppiv = self.pieces[par]["pivot"] if par in self.pieces else Vector((0, 0, 0))
            o.parent = by_name[par]
            o.matrix_parent_inverse = Matrix.Identity(4)
            o.location = B(pc["pivot"] - ppiv)
        return k

    def motion(self):
        """The motion note (written beside the .glb as <id>.motion.json), or None if nothing moves."""
        if not self.pieces:
            return None
        out = dict(self.top)
        out.setdefault("power_kw", 0.0)
        out.setdefault("load_kg", 0.0)
        pieces = []
        for pc in self.pieces.values():
            d = {kk: vv for kk, vv in pc.items() if kk != "pivot"}
            d["pivot"] = [round(c, 4) for c in pc["pivot"]]
            d["unit"] = {"hinge": "deg", "slide": "m", "spin": "deg", "belt": "m/s"}[pc["kind"]]
            if pc["kind"] != "belt":
                d["min"] = min(pc["stowed"], pc["deployed"], 0.0)
                d["max"] = max(pc["stowed"], pc["deployed"], 0.0)
                d["rest"] = 0.0
            if "swing" in pc:
                d["min"], d["max"] = -pc["swing"], pc["swing"]
            if "contact" in d:
                d["contact"] = {"at": [round(c, 4) for c in pc["contact"]["at"]], "radius": pc["contact"]["radius"]}
            for kk in ("stowed", "deployed", "min", "max"):
                if kk in d:
                    d[kk] = round(d[kk], 4)
            pieces.append(d)
        out["pieces"] = pieces
        return out

    def export(self, path):
        bpy.ops.object.select_all(action="DESELECT")
        for o in self.objects:
            o.select_set(True)
        bpy.context.view_layer.objects.active = self.objects[0]
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                                  export_apply=True, export_yup=True, export_materials="EXPORT",
                                  export_normals=True, export_animations=False, export_extras=False)

    def bounds(self):
        """The part's box in game coordinates after modifiers: (min, max)."""
        lo = Vector((1e9, 1e9, 1e9))
        hi = Vector((-1e9, -1e9, -1e9))
        dg = bpy.context.evaluated_depsgraph_get()
        for o in self.objects:
            ev = o.evaluated_get(dg)
            for v in ev.to_mesh().vertices:
                w = o.matrix_world @ v.co
                g = Vector((w.x, w.z, -w.y))
                lo = Vector(map(min, lo, g))
                hi = Vector(map(max, hi, g))
            ev.to_mesh_clear()
        return lo, hi


def _game_rot(rx, ry, rz):
    # Game y is Blender z; game z is Blender -y.
    return (Matrix.Rotation(ry, 4, "Z") @ Matrix.Rotation(rx, 4, "X") @ Matrix.Rotation(-rz, 4, "Y"))


def _axis_vec(f):
    s = -1.0 if f[0] == "-" else 1.0
    a = f[-1]
    return {"x": (s, 0.0, 0.0), "y": (0.0, s, 0.0), "z": (0.0, 0.0, s)}[a]


def _face_u(f):
    """The across direction on a face (for a viewer facing it)."""
    a = f[-1]
    if a == "z":
        return (1.0, 0.0, 0.0)
    if a == "x":
        return (0.0, 0.0, 1.0)
    return (1.0, 0.0, 0.0)


def _face_size(f, w, h, d):
    a = f[-1]
    if a == "z":
        return (w, h, d)
    if a == "x":
        return (d, h, w)
    return (w, d, h)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mat_cache.clear()
