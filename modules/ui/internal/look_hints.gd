class_name LookHints
extends Node
## Puts the "what you're looking at" card in the info panel: casts the view's ray a few
## times a second, asks HudSlots.look_hint_for() what it hits (an aimed TouchScreen first),
## and shows its title, text and keys, or no card when there's nothing to say. The UI bus
## owns one for the whole game.

const CARD := "ui.look"
## Above every module's card.
const ORDER := -100
## How often the ray is cast, s.
const EVERY := 0.1

var current: Dictionary = {}
var _tick := 0.0


func _ready() -> void:
	name = "LookHints"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = EVERY
	refresh()


## Looks again now and updates the card.
func refresh() -> void:
	show_hint(look())


## The hint for what the view's centre is on now ({} for none).
func look() -> Dictionary:
	if str(Router.current_id) in ["main_menu", "settings", "boot", ""]:
		return {}
	var screen := TouchScreen.current()
	if screen:
		return screen.look_hint()
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp else null
	if cam == null or not cam.is_inside_tree():
		return {}
	var from := cam.global_position
	var dir := -cam.global_basis.z
	var hit := {"collider": null, "position": from + dir * HudSlots.LOOK_REACH, "normal": Vector3.ZERO,
			"from": from, "direction": dir}
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * HudSlots.LOOK_REACH)
	q.collide_with_areas = true
	var got := cam.get_world_3d().direct_space_state.intersect_ray(q)
	if not got.is_empty():
		hit.collider = got.collider
		hit.position = got.position
		hit.normal = got.normal
	return HudSlots.look_hint_for(hit)


func show_hint(hint: Dictionary) -> void:
	current = hint
	if hint.is_empty():
		HudSlots.clear_info(CARD)
		return
	HudSlots.set_info(CARD, str(hint.get("title", "")), text_of(hint), ORDER)


## The card's text: the hint's text, then one line per key ("[F]  Push it").
static func text_of(hint: Dictionary) -> String:
	var lines := PackedStringArray()
	if str(hint.get("text", "")) != "":
		lines.append(str(hint.text))
	for k: Variant in hint.get("keys", []):
		var pair := k as Array
		if pair == null or pair.size() < 2:
			continue
		var key := str(pair[0])
		lines.append("%s  %s" % [Keys.prompt(key) if Keys.has(key) else "[%s]" % key, str(pair[1])])
	return "\n".join(lines)
