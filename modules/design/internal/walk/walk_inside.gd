extends Node3D
## Walk-inside mode (beenster, 18 Nov): the open design built round you at full size, as
## near real as the design says (WalkBuild: deck plates, lined walls, hull plating, frames,
## doors, stairs, lamps, cable trays and pipes, the parts as units; a faint pale blue outline
## is the only tell that it's a hologram), to walk through with the mouse and keyboard and get
## a feel for using the ship. And to design in: everything you can change at the table you can
## change from in here, through the same editor, so the table and the walls follow.
##
##   WASD walk, Shift run, Space jump, mouse look, Esc back to the table.
##   Tab: the parts for the room you're in, the hull choices, undo and redo.
##   Aim at a part: click to pick it up and click again to put it down, R turns it, X removes it.
##   Aim at a wall: F puts a door in it, X on a door takes it out, the mouse wheel pushes or
##   pulls the wall of the room you're in by a grid step.
## A part in your hands shows green where it fits with clear access and its wire or pipe in
## reach, amber where something's wrong, with the reason in the corner.
##
## Built in a world of its own (a SubViewport with its own World3D, its own sky, sun and
## physics), drawn over the whole screen, so nothing of the station lights or touches it.

const T := preload("res://modules/ui/api/terminal_kit.gd")
const WalkBuild := preload("res://modules/design/internal/walk/walk_build.gd")

## Where the walk-inside world is built, from the design room, m.
## The sun lights only what faces space (WalkBuild.EXTERIOR): the inside is lit by its lamps.
const EXTERIOR := WalkBuild.EXTERIOR
const LAYER := WalkBuild.LAYER
const DOOR_H := WalkBuild.DOOR_H
## How far you can reach to design, m.
const REACH := 8.0
## A part's wire or pipe counts as in reach within this of its footprint, m.
const SERVICE_REACH := 1.5

## Walking speed, m/s.
@export var walk_speed := 3.0
## Running speed (Shift), m/s.
@export var run_speed := 6.0
## Jump speed, m/s.
@export var jump_speed := 4.2
## Gravity, m/s2.
@export var gravity := 9.8
## Mouse look, radians per pixel.
@export var look_speed := 0.003

var bus: DesignBus
var builder: WalkBuild
## The world of its own, and the root everything 3D is built under.
var viewport: SubViewport
var world: Node3D
var body: CharacterBody3D
var camera: Camera3D
var hud: CanvasLayer
## A part in your hands: {type, id ("" for a new one), rot}; empty when none.
var holding: Dictionary = {}
## Where the part in your hands would go now: {ok, room, x, z, why}.
var spot: Dictionary = {}
var _built: Node3D
var _ghost: Node3D
var _ghost_key := ""
var _title: Label
var _where: Label
var _aim_label: Label
var _palette: PanelContainer
var _palette_list: VBoxContainer
var _pitch := 0.0
var _dirty := false

## Built last time (tests): see WalkBuild.
var wall_pieces: Array[Dictionary]:
	get:
		return builder.wall_pieces
var ramps: PackedStringArray:
	get:
		return builder.ramps


func setup(design_bus: DesignBus, origin: Transform3D) -> void:
	bus = design_bus
	name = "WalkInside"
	builder = WalkBuild.new(bus.catalog)
	_add_view()
	_add_ground()
	_add_sun()
	_built = Node3D.new()
	_built.name = "Design"
	world.add_child(_built)
	builder.build(record(), _built)
	_add_player()
	_add_hud()
	bus.design_changed.connect(_on_changed)
	spawn()


func _exit_tree() -> void:
	if bus and bus.design_changed.is_connected(_on_changed):
		bus.design_changed.disconnect(_on_changed)


func record() -> DesignRecord:
	return bus.library.current if bus else null


## Puts you in the airlock (else the first room), facing the middle of the ship.
func spawn() -> void:
	var rec := record()
	var at := Vector3(0, 0.1, 0)
	var face := Vector3(0, 0, -1)
	if rec and not rec.rooms.is_empty():
		var start: Dictionary = {}
		for r in rec.rooms_on(rec.decks()[0]):
			var rt := bus.catalog.room(str(r.type))
			if rt and rt.is_airlock:
				start = r
				break
		if start.is_empty():
			start = rec.rooms_on(rec.decks()[0])[0]
		var c := Rect2(start.x, start.z, start.w, start.d).get_center()
		at = Vector3(c.x, int(start.deck) * rec.deck_height + 0.1, c.y)
		var mid := rec.bounds().get_center()
		face = Vector3(mid.x - c.x, 0, mid.y - c.y)
		if face.length() < 0.1:
			face = Vector3(0, 0, -1)
	body.position = at + Vector3(0, 0.9, 0)
	body.velocity = Vector3.ZERO
	body.rotation.y = atan2(-face.x, -face.z)
	_pitch = 0.0
	camera.rotation.x = 0.0


## The deck you're on and the room you're in ("" outside).
func where() -> Dictionary:
	var rec := record()
	if rec == null:
		return {"deck": 0, "room": ""}
	var feet := body.position.y - 0.9
	var deck := maxi(int(floor((feet + 0.5) / rec.deck_height)), 0)
	return {"deck": deck, "room": rec.room_at(deck, Vector2(body.position.x, body.position.z))}


func look(relative: Vector2) -> void:
	body.rotation.y -= relative.x * look_speed
	_pitch = clampf(_pitch - relative.y * look_speed, -1.45, 1.45)
	camera.rotation.x = _pitch


## What you're looking at within reach: {info (the "walk" meta), point, normal} in room
## space, or {} for nothing.
func aim() -> Dictionary:
	var from := camera.global_position
	var to := from - camera.global_basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, LAYER, [body.get_rid()])
	var hit := world.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not (hit.collider as Object).has_meta("walk"):
		return {}
	var inv := world.global_transform.affine_inverse()
	return {"info": (hit.collider as Object).get_meta("walk"), "point": inv * (hit.position as Vector3),
			"normal": (hit.normal as Vector3)}


# Designing from inside

func is_palette_open() -> bool:
	return _palette != null and _palette.visible


func toggle_palette() -> void:
	_palette.visible = not _palette.visible
	if _palette.visible:
		_fill_palette()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _palette.visible else Input.MOUSE_MODE_CAPTURED


## Takes a new part of `type` in your hands.
func take_new(type: String) -> void:
	holding = {"type": type, "id": "", "rot": 0}
	if is_palette_open():
		toggle_palette()


## Picks up a placed part to move it.
func pick_up(component_id: String) -> void:
	var c: Dictionary = record().components.get(component_id, {})
	if not c.is_empty():
		holding = {"type": str(c.type), "id": component_id, "rot": int(c.get("rot", 0))}


## Puts the part in your hands down where you're aiming. Returns true if it went down.
func put_down() -> bool:
	_update_spot()
	if holding.is_empty() or str(spot.get("room", "")) == "":
		return false
	var at := {"room": spot.room, "x": spot.x, "z": spot.z, "rot": int(holding.rot)}
	if str(holding.id) == "":
		var c := at.duplicate()
		c["type"] = holding.type
		bus.editor.do({"op": "add_component", "component": c})
	else:
		bus.editor.do({"op": "set_component", "id": holding.id, "fields": at})
	holding = {}
	return true


func turn() -> void:
	if not holding.is_empty():
		holding.rot = (int(holding.rot) + 1) % 4
		return
	var a := aim()
	if not a.is_empty() and str(a.info.kind) == "component":
		var c: Dictionary = record().components.get(str(a.info.id), {})
		if not c.is_empty():
			bus.editor.do({"op": "set_component", "id": c.id, "fields": {"rot": (int(c.get("rot", 0)) + 1) % 4}})


## Removes the part or door you're aiming at.
func remove_aimed() -> bool:
	var a := aim()
	if a.is_empty():
		return false
	match str(a.info.kind):
		"component":
			bus.editor.do({"op": "remove_component", "id": str(a.info.id)})
			return true
		"door":
			bus.editor.do({"op": "remove_door", "id": str(a.info.id)})
			return true
	return false


## A door in the wall you're aiming at, at the nearest half metre. Returns its id or "".
func door_here() -> String:
	var a := aim()
	if a.is_empty() or str(a.info.kind) != "wall":
		return ""
	var rec := record()
	var wa: Vector2 = a.info.a
	var wb: Vector2 = a.info.b
	var deck := int(a.info.deck)
	var dir := (wb - wa).normalized()
	var p := Vector2(a.point.x, a.point.z)
	var t := clampf(snappedf((p - wa).dot(dir), 0.5), WalkBuild.DOOR_W * 0.5, wa.distance_to(wb) - WalkBuild.DOOR_W * 0.5)
	if wa.distance_to(wb) < WalkBuild.DOOR_W:
		return ""
	var at := wa + dir * t
	for d: Dictionary in rec.doors.values():
		if int(d.deck) == deck and Vector2(float(d.x), float(d.z)).distance_to(at) < WalkBuild.DOOR_W + 0.2:
			return ""
	var n := Vector2(-dir.y, dir.x)
	var r1 := rec.room_at(deck, at + n * 0.1)
	var r2 := rec.room_at(deck, at - n * 0.1)
	if r1 == "":
		r1 = r2
		r2 = ""
	if r1 == "":
		return ""
	var before := rec.doors.keys()
	bus.editor.do({"op": "add_door", "door": {"a": r1, "b": r2, "deck": deck, "x": at.x, "z": at.y}})
	for id in rec.doors:
		if not id in before:
			return str(id)
	return ""


## Pushes (steps > 0) or pulls the aimed wall of the room you're in by grid steps. Returns
## true if the room changed.
func push_wall(steps: int) -> bool:
	var a := aim()
	var rid := str(where().room)
	if a.is_empty() or str(a.info.kind) != "wall" or rid == "":
		return false
	var rec := record()
	var r: Dictionary = rec.rooms[rid]
	var rt := bus.catalog.room(str(r.type))
	var min_size := rt.min_size if rt else Vector2(1, 1)
	var wa: Vector2 = a.info.a
	var wb: Vector2 = a.info.b
	var g := rec.grid * steps
	var f := {}
	const E := 0.02
	if absf(wa.x - wb.x) < E:
		if absf(wa.x - float(r.x)) < E:
			f = {"x": float(r.x) - g, "w": float(r.w) + g}
		elif absf(wa.x - float(r.x) - float(r.w)) < E:
			f = {"w": float(r.w) + g}
	elif absf(wa.y - wb.y) < E:
		if absf(wa.y - float(r.z)) < E:
			f = {"z": float(r.z) - g, "d": float(r.d) + g}
		elif absf(wa.y - float(r.z) - float(r.d)) < E:
			f = {"d": float(r.d) + g}
	if f.is_empty() or float(f.get("w", r.w)) < min_size.x or float(f.get("d", r.d)) < min_size.y:
		return false
	bus.editor.do({"op": "set_room", "id": rid, "fields": f})
	return true


## Where the part in your hands would go, and whether it's a good spot.
func _update_spot() -> void:
	spot = {}
	if holding.is_empty():
		return
	var rec := record()
	var pt := bus.catalog.part(str(holding.type))
	var a := aim()
	if a.is_empty() or pt == null:
		return
	var p: Vector3 = a.point
	var deck := maxi(int(floor((p.y + 0.5) / rec.deck_height)), 0)
	var step := rec.grid * 0.5
	var at := Vector2(snappedf(p.x, step), snappedf(p.z, step))
	var room := rec.room_at(deck, at)
	spot = {"room": room, "x": at.x, "z": at.y, "deck": deck, "ok": false, "why": ""}
	if room == "":
		spot.why = "Not in a room"
		return
	var c := {"x": at.x, "z": at.y, "rot": int(holding.rot), "room": room}
	var foot := DesignRules.footprint(c, pt)
	var rr := rec.room_rect(room)
	var rt := bus.catalog.room(str(rec.rooms[room].type))
	if not pt.rooms.is_empty() and not str(rec.rooms[room].type) in pt.rooms:
		spot.why = "Belongs in %s" % ", ".join(pt.rooms)
	elif not rr.encloses(foot.grow(-0.01)):
		spot.why = "Doesn't fit against the walls"
	elif _overlaps(foot, room):
		spot.why = "Something's in the way"
	elif not rr.encloses(DesignRules.access_zone(c, pt).grow(-0.01)) or _overlaps(DesignRules.access_zone(c, pt), room):
		spot.why = "No room to get at its front (R to turn it)"
	else:
		var missing: Array[String] = []
		for kind: String in DesignServices.KINDS:
			if DesignServices.is_user(pt, kind) and not _service_near(kind, deck, foot):
				missing.append(str(DesignServices.KINDS[kind].name).to_lower())
		if missing.is_empty():
			spot.ok = true
			spot.why = "Good spot" + (": its services are in reach" if _uses_services(pt) else "")
		else:
			spot.why = "No %s within %.1f m" % [" or ".join(missing), SERVICE_REACH]
	if rt == null:
		pass


func _uses_services(pt: DesignPartType) -> bool:
	for kind: String in DesignServices.KINDS:
		if DesignServices.is_user(pt, kind):
			return true
	return false


func _overlaps(r: Rect2, room: String) -> bool:
	var rec := record()
	for c: Dictionary in rec.components.values():
		if str(c.room) != room or str(c.id) == str(holding.get("id", "")):
			continue
		var pt := bus.catalog.part(str(c.type))
		if pt and DesignRules.footprint(c, pt).grow(-0.01).intersects(r):
			return true
	return false


func _service_near(kind: String, deck: int, foot: Rect2) -> bool:
	var rec := record()
	var zone := foot.grow(SERVICE_REACH)
	for w: Dictionary in rec.runs.values():
		if str(w.kind) != kind or int(w.deck) != deck:
			continue
		var pts := DesignServices.points(w)
		for i in pts.size() - 1:
			# Sample along the run.
			var n := maxi(int(pts[i].distance_to(pts[i + 1]) / 0.25), 1)
			for k in n + 1:
				if zone.has_point(pts[i].lerp(pts[i + 1], float(k) / n)):
					return true
	return false


# Input and frames

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if not is_palette_open() and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless"):
			look(event.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if is_palette_open():
			return  # the palette's buttons take it
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if DisplayServer.get_name() != "headless":
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				click()
			MOUSE_BUTTON_RIGHT:
				holding = {}
			MOUSE_BUTTON_WHEEL_UP:
				push_wall(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				push_wall(-1)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var handled := true
		match event.physical_keycode:
			KEY_TAB:
				toggle_palette()
			KEY_ESCAPE:
				if is_palette_open():
					toggle_palette()
				elif not holding.is_empty():
					holding = {}
				else:
					handled = false  # back to the table (DesignFurnishing)
			KEY_R:
				turn()
			KEY_X, KEY_DELETE:
				remove_aimed()
			KEY_F:
				door_here()
			KEY_Z:
				if event.ctrl_pressed:
					bus.editor.redo() if event.shift_pressed else bus.editor.undo()
				else:
					handled = false
			KEY_Y:
				if event.ctrl_pressed:
					bus.editor.redo()
				else:
					handled = false
			_:
				handled = false
		if handled:
			get_viewport().set_input_as_handled()


## A left click: put down what you hold, or pick up the part you aim at.
func click() -> void:
	if not holding.is_empty():
		put_down()
		return
	var a := aim()
	if not a.is_empty() and str(a.info.kind) == "component":
		pick_up(str(a.info.id))


func _physics_process(delta: float) -> void:
	if body == null:
		return
	var move := Vector2.ZERO if is_palette_open() else _axis(Keys.LEFT, Keys.RIGHT, Keys.FORWARD, Keys.BACK)
	var running := InputMap.has_action(Keys.RUN) and Input.is_action_pressed(Keys.RUN)
	var dir := (body.global_basis * Vector3(move.x, 0, move.y))
	dir.y = 0.0
	dir = dir.normalized() * minf(move.length(), 1.0)
	var speed := run_speed if running else walk_speed
	body.velocity.x = dir.x * speed
	body.velocity.z = dir.z * speed
	if body.is_on_floor():
		body.velocity.y = 0.0
		if InputMap.has_action(Keys.JUMP) and Input.is_action_just_pressed(Keys.JUMP) and not is_palette_open():
			body.velocity.y = jump_speed
	else:
		body.velocity.y -= gravity * delta
	body.move_and_slide()
	if body.position.y < -30.0:
		spawn()


func _process(delta: float) -> void:
	if _dirty:
		_dirty = false
		builder.build(record(), _built)
	var near: Array[Vector3] = [body.position]
	builder.update_doors(near, delta)
	_update_spot()
	_update_ghost()
	if _where == null:
		return
	var rec := record()
	var w := where()
	var room_name := "Outside"
	if str(w.room) != "":
		room_name = _room_name(rec.rooms[w.room])
	_title.text = "WALK-INSIDE   %s" % (rec.name.to_upper() if rec else "")
	_where.text = "DECK %d   %s" % [int(w.deck) + 1, room_name.to_upper()]
	_aim_label.text = _aim_text()


func _aim_text() -> String:
	if not holding.is_empty():
		var pt := bus.catalog.part(str(holding.type))
		return "%s   %s\nClick put down   R turn   Right-click or Esc drop" % [
				pt.display_name if pt else str(holding.type), str(spot.get("why", "Aim at a floor"))]
	var a := aim()
	if a.is_empty():
		return "Tab  parts and hull"
	var rec := record()
	match str(a.info.kind):
		"component":
			var c: Dictionary = rec.components.get(str(a.info.id), {})
			var pt := bus.catalog.part(str(c.get("type", "")))
			return "%s\nClick pick up   R turn   X remove" % (pt.display_name if pt else "Part")
		"door":
			return "Door\nX remove"
		"wall":
			var what := "Outer wall: %s, %s" % [
					DesignStructure.option("hull", str(rec.structure.hull)).name,
					DesignStructure.option("frame", str(rec.structure.frame)).name] if a.info.outer \
					else "Inner wall: %s" % DesignStructure.option("inner", str(rec.structure.inner)).name
			return "%s\nF door here   Wheel push or pull this wall" % what
		"floor":
			return "Deck plating\nTab  parts and hull"
	return ""


static func _axis(neg_x: String, pos_x: String, neg_y: String, pos_y: String) -> Vector2:
	for a in [neg_x, pos_x, neg_y, pos_y]:
		if not InputMap.has_action(a):
			return Vector2.ZERO
	return Input.get_vector(neg_x, pos_x, neg_y, pos_y)


func _on_changed() -> void:
	_dirty = true
	if is_palette_open():
		_fill_palette()


func _room_name(r: Dictionary) -> String:
	if str(r.get("name", "")) != "":
		return str(r.name)
	var rt := bus.catalog.room(str(r.type))
	return rt.display_name if rt else str(r.type)


## The part in your hands, where it would go: green for a good spot, amber if not.
func _update_ghost() -> void:
	var key := "" if holding.is_empty() else "%s/%d/%s" % [holding.type, int(holding.rot), spot.get("ok", false)]
	if key != _ghost_key:
		_ghost_key = key
		if _ghost:
			_ghost.queue_free()
			_ghost = null
		if key != "":
			_ghost = _make_ghost()
	if _ghost == null:
		return
	_ghost.visible = str(spot.get("room", "")) != ""
	if _ghost.visible:
		_ghost.position = Vector3(float(spot.x), int(spot.deck) * record().deck_height + 0.01, float(spot.z))


func _make_ghost() -> Node3D:
	var pt := bus.catalog.part(str(holding.type))
	var g := Node3D.new()
	g.name = "Ghost"
	world.add_child(g)
	if pt == null:
		return g
	var c := {"x": 0.0, "z": 0.0, "rot": int(holding.rot)}
	var f := DesignRules.footprint(c, pt)
	var h := minf(pt.size.y, record().deck_height - 0.5)
	var col := Color(0.35, 1.0, 0.5) if spot.get("ok", false) else Color(1.0, 0.7, 0.2)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(col.r, col.g, col.b, 0.3)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(f.size.x, h, f.size.y)
	mi.mesh = bm
	mi.material_override = m
	mi.position.y = h * 0.5
	g.add_child(mi)
	# Its access zone on the floor.
	var az := DesignRules.access_zone(c, pt)
	var zm := MeshInstance3D.new()
	var zb := BoxMesh.new()
	zb.size = Vector3(az.size.x, 0.01, az.size.y)
	zm.mesh = zb
	var m2 := m.duplicate() as StandardMaterial3D
	m2.albedo_color = Color(col.r, col.g, col.b, 0.15)
	zm.material_override = m2
	zm.position = Vector3(az.get_center().x, 0.01, az.get_center().y)
	g.add_child(zm)
	return g


# The world and you

func _add_ground() -> void:
	# Space under the ship is a floor you can't see, so you can step out of the airlock and
	# look back at her.
	var g := StaticBody3D.new()
	g.name = "Ground"
	g.collision_layer = LAYER
	g.collision_mask = 0
	var s := CollisionShape3D.new()
	var plane := WorldBoundaryShape3D.new()
	plane.plane = Plane(Vector3.UP, -0.12)
	s.shape = plane
	g.add_child(s)
	world.add_child(g)


## A far sun, so the hull can be seen from outside; the ship's own walls shade the inside.
func _add_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 1.6
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.shadow_enabled = true
	sun.rotation = Vector3(-0.7, 0.6, 0)
	sun.light_cull_mask = EXTERIOR
	sun.directional_shadow_max_distance = 120.0
	world.add_child(sun)


## The world of its own, filling the screen under the HUD.
func _add_view() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WalkView"
	layer.layer = 5
	add_child(layer)
	var box := SubViewportContainer.new()
	box.name = "View"
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(box)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.world_3d = World3D.new()
	viewport.handle_input_locally = false
	viewport.msaa_3d = get_viewport().msaa_3d if get_viewport() else Viewport.MSAA_DISABLED
	box.add_child(viewport)
	world = Node3D.new()
	world.name = "World"
	viewport.add_child(world)
	world.add_child(SpaceLook.world_environment())


func _add_player() -> void:
	body = CharacterBody3D.new()
	body.name = "Walker"
	body.collision_layer = 0
	body.collision_mask = LAYER
	body.floor_max_angle = deg_to_rad(50.0)
	body.floor_snap_length = 0.3
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.8
	shape.shape = cap
	body.add_child(shape)
	camera = Camera3D.new()
	camera.name = "WalkCamera"
	camera.fov = 75.0
	camera.near = 0.05
	camera.position.y = 0.75
	body.add_child(camera)
	world.add_child(body)
	# Your own light, so a corner is never pitch black.
	var lamp := OmniLight3D.new()
	lamp.light_energy = 0.35
	lamp.omni_range = 5.0
	lamp.position.y = 0.6
	body.add_child(lamp)


func _add_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "WalkHud"
	hud.layer = 6
	add_child(hud)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", T.box(Color(0.02, 0.05, 0.09, 0.8), T.CYAN, 1, 10.0))
	box.position = Vector2(20, 20)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(box)
	var col := VBoxContainer.new()
	box.add_child(col)
	_title = T.label("WALK-INSIDE", "display_bold", 22, T.CYAN)
	col.add_child(_title)
	_where = T.label("", "mono_bold", 18, T.TEXT)
	_where.name = "Where"
	col.add_child(_where)
	col.add_child(T.label("WASD walk   Shift run   Space jump   Mouse look   Tab design   Esc back to the table",
			"body", 15, T.DIM))
	_aim_label = T.label("", "body_medium", 18, T.TEXT)
	_aim_label.name = "Aim"
	_aim_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_aim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aim_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aim_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_aim_label.position.y -= 60
	_aim_label.add_theme_constant_override("outline_size", 6)
	_aim_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_aim_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_aim_label)
	var dot := ColorRect.new()
	dot.color = Color(0.7, 0.95, 1.0, 0.8)
	dot.size = Vector2(4, 4)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position -= Vector2(2, 2)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(dot)
	# Tab: the parts for the room you're in and the hull.
	_palette = PanelContainer.new()
	_palette.name = "Palette"
	_palette.add_theme_stylebox_override("panel", T.box(Color(0.02, 0.05, 0.09, 0.92), T.CYAN, 1, 12.0))
	_palette.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_palette.custom_minimum_size.x = 380
	_palette.offset_left = -400
	_palette.offset_right = -20
	_palette.offset_top = 20
	_palette.offset_bottom = -20
	_palette.visible = false
	hud.add_child(_palette)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_palette.add_child(scroll)
	_palette_list = VBoxContainer.new()
	_palette_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_palette_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_palette_list)


func _fill_palette() -> void:
	for c in _palette_list.get_children():
		_palette_list.remove_child(c)
		c.queue_free()
	var rec := record()
	var w := where()
	var room_type := str(rec.rooms[w.room].type) if str(w.room) != "" else ""
	_palette_list.add_child(T.label("PARTS FOR THIS ROOM" if room_type != "" else "PARTS", "display_bold", 18, T.ORANGE))
	for pt in (bus.catalog.parts_for(room_type) if room_type != "" else bus.catalog.parts.values()):
		var b := T.button("%s   %s" % [pt.display_name, T.money(pt.cost)], false, 16)
		b.name = "Part_" + pt.id
		b.pressed.connect(take_new.bind(pt.id))
		_palette_list.add_child(b)
	_palette_list.add_child(T.label("HULL", "display_bold", 18, T.ORANGE))
	for kind in ["frame", "spacing", "hull", "inner"]:
		var cur: Variant = rec.structure.get(kind)
		var text := "FRAME SPACING  %s m" % str(cur) if kind == "spacing" else "%s  %s" % [
				kind.to_upper(), str(DesignStructure.option(kind, str(cur)).get("name", cur)).to_upper()]
		var b := T.button(text, false, 16)
		b.name = "Structure_" + kind
		b.pressed.connect(func() -> void:
			bus.editor.do({"op": "set_meta", "fields": {"structure": {kind: DesignStructure.next_choice(kind, rec.structure.get(kind))}}}))
		_palette_list.add_child(b)
	var row := HBoxContainer.new()
	for spec in [["UNDO", func() -> void: bus.editor.undo()], ["REDO", func() -> void: bus.editor.redo()]]:
		var b := T.button(spec[0], false, 16)
		b.pressed.connect(spec[1])
		row.add_child(b)
	_palette_list.add_child(row)
	_palette_list.add_child(T.label("Aim at a part: click to move it, R to turn it, X to remove it.\n"
			+ "Aim at a wall: F for a door, the mouse wheel to push or pull it.", "body", 14, T.DIM))
