extends Node3D
## Business in the shipyard: a big wall TV in every hall showing the wrist terminal (aim and
## click on it from across the hall, or walk up and press F for full screen)
## and, until Ship and Bay takes deliveries itself, crates in the deliveries hall for what
## is in store. Added by BusinessBus when Ship and Bay builds its shipyard.

const Look := preload("res://modules/business/internal/ui/terminal_look.gd")
const Tv := preload("res://modules/business/internal/ui/yard_tv.gd")

## Where the yard TVs hang, one per hall, yard space (Ship and Bay's shipyard.gd ROOMS): hall id
## -> the wall face at floor level, +Z out of the wall. Ship and Bay's shipyard spot
## "tv_<hall>" wins where it has one (it knows its walls); HALLS without either get no TV.
## Deliveries and pre-assembly: the outer end walls, facing the big courtyard doors, between
## the truck doors (deliveries) and south of the refurb machines (pre-assembly). Stock: the south wall
## by the door to prep. Prep: the north wall, clear of the benches. The bay: the courtyard's
## north wall between the doorways to stock and Store 2, facing the ship and the apron doors.
## The crusher house: its east end wall, past the smelter, facing the plant.
const MONITORS := {
	"bay": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -23.75)),
	"crusher": Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(88.0, 0.0, 9.5)),
	"deliveries": Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-49.75, 0.0, 0.0)),
	"stock": Transform3D(Basis(Vector3.UP, PI), Vector3(-5.85, 0.0, -24.25)),
	"prep": Transform3D(Basis.IDENTITY, Vector3(29.0, 0.0, -45.75)),
	"preassembly": Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(49.75, 0.0, 12.0)),
}
## Every hall that should have a TV, in order.
const HALLS := ["deliveries", "stock", "prep", "preassembly", "bay", "crusher", "store"]
## Height (metres) of the screen's centre over the floor: high enough to read across a hall
## over racks and trolleys, the bottom edge over people's heads.
const CENTRE_Y := 3.9
## Claimed while a TV is aimed at or full screen, so tools don't fire on the same click.
const POINTER_ID := "business.tv"
## The screen's texture size; the terminal is laid out for it. 16:9 like a TV.
const SCREEN_PX := Vector2i(1280, 720)
## Its size in metres (beenster, 23 Oct: 60% of the first 8.8 m).
const SCREEN_M := Vector2(5.28, 2.97)
## How far the screen's face stands off the wall (metres): clear of the conduit drops.
const DEPTH := 0.45
## How close (metres) and how square-on a player must be to take a TV full screen (F).
const REACH := 8.0
## How far (metres) the floating pointer reaches across a hall to a TV.
const AIM_REACH := 16.0
const FACING := 0.3
## Crates for goods in store: a grid in the deliveries hall clear of the pallets, the truck
## door and the walkways (x, z of the first crate; spacing; columns; rows).
const CRATE_ORIGIN := Vector3(-45.5, 0, 5.5)
const CRATE_STEP := Vector2(2.6, 2.3)
const CRATE_COLUMNS := 4
const CRATE_ROWS := 3
const MAX_CRATES := 24

var bus: BusinessBus
var monitors: Array[Node3D] = []
## The full-size terminal while a player uses one, else null.
var overlay: CanvasLayer
var _yard: Node3D
var _near := -1
var _was_paused := false
var _mouse_before := Input.MOUSE_MODE_VISIBLE
var _crates: Node3D
## The TV the player is aiming at and where on it (pixels), or -1: the floating pointer.
var aimed := -1
var aimed_px := Vector2.ZERO


func setup(p_bus: BusinessBus, yard: Node3D) -> void:
	bus = p_bus
	_yard = yard
	for hall: String in HALLS:
		var xf := wall_spot(hall)
		if xf != Transform3D.IDENTITY:
			monitors.append(_make_monitor(hall, xf.translated_local(Vector3(0, CENTRE_Y, 0))))
	for i in monitors.size():
		wake(i)
	_crates = Node3D.new()
	_crates.name = "GoodsIn"
	add_child(_crates)
	refresh_goods()


func _exit_tree() -> void:
	close_terminal()
	HudSlots.release_pointer(POINTER_ID)


func _process(delta: float) -> void:
	if overlay:
		return
	_update_pointer()
	var near := nearest_monitor()
	if near != _near:
		for i in monitors.size():
			(monitors[i].get_node("Prompt") as Label3D).visible = i == near
		_near = near


## The terminal a player could use now (index into monitors), or -1.
func nearest_monitor() -> int:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return -1
	var best := -1
	var best_d := REACH
	for i in monitors.size():
		var m := monitors[i]
		var to := cam.global_position - m.global_position
		var d := to.length()
		if d < best_d and to.normalized().dot(m.global_basis.z) > FACING:
			best = i
			best_d = d
	return best


func _input(event: InputEvent) -> void:
	# A screen in front of the view (the wrist holo, a menu) keeps its clicks and typing.
	if get_viewport().gui_get_hovered_control() != null or get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var button := event as InputEventMouseButton
	if button and overlay == null and aimed >= 0:
		_press_screen(aimed, button)
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if overlay:
		if event.is_action_pressed(Keys.CANCEL) or event.is_action_pressed(Keys.INTERACT):
			close_terminal()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed(Keys.INTERACT) and _near >= 0:
		open_full(_near)
		get_viewport().set_input_as_handled()


## Takes TV `i` full screen on the channel it shows. The purchase order is the wrist's, so
## it carries on.
func open_full(i: int) -> Control:
	var vp := _viewport(i)
	var channel := str(vp.get_node("Terminal").get("channel")) if is_awake(i) else holo_channel(str(vp.get_node("Broadcast").get("channel")))
	sleep(i)
	return open_terminal(channel)


## The wrist channel for a broadcast channel ("orders" -> "business.orders").
static func holo_channel(broadcast: String) -> String:
	return broadcast if broadcast.contains(".") else "business." + broadcast


## The wrist terminal (every wrist channel as a tab) on an opaque panel, as a TV shows it.
func _terminal(unit: String, closable: bool) -> Control:
	var term := HoloTerminal.new(false, "HALL TERMINAL", unit)
	term.closable = closable
	return term


## Puts the terminal up full size. Offline, the game holds still while you order.
func open_terminal(channel := "business.orders") -> Control:
	if overlay:
		return overlay.get_node("Screen")
	overlay = CanvasLayer.new()
	overlay.layer = 40
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var screen := _terminal("HALL TV", true)
	screen.name = "Screen"
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		screen.set("offset_" + side, 36.0 if side in ["left", "top"] else -36.0)
	overlay.add_child(screen)
	add_child(overlay)
	screen.call("show_channel", holo_channel(channel))
	screen.connect("close_requested", close_terminal)
	HudSlots.claim_pointer(POINTER_ID)
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_was_paused = get_tree().paused
	if _is_offline():
		get_tree().paused = true
	for m in monitors:
		(m.get_node("Prompt") as Label3D).visible = false
	_near = -1
	return screen


func close_terminal() -> void:
	if overlay == null:
		return
	overlay.queue_free()
	overlay = null
	HudSlots.release_pointer(POINTER_ID)
	if is_inside_tree():
		get_tree().paused = _was_paused
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = _mouse_before


func _is_offline() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer == null or peer is OfflineMultiplayerPeer or multiplayer.get_peers().is_empty()


## Where hall `hall`'s TV hangs: Ship and Bay's "tv_<hall>" spot, else ours, else IDENTITY
## (no TV). Origin on the wall face at floor level, +Z into the hall.
func wall_spot(hall: String) -> Transform3D:
	var yard_bus := Modules.bus("ship_bay")
	if yard_bus and yard_bus.has_method("shipyard_spot"):
		var spot: Transform3D = yard_bus.call("shipyard_spot", "tv_" + hall)
		if spot != Transform3D.IDENTITY:
			return spot
	return MONITORS.get(hall, Transform3D.IDENTITY)


# --- The floating pointer -----------------------------------------------------------------

## Where the view's centre meets a TV within reach: [index, pixel] or [-1, ZERO].
func aim() -> Array:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return [-1, Vector2.ZERO]
	var from := cam.global_position
	var dir := -cam.global_basis.z
	for i in monitors.size():
		var m := monitors[i]
		var n := m.global_basis.z
		var face := m.global_position + n * DEPTH
		var denom := dir.dot(n)
		if denom >= -0.05:
			continue
		var t := (face - from).dot(n) / denom
		if t <= 0.0 or t > AIM_REACH:
			continue
		var local := m.to_local(from + dir * t)
		var uv := Vector2(local.x / SCREEN_M.x + 0.5, 0.5 - local.y / SCREEN_M.y)
		if uv.x >= 0.0 and uv.x <= 1.0 and uv.y >= 0.0 and uv.y <= 1.0:
			return [i, uv * Vector2(SCREEN_PX)]
	return [-1, Vector2.ZERO]


func _update_pointer() -> void:
	var hit := aim()
	var was := aimed
	aimed = hit[0]
	# Tools leave the click alone while it's on a TV.
	if aimed >= 0 and was < 0:
		HudSlots.claim_pointer(POINTER_ID)
	elif aimed < 0 and was >= 0:
		HudSlots.release_pointer(POINTER_ID)
	if aimed >= 0:
		var moved: bool = aimed != was or (hit[1] as Vector2).distance_to(aimed_px) > 0.5
		aimed_px = hit[1]
		wake(aimed)
		if moved:
			var motion := InputEventMouseMotion.new()
			motion.position = aimed_px
			motion.global_position = aimed_px
			_viewport(aimed).push_input(motion, true)
	for i in monitors.size():
		var pointer := _viewport(i).get_node("Pointer") as Control
		pointer.visible = i == aimed
		if i == aimed:
			pointer.position = aimed_px
		if not is_awake(i) and overlay == null:
			wake(i)


func _press_screen(i: int, button: InputEventMouseButton) -> void:
	var ev := button.duplicate() as InputEventMouseButton
	ev.position = aimed_px
	ev.global_position = aimed_px
	_viewport(i).push_input(ev, true)


func _viewport(i: int) -> SubViewport:
	return monitors[i].get_node("Viewport") as SubViewport


func is_awake(i: int) -> bool:
	return _viewport(i).has_node("Terminal")


## Puts the wrist terminal on TV `i` (every TV shows it, as on the wrist; the pointer clicks on it).
func wake(i: int) -> Control:
	var vp := _viewport(i)
	if vp.has_node("Terminal"):
		return vp.get_node("Terminal")
	var tv := vp.get_node("Broadcast") as Control
	tv.visible = false
	tv.process_mode = Node.PROCESS_MODE_DISABLED
	var screen := _terminal("HALL %d TV" % (i + 1), false)
	screen.name = "Terminal"
	screen.size = Vector2(SCREEN_PX)
	vp.add_child(screen)
	vp.move_child(screen, vp.get_node("Pointer").get_index())
	screen.call("show_channel", holo_channel(str(tv.get("channel"))))
	return screen


## Takes TV `i`'s terminal down while the full screen shows it; it comes back after.
func sleep(i: int) -> void:
	var vp := _viewport(i)
	if not vp.has_node("Terminal"):
		return
	var screen := vp.get_node("Terminal")
	vp.remove_child(screen)
	screen.queue_free()
	var tv := vp.get_node("Broadcast") as Control
	tv.visible = true
	tv.process_mode = Node.PROCESS_MODE_INHERIT


## The floating pointer drawn on a TV: a ring and a dot in BSX orange.
class Pointer:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 10

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.35))
		draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 32, Color("e8792b"), 3.0, true)
		draw_circle(Vector2.ZERO, 3.5, Color("ffffff"))


# --- The monitors -------------------------------------------------------------------------

func _make_monitor(hall: String, xf: Transform3D) -> Node3D:
	var m := Node3D.new()
	m.name = "TV_%s" % hall
	m.transform = xf
	add_child(m)
	var w := SCREEN_M.x
	var h := SCREEN_M.y
	# Graphics highlights what the player can use when it's looked at or pinged; it finds the
	# set by this body.
	m.add_to_group("gfx_interactable")
	m.set_meta("gfx_id", "business.tv.%s" % hall)
	m.set_meta("look_hint", {"title": "Hall TV",
			"text": "The wrist terminal on the wall: orders, goods in, machines, accounts and the rest.",
			"keys": [["LMB", "Press what the pointer is on"], [Keys.INTERACT, "Full screen"]]})
	var body := StaticBody3D.new()
	body.name = "Body"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w + 0.07, h + 0.07, DEPTH)
	shape.shape = box
	shape.position.z = DEPTH * 0.5
	body.add_child(shape)
	m.add_child(body)
	var gloss := _mat(Color("0b0c0e"), 0.3, 0.18)
	var dark := _mat(Color("1d2024"), 0.7, 0.45)
	# Wall plate and arm, the set's back, then a slim gloss-black bezel round the panel.
	_box(m, Vector3(0.7, 0.45, 0.05), Vector3(0, 0, 0.025), dark)
	for x: float in [-0.18, 0.18]:
		_box(m, Vector3(0.06, 0.3, DEPTH - 0.1), Vector3(x, 0, (DEPTH - 0.1) * 0.5 + 0.05), dark)
	_box(m, Vector3(w - 0.4, h - 0.3, 0.06), Vector3(0, 0, DEPTH - 0.07), gloss)
	# The bezel stops a centimetre short of the screen so the two never share a plane.
	_box(m, Vector3(w + 0.07, h + 0.07, 0.04), Vector3(0, 0, DEPTH - 0.03), gloss)
	# A chin under the panel: BSX in orange and a standby light.
	_box(m, Vector3(w + 0.07, 0.07, 0.035), Vector3(0, -h * 0.5 - 0.07, DEPTH - 0.025), gloss)
	var badge := Label3D.new()
	badge.text = "BSX"
	badge.font = Look.font("display_bold")
	badge.font_size = 40
	badge.pixel_size = 0.0012
	badge.modulate = Look.ORANGE
	badge.position = Vector3(0, -h * 0.5 - 0.07, DEPTH - 0.006)
	m.add_child(badge)
	var led := _mat(Look.ORANGE, 0.0, 0.5)
	led.emission_enabled = true
	led.emission = Look.ORANGE
	led.emission_energy_multiplier = 3.0
	_box(m, Vector3(0.018, 0.018, 0.01), Vector3(w * 0.5 - 0.06, -h * 0.5 - 0.07, DEPTH - 0.004), led)

	var vp := SubViewport.new()
	vp.name = "Viewport"
	vp.size = SCREEN_PX
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_disable_input = false
	vp.handle_input_locally = true
	m.add_child(vp)
	var tv: Control = Tv.new()
	tv.name = "Broadcast"
	tv.size = Vector2(SCREEN_PX)
	vp.add_child(tv)
	tv.call("setup", bus, Tv.CHANNELS[monitors.size() % Tv.CHANNELS.size()])
	var pointer := Pointer.new()
	pointer.name = "Pointer"
	pointer.visible = false
	vp.add_child(pointer)

	var quad := MeshInstance3D.new()
	quad.name = "Screen"
	var qm := QuadMesh.new()
	qm.size = SCREEN_M
	quad.mesh = qm
	quad.position.z = DEPTH + 0.001
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_texture = vp.get_texture()
	sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	quad.material_override = sm
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(quad)
	# A faint sheen across the glass so it reads as a panel, not a hole in the wall.
	var sheen := MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = SCREEN_M
	sheen.mesh = sq
	sheen.position.z = DEPTH + 0.004
	var shm := StandardMaterial3D.new()
	shm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shm.albedo_color = Color(1, 1, 1, 0.0)
	shm.metallic = 0.0
	shm.roughness = 0.08
	shm.metallic_specular = 0.9
	sheen.material_override = shm
	sheen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(sheen)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.85, 0.9, 1.0)
	glow.light_energy = 0.8
	glow.omni_range = 6.0
	glow.position = Vector3(0, 0, 1.4)
	glow.shadow_enabled = false
	m.add_child(glow)

	var prompt := Label3D.new()
	prompt.name = "Prompt"
	prompt.text = "AIM AND CLICK   ·   %s  FULL SCREEN" % Keys.prompt(Keys.INTERACT)
	prompt.font = Look.font("display_bold")
	prompt.font_size = 48
	prompt.pixel_size = 0.005
	prompt.modulate = Look.ORANGE
	prompt.outline_size = 10
	prompt.outline_modulate = Color(0, 0, 0, 0.85)
	prompt.position = Vector3(0, -h * 0.5 - 0.32, DEPTH + 0.05)
	prompt.no_depth_test = true
	prompt.visible = false
	m.add_child(prompt)
	return m


func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = at
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _mat(c: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


# --- Goods in -----------------------------------------------------------------------------

## Rebuilds the crates from what is in store: one per part and condition, labelled. None
## when Ship and Bay places deliveries itself.
func refresh_goods() -> void:
	if _crates == null:
		return
	for c in _crates.get_children():
		c.free()
	if bus == null or bus.ship_bay_takes_deliveries():
		return
	var stock := bus.get_stock_detail()
	var parts := stock.keys()
	parts.sort()
	var i := 0
	for part in parts:
		for cond: String in PartCondition.ALL:
			if not stock[part].has(cond) or i >= MAX_CRATES:
				continue
			_crate(i, part, cond, int(stock[part][cond]))
			i += 1


func _crate(i: int, part: String, condition: String, qty: int) -> void:
	var slot := i % (CRATE_COLUMNS * CRATE_ROWS)
	var layer := i / (CRATE_COLUMNS * CRATE_ROWS)
	var mass := bus.get_catalogue().mass_of(part)
	var side := clampf(0.55 + pow(maxf(mass, 1.0), 1.0 / 3.0) * 0.06, 0.6, 1.5)
	var size := Vector3(side * 1.25, side * 0.85, side)
	var at := CRATE_ORIGIN + Vector3((slot % CRATE_COLUMNS) * CRATE_STEP.x, 0, (slot / CRATE_COLUMNS) * CRATE_STEP.y)
	var crate := Node3D.new()
	crate.name = "Crate_%s_%s" % [part, condition]
	crate.position = at + Vector3(0, layer * 1.3, 0)
	_crates.add_child(crate)
	var wood := _mat(Color("a98a5d") if condition != PartCondition.DAMAGED else Color("7d6a50"), 0.0, 0.85)
	_box(crate, size, Vector3(0, size.y * 0.5 + 0.06, 0), wood)
	# A steel skid under it and banding round it.
	_box(crate, Vector3(size.x, 0.12, size.z * 0.9), Vector3(0, 0.06, 0), _mat(Color("3a3e42"), 0.7, 0.5))
	for k: float in [-0.3, 0.3]:
		_box(crate, Vector3(0.04, size.y + 0.01, size.z + 0.01), Vector3(size.x * k, size.y * 0.5 + 0.06, 0), _mat(Color("2b2f33"), 0.8, 0.4))
	var tag := Label3D.new()
	tag.text = "%s\n%s  ×%d" % [bus.part_name(part).to_upper(), PartCondition.label(condition), qty]
	tag.font = Look.font("display_bold")
	tag.font_size = 40
	tag.pixel_size = 0.0035
	tag.modulate = Color("1d1d1d")
	tag.outline_size = 0
	tag.position = Vector3(0, size.y * 0.55 + 0.06, size.z * 0.5 + 0.006)
	tag.width = size.x / tag.pixel_size
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	crate.add_child(tag)
	var stripe := Label3D.new()
	stripe.text = PartCondition.label(condition)
	stripe.font = Look.font("mono_bold")
	stripe.font_size = 32
	stripe.pixel_size = 0.004
	stripe.modulate = Look.CONDITION_COLOURS.get(condition, Look.STEEL)
	stripe.position = Vector3(0, size.y + 0.075, 0)
	stripe.rotation.x = -PI * 0.5
	crate.add_child(stripe)


# --- Screenshots --------------------------------------------------------------------------

## Stands a camera in front of terminal `i` (release screenshots, tests).
func stage_monitor_view(i := 0) -> Camera3D:
	var m := monitors[i]
	var cam := Camera3D.new()
	cam.name = "BusinessShotCamera"
	add_child(cam)
	# From a walker's eye height (1.62 m), a few steps back and to one side.
	var eye := m.global_position + m.global_basis.z * 4.8 + m.global_basis.x * 1.2
	eye.y = 1.62
	cam.global_position = eye
	cam.look_at(m.global_position)
	cam.fov = 60
	cam.current = true
	(m.get_node("Prompt") as Label3D).visible = true
	return cam


## A camera over the goods-in crates.
func stage_goods_view() -> Camera3D:
	var cam := Camera3D.new()
	cam.name = "BusinessGoodsCamera"
	add_child(cam)
	var centre := CRATE_ORIGIN + Vector3(CRATE_STEP.x * 1.5, 0.6, CRATE_STEP.y)
	cam.global_position = centre + Vector3(5.5, 3.6, 6.0)
	cam.look_at(centre)
	cam.fov = 62
	cam.current = true
	return cam
