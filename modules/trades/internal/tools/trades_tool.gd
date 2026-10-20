class_name TradesTool
extends Node3D
## A hand tool on the bay's hotbar, built in code the way Void Salvage builds its tools
## (SalvageTool): boxes, cylinders and capsules in plain metals and rubber, the body in BSX
## orange, and a small screen set into the body with its live readings (torque, amps...),
## a fill bar and a status light. A station puts it on the work while it is in use;
## otherwise the bay carries it in the right hand.

const RUBBER := Color(0.09, 0.09, 0.1)
const GLASS := Color(0.012, 0.03, 0.035)

## Where the hand closes on it, in its own space.
var grip := Vector3.ZERO
## How it sits in a relaxed right hand: its own space as seen from the palm (fingers along
## -Z, back of the hand +Y).
var hold := Transform3D()

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


func _process(_delta: float) -> void:
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
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	m.rotation = rot
	parent.add_child(m)
	return m


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


static func steel() -> StandardMaterial3D:
	return TradesLook.metal(Color(0.72, 0.73, 0.75), 0.95, 0.25)


static func dark() -> StandardMaterial3D:
	return TradesLook.metal(Color(0.13, 0.13, 0.15), 0.4, 0.6)


static func body() -> StandardMaterial3D:
	return TradesLook.metal(TradesLook.TRIM, 0.3, 0.55)


static func rubber() -> StandardMaterial3D:
	return TradesLook.metal(RUBBER, 0.0, 0.85)


## Satin black anodised alloy (heads, chucks, yokes).
static func anodised() -> StandardMaterial3D:
	return TradesLook.metal(Color(0.2, 0.21, 0.23), 0.75, 0.38)
