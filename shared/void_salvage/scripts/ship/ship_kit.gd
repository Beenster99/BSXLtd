class_name ShipKit
extends FrameTarget
## Builds a ship's hull and fittings into a RigidBody3D from PartShapes: every piece gets
## a mesh and a collision shape on the body. Pieces can be tagged so the ship can find them
## again (things you use, doors that slide, the lift).
##
## Not for salvage wrecks (those use ShipBuilder, with joints between parts). This is for
## ships that hold together: the players' base ship. A ship with a `model` (BaseShip.model,
## docs/SHIP_FRAME_PLAN.md 4.1) can also be built as parts and joints like a wreck: `part`,
## `join`, `tack`, and `begin_part`/`end_part` to fold a fitting's pieces into one part.

var body: RigidBody3D
## Tag -> Array of pieces: {mesh: MeshInstance3D, shape: CollisionShape3D, xform}
var tagged: Dictionary = {}
## Total volume of solid metal added, m^3 (the ship works out its mass from it).
var volume: float = 0.0
## Every piece's bounds and how far its look is pulled in from its true size. Pieces that
## touch get different pull-ins, so where two of them share a face (a wall meeting a floor)
## one face sits a hair behind the other instead of flickering (z-fighting).
var _bounds: Array[AABB] = []
var _insets: Array[int] = []
const INSET_STEP: float = 0.0007   # metres per step
const INSET_STEPS: int = 10
## Mesh pieces, collision shapes and lights added so far (the ship file's counts check
## against these).
var piece_count: int = 0
var shape_count: int = 0
var light_count: int = 0
## Optional: records the build for the ship file (docs/SHIP_FORMAT_PLAN.md). Null in play.
var recorder: ShipRecorder
## The build step the next records belong to ("hull", "cabin", "hold", a slot's id...).
## Designs set it at the top of each step; fittings and systems take the current one.
var group: String = ""
## `model` (FrameTarget): the ship's parts and joints (BaseShip.model); null on bodies built
## of pieces only. A FrameHull builds into the kit (`part`, `join`).
## The part `begin_part` opened (null = pieces stay pieces), and its name and kind until
## its first solid piece makes it.
var _open_part: PartData
var _open_name: String = ""
var _open_kind: PartData.Kind = PartData.Kind.COMPONENT
var _opened: bool = false
## Folding (docs/SHIP_FRAME_PLAN.md 4.4): with `fold` on (a frame build), every fitting
## (`begin_fitting`), system (`begin_system`) and unit a design opens itself (`begin_unit`: a
## door leaf, an engine) is built as one part instead of loose pieces: its first solid piece
## is the part, the rest ride on it. Tagged pieces inside keep their own look and shape under
## their tag (a seat's cushion, a panel's buttons); a unit opened inside another folds into
## the outer one. When a unit's part is made, `mount(part, unit)` (the design's) fastens it
## where it stands; a unit of looks only (no solid piece: a lamp, a name board) makes no part,
## and `mount(null, unit)` says what it rides on (unit["onto"]; its looks go on that part).
## Off (the default), these calls change nothing.
var fold: bool = false
var mount := Callable()
## The design's slot ids (a unit built under one of them as `group` is named "slot:<id>/...").
var slot_ids: Array = []
## Every unit folded into a part, or riding on one: {kind, name, key, group, path, part or
## onto}.
var units: Array[Dictionary] = []
## Part id -> the build step (`group`) it was made in.
var groups: Dictionary = {}
var _stack: Array[Dictionary] = []
## The unit `end_unit` last closed ({} if it closed none): its path names a fitting's record.
var last_unit: Dictionary = {}
## Looks added inside a unit before its first solid piece: [MeshInstance3D, xform, tag].
var _pending: Array = []
var _unit_paths: Dictionary = {}
## Steel's density for a part's mass from its volume, kg/m^3 (the parts' masses are for BSX's
## pricing; the ship flies at its tuned `ship_mass`).
const PART_DENSITY: float = 7800.0


func _init(target: RigidBody3D) -> void:
	body = target


## Adds `shape` at `xform` (ship space) with `mat` (plain paint goes on the ship surface
## shader, ShipSurface). Returns the piece {mesh, shape}.
func add(shape: PartShapes.PartShape, xform: Transform3D, mat: Material, tag: String = "",
		glass_mat: Material = null, solid: bool = true) -> Dictionary:
	if _opened and model:
		return _add_to_part(shape, xform, mat, tag, glass_mat, solid)
	piece_count += 1
	if recorder:
		recorder.on_piece(shape, xform, mat, tag, glass_mat, solid, group)
	var mi := MeshInstance3D.new()
	mi.mesh = shape.mesh
	mi.material_override = ShipSurface.of(mat)
	var vis := _inset(shape.mesh.get_aabb(), xform)
	mi.transform = xform * vis
	body.add_child(mi)
	if shape.glass and glass_mat:
		var g := MeshInstance3D.new()
		g.mesh = shape.glass
		g.material_override = glass_mat
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(g)
	var piece := {"mesh": mi, "xform": xform, "vis": vis}
	if solid:
		var col := CollisionShape3D.new()
		col.shape = shape.collision
		col.transform = xform
		body.add_child(col)
		piece["shape"] = col
		shape_count += 1
	volume += shape.volume
	if tag != "":
		(tagged.get_or_add(tag, []) as Array).append(piece)
	return piece


# --- Parts and joints (a ship with a model) --------------------------------------------

## Adds `shape` at `xform` (ship space) as one part named `part_name` of `kind`, with its
## look (`mat` on the ship surface) and collision; `fill` is how solid it is (its mass is
## its volume of steel times that). Tagged like a piece: `kit.tagged[tag]` gets {mesh,
## shape, xform, part}, and `BaseShip._place` moves the part with its joint heads. `path`
## names it (PartData.path, docs/SHIP_FRAME_PLAN.md 4.7).
func part(part_name: String, kind: PartData.Kind, shape: PartShapes.PartShape, xform: Transform3D,
		mat: Material, tag: String = "", fill: float = 1.0, glass_mat: Material = null, path: String = "") -> PartData:
	piece_count += 1
	shape_count += 1 + shape.extra_collision.size()
	var by := builder()
	if recorder:
		if by != "":
			# A builder's part (a frame member, a deck plate, a stud): the file writes the builder's
			# recipe and the part among the derived ones, not a piece.
			recorder.open("", {}, group)
			recorder.on_piece(shape, xform, mat, tag, glass_mat, true, group)
			recorder.close()
		else:
			# A design's own part (outside a unit: a ceiling panel) is a piece that is a part.
			var info := {} if not _stack.is_empty() else {"name": part_name, "kind": PartData.Kind.keys()[kind].to_lower(),
					"path": path, "fill": fill}
			recorder.on_piece(shape, xform, mat, tag, glass_mat, true, group, true, info)
	var made := model.add_part(part_name, kind, maxf(shape.volume * PART_DENSITY * fill, 0.1), 0.0, xform,
			shape.mesh, shape.collision, ShipSurface.of(mat))
	made.path = path
	groups[made.id] = group
	if recorder:
		recorder.on_part(made.id, shape, mat, glass_mat, by)
	if not shape.extra_collision.is_empty():
		model.add_extra_collision(made, shape.extra_collision)
	if shape.glass and glass_mat:
		_glass_on(model.part_visual(made.id), shape, glass_mat, Transform3D.IDENTITY)
	volume += shape.volume
	_tag_part(made, tag)
	return made


## Joins two parts with a joint of `kind` at `at`, facing `normal` (ship space); its head
## hangs on `a`. Welds: `seam_up` and `seam_size` as in ConnectionData. `path` names it.
func join(a: PartData, b: PartData, kind: ConnectionData.Kind, at: Vector3, normal: Vector3,
		seam_up := Vector3.ZERO, seam_size := Vector2.ZERO, path: String = "") -> ConnectionData:
	var made := model.connect_parts(a, b, kind, at, normal, seam_up, seam_size)
	if made:
		made.path = path
	return made


## FrameTarget: a loom span's part on the ship (wiring, in the loom's own look, casting no
## shadow as on the wrecks), in the current group. Counted in the ship file but not written:
## the file writes the services from F7.
func _wire_part(part_name: String, kg: float, xform: Transform3D, mesh: Mesh, shape: Shape3D) -> PartData:
	piece_count += 1
	shape_count += 1
	if recorder:
		# Counted, not recorded (no shape recipe yet: vsship 2.0 writes the services).
		recorder.open("", {}, group)
		recorder.on_piece(_shape(mesh, shape, 0.0), xform, WiringLoom.material(), "", null, true, group)
		recorder.close()
	var made := model.add_part(part_name, PartData.Kind.CONDUIT, kg, 0.0, xform, mesh, shape, WiringLoom.material())
	groups[made.id] = group
	if recorder:
		# Its look is the loom's own (WiringLoom): the file names it by its length (the services
		# block says how the loom runs).
		var span := PartShapes.PartShape.new()
		span.recipe = {"shape": "loom_span", "args": [snappedf(mesh.get_aabb().size.y, 0.0001)]}
		recorder.on_part(made.id, span, WiringLoom.material(), null, builder())
	var look := model.part_visual(made.id)
	if look:
		look.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return made


## FrameTarget: a pipe part on the ship (PipeRouter's spans, elbows and unions) in the ship's
## paint, in the current group. Counted in the ship file but not written, like a loom span:
## the file writes the services from F7.
func pipe_part(part_name: String, shape: PartShapes.PartShape, xform: Transform3D, mat: Material,
		path: String = "") -> PartData:
	piece_count += 1
	shape_count += 1 + shape.extra_collision.size()
	if recorder:
		recorder.open("", {}, group)
		recorder.on_piece(shape, xform, mat, "", null, true, group)
		recorder.close()
	var made := model.add_part(part_name, PartData.Kind.CONDUIT, maxf(shape.volume * PART_DENSITY, 0.05), 0.0, xform,
			shape.mesh, shape.collision, ShipSurface.of(mat))
	made.path = path
	groups[made.id] = group
	if recorder:
		recorder.on_part(made.id, shape, mat, null, builder())
	if not shape.extra_collision.is_empty():
		model.add_extra_collision(made, shape.extra_collision)
	volume += shape.volume
	return made


## Tacks `fitting` to the plate it stands on (`onto`) with a spot weld at each of `points`
## (ship space, on the plate's face), the puddles facing `normal`. Returns the welds; with a
## `path`, the k-th is named "<path>/spot/<k>".
func tack(fitting: PartData, onto: PartData, points: Array, normal := Vector3.UP, path: String = "") -> Array[ConnectionData]:
	var made: Array[ConnectionData] = []
	for p: Vector3 in points:
		var c := model.connect_parts(fitting, onto, ConnectionData.Kind.SPOT, p, normal)
		if c and path != "":
			c.path = "%s/spot/%d" % [path, made.size()]
		made.append(c)
	return made


## Every piece added until `end_part` folds into one part named `part_name` (a fitting:
## the first solid piece's shape is its collision, the others' shapes are added to it and
## their looks ride on it). Pieces inside one part may touch and overlap; the gap rule is
## between parts. Without a model the pieces stay pieces, as before.
func begin_part(part_name: String, kind: PartData.Kind = PartData.Kind.COMPONENT) -> void:
	_opened = true
	_open_part = null
	_open_name = part_name
	_open_kind = kind


## Closes the part `begin_part` opened and returns it (null if no solid piece made one).
func end_part() -> PartData:
	var made := _open_part
	_opened = false
	_open_part = null
	return made


func _add_to_part(shape: PartShapes.PartShape, xform: Transform3D, mat: Material, tag: String,
		glass_mat: Material, solid: bool) -> Dictionary:
	if not _stack.is_empty() and tag != "":
		(_owner()["tags"] as Array).append(tag)
	if _open_part == null:
		if not solid:
			# A look before any solid piece: held until one makes the part (or put on the body
			# as a piece if none does).
			piece_count += 1
			if recorder:
				recorder.on_piece(shape, xform, mat, tag, glass_mat, solid, group)
			var held := MeshInstance3D.new()
			held.mesh = shape.mesh
			held.material_override = ShipSurface.of(mat)
			if shape.glass and glass_mat:
				_glass_on(held, shape, glass_mat, Transform3D.IDENTITY)
			var entry := {"mesh": held, "xform": xform, "vis": Transform3D.IDENTITY}
			_pending.append([held, xform, tag, entry, shape.volume])
			if tag != "":
				(tagged.get_or_add(tag, []) as Array).append(entry)
			return entry
		_open_part = part(_open_name, _open_kind, shape, xform, mat, tag, 1.0, glass_mat)
		for held: Array in _pending:
			var mi := held[0] as MeshInstance3D
			mi.transform = _open_part.local_transform.affine_inverse() * (held[1] as Transform3D)
			model.attach_to_part(_open_part, mi)
			(held[3] as Dictionary)["piece_of"] = _open_part.id
			volume += float(held[4])
		_pending.clear()
		return {"mesh": model.part_visual(_open_part.id), "xform": xform, "part": _open_part.id,
				"shape": model.part_collider(_open_part.id)}
	piece_count += 1
	if recorder:
		recorder.on_piece(shape, xform, mat, tag, glass_mat, solid, group)
	var offset := _open_part.local_transform.affine_inverse() * xform
	var mi := MeshInstance3D.new()
	mi.mesh = shape.mesh
	mi.material_override = ShipSurface.of(mat)
	mi.transform = offset
	model.attach_to_part(_open_part, mi)
	if shape.glass and glass_mat:
		_glass_on(mi, shape, glass_mat, Transform3D.IDENTITY)
	var own: CollisionShape3D = null
	if solid:
		var shapes: Array[Shape3D] = [shape.collision]
		shapes.append_array(shape.extra_collision)
		model.add_extra_collision(_open_part, shapes, offset)
		shape_count += shapes.size()
		var extras := model.extra_colliders(_open_part.id)
		own = extras[extras.size() - shapes.size()]
	_open_part.mass += shape.volume * PART_DENSITY
	volume += shape.volume
	var entry := {"mesh": mi, "xform": xform, "vis": Transform3D.IDENTITY, "piece_of": _open_part.id}
	if own:
		entry["shape"] = own
	# A piece under the part's own tag is the part (tagged once); under another tag, itself.
	if tag != "" and not _part_tagged(_open_part, tag):
		(tagged.get_or_add(tag, []) as Array).append(entry)
	return entry


func _part_tagged(made: PartData, tag: String) -> bool:
	for piece: Dictionary in tagged.get(tag, []):
		if piece.get("part", -1) == made.id:
			return true
	return false


## Opens a unit (see `fold`): every piece until the matching `end_unit` folds into one part
## named `unit_name`, of `kind` "fitting", "system", "leaf" (a system's moving part: a door
## leaf, a hatch's) or "slot"; `key`, the thing it belongs to, comes first in its path
## ("system:door_bulkhead/leaf"). A fitting's or system's `frame` and `args` ride in the unit
## (its `ports`, ShipParts.ports, are in that frame). A unit opened inside another folds into
## it, except a leaf: a system's moving part (the lift's platform) is a part of its own, and the
## outer unit's part goes on after it.
## Does nothing unless `fold` is on.
func begin_unit(kind: String, unit_name: String, key: String = "", frame: Variant = null, args: Array = []) -> void:
	if not fold or model == null:
		return
	var unit := {"kind": kind, "name": unit_name, "key": key, "group": group, "tags": [], "frame": frame, "args": args}
	# Opened outside a fitting's or system's record (a door's leaf, an engine): the ship file
	# marks its pieces with the unit they fold into.
	if recorder and not recorder.is_open() and (_stack.is_empty() or kind == "leaf"):
		unit["mark"] = recorder.begin_unit(kind, unit_name, key)
	if not _stack.is_empty() and kind == "leaf":
		unit["outer"] = [_open_part, _open_name, _open_kind, _opened, _pending]
		_pending = []
		_stack.append(unit)
		begin_part(unit_name)
		return
	_stack.append(unit)
	if _stack.size() == 1:
		begin_part(unit_name)


## The unit whose part the pieces fold into now: the innermost leaf of its own, else the outermost.
func _owner() -> Dictionary:
	for i in range(_stack.size() - 1, -1, -1):
		if _stack[i].has("outer"):
			return _stack[i]
	return _stack[0]


## Closes the unit `begin_unit` opened: names its part, notes its group and has the design
## `mount` it. Returns the part (null if none was made, or folding is off, or it was nested).
func end_unit() -> PartData:
	last_unit = {}
	if not fold or model == null or _stack.is_empty():
		return null
	var unit: Dictionary = _stack.pop_back()
	last_unit = unit
	if unit.has("outer"):
		var leaf := _finish(unit)
		if recorder and unit.has("mark"):
			recorder.end_unit(unit["mark"], unit.get("path", ""))
		var outer: Array = unit["outer"]
		_open_part = outer[0]
		_open_name = outer[1]
		_open_kind = outer[2]
		_opened = outer[3]
		_pending = outer[4]
		return leaf
	if not _stack.is_empty():
		return null
	var made := _finish(unit)
	if recorder and unit.has("mark"):
		recorder.end_unit(unit["mark"], unit.get("path", ""))
	return made


## Ends the part a unit folded into, names it and has the design `mount` it (or what it rides on).
func _finish(unit: Dictionary) -> PartData:
	var made := end_part()
	if made == null and not _pending.is_empty() and mount.is_valid():
		# Looks only (a lamp, a name board, a screen): they ride on the part the design finds
		# them fixed to (`mount` with no part sets unit["onto"]).
		var box := AABB()
		for i in _pending.size():
			var held: Array = _pending[i]
			var b := (held[1] as Transform3D) * (held[0] as MeshInstance3D).mesh.get_aabb()
			box = b if i == 0 else box.merge(b)
		unit["box"] = box
		unit["path"] = _unit_path(unit)
		mount.call(null, unit)
		var onto: PartData = unit.get("onto")
		if onto:
			for held: Array in _pending:
				var mi := held[0] as MeshInstance3D
				mi.transform = onto.local_transform.affine_inverse() * (held[1] as Transform3D)
				model.attach_to_part(onto, mi)
				(held[3] as Dictionary)["piece_of"] = onto.id
				volume += float(held[4])
			_pending.clear()
			units.append(unit)
	for held: Array in _pending:
		# No solid piece came and nothing holds them: pieces on the body after all.
		var mi := held[0] as MeshInstance3D
		mi.transform = held[1]
		body.add_child(mi)
		volume += float(held[4])
	_pending.clear()
	if made == null:
		return null
	made.path = _unit_path(unit)
	unit["path"] = made.path
	unit["part"] = made
	units.append(unit)
	if mount.is_valid():
		var phase_was := phase
		phase = "fitting"
		mount.call(made, unit)
		phase = phase_was
	return made


## A unit's path (docs/SHIP_FRAME_PLAN.md 4.7): "fitting:<its tag or name>",
## "system:<name>" ("system:<key>/<name>" for a panel working a key: a door's), under a
## slot "slot:<id>/<name>"; "/1", "/2" for the second and third of the same name.
func _unit_path(unit: Dictionary) -> String:
	var tags: Array = unit["tags"]
	var unit_name: String = unit["name"]
	var key: String = unit["key"]
	var base: String
	match unit["kind"]:
		"fitting":
			base = String(tags[0]) if not tags.is_empty() else unit_name
		_:
			base = "%s/%s" % [key, unit_name] if key != "" else unit_name
	var path := "slot:%s/%s" % [unit["group"], base] if slot_ids.has(unit["group"]) else "%s:%s" % [
			"fitting" if unit["kind"] == "fitting" else "system", base]
	var n: int = _unit_paths.get(path, 0)
	_unit_paths[path] = n + 1
	return path if n == 0 else "%s/%d" % [path, n]


func _glass_on(mi: Node3D, shape: PartShapes.PartShape, glass_mat: Material, at: Transform3D) -> void:
	var g := MeshInstance3D.new()
	g.mesh = shape.glass
	g.material_override = glass_mat
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.transform = at
	mi.add_child(g)


## A tagged part goes in `tagged` once, as the part (its xform is the part's as built).
func _tag_part(made: PartData, tag: String) -> void:
	if tag == "":
		return
	var list := tagged.get_or_add(tag, []) as Array
	for piece: Dictionary in list:
		if piece.get("part", -1) == made.id:
			return
	list.append({"mesh": model.part_visual(made.id), "xform": made.local_transform, "vis": Transform3D.IDENTITY,
			"part": made.id, "shape": model.part_collider(made.id)})


## Collision only, no look (a smooth ramp under steps so feet never catch on an edge).
## Adds nothing to the volume.
func collider(shape: PartShapes.PartShape, xform: Transform3D) -> CollisionShape3D:
	shape_count += 1
	if recorder:
		var empty := PartShapes.PartShape.new()
		empty.recipe = shape.recipe
		empty.mesh = shape.mesh
		recorder.on_piece(empty, xform, null, "", null, true, group, false)
	var col := CollisionShape3D.new()
	col.shape = shape.collision
	col.transform = xform
	body.add_child(col)
	return col


## Opens a fitting record (a ShipParts function: its name, frame and the arguments after
## the frame); the pieces it adds fold into it. Close it with `end_fitting`.
func begin_fitting(fitting_name: String, frame: Variant, args: Array) -> void:
	if recorder:
		var record := {"fitting": fitting_name, "args": args}
		if frame != null:
			record["frame"] = frame
		recorder.open("fittings", record, group)
	begin_unit("fitting", fitting_name, "", frame, args)


## Closes the fitting `begin_fitting` opened with what it returned ({name, box, label?}),
## and returns that.
func end_fitting(made: Dictionary) -> Dictionary:
	end_unit()
	if recorder:
		var extra := {"box": made.get("box", AABB())}
		if last_unit.get("path", "") != "":
			extra["path"] = last_unit["path"]
		if made.has("label"):
			extra["_label"] = made["label"]
		recorder.close(extra)
	return made


## Opens a system record (one of the ship's own builders: the bowsers, a door panel...).
## `frame` may be null; `key` is the state key it works, if any. Close with `end_system`.
func begin_system(system_name: String, frame: Variant = null, args: Array = [], key: String = "") -> void:
	if recorder:
		var record := {"system": system_name}
		if key != "":
			record["key"] = key
		if frame != null:
			record["frame"] = frame
		if not args.is_empty():
			record["args"] = args
		recorder.open("systems", record, group)
	# A door's panel is named by the door it works ("system:door_bulkhead/door_panel").
	begin_unit("system", system_name, key if system_name.ends_with("_panel") else "", frame, args)


func end_system() -> void:
	end_unit()
	if recorder:
		recorder.close({"path": last_unit["path"]} if last_unit.get("path", "") != "" else {})


## Pieces added until `end_quiet` are counted but not recorded (what the layout rebuilds:
## floodlights, beacons).
func begin_quiet() -> void:
	if recorder:
		recorder.open("", {}, group)


func end_quiet() -> void:
	if recorder:
		recorder.close()


## Shrinks a piece's look very slightly (never its collision), by an amount no piece it
## touches already uses. Returns the scale to apply to its mesh.
func _inset(local_box: AABB, xform: Transform3D) -> Transform3D:
	var box := xform * local_box
	var grown := box.grow(0.01)
	var used := {}
	for i in _bounds.size():
		if grown.intersects(_bounds[i]):
			used[_insets[i]] = true
	var step := 1
	while used.has(step) and step < INSET_STEPS:
		step += 1
	_bounds.append(box)
	_insets.append(step)
	var size := local_box.size
	var inset := INSET_STEP * float(step)
	# Thin pieces (screens, stripes) give up at most a fifth of their thickness.
	var s := Vector3.ONE
	for axis in 3:
		var d := maxf(size[axis], 0.001)
		s[axis] = 1.0 - 2.0 * minf(inset, d * 0.1) / d
	var centre := local_box.get_center()
	# Scale about the piece's own centre.
	return Transform3D(Basis.from_scale(s), centre - centre * s)


## A plain box from corner `a` to corner `b` (ship space).
func block(a: Vector3, b: Vector3, mat: Material, tag: String = "") -> Dictionary:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	if recorder:
		var record := {"block": {"a": lo, "b": hi}, "mat": mat}
		if tag != "":
			record["tag"] = tag
		recorder.open("walls", record, group)
	var piece := add(PartShapes.box(hi - lo), Transform3D(Basis(), (lo + hi) * 0.5), mat, tag)
	if recorder:
		recorder.close()
	return piece


## A flat wall in a plane, as boxes around rectangular `holes` (doorways, windows). The
## wall spans `u0..u1` by `v0..v1` in the plane's own axes, `thickness` thick, centred on
## `at` along its normal. `axis` picks the plane: "x" = wall facing X (u = z, v = y),
## "z" = facing Z (u = x, v = y), "y" = floor or ceiling (u = x, v = z).
## Each hole is Rect2(u, v, width, height).
func wall(axis: String, at: float, u0: float, u1: float, v0: float, v1: float,
		thickness: float, holes: Array, mat: Material, tag: String = "") -> void:
	if recorder:
		var record := {"wall": axis, "at": at, "u": [u0, u1], "v": [v0, v1], "thickness": thickness, "holes": holes,
				"mat": mat}
		if tag != "":
			record["tag"] = tag
		recorder.open("walls", record, group)
	_wall_strips(axis, at, u0, u1, v0, v1, thickness, holes, mat, tag)
	if recorder:
		recorder.close()


func _wall_strips(axis: String, at: float, u0: float, u1: float, v0: float, v1: float,
		thickness: float, holes: Array, mat: Material, tag: String) -> void:
	# Split the wall into strips between holes: columns along u, then rows inside each.
	var cuts: Array[float] = [u0, u1]
	for h: Rect2 in holes:
		cuts.append(clampf(h.position.x, u0, u1))
		cuts.append(clampf(h.position.x + h.size.x, u0, u1))
	cuts.sort()
	for i in cuts.size() - 1:
		var a := cuts[i]
		var b := cuts[i + 1]
		if b - a < 0.005:
			continue
		var mid := (a + b) * 0.5
		var spans: Array = [[v0, v1]]
		for h: Rect2 in holes:
			if mid > h.position.x and mid < h.position.x + h.size.x:
				var next: Array = []
				for s: Array in spans:
					var lo: float = s[0]
					var hi: float = s[1]
					var hlo := h.position.y
					var hhi := h.position.y + h.size.y
					if hhi <= lo or hlo >= hi:
						next.append(s)
						continue
					if hlo > lo:
						next.append([lo, hlo])
					if hhi < hi:
						next.append([hhi, hi])
				spans = next
		for s: Array in spans:
			if (s[1] as float) - (s[0] as float) < 0.005:
				continue
			_wall_piece(axis, at, a, b, s[0], s[1], thickness, mat, tag)


func _wall_piece(axis: String, at: float, a: float, b: float, lo: float, hi: float,
		t: float, mat: Material, tag: String) -> void:
	var h := t * 0.5
	match axis:
		"x":
			block(Vector3(at - h, lo, a), Vector3(at + h, hi, b), mat, tag)
		"z":
			block(Vector3(a, lo, at - h), Vector3(b, hi, at + h), mat, tag)
		_:
			block(Vector3(a, at - h, lo), Vector3(b, at + h, hi), mat, tag)


## A light hanging at `at` (ship space).
func light(at: Vector3, color: Color, energy: float, reach: float, shadows: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.shadow_enabled = shadows
	l.position = at
	body.add_child(l)
	light_count += 1
	if recorder:
		recorder.on_light(at, color, energy, reach, shadows, group)
	return l


static func paint(color: Color, metallic: float = 0.4, roughness: float = 0.55, finish: String = "") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	if finish != "":
		m.set_meta("finish", finish)   # the SurfaceFinish it shows (ShipSurface.finish_for)
	return m


static func glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.03, 0.03, 0.03)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func glass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.65, 0.85, 0.28)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.4
	m.roughness = 0.04
	return m


## A monospace system font so readout columns line up (labels, screens, the HUD); falls back
## to the default font.
static var _font: SystemFont


## One shared monospace font (a fresh one per call would reload its glyphs every time,
## and text drawn each frame would show as blocks).
static func mono_font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Consolas", "Menlo", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
	return _font
