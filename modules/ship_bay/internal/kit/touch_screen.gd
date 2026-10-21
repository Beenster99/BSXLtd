extends Node3D
## A small LED touch screen for the yard's machines (the power unit, the scissor lift, the
## scaffold rigs, the trolleys), drawn in the TV terminals' style with UI's TerminalKit: a
## title and a status chip over a grid of touch buttons, lit on a dark glass face in a thin
## bezel. There are no physical buttons: look at the screen and a pointer follows your view
## across it; left click presses the button under it (TouchPointer routes the mouse). A
## button can act on press, or while held (`hold`: called with true on press, false on
## release), like the scissor lift's RAISE and LOWER.
##
## Its +Z is out of the face; the face is `size` metres, centred on the node. Tests press
## buttons with `press(id)` and `hold(id, down)`.

const T := preload("res://modules/ui/api/terminal_kit.gd")
const Pointer := preload("res://modules/ship_bay/internal/kit/touch_pointer.gd")

## The face, metres.
var size := Vector2(0.3, 0.2)
## Pixels per metre of face.
var density := 760.0
var viewport: SubViewport
var buttons: Dictionary = {}    # id -> Button
var _title: Label
var _status: Label
var _chip: PanelContainer
var _grid: GridContainer
var _pointer: Control
var _holds: Dictionary = {}     # id -> Callable(down: bool)
var _face: MeshInstance3D
var _panel: PanelContainer


func _ready() -> void:
	Pointer.ensure(get_tree())


## Builds the screen: `size` metres across and up, a title, and `columns` of buttons.
func setup(p_size: Vector2, title: String, columns := 2) -> void:
	size = p_size
	name = name if name != "" else "TouchScreen"
	add_to_group(Pointer.GROUP)
	viewport = SubViewport.new()
	viewport.name = "Viewport"
	viewport.size = Vector2i(roundi(size.x * density), roundi(size.y * density))
	viewport.transparent_bg = false
	viewport.gui_embed_subwindows = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	_panel = PanelContainer.new()
	var panel := _panel
	panel.name = "Panel"
	panel.theme = BsxTheme.get_theme()
	var bg := T.box(T.KIOSK, T.ORANGE, 0, 10.0)
	panel.add_theme_stylebox_override("panel", bg)
	panel.size = Vector2(viewport.size)
	viewport.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	_title = T.label(title, "display_bold", 30, T.TEXT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	head.add_child(_title)
	_chip = PanelContainer.new()
	_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chip.add_theme_stylebox_override("panel", T.box(Color(T.GOOD, 0.16), T.GOOD, 1, 4.0))
	_status = T.label("", "mono_medium", 18, T.GOOD)
	_chip.add_child(_status)
	_chip.visible = false
	head.add_child(_chip)
	# The hazard rule under the header, like the TVs.
	var rule := ColorRect.new()
	rule.color = T.ORANGE
	rule.custom_minimum_size = Vector2(0, 3)
	col.add_child(rule)
	_grid = GridContainer.new()
	_grid.columns = columns
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_grid)
	# The pointer: a small ring that follows the view across the face.
	_pointer = Pointer.dot()
	viewport.add_child(_pointer)
	_build_face()


## Adds a touch button. `on_press` runs on a tap; with `on_hold` it runs `on_hold(true)` on
## press and `on_hold(false)` on release instead. `filled` lights it BSX orange.
func add_button(id: String, text: String, on_press: Callable, filled := false, on_hold := Callable()) -> Button:
	var b := T.button(text, filled, 22)
	b.name = "Button_" + id.validate_node_name()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.clip_text = false
	if on_hold.is_valid():
		_holds[id] = on_hold
		b.button_down.connect(func() -> void: on_hold.call(true))
		b.button_up.connect(func() -> void: on_hold.call(false))
	elif on_press.is_valid():
		b.pressed.connect(on_press)
	_grid.add_child(b)
	buttons[id] = b
	_fit.call_deferred()
	return b


## Grows the screen's pixels (keeping its shape) until everything on it fits.
func _fit() -> void:
	var need := _panel.get_combined_minimum_size()
	var px := size * density
	var k := maxf(1.0, maxf(need.x / px.x, need.y / px.y))
	viewport.size = Vector2i(ceili(px.x * k), ceili(px.y * k))
	_panel.size = Vector2(viewport.size)


## A button's text and whether it is lit (an on switch shows filled orange).
func set_button(id: String, text: String, lit := false) -> void:
	var b: Button = buttons.get(id)
	if b == null:
		return
	b.text = text
	var bg := T.ORANGE if lit else T.PLATE
	var normal := T.box(bg, T.ORANGE if lit else T.EDGE, 2, 8.0)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_color_override("font_color", T.BLACK if lit else T.STEEL)


## The chip by the title: its text and colour ("" hides it).
func set_status(text: String, colour := T.GOOD) -> void:
	_chip.visible = text != ""
	_status.text = text
	_status.add_theme_color_override("font_color", colour)
	var st := _chip.get_theme_stylebox("panel") as StyleBoxFlat
	st.bg_color = Color(colour, 0.16)
	st.border_color = colour


func set_title(text: String) -> void:
	_title.text = text
	_fit.call_deferred()


## A tap on button `id` (tests, and what a click does).
func press(id: String) -> void:
	var b: Button = buttons.get(id)
	if b == null or b.disabled:
		return
	if _holds.has(id):
		(_holds[id] as Callable).call(true)
		(_holds[id] as Callable).call(false)
	else:
		b.pressed.emit()


## Holds button `id` down (true) or lets it go (false) (tests).
func hold(id: String, down: bool) -> void:
	if _holds.has(id):
		(_holds[id] as Callable).call(down)


## Where a ray (world space) meets the face, in viewport pixels, or (-1, -1) if it misses.
## `distance` is how far along the ray (metres), INF on a miss.
func hit_pixel(from: Vector3, dir: Vector3) -> Array:
	var n := global_basis.z.normalized()
	var denom := dir.dot(n)
	if denom >= -0.02:
		return [Vector2(-1, -1), INF]
	var t := (global_position - from).dot(n) / denom
	if t <= 0.0:
		return [Vector2(-1, -1), INF]
	var local := global_transform.affine_inverse() * (from + dir * t)
	var uv := Vector2(local.x / size.x + 0.5, 0.5 - local.y / size.y)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return [Vector2(-1, -1), INF]
	return [uv * Vector2(viewport.size), t]


## The pointer at `px` (viewport pixels), or hidden.
func show_pointer(px: Vector2, on: bool) -> void:
	_pointer.visible = on
	if on:
		_pointer.position = px - _pointer.size * 0.5


## The button under a pixel, or "".
func button_at(px: Vector2) -> String:
	for id: String in buttons:
		var b: Button = buttons[id]
		if b.is_visible_in_tree() and b.get_global_rect().has_point(px):
			return id
	return ""


## Every label's and button's text, for tests.
func text() -> String:
	var out := PackedStringArray([_title.text, _status.text])
	for id: String in buttons:
		out.append((buttons[id] as Button).text)
	return " | ".join(out)


## The lit glass face in a thin dark bezel; unshaded so it reads as a lit screen.
func _build_face() -> void:
	var bezel := MeshInstance3D.new()
	bezel.name = "Bezel"
	bezel.mesh = PartShapes.chamfer_box(Vector3(size.x + 0.024, size.y + 0.024, 0.014), 0.004).mesh
	bezel.position = Vector3(0, 0, -0.009)
	bezel.material_override = ShipSurface.of(ShipKit.paint(Color(0.06, 0.065, 0.07), 0.4, 0.4, "gunmetal"))
	add_child(bezel)
	_face = MeshInstance3D.new()
	_face.name = "Face"
	var quad := QuadMesh.new()
	quad.size = size
	_face.mesh = quad
	_face.position = Vector3(0, 0, 0.0005)
	_face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = viewport.get_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_face.material_override = mat
	add_child(_face)
