extends Node3D
## The refurb shop (beenster, 19 Nov): an open deck in the weightless dock, just beyond holding
## berth H2, where TartanCo RF-2 refurbishers bring second-hand parts back to Standard. The
## intake rack (SECOND-HAND IN) on the left as you look from the station, four work cradles,
## the REFURBISHED rack on the right with the scrap bin, each bot's charging dock at the back
## and the shop's board over them.
##
## The state is a RefurbWorks, stepped here on the yard's shared clock: fixed ticks from the
## yard's epoch, with what players asked for ("refurb.in", "refurb.take" in the yard's log)
## applied at its tick, so every PC draws the same shop. Everything else here only draws it.

const Paint := preload("res://modules/refurb/internal/refurb_paint.gd")
const BotLook := preload("res://modules/refurb/internal/refurb_bot_look.gd")
const Sounds := preload("res://modules/refurb/internal/refurb_sounds.gd")

const TICK := 1.0 / 60.0
const FRAME_BUDGET_MS := 6.0
const CATCH_UP_BUDGET_MS := 30.0
const DECK_HALF := Vector2(23.0, 8.0)
const BACK_Z := -7.6
const STAGE_COLOURS: Array[Color] = [Color(0.3, 0.75, 1.0), Color(1.0, 0.6, 0.15), Color(0.85, 0.8, 0.6),
		Color(1.0, 0.45, 0.1), Color(0.3, 1.0, 0.45)]

var works: RefurbWorks
## Ticks run since the yard's epoch.
var tick := 0
var bots: Array[Node3D] = []

var _bus: Node
var _yard: Node
var _queue: Array[Dictionary] = []
var _local_time := 0.0
var _lot_nodes: Dictionary = {}
var _cradle_labels: Array[Label3D] = []
var _cradle_lamps: Array[StandardMaterial3D] = []
var _work_lights: Array[OmniLight3D] = []
var _board: Label3D
var _board_t := 0.0
var _fx: Array[Dictionary] = []
var _dealer: Node3D
var _jingle: AudioStreamPlayer3D
var _clang: AudioStreamPlayer3D
var _beacons: Array[MeshInstance3D] = []
var _clock := 0.0


## `bus`: the RefurbBus (signals go out through it); `yard`: the YardBus whose clock and log the
## shop follows (null: a local clock, for captures and tests).
func setup(bus: Node, yard: Node, w: RefurbWorks) -> void:
	_bus = bus
	_yard = yard
	works = w
	name = "RefurbShop"
	_build_deck()
	for i in works.tuning.cradles:
		_build_cradle(i)
		_build_dock(i)
	_build_rack(false)
	_build_rack(true)
	_build_scrap_bin()
	_build_board()
	_build_dealer()
	for b in works.bots:
		var look: Node3D = BotLook.new()
		add_child(look)
		look.call("build", String(b.serial))
		look.position = b.pos
		bots.append(look)
		_fx.append(_make_fx(look))
	_jingle = _player("Chime")
	_clang = _player("Clang")
	if _yard:
		for e: Dictionary in _yard.get("sim_log"):
			_enqueue(e)
		_yard.connect("sim_logged", _enqueue)
		_yard.connect("sim_reset", restart)


func _exit_tree() -> void:
	if _yard and is_instance_valid(_yard):
		if _yard.is_connected("sim_logged", _enqueue):
			_yard.disconnect("sim_logged", _enqueue)
		if _yard.is_connected("sim_reset", restart):
			_yard.disconnect("sim_reset", restart)


## The yard's clock started again: an empty shop from tick 0, the log replayed.
func restart() -> void:
	works.reset()
	tick = 0
	_queue.clear()
	for id: int in _lot_nodes:
		(_lot_nodes[id] as Node3D).queue_free()
	_lot_nodes.clear()
	if _yard:
		for e: Dictionary in _yard.get("sim_log"):
			_enqueue(e)


func _enqueue(e: Dictionary) -> void:
	if not String(e.get("kind", "")).begins_with("refurb."):
		return
	var at := _queue.size()
	while at > 0 and (int(_queue[at - 1].tick) > int(e.tick) or (int(_queue[at - 1].tick) == int(e.tick) and int(_queue[at - 1].get("n", 0)) > int(e.get("n", 0)))):
		at -= 1
	_queue.insert(at, e)


## Something a player asked for, at a tick (with no yard: now).
func request(entry: Dictionary) -> void:
	if _yard:
		_yard.call("sim_request", entry)
	else:
		entry.tick = tick
		_enqueue(entry)


func target_tick() -> int:
	if _yard:
		return int(_yard.call("sim_target_tick"))
	return int(_local_time / TICK)


func _process(delta: float) -> void:
	if _yard == null:
		_local_time += delta
	var target := target_tick()
	if target >= 0:
		var start := Time.get_ticks_usec()
		var limit := (CATCH_UP_BUDGET_MS if target - tick > 30 else FRAME_BUDGET_MS) * 1000.0
		while tick < target:
			run_tick()
			if Time.get_ticks_usec() - start > limit:
				break
	draw(delta)


## One tick: the requests due, then the shop moved on.
func run_tick() -> void:
	while not _queue.is_empty() and int(_queue[0].tick) <= tick:
		_apply(_queue.pop_front())
	works.step(TICK)
	for ev: Dictionary in works.events:
		_on_event(ev)
	tick += 1


func run_ticks(n: int) -> void:
	for i in n:
		run_tick()


## Runs the shop on by `seconds` straight away, off the shared clock (captures only).
func fast_forward(seconds: float) -> void:
	var n := int(seconds / TICK)
	for i in n:
		works.step(TICK)
	_local_time = maxf(_local_time, tick * TICK)


func _apply(e: Dictionary) -> void:
	match String(e.kind):
		"refurb.in":
			works.receive(String(e.get("type", "")), float(e.get("condition", 0.5)), String(e.get("source", "")))
		"refurb.take":
			works.take(String(e.get("type", "")))
		"refurb.dealer":
			works.standin_dealer = bool(e.get("on", true))


func _on_event(ev: Dictionary) -> void:
	var lot: Dictionary = works.lots.get(int(ev.lot), {})
	if _bus and _bus.has_method("_shop_event"):
		_bus.call("_shop_event", String(ev.kind), lot)
	if not is_inside_tree():
		return
	match String(ev.kind):
		"certified":
			_jingle.global_position = to_global(works.cradle_point(int(ev.bot)))
			_jingle.stream = Sounds.stream("chime")
			_jingle.play()
		"retest":
			_jingle.global_position = to_global(works.cradle_point(int(ev.bot)))
			_jingle.stream = Sounds.stream("buzz")
			_jingle.play()
		"scrapped":
			_clang.global_position = to_global(RefurbWorks.SCRAP_AT)
			_clang.stream = Sounds.stream("clang")
			_clang.play()


# --- Drawing ------------------------------------------------------------------------------

func draw(delta: float) -> void:
	_clock += delta
	for i in bots.size():
		_draw_bot(i, delta)
	_draw_lots()
	for i in works.cradles.size():
		_draw_cradle(i)
	var d: Dictionary = works.dealer
	_dealer.visible = String(d.phase) != "away"
	_dealer.position = d.pos
	for j in _beacons.size():
		_beacons[j].visible = fmod(_clock + j * 0.25, 1.6) < 0.25
	_board_t -= delta
	if _board_t <= 0.0:
		_board_t = 0.5
		_board.text = board_text()


func _draw_bot(i: int, delta: float) -> void:
	var b: Dictionary = works.bots[i]
	var look := bots[i]
	var lot: Dictionary = works.lots.get(int(b.lot), {})
	var state := String(b.state)
	var working := state == RefurbWorks.BOT_WORK and not lot.is_empty()
	var centre := Vector3.INF
	if not lot.is_empty():
		centre = to_global((lot.pos as Vector3) + Vector3(0, float(lot.h) * 0.5, 0))
	var face: Vector3 = centre if working else to_global(b.target)
	if state == RefurbWorks.BOT_DOCK:
		face = to_global((b.pos as Vector3) + Vector3(0, 0, 5.0))
	var work := Vector3.INF
	if working:
		# The tool reaches for the part's face nearest the bot.
		var from: Vector3 = to_global(b.pos)
		var half := float(lot.h) * 0.5
		work = centre + (from - centre).normalized() * maxf(half * 0.85, 0.3)
		work += Vector3(sin(_clock * 2.3 + i), cos(_clock * 1.9 + i * 2.0), 0) * 0.06
	var hold := Vector3.INF
	if state in [RefurbWorks.BOT_CARRY, RefurbWorks.BOT_STOW] and not lot.is_empty():
		hold = to_global((lot.pos as Vector3) + Vector3(0, float(lot.h), 0))
	var moving := (look.position - (b.pos as Vector3)).length() / maxf(delta, 0.001)
	look.call("pose", to_global(b.pos), face, work, hold, float(b.charge), bool(b.charging), String(b.tool), delta)
	look.call("thrust", clampf(moving / 3.0, 0.0, 1.0))
	_draw_fx(i, working, String(b.tool), centre, lot)


func _draw_lots() -> void:
	var seen := {}
	for id: int in works.lots:
		var lot: Dictionary = works.lots[id]
		var where := String(lot.where)
		if where in [RefurbWorks.AT_BACKLOG, RefurbWorks.AT_STORES]:
			continue
		seen[id] = true
		var n: Node3D = _lot_nodes.get(id)
		if n == null:
			n = _lot_node(lot)
			_lot_nodes[id] = n
		var on_rack := where in [RefurbWorks.AT_INTAKE, RefurbWorks.AT_OUT, RefurbWorks.AT_SCRAP]
		var fit := float(lot.rack_fit) if on_rack else float(lot.fit)
		n.position = lot.pos
		n.scale = Vector3.ONE * fit * float(n.get_meta("model_scale", 1.0))
		var mat: ShaderMaterial = n.get_meta("mat")
		var wear := 1.0 - float(lot.condition)
		var clean: Vector3 = n.get_meta("albedo")
		var g := clampf(float(lot.grime), 0.0, 1.0)
		mat.set_shader_parameter("albedo", clean.lerp(Vector3(0.09, 0.06, 0.035), g * 0.65))
		mat.set_shader_parameter("condition", Vector4(clampf(wear * 1.1, 0.0, 1.0), clampf(float(lot.grime) * 0.9, 0.0, 1.0), 3.0, float(id % 17) * 0.13))
		var glow: Node3D = n.get_meta("glow") if n.has_meta("glow") else null
		if glow:
			glow.visible = int(lot.stage) == RefurbWorks.Stage.TEST or where == RefurbWorks.AT_OUT
		var tag: Label3D = n.get_meta("tag")
		tag.visible = where in [RefurbWorks.AT_INTAKE, RefurbWorks.AT_OUT]
		tag.text = _lot_tag(lot)
		tag.position = Vector3(0, float(n.get_meta("height")) + 0.25 / maxf(n.scale.y, 0.05), 0)
		tag.scale = Vector3.ONE / maxf(n.scale.x, 0.05)
	for id: int in _lot_nodes.keys():
		if not seen.has(id):
			(_lot_nodes[id] as Node3D).queue_free()
			_lot_nodes.erase(id)


func _lot_tag(lot: Dictionary) -> String:
	var p := works.catalog.part(String(lot.type))
	if String(lot.where) == RefurbWorks.AT_OUT:
		var rp := works.catalog.part(String(lot.result))
		return "%s %s  OK" % [rp.display_name if rp else lot.name, DesignGrades.label(rp) if rp else ""]
	return "%s %s  %d%%" % [lot.name, DesignGrades.label(p) if p else "", roundi(float(lot.condition) * 100.0)]


func _draw_cradle(i: int) -> void:
	var lot := works.lot_on(i)
	var lamp := _cradle_lamps[i]
	var light := _work_lights[i]
	var label := _cradle_labels[i]
	if lot.is_empty() or int(lot.stage) < 0:
		lamp.emission = Color(0.15, 0.15, 0.17)
		lamp.albedo_color = lamp.emission
		light.light_energy = 0.4
		label.text = "R%d\nFREE" % (i + 1) if lot.is_empty() else "R%d\nIN TRANSIT" % (i + 1)
		return
	var stage := int(lot.stage)
	var c := STAGE_COLOURS[stage]
	lamp.emission = c
	lamp.albedo_color = c
	light.light_color = Color(1.0, 0.92, 0.8)
	light.light_energy = 1.6
	if stage == RefurbWorks.Stage.REBUILD and fmod(_clock * 13.0, 1.0) < 0.5:
		light.light_color = Color(0.7, 0.85, 1.0)
		light.light_energy = 2.6
	var p := works.catalog.part(String(lot.type))
	var to := works.catalog.part(works.certified_type(String(lot.type)))
	label.text = "R%d  %s  %s > %s\n%s%s  %d%%   COND %d%%" % [i + 1, String(lot.name).to_upper(),
			DesignGrades.label(p) if p else "", DesignGrades.label(to) if to else "",
			RefurbWorks.STAGE_NAMES[stage], " (RETEST)" if bool(lot.retest) and stage == RefurbWorks.Stage.REBUILD else "",
			roundi(float(lot.progress) * 100.0), roundi(float(lot.condition) * 100.0)]


## The shop's board: what is on each cradle, waiting, ready, and the money.
func board_text() -> String:
	var lines: PackedStringArray = ["REFURB SHOP  ·  TARTANCO RF-2 REFURBISHERS"]
	for i in works.cradles.size():
		var lot := works.lot_on(i)
		var b: Dictionary = works.bots[i]
		var bot := "%s %3d%%%s" % [String(b.serial).get_slice("/", 1), roundi(float(b.charge) * 100.0), " CHG" if bool(b.charging) else ""]
		if lot.is_empty() or int(lot.stage) < 0:
			lines.append("R%d  %-20s %-12s %s" % [i + 1, "-", "", bot])
		else:
			lines.append("R%d  %-20s %-7s %3d%%  %s" % [i + 1, String(lot.name).left(20), RefurbWorks.STAGE_NAMES[int(lot.stage)], roundi(float(lot.progress) * 100.0), bot])
	var waiting := works.lots_at(RefurbWorks.AT_INTAKE).size() + works.backlog.size()
	lines.append("WAITING %d   CERTIFIED %d   SCRAPPED %d   SPENT %s cr" % [waiting, works.certified, works.scrapped, _money(works.spent)])
	var ready: PackedStringArray = []
	var keys: Array = works.stock.keys()
	keys.sort()
	for t: String in keys:
		var p := works.catalog.part(t)
		ready.append("%s %s x%d" % [p.display_name if p else t, DesignGrades.label(p) if p else "", int(works.stock[t])])
	lines.append("READY: " + (", ".join(ready.slice(0, 3)) + (" +%d more" % (ready.size() - 3) if ready.size() > 3 else "") if not ready.is_empty() else "nothing yet"))
	return "\n".join(lines)


static func _money(v: float) -> String:
	var s := str(absi(roundi(v)))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if v < 0.0 else "") + s + out


# --- Effects ------------------------------------------------------------------------------

func _make_fx(look: Node3D) -> Dictionary:
	var sparks := CPUParticles3D.new()
	sparks.emitting = false
	sparks.amount = 90
	sparks.lifetime = 0.7
	sparks.local_coords = false
	sparks.direction = Vector3(0, 0, 1)
	sparks.spread = 70.0
	sparks.initial_velocity_min = 1.5
	sparks.initial_velocity_max = 4.5
	sparks.gravity = Vector3.ZERO
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.0
	var sm := SphereMesh.new()
	sm.radius = 0.012
	sm.height = 0.024
	sm.radial_segments = 4
	sm.rings = 2
	sparks.mesh = sm
	sparks.material_override = Paint.glow(Color(1.0, 0.65, 0.25), 6.0, true)
	add_child(sparks)
	var grit := CPUParticles3D.new()
	grit.emitting = false
	grit.amount = 160
	grit.lifetime = 1.1
	grit.local_coords = false
	grit.direction = Vector3(0, 0, 1)
	grit.spread = 18.0
	grit.initial_velocity_min = 3.0
	grit.initial_velocity_max = 5.5
	grit.gravity = Vector3.ZERO
	grit.damping_min = 2.0
	grit.damping_max = 4.0
	grit.scale_amount_min = 0.6
	grit.scale_amount_max = 2.2
	var gm := QuadMesh.new()
	gm.size = Vector2(0.08, 0.08)
	grit.mesh = gm
	var gmat := Paint.haze(Color(0.55, 0.52, 0.46, 0.35))
	gmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	grit.material_override = gmat
	add_child(grit)
	var fan := MeshInstance3D.new()
	var fm := PrismMesh.new()
	fm.size = Vector3(0.9, 1.0, 0.01)
	fan.mesh = fm
	fan.material_override = Paint.haze(Color(0.25, 0.75, 1.0, 0.35))
	fan.visible = false
	add_child(fan)
	var hum := AudioStreamPlayer3D.new()
	hum.bus = Sfx.bus()
	hum.unit_size = 4.0
	hum.max_distance = 60.0
	hum.volume_db = -8.0
	add_child(hum)
	return {"sparks": sparks, "grit": grit, "fan": fan, "hum": hum, "sound": ""}


func _draw_fx(i: int, working: bool, tool_name: String, centre: Vector3, lot: Dictionary) -> void:
	var fx := _fx[i]
	var look := bots[i]
	var tip: Vector3 = look.get("tip")
	var aim := (centre - tip).normalized() if working and centre.is_finite() else Vector3.DOWN
	var sparks: CPUParticles3D = fx.sparks
	var grit: CPUParticles3D = fx.grit
	var fan: MeshInstance3D = fx.fan
	var sparking := working and tool_name in ["welder", "nut_runner"]
	sparks.emitting = sparking
	if sparking:
		# The sparks fly back off the part, the welder's thick, the nut runner's a fizz.
		sparks.global_position = tip + aim * 0.06
		sparks.direction = -aim
		sparks.amount = 90 if tool_name == "welder" else 24
		sparks.initial_velocity_max = 4.5 if tool_name == "welder" else 2.0
	grit.emitting = working and tool_name == "blaster"
	if grit.emitting:
		grit.global_position = tip
		grit.direction = aim
	fan.visible = working and tool_name == "scanner"
	if fan.visible:
		var d := tip.distance_to(centre)
		fan.global_transform = Transform3D(Basis.looking_at(aim, Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5), tip + aim * d * 0.5)
		fan.scale = Vector3(0.6 + 0.3 * sin(_clock * 3.0 + i), d, 1.0)
		fan.rotate_object_local(Vector3.UP, sin(_clock * 1.7 + i) * 0.6)
	# The tool's sound, while it works.
	var want := tool_name if working else ""
	var hum: AudioStreamPlayer3D = fx.hum
	if want != String(fx.sound):
		fx.sound = want
		if want == "":
			hum.stop()
		else:
			hum.stream = Sounds.stream(want)
			hum.volume_db = -14.0 if want == "scanner" else -8.0
			hum.play()
	if working:
		hum.global_position = tip


func _player(n: String) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = n
	p.bus = Sfx.bus()
	p.unit_size = 6.0
	p.max_distance = 80.0
	add_child(p)
	return p


# --- Lots ---------------------------------------------------------------------------------

## A second-hand part as drawn: Void Salvage's own model of it, weathered by its condition (the
## salvage surface's wear and grime), its glow showing once it is under test.
func _lot_node(lot: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.name = "Lot%d" % int(lot.id)
	add_child(n)
	var p := works.catalog.part(String(lot.type))
	var sp := p.shared_part if p else ""
	var shape: PartShapes.PartShape = VsParts.shape(sp) if sp != "" and VsParts.has(sp) else null
	var mat: ShaderMaterial
	var height := 1.0
	if shape and shape.mesh:
		mat = (VsParts.surface(sp).duplicate() as ShaderMaterial)
		var aabb := shape.mesh.get_aabb()
		var mi := MeshInstance3D.new()
		mi.mesh = shape.mesh
		mi.material_override = mat
		mi.position = -Vector3(aabb.get_center().x, aabb.position.y, aabb.get_center().z)
		n.add_child(mi)
		height = aabb.size.y
		if shape.glow:
			var g := MeshInstance3D.new()
			g.mesh = shape.glow
			g.material_override = VsParts.glow_material(shape.glow_color)
			g.position = mi.position
			g.visible = false
			n.add_child(g)
			n.set_meta("glow", g)
		n.set_meta("model_scale", (float(lot.h) / float(lot.fit)) / maxf(height, 0.01))
	else:
		# No Void Salvage model: a crated part of its size.
		var size := p.size if p else Vector3.ONE
		mat = (Paint.paint(Color(0.5, 0.52, 0.55), 0.5, 0.5, "galvanised").duplicate() as ShaderMaterial)
		Paint.box(n, size, Vector3(0, size.y * 0.5, 0), mat)
		height = size.y
		n.set_meta("model_scale", 1.0)
	n.set_meta("mat", mat)
	var alb: Variant = mat.get_shader_parameter("albedo")
	n.set_meta("albedo", Vector3(alb.r, alb.g, alb.b) if alb is Color else (alb as Vector3 if alb is Vector3 else Vector3(0.5, 0.5, 0.5)))
	n.set_meta("height", height)
	var tag := Paint.label(n, "", Vector3(0, height + 0.25, 0), 0.009, Color(1.0, 0.85, 0.4), 40)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = false
	n.set_meta("tag", tag)
	return n


# --- The shop's build ---------------------------------------------------------------------

func _build_deck() -> void:
	var deck := Paint.paint(Paint.DECK, 0.6, 0.55, "tread_diamond_steel")
	var trim := Paint.paint(Paint.TRIM, 0.4, 0.5, "gunmetal")
	var hazard := Paint.paint(Paint.HAZARD, 0.1, 0.6, "hazard_stripes")
	var body := StaticBody3D.new()
	body.name = "Body"
	add_child(body)
	_solid(body, Vector3(DECK_HALF.x * 2.0, 0.5, DECK_HALF.y * 2.0), Vector3(0, -0.25, 0), deck)
	Paint.box(self, Vector3(DECK_HALF.x * 2.0 + 0.3, 0.7, 0.3), Vector3(0, -0.36, DECK_HALF.y + 0.1), trim)
	Paint.box(self, Vector3(DECK_HALF.x * 2.0, 0.012, 0.4), Vector3(0, 0.006, DECK_HALF.y - 0.4), hazard)
	# The back wall: a frame with dark panels, the board on it, the shop's name over it.
	var wall_h := 12.5
	_solid(body, Vector3(DECK_HALF.x * 2.0, wall_h, 0.3), Vector3(0, wall_h * 0.5, BACK_Z), Paint.paint(Color(0.22, 0.23, 0.25), 0.4, 0.6))
	for x in range(-23, 24, 6):
		Paint.box(self, Vector3(0.35, wall_h + 0.3, 0.46), Vector3(x, wall_h * 0.5, BACK_Z + 0.12), Paint.paint(Paint.PLATES, 0.15, 0.45))
	Paint.box(self, Vector3(DECK_HALF.x * 2.0 + 0.4, 0.5, 0.6), Vector3(0, wall_h, BACK_Z + 0.1), Paint.paint(Paint.PLATES, 0.15, 0.45))
	Paint.label(self, "BSX LTD  ·  REFURB SHOP", Vector3(0, wall_h + 1.4, BACK_Z + 0.2), 0.03, Paint.BEAM_ORANGE, 96)
	# Under the deck: two trusses back to the berths' framework, and corner beacons.
	for x: float in [-16.0, 16.0]:
		Paint.box(self, Vector3(0.5, 0.5, 30.0), Vector3(x, -2.5, -18.0), trim).rotation.x = 0.16
	for x: float in [-DECK_HALF.x, DECK_HALF.x]:
		for z: float in [-DECK_HALF.y, DECK_HALF.y]:
			_beacons.append(Paint.box(self, Vector3(0.3, 0.3, 0.3), Vector3(x, 0.4, z), Paint.glow(Color(1.0, 0.25, 0.2), 6.0)))
	# Two floods over the deck.
	for x: float in [-11.0, 11.0]:
		var l := OmniLight3D.new()
		l.position = Vector3(x, 9.0, 4.0)
		l.omni_range = 20.0
		l.light_energy = 1.4
		l.light_color = Color(1.0, 0.95, 0.88)
		add_child(l)


func _solid(body: StaticBody3D, size: Vector3, at: Vector3, mat: Material) -> void:
	Paint.box(self, size, at, mat)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = at
	body.add_child(cs)


func _build_cradle(i: int) -> void:
	var at := works.cradle_point(i)
	var trim := Paint.paint(Paint.TRIM, 0.4, 0.5, "gunmetal")
	var ochre := Paint.paint(Paint.OCHRE, 0.2, 0.5)
	var steel := Paint.paint(Paint.STEEL, 0.8, 0.35, "brushed_steel")
	Paint.box(self, Vector3(3.0, at.y - 0.2, 3.0), Vector3(at.x, (at.y - 0.2) * 0.5, 0), trim)
	Paint.box(self, Vector3(3.2, 0.2, 3.2), Vector3(at.x, at.y - 0.1, 0), steel)
	for s: float in [-1.0, 1.0]:
		Paint.box(self, Vector3(2.4, 0.3, 0.35), Vector3(at.x, at.y + 0.05, s * 0.9), ochre)
	# The arch over it, with the work lamp and the stage lamp.
	for s: float in [-1.0, 1.0]:
		Paint.box(self, Vector3(0.3, 5.4, 0.3), Vector3(at.x + s * 2.9, 2.7, -1.6), Paint.paint(Paint.PLATES, 0.15, 0.45))
	Paint.box(self, Vector3(6.16, 0.35, 0.35), Vector3(at.x, 5.4, -1.6), Paint.paint(Paint.PLATES, 0.15, 0.45))
	Paint.box(self, Vector3(0.6, 0.25, 1.4), Vector3(at.x, 5.15, -1.0), trim)
	var lamp := StandardMaterial3D.new()
	lamp.emission_enabled = true
	lamp.emission_energy_multiplier = 4.0
	lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	Paint.box(self, Vector3(1.2, 0.12, 0.12), Vector3(at.x, 5.4, -1.42), lamp)
	_cradle_lamps.append(lamp)
	var light := OmniLight3D.new()
	light.position = Vector3(at.x, 4.9, -0.4)
	light.omni_range = 9.0
	add_child(light)
	_work_lights.append(light)
	var l := Paint.label(self, "", Vector3(at.x, 6.15, -1.4), 0.0065, Color(1.0, 0.85, 0.4), 48)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cradle_labels.append(l)
	Paint.label(self, "R%d" % (i + 1), Vector3(at.x, 0.8, 1.52), 0.02, Paint.BEAM_ORANGE, 64)


func _build_dock(i: int) -> void:
	var at := works.dock_point(i)
	var trim := Paint.paint(Paint.TRIM, 0.4, 0.5, "gunmetal")
	Paint.box(self, Vector3(0.25, at.y - 0.4, 0.25), Vector3(at.x, (at.y - 0.4) * 0.5, at.z - 0.55), trim)
	Paint.box(self, Vector3(1.0, 0.18, 0.5), Vector3(at.x, at.y - 0.45, at.z - 0.35), Paint.paint(Paint.OCHRE, 0.2, 0.5))
	Paint.box(self, Vector3(0.2, 0.2, 0.06), Vector3(at.x + 0.6, at.y - 0.45, at.z - 0.08), Paint.glow(Color(0.3, 1.0, 0.45), 3.0))
	Paint.label(self, "D%d" % (i + 1), Vector3(at.x, at.y - 0.9, at.z - 0.4), 0.008, Color(0.9, 0.9, 0.9), 48)


func _build_rack(out: bool) -> void:
	var x := RefurbWorks.RACK_X * (1.0 if out else -1.0)
	var blue := Paint.paint(Paint.RACK_BLUE, 0.3, 0.4, "enamel")
	var orange := Paint.paint(Paint.BEAM_ORANGE, 0.2, 0.45, "enamel")
	var board := Paint.paint(Color(0.5, 0.52, 0.55), 0.7, 0.45, "galvanised")
	for sx: float in [-1.4, 1.4]:
		for z: float in [-6.0, -2.0, 2.0, 6.0]:
			Paint.box(self, Vector3(0.14, 6.6, 0.14), Vector3(x + sx, 3.3, z), blue)
	for y: float in RefurbWorks.RACK_LEVELS:
		Paint.box(self, Vector3(2.9, 0.08, 12.2), Vector3(x, y - 0.04, 0), board)
		for sx: float in [-1.4, 1.4]:
			Paint.box(self, Vector3(0.12, 0.16, 12.2), Vector3(x + sx, y - 0.12, 0), orange)
	Paint.label(self, "REFURBISHED" if out else "SECOND-HAND IN", Vector3(x, 7.2, 0.5), 0.016, Paint.BEAM_ORANGE, 96)


func _build_scrap_bin() -> void:
	var at := RefurbWorks.SCRAP_AT
	var trim := Paint.paint(Color(0.3, 0.28, 0.25), 0.6, 0.7, "rust")
	Paint.box(self, Vector3(2.6, 0.1, 2.0), Vector3(at.x, 0.05, at.z), trim)
	for s: float in [-1.0, 1.0]:
		Paint.box(self, Vector3(2.6, 1.1, 0.08), Vector3(at.x, 0.55, at.z + s * 1.0), trim)
		Paint.box(self, Vector3(0.08, 1.1, 2.0), Vector3(at.x + s * 1.3, 0.55, at.z), trim)
	Paint.label(self, "SCRAP", Vector3(at.x, 1.2, at.z + 1.06), 0.012, Paint.HAZARD, 64)


func _build_board() -> void:
	Paint.box(self, Vector3(17.0, 4.8, 0.12), Vector3(0, 9.3, BACK_Z + 0.22), Paint.glow(Color(0.02, 0.03, 0.05), 0.5))
	_board = Paint.label(self, "", Vector3(-8.0, 9.3, BACK_Z + 0.3), 0.01, Color(0.45, 0.95, 1.0), 48)
	_board.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_board.width = 1600.0
	_board.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Consolas", "Courier New", "monospace"])
	_board.font = mono
	_board.text = board_text()


## The used-parts dealer's tug: a stubby courier with a cargo cage, its name on its flank.
func _build_dealer() -> void:
	_dealer = Node3D.new()
	_dealer.name = "DealerTug"
	add_child(_dealer)
	var hull := Paint.paint(Color(0.42, 0.36, 0.3), 0.4, 0.6, "satin_paint")
	var trim := Paint.paint(Paint.TRIM, 0.4, 0.5, "gunmetal")
	Paint.box(_dealer, Vector3(5.0, 1.8, 3.0), Vector3(0, 1.0, 0), hull)
	Paint.box(_dealer, Vector3(1.6, 1.2, 2.4), Vector3(-3.0, 1.2, 0), trim)
	Paint.box(_dealer, Vector3(0.05, 0.4, 2.0), Vector3(-3.81, 1.4, 0), Paint.glow(Color(0.4, 0.8, 1.0), 3.0))
	for s: float in [-1.0, 1.0]:
		Paint.rod(_dealer, 0.45, 1.2, Vector3(3.0, 1.0, s * 1.0), trim, Basis(Vector3.FORWARD, PI * 0.5))
		Paint.rod(_dealer, 0.35, 0.05, Vector3(3.62, 1.0, s * 1.0), Paint.glow(Color(1.0, 0.55, 0.2), 5.0), Basis(Vector3.FORWARD, PI * 0.5))
	# The cage it drops lots from, under its belly.
	for x: float in [-2.0, 2.0]:
		for z: float in [-1.3, 1.3]:
			Paint.box(_dealer, Vector3(0.1, 1.6, 0.1), Vector3(x, -0.6, z), trim)
	var name_l := Paint.label(_dealer, "KETTLEMOOR SALVAGE", Vector3(0.4, 1.3, 1.52), 0.01, Color(1.0, 0.85, 0.4), 64)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dealer.visible = false


## Camera spots for shots (global): name -> [from, look at].
func view_points() -> Dictionary:
	return {
		"refurb_shop": [to_global(Vector3(3, 8, 23)), to_global(Vector3(0, 3.5, -2))],
		"refurb_cradle": [to_global(Vector3(-3.0, 4.2, 7.5)), to_global(Vector3(-7.0, 2.2, -0.5))],
		"refurb_racks": [to_global(Vector3(-10, 6.5, 14)), to_global(Vector3(-18, 2.5, 0))],
	}
