class_name TradesTool
extends Node3D
## A hand tool on the bay's hotbar, built in code the way Void Salvage builds its tools
## (SalvageTool): boxes, cylinders and capsules in plain metals and rubber, the body in BSX
## orange, and a screen set into the body with its live readings (torque, amps...), a fill
## bar and a status light: with trades.tool_display a TradesToolDisplay in the yard's TV
## look carrying its name, labelled readings and what it's doing (the HUD's tool panel goes). A station puts it on the work while it is in use;
## otherwise the bay carries it in the right hand.

const RUBBER := Color(0.09, 0.09, 0.1)
const GLASS := Color(0.012, 0.03, 0.035)

## Where the hand closes on it, in its own space.
var grip := Vector3.ZERO
## How it sits in a relaxed right hand: its own space as seen from the palm (fingers along
## -Z, back of the hand +Y).
var hold := Transform3D()

## Its name on its display (the bay sets it from the hotbar's labels).
var title := ""

var _display: TradesToolDisplay
var _readout: Label3D
var _bar: MeshInstance3D
var _bar_width := 0.0
var _led: MeshInstance3D
var _led_on: Material
var _led_off: Material


## Its transform when carried in a hand whose palm is at `palm`.
func carried(palm: Transform3D) -> Transform3D:
	return palm * hold * Transform3D(Basis(), -grip)


## Text for its screen (override; "" = no screen).
func readout_text() -> String:
	return ""


## How full the bar under the screen's text is (0..1), or below 0 for no bar.
func readout_fill() -> float:
	return -1.0


## The status light: lit while true (the tool is running or has just clicked).
func readout_alert() -> bool:
	return false


## Its display: labelled readings, [[label, value], ...] (override).
func panel_rows() -> Array:
	return []


## Its display: one word or two for what the tool is doing (override).
func panel_state() -> String:
	return "RUNNING" if readout_alert() else "READY"


## Everything its display shows, as text ("" without one).
func display_text() -> String:
	return _display.text() if _display else ""


func _process(_delta: float) -> void:
	if _display:
		_turn_swivel()
		_display.show_state(title, panel_rows(), panel_state(), readout_fill(), readout_alert())
		return
	if _readout == null:
		return
	_readout.text = readout_text()
	var fill := readout_fill()
	_bar.visible = fill >= 0.0
	if _bar.visible:
		var f := clampf(fill, 0.0, 1.0)
		_bar.scale.x = maxf(0.001, f)
		_bar.position.x = -_bar_width * 0.5 * (1.0 - f)
	if _led:
		_led.material_override = _led_on if readout_alert() else _led_off


## A small screen set into the tool's body: a rubber bezel, dark glass, `rows` lines of up
## to `cols` characters, a fill bar along the bottom and a status light beside it. `at` is
## the middle of its glass and `normal` the way it faces (tool space); the text's top points
## along `up`.
func add_screen(at: Vector3, normal: Vector3, size: Vector2, cols: int, rows: int, up := Vector3.FORWARD,
		color := TradesLook.SCREEN) -> void:
	var screen := Node3D.new()
	screen.name = "Screen"
	screen.position = at
	screen.basis = facing(normal, up)
	add_child(screen)
	if Flags.is_on("trades.tool_display"):
		_build_swivel(screen, TerminalKit.ORANGE if color == TradesLook.SCREEN else color)
		return
	box(Vector3(size.x + 0.008, size.y + 0.008, 0.006), Vector3(0, 0, -0.0032), rubber(), Vector3.ZERO, screen)
	var glass := StandardMaterial3D.new()
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.albedo_color = GLASS
	box(Vector3(size.x, size.y, 0.001), Vector3.ZERO, glass, Vector3.ZERO, screen)
	var bar_h := size.y * 0.1
	var text_h := size.y - bar_h * 2.5
	_readout = Label3D.new()
	_readout.font = TradesLook.mono_font()
	_readout.font_size = 48
	# A monospace glyph is about 0.6 of the font size wide and a line about 1.5 of it tall.
	_readout.pixel_size = minf(size.x * 0.92 / (cols * 0.6 * 48.0), text_h / (rows * 1.5 * 48.0))
	_readout.modulate = color
	_readout.outline_size = 0
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_readout.position = Vector3(-size.x * 0.46, bar_h * 0.75, 0.0008)
	_readout.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	screen.add_child(_readout)
	_bar_width = size.x * 0.78
	var track := box(Vector3(_bar_width, bar_h * 0.5, 0.0004), Vector3(-size.x * 0.06, -size.y * 0.5 + bar_h, 0.0006),
			TradesLook.glow(Color(color, 1.0) * 0.18, 1.0), Vector3.ZERO, screen)
	_bar = box(Vector3(_bar_width, bar_h * 0.5, 0.0004), Vector3(0, 0, 0.0003), TradesLook.glow(color, 1.6),
			Vector3.ZERO, track)
	_led_on = TradesLook.glow(Color(1.0, 0.55, 0.15), 4.0)
	_led_off = TradesLook.metal(Color(0.2, 0.08, 0.03), 0.1, 0.4)
	_led = cylinder(bar_h * 0.45, 0.002, Vector3(size.x * 0.43, -size.y * 0.5 + bar_h, 0.0008),
			Vector3(PI * 0.5, 0, 0), _led_off, 10, screen)


## The display's glass (metres): big enough to read at arm's length.
const DISPLAY_SIZE := Vector2(0.13, 0.095)
## Where the display stands off its knuckle, in the view's terms (metres): left, up, and
## back toward the eye.
const ARM_REACH := Vector3(0.1, 0.075, 0.0)
## The lowest the display's middle comes in the view, as a share of the half height below the
## middle (0.45: just over the hotbar).
const DISPLAY_LOW := 0.45
## The nearest the display comes to the eye (metres).
const DISPLAY_NEAR := 0.5
## The furthest it stays from the eye (metres).
const DISPLAY_FAR := 0.65
## Close up (first person) the display stands off to one side of where you're pointing
## (beenster, 2026-10-22: "right in the way of where we are pointing"): its middle this share
## of the half width left of the view's middle and this share of the half height above it, at
## DISPLAY_NEAR from the eye. In third person it keeps to its knuckle.
const SIDE_X := 0.62
const SIDE_Y := 0.1
## Looking through the worker's own eyes (the bay sets it each frame).
static var first_person := true

var _swivel: Node3D
var _knuckle: Node3D
var _arm: MeshInstance3D

## Boxes thinner than this (metres) stay sharp: a bevel would eat them.
const MIN_CHAMFERED := 0.006
static var _chamfered: Dictionary = {}


## The display on an arm where the screen was: a puck on the body with a knuckle, a steel
## arm, and the screen in a rubber bezel at its end, held up and to the left of the tool as
## you see it (clear of your hand) and turned to face your eye, in your hand or on the work.
func _build_swivel(base: Node3D, accent: Color) -> void:
	var dark := anodised()
	cylinder(0.011, 0.004, Vector3(0, 0, 0.001), Vector3(PI * 0.5, 0, 0), dark, 16, base)
	var knuckle := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.0065
	sphere.height = 0.013
	knuckle.mesh = sphere
	knuckle.material_override = dark
	knuckle.position = Vector3(0, 0, 0.006)
	knuckle.name = "Knuckle"
	base.add_child(knuckle)
	_knuckle = knuckle
	# The arm: a unit-long rod the frame stretches from the knuckle to the screen's back.
	_arm = cylinder(0.003, 1.0, Vector3.ZERO, Vector3.ZERO, steel(), 10, base)
	_arm.name = "Arm"
	_swivel = Node3D.new()
	_swivel.name = "Swivel"
	base.add_child(_swivel)
	# The head hangs on the arm by the middle of its back, its glass facing +Z (the eye).
	var head := Node3D.new()
	head.position = Vector3(0, 0, 0.012)
	_swivel.add_child(head)
	var s := DISPLAY_SIZE
	box(Vector3(s.x + 0.01, s.y + 0.01, 0.009), Vector3(0, 0, -0.0045), rubber(), Vector3.ZERO, head)
	box(Vector3(s.x + 0.014, 0.004, 0.011), Vector3(0, (s.y + 0.01) * 0.5, -0.0045), body(), Vector3.ZERO, head)
	box(Vector3(0.02, 0.014, 0.006), Vector3(0, 0, -0.011), dark, Vector3.ZERO, head)
	_display = TradesToolDisplay.new()
	_display.name = "Display"
	head.add_child(_display)
	_display.build(s, accent)


## Holds the screen out on its arm (up and left of the knuckle as the camera sees it), faces it
## to the eye, upright the way the view is, and stretches the arm to it.
func _turn_swivel() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or _swivel == null:
		return
	var view := cam.global_basis
	var from := _knuckle.global_position
	var at := from + view.y * ARM_REACH.y - view.x * ARM_REACH.x + view.z * ARM_REACH.z
	# Never lower than DISPLAY_LOW down the view (some tools hang below it in your hand): the
	# arm reaches up further instead.
	# And never nearer the eye than DISPLAY_NEAR (some tools' backs come close), so it reads
	# the same size whichever tool it's on.
	# Out on the work the arm telescopes back toward you like your hands do, holding the display
	# within DISPLAY_FAR so it still reads.
	var local := cam.global_transform.affine_inverse() * at
	if first_person:
		var tan_v := tan(deg_to_rad(cam.fov) * 0.5)
		var view_px := get_viewport().get_visible_rect().size
		var aspect := view_px.x / maxf(1.0, view_px.y)
		local = Vector3(-SIDE_X * DISPLAY_NEAR * tan_v * aspect, SIDE_Y * DISPLAY_NEAR * tan_v, -DISPLAY_NEAR)
	elif -local.z < DISPLAY_NEAR:
		local.z = -DISPLAY_NEAR
	if local.length() > DISPLAY_FAR:
		local *= DISPLAY_FAR / local.length()
	local.y = maxf(local.y, local.z * tan(deg_to_rad(cam.fov) * 0.5) * DISPLAY_LOW)
	at = cam.global_transform * local
	var to_eye := cam.global_position - at
	if to_eye.length() < 0.01:
		return
	var z := to_eye.normalized()
	var x := view.y.cross(z)
	if x.length() < 0.01:
		return
	x = x.normalized()
	_swivel.global_transform = Transform3D(Basis(x, z.cross(x), z), at)
	var along := at - from
	var length := along.length()
	if length < 0.001:
		_arm.visible = false
		return
	_arm.visible = true
	var y := along / length
	var side := y.cross(Vector3.UP if absf(y.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT).normalized()
	_arm.global_transform = Transform3D(Basis(side, y * length, side.cross(y)), from + along * 0.5)


## A basis whose +Z faces along `normal` with its +Y as near `up` as it can be.
static func facing(normal: Vector3, up: Vector3) -> Basis:
	var z := normal.normalized()
	var x := up.cross(z).normalized()
	return Basis(x, z.cross(x), z)


## Printed lettering on the body (the BSX mark, a scale), facing along `normal`.
func print_text(text: String, at: Vector3, normal: Vector3, up: Vector3, height: float,
		color := Color(0.95, 0.95, 0.92)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = TradesLook.mono_font()
	l.font_size = 48
	l.pixel_size = height / 48.0
	l.modulate = color
	l.outline_size = 0
	l.shaded = true
	l.position = at
	l.basis = facing(normal, up)
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(l)
	return l


## A rounded grip or body: a capsule along its own Y (rot X 90 degrees lays it along Z).
func capsule(radius: float, length: float, at: Vector3, rot: Vector3, mat: Material, parent: Node = self) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(length, radius * 2.0)
	mesh.radial_segments = 16
	mesh.rings = 4
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	m.rotation = rot
	parent.add_child(m)
	return m


## Rubber rings round a grip along `axis` from `from`, `count` of them `pitch` apart.
func ribs(radius: float, from: Vector3, axis: Vector3, count: int, pitch: float, parent: Node = self) -> void:
	var b := facing(axis, Vector3.UP if absf(axis.normalized().y) < 0.9 else Vector3.FORWARD) * Basis(Vector3.RIGHT, PI * 0.5)
	for i in count:
		var r := cylinder(radius, pitch * 0.45, from + axis.normalized() * pitch * i, Vector3.ZERO, rubber(), 14, parent)
		r.basis = b


func box(size: Vector3, at: Vector3, mat: Material, rot := Vector3.ZERO, parent: Node = self) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = _box_mesh(size)
	m.material_override = mat
	m.position = at
	m.rotation = rot
	parent.add_child(m)
	return m


## A box's mesh: with trades.tool_look, edges bevelled so they catch the light (the shared
## parts library's chamfer_box), one mesh per size.
static func _box_mesh(size: Vector3) -> Mesh:
	var least := minf(size.x, minf(size.y, size.z))
	if not Flags.is_on("trades.tool_look") or least < MIN_CHAMFERED:
		var plain := BoxMesh.new()
		plain.size = size
		return plain
	var key := "%.4f/%.4f/%.4f" % [size.x, size.y, size.z]
	if not _chamfered.has(key):
		_chamfered[key] = PartShapes.chamfer_box(size, minf(least * 0.22, 0.004)).mesh
	return _chamfered[key]


## A cylinder along its own Y (rot X 90 degrees lays it along Z).
func cylinder(radius: float, length: float, at: Vector3, rot: Vector3, mat: Material, radial := 16,
		parent: Node = self, top_radius := -1.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = radial
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	m.rotation = rot
	parent.add_child(m)
	return m


## The tools' finishes: with trades.tool_look, paint on the shared salvage surface shader with
## a finish from the yard's library (brushed steel, anodised alloy, textured plastic, rubber),
## so they catch the light like the ship and the yard; plain metals without it.
static func finish(color: Color, metallic: float, roughness: float, finish_id: String) -> Material:
	if Flags.is_on("trades.tool_look"):
		return TradesLook.paint(color, metallic, roughness, finish_id)
	return TradesLook.metal(color, metallic, roughness)


static func steel() -> Material:
	return finish(Color(0.72, 0.73, 0.75), 0.95, 0.25, "brushed_steel")


static func dark() -> Material:
	return finish(Color(0.13, 0.13, 0.15), 0.4, 0.6, "gunmetal")


static func body() -> Material:
	return finish(TradesLook.TRIM, 0.15, 0.5, "plastic_textured")


static func rubber() -> Material:
	return finish(RUBBER, 0.0, 0.85, "rubber")


## Satin black anodised alloy (heads, chucks, yokes).
static func anodised() -> Material:
	return finish(Color(0.2, 0.21, 0.23), 0.75, 0.38, "anodised")
