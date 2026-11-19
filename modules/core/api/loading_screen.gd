extends CanvasLayer
## The loading screen (flag "core.loading_screen", 19 Nov playtest: "I get in game then have
## to wait before my character can move, it always feels like the game has crashed"). Router
## owns one and shows it for Router.goto_loading(); it covers the window, holds the controls
## (HudSlots pointer claim "core.loading") and stays up until the new scene is ready to play:
##   1. drawn over the old scene for a couple of frames, then the scene changes (its build
##      blocks the window, so the bar sits at "Building" meanwhile);
##   2. the scene and its modules finish their own work, reported as holds
##      (Router.hold_loading / loading_progress / release_loading): the rooms' bounce light,
##      a guest catching up with the host's yard...;
##   3. the frames settle (SETTLE_FRAMES in a row under SETTLE_FRAME_MS), so the first thing
##      you do is felt at once.
## A load that never finishes still ends after GIVE_UP_S, so nothing can lock the game.
## Plain shapes and Godot's default font: Core draws without UI.

signal finished

const POINTER_ID := "core.loading"
## A frame quicker than this counts as settled (ms).
const SETTLE_FRAME_MS := 70.0
## This many settled frames in a row and the scene is ready.
const SETTLE_FRAMES := 20
## Ready or not, the screen goes after this long (s).
const GIVE_UP_S := 180.0
## Settling ends after this long even if the frames never calm (a slow PC) (s).
const SETTLE_GIVE_UP_S := 12.0
## The fade at the end (s).
const FADE_S := 0.35
## Where the bar stands at each step (0..1): before the build, after it, and once every
## hold is done (the settle runs from there to 1).
const AT_START := 0.05
const AT_BUILT := 0.3
const AT_HELD := 0.9

const BACK := Color("0b0f14")
const ACCENT := Color("e8a33c")
const TEXT := Color("e6edf3")
const MUTED := Color("8b98a5")

var active := false
## What the screen says it is loading ("Orbital yard").
var title := ""
## The bar's target (0..1); the bar eases to it and never goes back.
var target := 0.0
var _shown := 0.0
var _stage := ""
## key -> {label, fraction}: work a scene or module is still doing.
var _holds: Dictionary = {}
## Every hold this load had, done or not (the bar's share for holds is the mean over them).
var _seen: Dictionary = {}
var _phase := ""   # "", "before", "built", "holds", "settle", "fade"
var _started_ms := 0
var _settle_from_ms := 0
var _calm := 0
var _last_us := 0
var _fade := 0.0

var _root: Control
var _title: Label
var _status: Label
var _bar_back: ColorRect
var _bar_fill: ColorRect
var _percent: Label


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


## Shows the screen for a load of `what` ("Orbital yard").
func begin(what: String) -> void:
	title = what
	active = true
	_holds.clear()
	_seen.clear()
	_shown = 0.0
	target = AT_START
	_phase = "before"
	_started_ms = Time.get_ticks_msec()
	_calm = 0
	_fade = 0.0
	_last_us = Time.get_ticks_usec()
	_stage = "Loading..."
	_root.modulate.a = 1.0
	visible = true
	HudSlots.claim_pointer(POINTER_ID)
	_refresh()


## The scene is in the tree (its _ready has run).
func scene_built() -> void:
	if not active:
		return
	target = maxf(target, AT_BUILT)
	_phase = "holds"
	_stage = "Getting everything ready..."
	_refresh()


func hold(key: String, label: String) -> void:
	if not active or _phase == "fade":
		return
	var h: Dictionary = _holds.get(key, {"fraction": 0.0})
	h.label = label if label != "" else str(h.get("label", ""))
	_holds[key] = h
	_seen[key] = true
	if _phase == "settle":
		_phase = "holds"


func progress(key: String, fraction: float, label: String) -> void:
	if not _holds.has(key):
		return
	_holds[key].fraction = clampf(fraction, 0.0, 1.0)
	if label != "":
		_holds[key].label = label


func release(key: String) -> void:
	_holds.erase(key)


## Ends the load now (the scene could not open).
func release_all() -> void:
	_holds.clear()
	_end()


func holding(key: String) -> bool:
	return _holds.has(key)


func _process(delta: float) -> void:
	if not visible:
		return
	var now_us := Time.get_ticks_usec()
	var frame_ms := (now_us - _last_us) / 1000.0
	_last_us = now_us
	var elapsed := (Time.get_ticks_msec() - _started_ms) / 1000.0
	if active and elapsed > GIVE_UP_S and _phase != "fade":
		push_warning("Loading screen: gave up waiting for %s" % str(_holds.keys()))
		_holds.clear()
		_end()
	match _phase:
		"holds":
			if _holds.is_empty():
				_phase = "settle"
				_settle_from_ms = Time.get_ticks_msec()
				_calm = 0
			else:
				var done := 0.0
				for k: String in _seen:
					done += float(_holds[k].fraction) if _holds.has(k) else 1.0
				target = maxf(target, lerpf(AT_BUILT, AT_HELD, done / maxf(1.0, _seen.size())))
				# The newest hold says what is happening (it is usually the slow one).
				var last: Dictionary = _holds.values()[-1]
				_stage = str(last.get("label", "")) if str(last.get("label", "")) != "" else "Getting everything ready..."
		"settle":
			_stage = "Nearly there..."
			_calm = _calm + 1 if frame_ms < SETTLE_FRAME_MS else 0
			target = maxf(target, lerpf(AT_HELD, 1.0, float(_calm) / SETTLE_FRAMES))
			if _calm >= SETTLE_FRAMES or Time.get_ticks_msec() - _settle_from_ms > SETTLE_GIVE_UP_S * 1000.0:
				_end()
		"fade":
			_fade += delta
			_root.modulate.a = 1.0 - clampf(_fade / FADE_S, 0.0, 1.0)
			if _fade >= FADE_S:
				visible = false
				_phase = ""
	# The bar eases toward its target over real time (a long frame catches it right up).
	_shown = minf(target, _shown + maxf(0.002, (target - _shown) * (1.0 - exp(-frame_ms / 1000.0 * 6.0))))
	_refresh()


func _end() -> void:
	if not active:
		return
	active = false
	target = 1.0
	_shown = 1.0
	_stage = "Ready"
	_phase = "fade"
	_fade = 0.0
	HudSlots.release_pointer(POINTER_ID)
	finished.emit()


func _refresh() -> void:
	_title.text = title.to_upper() if title != "" else ""
	_status.text = _stage
	_percent.text = "%d%%" % roundi(_shown * 100.0)
	_bar_fill.size.x = _bar_back.size.x * clampf(_shown, 0.0, 1.0)


func _build() -> void:
	_root = Control.new()
	_root.name = "LoadingScreen"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var back := ColorRect.new()
	back.color = BACK
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(back)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(centre)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(760, 0)
	box.add_theme_constant_override("separation", 14)
	centre.add_child(box)

	var brand := _label("BSX LTD", 64, TEXT)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(brand)
	var rule := ColorRect.new()
	rule.color = ACCENT
	rule.custom_minimum_size = Vector2(0, 3)
	box.add_child(rule)
	_title = _label("", 26, ACCENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	box.add_child(gap)

	var row := HBoxContainer.new()
	box.add_child(row)
	_status = _label("", 22, TEXT)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status)
	_percent = _label("", 22, MUTED)
	row.add_child(_percent)

	_bar_back = ColorRect.new()
	_bar_back.color = Color(TEXT, 0.12)
	_bar_back.custom_minimum_size = Vector2(0, 14)
	box.add_child(_bar_back)
	_bar_fill = ColorRect.new()
	_bar_fill.color = ACCENT
	_bar_fill.position = Vector2.ZERO
	_bar_fill.size = Vector2(0, 14)
	_bar_back.add_child(_bar_fill)
	_bar_back.resized.connect(_refresh)

	var hint := _label("Your suit unlocks as soon as everything is in place.", 18, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


static func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
