extends CanvasLayer
## Finding the fastenings still to make (beenster, 0.5.3: "the welds are VERY hard to find"):
## over the view, each pending weld, rivet or bolt of the build in the berth gets a pulsing
## diamond that shows through beams and plates and stays the same size however far off it is;
## the nearest one is named with how far it is, and when it is off screen or behind you an arrow
## at the edge of the screen points the way to it. Drawn on every machine from the berth's own
## chalked plans, so a crewmate's view shows the same marks, in first or third person.
## Flag `build.weld_beacons`.

const FLAG := "build.weld_beacons"
## Draw the beacons only while the camera is this close to the ship's box (m).
const RANGE := 60.0
## The diamond's half size (px), and the edge arrow's distance in from the screen's sides and top
## and from its bottom, clear of the tool belt (px).
const DIAMOND := 12.0
const EDGE := 60.0
const EDGE_BOTTOM := 130.0
## Colours none of the yard's orange trim or the blue holo share.
const WELD_COLOUR := Color(0.72, 1.0, 0.18)
const BOLT_COLOUR := Color(1.0, 0.45, 0.85)
const RIVET_COLOUR := Color(1.0, 0.9, 0.2)

var berth: Node
var _view: Control
var _font: Font


func setup(b: Node) -> CanvasLayer:
	berth = b
	return self


func _ready() -> void:
	name = "WeldBeacons"
	layer = 9
	_view = Control.new()
	_view.name = "View"
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_view)
	add_child(_view)
	_font = BsxTheme.get_theme().default_font if BsxTheme.get_theme() else null
	if _font == null:
		_font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	_view.queue_redraw()


static func label_of(kind: int) -> String:
	match kind:
		ConnectionData.Kind.WELD:
			return "WELD"
		ConnectionData.Kind.BOLT:
			return "BOLT"
	return "RIVET"


static func colour_of(kind: int) -> Color:
	match kind:
		ConnectionData.Kind.WELD:
			return WELD_COLOUR
		ConnectionData.Kind.BOLT:
			return BOLT_COLOUR
	return RIVET_COLOUR


## The pending fastenings in world space: [{at: Vector3, kind: int}].
func targets() -> Array:
	var out := []
	if berth == null or not is_instance_valid(berth):
		return out
	var work := berth.get("work") as Node3D
	if work == null or not work.is_inside_tree():
		return out
	var plans: Dictionary = berth.get("plans")
	for key: String in plans:
		var p: Dictionary = plans[key]
		out.append({"at": work.global_transform * (p.at as Vector3), "kind": int(p.kind)})
	return out


## True when the beacons should show to `cam` (near the ship, nothing using the mouse).
func showing(cam: Camera3D) -> bool:
	if cam == null or berth == null or not is_instance_valid(berth) or HudSlots.pointer_claimed():
		return false
	var bp: Object = berth.get("bp")
	var ship := berth.get("ship") as Node3D
	if bp == null or ship == null or not ship.is_inside_tree():
		return false
	var box: AABB = (bp.get("bounds") as AABB).grow(RANGE)
	return box.has_point(ship.global_transform.affine_inverse() * cam.global_position)


## The nearest target to `from`, or {} when there is none.
static func nearest(list: Array, from: Vector3) -> Dictionary:
	var best := {}
	var bd := INF
	for t: Dictionary in list:
		var d := from.distance_to(t.at as Vector3)
		if d < bd:
			bd = d
			best = t
	return best


func _draw_view() -> void:
	var cam := _view.get_viewport().get_camera_3d()
	if not showing(cam):
		return
	var list := targets()
	if list.is_empty():
		return
	var size := _view.get_viewport_rect().size
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	var near := nearest(list, cam.global_position)
	for t: Dictionary in list:
		var at: Vector3 = t.at
		if cam.is_position_behind(at):
			continue
		var s := cam.unproject_position(at)
		if not Rect2(Vector2.ZERO, size).has_point(s):
			continue
		var c := colour_of(int(t.kind))
		var r := DIAMOND * (1.0 + 0.25 * pulse) * (1.25 if t == near else 1.0)
		_diamond(s, r + 4.0, Color(0, 0, 0, 0.55), 3.0)
		_diamond(s, r, c, 3.0)
		_diamond(s, r * 0.4, Color(c, 0.6 + 0.4 * pulse), 0.0)
	_point_to(cam, near, size, list.size(), pulse)


## The nearest one: its name and distance beside its diamond, or an arrow at the screen's edge
## pointing the way when it is off screen or behind.
func _point_to(cam: Camera3D, t: Dictionary, size: Vector2, left: int, pulse: float) -> void:
	var at: Vector3 = t.at
	var c := colour_of(int(t.kind))
	var d := cam.global_position.distance_to(at)
	var text := "%s  %.1f m" % [label_of(int(t.kind)), d]
	if left > 1:
		text += "   (%d left)" % left
	var behind := cam.is_position_behind(at)
	var s := cam.unproject_position(at)
	var rect := Rect2(Vector2.ZERO, size)
	if not behind and rect.has_point(s):
		_label(s + Vector2(DIAMOND * 2.0 + 6.0, 6.0), text, c)
		return
	# Off screen: the way to it on the screen's plane, from the middle.
	var local := cam.global_transform.affine_inverse() * at
	var dir := Vector2(local.x, -local.y)
	if dir.length() < 0.001:
		dir = Vector2.DOWN
	dir = dir.normalized()
	var area := Rect2(Vector2(EDGE, EDGE), size - Vector2(EDGE * 2.0, EDGE + EDGE_BOTTOM))
	var mid := area.get_center()
	var half := area.size * 0.5
	var k := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
	var tip := mid + dir * k
	var arrow := 26.0 + 5.0 * pulse
	var side := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([tip + dir * arrow, tip - dir * arrow * 0.6 + side * arrow * 0.8,
			tip - dir * arrow * 0.25, tip - dir * arrow * 0.6 - side * arrow * 0.8])
	var shadow := PackedVector2Array()
	for p: Vector2 in pts:
		shadow.append(p + Vector2(2, 2))
	_view.draw_colored_polygon(shadow, Color(0, 0, 0, 0.5))
	_view.draw_colored_polygon(pts, c)
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var at_text := tip - dir * (arrow + 34.0) - Vector2(w * 0.5, -6.0)
	at_text.x = clampf(at_text.x, 8.0, size.x - w - 8.0)
	at_text.y = clampf(at_text.y, 24.0, size.y - EDGE_BOTTOM + 30.0)
	_label(at_text, text, c)


func _diamond(s: Vector2, r: float, c: Color, width: float) -> void:
	var pts := PackedVector2Array([s + Vector2(0, -r), s + Vector2(r, 0), s + Vector2(0, r), s + Vector2(-r, 0)])
	if width <= 0.0:
		_view.draw_colored_polygon(pts, c)
		return
	pts.append(pts[0])
	_view.draw_polyline(pts, c, width, true)


func _label(at: Vector2, text: String, c: Color) -> void:
	_view.draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, 0.8))
	_view.draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, c)
