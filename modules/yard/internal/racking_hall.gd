extends Node3D
## The racking hall's automated store (stage 1.1): three aisles of racks, one per load size,
## each with a stacker crane that fetches a load to a port at the front where you take it
## (or a bot will, later), and puts it back. Draws a YardRackStore and animates its moves.
##
## The racks stand behind a fence; at the front, a waist-high counter for small totes, a low
## roller bed for medium crates and a floor bay for large cages, each with a terminal: F
## brings the nearest load of that size, F again puts it back.


## Crane speeds: along the aisle (m/s), up and down (m/s), the forks' reach (s).
@export var travel_speed := 4.0
@export var lift_speed := 2.0
@export var fork_time := 0.45
## How long a load takes to roll from the crane to its port (s).
@export var conveyor_time := 1.4

## Front of the racks, where each crane hands over, and the fence's line (z).
const HANDOVER_Z := -10.5
const FENCE_Z := -10.0

## What each load size looks like: colours of totes, crates and cages.
const LOAD_COLOURS := [
	[Color(0.2, 0.45, 0.75), Color(0.85, 0.55, 0.15), Color(0.35, 0.36, 0.4), Color(0.75, 0.2, 0.2), Color(0.3, 0.6, 0.35)],
	[Color(0.62, 0.48, 0.3), Color(0.25, 0.4, 0.6), Color(0.5, 0.5, 0.48)],
	[Color(0.55, 0.57, 0.6), Color(0.85, 0.6, 0.2)],
]

var store: YardRackStore
## Per size: the MultiMesh of loads in their slots.
var load_meshes: Array[MultiMeshInstance3D] = []
## Per size: crane parts {mast, carriage, fork, carried} and its queue of jobs.
var cranes: Array[Dictionary] = []
## Per size: the load standing at the port (a MeshInstance3D), or null.
var port_boxes: Array = [null, null, null]
## Per size: the terminal's screen text.
var port_labels: Array[Label3D] = []
## slot -> its index in its size's MultiMesh.
var _instance_of: Dictionary = {}
## Slots the cranes are still on their way to, so their loads stay drawn until picked.
var _shown: Dictionary = {}
var _kit


func build(kit, rack_store: YardRackStore) -> void:
	_kit = kit
	store = rack_store
	_build_racks()
	_build_loads()
	_build_cranes()
	_build_front()
	for size in 3:
		if not store.ports[size].is_empty():
			_show_port_box(size)
		_update_terminal(size)


## Asks the crane of that size to bring a load (or, with one at the port, to put it back).
## Returns what happened: "fetching", "storing", "busy" (the crane is mid-job), "empty".
func use_port(size: int) -> String:
	if not (cranes[size].queue as Array).is_empty() or cranes[size].busy:
		return "busy"
	if store.ports[size].is_empty():
		var slot := store.take_out(size)
		if slot < 0:
			return "empty"
		_queue(size, {"kind": "fetch", "slot": slot})
		return "fetching"
	var back := store.put_away(size)
	if back < 0:
		return "busy"
	_queue(size, {"kind": "store", "slot": back})
	return "storing"


## True while any crane is moving.
func busy() -> bool:
	for c in cranes:
		if c.busy or not (c.queue as Array).is_empty():
			return true
	return false


# --- Racks ---------------------------------------------------------------------------------

func _build_racks() -> void:
	var uprights: Array[Transform3D] = []
	var beams: Array[Transform3D] = []
	for size in 3:
		var a: Dictionary = YardRackStore.AISLES[size]
		var cell: float = a.cell
		var levels: int = a.levels
		var bays: int = a.bays
		var post := 0.06 + cell * 0.03
		var top := 0.35 + cell * levels
		var length := cell * bays
		var z_mid := YardRackStore.RACK_FRONT_Z - length * 0.5
		for side: int in [-1, 1]:
			var inner: float = float(a.x) + side * float(a.aisle) * 0.5
			var outer := inner + side * cell
			for x: float in [inner, outer]:
				for bay in bays + 1:
					var z := YardRackStore.RACK_FRONT_Z - cell * bay
					uprights.append(Transform3D(Basis.from_scale(Vector3(post, top, post)), Vector3(x, top * 0.5, z)))
				for level in levels + 1:
					var y := 0.35 + cell * level - 0.04
					beams.append(Transform3D(Basis.from_scale(Vector3(post * 0.8, 0.08, length)), Vector3(x, y, z_mid)))
			# Rails for the crane, floor and top.
		beams.append(Transform3D(Basis.from_scale(Vector3(0.25, 0.12, length + 1.0)), Vector3(float(a.x), 0.06, z_mid - 0.5)))
		beams.append(Transform3D(Basis.from_scale(Vector3(0.25, 0.12, length + 1.0)), Vector3(float(a.x), top + 0.5, z_mid - 0.5)))
	_multi(uprights, _kit.paint(Color(0.2, 0.3, 0.5), 0.4, 0.5), "Uprights")
	_multi(beams, _kit.paint(Color(1.0, 0.5, 0.12), 0.2, 0.45), "Beams")


func _multi(xforms: Array[Transform3D], mat: Material, node_name: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	mm.mesh = cube
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
	return mmi


# --- Loads ---------------------------------------------------------------------------------

func _build_loads() -> void:
	var counts := [0, 0, 0]
	for i in store.slots.size():
		var size: int = store.slots[i].size
		_instance_of[i] = counts[size]
		counts[size] += 1
	for size in 3:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _load_mesh(size)
		mm.instance_count = counts[size]
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Loads_%s" % YardRackStore.SIZE_NAMES[size]
		mmi.multimesh = mm
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.6 if size == 0 else 0.75
		m.metallic = 0.5 if size == 2 else 0.0
		mmi.material_override = m
		add_child(mmi)
		load_meshes.append(mmi)
	for i in store.slots.size():
		_shown[i] = not store.slots[i].load.is_empty()
		_draw_slot(i)


func _load_mesh(size: int) -> Mesh:
	var s := YardRackStore.load_size(size)
	var b := BoxMesh.new()
	b.size = Vector3(s, s * (0.7 if size == 0 else 0.85), s)
	return b


func _draw_slot(i: int) -> void:
	var size: int = store.slots[i].size
	var mm := load_meshes[size].multimesh
	var idx: int = _instance_of[i]
	if not _shown.get(i, false):
		mm.set_instance_transform(idx, Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), Vector3(0, -50, 0)))
		return
	var p := store.slot_position(i)
	var h := YardRackStore.load_size(size) * (0.7 if size == 0 else 0.85)
	p.y = p.y - float(YardRackStore.AISLES[size].cell) * 0.5 + h * 0.5 + 0.02
	mm.set_instance_transform(idx, Transform3D(Basis.IDENTITY, p))
	mm.set_instance_color(idx, _colour_for(i))


func _colour_for(i: int) -> Color:
	var s := store.slots[i]
	var palette: Array = LOAD_COLOURS[int(s.size)]
	var label: String = s.load.get("label", "")
	var c: Color = palette[abs(label.hash()) % palette.size()]
	return c


# --- Cranes --------------------------------------------------------------------------------

func _build_cranes() -> void:
	var yellow: Material = _kit.paint(Color(1.0, 0.78, 0.1), 0.2, 0.5)
	var dark: Material = _kit.paint(Color(0.15, 0.16, 0.18), 0.5, 0.45)
	for size in 3:
		var a: Dictionary = YardRackStore.AISLES[size]
		var cell: float = a.cell
		var top := 0.35 + cell * int(a.levels)
		var mast := Node3D.new()
		mast.name = "Crane_%s" % YardRackStore.SIZE_NAMES[size]
		mast.position = Vector3(float(a.x), 0.0, HANDOVER_Z)
		add_child(mast)
		_kit.box(Vector3(0.3, top + 0.4, 0.25), Vector3(0, (top + 0.4) * 0.5, 0), yellow, false, mast)
		_kit.box(Vector3(float(a.aisle) * 0.7, 0.3, 0.8), Vector3(0, 0.2, 0), dark, false, mast)
		_kit.box(Vector3(float(a.aisle) * 0.7, 0.2, 0.6), Vector3(0, top + 0.4, 0), dark, false, mast)
		var lamp: MeshInstance3D = _kit.box(Vector3(0.12, 0.12, 0.12), Vector3(0, top + 0.6, 0), _kit.glow(Color(1.0, 0.6, 0.1), 5.0), false, mast)
		lamp.name = "Beacon"
		var carriage := Node3D.new()
		carriage.name = "Carriage"
		carriage.position.y = 0.35
		mast.add_child(carriage)
		_kit.box(Vector3(float(a.aisle) * 0.8, 0.12, cell * 0.9), Vector3(0, 0.0, 0), dark, false, carriage)
		var fork := Node3D.new()
		fork.name = "Fork"
		carriage.add_child(fork)
		for dz: float in [-cell * 0.25, cell * 0.25]:
			_kit.box(Vector3(cell * 0.9, 0.04, 0.06), Vector3(0, 0.08, dz), yellow, false, fork)
		var carried := MeshInstance3D.new()
		carried.name = "Carried"
		carried.mesh = _load_mesh(size)
		carried.visible = false
		var cm := StandardMaterial3D.new()
		cm.roughness = 0.6
		carried.material_override = cm
		fork.add_child(carried)
		var h := YardRackStore.load_size(size) * (0.7 if size == 0 else 0.85)
		carried.position.y = 0.1 + h * 0.5
		cranes.append({"mast": mast, "carriage": carriage, "fork": fork, "carried": carried,
				"queue": [], "busy": false, "beacon": lamp})


func _queue(size: int, job: Dictionary) -> void:
	(cranes[size].queue as Array).append(job)
	if not cranes[size].busy:
		_next_job(size)


func _next_job(size: int) -> void:
	var c: Dictionary = cranes[size]
	var q: Array = c.queue
	if q.is_empty():
		c.busy = false
		(c.beacon as Node3D).visible = false
		return
	c.busy = true
	(c.beacon as Node3D).visible = true
	var job: Dictionary = q.pop_front()
	var slot: int = job.slot
	var s := store.slots[slot]
	var a: Dictionary = YardRackStore.AISLES[size]
	var cell: float = a.cell
	var target := store.slot_position(slot)
	var shelf_y := target.y - cell * 0.5 + 0.02 - 0.1
	var reach := float(s.side) * (float(a.aisle) * 0.5 + cell * 0.5)
	var hand_y := _port_hand_y(size)
	var mast: Node3D = c.mast
	var carriage: Node3D = c.carriage
	var fork: Node3D = c.fork
	var carried: MeshInstance3D = c.carried
	var t := create_tween()
	if job.kind == "fetch":
		_travel(t, mast, carriage, target.z, shelf_y)
		t.tween_property(fork, "position:x", reach, fork_time)
		t.tween_callback(func() -> void:
			_shown[slot] = false
			_draw_slot(slot)
			(carried.material_override as StandardMaterial3D).albedo_color = _colour_of_load(size, store.ports[size])
			carried.visible = true)
		t.tween_property(carriage, "position:y", shelf_y + 0.12, 0.25)
		t.tween_property(fork, "position:x", 0.0, fork_time)
		_travel(t, mast, carriage, HANDOVER_Z, hand_y)
		t.tween_callback(func() -> void:
			carried.visible = false
			_show_port_box(size, true))
		t.tween_interval(conveyor_time)
	else:
		# The load rolls back from the port onto the forks, then goes up into its slot.
		t.tween_callback(func() -> void: _roll_back(size))
		_travel(t, mast, carriage, HANDOVER_Z, hand_y)
		t.tween_interval(conveyor_time)
		t.tween_callback(func() -> void:
			(carried.material_override as StandardMaterial3D).albedo_color = _colour_for_slot_load(slot)
			carried.visible = true)
		_travel(t, mast, carriage, target.z, shelf_y + 0.12)
		t.tween_property(fork, "position:x", reach, fork_time)
		t.tween_property(carriage, "position:y", shelf_y, 0.25)
		t.tween_callback(func() -> void:
			carried.visible = false
			_shown[slot] = true
			_draw_slot(slot))
		t.tween_property(fork, "position:x", 0.0, fork_time)
	t.tween_callback(func() -> void:
		_update_terminal(size)
		_next_job(size))


func _travel(t: Tween, mast: Node3D, carriage: Node3D, z: float, y: float) -> void:
	var dz := absf(mast.position.z - z)
	var dy := absf(carriage.position.y - y)
	var time := maxf(dz / travel_speed, dy / lift_speed)
	time = maxf(time, 0.2)
	t.tween_property(mast, "position:z", z, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(carriage, "position:y", y, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## The carriage's height when it hands a load to its port's conveyor.
func _port_hand_y(size: int) -> float:
	var h := YardRackStore.load_size(size) * (0.7 if size == 0 else 0.85)
	return (YardRackStore.PORTS[size] as Vector3).y - h * 0.5 - 0.1


func _colour_of_load(size: int, load_data: Dictionary) -> Color:
	var palette: Array = LOAD_COLOURS[size]
	return palette[abs(str(load_data.get("label", "")).hash()) % palette.size()]


func _colour_for_slot_load(slot: int) -> Color:
	return _colour_for(slot)


# --- The front: fence, ports and terminals -------------------------------------------------

func _build_front() -> void:
	var k = _kit
	var steel: Material = k.paint(Color(0.3, 0.32, 0.36), 0.5, 0.45)
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_color = Color(0.25, 0.28, 0.32, 0.35)
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.metallic = 0.6
	mesh_mat.roughness = 0.4
	# Each port's opening in the fence: [from x, to x, top, sill].
	var gaps := []
	for size in 3:
		var p: Vector3 = YardRackStore.PORTS[size]
		var s := YardRackStore.load_size(size)
		var bottom := _port_hand_y(size) + 0.1
		gaps.append([p.x - s * 0.5 - 0.15, p.x + s * 0.5 + 0.15, bottom + s + 0.15, maxf(bottom - 0.02, 0.0)])
	k.wall(true, FENCE_Z, 14.1, 45.9, 0.0, 2.6, mesh_mat, gaps, 0.06)
	for x in range(15, 46, 2):
		k.box(Vector3(0.08, 2.6, 0.1), Vector3(float(x), 1.3, FENCE_Z), steel, false)
	k.box(Vector3(31.8, 0.1, 0.12), Vector3(30.0, 2.62, FENCE_Z), k.paint(Color(1.0, 0.5, 0.12), 0.2, 0.45), false)
	# The openings stay closed to you (light curtains), open to loads.
	for g: Array in gaps:
		k.span(Vector3(g[0], g[3], FENCE_Z - 0.03), Vector3(g[1], g[2], FENCE_Z + 0.03), null, true).visible = false
	for size in 3:
		_build_port(size, steel)


func _build_port(size: int, steel: Material) -> void:
	var k = _kit
	var p: Vector3 = YardRackStore.PORTS[size]
	var s := YardRackStore.load_size(size)
	var bed_top := _port_hand_y(size) + 0.1
	var bed_end := p.z + s * 0.5 + 0.3
	# The bed the load rolls out on: from the crane, through the fence, to the port.
	k.span(Vector3(p.x - s * 0.5 - 0.1, 0.0, HANDOVER_Z - 0.3), Vector3(p.x + s * 0.5 + 0.1, bed_top, bed_end), steel)
	for i in int((bed_end - HANDOVER_Z) / 0.25):
		k.box(Vector3(s + 0.1, 0.03, 0.05), Vector3(p.x, bed_top + 0.012, HANDOVER_Z + 0.1 + i * 0.25),
				k.paint(Color(0.6, 0.62, 0.66), 0.8, 0.3), false)
	# Hazard edge round a floor bay.
	k.box(Vector3(s + 0.3, 0.012, 0.15), Vector3(p.x, 0.006, bed_end + 0.15), k.paint(Color(1.0, 0.78, 0.1), 0.1, 0.6), false)
	# The terminal beside the port.
	var tx := p.x + s * 0.5 + 0.7
	var term: MeshInstance3D = k.box(Vector3(0.5, 1.15, 0.4), Vector3(tx, 0.575, -6.8), k.paint(Color(0.85, 0.86, 0.88), 0.1, 0.5))
	term.name = "Terminal_%s" % YardRackStore.SIZE_NAMES[size]
	k.box(Vector3(0.46, 0.34, 0.03), Vector3(tx, 1.32, -6.7), k.glow(Color(0.15, 0.4, 0.7), 1.2), false)
	var screen := Label3D.new()
	screen.pixel_size = 0.0018
	screen.font_size = 32
	screen.width = 230.0
	screen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen.position = Vector3(tx, 1.32, -6.68)
	screen.modulate = Color(0.9, 0.95, 1.0)
	add_child(screen)
	port_labels.append(screen)
	k.sign(YardRackStore.SIZE_NAMES[size].to_upper(), Vector3(p.x, 2.9, FENCE_Z + 0.06), Vector3.BACK, 0.008, Color(1.0, 0.5, 0.12))
	# What makes it usable: an area round the terminal (the mover's ray takes areas).
	var area := Area3D.new()
	area.name = "Use_%s" % YardRackStore.SIZE_NAMES[size]
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.7, 1.6, 0.6)
	cs.shape = shape
	area.add_child(cs)
	area.position = Vector3(tx, 0.8, -6.8)
	area.set_meta("yard_use", func() -> void: use_port(size))
	area.set_meta("yard_hint", func() -> String: return _hint_for(size))
	area.add_to_group("gfx_interactable")
	area.set_meta("gfx_id", "rack_port:%d" % size)
	add_child(area)


func _hint_for(size: int) -> String:
	var key := Keys.prompt(Keys.INTERACT)
	var noun: String = YardRackStore.LOAD_NAMES[size]
	if cranes[size].busy:
		return "The crane is working..."
	if store.ports[size].is_empty():
		return "%s  Bring a %s %s" % [key, YardRackStore.SIZE_NAMES[size], noun]
	return "%s  Put the %s away (%s)" % [key, noun, store.ports[size].get("label", "")]


func _update_terminal(size: int) -> void:
	if size >= port_labels.size():
		return
	var at_port: Dictionary = store.ports[size]
	var text := "%s %sS\n%d / %d stored" % [YardRackStore.SIZE_NAMES[size].to_upper(), YardRackStore.LOAD_NAMES[size].to_upper(),
			store.filled_count(size), store.slot_count(size)]
	if not at_port.is_empty():
		text += "\nAT PORT: %s x%d" % [at_port.label, int(at_port.qty)]
	port_labels[size].text = text


## The load at the port: drawn there (rolling out along the bed when `roll`), with its label.
func _show_port_box(size: int, roll := false) -> void:
	if port_boxes[size]:
		(port_boxes[size] as Node).queue_free()
	var mi := MeshInstance3D.new()
	mi.name = "PortLoad_%s" % YardRackStore.SIZE_NAMES[size]
	mi.mesh = _load_mesh(size)
	var m := StandardMaterial3D.new()
	m.albedo_color = _colour_of_load(size, store.ports[size])
	m.roughness = 0.6
	mi.material_override = m
	var h := YardRackStore.load_size(size) * (0.7 if size == 0 else 0.85)
	var p: Vector3 = YardRackStore.PORTS[size]
	var rest := Vector3(p.x, _port_hand_y(size) + 0.1 + h * 0.5, p.z)
	add_child(mi)
	var tag := Label3D.new()
	tag.text = "%s\nx%d" % [store.ports[size].get("label", ""), int(store.ports[size].get("qty", 0))]
	tag.pixel_size = 0.002 + 0.001 * size
	tag.font_size = 32
	tag.position = Vector3(0, 0, YardRackStore.load_size(size) * 0.5 + 0.01)
	tag.modulate = Color.WHITE
	tag.outline_size = 8
	mi.add_child(tag)
	port_boxes[size] = mi
	if roll:
		mi.position = Vector3(p.x, rest.y, HANDOVER_Z)
		create_tween().tween_property(mi, "position", rest, conveyor_time).set_trans(Tween.TRANS_SINE)
	else:
		mi.position = rest
	_update_terminal(size)


func _roll_back(size: int) -> void:
	var mi: Node3D = port_boxes[size]
	port_boxes[size] = null
	if mi == null:
		return
	var t := create_tween()
	t.tween_property(mi, "position:z", HANDOVER_Z, conveyor_time).set_trans(Tween.TRANS_SINE)
	t.tween_callback(mi.queue_free)
	_update_terminal(size)
