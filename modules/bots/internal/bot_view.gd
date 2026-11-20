extends Node3D
## The bot crew in the open station (master plan 6.4, 6.5): the bot bay beside the build berth
## (a charging cradle for each bot, its lamp green while it charges), and every bot flying, working
## and docking, drawn from the crew's state (BotsBus.crew). Presentation only: nothing here
## decides anything, so it is the same on every machine.
##
## Each bot has its look (BotLook, rebuilt when its type, paint or mark changes; its wear shows on
## the paint), a lamp, jets that burn with its speed, arms that reach and tap as it works, and its
## work: a welder's arc with sparks, a riveter's flash, a nut runner's spin, an inspector's scan
## beam, a crate of parts while it carries one, tractor lines while it floats a job in. Each hums
## (its own lift fans) and its tool makes its own sound.

const Look := preload("res://modules/bots/internal/bot_look.gd")
const Sounds := preload("res://modules/bots/internal/bot_sounds.gd")
const Types := preload("res://modules/bots/api/bot_types.gd")

## How many cradles the bay has (two rows of eight).
const BAY_SLOTS := 16

var bus: Object
var bay: Node3D
## bot id -> {look, key, sparks, arc, beam, lines, hum, tool_audio, tool_sound, t, flash}
var _bots: Dictionary = {}
var _cradles: Array[MeshInstance3D] = []
var _t := 0.0
var _beam_mat: StandardMaterial3D
var _line_mat: StandardMaterial3D


func setup(bots_bus: Object) -> void:
	bus = bots_bus
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.albedo_color = Color(0.45, 1.0, 0.7, 0.28)
	_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_line_mat = StandardMaterial3D.new()
	_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line_mat.albedo_color = Color(0.5, 0.8, 1.0, 0.5)
	_build_bay()
	sync()
	bus.connect("crew_changed", sync)


# --- The bot bay ---------------------------------------------------------------------------------

func _build_bay() -> void:
	bay = Node3D.new()
	bay.name = "BotBay"
	add_child(bay)
	var o: Vector3 = bus.call("bay_origin")
	var frame := _mat(Color(0.3, 0.32, 0.34), 0.7, 0.45)
	var panel := _mat(Color(0.18, 0.19, 0.2), 0.4, 0.6)
	var orange := _mat(Color("e8792b"), 0.3, 0.5)
	# The back wall the cradles hang on, and its frame.
	var cols := 4
	var rows := BAY_SLOTS / cols
	var w := float(cols) * 3.0 + 1.4
	var h := float(rows) * 3.2 + 1.4
	var top := o.y + 1.7
	var mid := Vector3(o.x, top - h * 0.5, o.z + 1.6)
	_box(bay, Vector3(w, h, 0.25), mid, panel)
	for sx: float in [-1.0, 1.0]:
		_box(bay, Vector3(0.4, h + 1.0, 0.6), mid + Vector3(sx * w * 0.5, 0, 0), frame)
	for sy: float in [-1.0, 1.0]:
		_box(bay, Vector3(w + 0.8, 0.4, 0.6), mid + Vector3(0, sy * h * 0.5, 0), frame)
	# A brace back to the station face, and the company's orange band across the top.
	_box(bay, Vector3(0.5, 0.5, YardLayout.BERTH_FACE_Z - YardLayout.HULL_BOX.position.z + 6.0),
			Vector3(o.x, top + 0.2, (o.z + YardLayout.HULL_BOX.position.z) * 0.5 + 1.0), frame)
	_box(bay, Vector3(w + 0.8, 0.5, 0.1), mid + Vector3(0, h * 0.5 + 0.1, -0.35), orange)
	for i in BAY_SLOTS:
		var at: Vector3 = bus.call("bay_slot", i)
		# A cradle: a shelf, two arms and a charging lamp.
		_box(bay, Vector3(2.2, 0.14, 1.4), at + Vector3(0, -0.85, 0.7), frame)
		for sx: float in [-1.0, 1.0]:
			_box(bay, Vector3(0.12, 0.9, 0.12), at + Vector3(sx * 1.0, -0.45, 1.3), frame)
		var lamp := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.5, 0.08, 0.05)
		lamp.mesh = lm
		lamp.position = at + Vector3(0, 0.9, 1.45)
		lamp.material_override = _glow(Color(0.9, 0.55, 0.15), 1.0)
		bay.add_child(lamp)
		_cradles.append(lamp)
	# Floods on the bay.
	for sx: float in [-1.0, 1.0]:
		var l := SpotLight3D.new()
		l.light_color = Color(1.0, 0.94, 0.85)
		l.light_energy = 3.0
		l.spot_range = 22.0
		l.spot_angle = 50.0
		l.position = mid + Vector3(sx * (w * 0.5 + 1.5), h * 0.5 + 1.0, -5.0)
		bay.add_child(l)
		l.look_at(mid, Vector3.UP)


# --- The bots ------------------------------------------------------------------------------------

## The roster changed: looks made, remade or taken away.
func sync() -> void:
	var seen := {}
	for b: Dictionary in bus.crew.bots:
		var id := int(b.id)
		seen[id] = true
		var key := "%s/%s/%d" % [b.type, b.paint, int(b.mark)]
		var e: Dictionary = _bots.get(id, {})
		if e.is_empty() or str(e.key) != key:
			if not e.is_empty():
				(e.look as Node3D).queue_free()
			e = _make(b, key)
			_bots[id] = e
	for id: int in _bots.keys():
		if not seen.has(id):
			(_bots[id].look as Node3D).queue_free()
			_bots.erase(id)


func _make(b: Dictionary, key: String) -> Dictionary:
	var t := Types.info(str(b.type))
	var paint: Color = Types.PAINTS.get(str(b.paint), Color("e8792b"))
	var look := Look.make(str(t.family), paint, int(b.mark), float(b.wear), int(b.id))
	look.name = "Bot%d" % int(b.id)
	look.position = b.pos
	add_child(look)
	var e := {"look": look, "key": key, "t": randf() * 10.0, "flash": 0.0, "family": str(t.family)}
	# Sparks and an arc light for the welders, a scan beam for the inspectors, tractor lines for fitting.
	var tips := Look.tips(look)
	var tip: Node3D = tips[tips.size() - 1] if not tips.is_empty() else look
	e.tip = tip
	var sparks := CPUParticles3D.new()
	sparks.name = "Sparks"
	sparks.emitting = false
	sparks.amount = 40
	sparks.lifetime = 0.5
	sparks.direction = Vector3(0, 0, 1)
	sparks.spread = 70.0
	sparks.initial_velocity_min = 1.5
	sparks.initial_velocity_max = 4.0
	sparks.gravity = Vector3.ZERO
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.0
	var sm := SphereMesh.new()
	sm.radius = 0.012
	sm.height = 0.024
	sparks.mesh = sm
	sparks.material_override = _glow(Color(1.0, 0.75, 0.35), 4.0)
	tip.add_child(sparks)
	e.sparks = sparks
	var arc := OmniLight3D.new()
	arc.light_color = Color(0.7, 0.85, 1.0)
	arc.light_energy = 0.0
	arc.omni_range = 3.5
	tip.add_child(arc)
	e.arc = arc
	var beam := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 0.35
	cone.height = 1.0
	beam.mesh = cone
	beam.material_override = _beam_mat
	beam.visible = false
	add_child(beam)
	e.beam = beam
	var lines := MeshInstance3D.new()
	lines.mesh = ImmediateMesh.new()
	lines.material_override = _line_mat
	lines.visible = false
	add_child(lines)
	e.lines = lines
	# Its hum, and its tool's voice.
	var hum := AudioStreamPlayer3D.new()
	hum.stream = Sounds.stream("hover_" + str(t.family))
	hum.volume_db = -20.0
	hum.max_distance = 28.0
	hum.unit_size = 3.0
	look.add_child(hum)
	e.hum = hum
	var tool := AudioStreamPlayer3D.new()
	tool.volume_db = -14.0
	tool.max_distance = 30.0
	tool.unit_size = 3.0
	look.add_child(tool)
	e.tool = tool
	e.tool_sound = ""
	return e


func _process(delta: float) -> void:
	_t += delta
	for b: Dictionary in bus.crew.bots:
		var e: Dictionary = _bots.get(int(b.id), {})
		if e.is_empty():
			continue
		_draw_bot(b, e, delta)
	_draw_cradles()


func _draw_bot(b: Dictionary, e: Dictionary, delta: float) -> void:
	var look: Node3D = e.look
	var task: Dictionary = b.task
	var kind := str(task.get("kind", "idle"))
	var phase := str(task.get("phase", ""))
	var was := look.position
	var to: Vector3 = b.pos
	# Close the gap a guest's snapshot leaves, smoothly.
	look.position = was.lerp(to, clampf(delta * 10.0, 0.0, 1.0)) if was.distance_to(to) < 6.0 else to
	var vel := (look.position - was) / maxf(delta, 0.0001)
	var speed := vel.length()
	var working := phase in ["fasten", "fit", "scan"] or kind == "refurb"
	# Face the way it flies, or the work.
	var face := Vector3.ZERO
	if working and task.has("spot"):
		face = (task.spot as Vector3) - look.position
	elif working and phase == "fit":
		var info: Dictionary = bus.call("job_info", int(task.get("job", -1)))
		face = (info.get("centre", look.position) as Vector3) - look.position
	elif speed > 0.3:
		face = vel
	if kind == "charge" or kind == "service":
		if look.position.distance_to(to) < 0.5:
			face = Vector3(0, 0, -1)
	if face.length() > 0.05:
		var flat := Vector3(face.x, 0.0, face.z)
		if flat.length() > 0.05:
			var want := Basis.looking_at(flat.normalized(), Vector3.UP)
			look.basis = look.basis.slerp(want, clampf(delta * 4.0, 0.0, 1.0)).orthonormalized()
	e.t = float(e.t) + delta
	var skin := look.get_meta("skin", null) as ShaderMaterial
	if skin and absf(float(e.get("wear", -1.0)) - float(b.wear)) > 0.02:
		e.wear = float(b.wear)
		skin.set_shader_parameter("wear", clampf(float(b.wear), 0.0, 1.0) * 0.8 + 0.08)
		skin.set_shader_parameter("grime", 0.25 + clampf(float(b.wear), 0.0, 1.0) * 0.5)
	var lean := look.basis.inverse() * vel
	Look.animate(look, float(e.t), 1.0 if working else (0.35 if kind == "idle" else 0.0), speed, lean)
	# A refurbisher in the annex is out of sight.
	look.visible = not (kind == "refurb" and look.position.distance_to(to) < 1.0)
	var cargo := look.find_child("Cargo", true, false) as Node3D
	if cargo:
		cargo.visible = bool(task.get("carrying", false))
	# The work's effects.
	var skill := Types.kind_skill(int(task.get("kind_of", 0))) if task.has("kind_of") else ""
	var welding := phase == "fasten" and skill == "weld"
	var riveting := phase == "fasten" and skill == "rivet"
	var bolting := phase == "fasten" and skill == "bolt"
	var scanning := phase == "scan"
	(e.sparks as CPUParticles3D).emitting = welding or (riveting and fmod(float(e.t), 0.7) < 0.08)
	var arc := e.arc as OmniLight3D
	arc.light_energy = (1.6 + sin(_t * 47.0) * 0.6 + sin(_t * 113.0) * 0.4) if welding else (2.5 if riveting and fmod(float(e.t), 0.7) < 0.06 else 0.0)
	var tip := e.tip as Node3D
	if bolting:
		tip.rotate_object_local(Vector3(0, 0, 1), delta * 18.0)
	var beam := e.beam as MeshInstance3D
	beam.visible = scanning
	if scanning and task.has("spot"):
		_stretch(beam, tip.global_position, task.spot as Vector3)
	_draw_lines(e, phase == "fit", task, look)
	_sound(e, welding, riveting, bolting, scanning, kind)


## Points mesh `m` (a cone 1 m tall along y) from `a` to `b`.
func _stretch(m: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var len := d.length()
	if len < 0.01:
		m.visible = false
		return
	var y := d / len
	var x := y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	m.global_transform = Transform3D(Basis(x, y * len, z), a + d * 0.5)


## Tractor lines from the bot's tips to the job it floats in.
func _draw_lines(e: Dictionary, on: bool, task: Dictionary, look: Node3D) -> void:
	var lines := e.lines as MeshInstance3D
	lines.visible = on
	if not on:
		return
	var info: Dictionary = bus.call("job_info", int(task.get("job", -1)))
	var to: Vector3 = info.get("centre", look.global_position)
	var im := lines.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for tip in Look.tips(look):
		for k in 3:
			var wob := Vector3(sin(_t * 3.0 + k), cos(_t * 2.3 + k), sin(_t * 1.7 + k * 2.0)) * 0.15
			im.surface_add_vertex(tip.global_position)
			im.surface_add_vertex(to + wob)
	im.surface_end()


func _sound(e: Dictionary, welding: bool, riveting: bool, bolting: bool, scanning: bool, kind: String) -> void:
	var hum := e.hum as AudioStreamPlayer3D
	var want_hum := kind != "charge" and kind != "service" and (e.look as Node3D).visible
	if want_hum and not hum.playing and hum.is_inside_tree():
		hum.play(randf() * 1.5)
	elif not want_hum and hum.playing:
		hum.stop()
	var tool := e.tool as AudioStreamPlayer3D
	var want := "weld" if welding else ("bolt" if bolting else ("scan" if scanning else ""))
	if riveting and fmod(float(e.t), 0.7) < 0.03 and tool.is_inside_tree():
		tool.stream = Sounds.stream("rivet")
		tool.play()
		e.tool_sound = "rivet"
		return
	if want != str(e.tool_sound):
		e.tool_sound = want
		if want == "":
			if tool.stream != Sounds.stream("rivet"):
				tool.stop()
		elif tool.is_inside_tree():
			tool.stream = Sounds.stream(want)
			tool.play()


func _draw_cradles() -> void:
	var by_slot := {}
	for i in bus.crew.bots.size():
		var b: Dictionary = bus.crew.bots[i]
		by_slot[i] = b
	for i in _cradles.size():
		var lamp := _cradles[i]
		var m := lamp.material_override as StandardMaterial3D
		var b: Dictionary = by_slot.get(i, {})
		var c := Color(0.25, 0.25, 0.25)
		if not b.is_empty():
			var k := str(b.task.get("kind", ""))
			var docked := (b.pos as Vector3).distance_to(bus.call("bay_slot", i)) < 0.6
			if docked and (k == "charge" or k == "service"):
				c = Color(0.3, 1.0, 0.45) if k == "charge" else Color(0.4, 0.7, 1.0)
				c = c * (0.7 + 0.3 * sin(_t * 3.0))
			else:
				c = Color(0.95, 0.55, 0.15)
		m.albedo_color = c
		m.emission = c


## Draws every bot where it is now at once (screenshots, tests).
func snap() -> void:
	sync()
	for b: Dictionary in bus.crew.bots:
		var e: Dictionary = _bots.get(int(b.id), {})
		if not e.is_empty():
			(e.look as Node3D).position = b.pos
	_process(0.016)


func look_of(id: int) -> Node3D:
	return (_bots.get(id, {}) as Dictionary).get("look") as Node3D


func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.position = at
	m.material_override = mat
	parent.add_child(m)
	return m


static func _mat(c: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


static func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m
