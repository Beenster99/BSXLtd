extends CanvasLayer
## The picture-in-picture view while you drive a hover trolley on remote: a framed window in
## the bottom right corner showing the trolley's own camera (just behind and over it, looking
## where it goes), with its name, status and the keys, in the TV terminals' style. The camera
## follows the trolley every frame; your own view stays where you stand.

const T := preload("res://modules/ui/api/terminal_kit.gd")

## The window's size on screen, pixels (at 1080 p; it scales with the window height).
const WINDOW := Vector2(560, 340)
## The camera behind and over the trolley's centre, metres, and how far ahead it looks.
const BEHIND := 3.4
const ABOVE := 2.3
const AHEAD := 2.5

var trolley: Node3D
var camera: Camera3D
var viewport: SubViewport
var _frame: PanelContainer
var _title: Label
var _status: Label
## 0 looking where its nose points, 1 turned round to look back while it backs up.
var _back := 0.0


func _init() -> void:
	layer = 6
	name = "RemoteView"


func _ready() -> void:
	_frame = PanelContainer.new()
	_frame.name = "Frame"
	_frame.add_theme_stylebox_override("panel", T.box(T.KIOSK, T.ORANGE, 2, 6.0))
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	_title = T.label("", "display_bold", 22, T.TEXT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_status = T.label("", "mono_medium", 16, T.CYAN)
	head.add_child(_status)
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.custom_minimum_size = WINDOW
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(holder)
	viewport = SubViewport.new()
	viewport.name = "Viewport"
	viewport.size = Vector2i(WINDOW)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = false
	holder.add_child(viewport)
	camera = Camera3D.new()
	camera.name = "TrolleyCamera"
	camera.fov = 68.0
	camera.near = 0.05
	camera.far = 3000.0
	viewport.add_child(camera)
	camera.current = true
	var deck_keys := "%s %s" % [Keys.key_name("ship_bay.raise"), Keys.key_name("ship_bay.lower")] if Keys.has("ship_bay.raise") else "UP DOWN"
	var keys := T.label("W S drive · A D / mouse turn · %s deck · SHIFT fast · F hand back" % deck_keys.to_upper(), "mono", 14, T.DIM)
	keys.clip_text = true
	keys.custom_minimum_size.x = WINDOW.x
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(keys)
	_place_frame()
	get_viewport().size_changed.connect(_place_frame)


## Shows `t`'s camera, with its name.
func show_trolley(t: Node3D, title: String) -> void:
	trolley = t
	_title.text = "REMOTE  ·  " + title.to_upper()
	_follow()


func set_status(text: String) -> void:
	_status.text = text


func _process(delta: float) -> void:
	if trolley and is_instance_valid(trolley) and trolley.has_method("speed"):
		var v := float(trolley.call("speed"))
		if absf(v) > 0.15:
			_back = move_toward(_back, 1.0 if v < 0.0 else 0.0, delta * 1.5)
	_follow()


func _follow() -> void:
	if trolley == null or not is_instance_valid(trolley) or camera == null:
		return
	var b := trolley.global_basis
	var at := trolley.global_position
	var fwd := -b.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	# The camera looks the way it travels: round behind it while it backs up.
	fwd = fwd.rotated(Vector3.UP, smoothstep(0.0, 1.0, _back) * PI)
	# Bigger trolleys (the large one's long deck) put it further back and higher.
	var k := maxf(1.0, float(trolley.call("radius")) / 0.85) if trolley.has_method("radius") else 1.0
	var eye := at - fwd * BEHIND * k + Vector3(0, ABOVE * k, 0)
	# Pulled in short of a wall behind it, so the view never looks through one.
	var top := at + Vector3(0, ABOVE * k, 0)
	var q := PhysicsRayQueryParameters3D.create(top, eye)
	q.exclude = [(trolley as CollisionObject3D).get_rid()] if trolley is CollisionObject3D else []
	var hit := trolley.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		eye = (hit.position as Vector3) + (top - eye).normalized() * 0.25
	camera.global_transform = Transform3D(Basis.looking_at(at + fwd * AHEAD + Vector3(0, 0.6, 0) - eye), eye)


func _place_frame() -> void:
	if _frame == null:
		return
	var win := get_viewport().get_visible_rect().size
	var k := clampf(win.y / 1080.0, 0.6, 2.0)
	_frame.scale = Vector2(k, k)
	_frame.reset_size()
	var size := _frame.get_combined_minimum_size()
	_frame.size = size
	_frame.position = win - size * k - Vector2(24, 24)
