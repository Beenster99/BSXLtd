extends Node3D
## The refurb works (beenster, 19 Nov; 0.4.4 playtest: "move refurbishing unit to an annex of the
## main hall"): an annex behind the stores hall (YardLayout.ROOMS.refurb, x 48..84, z -4..26),
## through a big door from goods in. Inside: the intake rollers along the hall wall, four
## light-line cradles each with its RF-2, the heavy stand under an overhead crane for big parts
## (a team of RF-2H heavy bots and any idle RF-2s works them), the refurbished rack on the west
## wall, the heavy out bay, the scrap skip, the drones' charger rack on the back wall and the
## works' board over it. The goods-in cart brings second-hand parts through from the hall.
## The station builds the annex's floor, roof and ceiling with its other rooms; this builds its
## walls and everything in it.
##
## The state is a RefurbWorks, stepped here on the yard's shared clock: fixed ticks from the
## yard's epoch, with what players asked for ("refurb.in", "refurb.take" in the yard's log)
## applied at its tick, so every PC draws the same works. Everything else here only draws it.

const Paint := preload("res://modules/refurb/internal/refurb_paint.gd")
const BotLook := preload("res://modules/refurb/internal/refurb_bot_look.gd")
const Sounds := preload("res://modules/refurb/internal/refurb_sounds.gd")

const TICK := 1.0 / 60.0
const FRAME_BUDGET_MS := 6.0
const CATCH_UP_BUDGET_MS := 30.0
const HALF := Vector2(18.0, 15.0)
const WALL_T := 0.2
const WALL_TOP := 15.98
const STAGE_COLOURS: Array[Color] = [Color(0.3, 0.75, 1.0), Color(1.0, 0.6, 0.15), Color(0.85, 0.8, 0.6),
		Color(1.0, 0.45, 0.1), Color(0.3, 1.0, 0.45), Color(1.0, 0.25, 0.15)]
## The crane's runway rails (z of each, their top) and the bridge girder's middle height.
const RAIL_Z := 14.25
const RAIL_TOP := 14.55
const BRIDGE_Y := 14.95
const TROLLEY_Y := 14.35
const HULL_WHITE := Color(0.86, 0.87, 0.88)
## The scrap skip shows its newest this many lots.
const SKIP_SHOWS := 8

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
var _charger_lamps: Array[StandardMaterial3D] = []
var _board: Label3D
var _board_t := 0.0
var _fx: Array[Dictionary] = []
var _cart: Node3D
var _cart_beacon: MeshInstance3D
var _cart_yaw := 0.0
var _bridge: Node3D
var _trolley: Node3D
var _hook: Node3D
var _cable: MeshInstance3D
var _slings: Array[MeshInstance3D] = []
var _crane_beacon: MeshInstance3D
var _crane_hum: AudioStreamPlayer3D
var _cart_beep: AudioStreamPlayer3D
var _jingle: AudioStreamPlayer3D
var _clang: AudioStreamPlayer3D
var _clock := 0.0


## `bus`: the RefurbBus (signals go out through it); `yard`: the YardBus whose clock and log the
## works follows (null: a local clock, for captures and tests).
func setup(bus: Node, yard: Node, w: RefurbWorks) -> void:
	_bus = bus
	_yard = yard
	works = w
	name = "RefurbShop"
	_build_walls()
	for i in works.light_count():
		_build_cradle(i)
	_build_heavy_stand()
	_build_rollers()
	_build_out_rack()
	_build_charger_rack()
	_build_scrap_skip()
	_build_board()
	_build_crane()
	_build_cart()
	for b in works.bots:
		var look: Node3D = BotLook.new()
		add_child(look)
		look.call("build", String(b.serial), String(b.role) == "heavy")
		look.position = b.pos
		bots.append(look)
		_fx.append(_make_fx(look))
	_jingle = _player("Chime")
	_clang = _player("Clang")
	_crane_hum = _player("CraneHum")
	_cart_beep = _player("CartBeep")
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


## The yard's clock started again: an empty works from tick 0, the log replayed.
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


## One tick: the requests due, then the works moved on.
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


## Runs the works on by `seconds` straight away, off the shared clock (captures only).
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
	if not is_inside_tree() or lot.is_empty():
		return
	var at := to_global((lot.pos as Vector3) + Vector3(0, float(lot.h) * 0.5, 0))
	match String(ev.kind):
		"certified":
			_play(_jingle, "chime", at)
		"retest":
			_play(_jingle, "buzz", at)
		"scrapped", "set":
			_play(_clang, "clang", at)
		"unloaded":
			_play(_clang, "thunk", at)


func _play(p: AudioStreamPlayer3D, sound: String, at: Vector3) -> void:
	p.global_position = at
	p.stream = Sounds.stream(sound)
	p.play()


# --- Drawing ------------------------------------------------------------------------------

func draw(delta: float) -> void:
	_clock += delta
	for i in bots.size():
		_draw_bot(i, delta)
	_draw_lots()
	for i in works.cradles.size():
		_draw_cradle(i)
	_draw_crane()
	_draw_cart(delta)
	_draw_chargers()
	_board_t -= delta
	if _board_t <= 0.0:
		_board_t = 0.5
		_board.text = board_text()


## A lot's box as drawn (local: its bottom middle and half sizes, turned by its rot).
func _lot_box(lot: Dictionary) -> AABB:
	var d: Vector3 = lot.dims
	var f := works.draw_fit(lot)
	var s := absf(sin(float(lot.rot)))
	var hx := lerpf(d.x, d.z, s) * 0.5 * f
	var hz := lerpf(d.z, d.x, s) * 0.5 * f
	var p: Vector3 = lot.pos
	return AABB(Vector3(p.x - hx, p.y, p.z - hz), Vector3(hx * 2.0, float(lot.h) * f, hz * 2.0))


func _draw_bot(i: int, delta: float) -> void:
	var b: Dictionary = works.bots[i]
	var look := bots[i]
	var lot: Dictionary = works.lots.get(int(b.lot), {})
	var state := String(b.state)
	var working := state == RefurbWorks.BOT_WORK and not lot.is_empty()
	var face: Vector3 = to_global(b.target)
	var work := Vector3.INF
	var centre := Vector3.INF
	if working:
		# It faces the part and its tool reaches for the part's surface nearest it.
		var box := _lot_box(lot)
		var p: Vector3 = b.pos
		var near := Vector3(clampf(p.x, box.position.x, box.end.x), clampf(p.y, box.position.y, box.end.y), clampf(p.z, box.position.z, box.end.z))
		centre = to_global(box.get_center())
		face = to_global(near)
		work = to_global(near) + Vector3(sin(_clock * 2.3 + i), cos(_clock * 1.9 + i * 2.0), sin(_clock * 1.3 + i)) * 0.07
	elif state in [RefurbWorks.BOT_DOCK, RefurbWorks.BOT_RETURN] and (b.pos as Vector3).distance_to(works.dock_point(i)) < 1.5:
		face = to_global((b.pos as Vector3) + Vector3(0, 0, -5.0))
	var hold := Vector3.INF
	if state in [RefurbWorks.BOT_CARRY, RefurbWorks.BOT_STOW] and not lot.is_empty():
		var box := _lot_box(lot)
		hold = to_global(Vector3(box.get_center().x, box.end.y, box.get_center().z))
	var moving := (look.position - (b.pos as Vector3)).length() / maxf(delta, 0.001)
	var docked := state == RefurbWorks.BOT_DOCK and (b.pos as Vector3).distance_to(works.dock_point(i)) < 0.05
	look.call("pose", to_global(b.pos), face, work, hold, float(b.charge), bool(b.charging), String(b.tool), delta, docked)
	look.call("thrust", clampf(moving / 3.0, 0.0, 1.0))
	_draw_fx(i, working, String(b.tool), centre, work)


func _draw_lots() -> void:
	var seen := {}
	var scrap := works.lots_at(RefurbWorks.AT_SCRAP)
	var hidden := {}
	for k in maxi(0, scrap.size() - SKIP_SHOWS):
		hidden[int(scrap[k].id)] = true
	for id: int in works.lots:
		var lot: Dictionary = works.lots[id]
		var where := String(lot.where)
		if where in [RefurbWorks.AT_BACKLOG, RefurbWorks.AT_STORES] or hidden.has(id):
			continue
		seen[id] = true
		var n: Node3D = _lot_nodes.get(id)
		if n == null:
			n = _lot_node(lot)
			_lot_nodes[id] = n
		var fit := works.draw_fit(lot)
		n.position = lot.pos
		n.basis = Basis(Vector3.UP, float(lot.yaw) + float(lot.rot)).scaled(Vector3.ONE * fit * float(n.get_meta("model_scale", 1.0)))
		var mat: ShaderMaterial = n.get_meta("mat")
		var wear := 1.0 - float(lot.condition)
		var clean: Vector3 = n.get_meta("albedo")
		var g := clampf(float(lot.grime), 0.0, 1.0)
		var scorched := 0.6 if int(lot.stage) == RefurbWorks.Stage.CUT or where == RefurbWorks.AT_SCRAP else 0.0
		mat.set_shader_parameter("albedo", clean.lerp(Vector3(0.09, 0.06, 0.035), g * 0.65))
		mat.set_shader_parameter("condition", Vector4(clampf(wear * 1.1, 0.0, 1.0), clampf(float(lot.grime) * 0.9, 0.0, 1.0), 3.0 + scorched, float(id % 17) * 0.13))
		var glow: Node3D = n.get_meta("glow") if n.has_meta("glow") else null
		if glow:
			glow.visible = int(lot.stage) == RefurbWorks.Stage.TEST or where == RefurbWorks.AT_OUT
		var tag: Label3D = n.get_meta("tag")
		tag.visible = where in [RefurbWorks.AT_INTAKE, RefurbWorks.AT_OUT, RefurbWorks.AT_CART] or (where == RefurbWorks.AT_CRANE and String(lot.result) != "scrap")
		tag.text = _lot_tag(lot)
		var s := maxf(n.basis.get_scale().x, 0.05)
		tag.position = Vector3(0, float(n.get_meta("height")) + 0.3 / s, 0)
		tag.scale = Vector3.ONE / s
	for id: int in _lot_nodes.keys():
		if not seen.has(id):
			(_lot_nodes[id] as Node3D).queue_free()
			_lot_nodes.erase(id)


func _lot_tag(lot: Dictionary) -> String:
	var p := works.catalog.part(String(lot.type))
	if String(lot.where) == RefurbWorks.AT_OUT or (String(lot.result) != "" and String(lot.result) != "scrap"):
		var rp := works.catalog.part(String(lot.result))
		return "%s %s  OK" % [rp.display_name if rp else lot.name, DesignGrades.label(rp) if rp else ""]
	return "%s %s  %d%%" % [lot.name, DesignGrades.label(p) if p else "", roundi(float(lot.condition) * 100.0)]


func _draw_cradle(i: int) -> void:
	var lot := works.lot_on(i)
	var lamp := _cradle_lamps[i]
	var light := _work_lights[i]
	var label := _cradle_labels[i]
	var heavy := i == works.heavy_index()
	var title := "HEAVY STAND" if heavy else "R%d" % (i + 1)
	if lot.is_empty() or int(lot.stage) < 0 or String(lot.where) != RefurbWorks.AT_CRADLE:
		lamp.emission = Color(0.15, 0.15, 0.17)
		lamp.albedo_color = lamp.emission
		light.light_energy = 0.5
		if lot.is_empty():
			label.text = "%s\nFREE" % title
		elif String(lot.where) == RefurbWorks.AT_CRADLE:
			label.text = "%s  %s\n%s" % [title, String(lot.name).to_upper(), "CUT UP · FOR THE SKIP" if String(lot.result) == "scrap" else "CERTIFIED · FOR THE CRANE"]
		else:
			label.text = "%s\n%s ON ITS WAY" % [title, String(lot.name).to_upper()]
		return
	var stage := int(lot.stage)
	var c := STAGE_COLOURS[stage]
	lamp.emission = c
	lamp.albedo_color = c
	light.light_color = Color(1.0, 0.92, 0.8)
	light.light_energy = 2.4 if heavy else 1.6
	if stage in [RefurbWorks.Stage.REBUILD, RefurbWorks.Stage.CUT] and fmod(_clock * 13.0, 1.0) < 0.5:
		light.light_color = Color(0.7, 0.85, 1.0) if stage == RefurbWorks.Stage.REBUILD else Color(1.0, 0.6, 0.3)
		light.light_energy *= 1.6
	var p := works.catalog.part(String(lot.type))
	var to := works.catalog.part(works.certified_type(String(lot.type)))
	var team := " · TEAM OF %d" % works.heavy_team(int(lot.id)).size() if heavy else ""
	label.text = "%s  %s  %s > %s\n%s%s  %d%%   COND %d%%%s" % [title, String(lot.name).to_upper(),
			DesignGrades.label(p) if p else "", DesignGrades.label(to) if to else "",
			RefurbWorks.STAGE_NAMES[stage], " (RETEST)" if bool(lot.retest) and stage == RefurbWorks.Stage.REBUILD else "",
			roundi(float(lot.progress) * 100.0), roundi(float(lot.condition) * 100.0), team]


func _draw_crane() -> void:
	var k: Dictionary = works.crane
	var hook: Vector3 = k.hook
	_bridge.position.x = hook.x
	_trolley.position.z = hook.z
	_hook.position = hook
	var top := TROLLEY_Y - 0.35
	var len := maxf(top - (hook.y + 0.8), 0.05)
	_cable.position = Vector3(hook.x, top - len * 0.5, hook.z)
	_cable.scale = Vector3(1.0, len, 1.0)
	var lot: Dictionary = works.lots.get(int(k.lot), {})
	var slung := not lot.is_empty() and String(k.phase) in ["sling", "lift", "carry", "set", "unsling"]
	for j in _slings.size():
		_slings[j].visible = slung
	if slung:
		var box := _lot_box(lot)
		var corners := [Vector3(box.position.x, box.end.y, box.position.z), Vector3(box.end.x, box.end.y, box.position.z),
				Vector3(box.position.x, box.end.y, box.end.z), Vector3(box.end.x, box.end.y, box.end.z)]
		for j in 4:
			var from: Vector3 = hook
			var to: Vector3 = corners[j]
			var gap := to - from
			_slings[j].position = from + gap * 0.5
			_slings[j].basis = _along(gap).scaled(Vector3(1.0, gap.length(), 1.0))
	var moving := String(k.phase) not in ["idle", "sling", "unsling"]
	_crane_beacon.visible = moving and fmod(_clock, 0.8) < 0.4
	if moving and not _crane_hum.playing:
		_crane_hum.stream = Sounds.stream("crane")
		_crane_hum.play()
	elif not moving and _crane_hum.playing:
		_crane_hum.stop()
	if moving:
		_crane_hum.global_position = to_global(Vector3(hook.x, TROLLEY_Y, hook.z))


## A basis whose +Y runs along `v` (a rod from one point to another).
static func _along(v: Vector3) -> Basis:
	var y := v.normalized() if v.length() > 0.0001 else Vector3.UP
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))


func _draw_cart(delta: float) -> void:
	var c: Dictionary = works.cart
	_cart.position = c.pos
	_cart_yaw = lerp_angle(_cart_yaw, float(c.yaw), clampf(delta * 4.0, 0.0, 1.0))
	_cart.basis = Basis(Vector3.UP, _cart_yaw)
	var moving := String(c.phase) in ["out", "in", "back"]
	_cart_beacon.visible = (moving or String(c.phase) in ["load", "unload"]) and fmod(_clock, 0.6) < 0.3
	var reversing := String(c.phase) == "back" and not (c.path as Array).is_empty() and (c.path as Array).size() > 1
	if reversing and not _cart_beep.playing:
		_cart_beep.stream = Sounds.stream("beep")
		_cart_beep.play()
	elif not reversing and _cart_beep.playing:
		_cart_beep.stop()
	if reversing:
		_cart_beep.global_position = _cart.global_position + Vector3(0, 1.0, 0)


func _draw_chargers() -> void:
	for i in _charger_lamps.size():
		var lamp := _charger_lamps[i]
		var c := Color(0.12, 0.12, 0.13)
		if i < works.bots.size():
			var b: Dictionary = works.bots[i]
			var home := (b.pos as Vector3).distance_to(works.dock_point(i)) < 0.05
			if home and bool(b.charging):
				c = Color(1.0, 0.65, 0.1) if fmod(_clock + i * 0.3, 1.0) < 0.6 else Color(0.3, 0.18, 0.04)
			elif home:
				c = Color(0.25, 1.0, 0.4)
			else:
				c = Color(0.3, 0.6, 1.0) * 0.5
		lamp.albedo_color = c
		lamp.emission = c


## The works' board: what is on each cradle and the heavy stand, the crane and cart, what is
## waiting, ready, and the money.
func board_text() -> String:
	var lines: PackedStringArray = ["REFURB WORKS  ·  TARTANCO RF-2 / RF-2H REFURBISHERS"]
	for i in works.light_count():
		var lot := works.lot_on(i)
		var b: Dictionary = works.bots[i]
		var bot := "%s %3d%%%s" % [String(b.serial).get_slice("/", 1), roundi(float(b.charge) * 100.0), " CHG" if bool(b.charging) else ""]
		if lot.is_empty() or int(lot.stage) < 0:
			lines.append("R%d  %-20s %-12s %s" % [i + 1, "-", "", bot])
		else:
			lines.append("R%d  %-20s %-7s %3d%%  %s" % [i + 1, String(lot.name).left(20), RefurbWorks.STAGE_NAMES[int(lot.stage)], roundi(float(lot.progress) * 100.0), bot])
	var h := works.lot_on(works.heavy_index())
	if h.is_empty():
		lines.append("HV  %-20s" % "-")
	elif int(h.stage) < 0:
		lines.append("HV  %-20s ON THE CRANE" % String(h.name).left(20))
	else:
		lines.append("HV  %-20s %-7s %3d%%  TEAM %d" % [String(h.name).left(20), RefurbWorks.STAGE_NAMES[int(h.stage)], roundi(float(h.progress) * 100.0), works.heavy_team(int(h.id)).size()])
	var waiting := works.lots_at(RefurbWorks.AT_INTAKE).size() + works.backlog.size() + works.lots_at(RefurbWorks.AT_CART).size()
	lines.append("GOODS IN %d   ON ROLLERS %d   CRANE %s   CART %s" % [works.backlog.size(), works.lots_at(RefurbWorks.AT_INTAKE).size(),
			String(works.crane.phase).to_upper(), String(works.cart.phase).to_upper()])
	lines.append("WAITING %d   CERTIFIED %d   SCRAPPED %d   SPENT %s" % [waiting, works.certified, works.scrapped, _money(works.spent)])
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
	sparks.gravity = Vector3(0, -6.0, 0)
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
	grit.gravity = Vector3(0, -1.5, 0)
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
	fan.set_meta("gfx_coplanar_ok", true)
	add_child(fan)
	var flare := OmniLight3D.new()
	flare.light_color = Color(0.75, 0.85, 1.0)
	flare.omni_range = 3.5
	flare.light_energy = 0.0
	flare.shadow_enabled = false
	add_child(flare)
	var hum := AudioStreamPlayer3D.new()
	hum.bus = Sfx.bus()
	hum.unit_size = 4.0
	hum.max_distance = 60.0
	hum.volume_db = -8.0
	add_child(hum)
	return {"sparks": sparks, "grit": grit, "fan": fan, "flare": flare, "hum": hum, "sound": ""}


func _draw_fx(i: int, working: bool, tool_name: String, centre: Vector3, work: Vector3) -> void:
	var fx := _fx[i]
	var look := bots[i]
	var tip: Vector3 = look.get("tip")
	var aim := (work - tip).normalized() if working and work.is_finite() and work.distance_to(tip) > 0.01 else Vector3.DOWN
	var sparks: CPUParticles3D = fx.sparks
	var grit: CPUParticles3D = fx.grit
	var fan: MeshInstance3D = fx.fan
	var flare: OmniLight3D = fx.flare
	var sparking := working and tool_name in ["welder", "nut_runner", "cutter"]
	sparks.emitting = sparking
	if sparking:
		# The sparks fly back off the part: the cutter's a shower, the welder's thick, the nut
		# runner's a fizz.
		sparks.global_position = tip + aim * 0.06
		sparks.direction = -aim
		sparks.amount = 160 if tool_name == "cutter" else (90 if tool_name == "welder" else 24)
		sparks.initial_velocity_max = 6.5 if tool_name == "cutter" else (4.5 if tool_name == "welder" else 2.0)
	var arc := working and tool_name in ["welder", "cutter"]
	flare.light_energy = (1.2 + 0.8 * sin(_clock * 40.0 + i)) if arc else 0.0
	flare.light_color = Color(0.75, 0.85, 1.0) if tool_name == "welder" else Color(1.0, 0.6, 0.3)
	if arc:
		flare.global_position = tip
	grit.emitting = working and tool_name == "blaster"
	if grit.emitting:
		grit.global_position = tip
		grit.direction = aim
	fan.visible = working and tool_name == "scanner" and centre.is_finite()
	if fan.visible:
		var d := maxf(tip.distance_to(centre), 0.3)
		var to_c := (centre - tip).normalized()
		fan.global_transform = Transform3D(Basis.looking_at(to_c, Vector3.UP if absf(to_c.y) < 0.95 else Vector3.RIGHT) * Basis(Vector3.RIGHT, -PI * 0.5), tip + to_c * d * 0.5)
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
			g.set_meta("gfx_coplanar_ok", true)
			n.add_child(g)
			n.set_meta("glow", g)
		n.set_meta("model_scale", float(lot.h) / maxf(height, 0.01))
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


# --- The annex's build --------------------------------------------------------------------

## The annex's walls (the station lays its floor, roof and ceiling): west, east and back, inside
## the room's edges like the station's own, the hall's back wall closing the front. Signs over
## the door both sides, floor markings, the crane's runway, ceiling lamps.
func _build_walls() -> void:
	var wall := Paint.paint(Color(0.7, 0.72, 0.75), 0.15, 0.6, "satin_paint")
	var dark := Paint.paint(Paint.TRIM, 0.6, 0.45, "gunmetal")
	var orange := Paint.paint(Paint.BEAM_ORANGE, 0.1, 0.4, "enamel")
	var yellow := Paint.paint(Paint.HAZARD, 0.1, 0.6, "enamel")
	var body := StaticBody3D.new()
	body.name = "Body"
	add_child(body)
	var front := -HALF.y + 0.1
	_solid(body, Vector3(WALL_T, WALL_TOP, HALF.y - front + WALL_T * 0.5), Vector3(-HALF.x, WALL_TOP * 0.5, (front + HALF.y + WALL_T * 0.5) * 0.5), wall)
	_solid(body, Vector3(WALL_T, WALL_TOP, HALF.y - front + WALL_T * 0.5), Vector3(HALF.x, WALL_TOP * 0.5, (front + HALF.y + WALL_T * 0.5) * 0.5), wall)
	_solid(body, Vector3(HALF.x * 2.0 - WALL_T, WALL_TOP, WALL_T), Vector3(0, WALL_TOP * 0.5, HALF.y), wall)
	# A dado of dark panels round the walls' feet, and pilasters up them every six metres.
	for side: float in [-1.0, 1.0]:
		Paint.box(self, Vector3(0.06, 1.2, HALF.y * 2.0 - 0.6), Vector3(side * (HALF.x - WALL_T * 0.5 - 0.03), 0.6, 0.15), dark)
		for z in range(-12, 15, 6):
			Paint.box(self, Vector3(0.24, WALL_TOP - 0.2, 0.4), Vector3(side * (HALF.x - WALL_T * 0.5 - 0.12), (WALL_TOP - 0.2) * 0.5, z + 0.5), Paint.paint(HULL_WHITE, 0.15, 0.5))
	Paint.box(self, Vector3(HALF.x * 2.0 - 0.6, 1.2, 0.06), Vector3(0, 0.6, HALF.y - WALL_T * 0.5 - 0.03), dark)
	# The door from the hall: an orange frame on this side, hazard stripes on its floor.
	var door := RefurbWorks.DOOR_X
	for x: float in [door.x, door.y]:
		Paint.box(self, Vector3(0.5, RefurbWorks.DOOR_H, 0.3), Vector3(x + (-0.25 if x == door.x else 0.25), RefurbWorks.DOOR_H * 0.5, -HALF.y + 0.25), orange)
	Paint.box(self, Vector3(door.y - door.x + 1.0, 0.5, 0.3), Vector3((door.x + door.y) * 0.5, RefurbWorks.DOOR_H + 0.25, -HALF.y + 0.25), orange)
	Paint.box(self, Vector3(door.y - door.x, 0.012, 0.6), Vector3((door.x + door.y) * 0.5, 0.006, -HALF.y + 0.5), Paint.paint(Paint.HAZARD, 0.1, 0.6, "hazard_stripes"))
	Paint.label(self, "BSX LTD  ·  REFURB WORKS", Vector3((door.x + door.y) * 0.5, RefurbWorks.DOOR_H + 1.9, -HALF.y - 0.13), 0.012, Paint.BEAM_ORANGE, 96, Vector3.FORWARD)
	Paint.label(self, "SECOND-HAND PARTS IN  ·  CERTIFIED PARTS OUT", Vector3((door.x + door.y) * 0.5, RefurbWorks.DOOR_H + 0.8, -HALF.y - 0.13), 0.008, Color(0.95, 0.95, 0.95), 64, Vector3.FORWARD)
	Paint.label(self, "TO STORES · GOODS IN", Vector3((door.x + door.y) * 0.5, RefurbWorks.DOOR_H + 1.0, -HALF.y + 0.42), 0.014, Paint.BEAM_ORANGE, 64)
	# The cart's lane, painted on the floor, and the light line's walkway.
	_lane(Vector3(3.8, 0, -14.7), Vector3(3.8, 0, -11.3), yellow)
	_lane(Vector3(3.8, 0, -11.3), Vector3(-9.8, 0, -11.3), yellow)
	_lane(Vector3(9.0, 0, -14.7), Vector3(9.0, 0, -9.6), yellow)
	# The crane's runway: a rail along each long wall on brackets, a buffer at each end.
	for side: float in [-1.0, 1.0]:
		var z := side * RAIL_Z
		Paint.box(self, Vector3(HALF.x * 2.0 - 0.4, 0.3, 0.5), Vector3(0, RAIL_TOP - 0.15, z), Paint.paint(Paint.HAZARD, 0.2, 0.5, "enamel"))
		Paint.box(self, Vector3(HALF.x * 2.0 - 0.4, 0.08, 0.12), Vector3(0, RAIL_TOP + 0.04, z), Paint.paint(Paint.STEEL, 0.85, 0.3, "brushed_steel"))
		for x in range(-15, 17, 5):
			Paint.box(self, Vector3(0.3, 0.9, absf(HALF.y - absf(z)) - WALL_T * 0.5 + 0.25), Vector3(x + 0.5, RAIL_TOP - 0.75, side * (RAIL_Z + (HALF.y - RAIL_Z) * 0.5 - 0.02)), dark)
		for x: float in [-HALF.x + 0.45, HALF.x - 0.45]:
			Paint.box(self, Vector3(0.3, 0.5, 0.42), Vector3(x, RAIL_TOP + 0.3, z), Paint.paint(Color(0.15, 0.15, 0.16), 0.2, 0.7))
	# Ceiling lamps over the light line and the heavy stand.
	for x: float in [-13.5, -5.5]:
		_ceiling_lamp(Vector3(x, 0, 2.0))
	for x: float in [5.0, 13.0]:
		_ceiling_lamp(Vector3(x, 0, -6.0))
		_ceiling_lamp(Vector3(x, 0, 9.0))
	_ceiling_lamp(Vector3(-9.0, 0, -9.0))


func _ceiling_lamp(at: Vector3) -> void:
	Paint.box(self, Vector3(2.2, 0.08, 0.7), Vector3(at.x, 15.92, at.z), Paint.paint(Paint.TRIM, 0.6, 0.45, "gunmetal"))
	var panel := Paint.box(self, Vector3(2.0, 0.02, 0.5), Vector3(at.x, 15.87, at.z), Paint.glow(Color(1.0, 0.96, 0.88), 3.0))
	panel.set_meta("gfx_coplanar_ok", true)


func _lane(a: Vector3, b: Vector3, mat: Material) -> void:
	var along_x := absf(b.x - a.x) > absf(b.z - a.z)
	var len := (b - a).length() + 0.15
	var mid := (a + b) * 0.5
	for s: float in [-1.0, 1.0]:
		var at := mid + (Vector3(0, 0, s * 1.35) if along_x else Vector3(s * 1.35, 0, 0))
		var m := Paint.box(self, Vector3(len, 0.006, 0.12) if along_x else Vector3(0.12, 0.006, len), at + Vector3(0, 0.004 + (0.0006 if along_x else 0.0), 0), mat)
		m.set_meta("gfx_coplanar_ok", true)


func _solid(body: StaticBody3D, size: Vector3, at: Vector3, mat: Material) -> void:
	Paint.box(self, size, at, mat)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = at
	body.add_child(cs)


## A light-line cradle: a stand with padded chocks, an arch behind with its work lamp and stage
## lamp, its number on the front.
func _build_cradle(i: int) -> void:
	var at := works.cradle_point(i)
	var trim := Paint.paint(Paint.TRIM, 0.4, 0.5, "gunmetal")
	var ochre := Paint.paint(Paint.OCHRE, 0.2, 0.5)
	var steel := Paint.paint(Paint.STEEL, 0.8, 0.35, "brushed_steel")
	var plates := Paint.paint(Paint.PLATES, 0.15, 0.45)
	Paint.box(self, Vector3(2.6, at.y - 0.2, 2.6), Vector3(at.x, (at.y - 0.2) * 0.5, at.z), trim)
	Paint.box(self, Vector3(3.0, 0.2, 3.3), Vector3(at.x, at.y - 0.1, at.z), steel)
	for s: float in [-1.0, 1.0]:
		Paint.box(self, Vector3(0.35, 0.3, 2.4), Vector3(at.x + s * 0.9, at.y + 0.05, at.z), ochre)
	# The arch behind it (towards the back wall), with the work lamp and the stage lamp.
	var az := at.z + 2.1
	for s: float in [-1.0, 1.0]:
		Paint.box(self, Vector3(0.28, 5.0, 0.28), Vector3(at.x + s * 1.85, 2.5, az), plates)
	Paint.box(self, Vector3(4.08, 0.32, 0.36), Vector3(at.x, 5.0, az), plates)
	Paint.box(self, Vector3(0.6, 0.22, 1.2), Vector3(at.x, 4.77, az - 0.55), trim)
	var lamp := StandardMaterial3D.new()
	lamp.emission_enabled = true
	lamp.emission_energy_multiplier = 4.0
	lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	Paint.box(self, Vector3(1.2, 0.12, 0.12), Vector3(at.x, 5.0, az - 0.18), lamp)
	_cradle_lamps.append(lamp)
	var light := OmniLight3D.new()
	light.position = Vector3(at.x, 4.4, at.z + 0.6)
	light.omni_range = 7.0
	add_child(light)
	_work_lights.append(light)
	var l := Paint.label(self, "", Vector3(at.x, 5.75, az - 0.18), 0.0055, Color(1.0, 0.85, 0.4), 44, Vector3.FORWARD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.width = 680.0
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cradle_labels.append(l)
	Paint.label(self, "R%d" % (i + 1), Vector3(at.x, 0.55, at.z - 1.32), 0.02, Paint.BEAM_ORANGE, 64, Vector3.FORWARD)


## The heavy stand: a long low steel stand under the crane with chocks along it, a light tower at
## each corner, its stage lamps along the front and its board on a post; the heavy out bay
## marked on the floor behind it.
func _build_heavy_stand() -> void:
	var at := RefurbWorks.HEAVY_AT
	var trim := Paint.paint(Paint.TRIM, 0.4, 0.5, "gunmetal")
	var tread := Paint.paint(Paint.DECK, 0.6, 0.55, "tread_diamond_steel")
	var ochre := Paint.paint(Paint.OCHRE, 0.2, 0.5)
	var plates := Paint.paint(Paint.PLATES, 0.15, 0.45)
	var size := Vector2(12.4, 8.0)
	Paint.box(self, Vector3(size.x - 0.4, at.y - 0.15, size.y - 0.4), Vector3(at.x, (at.y - 0.15) * 0.5, at.z), trim)
	Paint.box(self, Vector3(size.x, 0.15, size.y), Vector3(at.x, at.y - 0.075, at.z), tread)
	for k in 4:
		var x := at.x - size.x * 0.5 + 1.6 + k * (size.x - 3.2) / 3.0
		Paint.box(self, Vector3(0.5, 0.25, size.y - 1.4), Vector3(x, at.y + 0.1, at.z), ochre)
	Paint.box(self, Vector3(size.x, 0.1, 0.3), Vector3(at.x, at.y - 0.08, at.z - size.y * 0.5 - 0.149), Paint.paint(Paint.HAZARD, 0.1, 0.6, "hazard_stripes"))
	var lamp := StandardMaterial3D.new()
	lamp.emission_enabled = true
	lamp.emission_energy_multiplier = 4.0
	lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	Paint.box(self, Vector3(size.x - 2.0, 0.14, 0.05), Vector3(at.x, at.y * 0.5, at.z - size.y * 0.5 + 0.17), lamp)
	_cradle_lamps.append(lamp)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var p := Vector3(at.x + sx * (size.x * 0.5 + 0.5), 0, at.z + sz * (size.y * 0.5 + 0.5))
			Paint.box(self, Vector3(0.3, 6.0, 0.3), p + Vector3(0, 3.0, 0), plates)
			Paint.box(self, Vector3(0.8, 0.35, 0.5), p + Vector3(-sx * 0.2, 6.1, -sz * 0.15), trim)
			Paint.box(self, Vector3(0.6, 0.04, 0.3), p + Vector3(-sx * 0.2, 5.9, -sz * 0.15), Paint.glow(Color(1.0, 0.95, 0.85), 3.0))
	var light := OmniLight3D.new()
	light.position = at + Vector3(0, 5.5, 0)
	light.omni_range = 13.0
	add_child(light)
	_work_lights.append(light)
	# Its board on a post at the front corner.
	var bp := Vector3(at.x - size.x * 0.5 - 1.2, 0, at.z - size.y * 0.5 - 0.3)
	Paint.box(self, Vector3(0.2, 3.4, 0.2), bp + Vector3(0, 1.7, 0), trim)
	Paint.box(self, Vector3(3.2, 1.1, 0.1), bp + Vector3(0, 3.6, 0), Paint.glow(Color(0.02, 0.03, 0.05), 0.5))
	var l := Paint.label(self, "", bp + Vector3(0, 3.6, -0.07), 0.0045, Color(1.0, 0.85, 0.4), 44, Vector3.FORWARD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.width = 680.0
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cradle_labels.append(l)
	# The heavy out bay: a painted outline and its name.
	var out := RefurbWorks.HEAVY_OUT_AT
	_outline(Vector3(out.x, 0, out.z), Vector2(12.0, 7.2), Paint.paint(Paint.HAZARD, 0.1, 0.6, "enamel"))
	Paint.box(self, Vector3(11.0, out.y, 6.4), Vector3(out.x, out.y * 0.5, out.z), Paint.paint(Color(0.3, 0.31, 0.33), 0.5, 0.6, "galvanised"))
	Paint.label(self, "HEAVY OUT  ·  CERTIFIED", Vector3(out.x, 0.01, out.z - 3.85), 0.012, Paint.HAZARD, 64).basis = Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -PI * 0.5)
	Paint.label(self, "HEAVY STAND", Vector3(at.x, at.y - 0.4, at.z - size.y * 0.5 - 0.32), 0.016, Paint.BEAM_ORANGE, 64, Vector3.FORWARD)


func _outline(mid: Vector3, size: Vector2, mat: Material) -> void:
	var w := 0.15
	for s: float in [-1.0, 1.0]:
		var a := Paint.box(self, Vector3(size.x, 0.006, w), mid + Vector3(0, 0.005, s * (size.y * 0.5 - w * 0.5)), mat)
		var b := Paint.box(self, Vector3(w, 0.006, size.y - w * 2.0), mid + Vector3(s * (size.x * 0.5 - w * 0.5), 0.005, 0), mat)
		a.set_meta("gfx_coplanar_ok", true)
		b.set_meta("gfx_coplanar_ok", true)


## The intake rollers along the hall wall: a low frame with a bed of rollers (one MultiMesh) the
## cart pushes the light parts onto.
func _build_rollers() -> void:
	var xs := RefurbWorks.ROLLER_XS
	var x0 := xs[0] - 1.25
	var x1 := xs[xs.size() - 1] + 1.25
	var z := RefurbWorks.ROLLER_Z
	var y := RefurbWorks.ROLLER_Y
	var blue := Paint.paint(Paint.RACK_BLUE, 0.3, 0.4, "enamel")
	var steel := Paint.paint(Paint.STEEL, 0.85, 0.3, "brushed_steel")
	for x in range(int(x0) + 1, int(x1), 2):
		for dz: float in [-0.8, 0.8]:
			Paint.box(self, Vector3(0.1, y - 0.1, 0.1), Vector3(x, (y - 0.1) * 0.5, z + dz), blue)
	for dz: float in [-0.88, 0.88]:
		Paint.box(self, Vector3(x1 - x0, 0.16, 0.08), Vector3((x0 + x1) * 0.5, y - 0.12, z + dz), blue)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var rm := CylinderMesh.new()
	rm.top_radius = 0.05
	rm.bottom_radius = 0.05
	rm.height = 1.68
	rm.radial_segments = 10
	mm.mesh = rm
	var n := int((x1 - x0) / 0.22)
	mm.instance_count = n
	for k in n:
		mm.set_instance_transform(k, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x0 + 0.11 + k * 0.22, y - 0.05, z)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Rollers"
	mmi.multimesh = mm
	mmi.material_override = steel
	add_child(mmi)
	for k in xs.size():
		Paint.label(self, "IN %d" % (k + 1), Vector3(xs[k], y - 0.2, z + 0.93), 0.008, Color(0.95, 0.95, 0.95), 48)
	Paint.label(self, "SECOND-HAND IN", Vector3((x0 + x1) * 0.5, 3.4, -HALF.y + 0.12), 0.02, Paint.BEAM_ORANGE, 96)


## The refurbished rack on the west wall: three bays, two levels.
func _build_out_rack() -> void:
	var x := RefurbWorks.OUT_X
	var zs := RefurbWorks.OUT_ZS
	var blue := Paint.paint(Paint.RACK_BLUE, 0.3, 0.4, "enamel")
	var orange := Paint.paint(Paint.BEAM_ORANGE, 0.2, 0.45, "enamel")
	var board := Paint.paint(Color(0.5, 0.52, 0.55), 0.7, 0.45, "galvanised")
	var z0 := zs[0] - 1.35
	var z1 := zs[zs.size() - 1] + 1.35
	for z in [z0, (zs[0] + zs[1]) * 0.5, (zs[1] + zs[2]) * 0.5, z1]:
		for dx: float in [-1.0, 1.0]:
			Paint.box(self, Vector3(0.12, 5.2, 0.12), Vector3(x + dx, 2.6, z), blue)
	for y: float in RefurbWorks.OUT_LEVELS:
		Paint.box(self, Vector3(2.1, 0.06, z1 - z0), Vector3(x, y - 0.03, (z0 + z1) * 0.5), board)
		for dx: float in [-1.0, 1.0]:
			Paint.box(self, Vector3(0.1, 0.16, z1 - z0 + 0.02), Vector3(x + dx * 1.06, y - 0.11, (z0 + z1) * 0.5), orange)
	Paint.label(self, "REFURBISHED", Vector3(-HALF.x + WALL_T * 0.5 + 0.4, 6.0, (z0 + z1) * 0.5), 0.011, Paint.BEAM_ORANGE, 96, Vector3.RIGHT)


## The drones' charger rack on the back wall: a frame with a charger head over each slot (a
## saddle with contacts the drone docks up into), a status lamp each, cable trays to a cabinet.
func _build_charger_rack() -> void:
	var dark := Paint.paint(Paint.TRIM, 0.6, 0.45, "gunmetal")
	var plates := Paint.paint(Paint.PLATES, 0.15, 0.45, "satin_paint")
	var ochre := Paint.paint(Paint.OCHRE, 0.2, 0.5)
	var copper := Paint.paint(Color(0.72, 0.45, 0.25), 0.9, 0.3, "copper")
	var wall_z := HALF.y - WALL_T * 0.5
	var xs := RefurbWorks.CHARGER_XS
	var ys := RefurbWorks.CHARGER_YS
	var x0 := xs[0] - 2.0
	var x1 := xs[xs.size() - 1] + 2.0
	# The frame: uprights, rails, a cabinet at the end.
	for x in [x0, (xs[0] + xs[1]) * 0.5, (xs[1] + xs[2]) * 0.5, x1]:
		Paint.box(self, Vector3(0.22, ys[ys.size() - 1] + 1.9, 0.18), Vector3(x, (ys[ys.size() - 1] + 1.9) * 0.5, wall_z - 0.09), dark)
	for y: float in ys:
		Paint.box(self, Vector3(x1 - x0 + 0.34, 0.18, 0.16), Vector3((x0 + x1) * 0.5, y + 1.1, wall_z - 0.2), plates)
		Paint.box(self, Vector3(x1 - x0 - 0.4, 0.1, 0.24), Vector3((x0 + x1) * 0.5, y + 1.32, wall_z - 0.22), dark)
	Paint.box(self, Vector3(1.4, 2.2, 0.7), Vector3(x1 + 1.0, 1.1, wall_z - 0.35), plates)
	Paint.box(self, Vector3(1.2, 0.2, 0.02), Vector3(x1 + 1.0, 1.7, wall_z - 0.71), Paint.glow(Color(0.25, 1.0, 0.4), 2.5))
	Paint.label(self, "CHARGERS", Vector3(x1 + 1.0, 2.0, wall_z - 0.711), 0.008, Color(0.1, 0.1, 0.11), 48, Vector3.FORWARD)
	# A charger head over each slot: an arm off the rail, a saddle with contacts, a lamp.
	for i in xs.size() * ys.size():
		var d := works.dock_point(i)
		var top := d.y + 0.62 * (1.8 if i >= works.light_count() else 1.4) / 1.4
		Paint.box(self, Vector3(0.18, 0.18, wall_z - d.z - 0.25), Vector3(d.x, d.y + 1.1, (wall_z + d.z) * 0.5 + 0.02), dark)
		Paint.box(self, Vector3(0.14, d.y + 1.1 - top, 0.14), Vector3(d.x, (d.y + 1.1 + top) * 0.5, d.z), dark)
		Paint.box(self, Vector3(0.9, 0.08, 0.7), Vector3(d.x, top + 0.04, d.z), ochre)
		for s: float in [-1.0, 1.0]:
			Paint.box(self, Vector3(0.12, 0.03, 0.12), Vector3(d.x + s * 0.25, top - 0.015, d.z), copper)
		var lamp := StandardMaterial3D.new()
		lamp.emission_enabled = true
		lamp.emission_energy_multiplier = 3.0
		lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		Paint.box(self, Vector3(0.22, 0.1, 0.02), Vector3(d.x + 0.6, d.y + 1.1, wall_z - 0.29), lamp)
		_charger_lamps.append(lamp)
		Paint.label(self, "C%d" % (i + 1), Vector3(d.x - 0.6, d.y + 1.1, wall_z - 0.29), 0.008, Color(0.1, 0.1, 0.11), 48, Vector3.FORWARD)


func _build_scrap_skip() -> void:
	var at := RefurbWorks.SCRAP_AT
	var h := RefurbWorks.SCRAP_HALF
	var rust := Paint.paint(Color(0.3, 0.28, 0.25), 0.6, 0.7, "rust")
	var yellow := Paint.paint(Paint.HAZARD, 0.2, 0.6, "enamel")
	Paint.box(self, Vector3(h.x * 2.0, at.y, h.y * 2.0), Vector3(at.x, at.y * 0.5, at.z), rust)
	for s: float in [-1.0, 1.0]:
		Paint.box(self, Vector3(h.x * 2.0 + 0.2, 1.4, 0.1), Vector3(at.x, 0.7, at.z + s * (h.y + 0.05)), yellow)
		Paint.box(self, Vector3(0.1, 1.4, h.y * 2.0), Vector3(at.x + s * (h.x + 0.05), 0.7, at.z), yellow)
	Paint.label(self, "SCRAP", Vector3(at.x, 1.0, at.z - h.y - 0.11), 0.014, Paint.TRIM, 64, Vector3.FORWARD)


func _build_board() -> void:
	var at := Vector3(-10.5, 10.6, HALF.y - WALL_T * 0.5)
	Paint.box(self, Vector3(14.0, 5.4, 0.12), Vector3(at.x, at.y, at.z - 0.06), Paint.glow(Color(0.02, 0.03, 0.05), 0.5))
	_board = Paint.label(self, "", Vector3(at.x + 6.6, at.y, at.z - 0.13), 0.0085, Color(0.45, 0.95, 1.0), 48, Vector3.FORWARD)
	_board.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_board.width = 1560.0
	_board.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Consolas", "Courier New", "monospace"])
	_board.font = mono
	_board.text = board_text()


## The overhead crane: a bridge girder across the annex riding the two rails, a trolley along it,
## the hoist cable and hook block, four slings for a load.
func _build_crane() -> void:
	var yellow := Paint.paint(Paint.HAZARD, 0.2, 0.5, "enamel")
	var dark := Paint.paint(Paint.TRIM, 0.6, 0.45, "gunmetal")
	var steel := Paint.paint(Paint.STEEL, 0.85, 0.3, "brushed_steel")
	_bridge = Node3D.new()
	_bridge.name = "CraneBridge"
	add_child(_bridge)
	for dx: float in [-0.55, 0.55]:
		Paint.box(_bridge, Vector3(0.35, 0.75, RAIL_Z * 2.0 - 0.6), Vector3(dx, BRIDGE_Y, 0), yellow)
	Paint.box(_bridge, Vector3(1.55, 0.1, RAIL_Z * 2.0 - 0.7), Vector3(0, BRIDGE_Y + 0.42, 0), dark)
	Paint.box(_bridge, Vector3(0.9, 0.04, RAIL_Z * 2.0 - 1.0), Vector3(0, BRIDGE_Y - 0.39, 0), Paint.paint(Paint.HAZARD, 0.1, 0.6, "hazard_stripes"))
	for side: float in [-1.0, 1.0]:
		Paint.box(_bridge, Vector3(2.4, 0.55, 0.6), Vector3(0, RAIL_TOP + 0.36, side * RAIL_Z), dark)
		Paint.box(_bridge, Vector3(0.7, 0.5, 0.36), Vector3(0, RAIL_TOP + 0.9, side * (RAIL_Z - 0.5)), dark)
	Paint.label(_bridge, "SWL 60 t", Vector3(0.74, BRIDGE_Y, 0), 0.005, Paint.TRIM, 96, Vector3.RIGHT)
	Paint.label(_bridge, "SWL 60 t", Vector3(-0.74, BRIDGE_Y, 0), 0.005, Paint.TRIM, 96, Vector3.LEFT)
	_trolley = Node3D.new()
	_trolley.name = "Trolley"
	_bridge.add_child(_trolley)
	Paint.box(_trolley, Vector3(1.9, 0.5, 1.6), Vector3(0, TROLLEY_Y + 0.05, 0), dark)
	Paint.rod(_trolley, 0.32, 1.3, Vector3(0, TROLLEY_Y - 0.1, 0), steel, Basis(Vector3.FORWARD, PI * 0.5))
	Paint.box(_trolley, Vector3(0.5, 0.3, 0.6), Vector3(0.6, TROLLEY_Y - 0.15, 0.3), yellow)
	_crane_beacon = Paint.box(_trolley, Vector3(0.18, 0.18, 0.18), Vector3(-0.7, TROLLEY_Y - 0.3, -0.6), Paint.glow(Color(1.0, 0.6, 0.1), 6.0, true))
	_cable = Paint.rod(self, 0.035, 1.0, Vector3.ZERO, steel)
	_hook = Node3D.new()
	_hook.name = "Hook"
	add_child(_hook)
	Paint.box(_hook, Vector3(0.5, 0.5, 0.32), Vector3(0, 0.55, 0), yellow)
	Paint.rod(_hook, 0.18, 0.34, Vector3(0, 0.55, 0), dark, Basis(Vector3.RIGHT, PI * 0.5))
	Paint.box(_hook, Vector3(0.12, 0.35, 0.12), Vector3(0, 0.25, 0), steel)
	Paint.box(_hook, Vector3(0.3, 0.1, 0.12), Vector3(0.1, 0.05, 0), steel)
	var sling := Paint.paint(Color(0.95, 0.75, 0.1), 0.0, 0.8, "satin_paint")
	for j in 4:
		var s := Paint.rod(self, 0.03, 1.0, Vector3.ZERO, sling)
		s.visible = false
		_slings.append(s)


## The goods-in cart: a low flat-bed mover (its length along x), bumpers, amber corner lamps, a
## beacon on a mast and the yard's name on its flanks.
func _build_cart() -> void:
	_cart = Node3D.new()
	_cart.name = "GoodsInCart"
	add_child(_cart)
	var body := Paint.paint(Color(0.92, 0.55, 0.12), 0.2, 0.5, "enamel")
	var dark := Paint.paint(Paint.TRIM, 0.6, 0.45, "gunmetal")
	var bed := Paint.paint(Paint.DECK, 0.6, 0.55, "tread_diamond_steel")
	var bed_y := RefurbWorks.CART_BED
	Paint.box(_cart, Vector3(6.8, bed_y - 0.35, 3.0), Vector3(0, 0.15 + (bed_y - 0.35) * 0.5, 0), body)
	Paint.box(_cart, Vector3(7.0, 0.1, 3.2), Vector3(0, bed_y - 0.05, 0), bed)
	for s: float in [-1.0, 1.0]:
		Paint.box(_cart, Vector3(0.25, 0.3, 3.0), Vector3(s * 3.6, 0.35, 0), dark)
		for z: float in [-1.1, 1.1]:
			Paint.rod(_cart, 0.17, 0.25, Vector3(s * 2.4, 0.17, z * 1.25), dark, Basis(Vector3.RIGHT, PI * 0.5))
			Paint.box(_cart, Vector3(0.05, 0.12, 0.3), Vector3(s * 3.73, 0.45, z), Paint.glow(Color(1.0, 0.55, 0.1), 3.0))
		var name_l := Paint.label(_cart, "BSX GOODS IN  ·  MOVER 3", Vector3(0, 0.45, s * 1.51), 0.008, Color(0.1, 0.1, 0.11), 48, Vector3(0, 0, s))
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Paint.box(_cart, Vector3(0.12, 1.2, 0.12), Vector3(-3.3, bed_y + 0.6, 1.4), dark)
	_cart_beacon = Paint.box(_cart, Vector3(0.22, 0.22, 0.22), Vector3(-3.3, bed_y + 1.3, 1.4), Paint.glow(Color(1.0, 0.6, 0.1), 6.0, true))


## Camera spots for shots (global): name -> [from, look at].
func view_points() -> Dictionary:
	return {
		"refurb_shop": [to_global(Vector3(15.5, 9.0, -13.5)), to_global(Vector3(-3.0, 2.5, 5.0))],
		"refurb_cradle": [to_global(Vector3(-8.0, 4.0, -3.5)), to_global(Vector3(-11.4, 2.0, 3.0))],
		"refurb_racks": [to_global(Vector3(-1.0, 6.5, 9.5)), to_global(Vector3(-10.5, 5.0, 14.5))],
		"refurb_heavy": [to_global(Vector3(-2.5, 8.0, -9.0)), to_global(Vector3(9.0, 3.0, 2.0))],
		"refurb_board": [to_global(Vector3(-10.5, 8.0, 3.0)), to_global(Vector3(-10.5, 8.5, 15.0))],
		"refurb_door": [to_global(Vector3(9.0, 6.0, -34.0)), to_global(Vector3(9.0, 4.0, -6.0))],
	}
