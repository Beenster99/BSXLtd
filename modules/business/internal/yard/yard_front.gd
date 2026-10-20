extends Node3D
## Business in the shipyard: a big wall TV in every hall (walk up, press F, order parts)
## and, until Ship and Bay takes deliveries itself, crates in the deliveries hall for what
## is in store. Added by BusinessBus when Ship and Bay builds its shipyard.

const Screen := preload("res://modules/business/internal/ui/terminal_screen.gd")
const Look := preload("res://modules/business/internal/ui/terminal_look.gd")
const Tv := preload("res://modules/business/internal/ui/yard_tv.gd")

## Where the yard TVs hang, one per hall, yard space (Ship and Bay's shipyard.gd ROOMS): hall id
## -> the wall face at screen height, +Z out of the wall. Deliveries: the north wall beside
## the door to stock. Stock: the south wall in the clear corner by the door to prep. Prep and
## pre-assembly: the north walls, clear of the benches and stations.
const MONITORS := {
	"deliveries": Transform3D(Basis.IDENTITY, Vector3(-47.0, 2.85, -23.75)),
	"stock": Transform3D(Basis(Vector3.UP, PI), Vector3(-5.85, 2.7, -24.25)),
	"prep": Transform3D(Basis.IDENTITY, Vector3(29.0, 2.7, -45.75)),
	"preassembly": Transform3D(Basis.IDENTITY, Vector3(47.0, 2.85, -23.75)),
}
## The screen's texture size; the terminal is laid out for it. 16:9 like a TV.
const SCREEN_PX := Vector2i(1280, 720)
const SCREEN_M := Vector2(2.9, 1.63)
## How far the screen's face stands off the wall (metres).
const DEPTH := 0.24
## How close (metres) and how square-on a player must be to use a terminal.
const REACH := 4.5
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


func setup(p_bus: BusinessBus, yard: Node3D) -> void:
	bus = p_bus
	_yard = yard
	for hall: String in MONITORS:
		monitors.append(_make_monitor(hall, MONITORS[hall]))
	_crates = Node3D.new()
	_crates.name = "GoodsIn"
	add_child(_crates)
	refresh_goods()


func _exit_tree() -> void:
	close_terminal()


func _process(_delta: float) -> void:
	if overlay:
		return
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
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if overlay:
		if key.physical_keycode in [KEY_ESCAPE, KEY_F]:
			close_terminal()
			get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_F and _near >= 0:
		open_terminal()
		get_viewport().set_input_as_handled()


## Puts the terminal up full size. Offline, the game holds still while you order.
func open_terminal(channel := "orders") -> Control:
	if overlay:
		return overlay.get_node("Screen")
	overlay = CanvasLayer.new()
	overlay.layer = 40
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var screen: Control = Screen.new()
	screen.name = "Screen"
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		screen.set("offset_" + side, 36.0 if side in ["left", "top"] else -36.0)
	overlay.add_child(screen)
	add_child(overlay)
	screen.call("setup", bus, true)
	screen.call("show_channel", channel)
	screen.connect("close_requested", close_terminal)
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
	if is_inside_tree():
		get_tree().paused = _was_paused
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = _mouse_before


func _is_offline() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer == null or peer is OfflineMultiplayerPeer or multiplayer.get_peers().is_empty()


# --- The monitors -------------------------------------------------------------------------

func _make_monitor(hall: String, xf: Transform3D) -> Node3D:
	var m := Node3D.new()
	m.name = "TV_%s" % hall
	m.transform = xf
	add_child(m)
	var w := SCREEN_M.x
	var h := SCREEN_M.y
	var gloss := _mat(Color("0b0c0e"), 0.3, 0.18)
	var dark := _mat(Color("1d2024"), 0.7, 0.45)
	# Wall plate and arm, the set's back, then a slim gloss-black bezel round the panel.
	_box(m, Vector3(0.7, 0.45, 0.05), Vector3(0, 0, 0.025), dark)
	for x: float in [-0.18, 0.18]:
		_box(m, Vector3(0.06, 0.3, 0.1), Vector3(x, 0, 0.1), dark)
	_box(m, Vector3(w - 0.4, h - 0.3, 0.06), Vector3(0, 0, 0.17), gloss)
	_box(m, Vector3(w + 0.07, h + 0.07, 0.04), Vector3(0, 0, DEPTH - 0.02), gloss)
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
	vp.gui_disable_input = true
	m.add_child(vp)
	var tv: Control = Tv.new()
	tv.name = "Broadcast"
	tv.size = Vector2(SCREEN_PX)
	vp.add_child(tv)
	tv.call("setup", bus, Tv.CHANNELS[monitors.size() % Tv.CHANNELS.size()])

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
	glow.light_energy = 0.5
	glow.omni_range = 3.5
	glow.position = Vector3(0, 0, 0.9)
	glow.shadow_enabled = false
	m.add_child(glow)

	var prompt := Label3D.new()
	prompt.name = "Prompt"
	prompt.text = "[F]  USE SCREEN"
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
	cam.global_position = m.global_position + m.global_basis.z * 3.8 + m.global_basis.x * 1.2 + Vector3(0, -1.1, 0)
	cam.look_at(m.global_position + Vector3(0, -0.15, 0))
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
