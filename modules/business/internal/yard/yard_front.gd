extends Node3D
## Business in the shipyard: the wall-mounted yard terminals (walk up, press T, order parts)
## and, until Ship and Bay takes deliveries itself, crates in the deliveries hall for what
## is in store. Added by BusinessBus when Ship and Bay builds its shipyard.

const Screen := preload("res://modules/business/internal/ui/terminal_screen.gd")
const Look := preload("res://modules/business/internal/ui/terminal_look.gd")

## Where the terminals hang, yard space (Ship and Bay's shipyard.gd ROOMS): the north wall of
## the deliveries hall beside the door to stock, and the south wall by the goods-in desk.
## Each faces +Z of its basis.
const MONITORS: Array[Transform3D] = [
	Transform3D(Basis.IDENTITY, Vector3(-46.6, 1.95, -23.62)),
	Transform3D(Basis(Vector3.UP, PI), Vector3(-40.0, 1.95, 23.62)),
]
## The screen's texture size; the terminal is laid out for it.
const SCREEN_PX := Vector2i(1280, 800)
const SCREEN_M := Vector2(1.84, 1.15)
## How close (metres) and how square-on a player must be to use a terminal.
const REACH := 3.2
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
	for xf in MONITORS:
		monitors.append(_make_monitor(xf))
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
		if key.physical_keycode in [KEY_ESCAPE, KEY_T]:
			close_terminal()
			get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_T and _near >= 0:
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

func _make_monitor(xf: Transform3D) -> Node3D:
	var m := Node3D.new()
	m.name = "Terminal%d" % (monitors.size() + 1)
	m.transform = xf
	add_child(m)
	var steel := _mat(Color("2a2e33"), 0.6, 0.45)
	_box(m, Vector3(SCREEN_M.x + 0.16, SCREEN_M.y + 0.16, 0.09), Vector3(0, 0, 0.045), steel)
	# Wall bracket and a BSX orange strip under the bezel.
	_box(m, Vector3(0.5, 0.36, 0.06), Vector3(0, 0, -0.01), _mat(Color("1b1e21"), 0.7, 0.5))
	_box(m, Vector3(SCREEN_M.x + 0.16, 0.05, 0.1), Vector3(0, -SCREEN_M.y * 0.5 - 0.105, 0.05), _mat(Look.ORANGE, 0.2, 0.5))
	# Hazard tape across the top edge of the bezel.
	var tape := _mat(Look.ORANGE, 0.1, 0.6)
	tape.albedo_texture = _hazard_texture()
	tape.uv1_scale = Vector3(14, 1, 1)
	_box(m, Vector3(SCREEN_M.x + 0.16, 0.04, 0.1), Vector3(0, SCREEN_M.y * 0.5 + 0.1, 0.05), tape)

	var vp := SubViewport.new()
	vp.name = "Viewport"
	vp.size = SCREEN_PX
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_disable_input = true
	m.add_child(vp)
	var screen: Control = Screen.new()
	screen.size = Vector2(SCREEN_PX)
	vp.add_child(screen)
	screen.call("setup", bus, false)
	screen.call("show_channel", ["orders", "goods", "accounts"][monitors.size() % 3])

	var quad := MeshInstance3D.new()
	quad.name = "Screen"
	var qm := QuadMesh.new()
	qm.size = SCREEN_M
	quad.mesh = qm
	quad.position.z = 0.092
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_texture = vp.get_texture()
	sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	quad.material_override = sm
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(quad)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.85, 0.9, 1.0)
	glow.light_energy = 0.35
	glow.omni_range = 2.2
	glow.position = Vector3(0, 0, 0.5)
	glow.shadow_enabled = false
	m.add_child(glow)

	var prompt := Label3D.new()
	prompt.name = "Prompt"
	prompt.text = "[T]  USE TERMINAL"
	prompt.font = Look.font("display_bold")
	prompt.font_size = 48
	prompt.pixel_size = 0.004
	prompt.modulate = Look.ORANGE
	prompt.outline_size = 10
	prompt.outline_modulate = Color(0, 0, 0, 0.85)
	prompt.position = Vector3(0, -SCREEN_M.y * 0.5 - 0.3, 0.12)
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


static var _hazard: ImageTexture


static func _hazard_texture() -> ImageTexture:
	if _hazard:
		return _hazard
	var img := Image.create(32, 8, false, Image.FORMAT_RGB8)
	for x in 32:
		for y in 8:
			img.set_pixel(x, y, Look.ORANGE if (x + y) % 16 < 8 else Look.BLACK)
	_hazard = ImageTexture.create_from_image(img)
	return _hazard


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
	cam.global_position = m.global_position + m.global_basis.z * 2.6 + Vector3(0.9, -0.15, 0)
	cam.look_at(m.global_position + Vector3(0.1, -0.1, 0))
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
