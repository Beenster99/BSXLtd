class_name TradesBeamDesigner
extends Node3D
## Designing a modification as a hologram of beams round the ship in the courtyard (beenster,
## 0.3.27: "players are able to draw a hologram of beams around an existing ship in the
## courtyard and move, rotate, delete and test different ideas for the modification"). Behind
## trades.beam_designer; the plan is the doc "Beam Designer and Assembly Packages" (stage D1).
##
## With the design tablet in hand:
##   left click     start a beam, click again to end it (ends snap to other beams' ends and
##                  the ship's frame corners, else to a 50 mm grid); on a beam, pick it up to
##                  move it, and click again to set it down
##   right click    cancel what you are drawing or moving; on a beam, delete it
##   wheel          the section of the beam you are drawing, moving or pointing at
##   Q / E          turn the beam 15 degrees about the upright (Shift: roll it about its length)
##   G              copy the beam you point at and pick the copy up
##   X              undo (Shift+X redo)
##   R              (trades.beam_versions) show the next version, A, B or C (Shift+R: copy this
##                  version into the next and show it)
##   H              (trades.beam_versions) TEST the version showing: every end held, no
##                  clashes, the mass it adds and how far it moves the ship's centre of mass
## The design is kept per ship in TradesBus (in the save) and shared with the crew by one
## event that carries the whole design; a beam clashing with the ship or another beam is red,
## an end that nothing holds is amber.
##
## A modification is built onto the ship's own frame (beenster, 29 Oct: "the beams and design
## that we add MUST be attached to the existing beam structure"): strip the outer plates to
## show the frame, then draw beams from it. An end holds only on a frame member of the ship or
## on another beam of the design; the ground, the cradle and the plating don't count. An end
## on the frame where a plate is still fitted is pink (strip that plate first), and beams
## that never reach the frame through the design are "not on the ship". Ends snap to the
## frame's nodes and onto a member under the aim.
##
## Grown out of the ship (trades.beam_grow, beenster, 29 Oct): a click on the ship (or on the
## end of a beam of the design) starts a beam growing straight out of that face; the wheel sets
## its length (Shift: its section), Q/E swing it left and right, Shift+Q/E tilt it up and down,
## and a second click places it. Nothing but the ship and the design's beam ends can be clicked:
## not the ground, the walls or anything else in the yard. The same keys change a placed beam
## (about the end it grew from; Ctrl+Q/E rolls it). Everyone sees everyone's beam as it grows,
## and each change goes out a beam at a time so the crew can work on one design together.

const EVENT := "trades.beams"
## trades.beam_grow: each player's beam as it grows, for the others to see.
const DRAFT_EVENT := "trades.beam_draft"
const DRAFT_S := 0.1
## A grown beam's first length, the wheel's step, and how near a beam's end the aim must be to
## grow from it (m).
const GROW_M := 1.0
const LENGTH_STEP_M := 0.1
const END_PICK_M := 0.3
const SECTION := "trades_beams"
const INFO := "trades.beams"
## How far the tablet reaches (m from the eye), and where the aim lands when it meets nothing.
const REACH_M := 14.0
const AIR_M := 4.0
## Snapping: to another beam's end, to a corner of the ship's frame, else to the grid (m).
const SNAP_END_M := 0.25
const SNAP_NODE_M := 0.3
const GRID_M := 0.05
## Turning steps (degrees), the shortest beam and the most in a design.
const TURN_DEG := 15.0
const MIN_M := 0.1
const MAX_M := 30.0
const MAX_BEAMS := 300
## How near a beam's end must be to something for it to count as held (m), and how close two
## beams' ends must be to count as meeting.
const HOLD_M := 0.08
## How much of each end the clash check leaves out (m): where the beam meets what holds it.
const END_CLEAR_M := 0.2
## How near a fitted plate an end on the frame may be before the plate is in the way (m).
const PLATE_M := 0.25
## trades.gentle_plates: only the plates touching the end (m).
const PLATE_GENTLE_M := 0.15
const MEET_M := 0.06
## How often the clash and support checks run while nothing changes (s).
const CHECK_S := 1.0

const BLUE := Color(0.35, 0.75, 1.0, 0.55)
const BLUE_FAINT := Color(0.35, 0.75, 1.0, 0.25)
const LIT := Color(0.7, 0.95, 1.0, 0.6)
const RED := Color(1.0, 0.25, 0.2, 0.55)
const AMBER := Color(1.0, 0.7, 0.15, 0.9)
const PINK := Color(1.0, 0.35, 0.8, 0.9)
const GHOST := Color(0.6, 0.9, 1.0, 0.35)

var bay: Node  # TradesBay
## The section the next beam is drawn in.
var section := TradesBeamSections.DEFAULT
## The beam under the aim (its id, -1 for none), picked up (-1 for none), and the start of the
## beam being drawn (INF while not drawing): ship space.
var hovered := -1
var grabbed := -1
var start := Vector3.INF
## The snapped point under the aim now (ship space) and what it snapped to: "end", "node" (a
## frame node), "frame" (a member under the aim), "plate" (plating over it), "grid" or "".
var aim_point := Vector3.INF
var snapped_to := ""
## The checks' findings: beam ids that clash, and [beam id, end 0|1] pairs nothing holds.
var clashes: Dictionary = {}
var loose_ends: Array = []
## [beam id, end 0|1] pairs on the frame where a plate is still fitted over it, and the ids of
## beams that don't reach the ship's frame through the design.
var plated_ends: Array = []
var unattached: Array = []
## The last TEST (trades.beam_versions): {version, key (the design it tested), beams, clashes,
## loose, kg, length, shift (Vector3, ship space, m), ship_kg, passed}; {} before one.
var test_result: Dictionary = {}

var _net: Node
var _holo: Node3D
var _ghost: MeshInstance3D
var _marker: MeshInstance3D
var _length_label: Label3D
var _mats: Dictionary = {}
var _undo: Array = []
var _redo: Array = []
## The picked-up beam where it is being moved to, drawn here and shared when it is set down.
var _moving: Dictionary = {}
var _pick_when_here := -1
var _grab_offset := Vector3.ZERO
var _grab_depth := AIR_M
## The beam as it was when picked up (its row), for undo once it is set down; {} for a copy.
var _grab_before: Dictionary = {}
## trades.beam_grow: the beam growing out of the ship, {} while none: {root, normal (ship
## space: where it starts and the face it grows out of), yaw, pitch (degrees off the face's
## normal), length (m)}. What the aim can grow one from now: `root_on` "frame", "plate" (the
## ship's plating, which TEST asks to strip), "ship" (another part of her), "end" (a beam's
## end) or "" (nothing the tablet can click), at `root_point` facing `root_normal`.
var draft: Dictionary = {}
## trades.frame_order: the order O offers before a second O places it ({} while none):
## {key (design_key when made), plan (TradesFrameOrder.cut_plan), need {bar: n}, basket
## (TradesFrameOrder.basket)}.
var order_offer: Dictionary = {}
## trades.beam_copy: the beam G copied, to grow from the next root clicked ({dir (ship space),
## length (m), section}), {} while none.
var copying: Dictionary = {}
var root_on := ""
var root_point := Vector3.INF
var root_normal := Vector3.ZERO
## The other players' beams as they grow: peer -> {a, b, section}.
var drafts: Dictionary = {}
var _draft_sent := ""
var _draft_s := 0.0
## Where the aim meets something the tablet can't grow a beam from (ship space), INF when not.
var _bad_point := Vector3.INF
## Tests: the modifier keys held (KEY_SHIFT, KEY_CTRL), in place of the keyboard's; null: the keyboard.
var fake_keys: Variant = null
var _check_s := 0.0
var _dirty := true
var _drawn_key := ""
var _shown := ""


static func enabled() -> bool:
	return Flags.is_on("trades.beam_designer")


static func versions_on() -> bool:
	return Flags.is_on("trades.beam_versions")


static func grow_on() -> bool:
	return Flags.is_on("trades.beam_grow")


## trades.beam_edit (beenster, 0.3.30: "We need to be able to edit existing beams"): a click on
## a placed beam takes it back up as a growing beam from its root, with the same keys (wheel
## length, Q/E swing, Shift+Q/E tilt); a click puts it back changed, right click as it was.
static func edit_on() -> bool:
	return Flags.is_on("trades.beam_edit")


## trades.beam_copy (beenster, 0.3.30: "a \"copy this\" option when we select a holo beam"): G on
## a beam takes a copy of it (its length, the way it points, its section); the next click on the
## frame or a beam's end grows the copy from there, to adjust and click down as any other.
static func copy_on() -> bool:
	return Flags.is_on("trades.beam_copy")


## trades.frame_order (beenster, 0.3.31: "Once I am happy with my new frame, what do i do to
## commit it and get the parts ordered as a package"): O shows what the frame's beams are cut
## from and what that costs; O again commits the frame and buys the bars in one order. A frame
## committed again orders only bars it didn't have before.
static func order_on() -> bool:
	return Flags.is_on("trades.frame_order")


## trades.beam_grid (beenster, 0.3.30: "a sort of thin holo grid to help with 3D alignment"):
## while a beam grows, a thin level grid at its far end's height, a line down to the grid and
## lines along the ship's three axes through the end.
static func grid_on() -> bool:
	return Flags.is_on("trades.beam_grid")

## The grid's cells and how far it reaches either way from the beam's end (m).
const GRID_CELL_M := 0.5
const GRID_HALF_M := 3.0
const GRID_COLOUR := Color(0.35, 0.8, 1.0, 0.16)
const AXIS_COLOUR := Color(0.45, 0.9, 1.0, 0.45)
var _grid: MeshInstance3D
var _grid_key := ""


## trades.beam_clear (beenster, 0.3.29: "it should be possible to remove all holo designs to
## remove clutter"): Backspace on the tablet takes every beam of the version on show away at
## once, as one step undo brings back.
static func clear_on() -> bool:
	return Flags.is_on("trades.beam_clear")


## Takes every beam of the design on show away (one undo step). How many went.
func clear_all() -> int:
	var n := beams().size()
	if n == 0:
		return 0
	grabbed = -1
	hovered = -1
	start = Vector3.INF
	draft = {}
	commit([])
	return n


func build(net: Node = null) -> void:
	_holo = Node3D.new()
	_holo.name = "Hologram"
	_holo.top_level = true
	add_child(_holo)
	for key: String in ["blue", "faint", "lit", "red", "amber", "pink", "ghost"]:
		_mats[key] = _material({"blue": BLUE, "faint": BLUE_FAINT, "lit": LIT, "red": RED, "amber": AMBER, "pink": PINK, "ghost": GHOST}[key])
	_ghost = MeshInstance3D.new()
	_ghost.name = "Ghost"
	_ghost.material_override = _mats.ghost
	_ghost.visible = false
	_holo.add_child(_ghost)
	_grid = MeshInstance3D.new()
	_grid.name = "Grid"
	_grid.mesh = ImmediateMesh.new()
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.vertex_color_use_as_albedo = true
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.no_depth_test = true
	_grid.material_override = gm
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grid.visible = false
	_holo.add_child(_grid)
	_marker = MeshInstance3D.new()
	_marker.name = "Snap"
	var dot := SphereMesh.new()
	dot.radius = 0.04
	dot.height = 0.08
	_marker.mesh = dot
	_marker.material_override = _mats.lit
	_marker.visible = false
	_holo.add_child(_marker)
	_length_label = Label3D.new()
	_length_label.name = "Length"
	_length_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_length_label.no_depth_test = true
	_length_label.font = TradesLook.mono_font()
	_length_label.font_size = 40
	_length_label.pixel_size = 0.004
	_length_label.modulate = LIT
	_length_label.visible = false
	_holo.add_child(_length_label)
	var bus := Modules.bus("trades") as TradesBus
	if bus:
		bus.beam_design_changed.connect(func(_id: String) -> void: _dirty = true)
	_net = net
	if _net:
		_net.call("register_event", EVENT, _apply, _validate)
		_net.call("register_event", DRAFT_EVENT, _apply_draft, _validate_draft)
		if _net.has_method("register_snapshot_provider"):
			_net.call("register_snapshot_provider", SECTION, self)


func _exit_tree() -> void:
	HudSlots.clear_info(INFO)
	if _net:
		_net.call("unregister_event", EVENT)
		_net.call("unregister_event", DRAFT_EVENT)
		if _net.has_method("unregister_snapshot_provider"):
			_net.call("unregister_snapshot_provider", SECTION)


## The hologram's look (beenster, 29 Oct: "the hologram beam should look like a hologram of a
## beam"): see-through light, its edges and the faces seen side on brightest, scan lines running
## up it and a faint flicker. Drawn over itself (no depth write), so the inside shows through.
const HOLO_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.35, 0.75, 1.0, 0.55);
uniform float lines_per_m = 28.0;
uniform float speed = 1.5;
varying vec3 world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float scan = smoothstep(0.55, 1.0, 0.5 + 0.5 * sin((world.y + world.x * 0.3) * lines_per_m * 6.2832 - TIME * speed * 6.2832));
	float flick = 0.9 + 0.1 * sin(TIME * 31.0) * sin(TIME * 7.0);
	ALBEDO = tint.rgb * (0.5 + 1.3 * rim + 0.6 * scan) * flick;
	ALPHA = clamp(tint.a * (0.35 + 0.65 * rim + 0.4 * scan), 0.0, 1.0);
}
"""
static var _holo_shader: Shader


func _material(c: Color) -> Material:
	if grow_on():
		if _holo_shader == null:
			_holo_shader = Shader.new()
			_holo_shader.code = HOLO_SHADER
		var h := ShaderMaterial.new()
		h.shader = _holo_shader
		h.set_shader_parameter("tint", c)
		return h
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# --- The design ----------------------------------------------------------------------------

## The ship the design is drawn round (its id; "" with none in the bay).
func ship_id() -> String:
	var b := Modules.bus("ship_bay") as ShipBayBus
	return b.ship.ship_id if b and b.ship else ""


## The beams of the design now: rows {id, a, b (Vector3, ship space), section, turn}.
func beams() -> Array:
	var bus := Modules.bus("trades") as TradesBus
	var out: Array = []
	if bus == null:
		return out
	for r: Dictionary in bus.beam_design(ship_id()):
		var b := {"id": int(r.id), "a": _v(r.a), "b": _v(r.b), "section": TradesBeamSections.normal(str(r.section)), "turn": float(r.turn)}
		if not _moving.is_empty() and int(_moving.id) == b.id:
			b = _moving.duplicate()
		out.append(b)
	return out


## The version of the design showing ("A", "B" or "C").
func version() -> String:
	var bus := Modules.bus("trades") as TradesBus
	return bus.beam_version(ship_id()) if bus else "A"


## How many beams each version has: {letter: count}.
func version_counts() -> Dictionary:
	var bus := Modules.bus("trades") as TradesBus
	var out := {}
	for v: String in TradesBus.BEAM_VERSIONS:
		out[v] = bus.beam_design(ship_id(), v).size() if bus else 0
	return out


func beam(id: int) -> Dictionary:
	for b: Dictionary in beams():
		if int(b.id) == id:
			return b
	return {}


static func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


static func _row(b: Dictionary) -> Dictionary:
	var a: Vector3 = b.a
	var e: Vector3 = b.b
	return {"id": int(b.id), "a": [snappedf(a.x, 0.001), snappedf(a.y, 0.001), snappedf(a.z, 0.001)],
			"b": [snappedf(e.x, 0.001), snappedf(e.y, 0.001), snappedf(e.z, 0.001)],
			"section": str(b.section), "turn": snappedf(float(b.turn), 0.01)}


## Total length (m) and mass (kg, steel) of the design.
func totals() -> Vector2:
	var out := Vector2.ZERO
	for b: Dictionary in beams():
		var l := ((b.b as Vector3) - (b.a as Vector3)).length()
		out += Vector2(l, TradesBeamSections.mass(str(b.section), l))
	return out


## Puts the design in place of what is there (an edit: undoable). `list`: beam dictionaries.
## Sent as one change per beam that differs, so two players editing different beams at once
## both keep their work (beenster, 29 Oct: "all players can do the same at the same time").
func commit(list: Array, undoable := true) -> void:
	var now := {}
	for b: Dictionary in beams():
		now[int(b.id)] = _row(b)
	var want := {}
	for b: Dictionary in list:
		want[int(b.id)] = _row(b)
	var step: Array = []
	for id: int in now:
		if not want.has(id):
			step.append([id, now[id], null])
	for id: int in want:
		if not now.has(id) or str(now[id]) != str(want[id]):
			step.append([id, now.get(id), want[id]])
	if step.is_empty():
		return
	if undoable:
		_undo.append(step)
		_redo.clear()
	for c: Array in step:
		_send(c[0], c[2], c[1] == null)


## Sends one beam's change: its new row, or null to take it away.
## `fresh`: a new beam, whose id the host changes if another player took it meanwhile.
func _send(id: int, row: Variant, fresh := false) -> void:
	if row == null:
		_ask({"ship": ship_id(), "version": version(), "del": id})
	else:
		_ask({"ship": ship_id(), "version": version(), "put": row, "new": fresh})


func _next_id(list: Array) -> int:
	var n := 0
	for b: Dictionary in list:
		n = maxi(n, int(b.id))
	return n + 1


## Adds a beam from `a` to `b` (ship space). Returns its id, or -1 when it is too short or long.
func add_beam(a: Vector3, b: Vector3, sec := "") -> int:
	var l := a.distance_to(b)
	if l < MIN_M or l > MAX_M:
		return -1
	var list := beams()
	if list.size() >= MAX_BEAMS:
		return -1
	var id := _next_id(list)
	list.append({"id": id, "a": a, "b": b, "section": sec if sec != "" else section, "turn": 0.0})
	commit(list)
	return id


func delete_beam(id: int) -> void:
	commit(beams().filter(func(b: Dictionary) -> bool: return int(b.id) != id))


## Changes one beam (`change` merged over it).
func edit_beam(id: int, change: Dictionary, undoable := true) -> void:
	if id == grabbed and not _moving.is_empty():
		_moving.merge(change, true)
		_dirty = true
		return
	var list := beams()
	for b: Dictionary in list:
		if int(b.id) == id:
			b.merge(change, true)
	commit(list, undoable)


## Turns a beam `deg` about the upright through its middle, or rolls it about its length.
func turn_beam(id: int, deg: float, roll := false) -> void:
	var b := beam(id)
	if b.is_empty():
		return
	if roll:
		edit_beam(id, {"turn": fposmod(float(b.turn) + deg, 360.0)})
		return
	var mid := ((b.a as Vector3) + (b.b as Vector3)) * 0.5
	var r := Basis(Vector3.UP, deg_to_rad(deg))
	edit_beam(id, {"a": mid + r * ((b.a as Vector3) - mid), "b": mid + r * ((b.b as Vector3) - mid)})


## Undo and redo go a change at a time: [[id, row before or null, row after or null], ...]
## for each beam it touched, so undoing yours leaves what others did since alone.
func undo() -> bool:
	if _undo.is_empty():
		return false
	var step: Array = _undo.pop_back()
	_redo.append(step)
	for c: Array in step:
		_send(c[0], c[1])
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	var step: Array = _redo.pop_back()
	_undo.append(step)
	for c: Array in step:
		_send(c[0], c[2])
	return true


# --- Versions and the test (trades.beam_versions) ------------------------------------------

func _next_version() -> String:
	var all := TradesBus.BEAM_VERSIONS
	return all[(all.find(version()) + 1) % all.size()]


## Shows another version: what was being drawn or moved is let go, and undo starts afresh.
func show_version(v: String) -> void:
	if not TradesBus.BEAM_VERSIONS.has(v) or v == version():
		return
	_let_go()
	_ask({"ship": ship_id(), "show": v})


## Copies the version showing into `v` (in place of what it had) and shows it.
func copy_to(v: String) -> void:
	if not TradesBus.BEAM_VERSIONS.has(v) or v == version():
		return
	var rows: Array = []
	for b: Dictionary in beams():
		rows.append(_row(b))
	_let_go()
	_ask({"ship": ship_id(), "version": v, "rows": rows, "show": v})


func _let_go() -> void:
	grabbed = -1
	_moving = {}
	start = Vector3.INF
	_undo.clear()
	_redo.clear()
	_dirty = true


## A key for the design as it stands, so a test can tell it is out of date.
func design_key() -> String:
	return "%s|%s" % [version(), str(beams())]


## TEST: runs the checks on the version showing and keeps what they found in test_result.
func test() -> Dictionary:
	run_checks()
	_check_s = 0.0
	var list := beams()
	var t := totals()
	var mid := Vector3.ZERO
	for b: Dictionary in list:
		var l := ((b.b as Vector3) - (b.a as Vector3)).length()
		mid += ((b.a as Vector3) + (b.b as Vector3)) * 0.5 * TradesBeamSections.mass(str(b.section), l)
	var ship := ship_mass(_ship_def())
	var ship_kg := float(ship.get("kg", 0.0))
	var shift := Vector3.ZERO
	if t.y > 0.0 and ship_kg > 0.0:
		shift = (mid / t.y - (ship.centre as Vector3)) * t.y / (ship_kg + t.y)
	test_result = {"version": version(), "key": design_key(), "beams": list.size(), "clashes": clashes.size(),
			"loose": loose_ends.size(), "plated": plated_ends.size(), "unattached": unattached.size(),
			"kg": t.y, "length": t.x, "shift": shift, "ship_kg": ship_kg,
			"passed": not list.is_empty() and clashes.is_empty() and loose_ends.is_empty() and plated_ends.is_empty() and unattached.is_empty()}
	_play(&"click" if test_result.passed else &"clunk")
	_say(test_line())
	return test_result


## The test's verdict in a line, "" before one.
func test_line() -> String:
	if test_result.is_empty():
		return ""
	if int(test_result.beams) == 0:
		return "Nothing to test: version %s has no beams." % test_result.version
	var bits := PackedStringArray()
	if int(test_result.clashes) > 0:
		bits.append("%d clash%s" % [test_result.clashes, "" if int(test_result.clashes) == 1 else "es"])
	if int(test_result.unattached) > 0:
		bits.append("%d beam%s not on the ship's frame" % [test_result.unattached, "" if int(test_result.unattached) == 1 else "s"])
	if int(test_result.loose) > 0:
		bits.append("%d loose end%s" % [test_result.loose, "" if int(test_result.loose) == 1 else "s"])
	if int(test_result.plated) > 0:
		bits.append("%d end%s under plating (strip it first)" % [test_result.plated, "" if int(test_result.plated) == 1 else "s"])
	var head := "Version %s passes" % test_result.version if bits.is_empty() else "Version %s fails: %s" % [test_result.version, ", ".join(bits)]
	return "%s. Adds %d kg%s." % [head, roundi(float(test_result.kg)), _shift_words(test_result.shift, float(test_result.ship_kg))]


## How far the design moves the ship's centre of mass, in words (ship space: -Z forward, +X
## to the right, +Y up).
static func _shift_words(shift: Vector3, ship_kg: float) -> String:
	if ship_kg <= 0.0:
		return ""
	var parts := PackedStringArray()
	for axis in [[shift.z, "aft", "forward"], [shift.y, "up", "down"], [shift.x, "right", "left"]]:
		var mm := roundi(absf(float(axis[0])) * 1000.0)
		if mm >= 1:
			parts.append("%d mm %s" % [mm, axis[1] if float(axis[0]) > 0.0 else axis[2]])
	if parts.is_empty():
		return ", centre of mass unmoved"
	return ", moves the centre of mass " + ", ".join(parts)


func _ship_def() -> ShipDefinition:
	var b := Modules.bus("ship_bay") as ShipBayBus
	return b.ship if b else null


static var _mass_cache: Dictionary = {}
static var _files: Dictionary = {}


## A ship's Void Salvage file: a wreck's own, else her design's (read once).
static func _ship_file(def: ShipDefinition) -> Dictionary:
	if not def.file.is_empty():
		return def.file
	if not _files.has(def.ship_id):
		_files[def.ship_id] = VsShipImport.design_source(def.ship_id.trim_prefix("vs_"))
	return _files[def.ship_id]


## A ship's mass (kg) and centre of mass (ship space) from its Void Salvage file's parts:
## {kg, centre}; {} when its file can't be read.
static func ship_mass(def: ShipDefinition) -> Dictionary:
	if def == null:
		return {}
	var key := def.ship_id + ("#%d" % def.file.hash() if not def.file.is_empty() else "")
	if _mass_cache.has(key):
		return _mass_cache[key]
	var f := _ship_file(def)
	var kg := 0.0
	var sum := Vector3.ZERO
	for p: Variant in f.get("parts", []):
		if not p is Dictionary:
			continue
		var m := float((p as Dictionary).get("mass", 0.0))
		var box: Dictionary = (p as Dictionary).get("box", {})
		var at := Vector3.ZERO
		if box.has("pos") and box.has("size"):
			at = VsShipImport.vec3(box.pos) + VsShipImport.vec3(box.size) * 0.5
		else:
			at = VsShipImport.vec3(((p as Dictionary).get("xform", {}) as Dictionary).get("o", [0, 0, 0]))
		kg += m
		sum += at * m
	var out := {} if kg <= 0.0 else {"kg": kg, "centre": sum / kg}
	_mass_cache[key] = out
	return out


# --- Input (the bay hands it the tablet's clicks, keys and wheel) ---------------------------

func holding() -> bool:
	return bay != null and bay.get("tool") == &"tablet"


## Left (pressed) or right click with the tablet. Returns true when it used it.
func click(left: bool) -> bool:
	if grow_on() and grabbed < 0:
		return _click_grow(left)
	if left:
		if grabbed >= 0:
			set_down()
			_play(&"clunk")
		elif start.is_finite():
			if aim_point.is_finite() and add_beam(start, aim_point) >= 0:
				_play(&"click")
				start = Vector3.INF
			else:
				_say("A beam runs %d mm to %d m." % [roundi(MIN_M * 1000.0), roundi(MAX_M)])
		elif hovered >= 0:
			pick_up(hovered)
		elif aim_point.is_finite():
			start = aim_point
			_play(&"tick")
		return true
	if grabbed >= 0:
		# Put back where it was: the move never left this machine.
		grabbed = -1
		_moving = {}
		_dirty = true
	elif start.is_finite():
		start = Vector3.INF
	elif hovered >= 0:
		delete_beam(hovered)
		hovered = -1
		_play(&"clunk")
	return true


## Picks a beam up to move it (it follows the aim till the next left click).
func pick_up(id: int, push := true) -> void:
	var b := beam(id)
	if b.is_empty():
		return
	grabbed = id
	_grab_before = _row(b) if push else {}
	_moving = b.duplicate()
	var eye := _eye_ship()
	var mid := ((b.a as Vector3) + (b.b as Vector3)) * 0.5
	_grab_depth = clampf(eye[0].distance_to(mid), 1.0, REACH_M)
	_grab_offset = mid - (eye[0] + eye[1] * _grab_depth)
	_play(&"tick")


## One wheel notch: true when it changed a section (else the bay changes tools).
func wheel(step: int) -> bool:
	var id := grabbed if grabbed >= 0 else hovered
	if grow_on():
		var shift := _held(KEY_SHIFT)
		if not draft.is_empty():
			if shift:
				section = TradesBeamSections.step(section, step)
			else:
				draft.length = clampf(float(draft.length) - step * LENGTH_STEP_M, MIN_M, MAX_M)
			_play(&"tick")
			return true
		if id >= 0 and not shift:
			stretch_beam(id, -step * LENGTH_STEP_M)
			_play(&"tick")
			return true
	if start.is_finite() or id < 0:
		if not start.is_finite():
			return false
		section = TradesBeamSections.step(section, step)
	else:
		var b := beam(id)
		var sec := TradesBeamSections.step(str(b.section), step)
		section = sec
		edit_beam(id, {"section": sec}, grabbed < 0)
	_play(&"tick")
	return true


## A key with the tablet in hand (TradesBus.KEY_*). True when it used it.
func key(action: String) -> bool:
	var shift := _held(KEY_SHIFT)
	var id := grabbed if grabbed >= 0 else hovered
	match action:
		TradesBus.KEY_TURN_LEFT, TradesBus.KEY_TURN_RIGHT:
			var deg := TURN_DEG * (1.0 if action == TradesBus.KEY_TURN_RIGHT else -1.0)
			if grow_on() and (not draft.is_empty() or (hovered >= 0 and grabbed < 0)):
				_turn_grow(deg, shift, _held(KEY_CTRL))
				_play(&"tick")
				return true
			if id < 0:
				return false
			if grabbed >= 0:
				var b := beam(id)
				if shift:
					edit_beam(id, {"turn": fposmod(float(b.turn) + deg, 360.0)}, false)
				else:
					var mid := ((b.a as Vector3) + (b.b as Vector3)) * 0.5
					var r := Basis(Vector3.UP, deg_to_rad(deg))
					edit_beam(id, {"a": mid + r * ((b.a as Vector3) - mid), "b": mid + r * ((b.b as Vector3) - mid)}, false)
			else:
				turn_beam(id, deg, shift)
			_play(&"tick")
			return true
		TradesBus.KEY_NEXT:
			if grow_on() and copy_on() and grabbed < 0 and draft.is_empty():
				if hovered < 0:
					return false
				copy_beam(hovered)
				_play(&"tick")
				_say("Copied. Click where the copy should grow from.")
				return true
			if hovered < 0 or grabbed >= 0:
				return false
			var b := beam(hovered)
			var list := beams()
			var copy := b.duplicate()
			copy.id = _next_id(list)
			list.append(copy)
			commit(list)
			# The copy only arrives with the event: offline at once, online a moment later.
			_pick_when_here = int(copy.id)
			_say("Copied. Move the copy and click to set it down.")
			return true
		TradesBus.KEY_ROTATE:
			if not versions_on():
				return false
			if shift:
				var to := _next_version()
				copy_to(to)
				_say("Copied into version %s." % to)
			else:
				show_version(_next_version())
			_play(&"tick")
			return true
		TradesBus.KEY_HELMET:
			if not versions_on():
				return false
			test()
			return true
		TradesBus.KEY_ORDER:
			if not order_on() or grabbed >= 0 or start.is_finite() or not draft.is_empty():
				return false
			if order_offer.is_empty() or str(order_offer.key) != design_key():
				offer_order()
			else:
				place_frame_order()
			return true
		TradesBus.KEY_RESET:
			if not clear_on():
				return false
			var n := clear_all()
			if n > 0:
				_play(&"clunk")
				_say("Cleared %d beam%s. X brings them back." % [n, "" if n == 1 else "s"])
			else:
				_say("No beams to clear.")
			return true
		TradesBus.KEY_MODE:
			if grabbed >= 0 or start.is_finite() or not draft.is_empty():
				return false
			if redo() if shift else undo():
				_play(&"tick")
			else:
				_say("Nothing to redo." if shift else "Nothing to undo.")
			return true
	return false


func _held(k: Key) -> bool:
	return (fake_keys as Array).has(k) if fake_keys is Array else Input.is_key_pressed(k)


# --- Committing the frame and ordering its parts (trades.frame_order) -----------------------

## Works out what the frame needs and offers the order (the panel shows it). Returns the offer.
func offer_order() -> Dictionary:
	order_offer = {}
	var rows := beams()
	if rows.is_empty():
		_say("Nothing to commit: draw the frame's beams first.")
		return {}
	var plan := TradesFrameOrder.cut_plan(rows)
	var done := committed()
	var need := TradesFrameOrder.still_to_buy(plan.counts, done.get("ordered", {}))
	var b := TradesFrameOrder.basket(Modules.bus("business"), need) if not need.is_empty() else {}
	order_offer = {"key": design_key(), "plan": plan, "need": need, "basket": b}
	_play(&"tick")
	_say(order_line())
	return order_offer


## Commits the frame and places the offered order. "" when done, else why not.
func place_frame_order() -> String:
	if order_offer.is_empty() or str(order_offer.key) != design_key():
		offer_order()
		return "changed"
	var need: Dictionary = order_offer.need
	var b: Dictionary = order_offer.basket
	var done := committed()
	var ordered: Dictionary = (done.get("ordered", {}) as Dictionary).duplicate()
	var cost := int(done.get("cost", 0))
	if not need.is_empty():
		if not bool(b.get("ok", false)):
			_play(&"clunk")
			_say("Can't order it: %s." % b.get("reason", "the shop said no"))
			return str(b.get("reason", "refused"))
		# Booked against the job in hand, when there is one (Business: its contract_id).
		var contracts := Modules.bus("contracts") as ContractsBus
		var job := contracts.get_active_job() if contracts else null
		var shop: Object = Modules.bus("business")
		if shop == null:
			return "no shop"
		var r: Object = shop.call("place_market_order", b.basket, job.job_id if job else "")
		if not bool(r.call("is_ok")):
			_play(&"clunk")
			_say("Can't order it: %s." % r.get("message"))
			return str(r.get("message"))
		for bar: String in need:
			ordered[bar] = int(ordered.get(bar, 0)) + int(need[bar])
		cost += int(b.cost)
	var rows: Array = []
	for row: Dictionary in beams():
		rows.append(_row(row))
	var cuts: Array = []
	for bar: Dictionary in (order_offer.plan as Dictionary).bars:
		cuts.append({"bar": bar.bar, "mm": (bar.lengths as Array).map(func(e: Dictionary) -> int: return int(e.mm))})
	# Bars already cut for an earlier commit stay cut when the plan hasn't changed.
	var cut_already := done_cuts(done, cuts)
	_ask({"ship": ship_id(), "commit": {"version": version(), "rows": rows, "counts": (order_offer.plan as Dictionary).counts,
			"ordered": ordered, "cost": cost, "by": str(_me()), "cuts": cuts, "done": cut_already}})
	var bars := 0
	for bar: String in need:
		bars += int(need[bar])
	order_offer = {}
	_play(&"click")
	if bars > 0:
		_say("Frame committed. %d bar%s ordered for %d CR: they come in with the deliveries." % [bars, "" if bars == 1 else "s", int(b.cost)])
	else:
		_say("Frame committed. Its bars are on order already.")
	return ""


## Which of a new commit's bars count as cut already: one cut for the commit before with the
## same bar and lengths.
static func done_cuts(before: Dictionary, cuts: Array) -> Array:
	var was: Array = before.get("cuts", [])
	var free: Array = (before.get("done", []) as Array).duplicate()
	var out: Array = []
	for i in cuts.size():
		for j: int in free:
			if j < was.size() and str(was[j].bar) == str(cuts[i].bar) and str(was[j].mm) == str(cuts[i].mm):
				out.append(i)
				free.erase(j)
				break
	return out


## The frame committed on this ship ({} before one).
func committed() -> Dictionary:
	var bus := Modules.bus("trades") as TradesBus
	return bus.committed_frame(ship_id()) if bus else {}


## True when the design showing is the one committed.
func is_committed() -> bool:
	var c := committed()
	if c.is_empty() or str(c.version) != version():
		return false
	var mine: Array = []
	for row: Dictionary in beams():
		mine.append(_row(row))
	var theirs: Array = []
	for row: Dictionary in c.rows:
		theirs.append(_row({"id": row.id, "a": _v(row.a), "b": _v(row.b), "section": row.section, "turn": row.turn}))
	return str(mine) == str(theirs)


## The offer in a line, for the panel and the hint.
func order_line() -> String:
	if order_offer.is_empty():
		return ""
	var plan: Dictionary = order_offer.plan
	var need: Dictionary = order_offer.need
	var head := "%d beam%s cut from %s" % [int(plan.pieces), "" if int(plan.pieces) == 1 else "s", _bars_text(plan.counts)]
	if int(plan.spliced) > 0:
		head += " (%d spliced from two bars)" % plan.spliced
	if need.is_empty():
		return head + ". All on order already: O again to commit, right click cancel"
	var b: Dictionary = order_offer.basket
	if not bool(b.get("ok", false)):
		return "%s. Can't order: %s" % [head, b.get("reason", "")]
	var from := ""
	var bb: Object = Modules.bus("business")
	var who: Object = bb.call("supplier", str(b.supplier)) if bb and str(b.supplier) != "" else null
	if who:
		from = " from %s" % who.get("display_name")
	var buying := "" if need.hash() == (plan.counts as Dictionary).hash() else " (buying %s)" % _bars_text(need)
	return "%s%s%s, %d CR. O again to commit and order, right click cancel" % [head, buying, from, int(b.cost)]


static func _bars_text(counts: Dictionary) -> String:
	var bits := PackedStringArray()
	for bar: String in counts:
		var it := StockBeams.item(bar)
		bits.append("%d x %d m bar" % [int(counts[bar]), roundi(float(it.get("length", 0.0)))] + ("" if int(counts[bar]) == 1 else "s"))
	return ", ".join(bits)


# --- Growing a beam out of the ship (trades.beam_grow) --------------------------------------

func _click_grow(left: bool) -> bool:
	if left:
		if not draft.is_empty():
			if place_growing() >= 0:
				_play(&"click")
			else:
				_say("A beam runs %d mm to %d m." % [roundi(MIN_M * 1000.0), roundi(MAX_M)])
		elif root_on != "":
			start_growing()
			_play(&"tick")
		elif not copying.is_empty():
			_say("Point at the frame or a beam's end to grow the copy from.")
		elif hovered >= 0:
			if edit_on():
				take_up(hovered)
				_play(&"tick")
			else:
				pick_up(hovered)
		else:
			_say("Point at the ship, or the end of a beam, to grow a beam from it.")
		return true
	if not draft.is_empty():
		draft = {}
	elif not order_offer.is_empty():
		order_offer = {}
		_say("Order cancelled.")
	elif not copying.is_empty():
		copying = {}
	elif hovered >= 0:
		delete_beam(hovered)
		hovered = -1
		_play(&"clunk")
	return true


## A face's up and across (unit vectors at right angles to its normal `n`), for swinging and
## tilting a beam grown out of it: across is level unless the face is.
static func face_axes(n: Vector3) -> Array:
	var up := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var side := up.cross(n).normalized()
	return [n.cross(side).normalized(), side]


## Which way a beam grown out of a face points: its normal swung `yaw` degrees about the face's
## up and tilted `pitch` degrees up off it.
static func grow_dir(n: Vector3, yaw: float, pitch: float) -> Vector3:
	var ax := face_axes(n)
	return n.rotated(ax[1], deg_to_rad(-pitch)).rotated(ax[0], deg_to_rad(yaw)).normalized()


## The growing beam's far end (ship space) and what it snapped to: another beam's end or a
## frame node within reach of it, else [where it reaches, ""].
func draft_end() -> Array:
	var e: Vector3 = (draft.root as Vector3) + grow_dir(draft.normal, float(draft.yaw), float(draft.pitch)) * float(draft.length)
	var sn := snap(e, editing(), false)
	if sn[1] != "" and (sn[0] as Vector3).distance_to(draft.root) >= MIN_M:
		return sn
	return [e, ""]


## Starts a beam growing out of where the aim is: false when it isn't on the ship or a beam's end.
func start_growing() -> bool:
	if root_on == "" or not root_point.is_finite():
		return false
	draft = {"root": root_point, "normal": root_normal, "yaw": 0.0, "pitch": 0.0, "length": GROW_M}
	if not copying.is_empty():
		draft.normal = copying.dir
		draft.length = copying.length
		section = str(copying.section)
		copying = {}
	return true


## Takes a copy of a placed beam to grow from the next root clicked (trades.beam_copy).
func copy_beam(id: int) -> bool:
	var b := beam(id)
	if b.is_empty():
		return false
	var d: Vector3 = (b.b as Vector3) - (b.a as Vector3)
	copying = {"dir": d.normalized(), "length": d.length(), "section": str(b.section)}
	return true


## Takes a placed beam back up as the growing beam (trades.beam_edit): from its root, the way
## it points, its length and section. False when there's no such beam.
func take_up(id: int) -> bool:
	var b := beam(id)
	if b.is_empty():
		return false
	var d: Vector3 = (b.b as Vector3) - (b.a as Vector3)
	draft = {"root": b.a, "normal": d.normalized(), "yaw": 0.0, "pitch": 0.0, "length": d.length(), "editing": id}
	section = str(b.section)
	hovered = -1
	return true


## The beam being edited as the growing beam (trades.beam_edit), or -1.
func editing() -> int:
	return int(draft.get("editing", -1))


## Places the growing beam for everyone. Its id, or -1 when it can't be.
func place_growing() -> int:
	if draft.is_empty():
		return -1
	if editing() >= 0:
		var was := editing()
		if beam(was).is_empty():
			draft = {}
			return -1
		var end: Vector3 = draft_end()[0]
		if end.distance_to(draft.root) < MIN_M:
			return -1
		edit_beam(was, {"b": end, "section": section})
		draft = {}
		return was
	var id := add_beam(draft.root, draft_end()[0])
	if id >= 0:
		draft = {}
	return id


## Q/E on the growing beam or the one under the aim: swing (`tilt` false) or tilt it, or roll it.
func _turn_grow(deg: float, tilt: bool, roll: bool) -> void:
	if not draft.is_empty():
		if tilt:
			draft.pitch = clampf(float(draft.pitch) + deg, -90.0, 90.0)
		else:
			draft.yaw = wrapf(float(draft.yaw) + deg, -180.0, 180.0)
		return
	if roll:
		turn_beam(hovered, deg, true)
	else:
		swing_beam(hovered, deg, tilt)


## Swings (`tilt` false) or tilts a placed beam `deg` degrees about the end it grew from.
func swing_beam(id: int, deg: float, tilt := false) -> void:
	var b := beam(id)
	if b.is_empty():
		return
	var a: Vector3 = b.a
	var d: Vector3 = (b.b as Vector3) - a
	var ax := face_axes(d.normalized())
	var r := d.rotated(ax[1], deg_to_rad(-deg)) if tilt else d.rotated(ax[0], deg_to_rad(deg))
	edit_beam(id, {"b": a + r}, grabbed < 0)


## Makes a placed beam `by` metres longer (shorter when negative) from the end it grew from.
func stretch_beam(id: int, by: float) -> void:
	var b := beam(id)
	if b.is_empty():
		return
	var d: Vector3 = (b.b as Vector3) - (b.a as Vector3)
	var l := clampf(d.length() + by, MIN_M, MAX_M)
	edit_beam(id, {"b": (b.a as Vector3) + d.normalized() * l}, grabbed < 0)


## What a hit on the ship can grow a beam from: "frame" (a member still on her), "plate" (a
## plate or pane still fitted), "ship" (another part of her), "" for anything that isn't her.
func ship_part(collider: Object, shape_idx: int, at: Vector3) -> String:
	var b := Modules.bus("ship_bay") as ShipBayBus
	if b == null or collider == null:
		return ""
	var info := b.inspect_at(collider, shape_idx, at)
	if info.is_empty() or str(info.get("slot_state", "")) == "empty":
		return ""
	match str(info.get("kind", "")):
		"frame":
			return "frame"
		"hull", "glass":
			return "plate"
	return "ship"


## The aim with trades.beam_grow: the growing beam's end, else what a click would grow from.
func _aim_grow(near_t: float, hit: Dictionary, from: Vector3, dir: Vector3) -> void:
	root_on = ""
	root_point = Vector3.INF
	root_normal = Vector3.ZERO
	_bad_point = Vector3.INF
	if not draft.is_empty():
		hovered = -1
		var e := draft_end()
		aim_point = e[0]
		snapped_to = e[1]
		return
	var xi := ship_xform().affine_inverse()
	var hit_t := INF if hit.is_empty() else from.distance_to(xi * (hit.position as Vector3))
	if hovered >= 0 and near_t <= hit_t:
		var b := beam(hovered)
		var c: Vector3 = Geometry3D.get_closest_points_between_segments(from, from + dir * REACH_M, b.a, b.b)[1]
		for k in 2:
			var end: Vector3 = b.a if k == 0 else b.b
			var other: Vector3 = b.b if k == 0 else b.a
			if c.distance_to(end) < END_PICK_M:
				root_on = "end"
				root_point = end
				root_normal = (end - other).normalized()
	elif not hit.is_empty():
		hovered = -1
		var kind := ship_part(hit.get("collider"), int(hit.get("shape", 0)), hit.position)
		if kind != "":
			root_on = kind
			root_point = xi * (hit.position as Vector3)
			root_normal = (xi.basis * (hit.normal as Vector3)).normalized()
		else:
			_bad_point = xi * (hit.position as Vector3)
	aim_point = root_point
	snapped_to = root_on


## The tablet's ray into the yard (world space), going on through parts taken off the ship:
## their shapes stay on her body, but there's nothing there to click.
func cast(world_from: Vector3, world_dir: Vector3, exclude: Array[RID] = []) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var at := world_from
	var end := world_from + world_dir * REACH_M
	for i in 8:
		var q := PhysicsRayQueryParameters3D.create(at, end)
		q.exclude = exclude
		var hit := space.intersect_ray(q)
		if hit.is_empty() or not grow_on() or not _gone(hit.get("collider"), int(hit.get("shape", 0))):
			return hit
		at = (hit.position as Vector3) + world_dir * 0.01
	return {}


## Sends this player's growing beam to the others (a few times a second while it changes).
func _share_draft(delta: float) -> void:
	_draft_s -= delta
	if _net == null or not bool(_net.call("is_online")):
		return
	var p := {}
	if holding() and not draft.is_empty():
		var e: Vector3 = draft_end()[0]
		p = {"ship": ship_id(), "a": _arr(draft.root), "b": _arr(e), "section": section}
	var want := str(p)
	if want == _draft_sent or (want != "{}" and _draft_s > 0.0):
		return
	_draft_s = DRAFT_S
	_draft_sent = want
	_net.call("request", DRAFT_EVENT, p)


static func _arr(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


func _validate_draft(sender: int, p: Dictionary) -> Variant:
	if not p.has("a"):
		return {"peer": sender}
	if _bad_row(p, false) != "":
		return "bad beam"
	return {"peer": sender, "ship": str(p.get("ship", "")), "a": p.a, "b": p.b, "section": str(p.section)}


func _apply_draft(p: Dictionary) -> void:
	var peer := int(p.get("peer", 0))
	if peer == _me():
		return
	if p.has("a"):
		drafts[peer] = {"ship": str(p.ship), "a": _v(p.a), "b": _v(p.b), "section": str(p.section)}
	else:
		drafts.erase(peer)


## The other players' growing beams round this ship, those still here.
func others_growing() -> Dictionary:
	var online := _net != null and bool(_net.call("is_online"))
	var here: Dictionary = _net.call("peers") if online and _net.has_method("peers") else {}
	var out := {}
	for peer: int in drafts.keys():
		if online and not here.has(peer):
			drafts.erase(peer)
		elif str(drafts[peer].ship) == ship_id():
			out[peer] = drafts[peer]
	return out


# --- Every step: the aim, the snapping, the checks ------------------------------------------

func ship_xform() -> Transform3D:
	return bay.call("ship_transform") if bay and bay.has_method("ship_transform") else Transform3D.IDENTITY


## The eye and the aim's direction in ship space.
func _eye_ship() -> Array:
	var w := bay.get("worker") as Node3D if bay else null
	if w == null or not w.is_inside_tree():
		return [Vector3.ZERO, Vector3.FORWARD]
	var inv := ship_xform().affine_inverse()
	var from: Vector3 = w.call("aim_origin")
	var dir: Vector3 = w.call("aim_dir")
	return [inv * from, (inv.basis * dir).normalized()]


func _physics_process(delta: float) -> void:
	if _holo == null:
		return
	_holo.global_transform = ship_xform()
	if holding():
		_aim()
	else:
		hovered = -1
		start = Vector3.INF
		draft = {}
		root_on = ""
		_bad_point = Vector3.INF
		if grabbed >= 0:
			set_down()
		aim_point = Vector3.INF
	_share_draft(delta)
	_check_s -= delta
	if _dirty or _check_s <= 0.0:
		_check_s = CHECK_S
		_dirty = false
		run_checks()
	_draw()


## Sets the beam being moved down where it is now, for everyone.
func set_down() -> void:
	if grabbed < 0:
		return
	var moved := _row(_moving) if not _moving.is_empty() else {}
	var id := grabbed
	grabbed = -1
	_moving = {}
	if moved.is_empty():
		return
	if not _grab_before.is_empty() and str(_grab_before) != str(moved):
		_undo.append([[id, _grab_before, moved]])
		_redo.clear()
	_send(id, moved)


func _aim() -> void:
	if _pick_when_here >= 0 and not beam(_pick_when_here).is_empty():
		pick_up(_pick_when_here, false)
		_pick_when_here = -1
	var w := bay.get("worker") as CollisionObject3D
	var eye := _eye_ship()
	var from: Vector3 = eye[0]
	var dir: Vector3 = eye[1]
	if grabbed >= 0:
		_follow_grab(from, dir)
		return
	# A beam under the aim, nearest first.
	hovered = -1
	var near_t := INF
	for b: Dictionary in beams():
		var c := Geometry3D.get_closest_points_between_segments(from, from + dir * REACH_M, b.a, b.b)
		if c[0].distance_to(c[1]) <= TradesBeamSections.radius(str(b.section)) + 0.05:
			var t := from.distance_to(c[0])
			if t < near_t:
				near_t = t
				hovered = int(b.id)
	# The surface under the aim.
	var world_from: Vector3 = w.call("aim_origin")
	var world_dir: Vector3 = w.call("aim_dir")
	var hit := cast(world_from, world_dir, [w.get_rid()])
	if grow_on():
		_aim_grow(near_t, hit, from, dir)
		return
	var p: Vector3
	var on := ""
	if not hit.is_empty():
		p = ship_xform().affine_inverse() * (hit.position as Vector3)
		if hovered >= 0 and near_t > from.distance_to(p):
			hovered = -1
		on = part_kind(hit.get("collider"), int(hit.get("shape", 0)), hit.position)
	elif start.is_finite():
		p = from + dir * clampf(from.distance_to(start), 1.0, REACH_M)
	else:
		p = from + dir * AIR_M
	if start.is_finite():
		hovered = -1
	var s := snap(p)
	if s[1] == "grid" and on == "frame":
		s = [p, "frame"]
	aim_point = s[0]
	snapped_to = s[1] if s[1] != "grid" or on != "plate" else "plate"


func _follow_grab(from: Vector3, dir: Vector3) -> void:
	var b := beam(grabbed)
	if b.is_empty():
		grabbed = -1
		return
	var a: Vector3 = b.a
	var e: Vector3 = b.b
	var mid := (a + e) * 0.5
	var want := from + dir * _grab_depth + _grab_offset
	var shift := want - mid
	# An end that comes near a snap point pulls the whole beam onto it, else the middle to the grid.
	var sa := snap(a + shift, grabbed, false)
	var se := snap(e + shift, grabbed, false)
	if sa[1] != "":
		shift = (sa[0] as Vector3) - a
		snapped_to = sa[1]
	elif se[1] != "":
		shift = (se[0] as Vector3) - e
		snapped_to = se[1]
	else:
		shift = (want - mid).snapped(Vector3.ONE * GRID_M)
		snapped_to = "grid"
	aim_point = Vector3.INF
	if shift.length() > 0.0005:
		edit_beam(grabbed, {"a": a + shift, "b": e + shift}, false)


## A ship-space point snapped: [point, what to]. To another beam's end (not `skip`'s), a corner
## of the ship's frame, else the grid (`grid` false: no grid, [p, ""] instead).
func snap(p: Vector3, skip := -1, grid := true) -> Array:
	var best := Vector3.INF
	var best_d := SNAP_END_M
	for b: Dictionary in beams():
		if int(b.id) == skip:
			continue
		for end: Vector3 in [b.a, b.b]:
			var d := end.distance_to(p)
			if d < best_d:
				best_d = d
				best = end
	if best.is_finite():
		return [best, "end"]
	best_d = SNAP_NODE_M
	for c: Vector3 in frame_nodes():
		var d := c.distance_to(p)
		if d < best_d:
			best_d = d
			best = c
	if best.is_finite():
		return [best, "node"]
	return [p.snapped(Vector3.ONE * GRID_M), "grid"] if grid else [p, ""]


## The clash and support checks: what each beam meets.
func run_checks() -> void:
	clashes.clear()
	loose_ends.clear()
	plated_ends.clear()
	unattached.clear()
	var ends := {}
	var list := beams()
	if list.is_empty() or not is_inside_tree():
		return
	var xf := ship_xform()
	var space := get_world_3d().direct_space_state
	var w := bay.get("worker") as CollisionObject3D if bay else null
	var exclude: Array[RID] = []
	if w:
		exclude.append(w.get_rid())
	for b: Dictionary in list:
		var a: Vector3 = b.a
		var e: Vector3 = b.b
		var sec := str(b.section)
		var r := TradesBeamSections.radius(sec)
		var l := a.distance_to(e)
		# The beam's body (its ends left out, where it meets what holds it: a frame node is
		# half a metre across) against the world.
		if l > END_CLEAR_M * 2.0 + 0.1:
			var box := BoxShape3D.new()
			var s: Dictionary = TradesBeamSections.info(sec)
			box.size = Vector3(float(s.get("w", 0.1)) * 0.8, float(s.get("h", 0.1)) * 0.8, l - END_CLEAR_M * 2.0)
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = box
			q.transform = xf * beam_xform(b)
			q.exclude = exclude
			for hit: Dictionary in space.intersect_shape(q, 8):
				# A part already taken off her (its slot empty) is out of the way.
				if not _gone(hit.get("collider"), int(hit.get("shape", 0))):
					clashes[int(b.id)] = "ship"
					break
		for o: Dictionary in list:
			if int(o.id) <= int(b.id):
				continue
			var c := Geometry3D.get_closest_points_between_segments(a, e, o.a, o.b)
			if c[0].distance_to(c[1]) >= (r + TradesBeamSections.radius(str(o.section))) * 0.8:
				continue
			# Meeting at an end is a joint, not a clash.
			var at: Vector3 = c[0]
			var at_end := false
			for end: Vector3 in [a, e, o.a, o.b]:
				if end.distance_to(at) < r * 2.0 + MEET_M:
					at_end = true
			if not at_end:
				clashes[int(b.id)] = "beam"
				clashes[int(o.id)] = "beam"
		for k in 2:
			var end: Vector3 = a if k == 0 else e
			var on := _end_on(end, int(b.id), list, space, xf, exclude)
			if on == "frame" or on == "plated":
				ends[int(b.id)] = true
			if on == "":
				loose_ends.append([int(b.id), k])
			elif on == "plated":
				plated_ends.append([int(b.id), k])
	# Which beams reach the frame through the design: from every beam with an end on the
	# frame, along the beams whose ends meet or rest on each other.
	var reached := {}
	var todo: Array = []
	for id: int in ends:
		reached[id] = true
		todo.append(id)
	while not todo.is_empty():
		var id: int = todo.pop_back()
		var b0 := {}
		for o: Dictionary in list:
			if int(o.id) == id:
				b0 = o
		for o: Dictionary in list:
			if reached.has(int(o.id)) or not _touches(b0, o):
				continue
			reached[int(o.id)] = true
			todo.append(int(o.id))
	for o: Dictionary in list:
		if not reached.has(int(o.id)):
			unattached.append(int(o.id))


## Whether two beams of the design meet: an end of one on the other.
static func _touches(b: Dictionary, o: Dictionary) -> bool:
	for pair: Array in [[b, o], [o, b]]:
		var x: Dictionary = pair[0]
		var y: Dictionary = pair[1]
		for end: Vector3 in [x.a, x.b]:
			if end.distance_to(y.a) < MEET_M or end.distance_to(y.b) < MEET_M:
				return true
			var c := Geometry3D.get_closest_point_to_segment(end, y.a, y.b)
			if c.distance_to(end) < TradesBeamSections.radius(str(y.section)) + HOLD_M:
				return true
	return false


## What holds an end: "beam" (another beam of the design), "frame" (a frame member of the
## ship), "plated" (a frame member with a plate still fitted over it there), "" (nothing:
## the air, the ground, the cradle or a plate alone).
func _end_on(end: Vector3, id: int, list: Array, space: PhysicsDirectSpaceState3D, xf: Transform3D, exclude: Array[RID]) -> String:
	for o: Dictionary in list:
		if int(o.id) == id:
			continue
		if end.distance_to(o.a) < MEET_M or end.distance_to(o.b) < MEET_M:
			return "beam"
		var c := Geometry3D.get_closest_point_to_segment(end, o.a, o.b)
		if c.distance_to(end) < TradesBeamSections.radius(str(o.section)) + HOLD_M:
			return "beam"
	var ball := SphereShape3D.new()
	ball.radius = HOLD_M
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = ball
	q.transform = Transform3D(Basis(), xf * end)
	q.exclude = exclude
	for hit: Dictionary in space.intersect_shape(q, 16):
		if part_kind(hit.get("collider"), int(hit.get("shape", 0)), xf * end) == "frame":
			return "plated" if plated_at(end) else "frame"
	return ""


## Whether one of the ship's outer plates is still fitted over the frame at `end` (ship space).
func plated_at(end: Vector3) -> bool:
	var b := Modules.bus("ship_bay") as ShipBayBus
	if b == null or b.ship == null:
		return false
	var fitted := false
	var reach := PLATE_GENTLE_M if Flags.is_on("trades.gentle_plates") else PLATE_M
	for s: MountSlot in b.get_slots():
		if not s.slot_id.begins_with("plate_") or not s.box.grow(reach).has_point(end):
			continue
		if b.get_slot_state(s.slot_id) != ShipBayBus.SlotState.EMPTY:
			fitted = true
		elif Flags.is_on("trades.gentle_plates"):
			# trades.gentle_plates (beenster, 0.3.31: "the test highlights some ends which are
			# obscured by plates but it wasn't the case"): a plate taken off beside the end
			# leaves the frame there bare, whatever its neighbours still cover.
			return false
	return fitted


## Whether a hit is on a part of the ship that has been taken off (its slot empty).
func _gone(collider: Object, shape_idx: int) -> bool:
	var b := Modules.bus("ship_bay") as ShipBayBus
	if b == null or collider == null:
		return false
	return str(b.inspect_at(collider, shape_idx, Vector3.ZERO).get("slot_state", "")) == "empty"


## What a hit on the ship is: "frame" (a member still on her), "plate" (a hull plate or a pane
## still fitted), "" for anything else (or nothing the bay knows).
func part_kind(collider: Object, shape_idx: int, at: Vector3) -> String:
	var b := Modules.bus("ship_bay") as ShipBayBus
	if b == null or collider == null:
		return ""
	var info := b.inspect_at(collider, shape_idx, at)
	if info.is_empty() or str(info.get("slot_state", "")) == "empty":
		return ""
	match str(info.get("kind", "")):
		"frame":
			return "frame"
		"hull", "glass":
			return "plate"
	return ""


## The ship's frame nodes still on her (ship space): where members meet, for ends to snap to.
## From her Void Salvage file; a node whose slot is empty has been taken off.
func frame_nodes() -> Array:
	var b := Modules.bus("ship_bay") as ShipBayBus
	var out: Array = []
	if b == null or b.ship == null:
		return out
	var gone := {}
	for s: MountSlot in b.get_slots():
		if s.slot_id.begins_with("frame_") and b.get_slot_state(s.slot_id) == ShipBayBus.SlotState.EMPTY:
			for path: String in s.parts:
				gone[path] = true
	for p: Variant in _ship_file(b.ship).get("parts", []):
		if p is Dictionary and str((p as Dictionary).get("name", "")) == "FrameNode" and not gone.has(str((p as Dictionary).get("path", ""))):
			out.append(VsShipImport.vec3(((p as Dictionary).get("xform", {}) as Dictionary).get("o", [0, 0, 0])))
	return out


## A beam's transform in ship space: its middle, its length along Z, its section's height up
## (as near up as the beam lets it), rolled by its turn.
static func beam_xform(b: Dictionary) -> Transform3D:
	var a: Vector3 = b.a
	var e: Vector3 = b.b
	var dir := (e - a).normalized()
	if dir == Vector3.ZERO:
		dir = Vector3.FORWARD
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	var basis := Basis.looking_at(dir, up)
	basis = basis * Basis(Vector3.BACK, deg_to_rad(float(b.get("turn", 0.0))))
	return Transform3D(basis, (a + e) * 0.5)


# --- Drawing --------------------------------------------------------------------------------

func _draw() -> void:
	var list := beams()
	var faint := not _anyone_holding()
	var key := "%s|%s|%s|%s|%s|%d|%d|%s|%d" % [str(list), str(clashes), str(loose_ends), str(plated_ends), str(unattached), hovered, grabbed, faint, editing()]
	if key != _drawn_key:
		_drawn_key = key
		for c in _holo.get_children():
			if c.name.begins_with("Beam_") or c.name.begins_with("End_"):
				_holo.remove_child(c)
				c.queue_free()
		var meshes := {}
		for b: Dictionary in list:
			var id := int(b.id)
			# The one being edited is drawn as the growing beam instead.
			if id == editing():
				continue
			var l := ((b.b as Vector3) - (b.a as Vector3)).length()
			var mk := "%s/%.3f" % [b.section, l]
			if not meshes.has(mk):
				meshes[mk] = TradesBeamSections.mesh(str(b.section), l)
			var mi := MeshInstance3D.new()
			mi.name = "Beam_%d" % id
			mi.mesh = meshes[mk]
			mi.transform = beam_xform(b)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.material_override = _mats.red if clashes.has(id) else (_mats.lit if id == hovered or id == grabbed
					else (_mats.amber if unattached.has(id) else (_mats.faint if faint else _mats.blue)))
			_holo.add_child(mi)
		for le: Array in loose_ends + plated_ends:
			var b := {}
			for o: Dictionary in list:
				if int(o.id) == int(le[0]):
					b = o
			if b.is_empty():
				continue
			var dot := MeshInstance3D.new()
			dot.name = "End_%d_%d" % [le[0], le[1]]
			var sm := SphereMesh.new()
			sm.radius = 0.06
			sm.height = 0.12
			dot.mesh = sm
			dot.material_override = _mats.amber if loose_ends.has(le) else _mats.pink
			dot.position = b.a if int(le[1]) == 0 else b.b
			_holo.add_child(dot)
	# The beam being drawn, the snap point and the length.
	var bad := holding() and _bad_point.is_finite()
	_marker.visible = holding() and (aim_point.is_finite() or bad)
	if _marker.visible:
		_marker.position = aim_point if aim_point.is_finite() else _bad_point
		_marker.material_override = _mats.red if bad else (_mats.amber if snapped_to == "end" else (_mats.pink if snapped_to == "plate" else _mats.lit))
	var ga := start if draft.is_empty() else (draft.root as Vector3)
	_ghost.visible = holding() and ga.is_finite() and aim_point.is_finite() and ga.distance_to(aim_point) > 0.01
	_length_label.visible = _ghost.visible or grabbed >= 0
	if _ghost.visible:
		var g := {"a": ga, "b": aim_point, "section": section, "turn": 0.0}
		var l := ga.distance_to(aim_point)
		_beam_mesh(_ghost, section, l)
		_ghost.transform = beam_xform(g)
		_length_label.position = (ga + aim_point) * 0.5 + Vector3.UP * 0.15
		_length_label.text = "%d mm" % roundi(l * 1000.0)
		if not draft.is_empty() and (absf(float(draft.yaw)) > 0.1 or absf(float(draft.pitch)) > 0.1):
			_length_label.text += "  %+d° %+d°" % [roundi(float(draft.yaw)), roundi(float(draft.pitch))]
	elif grabbed >= 0:
		var b := beam(grabbed)
		if not b.is_empty():
			_length_label.position = ((b.a as Vector3) + (b.b as Vector3)) * 0.5 + Vector3.UP * 0.15
			_length_label.text = "%d mm" % roundi(((b.b as Vector3) - (b.a as Vector3)).length() * 1000.0)
	_draw_grid(_ghost.visible and not draft.is_empty())
	_draw_others()
	_info()


## The alignment grid round the growing beam's end (trades.beam_grid), in ship space: a level
## grid on the ship's own 0.5 m lines at the end's height, a line from the end down (or up) to
## it, and the ship's three axes through the end.
func _draw_grid(on: bool) -> void:
	on = on and grid_on()
	_grid.visible = on
	if not on:
		_grid_key = ""
		return
	var e := aim_point
	var key := str(e.snappedf(0.001))
	if key == _grid_key:
		return
	_grid_key = key
	var im := _grid.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var y := e.y
	var c := Vector3(snappedf(e.x, GRID_CELL_M), y, snappedf(e.z, GRID_CELL_M))
	var n := roundi(GRID_HALF_M / GRID_CELL_M)
	for k in range(-n, n + 1):
		var fade := 1.0 - absf(k) / float(n + 1)
		var col := Color(GRID_COLOUR, GRID_COLOUR.a * fade)
		for q: Vector3 in [c + Vector3(k * GRID_CELL_M, 0, -GRID_HALF_M), c + Vector3(k * GRID_CELL_M, 0, GRID_HALF_M),
				c + Vector3(-GRID_HALF_M, 0, k * GRID_CELL_M), c + Vector3(GRID_HALF_M, 0, k * GRID_CELL_M)]:
			im.surface_set_color(col)
			im.surface_add_vertex(q)
	var root: Vector3 = draft.root
	for q: Vector3 in [root, Vector3(root.x, y, root.z)]:
		im.surface_set_color(GRID_COLOUR)
		im.surface_add_vertex(q)
	for ax: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		for q: Vector3 in [e - ax * GRID_HALF_M, e + ax * GRID_HALF_M]:
			im.surface_set_color(AXIS_COLOUR)
			im.surface_add_vertex(q)
	im.surface_end()


func _beam_mesh(mi: MeshInstance3D, sec: String, l: float) -> void:
	var gk := "%s/%.3f" % [sec, l]
	if mi.get_meta("key", "") != gk:
		mi.set_meta("key", gk)
		mi.mesh = TradesBeamSections.mesh(sec, l)


## The other players' beams as they grow, faint, where they are now.
func _draw_others() -> void:
	var others := others_growing()
	for c in _holo.get_children():
		if c.name.begins_with("Draft_") and not others.has(int(str(c.name).trim_prefix("Draft_"))):
			_holo.remove_child(c)
			c.queue_free()
	for peer: int in others:
		var g: Dictionary = others[peer]
		var mi := _holo.get_node_or_null("Draft_%d" % peer) as MeshInstance3D
		if mi == null:
			mi = MeshInstance3D.new()
			mi.name = "Draft_%d" % peer
			mi.material_override = _mats.ghost
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_holo.add_child(mi)
		var l := (g.a as Vector3).distance_to(g.b)
		if l < 0.01:
			continue
		_beam_mesh(mi, str(g.section), l)
		mi.transform = beam_xform({"a": g.a, "b": g.b, "turn": 0.0})


func _anyone_holding() -> bool:
	return holding()


## The right-hand panel while the tablet is in hand.
func info_lines() -> PackedStringArray:
	var out := PackedStringArray()
	var t := totals()
	var n := beams().size()
	out.append("Next beam  %s" % TradesBeamSections.name_of(section))
	if not draft.is_empty():
		out.append("Growing  %d mm, swung %+d°, tilted %+d°" % [roundi(float(draft.length) * 1000.0), roundi(float(draft.yaw)), roundi(float(draft.pitch))])
	var others := others_growing().size()
	if others > 0:
		out.append("Crew drawing  %d beam%s" % [others, "" if others == 1 else "s"])
	if versions_on():
		var counts := version_counts()
		var row := PackedStringArray()
		for v: String in TradesBus.BEAM_VERSIONS:
			row.append(("[%s]" if v == version() else "%s") % v + " " + (str(counts[v]) if int(counts[v]) > 0 else "-"))
		out.append("Version  %s" % "   ".join(row))
	out.append("Design  %d beams, %.1f m, %d kg" % [n, t.x, roundi(t.y)])
	if order_on():
		var c := committed()
		if not order_offer.is_empty():
			out.append("Order  " + order_line())
		elif not c.is_empty():
			var bars := 0
			for bar: String in c.ordered:
				bars += int(c.ordered[bar])
			out.append("Committed  version %s, %d beams, %d bar%s ordered, %d CR%s" % [c.version, (c.rows as Array).size(), bars,
					"" if bars == 1 else "s", int(c.cost), "" if is_committed() else ": changed since, O to commit again"])
		elif n > 0:
			out.append("Happy with it?  O commits the frame and orders its parts")
	if not clashes.is_empty():
		out.append("Clashes  %d beams (red)" % clashes.size())
	if not loose_ends.is_empty():
		out.append("Loose ends  %d (amber): not on the frame or another beam" % loose_ends.size())
	if not plated_ends.is_empty():
		out.append("Plated  %d ends (pink): strip the plates over the frame there" % plated_ends.size())
	if not unattached.is_empty():
		out.append("Not on the ship  %d beams (amber): join them to her frame" % unattached.size())
	var id := grabbed if grabbed >= 0 else hovered
	if id >= 0:
		var b := beam(id)
		if not b.is_empty():
			out.append("This beam  %s, %d mm" % [TradesBeamSections.name_of(str(b.section)),
					roundi(((b.b as Vector3) - (b.a as Vector3)).length() * 1000.0)])
	if versions_on() and not test_result.is_empty():
		out.append(("Test  " + test_line()) if str(test_result.key) == design_key() else "Test  changed since: H to test again")
	out.append(doing())
	return out


## What the tablet is doing, in a few words with its keys.
func doing() -> String:
	if grow_on() and grabbed < 0:
		var sec := ", Shift+wheel section" if TradesBeamSections.order().size() > 1 else ""
		if not draft.is_empty():
			if editing() >= 0:
				return "Editing (Growing from its root): wheel length%s, Q/E swing, Shift+Q/E tilt, click to put it back, right click leave it as it was" % sec
			return "Growing: wheel length%s, Q/E swing, Shift+Q/E tilt, click to place, right click cancel" % sec
		if not copying.is_empty():
			var l := "Copy of a %d mm beam: " % roundi(float(copying.length) * 1000.0)
			if root_on != "":
				return l + "click to grow it from here, right click drop the copy"
			return l + "point at the frame or a beam's end to grow it from, right click drop the copy"
		if root_on == "end":
			return "Click to grow a beam on from this end"
		if hovered >= 0:
			return "Click to %s, right click delete,%s wheel length%s, Q/E swing, Shift+Q/E tilt, Ctrl+Q/E roll" % ["edit" if edit_on() else "move", " G copy," if copy_on() else "", sec]
		if root_on != "":
			return "Click to grow a beam out of the ship here" + (" (strip this plate first)" if root_on == "plate" else "")
		return "Point at the ship's frame, or a beam's end, to grow a beam" + (", X undo, R version, H test" if versions_on() else ", X undo") \
				+ (", Backspace clear all" if clear_on() else "") + (", O commit and order" if order_on() and not beams().is_empty() else "")
	if grabbed >= 0:
		return "Moving: click to set it down, Q/E turn, right click cancel"
	if start.is_finite():
		return "Drawing: click the far end, wheel for the section, right click cancel"
	if hovered >= 0:
		return "Click to move, right click delete, G copy, Q/E turn, wheel section"
	var clear := ", Backspace clear all" if clear_on() else ""
	if versions_on():
		return "Click to start a beam, X undo, R version, H test" + clear
	return "Click to start a beam, X undo" + clear


func _info() -> void:
	var tab := bay.call("tool_node", &"tablet") as TradesDesignTablet if bay and bay.has_method("tool_node") else null
	if tab:
		tab.section = TradesBeamSections.name_of(section)
		tab.count = beams().size()
		tab.version = version() if versions_on() else ""
		tab.test = "" if test_result.is_empty() or str(test_result.key) != design_key() else ("PASS" if test_result.passed else "FAIL")
		tab.doing = "moving" if grabbed >= 0 else ("drawing" if start.is_finite() or not draft.is_empty() else ("on a beam" if hovered >= 0 else "ready"))
	if not holding():
		if _shown != "":
			_shown = ""
			HudSlots.clear_info(INFO)
		return
	var text := "\n".join(info_lines())
	if text != _shown:
		_shown = text
		HudSlots.set_info(INFO, "Frame Builder" if TradesDesignTablet.renamed() else "Beam design", text, 9)


func _play(sound: StringName) -> void:
	if bay and bay.has_method("play"):
		bay.call("play", sound)


func _say(text: String) -> void:
	if bay and bay.has_method("hint"):
		bay.call("hint", text)


# --- Shared with the crew -------------------------------------------------------------------

func _ask(p: Dictionary) -> void:
	if _net and bool(_net.call("is_online")):
		_net.call("request", EVENT, p)
		return
	var v: Variant = _validate(1, p)
	if v is Dictionary:
		_apply(v)


func _validate(sender: int, p: Dictionary) -> Variant:
	var out := {"ship": str(p.get("ship", ""))}
	if p.has("put") or p.has("del"):
		return _validate_one(sender, p, out)
	if p.has("commit"):
		var c: Variant = p.commit
		if not c is Dictionary or not (c as Dictionary).get("rows") is Array or ((c as Dictionary).rows as Array).size() > MAX_BEAMS:
			return "bad commit"
		for r: Variant in (c as Dictionary).rows:
			var bad := _bad_row(r)
			if bad != "":
				return bad
		out["commit"] = c
		return out
	if p.has("show"):
		if not TradesBus.BEAM_VERSIONS.has(str(p.show)):
			return "bad version"
		out["show"] = str(p.show)
		if not p.has("rows"):
			return out
	if p.has("version"):
		if not TradesBus.BEAM_VERSIONS.has(str(p.version)):
			return "bad version"
		out["version"] = str(p.version)
	var rows: Variant = p.get("rows")
	if not rows is Array or (rows as Array).size() > MAX_BEAMS:
		return "bad design"
	for r: Variant in rows:
		var bad := _bad_row(r, false)
		if bad != "":
			return bad
	out["rows"] = rows
	return out


## One beam's change: its row checked, a new beam's id made free on the host's design.
func _validate_one(sender: int, p: Dictionary, out: Dictionary) -> Variant:
	var v := str(p.get("version", ""))
	if v != "" and not TradesBus.BEAM_VERSIONS.has(v):
		return "bad version"
	out["version"] = v
	if p.has("del"):
		out["del"] = int(p.del)
		return out
	var bad := _bad_row(p.get("put"))
	if bad != "":
		return bad
	var row := (p.put as Dictionary).duplicate()
	var bus := Modules.bus("trades") as TradesBus
	if bool(p.get("new", false)) and bus:
		var used := {}
		var top := 0
		for r: Dictionary in bus.beam_design(out.ship, v):
			used[int(r.id)] = true
			top = maxi(top, int(r.id))
		if used.has(int(row.id)):
			out["asked"] = int(row.id)
			row["id"] = top + 1
	out["put"] = row
	out["peer"] = sender
	return out


## Why a beam's row can't be taken ("" when it can).
static func _bad_row(r: Variant, need_id := true) -> String:
	if not r is Dictionary or not (r as Dictionary).get("a") is Array or not (r as Dictionary).get("b") is Array:
		return "bad beam"
	var d := r as Dictionary
	if (d.a as Array).size() != 3 or (d.b as Array).size() != 3 or (need_id and not d.has("id")):
		return "bad beam"
	var l := _v(d.a).distance_to(_v(d.b))
	if not is_finite(l) or l < MIN_M * 0.5 or l > MAX_M:
		return "bad length"
	if not TradesBeamSections.has(str(d.get("section", ""))):
		return "bad section"
	return ""


func _apply(p: Dictionary) -> void:
	var bus := Modules.bus("trades") as TradesBus
	if bus == null:
		return
	if p.has("put") or p.has("del"):
		_apply_one(bus, p)
		return
	if p.has("commit"):
		bus.set_committed_frame(str(p.ship), p.commit)
		return
	if p.has("rows"):
		bus.set_beam_design(str(p.ship), p.rows, str(p.get("version", "")))
	if p.has("show"):
		bus.show_beam_version(str(p.ship), str(p.show))


func _apply_one(bus: TradesBus, p: Dictionary) -> void:
	var ship := str(p.ship)
	var v := str(p.get("version", ""))
	var rows: Array = bus.beam_design(ship, v).duplicate(true)
	var id := int(p.del) if p.has("del") else int((p.put as Dictionary).id)
	rows = rows.filter(func(r: Dictionary) -> bool: return int(r.id) != id)
	if p.has("put"):
		rows.append(p.put)
	bus.set_beam_design(ship, rows, v)
	# A new beam of mine the host gave another id: keep pointing at it.
	if p.has("asked") and int(p.get("peer", -1)) == _me():
		_renumber(int(p.asked), id)


func _me() -> int:
	return int(_net.call("local_peer_id")) if _net and bool(_net.call("is_online")) else 1


func _renumber(from: int, to: int) -> void:
	if _pick_when_here == from:
		_pick_when_here = to
	for stack: Array in [_undo, _redo]:
		for step: Array in stack:
			for c: Array in step:
				if int(c[0]) == from:
					c[0] = to
					for i in [1, 2]:
						if c[i] is Dictionary:
							c[i]["id"] = to


func get_net_snapshot() -> Dictionary:
	var bus := Modules.bus("trades") as TradesBus
	return {"designs": bus.save_data().get("beam_designs", {}) if bus else {}}


func apply_net_snapshot(data: Dictionary) -> void:
	var bus := Modules.bus("trades") as TradesBus
	var designs: Variant = data.get("designs", {})
	if bus and designs is Dictionary:
		for ship: Variant in designs:
			bus.restore_beam_design(str(ship), designs[ship])
