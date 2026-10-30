extends Node
## Routes the mouse to the yard's touch screens (touch_screen.gd): every frame it finds the
## screen the view's centre is on (within REACH and not behind a wall), moves a pointer
## across it and hovers its buttons; a left click there presses the button under the
## pointer, and the release goes to the same screen (so a held RAISE lets go even if you look
## away). One per scene tree, made by the first screen that needs it (`ensure`).

const GROUP := "ship_bay_touch"
## How far you can reach a screen from, metres.
const REACH := 3.0
const PENDING_META := &"ship_bay_touch_pointer"

## The screen the view is on, and where (viewport pixels).
var aimed: Node3D
var aimed_px := Vector2.ZERO
var _held: Node3D
var _held_px := Vector2.ZERO


## The tree's pointer, made under the root if there is none yet.
static func ensure(tree: SceneTree) -> Node:
	var p := tree.root.get_node_or_null("ShipBayTouchPointer")
	# One made this frame is still waiting to go in (added deferred): every screen built in the
	# same frame made its own before, some thirty pointers each testing every screen each frame.
	if p == null and tree.root.has_meta(PENDING_META) and is_instance_valid(tree.root.get_meta(PENDING_META)):
		p = tree.root.get_meta(PENDING_META)
	if p == null:
		p = (load("res://modules/ship_bay/internal/kit/touch_pointer.gd") as GDScript).new()
		p.name = "ShipBayTouchPointer"
		tree.root.set_meta(PENDING_META, p)
		tree.root.add_child.call_deferred(p)
	return p


## The pointer's look: a small lit ring with a dot.
static func dot() -> Control:
	var c := Control.new()
	c.name = "Pointer"
	c.size = Vector2(22, 22)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.visible = false
	c.z_index = 100
	c.draw.connect(func() -> void:
		c.draw_arc(Vector2(11, 11), 9.0, 0.0, TAU, 24, Color(1.0, 0.62, 0.25), 2.5, true)
		c.draw_circle(Vector2(11, 11), 2.5, Color(1.0, 0.85, 0.6)))
	return c


func _process(_delta: float) -> void:
	var hit := aim()
	var screen: Node3D = hit[0]
	var px: Vector2 = hit[1]
	if aimed and is_instance_valid(aimed) and aimed != screen:
		aimed.call("show_pointer", Vector2.ZERO, false)
		_motion(aimed, Vector2(-100, -100))
	if screen and (screen != aimed or px.distance_to(aimed_px) > 0.5):
		_motion(screen, px)
	aimed = screen
	aimed_px = px
	if screen:
		screen.call("show_pointer", px, true)


## [screen, pixel] where the camera's view centre meets a screen, or [null, ZERO].
func aim() -> Array:
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp else null
	if cam == null or not cam.is_inside_tree():
		return [null, Vector2.ZERO]
	var from := cam.global_position
	var dir := -cam.global_basis.z
	var best: Node3D = null
	var best_px := Vector2.ZERO
	var best_t := REACH
	for s: Node in get_tree().get_nodes_in_group(GROUP):
		var screen := s as Node3D
		if screen == null or not screen.is_visible_in_tree():
			continue
		var h: Array = screen.call("hit_pixel", from, dir)
		if float(h[1]) < best_t:
			best = screen
			best_px = h[0]
			best_t = h[1]
	if best == null:
		return [null, Vector2.ZERO]
	# Not through a wall: the first solid thing along the ray must not be well in front.
	var space := cam.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * best_t)
	var wall := space.intersect_ray(q)
	if not wall.is_empty() and from.distance_to(wall.position) < best_t - 0.15:
		return [null, Vector2.ZERO]
	return [best, best_px]


func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	# A screen in front of the view (the wrist holo, a menu) keeps its clicks.
	if get_viewport().gui_get_hovered_control() != null:
		return
	if mb.pressed and aimed and is_instance_valid(aimed):
		_held = aimed
		_held_px = aimed_px
		_click(aimed, aimed_px, true)
		get_viewport().set_input_as_handled()
	elif not mb.pressed and _held and is_instance_valid(_held):
		_click(_held, aimed_px if aimed == _held else _held_px, false)
		_held = null
		get_viewport().set_input_as_handled()


func _motion(screen: Node3D, px: Vector2) -> void:
	var vp: SubViewport = screen.get("viewport")
	var m := InputEventMouseMotion.new()
	m.position = px
	m.global_position = px
	vp.push_input(m, true)


func _click(screen: Node3D, px: Vector2, down: bool) -> void:
	var vp: SubViewport = screen.get("viewport")
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = down
	b.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	b.position = px
	b.global_position = px
	vp.push_input(b, true)
