extends CanvasLayer
## The emote wheel: held open (middle mouse held, through Graphics' ping input), the player
## moves the mouse toward a signal and lets go to send it; let go in the middle to send
## nothing. The view doesn't turn while it's open: it claims the pointer, and with the
## mouse captured the wheel reads mouse movement instead of a position. Owned by the crew.

const CLAIM := "multiplayer.emotes"
const RADIUS := 150.0
const DEAD := 30.0  # mouse travel before a slice is picked
const SENT_TIME := 1.2

var emotes: Array[Dictionary] = []
var is_open := false
var _aim := Vector2.ZERO
var _canvas: Control
var _sent := ""
var _sent_left := 0.0


func _ready() -> void:
	name = "EmoteWheel"
	layer = 20
	_canvas = Control.new()
	_canvas.name = "Wheel"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_wheel)
	add_child(_canvas)
	_canvas.visible = false


func open() -> void:
	if is_open:
		return
	is_open = true
	_aim = Vector2.ZERO
	_sent_left = 0.0
	HudSlots.claim_pointer(CLAIM)
	_canvas.visible = true
	_canvas.queue_redraw()


## Closes the wheel and gives the picked emote's id ("" for none).
func close() -> String:
	if not is_open:
		return ""
	is_open = false
	HudSlots.release_pointer(CLAIM)
	var picked := selected()
	_sent = ""
	for e in emotes:
		if e.id == picked:
			_sent = e.label
	_sent_left = SENT_TIME if _sent != "" else 0.0
	_canvas.visible = _sent_left > 0.0
	_canvas.queue_redraw()
	return picked


## The emote the mouse points at now, or "".
func selected() -> String:
	var i := slice_at(_aim, emotes.size())
	return emotes[i].id if i >= 0 else ""


## Which of `count` slices (clockwise from the top) a direction picks; -1 in the middle.
static func slice_at(aim: Vector2, count: int) -> int:
	if aim.length() < DEAD or count == 0:
		return -1
	var turn := fposmod(atan2(aim.x, -aim.y), TAU)
	return int(roundf(turn / (TAU / count))) % count


## Points the wheel (tests, and a free mouse).
func aim(at: Vector2) -> void:
	_aim = at.limit_length(RADIUS)
	_canvas.queue_redraw()


func _exit_tree() -> void:
	if is_open:
		HudSlots.release_pointer(CLAIM)


func _process(delta: float) -> void:
	if _sent_left > 0.0:
		_sent_left -= delta
		if _sent_left <= 0.0 and not is_open:
			_canvas.visible = false
		_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	var motion := event as InputEventMouseMotion
	if motion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			aim(_aim + motion.relative)
		else:
			aim(motion.position - _canvas.get_rect().size * 0.5)
		_canvas.get_viewport().set_input_as_handled()


func _draw_wheel() -> void:
	var centre := _canvas.get_rect().size * 0.5
	var font := ThemeDB.fallback_font
	if not is_open:
		if _sent_left > 0.0:
			var text := "Sent: %s" % _sent
			var a := clampf(_sent_left / 0.4, 0.0, 1.0)
			_canvas.draw_string(font, centre + Vector2(-RADIUS, RADIUS * 0.6), text, HORIZONTAL_ALIGNMENT_CENTER,
					RADIUS * 2.0, 22, Color(1, 0.82, 0.4, a))
		return
	var count := emotes.size()
	var pick := slice_at(_aim, count)
	_canvas.draw_circle(centre, RADIUS + 40.0, Color(0.05, 0.06, 0.08, 0.55))
	_canvas.draw_arc(centre, DEAD, 0.0, TAU, 32, Color(1, 1, 1, 0.35), 2.0)
	for i in count:
		var dir := Vector2.from_angle(i * TAU / count - PI / 2.0)
		var at := centre + dir * RADIUS
		var lit := i == pick
		_canvas.draw_circle(at, 34.0, Color("e8792b") if lit else Color(1, 1, 1, 0.12))
		_canvas.draw_string(font, at + Vector2(-60, 6), emotes[i].label, HORIZONTAL_ALIGNMENT_CENTER, 120,
				18 if lit else 15, Color.WHITE if lit else Color(1, 1, 1, 0.8))
	_canvas.draw_line(centre, centre + _aim, Color(1, 0.82, 0.4, 0.8), 2.0)
	var hint: String = emotes[pick].label if pick >= 0 else "Let go to cancel"
	_canvas.draw_string(font, centre + Vector2(-RADIUS, 6), hint, HORIZONTAL_ALIGNMENT_CENTER, RADIUS * 2.0, 16,
			Color(1, 1, 1, 0.9))
