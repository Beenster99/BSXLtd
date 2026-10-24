class_name TradesUnitWork
extends Node3D
## A component on an upgrade rig, opened up for its add-ons (Component Upgrades U1, beenster
## 2026-10-24: "Lets start up stage 1"; the plan's loop: mount the unit, open it, fit the
## add-ons at its internal points, close it, test, certify). Behind the flag
## "trades.unit_mounts". Ship and Bay builds the rig and puts the unit on it (rig_mount,
## rig_changed); this is what Tools does inside it:
##
##   cover    4 M10 bolts and 2 tack welds hold the top cover shut. Take them all out and
##            the cover swings open; put one back and it shuts.
##   seats    with the cover open, three seats inside (at most 3 add-ons a unit, Gamifying):
##            the quantum core (6 M12 bolts), the field emitter horns (2 seam welds) and the
##            control board (a power and a data plug). F on an empty seat puts its add-on in;
##            F on one with every joint out lifts it back off.
##
## The joints are FastenerPoints like the ship's, worked by the same station
## (TradesShipJoints), which keeps their state (`practice`) and shares it with the crew; the
## seats' "fitted" flags ride in the same dictionary ("<slot>/fitted"). Quality hears about
## every joint and change through TradesBus (unit_joint_changed, unit_changed).
## Unit space: metres, the origin on the rig's deck under the unit's middle, +X along the
## coil, +Y up, +Z toward the worker.

## The seats in fitting order; a unit of tier n has the first n (all three from tier 3).
const SEATS := ["core", "emitter", "board"]
## What goes on each seat, as the player reads it.
const ADDON_NAMES := {"core": "Quantum core", "emitter": "Field emitter horns", "board": "Control board"}
## The housing (m): the coil's case, its walls and floor; low, so you see in over the front
## wall standing at the rig.
const HOUSING := Vector3(1.2, 0.32, 0.7)
const WALL_M := 0.03
## Each mount: [kind, centre on its face (unit space), the box the part fills].
const MOUNTS := {
	"cover": ["cover", Vector3(0, 0.32, 0), Vector3(1.2, 0.02, 0.7)],
	"core": ["core", Vector3(-0.3, 0.05, 0), Vector3(0.34, 0.24, 0.34)],
	"emitter": ["emitter", Vector3(0.12, 0.03, 0), Vector3(0.3, 0.18, 0.14)],
	"board": ["board", Vector3(0.42, 0.03, 0.05), Vector3(0.2, 0.03, 0.16)],
}
## How near the aim has to pass a seat's middle for F to fit or lift its add-on (m).
const SEAT_PICK_M := 0.25
## How far the cover swings open (radians, about its back edge).
const OPEN_ANGLE := 1.75
const RED := Color(0.85, 0.2, 0.15)
const AMBER := Color(1.0, 0.62, 0.15)
const GREEN := Color(0.3, 1.0, 0.45)

## The rig this unit sits on ("rig_emitter") and the unit's own id ("attractor_coil_1").
var rig_id := ""
var unit_id := ""
var seats: Array[String] = []
## Every joint in unit space: the cover's, then each seat's.
var joints: Array[FastenerPoint] = []
## joint_id -> true while made (the station's `practice`); "<slot>/fitted" for the seats.
var state: Dictionary
## Where the player points (world) and how near it a ring must be to show (m); INF shows all.
var focus := Vector3.ZERO
var focus_radius := INF

var _markers := {}
var _cover: Node3D
var _addons := {}
var _ghosts := {}
var _ring_on: StandardMaterial3D
var _ring_off: StandardMaterial3D
var _head: StandardMaterial3D
var _cover_angle := 0.0


func _init(rig: String = "rig_emitter", unit: String = "", tier: int = 3) -> void:
	name = "UnitWork"
	top_level = true
	rig_id = rig
	unit_id = unit
	for i in clampi(tier, 1, SEATS.size()):
		seats.append(SEATS[i])
	_lay_out()


## The slot a mount's joints belong to: "unit_<rig>_<mount>".
func slot_of(mount: String) -> String:
	return "unit_%s_%s" % [rig_id, mount]


## The mount ("cover", "core"...) a joint id belongs to, or "" when it isn't this unit's.
func mount_of(joint_id: String) -> String:
	var prefix := "unit_%s_" % rig_id
	var slot := FastenerPoint.slot_of(joint_id)
	return slot.trim_prefix(prefix) if slot.begins_with(prefix) else ""


## The state every joint and seat starts in: a closed unit straight off the rig, nothing in.
func starting_state() -> Dictionary:
	var out := {}
	for f in joints:
		out[f.joint_id] = mount_of(f.joint_id) == "cover"
	for seat in seats:
		out[slot_of(seat) + "/fitted"] = false
	return out


func mount_joints(mount: String) -> Array[FastenerPoint]:
	var slot := slot_of(mount)
	return joints.filter(func(f: FastenerPoint) -> bool: return FastenerPoint.slot_of(f.joint_id) == slot)


func made(joint_id: String) -> bool:
	return bool(state.get(joint_id, false)) if state != null else false


## The cover is open once every one of its bolts and tack welds is out.
func is_open() -> bool:
	return not mount_joints("cover").any(func(f: FastenerPoint) -> bool: return made(f.joint_id))


func is_fitted(seat: String) -> bool:
	return made(slot_of(seat) + "/fitted")


func fitted() -> Array[String]:
	return seats.filter(func(s: String) -> bool: return is_fitted(s))


## The joints a player can work now: the cover's always; inside, only with the cover open
## and only on an add-on that's in.
func workable() -> Array[FastenerPoint]:
	var out := mount_joints("cover")
	if is_open():
		for seat in fitted():
			out.append_array(mount_joints(seat))
	return out


## The seat F would act on, aiming from `origin` along `dir` (world): the one the aim passes
## nearest, open cover only.
func seat_near(origin: Vector3, dir: Vector3) -> String:
	if not is_open():
		return ""
	var best := ""
	var best_d := SEAT_PICK_M
	for seat in seats:
		var c := global_transform * seat_centre(seat)
		var along := (c - origin).dot(dir)
		if along <= 0.0:
			continue
		var d := (origin + dir * along).distance_to(c)
		if d < best_d:
			best = seat
			best_d = d
	return best


func seat_centre(seat: String) -> Vector3:
	var m: Array = MOUNTS[seat]
	return (m[1] as Vector3) + Vector3(0, (m[2] as Vector3).y * 0.5, 0)


## Whether an add-on can come off: in, with every one of its joints out.
func can_lift(seat: String) -> bool:
	return is_fitted(seat) and not mount_joints(seat).any(func(f: FastenerPoint) -> bool: return made(f.joint_id))


## Quality's view (TradesBus.unit_state): open, what's in, and each joint's quality (or -1).
func report(qualities: Dictionary) -> Dictionary:
	var js := {}
	for f in joints:
		js[f.joint_id] = float(qualities.get(f.joint_id, 1.0)) if made(f.joint_id) else -1.0
	return {"unit": unit_id, "open": is_open(), "fitted": fitted(), "seats": seats.duplicate(), "joints": js}


func _lay_out() -> void:
	var mounts: Array[String] = ["cover"]
	mounts.append_array(seats)
	for mount in mounts:
		var m: Array = MOUNTS[mount]
		joints.append_array(TradesMountPatterns.pattern(m[0], slot_of(mount), Transform3D(Basis(), m[1]), m[2]))


# --- The look ---------------------------------------------------------------------------------

func _ready() -> void:
	_ring_on = TradesLook.glow(GREEN, 0.9)
	_ring_off = TradesLook.glow(AMBER, 0.9)
	_head = TradesLook.metal(Color(0.62, 0.64, 0.66), 0.9, 0.35)
	_build_housing()
	for seat in seats:
		_ghosts[seat] = _build_ghost(seat)
		_addons[seat] = _build_addon(seat)
	for f in joints:
		var m := _marker(f)
		_markers[f.joint_id] = m
		# On the rim and the seats, not the lid: they stay where the aim finds them.
		add_child(m)
	_show(0.0)


func _process(delta: float) -> void:
	_show(delta)


## As things stand: the cover shut or swung open, each add-on in or its seat's outline, and
## every joint's ring (green made, amber not) with its head while it's made.
func _show(delta: float) -> void:
	var want := OPEN_ANGLE if is_open() else 0.0
	_cover_angle = want if delta <= 0.0 else move_toward(_cover_angle, want, delta * 3.0)
	_cover.rotation = Vector3(-_cover_angle, 0, 0)
	var open := is_open()
	for seat in seats:
		(_addons[seat] as Node3D).visible = is_fitted(seat)
		(_ghosts[seat] as Node3D).visible = open and not is_fitted(seat)
	var inner_ok := open
	for f in joints:
		var m := _markers.get(f.joint_id) as MeshInstance3D
		var mount := mount_of(f.joint_id)
		var show := mount == "cover" or (inner_ok and is_fitted(mount))
		m.visible = show
		if not show:
			continue
		var on := made(f.joint_id)
		m.material_override = _ring_on if on else _ring_off
		(m.get_child(0) as Node3D).visible = on
		m.transparency = 0.0 if focus_radius == INF or m.global_position.distance_to(focus) <= focus_radius else 1.0


func _build_housing() -> void:
	var shell := TradesLook.metal(Color(0.2, 0.36, 0.5), 0.5, 0.45)
	var dark := TradesLook.metal(TradesLook.DARK, 0.6, 0.5)
	var coil := TradesLook.metal(Color(0.78, 0.45, 0.2), 0.85, 0.3)
	var h := HOUSING
	_box(Vector3(h.x, WALL_M, h.z), Vector3(0, WALL_M * 0.5, 0), dark)
	for z: float in [-1.0, 1.0]:
		_box(Vector3(h.x, h.y, WALL_M), Vector3(0, h.y * 0.5, z * (h.z - WALL_M) * 0.5), shell)
	for x: float in [-1.0, 1.0]:
		_box(Vector3(WALL_M, h.y, h.z), Vector3(x * (h.x - WALL_M) * 0.5, h.y * 0.5, 0), shell)
	# The coil's windings round each end, inside, so it reads as an attractor coil.
	for x: float in [-1.0, 1.0]:
		var ring := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.1
		t.outer_radius = 0.14
		t.rings = 24
		t.ring_segments = 10
		ring.mesh = t
		ring.material_override = coil
		ring.rotation = Vector3(0, 0, PI * 0.5)
		ring.position = Vector3(x * (h.x * 0.5 + 0.03), h.y * 0.5, 0)
		add_child(ring)
	# The cover, hinged on its back edge.
	_cover = Node3D.new()
	_cover.name = "Cover"
	_cover.position = Vector3(0, h.y, -h.z * 0.5)
	add_child(_cover)
	var lid := _box(Vector3(h.x, 0.02, h.z), Vector3(0, 0.01, h.z * 0.5), shell, _cover)
	lid.name = "Lid"
	var plate := _label("BSX  UPGRADE BAY", Vector3(0, 0.021, h.z * 0.5), 40, _cover)
	plate.rotation = Vector3(-PI * 0.5, 0, 0)
	plate.modulate = TradesLook.TRIM
	# Something for the pointer to land on inside, and to stand against: floor and walls.
	var body := StaticBody3D.new()
	body.name = "Body"
	add_child(body)
	for b: Array in [[Vector3(h.x, WALL_M, h.z), Vector3(0, WALL_M * 0.5, 0)],
			[Vector3(h.x, h.y, WALL_M), Vector3(0, h.y * 0.5, -(h.z - WALL_M) * 0.5)],
			[Vector3(h.x, h.y, WALL_M), Vector3(0, h.y * 0.5, (h.z - WALL_M) * 0.5)],
			[Vector3(WALL_M, h.y, h.z), Vector3(-(h.x - WALL_M) * 0.5, h.y * 0.5, 0)],
			[Vector3(WALL_M, h.y, h.z), Vector3((h.x - WALL_M) * 0.5, h.y * 0.5, 0)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = b[0]
		shape.shape = box
		shape.position = b[1]
		body.add_child(shape)
	var name_plate := _label(unit_id.to_upper().replace("_", " "), Vector3(0, h.y * 0.62, h.z * 0.5 + 0.002), 28)
	name_plate.modulate = TradesLook.SHELL


## A seat with nothing in it: a lit outline on the floor and its name.
func _build_ghost(seat: String) -> Node3D:
	var m: Array = MOUNTS[seat]
	var at: Vector3 = m[1]
	var size: Vector3 = m[2]
	var g := Node3D.new()
	g.name = "Seat_" + seat
	g.position = Vector3(at.x, WALL_M, at.z)
	add_child(g)
	var glow := TradesLook.glow(AMBER, 0.6)
	for z: float in [-1.0, 1.0]:
		_box(Vector3(size.x, 0.004, 0.01), Vector3(0, 0.002, z * size.z * 0.5), glow, g)
	for x: float in [-1.0, 1.0]:
		_box(Vector3(0.01, 0.004, size.z), Vector3(x * size.x * 0.5, 0.002, 0), glow, g)
	var l := _label("%s\nF to fit" % ADDON_NAMES[seat].to_upper(), Vector3(0, 0.01, 0), 22, g)
	l.rotation = Vector3(-PI * 0.5, 0, 0)
	l.modulate = AMBER
	return g


## The add-on as it sits on its seat (a stand-in until Shared Components' model).
func _build_addon(seat: String) -> Node3D:
	var m: Array = MOUNTS[seat]
	var at: Vector3 = m[1]
	var size: Vector3 = m[2]
	var a := Node3D.new()
	a.name = "Addon_" + seat
	a.position = at
	add_child(a)
	match seat:
		"core":
			var foot := TradesLook.metal(Color(0.35, 0.37, 0.4), 0.7, 0.4)
			# The core's flange: its bolts go through it, so the seat's face is its top.
			_box(Vector3(size.x, 0.02, size.z), Vector3(0, -0.01, 0), foot, a)
			var core := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = size.x * 0.32
			c.bottom_radius = size.x * 0.36
			c.height = size.y - 0.04
			c.radial_segments = 16
			core.mesh = c
			core.material_override = TradesLook.glow(Color(0.35, 0.7, 1.0), 0.5)
			core.position = Vector3(0, c.height * 0.5, 0)
			a.add_child(core)
		"emitter":
			var horn := TradesLook.metal(Color(0.82, 0.8, 0.74), 0.9, 0.25)
			_box(Vector3(size.x, 0.02, size.z), Vector3(0, 0.01, 0), horn, a)
			for x: float in [-1.0, 1.0]:
				var cone := MeshInstance3D.new()
				var c := CylinderMesh.new()
				c.top_radius = size.z * 0.45
				c.bottom_radius = size.z * 0.15
				c.height = size.y - 0.02
				c.radial_segments = 12
				cone.mesh = c
				cone.material_override = horn
				cone.position = Vector3(x * size.x * 0.25, 0.02 + c.height * 0.5, 0)
				a.add_child(cone)
		"board":
			var pcb := TradesLook.metal(Color(0.1, 0.42, 0.22), 0.1, 0.6)
			_box(size, Vector3(0, size.y * 0.5, 0), pcb, a)
			_box(Vector3(size.x * 0.4, 0.02, size.z * 0.4), Vector3(0, size.y + 0.01, -0.02), TradesLook.metal(TradesLook.DARK, 0.4, 0.4), a)
	return a


## A joint's marker: a ring (a strip for a weld) round its normal, the head as its first child.
func _marker(f: FastenerPoint) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var head := MeshInstance3D.new()
	head.material_override = _head
	var n := f.normal.normalized()
	var along := f.seam_up.normalized() if f.seam_up != Vector3.ZERO else (Vector3.RIGHT if absf(n.x) < 0.9 else Vector3.BACK)
	along = (along - n * along.dot(n)).normalized()
	ring.transform = Transform3D(Basis(along, n, along.cross(n)), f.position + n * 0.002)
	match f.kind:
		"weld":
			var strip := BoxMesh.new()
			strip.size = Vector3(f.seam_size.x, 0.003, f.seam_size.y + 0.012)
			ring.mesh = strip
			var bead := CapsuleMesh.new()
			bead.radius = f.seam_size.y * 0.5
			bead.height = f.seam_size.x
			bead.radial_segments = 6
			bead.rings = 2
			head.mesh = bead
			head.rotation = Vector3(0, 0, PI * 0.5)
			head.position.y = f.seam_size.y * 0.2
		"connector":
			ring.mesh = TradesTestStand._ring(0.022, 0.03)
			var plug := CylinderMesh.new()
			plug.top_radius = 0.018
			plug.bottom_radius = 0.02
			plug.height = 0.04
			plug.radial_segments = 12
			head.mesh = plug
			head.position.y = 0.02
		_:
			ring.mesh = TradesTestStand._ring(0.02, 0.028)
			var hex := CylinderMesh.new()
			hex.top_radius = 0.017
			hex.bottom_radius = 0.017
			hex.height = 0.012
			hex.radial_segments = 6
			head.mesh = hex
			head.position.y = 0.008
	ring.add_child(head)
	return ring


func _box(size: Vector3, at: Vector3, mat: Material, parent: Node = self) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	parent.add_child(m)
	return m


func _label(text: String, at: Vector3, font_size: int, parent: Node = self) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = TradesLook.mono_font()
	l.font_size = font_size
	l.pixel_size = 0.0015
	l.modulate = Color(0.12, 0.13, 0.15)
	l.outline_size = 0
	l.position = at
	parent.add_child(l)
	return l
