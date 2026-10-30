class_name TouchScreen
extends Node3D
## A screen in the world that you use by looking at it: any Control shown on a lit panel
## (a SubViewport on a quad, in a slim gloss bezel). Aim the view's centre at it within
## `reach` (or the free mouse, when the mouse is free) and an orange pointer follows on the
## screen; left click presses what's under it. It takes the clicks it gets in _input, so tools
## and benches (_unhandled_input) don't fire on the same click. It doesn't claim the pointer:
## a claim stops the view turning, and the pointer follows the view.
##   var tv := TouchScreen.new(HoloTerminal.new(false, "HALL TERMINAL"), Vector2i(1280, 720), Vector2(2.4, 1.35))
##   add_child(tv)   # the screen faces +Z
## For buttons on machines, a mini LED panel of touch buttons; left click toggles a toggle:
##   var panel := TouchScreen.buttons([{id = "power", label = "SHORE POWER", toggle = true},
##           {id = "up", label = "RAISE", hold = true}], Vector2(0.3, 0.2))
##   panel.button_pressed.connect(func(id: String, on: bool) -> void: ...)
##   panel.button_held.connect(func(id: String, down: bool) -> void: ...)   # hold = true ones

signal aimed_changed(aimed: bool)
signal button_pressed(id: String, on: bool)
signal button_held(id: String, down: bool)

const T := preload("res://modules/ui/api/terminal_kit.gd")
## How far in front of the bezel the picture sits, m.
const FACE := 0.012
## Pixels per metre for LED button panels.
const PANEL_PX_PER_M := 600.0

## How far away it can be used from, m.
@export var reach := 4.0
## Stops aim through walls: something solid nearer than the screen blocks it.
@export var check_walls := true
## The picture's brightness (unshaded, so it reads as lit in a dark hall).
@export var brightness := 1.0

## What the info panel says while it's aimed at (HudSlots look hints).
var hint := {"title": "Screen", "keys": [["LMB", "Press"]]}
var size_m := Vector2(1.0, 0.6)
var px := Vector2i(1000, 600)
var content: Control
var viewport: SubViewport
var pointer: Control
## Where the pointer is on the screen, in pixels.
var pointer_px := Vector2.ZERO

var _glass: MeshInstance3D
var _edge_mat: StandardMaterial3D
var _aimed := false
var _held := 0  # mouse buttons pushed in while aimed, so their releases follow
var _hit_t := INF
var _buttons: Dictionary = {}

# The one screen aimed at across the world: each screen offers its hit every frame, the
# nearest wins, and the winner is read the frame after.
static var _frame := -1
static var _cand: TouchScreen
static var _cand_t := INF
static var _current: TouchScreen


func _init(p_content: Control = null, p_px := Vector2i(1000, 600), p_size_m := Vector2(1.0, 0.6)) -> void:
	content = p_content
	px = p_px
	size_m = p_size_m
	name = "TouchScreen"
	_build()


func _ready() -> void:
	(_glass.material_override as StandardMaterial3D).albedo_texture = viewport.get_texture()


func _exit_tree() -> void:
	if _cand == self:
		_cand = null
		_cand_t = INF
	if _current == self:
		_current = null
	_set_aimed(false)


## The screen being aimed at now, or null.
static func current() -> TouchScreen:
	return _current if _current != null and is_instance_valid(_current) else null


func look_hint() -> Dictionary:
	return hint


func is_aimed() -> bool:
	return _aimed


func _process(_delta: float) -> void:
	var f := Engine.get_process_frames()
	if f != _frame:
		_frame = f
		_current = _cand if _cand != null and is_instance_valid(_cand) else null
		_cand = null
		_cand_t = INF
	_set_aimed(_current == self)
	var hit := aim()
	if hit.x >= 0.0 and _hit_t < _cand_t:
		_cand = self
		_cand_t = _hit_t
	if _aimed and hit.x >= 0.0 and hit.distance_to(pointer_px) > 0.5:
		pointer_px = hit
		var motion := InputEventMouseMotion.new()
		motion.position = pointer_px
		motion.global_position = pointer_px
		viewport.push_input(motion, true)
	pointer.visible = _aimed
	pointer.position = pointer_px


## Where the aim meets the picture, in pixels; (-1, -1) when it doesn't (out of reach, at
## its back, off its edge, behind a wall, or another screen has the pointer).
func aim() -> Vector2:
	_hit_t = INF
	var none := Vector2(-1, -1)
	if not is_visible_in_tree() or not is_inside_tree() or HudSlots.pointer_claimed(_claim_id()):
		return none
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return none
	var from := cam.global_position
	var dir := -cam.global_basis.z
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and DisplayServer.get_name() != "headless":
		if get_viewport().gui_get_hovered_control() != null:
			return none
		var mouse := get_viewport().get_mouse_position()
		from = cam.project_ray_origin(mouse)
		dir = cam.project_ray_normal(mouse)
	var n := global_basis.z.normalized()
	var face := global_position + n * FACE
	var denom := dir.dot(n)
	if denom >= -0.05:
		return none
	var t := (face - from).dot(n) / denom
	if t <= 0.0 or t > reach:
		return none
	var local := to_local(from + dir * t)
	var uv := Vector2(local.x / size_m.x + 0.5, 0.5 - local.y / size_m.y)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return none
	if check_walls and t > 0.1:
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * (t - 0.06))
		q.collide_with_areas = false
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			return none
	_hit_t = t
	return uv * Vector2(px)


func _input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or (not _aimed and _held == 0):
		return
	if button.pressed and not _aimed:
		return
	var ev := button.duplicate() as InputEventMouseButton
	ev.position = pointer_px
	ev.global_position = pointer_px
	viewport.push_input(ev, true)
	if button.pressed:
		_held |= 1 << button.button_index
	else:
		_held &= ~(1 << button.button_index)
	get_viewport().set_input_as_handled()


## Presses the screen at a pixel, as a left click there (tests, or a key that uses it).
func click_at(at: Vector2) -> void:
	for down: bool in [true, false]:
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.global_position = at
		viewport.push_input(motion, true)
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = at
		ev.global_position = at
		viewport.push_input(ev, true)


func _set_aimed(on: bool) -> void:
	if on == _aimed:
		return
	_aimed = on
	if not on:
		_held = 0
		if viewport.is_inside_tree():  # the pointer leaves, so nothing stays lit as hovered
			var away := InputEventMouseMotion.new()
			away.position = Vector2(-100, -100)
			away.global_position = away.position
			viewport.push_input(away, true)
	if _edge_mat:
		_edge_mat.emission_energy_multiplier = 2.2 if on else 0.7
	aimed_changed.emit(on)


func _claim_id() -> String:
	return "ui.touch.%d" % get_instance_id()


# --- LED button panels --------------------------------------------------------------------

## A mini LED panel of touch buttons. Specs: {id, label, toggle (left click flips it, lit
## while on), on (starts on), hold (button_held while pressed down)}. Laid out in one column,
## or `columns` side by side.
static func buttons(specs: Array, p_size_m := Vector2(0.3, 0.2), columns := 1) -> TouchScreen:
	var p := Vector2i((p_size_m * PANEL_PX_PER_M).round())
	var panel := PanelContainer.new()
	var st := T.box(Color("07090b"), Color(T.CYAN, 0.35), 3, 14.0)
	panel.add_theme_stylebox_override("panel", st)
	var grid := GridContainer.new()
	grid.name = "Buttons"
	grid.columns = maxi(1, columns)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	panel.add_child(grid)
	var rows := ceili(float(specs.size()) / float(grid.columns))
	var cell := Vector2((p.x - 28.0 - 10.0 * (grid.columns - 1)) / grid.columns,
			(p.y - 28.0 - 10.0 * (rows - 1)) / maxf(1.0, rows))
	var screen := TouchScreen.new(panel, p, p_size_m)
	screen.reach = 2.5
	screen.hint = {"title": "Controls", "keys": [["LMB", "Press a button"]]}
	for spec: Dictionary in specs:
		var b := led_button(str(spec.get("label", spec.id)), bool(spec.get("toggle", false)),
				bool(spec.get("on", false)), int(cell.y * 0.42))
		b.name = "Btn_" + str(spec.id).validate_node_name()
		b.custom_minimum_size = cell
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var id := str(spec.id)
		if b.toggle_mode:
			b.toggled.connect(func(on: bool) -> void: screen.button_pressed.emit(id, on))
		else:
			b.pressed.connect(func() -> void: screen.button_pressed.emit(id, true))
		if spec.get("hold", false):
			b.button_down.connect(func() -> void: screen.button_held.emit(id, true))
			b.button_up.connect(func() -> void: screen.button_held.emit(id, false))
		grid.add_child(b)
		screen._buttons[id] = b
	return screen


## The panel's button `id` (LED panels), or null.
func button(id: String) -> Button:
	return _buttons.get(id) as Button


## Lights a toggle without emitting button_pressed (the machine's state changed elsewhere).
func set_on(id: String, on: bool) -> void:
	var b := button(id)
	if b:
		b.set_pressed_no_signal(on)


## A touch button in the LED look: a black glass key with a glowing edge and caption, lit
## up cyan while pressed or (toggles) on.
static func led_button(text: String, toggle := false, on := false, font_size := 22) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.toggle_mode = toggle
	b.button_pressed = on and toggle
	b.add_theme_font_override("font", T.font("display_bold"))
	b.add_theme_font_size_override("font_size", maxi(12, font_size))
	var normal := T.box(Color("0e1418"), Color(T.CYAN, 0.45), 2, 6.0)
	normal.border_width_bottom = 4
	var hover := T.box(Color("13222a"), T.CYAN, 2, 6.0)
	hover.border_width_bottom = 4
	hover.shadow_color = Color(T.CYAN, 0.35)
	hover.shadow_size = 8
	var lit := T.box(Color(T.CYAN, 0.85), Color("d8f6ff"), 2, 6.0)
	lit.shadow_color = Color(T.CYAN, 0.6)
	lit.shadow_size = 12
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", lit)
	b.add_theme_stylebox_override("hover_pressed", lit)
	b.add_theme_stylebox_override("disabled", T.box(Color("0a0d10"), Color(T.STEEL, 0.25), 2, 6.0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color(T.CYAN, 0.9))
	b.add_theme_color_override("font_hover_color", Color("d8f6ff"))
	b.add_theme_color_override("font_pressed_color", T.BLACK)
	b.add_theme_color_override("font_hover_pressed_color", T.BLACK)
	b.add_theme_color_override("font_disabled_color", Color(T.STEEL, 0.4))
	b.pressed.connect(func() -> void: Sfx.press(b))
	b.set_meta("sfx", true)
	return b


# --- The set ------------------------------------------------------------------------------

func _build() -> void:
	viewport = SubViewport.new()
	viewport.name = "Viewport"
	viewport.size = px
	viewport.disable_3d = true
	viewport.transparent_bg = false
	# Drawn only while its picture is on screen (it was redrawn every frame, seen or not).
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport.handle_input_locally = true
	viewport.gui_disable_input = false
	add_child(viewport)
	var root := Control.new()
	root.name = "Root"
	root.theme = BsxTheme.get_theme()
	root.size = Vector2(px)
	root.set_meta("holo", true)  # its buttons tick
	viewport.add_child(root)
	if content == null:
		content = Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(content)
	pointer = Pointer.new()
	pointer.name = "Pointer"
	pointer.visible = false
	root.add_child(pointer)

	var bezel_mat := StandardMaterial3D.new()
	bezel_mat.albedo_color = Color("0b0c0e")
	bezel_mat.metallic = 0.3
	bezel_mat.roughness = 0.2
	var bezel := MeshInstance3D.new()
	bezel.name = "Bezel"
	var box := BoxMesh.new()
	var rim := clampf(minf(size_m.x, size_m.y) * 0.04, 0.01, 0.06)
	box.size = Vector3(size_m.x + rim * 2.0, size_m.y + rim * 2.0, 0.03)
	bezel.mesh = box
	bezel.material_override = bezel_mat
	bezel.position.z = -0.015 + FACE * 0.5
	add_child(bezel)
	_edge_mat = StandardMaterial3D.new()
	_edge_mat.albedo_color = Color(T.CYAN, 1.0)
	_edge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_edge_mat.emission_enabled = true
	_edge_mat.emission = T.CYAN
	_edge_mat.emission_energy_multiplier = 0.7
	var edge := MeshInstance3D.new()
	edge.name = "Edge"
	var ebox := BoxMesh.new()
	ebox.size = Vector3(size_m.x + rim * 0.7, size_m.y + rim * 0.7, 0.004)
	edge.mesh = ebox
	edge.material_override = _edge_mat
	edge.position.z = FACE * 0.6
	add_child(edge)
	_glass = MeshInstance3D.new()
	_glass.name = "Glass"
	var quad := QuadMesh.new()
	quad.size = size_m
	_glass.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(brightness, brightness, brightness)
	_glass.material_override = mat
	_glass.position.z = FACE
	add_child(_glass)


## The pointer drawn on the screen: a ring and a dot in BSX orange.
class Pointer extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 10

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.35))
		draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 32, TerminalKit.ORANGE, 3.0, true)
		draw_circle(Vector2.ZERO, 3.5, Color.WHITE)
