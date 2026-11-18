class_name YardAvatar
extends Node3D
## What other players look like: a salvager in a hard-shell EVA suit with a jet pack
## (docs/AVATAR_PLAN.md, direction A), on a jointed rig: `joints` is a hierarchy of named
## pivots (pelvis, spine, chest, neck, head, pack, clavicles, arms, hands, fingers, thumbs,
## legs, feet, toes; `BONES`) and every suit part rides one, so poses are just joint
## rotations: standing, floating, crouched, seated (AV1). Hard shell in the company's
## livery over ribbed fabric joints, the player's colour on the shoulders, visor rim and
## pack flash. A name tag above says how far away they are.
##
## Built for OTHER players' rigs; your own view is first-person, so your own rig gets a
## shadow-only copy (`setup_shadow`): unseen, but it casts your shadow. Positions are
## relative to the rig's centre (chest height): the eyes are 0.3 m up, the feet 1.25 m
## down, inside the rig's 0.6 x 1.8 m capsule (the pack sits behind it, as it always has).
## Presentation only: the pose follows the rig's state (`_follow_rig`), nothing is sent.

const SHELL := ShipParts.SHELL       # the livery's warm white
const TRIM := ShipParts.TRIM         # the company teal
const FABRIC := Color(0.22, 0.25, 0.29)
const RUBBER := Color(0.1, 0.105, 0.11)
const FRAME := Color(0.16, 0.17, 0.19)

## The joints: [name, parent ("" for the root), position in the model's rest pose (m)].
## The rest pose stands straight, arms hanging; every joint's rest basis is identity, so a
## pose is a rotation per joint about its own pivot (+X pitches a hanging limb forward and
## an upright one, the spine or neck, back).
const BONES: Array = [
	["pelvis", "", Vector3(0, -0.36, 0)],
	["spine", "pelvis", Vector3(0, -0.2, 0)],
	["chest", "spine", Vector3(0, 0.0, 0)],
	["neck", "chest", Vector3(0, 0.17, 0)],
	["head", "neck", Vector3(0, 0.26, 0)],
	["pack", "chest", Vector3(0, 0.02, 0.2)],
	["clavicle_L", "chest", Vector3(-0.07, 0.12, 0)],
	["upper_arm_L", "clavicle_L", Vector3(-0.23, 0.11, 0)],
	["forearm_L", "upper_arm_L", Vector3(-0.25, -0.17, 0)],
	["hand_L", "forearm_L", Vector3(-0.26, -0.43, 0)],
	["fingers_L", "hand_L", Vector3(-0.26, -0.52, -0.01)],
	["thumb_L", "hand_L", Vector3(-0.205, -0.465, 0.0)],
	["clavicle_R", "chest", Vector3(0.07, 0.12, 0)],
	["upper_arm_R", "clavicle_R", Vector3(0.23, 0.11, 0)],
	["forearm_R", "upper_arm_R", Vector3(0.25, -0.17, 0)],
	["hand_R", "forearm_R", Vector3(0.26, -0.43, 0)],
	["fingers_R", "hand_R", Vector3(0.26, -0.52, -0.01)],
	["thumb_R", "hand_R", Vector3(0.205, -0.465, 0.0)],
	["thigh_L", "pelvis", Vector3(-0.1, -0.44, 0)],
	["shin_L", "thigh_L", Vector3(-0.1, -0.85, 0)],
	["foot_L", "shin_L", Vector3(-0.1, -1.15, 0)],
	["toe_L", "foot_L", Vector3(-0.1, -1.21, -0.13)],
	["thigh_R", "pelvis", Vector3(0.1, -0.44, 0)],
	["shin_R", "thigh_R", Vector3(0.1, -0.85, 0)],
	["foot_R", "shin_R", Vector3(0.1, -1.15, 0)],
	["toe_R", "foot_R", Vector3(0.1, -1.21, -0.13)],
]
## Where the soles are (m below the rig's centre): JetRig.FEET.
const SOLE: float = -1.25
## The eye over the rig's centre (m): YardRig.EYE.
const EYE: float = 0.3
## What a crewmate new to the crew carries on their tag.
const NEW_WORD := "NEW"
## The gestures the free arm acts out (Void Salvage's JetRig.Gesture, in its order).
enum Gesture { NONE, OK, NO, COME, STOP, WAVE, BACK, SALUTE, REACH }
## The pack's O2 strip's levels.
enum Air { FINE, WARN, ALARM }
## The company whose initials the badge shows.
var company_name: String = "BSX Ltd"

## The name tag's size: its Label3D pixel_size (the tag keeps one size on screen however far
## away the player is; 0.0018 was the first size, the playtest asked for half).
@export var name_tag_size: float = 0.0009
## How long the faint cone on this player's lamp is (m; the rig's `beam_length` sets it).
@export var beam_length: float = 12.0
## How bright that cone is (light_beam.gdshader's `strength`); dust in a wreck's air dims it
## while the real beam shows there (WreckAir, VX5: `set_beam_strength`).
const BEAM_STRENGTH: float = 0.18
## The painted cone stops at the first wall down each of its edges (`_probe_beam`), else it ran
## its 12 m through the hull: a crewmate's beam stood out of the Kestrel's side and roof (29 Oct).
## Rays round the edge, one per `light_beam.gdshader` reach (its `reach` array's size).
const BEAM_RAYS: int = 8
## How often the cone looks for walls again (s).
@export var beam_probe_every: float = 0.1
## How fast the figure eases from one pose to the next (1/s).
@export var pose_rate: float = 9.0
## Crouching: how far the hips drop (m) and the torso leans forward (degrees). The hips go
## back as far as keeps the head over the rig's eye (`_head_over_eye`): leaning forward from
## where they were, the helmet stood 21 cm ahead of the eye, round the helmet lamp, and your
## own shadow-only head put the whole beam out ("torch is really bad when crouched", 30 Oct).
@export var crouch_drop: float = 0.5
@export var crouch_lean: float = 40.0
## The exo frame: hip, knee and elbow motors, a spine bar, rails down the legs and arms (an
## upgrade bought at the OUTFIT tab, AVATAR_PLAN.md 9.7).
@export var exo: bool = false
## The name plate's text height (m); the badge's is 0.8 of it.
@export var plate_size: float = 0.025
## How fast a hand goes onto the tool, or onto something carried, and back (1/s).
@export var reach_rate: float = 8.0
## How much of the head's look up and down the figure's neck and helmet follow (0..1).
@export var look_follow: float = 0.9
## Seated, the head turns with the look round from the seat (the pilot's free look, a
## passenger's look) up to a hard suit's neck: to each side, up and down (degrees, the figure's
## own turn; past them the helmet holds there, `head_turn`).
@export var head_turn_limit: float = 70.0
@export var head_up_limit: float = 40.0
@export var head_down_limit: float = 45.0
## Seated where the ship gives the seat a hand rest (`BaseShip.hand_rests`: the Gannet's consoles),
## the hands go onto it, fingertips first: the fingers' bend there (degrees) and how flat the hand
## lies (0: along the line from the shoulder, 1: level).
@export var rest_curl: float = 20.0
@export var rest_flat: float = 1.0
## ...and the body leans forward this far over its seated lean to reach it (degrees).
@export var rest_lean: float = 14.0
@export_group("Motion")
## Walking: the length of one step (m), how high a foot lifts as it swings through (m),
## the free arm's swing (degrees), and the forward lean at a run (degrees).
@export var stride_length: float = 0.55
@export var step_lift: float = 0.07
@export var arm_swing: float = 22.0
@export var run_lean: float = 8.0
## Gliding: how much of the body's lay-out the neck and helmet turn back up to look ahead
## (0..1).
@export var glide_head_up: float = 0.85
## Thrusting: the lean back when braking or reversing, and against a strafe (degrees).
@export var brake_lean: float = 18.0
@export var strafe_lean: float = 14.0
## Floating idle: how far the limbs drift (degrees).
@export var drift: float = 5.0
@export_group("")
## How often the tag's distance is redrawn (s).
const TAG_REFRESH: float = 0.2
## Walking slower than this over the deck (m/s) is standing.
const WALK_FROM: float = 0.25
## The walking speed the stride is sized for (m/s; JetRig.walk_speed).
const WALK_REF: float = 3.0

## A foot came down (EV3): as the stride crosses 0 (the left) and pi (the right), on every
## machine for every rig, from the speed over the deck the figure walks at: the feet you see
## are the feet you hear. `foot` "L" or "R", `speed` over the deck (m/s), `surface` what the
## rig stands on (a ship, a wreck in the boots) where this machine knows it, else null (AU10b
## casts its own ray for another player's).
signal footfall(foot: String, speed: float, surface: Node3D)

## Footfalls so far (tests).
var footfalls: int = 0

## The joints by name (Node3D pivots; BONES).
var joints: Dictionary = {}
## The pose the figure is easing to: "stand", "walk", "crouch", "seat", "float" or "glide".
var pose: String = "stand"
var seated := false
var crouched := false
var on_deck := true
## How the rig moves (from it each frame; set by hand without one): its thrust input
## (local axes, -Z forward), its speed over the deck (model space, m/s), how far into the
## glide it is (0..1) and the glide's full angle (degrees).
var motion := Vector3.ZERO
var ground_speed := Vector3.ZERO
var glide: float = 0.0
var glide_angle: float = 70.0
var _walk_phase: float = 0.0
var _time: float = 0.0

## How far each hand is onto its target (0 = posed, 1 = on it): the right on the tool's
## grip, the left on whatever the rig carries.
var _hold: Dictionary = {"R": 0.0, "L": 0.0}
## A tool to hold without a rig (captures, tests): the right hand goes to its grip.
var tool_override: Node3D
## Something to carry without a rig (captures, tests): the left hand goes to it.
var carry_override: Node3D
## A ping's marker the free (left) arm points at (TW5a, PingSystem: on every machine from the
## ping message), for `_point_left` more seconds.
var _point_target: Node3D
var _point_left: float = 0.0
var _pointing := false   # this frame's left hand is the pointing one
## Seated, the hands resting on the seat's console this frame (side -> true; `_rest_goal`).
var _resting: Dictionary = {}
## TW13: the gesture the free arm acts out (a `JetRig.Gesture`; the rig's own, or a copy's as
## heard in its crew bits), and how long since it began (s). `gesture_override` (>= 0) poses one
## off a rig (captures, tests).
var gesture: int = 0
var gesture_override: int = -1
var _gesture_t: float = 0.0
var _gesturing := false           # this frame's left hand is gesturing
var _gesture_curl: float = -1.0   # its fingers' curl (degrees; < 0: straight)
var _gesture_thumb_up := false
## The way a gesture's palm faces (model space; zero: as the arm's reach leaves it, palm down).
var _gesture_palm := Vector3.ZERO
## TW13: the pack's strobe, on while the rig's beacon is (`beacon_override` >= 0 sets it off a rig),
## and whether it is flashing lit this frame.
var beacon := false
var beacon_override: int = -1
var beacon_flash_lit := false
var _beacon_mat: StandardMaterial3D
var _beacon_lamp: OmniLight3D
## (VX11) A downed suit to everyone else (`set_distress`): the accent strip pulsing red at
## `distress_hz`, the pack's beacon red and fast (`distress_beacon_hz`, lit `distress_flash` of each),
## and a red point on the pack you can see to `distress_range` (from `distress_point_from` out: closer,
## the beacon itself shows), hidden by walls. `distress_override` (>= 0) sets it off a rig.
@export var distress_hz: float = 1.6
@export var distress_beacon_hz: float = 3.0
@export var distress_flash: float = 0.3
@export var distress_range: float = 300.0
@export var distress_point_from: float = 6.0
## The point's size on screen (radians of view: 0.018 is about 13 px at 1080p).
@export var distress_point_size: float = 0.018
const DISTRESS_SHADER := preload("res://modules/yard/assets/avatar/distress_point.gdshader")
const DISTRESS_RED := Color(1.0, 0.06, 0.03)
var distress := false
var distress_override: int = -1
var _distress_shown := false
var _distress_point: MeshInstance3D
var _distress_mat: ShaderMaterial
## (VX11) The visor's panes (every helmet's), and how many cracks they wear now: a suit under the
## visor's `crack_from` shows its cracks to everyone (`set_cracked`, from its integrity).
var _visor_meshes: Array[MeshInstance3D] = []
var visor_cracks: int = 0
## The look's pitch (radians, + up): the rig's head tilt.
var _look_pitch: float = 0.0
## Seated, the figure's own head turn from the seat look (radians, x yaw + left, y pitch + up),
## within the neck's limits (`head_turn`).
var _head_turn := Vector2.ZERO
var _tag: Label3D
var _beam_mat: ShaderMaterial
var _beam_lamp: SpotLight3D
var _beam_half: float = 0.0          # the cone's half-angle (radians)
var _beam_wait: float = 0.0
## Where each edge of the painted cone stops (m along the beam): `BEAM_RAYS` of them, round from
## the lamp's +X toward +Y, as the shader takes them.
var beam_reach := PackedFloat32Array()
var _tag_name: String = ""
## The rig's owner is new to the crew (UX13: its crew bits' NEW flag): the tag says so.
var new_player := false
var _tag_wait: float = 0.0
var _pack_parts: Node3D
var _exo_parts: Array[Node3D] = []
## Every node the suit is built of, freed and built again by `apply_look`.
var _suit_nodes: Array[Node] = []
## Meta on a suit piece whose shadow its joint's (or group's) "SuitShadow" casts (`_merge_shadows`).
const SHADOW_MERGED := "suit_shadow_merged"
## The render layer (17) your own body's unseen pieces and shadows sit on, which your own
## helmet lamp's `shadow_caster_mask` leaves out (JetRig): from inside the helmet you see none
## of it, so its shadow down your own beam was a dark hole round the crosshair (looking down
## crouched, the chest filled it). The sun and others' lamps still cast it; cameras draw it.
const OWN_BODY_LAYER: int = 1 << 16
## The shadow-only material the merged shadows draw with (shared).
static var _shadow_mat: StandardMaterial3D
var _target: Dictionary = {}          # joint -> Quaternion
var _target_pelvis := Vector3.ZERO    # the pelvis's position
var _into: Node3D
var _shell: Material
var _trim: Material
var _accent: StandardMaterial3D
## The pack's O2 strip (TW2): lit from the rig's air, the accent while fine, amber when low,
## red and blinking when nearly out (CrewStatus.air_color).
var _o2: StandardMaterial3D
## How the strip stands now: a CrewStatus.Air level, and the blink's half.
var o2_level: int = Air.FINE
var _o2_lit := true
var _fabric: Material
var _rubber: Material
var _frame: Material
var _visor: StandardMaterial3D
## The designs' panes draw with the visor shader (YardSuitAssets.visor); `_visor` stays the
## plain glass a cracked pane is made from (Glazing.cracked reads its colour and shine).
var _visor_glass: ShaderMaterial

## The look the suit is built from (YardSuitLook) and the accent it shows: the colour the host
## gave this player (the look's own, unless someone else wears it).
var look: Dictionary = YardSuitLook.default_look()
var accent: Color = YardSuitLook.ACCENT[0]
## What the name plate says when the look's plate is blank: the player's name.
var plate_default: String = ""
## The name plate on the chest and the company badge on the left shoulder (Label3D).
var plate: Label3D
var badge: Label3D
## The company initials the badge shows (World.company, redrawn when it changes).
var _badge_text: String = ""

## Where the helmet lamp sits in the head joint's space (m): the rig's lamp, taken in `setup`.
var lamp_mount := Vector3(0.12, 0.12, -0.25)

## Your own body (`setup_shadow`): shadow-only but for the forearms, until a camera
## outside you shows all of it (`show_from_outside`).
var _own_body := false
var _from_outside := false


## Your own body, for shadows only: nothing you can see, no lamp beam or name tag. Your
## name still goes on the plate (the chase camera sees it).
func setup_shadow(color: Color, lamp: SpotLight3D, p_look: Dictionary = {}, display_name: String = "") -> void:
	setup(display_name, color, lamp, true, p_look)


## Your own body: seen from outside (the pilot's chase camera) the whole suit is drawn;
## from inside the helmet only the forearms are (the rest just casts its shadow).
func show_from_outside(on: bool) -> void:
	if not _own_body or on == _from_outside:
		return
	_from_outside = on
	_cast_for_own_body()


func _cast_for_own_body() -> void:
	var forearms: Array = []
	for s in ["L", "R"]:
		forearms.append_array((joints["forearm_" + s] as Node3D).find_children("*", "GeometryInstance3D", true, false))
	for n in find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		# The forearms you see shade your work in your own lamp; the rest stays out of it.
		g.layers = 1 if forearms.has(g) else OWN_BODY_LAYER
		if String(g.name).begins_with("SuitShadow"):
			continue   # the merged shadows cast whatever is seen
		var seen := _from_outside or forearms.has(g)
		if g.has_meta(SHADOW_MERGED) or g is Label3D:
			g.visible = seen   # its shadow is its joint's merged one (a label casts none)
		else:
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if seen \
					else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


## Whether a piece of the suit is drawn (not just casting its shadow): your own body hides
## all but its forearms in first person.
static func drawn(g: GeometryInstance3D) -> bool:
	return g.is_visible_in_tree() and g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


## Builds the figure: `display_name` on the tag (none if "") and the plate, `color` the
## accent the host gave this player, `p_look` the suit (YardSuitLook; {} = the default).
func setup(display_name: String, color: Color, lamp: SpotLight3D, shadow_only: bool = false, p_look: Dictionary = {}) -> void:
	_own_body = shadow_only
	if lamp and lamp.get_parent() is Node3D:
		# The lamp hangs on the rig's Head (the eye); the helmet on the head joint just under it.
		lamp_mount = lamp.position + (lamp.get_parent() as Node3D).position - (BONES_REST["head"] as Vector3)
	if display_name != "":
		plate_default = display_name
	look = YardSuitLook.valid(p_look)
	if exo:
		look["exo"] = true   # the export (captures) shows the struts whatever the look
	accent = color
	_build_joints()
	_build_suit()
	_aim_pose(true)
	if shadow_only:
		# In first person you see only your own forearms and gloves; the helmet, which sits
		# round your own lamp, has no lamp housing so the beam isn't blocked.
		_cast_for_own_body()
		return
	_add_beam(lamp)
	if display_name == "":
		return
	var tag := Label3D.new()
	tag.name = "NameTag"
	tag.text = display_name
	tag.position = Vector3(0, 1.07, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.fixed_size = true
	tag.pixel_size = name_tag_size
	tag.font_size = 32
	tag.outline_size = 8
	tag.modulate = color.lightened(0.35)
	tag.outline_modulate = Color(0, 0, 0, 0.8)
	tag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tag)
	_tag = tag
	_tag_name = display_name


## Wears another look (and accent): the suit is built again under the same joints, so the
## pose, the hands on their tools and everything else carry on.
func apply_look(p_look: Dictionary, color: Color = accent) -> void:
	look = YardSuitLook.valid(p_look)
	accent = color
	if joints.is_empty():
		return
	for n in _suit_nodes:
		if is_instance_valid(n):
			n.free()
	_suit_nodes.clear()
	_exo_parts.clear()
	_pack_parts = null
	_visor_meshes.clear()
	_distress_point = null
	_distress_shown = false
	var cracked := visor_cracks
	visor_cracks = 0
	_build_suit()
	_show_cracks(cracked)
	set_seated(seated)
	if _own_body:
		_cast_for_own_body()
	if _tag:
		_tag.modulate = color.lightened(0.35)


func _process(delta: float) -> void:
	_pose(delta)


## A frame's pose, tag and badge.
func _pose(delta: float) -> void:
	_follow_rig()
	_step(delta)
	_aim_pose()
	_ease_pose(delta)
	_reach_hands(delta)
	_flash_beacon()
	_flash_distress()
	# The tag rides over the head, wherever the pose puts it.
	if _tag:
		_tag.position = _head_in_model() + Vector3(0, 0.45, 0)
	_tag_wait -= delta
	if _tag_wait > 0.0:
		return
	_tag_wait = TAG_REFRESH
	_refresh_badge()
	if _tag == null:
		return
	_tag.pixel_size = name_tag_size
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		_tag.text = _tag_name + (" " + NEW_WORD if new_player else "")
		return
	_tag.text = "%s%s  %d m" % [_tag_name, (" " + NEW_WORD) if new_player else "",
			roundi(cam.global_position.distance_to(global_position))]


## What the name tag says ("" for your own shadow-only body).
func tag_text() -> String:
	return _tag.text if _tag else ""


## A glowing lens and a faint cone of light, hung on the lamp so they switch with it.
func _add_beam(lamp: SpotLight3D) -> void:
	var lens := MeshInstance3D.new()
	lens.name = "LampLens"
	var lens_mesh := SphereMesh.new()
	lens_mesh.radius = 0.03
	lens_mesh.height = 0.06
	lens.mesh = lens_mesh
	var lens_mat := StandardMaterial3D.new()
	lens_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lens_mat.albedo_color = lamp.light_color
	lens_mat.emission_enabled = true
	lens_mat.emission = lamp.light_color
	lens_mat.emission_energy_multiplier = 6.0
	lens.material_override = lens_mat
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lens.position = Vector3(0, 0, -0.02)
	lamp.add_child(lens)

	var length := beam_length
	var cone := MeshInstance3D.new()
	cone.name = "LampBeam"
	cone.mesh = _beam_mesh(length, 0.035, length * tan(deg_to_rad(lamp.spot_angle)) * 0.6)
	var beam_mat := ShaderMaterial.new()
	beam_mat.shader = load("res://modules/yard/assets/avatar/light_beam.gdshader") as Shader
	beam_mat.set_shader_parameter("beam_color", lamp.light_color)
	beam_mat.set_shader_parameter("strength", BEAM_STRENGTH)
	_beam_mat = beam_mat
	cone.material_override = beam_mat
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.add_child(cone)
	_beam_lamp = lamp
	_beam_half = atan((length * tan(deg_to_rad(lamp.spot_angle)) * 0.6 - 0.035) / length)
	beam_reach.resize(BEAM_RAYS)
	beam_reach.fill(length + 1.0)
	beam_mat.set_shader_parameter("reach", beam_reach)
	_beam_wait = randf() * beam_probe_every   # (crewmates' probes spread over the frames)


func _physics_process(delta: float) -> void:
	if _beam_mat == null:
		return
	_beam_wait -= delta
	if _beam_wait > 0.0:
		return
	_beam_wait = beam_probe_every
	_probe_beam()


## Each edge of the painted cone runs to the first wall along it, through glass (a pane lets
## the light out); what is past the wall is drawn no longer. The real light's shadow stops it
## there too.
func _probe_beam() -> void:
	if _beam_lamp == null or not is_instance_valid(_beam_lamp) or not _beam_lamp.is_visible_in_tree() \
			or not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var xf := _beam_lamp.global_transform
	var length := beam_length
	var along := cos(_beam_half)
	for i in BEAM_RAYS:
		var a := TAU * float(i) / float(BEAM_RAYS)
		var dir := (xf.basis * Vector3(cos(a) * sin(_beam_half), sin(a) * sin(_beam_half), -along)).normalized()
		beam_reach[i] = _wall_along(space, xf.origin, dir, length / along) * along
	_beam_mat.set_shader_parameter("reach", beam_reach)


## How far a ray from `from` along `dir` goes before a wall (glass passed), up to `most` (m),
## or `most` + 1 when it meets none.
static func _wall_along(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3, most: float) -> float:
	var start := from
	for pane in 4:
		var q := PhysicsRayQueryParameters3D.create(start, from + dir * most, 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return most + 1.0
		var at := (hit.position as Vector3)
		if pane == 3 or not _is_pane(hit):
			return from.distance_to(at)
		start = at + dir * 0.05
	return most + 1.0


## Did a ray hit a pane of glass (a GLASS part on a salvage body or a frame-built ship)?
static func _is_pane(hit: Dictionary) -> bool:
	var body := hit.get("collider") as CollisionObject3D
	if body == null or not ("model" in body):
		return false
	var owner := body.shape_owner_get_owner(body.shape_find_owner(int(hit.get("shape", 0))))
	var model := body.get("model") as PartModel
	var part := model.part_for_collider(owner as CollisionShape3D) if model and owner is CollisionShape3D else null
	return part != null and part.kind == PartData.Kind.GLASS


## Sets the painted cone's brightness (BEAM_STRENGTH as built; WreckAir dims it in dust).
func set_beam_strength(s: float) -> void:
	if _beam_mat:
		_beam_mat.set_shader_parameter("strength", s)


## The painted cone's brightness now (0 with no cone).
func beam_strength() -> float:
	return float(_beam_mat.get_shader_parameter("strength")) if _beam_mat else 0.0


## The beam's cone along the lamp's forward (-Z), narrow end at the lamp. Its brightness is
## baked into the vertex colours (alpha): bright at the lamp, gone well before the open far
## end, so the rim can never show as a ring whatever the renderer does with it.
static func _beam_mesh(length: float, near_radius: float, far_radius: float) -> ArrayMesh:
	var rings := 14
	var sides := 24
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var slope := (far_radius - near_radius) / length
	for r in rings + 1:
		var t := float(r) / float(rings)
		var radius := lerpf(near_radius, far_radius, t)
		var z := -0.03 - length * t
		var fade := pow(1.0 - smoothstep(0.0, 0.8, t), 2.4)
		for s in sides + 1:
			var a := TAU * float(s) / float(sides)
			var dir := Vector2(cos(a), sin(a))
			verts.append(Vector3(dir.x * radius, dir.y * radius, z))
			normals.append(Vector3(dir.x, dir.y, slope).normalized())
			colors.append(Color(1, 1, 1, fade))
	for r in rings:
		for s in sides:
			var i := r * (sides + 1) + s
			var j := i + sides + 1
			indices.append_array([i, j, i + 1, i + 1, j, j + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# --- Pose ----------------------------------------------------------------------------

## Crouched (or standing again). `share` and `feet` are the rig's (kept for its call; the
## pose bends the knees and drops the hips instead of squashing the figure).
func set_crouched(on: bool, _share: float = 1.0, _feet: float = 0.0) -> void:
	crouched = on
	_aim_pose()


## Sitting in a ship's seat: hips and knees bent, the pack left off (it stays in the
## airlock rack, as far as anyone can tell).
func set_seated(on: bool) -> void:
	seated = on
	if _pack_parts:
		_pack_parts.visible = not on
	for part in _exo_parts:
		part.visible = exo and not on
	_aim_pose()


## Standing on a deck or a hull (true) or floating free (false).
func set_on_deck(on: bool) -> void:
	if on != on_deck:
		on_deck = on
		_aim_pose()


## Goes straight to the current pose (no easing): for tests and captures.
func snap() -> void:
	_follow_rig()
	_aim_pose()
	_ease_pose(1000.0)
	_reach_hands(1000.0)


## A joint's position in the model's space (the rig's), after the current pose.
func joint_position(joint_name: String) -> Vector3:
	return _chain(joints[joint_name] as Node3D).origin


## The centre of a glove's palm (`side` "L" or "R") in the model's space, after the pose.
func palm_position(side: String) -> Vector3:
	return _chain(joints["hand_" + side] as Node3D) * Vector3(0.0, -0.045, 0.0)


## The middle of the end of a glove's fingers (`side` "L" or "R") in the model's space, after the pose.
func fingertip_position(side: String) -> Vector3:
	return _chain(joints["fingers_" + side] as Node3D) * Vector3(0.0, -0.07, 0.0)


## On a JetRig, the pose follows it: seated, crouched, on a deck or floating.
## (RS4a) Is the figure's suit down (its rig's DOWN bit), and the head's pitch then (rad).
var suit_down := false
@export var down_pitch: float = -0.6


func _follow_rig() -> void:
	var rig := get_parent() as YardRig
	if rig == null:
		return
	if crouched:
		set_crouched(false)
	set_on_deck(rig.on_deck())
	_look_pitch = (rig.get_node("Head") as Node3D).rotation.x
	_head_turn = Vector2.ZERO
	motion = rig.thrust_input
	glide = rig.glide
	glide_angle = rig.glide_angle
	ground_speed = global_basis.inverse() * rig.ground_velocity() if on_deck else Vector3.ZERO
	set_air(1.0)
	take_gesture(Gesture.NONE)
	beacon = false


## (VX11) The downed look on this figure (every machine, from its rig's DOWN bit): the strip, the
## beacon and the far point; the helmet lamp's SOS is the rig's (JetRig.sos_lit).
func set_distress(on: bool) -> void:
	distress = on


## Is the distress look showing now (`distress`, or `distress_override`)?
func distress_on() -> bool:
	return distress if distress_override < 0 else distress_override > 0


## (VX11) Wears the visor's cracks for a suit at `integrity` points (the World's visor's
## `crack_from` and `crack_step`, else 60 and 15): its panes take a cracked glass, seeded by its name.
func set_cracked(integrity: float) -> void:
	_show_cracks(0 if integrity >= 60.0 else 1 + floori((60.0 - integrity) / 15.0))


func _show_cracks(count: int) -> void:
	if count == visor_cracks:
		return
	visor_cracks = count
	var seed := absi(hash(_tag_name if _tag_name != "" else plate_default)) % 997
	for i in _visor_meshes.size():
		var mi := _visor_meshes[i]
		if not is_instance_valid(mi):
			continue
		if count <= 0:
			mi.material_override = _visor_glass if mi.has_meta("design_pane") else _visor
			continue
		var box := mi.mesh.get_aabb()
		var points: Array = []
		for k in count:
			# Spread over the pane's front face, seeded (alike on every machine), the first nearest the middle.
			var h := float((seed * 31 + i * 7 + k * 13) % 101) / 101.0
			var g := float((seed * 17 + i * 11 + k * 29) % 89) / 89.0
			var spread := 0.3 + 0.5 * float(k)   # a share of the pane each way from its middle
			var front := box.position.z            # the pane's face toward the view (-Z)
			var at := Vector3(box.get_center().x + (h - 0.5) * box.size.x * spread,
					box.get_center().y + (g - 0.5) * box.size.y * spread, front)
			points.append([at, maxf(box.size.x, box.size.y) * (0.45 + 0.15 * float(k))])
		# A flat pane's box names its glass's plane; the dome's is its faces' own.
		var flat := box.size.z < box.size.x * 0.5
		mi.material_override = Glazing.cracked(_visor, points, box if flat else AABB())


## The rig's gesture now: a new one starts its clock over.
func take_gesture(which: int) -> void:
	if which != gesture:
		gesture = which
		_gesture_t = 0.0


## Lights the pack's O2 strip for `share` of the bottle (every machine, every rig, from the
## air byte in its state): the accent, amber, or red blinking (TW2).
func set_air(share: float) -> void:
	if _o2 == null:
		return
	var level := Air.ALARM if share < 0.1 else (Air.WARN if share < 0.25 else Air.FINE)
	var lit := level != Air.ALARM or fmod(Time.get_ticks_msec() / 1000.0 * 2.0, 1.0) < 0.5
	if level == o2_level and lit == _o2_lit:
		return
	o2_level = level
	_o2_lit = lit
	var c := accent if level == Air.FINE else (Color(1.0, 0.68, 0.12) if level == Air.WARN \
			else (Color(1.0, 0.18, 0.12) if lit else Color(1.0, 0.18, 0.12).darkened(0.85)))
	if _asset_finish:
		_asset_finish.set_shader_parameter("oxygen", c)
	_o2.albedo_color = c
	_o2.emission = c
	_o2.emission_energy_multiplier = (1.4 if level != Air.FINE else 0.45) if lit else 0.0


## The O2 strip's colour now (its glow).
func o2_color() -> Color:
	return _o2.emission if _o2 else accent


## The clocks: the drift's, and the stride's (it advances with the speed over the deck).
func _step(delta: float) -> void:
	_time += delta
	_gesture_t += delta
	var flat := Vector2(ground_speed.x, ground_speed.z).length()
	if flat > WALK_FROM:
		var was := _walk_phase
		_walk_phase = fmod(_walk_phase + flat * delta / stride_length * PI, TAU)
		if floori(was / PI) != floori(_walk_phase / PI) or _walk_phase < was:
			footfalls += 1
			footfall.emit("R" if _walk_phase >= PI else "L", flat, _footing())


## What the rig stands on, where this machine knows it (EV3's footfall): the ship it walks or
## stands in, the body its boots hold; else null.
func _footing() -> Node3D:
	var rig := get_parent() as YardRig
	return rig.floor_body() if rig else null


## Where each hand should be this frame (world), or null: the right hand on the held tool's
## grip, the left on what the rig carries.
func hand_targets() -> Dictionary:
	var out := {"R": null, "L": null}
	_pointing = false
	_resting = {}
	if seated:
		for side: String in ["L", "R"]:
			out[side] = _rest_goal(side)
		var point: Variant = _point_goal()   # a ping from a seat still points
		if point != null:
			out["L"] = point
		_gesture_over(out)
		for side: String in ["L", "R"]:
			_resting[side] = out[side] != null and not (side == "L" and (_pointing or _gesturing))
		return out
	if tool_override and tool_override.is_inside_tree():
		out["R"] = _tool_hand_target(tool_override)
	if carry_override and carry_override.is_inside_tree():
		out["L"] = carry_override.global_transform
	if out["L"] == null:
		out["L"] = _point_goal()   # the free arm, at a marker
	_gesture_over(out)
	return out


func _tool_hand_target(tool: Node3D) -> Transform3D:
	var grip: Variant = tool.get("grip")
	return Transform3D(tool.global_basis, tool.global_transform * (grip as Vector3 if grip is Vector3 else Vector3.ZERO))


## Seated, from the palm's middle to the middle of a resting finger's end, along the hand (m): the
## glove's palm (0.045 to the knuckles) and its fingers (0.07) bent `rest_curl`.
const REST_TIP: float = 0.11
## From a finger's middle line to the face of its pad (m): a resting hand is held this far off
## its rest, so the pads touch it and the fingers are not sunk in it.
const REST_PAD: float = 0.018


## Seated where the seat gives the hands a rest (`BaseShip.hand_rests`)?
func _has_rest() -> bool:
	return false


## Seated, where `side`'s hand rests this frame (world), or null: its fingertips on the seat's rest
## (`BaseShip.hand_rests`), the hand reaching to it from the shoulder, lying `rest_flat` of the way
## to level, palm down: the fingers curl `rest_curl` down onto it, so the palm rides that much
## higher. Null with no rest there, or the suit down.
func _rest_goal(_side: String) -> Variant:
	return null


## A gesture takes the free (left) arm over whatever else it was doing (TW13).
func _gesture_over(out: Dictionary) -> void:
	var g: Variant = _gesture_goal()
	if g != null:
		out["L"] = g
		_pointing = false


## The gesture acting out now (TW13): the override, else the rig's.
func gesture_shown() -> int:
	return gesture_override if gesture_override >= 0 else gesture


## Where the gesturing hand goes this frame (world), or null with none: each a place by the
## shoulder and the way the hand points, moving on the gesture's clock (`_gesture_t`).
func _gesture_goal() -> Variant:
	_gesturing = false
	_gesture_curl = -1.0
	_gesture_thumb_up = false
	_gesture_palm = Vector3.ZERO
	var g := gesture_shown()
	if g == Gesture.NONE or joints.is_empty():
		return null
	var upper := joints["upper_arm_L"] as Node3D
	var sh := _chain(joints["clavicle_L"] as Node3D) * upper.position   # the shoulder, model space
	var t := _gesture_t
	var pos := sh
	var dir := Vector3.UP
	match g:
		Gesture.OK:   # thumbs up, the fist out in front
			pos += Vector3(0.08, -0.14, -0.4)
			dir = Vector3(0.15, 0.05, -1.0)
			_gesture_curl = 100.0
			_gesture_thumb_up = true
			_gesture_palm = Vector3.RIGHT   # the fist on its edge, palm to the body's middle
		Gesture.COME:   # come here: the hand out, palm up, beckoning
			var k := sin(TAU * 2.0 * t)
			pos += Vector3(0.05, -0.12, -0.38 + 0.06 * k)
			dir = Vector3(0.0, 0.6 + 0.5 * k, -1.0)
			_gesture_curl = 20.0 + 35.0 * (1.0 + k)
			_gesture_palm = Vector3.UP
		Gesture.WAVE:   # the hand up by the head, side to side
			var k := sin(TAU * 2.2 * t)
			pos += Vector3(-0.14 + 0.09 * k, 0.4, -0.1)
			dir = Vector3(0.45 * k, 1.0, -0.1)
			_gesture_palm = Vector3.FORWARD
		Gesture.STOP:   # the arm out, the palm held up to them
			pos += Vector3(0.06, 0.06, -0.48)
			dir = Vector3(0.0, 1.0, 0.2)
			_gesture_palm = Vector3.FORWARD
		Gesture.NO:   # the hand up in front, wagging
			var k := sin(TAU * 2.6 * t)
			pos += Vector3(0.03 + 0.07 * k, 0.06, -0.4)
			dir = Vector3(0.4 * k, 1.0, -0.1)
			_gesture_palm = Vector3.FORWARD
		Gesture.BACK:   # back off: the palm pushed out, twice and again
			var k := maxf(sin(TAU * 1.8 * t), 0.0)
			pos += Vector3(0.05, -0.02, -0.28 - 0.2 * k)
			dir = Vector3(0.0, 1.0, 0.35)
			_gesture_palm = Vector3.FORWARD
		_:
			return null
	_gesturing = true
	return global_transform * _hand_along(pos, dir.normalized())


## A hand goal (model space) at `pos` with the hand running along `dir` (_arm_ik runs the hand
## down the grip, so the grip is turned onto `dir`).
static func _hand_along(pos: Vector3, dir: Vector3) -> Transform3D:
	var grip := Vector3(0.0, cos(0.3), sin(0.3))
	return Transform3D(Basis(Quaternion(grip, -dir)), pos)


## Points the free (left) arm at `target` (a ping's marker) for `seconds` (TW5a).
func point_at(target: Node3D, seconds: float) -> void:
	_point_target = target
	_point_left = seconds


## Is the arm pointing at a ping now?
func is_pointing() -> bool:
	return _point_left > 0.0 and is_instance_valid(_point_target) and _point_target.is_inside_tree()


## Where the pointing hand goes (world), or null: the arm straight from the shoulder toward the
## ping, the hand flat along it.
func _point_goal() -> Variant:
	if not is_pointing() or joints.is_empty():
		return null
	var upper := joints["upper_arm_L"] as Node3D
	var shoulder := global_transform * (_chain(joints["clavicle_L"] as Node3D) * upper.position)
	var to := _point_target.global_position - shoulder
	if to.length() < 0.05:
		return null
	_pointing = true
	var dir := to.normalized()
	var a: float = (BONES_REST["forearm_L"] - BONES_REST["upper_arm_L"]).length()
	var b: float = (BONES_REST["hand_L"] - BONES_REST["forearm_L"]).length()
	# _arm_ik runs the hand down the grip, -(basis * GRIP); turned so that runs along `dir`.
	var grip := Vector3(0.0, cos(0.3), sin(0.3))
	return Transform3D(Basis(Quaternion(grip, -dir)), shoulder + dir * ((a + b) * 0.97 + 0.045))


## Puts the hands on their targets (two-bone arm IK, the elbow down and out), easing on
## and off. Runs after the pose, over it.
func _reach_hands(delta: float) -> void:
	if joints.is_empty():
		return
	_point_left = maxf(_point_left - delta, 0.0)
	var targets := hand_targets()
	var k := 1.0 - exp(-reach_rate * delta)
	for side: String in ["R", "L"]:
		var want := 1.0 if targets[side] != null else 0.0
		_hold[side] = lerpf(float(_hold[side]), want, k) if delta < 100.0 else want
		if targets[side] != null:
			_hand_goal[side] = global_transform.affine_inverse() * (targets[side] as Transform3D)
		if float(_hold[side]) > 0.001 and _hand_goal.has(side):
			_arm_ik(side, _hand_goal[side], float(_hold[side]))
			if side == "L" and _pointing:
				# Pointing: the fingers out straight, not round a grip.
				var fingers := joints["fingers_L"] as Node3D
				fingers.quaternion = fingers.quaternion.slerp(Quaternion.IDENTITY, float(_hold[side]))
			elif side == "L" and _gesturing:
				_gesture_hand(float(_hold[side]))
			elif _resting.get(side, false):
				# Resting on a console: the fingers only a little bent, their tips on it.
				var rest := joints["fingers_" + side] as Node3D
				rest.quaternion = rest.quaternion.slerp(_curl(rest_curl), float(_hold[side]))
	_fit_tool_hand()


## The hand is part of the fitted tool assembly while equipped. The arm keeps its
## existing IK target; the elastic wrist spans from its cuff to the travelling hand.
func _fit_tool_hand() -> void:
	(joints["hand_R"] as Node3D).visible = true


## A gesture's fingers and thumb, over the arm's IK, by `weight`: curled or straight, the thumb
## turned to point up (the thumbs-up: its box runs down its -Y).
func _gesture_hand(weight: float) -> void:
	var fingers := joints["fingers_L"] as Node3D
	var curl := Quaternion.IDENTITY if _gesture_curl < 0.0 else _curl(_gesture_curl)
	fingers.quaternion = fingers.quaternion.slerp(curl, weight)
	if _gesture_palm != Vector3.ZERO:
		# The arm's reach sets only the way the hand runs; it is turned about its own length
		# till the palm (its +Z face) looks the way the gesture wants.
		var hand := joints["hand_L"] as Node3D
		var along: Vector3 = (BONES_REST["fingers_L"] - BONES_REST["hand_L"]).normalized()
		var hand_now := _chain(hand).basis.orthonormalized()
		var axis := (hand_now * along).normalized()
		var palm := hand_now * Vector3.BACK
		palm = palm - axis * palm.dot(axis)
		var want := _gesture_palm - axis * _gesture_palm.dot(axis)
		if palm.length() > 0.01 and want.length() > 0.01:
			hand.quaternion = hand.quaternion * Quaternion(along, palm.signed_angle_to(want, axis) * weight)
	if _gesture_thumb_up:
		var thumb := joints["thumb_L"] as Node3D
		var hand_basis := _chain(joints["hand_L"] as Node3D).basis.orthonormalized()
		var up := (hand_basis.inverse() * Vector3.UP).normalized()
		thumb.quaternion = thumb.quaternion.slerp(Quaternion(Vector3.DOWN, up), weight)


## The pack's strobe (TW13): lit `beacon_flash` of each flash at `beacon_hz` while the beacon is
## on, in the accent, its light out to `beacon_range` (the World's ping system's exports, else
## its defaults).
func _flash_beacon() -> void:
	if _beacon_mat == null:
		return
	var on := beacon if beacon_override < 0 else beacon_override > 0
	var hz := 1.2
	var flash := 0.14
	var reach := 25.0
	var energy := 2.5
	# (VX11) a downed suit's beacon: red and fast, whether or not she lit it
	var sos := distress_on() and not _own_body
	if sos:
		on = true
		hz = distress_beacon_hz
		flash = distress_flash / maxf(hz, 0.01)
	var colour := DISTRESS_RED if sos else accent.lightened(0.2)
	if _beacon_mat.emission != colour:
		_beacon_mat.albedo_color = colour
		_beacon_mat.emission = colour
		_beacon_lamp.light_color = colour
	var lit := on and fmod(Time.get_ticks_msec() / 1000.0 * hz, 1.0) < flash * hz
	beacon_flash_lit = lit
	_beacon_mat.emission_energy_multiplier = 6.0 if lit else (0.25 if on else 0.0)
	_beacon_lamp.visible = on
	_beacon_lamp.omni_range = reach
	_beacon_lamp.light_energy = energy if lit else 0.0


## The last place each hand was sent (model space), kept while it lets go.
var _hand_goal: Dictionary = {}


## One arm onto `goal` (model space: the palm's centre, its basis the thing held, -Y down
## its grip), by `weight` (0..1) over the pose.
func _arm_ik(side: String, goal: Transform3D, weight: float) -> void:
	var s := 1.0 if side == "R" else -1.0
	var upper := joints["upper_arm_" + side] as Node3D
	var fore := joints["forearm_" + side] as Node3D
	var hand := joints["hand_" + side] as Node3D
	var a: float = (BONES_REST["forearm_" + side] - BONES_REST["upper_arm_" + side]).length()
	var b: float = (BONES_REST["hand_" + side] - BONES_REST["forearm_" + side]).length()
	var parent := _chain(joints["clavicle_" + side] as Node3D)
	var shoulder := parent * upper.position
	# The hand runs down the grip (leaning forward like a pistol grip); the wrist sits above
	# the palm's centre.
	var down := -(goal.basis * Vector3(0.0, cos(0.3), sin(0.3))).normalized()
	var wrist := goal.origin - down * 0.045
	var to := wrist - shoulder
	var d := clampf(to.length(), 0.05, a + b - 0.001)
	var dir := to.normalized() if to.length() > 0.001 else Vector3.DOWN
	var pole := Vector3(s * 0.6, -1.0, 0.35).normalized()
	var perp := pole - dir * pole.dot(dir)
	perp = perp.normalized() if perp.length() > 0.01 else Vector3.DOWN
	var alpha := acos(clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0))
	var elbow := shoulder + dir * cos(alpha) * a + perp * sin(alpha) * a
	var wrist_at := elbow + (shoulder + dir * d - elbow).normalized() * b
	# Joint turns: each maps its rest direction onto the new one, in its parent's frame.
	var pb := parent.basis.orthonormalized()
	var u0: Vector3 = (BONES_REST["forearm_" + side] - BONES_REST["upper_arm_" + side]).normalized()
	var q_upper := Quaternion(u0, (pb.inverse() * (elbow - shoulder)).normalized())
	var ub := pb * Basis(q_upper)
	var f0: Vector3 = (BONES_REST["hand_" + side] - BONES_REST["forearm_" + side]).normalized()
	var q_fore := Quaternion(f0, (ub.inverse() * (wrist_at - elbow)).normalized())
	var fb := ub * Basis(q_fore)
	var h0: Vector3 = (BONES_REST["fingers_" + side] - BONES_REST["hand_" + side]).normalized()
	var q_hand := Quaternion(h0, (fb.inverse() * down).normalized())
	upper.quaternion = upper.quaternion.slerp(q_upper, weight)
	fore.quaternion = fore.quaternion.slerp(q_fore, weight)
	hand.quaternion = hand.quaternion.slerp(q_hand, weight)
	var fingers := joints["fingers_" + side] as Node3D
	fingers.quaternion = fingers.quaternion.slerp(_curl(70.0), weight)
	var thumb := joints["thumb_" + side] as Node3D
	thumb.quaternion = thumb.quaternion.slerp(_rot(-30.0, 0.0, -s * 30.0), weight)


## Picks the pose from the state and how the rig moves, and sets every joint's target.
## Runs every frame (the stride and the drift move on).
func _aim_pose(now: bool = false) -> void:
	if joints.is_empty():
		return
	var flat := Vector2(ground_speed.x, ground_speed.z).length()
	if seated:
		pose = "seat"
	elif crouched:
		pose = "crouch"
	elif on_deck:
		pose = "walk" if flat > WALK_FROM else "stand"
	else:
		pose = "glide" if glide > 0.05 else "float"
	for b: Array in BONES:
		_target[b[0]] = Quaternion.IDENTITY
	_target_pelvis = Vector3.ZERO
	match pose:
		"stand":
			_arms(4.0, 12.0, 22.0)
		"walk":
			_walk_pose(flat)
		"float":
			_float_pose()
		"glide":
			_glide_pose()
		"crouch":
			# -X pitches the torso (pointing up) forward; the arms hang from it, so they turn
			# with it and need the lean back plus a little to reach towards the knees.
			_target["pelvis"] = _rot(-crouch_lean * 0.45)
			_target["spine"] = _rot(-crouch_lean * 0.55)
			_target["neck"] = _rot(crouch_lean * 0.6)   # eyes stay level
			_target_pelvis = Vector3(0, -crouch_drop, 0)
			_target_pelvis.z = _head_over_eye()
			_arms(12.0, crouch_lean + 25.0, 30.0)
			for side in ["L", "R"]:
				_leg_ik(side, Vector3(-0.1 if side == "L" else 0.1, BONES_REST["foot_" + side].y, 0.0))
		"seat":
			_target["spine"] = _rot(-4.0 - (rest_lean if _has_rest() else 0.0))
			_arms(10.0, 24.0, 62.0)
			for side in ["L", "R"]:
				_target["thigh_" + side] = _rot(90.0)
				_target["shin_" + side] = _rot(-88.0)
	if now:
		snap()


## How far back (m, +Z) the hips go so the head joint, posed by the targets from the pelvis
## at `_target_pelvis`, stands where it does at rest along the body: over the rig's eye, behind
## the helmet lamp (the look's pitch aside: it turns the head about the neck alike standing).
func _head_over_eye() -> float:
	var at: Vector3 = BONES_REST["pelvis"] + _target_pelvis
	var turn := Quaternion.IDENTITY
	var from := "pelvis"
	for b in ["pelvis", "spine", "chest", "neck"]:
		turn = turn * (_target.get(b, Quaternion.IDENTITY) as Quaternion)
		var child: String = {"pelvis": "spine", "spine": "chest", "chest": "neck", "neck": "head"}[b]
		at += turn * ((BONES_REST[child] as Vector3) - (BONES_REST[from] as Vector3))
		from = child
	return (BONES_REST["head"] as Vector3).z - at.z


## Walking or running over the deck: the feet step along the way you go (planted by the
## leg IK, swinging through with a lift), the hips dip a little, the free arm swings
## against the legs and the body leans into a run.
func _walk_pose(flat: float) -> void:
	var pace := clampf(flat / WALK_REF, 0.0, 1.6)
	var forward := -ground_speed.z / maxf(flat, 0.001)   # 1 straight ahead, -1 backing up
	var reach := stride_length * 0.5 * clampf(pace, 0.0, 1.0) * forward
	_target_pelvis = Vector3(0.0, -0.05 - 0.025 * absf(sin(_walk_phase)) * pace, 0.0)
	_target["spine"] = _rot(-run_lean * maxf(pace - 1.0, 0.0) / 0.6 * signf(forward))
	for side in ["L", "R"]:
		var phase := _walk_phase + (0.0 if side == "L" else PI)
		var lift := step_lift * clampf(pace * 2.0, 0.0, 1.0) * maxf(cos(phase), 0.0)
		var ankle := Vector3(-0.1 if side == "L" else 0.1, BONES_REST["foot_" + side].y + lift, -reach * sin(phase))
		_leg_ik(side, ankle)
	_arms(4.0, 12.0, 22.0)
	_target["upper_arm_L"] = _rot(12.0 - arm_swing * pace * sin(_walk_phase), 0.0, -4.0)
	_target["upper_arm_R"] = _rot(12.0 + arm_swing * pace * sin(_walk_phase), 0.0, 4.0)


## Floating free: limbs loose and bent, drifting slowly; thrust leans the body against it.
## Backing off or braking swings the legs forward and leans back, a strafe leans into it
## with the legs trailing, thrusting down tucks the knees up.
func _float_pose() -> void:
	var d1 := sin(_time * 0.7) * drift
	var d2 := sin(_time * 0.53 + 1.3) * drift
	_arms(26.0 + d2, 22.0 + d1, 38.0 + d2)
	var back := clampf(motion.z, 0.0, 1.0)
	var side := clampf(motion.x, -1.0, 1.0)
	var down := clampf(-motion.y, 0.0, 1.0)
	for leg in ["L", "R"]:
		var s := -1.0 if leg == "L" else 1.0
		_target["thigh_" + leg] = _rot(14.0 + d1 + 50.0 * back + 40.0 * down, 0.0, s * 7.0 - strafe_lean * side)
		_target["shin_" + leg] = _rot(-30.0 - d2 - 25.0 * back - 50.0 * down)
		_target["foot_" + leg] = _rot(18.0)
	_target["spine"] = _rot(6.0 + brake_lean * back, 0.0, -strafe_lean * 0.7 * side)


## The glide: the whole body lies out along the thrust (the joints' root turns about the
## eye, as the rig's capsule does), the head turned back up to look ahead, the legs
## trailing straight with the toes pointed, the free arm down by the side (reaching
## forward it filled your own first-person view: playtest, 25 Oct).
func _glide_pose() -> void:
	var up := glide_angle * glide_head_up * glide
	_target["neck"] = _rot(up * 0.4)
	_target["head"] = _rot(up * 0.6)
	_target["spine"] = _rot(8.0, 0.0, -strafe_lean * 0.7 * clampf(motion.x, -1.0, 1.0))
	_arms(10.0, 30.0, 30.0)
	_target["upper_arm_L"] = _rot(-25.0, 0.0, -14.0)  # along the body (if it carries nothing)
	_target["forearm_L"] = _rot(10.0)
	_target["upper_arm_R"] = _rot(-25.0, 0.0, 14.0)   # along the body (if no tool in it)
	_target["forearm_R"] = _rot(10.0)
	for leg in ["L", "R"]:
		var s := -1.0 if leg == "L" else 1.0
		_target["thigh_" + leg] = _rot(-6.0, 0.0, s * 3.0 - strafe_lean * clampf(motion.x, -1.0, 1.0))
		_target["shin_" + leg] = _rot(-12.0)
		_target["foot_" + leg] = _rot(-55.0)


## Arms: out from the side `out` degrees, upper arms forward `fwd`, elbows bent `bend`.
func _arms(out: float, fwd: float, bend: float) -> void:
	_target["upper_arm_L"] = _rot(fwd, 0.0, -out)
	_target["upper_arm_R"] = _rot(fwd, 0.0, out)
	_target["forearm_L"] = _rot(bend)
	_target["forearm_R"] = _rot(bend)
	_target["fingers_L"] = _curl(25.0)
	_target["fingers_R"] = _curl(25.0)


## Two-bone leg IK in the pelvis's plane: the thigh and shin turn (about X) so the ankle
## reaches `ankle` (model space), the knee forward, the foot kept flat to the model.
func _leg_ik(side: String, ankle: Vector3) -> void:
	var a: float = (BONES_REST["shin_" + side] - BONES_REST["thigh_" + side]).length()
	var b: float = (BONES_REST["foot_" + side] - BONES_REST["shin_" + side]).length()
	var pelvis_rot: Quaternion = _target["pelvis"]
	var pelvis_at: Vector3 = BONES_REST["pelvis"] + _target_pelvis
	var hip: Vector3 = pelvis_at + pelvis_rot * (BONES_REST["thigh_" + side] - BONES_REST["pelvis"])
	var v := pelvis_rot.inverse() * (ankle - hip)
	var d := clampf(Vector2(v.y, v.z).length(), absf(a - b) + 0.01, a + b - 0.001)
	var phi := atan2(-v.z, -v.y)
	var alpha := acos(clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0))
	var beta := acos(clampf((a * a + b * b - d * d) / (2.0 * a * b), -1.0, 1.0))
	var thigh := phi + alpha
	var knee := -(PI - beta)
	_target["thigh_" + side] = Quaternion(Vector3.RIGHT, thigh)
	_target["shin_" + side] = Quaternion(Vector3.RIGHT, knee)
	var tilt := pelvis_rot.get_euler().x
	_target["foot_" + side] = Quaternion(Vector3.RIGHT, -(tilt + thigh + knee))


func _ease_pose(delta: float) -> void:
	if joints.is_empty():
		return
	# A stride moves faster than a change of pose: walking, the joints follow it closely.
	var k := 1.0 - exp(-(pose_rate * 3.5 if pose == "walk" else pose_rate) * delta)
	for b: Array in BONES:
		var j := joints[b[0]] as Node3D
		var want: Quaternion = _target.get(b[0], Quaternion.IDENTITY)
		if b[0] == "neck" or b[0] == "head":
			# The look round (seated) and up or down, shared between the neck and the helmet.
			var share := 0.4 if b[0] == "neck" else 0.6
			want = want * Quaternion(Vector3.UP, _head_turn.x * share) \
					* Quaternion(Vector3.RIGHT, (_look_pitch * look_follow + _head_turn.y) * share)
		j.quaternion = j.quaternion.slerp(want, k)
	var pelvis := joints["pelvis"] as Node3D
	pelvis.position = pelvis.position.lerp(BONES_REST["pelvis"] + _target_pelvis, k)
	# The glide lays the whole figure out about the eye (the rig's glide is eased already).
	var turn := Basis(Vector3.RIGHT, -deg_to_rad(glide_angle) * glide)
	var eye := Vector3(0.0, EYE, 0.0)
	(get_node("Joints") as Node3D).transform = Transform3D(turn, eye - turn * eye)


## The figure's head turn (radians, x yaw + left, y pitch + up) for a look from the seat
## (`JetRig.seat_look`): `look_follow` of it, held within `head_turn_limit` to each side and
## `head_up_limit`/`head_down_limit`, so a look over the shoulder stops where a neck would.
func head_turn(look: Vector2) -> Vector2:
	var yaw := wrapf(look.x, -PI, PI) * look_follow
	var pitch := look.y * look_follow
	return Vector2(clampf(yaw, -deg_to_rad(head_turn_limit), deg_to_rad(head_turn_limit)),
			clampf(pitch, -deg_to_rad(head_down_limit), deg_to_rad(head_up_limit)))


## The head's turn now (radians, x yaw, y pitch): what the pose eases the neck and helmet to.
func head_turn_now() -> Vector2:
	return _head_turn


## Degrees about X (pitch forward), Y, Z (out to the side) to a quaternion.
static func _rot(x: float, y: float = 0.0, z: float = 0.0) -> Quaternion:
	return Quaternion.from_euler(Vector3(deg_to_rad(x), deg_to_rad(y), deg_to_rad(z)))


## A finger joint's turn for `deg` of curl towards the palm. The palm is the hand's +Z face at
## rest: to the rear with the arm hanging, down with the hand on a console, the thumb on the
## body's side (Dan, 12 Nov: the hands were palm up with the thumbs on the wrong side).
static func _curl(deg: float) -> Quaternion:
	return _rot(-deg)


func _head_in_model() -> Vector3:
	return _chain(joints["head"] as Node3D).origin


## A joint's transform in the model's space, walked up its parents (works out of the tree).
func _chain(j: Node3D) -> Transform3D:
	var t := j.transform
	var p := j.get_parent() as Node3D
	while p != null and p != self:
		t = p.transform * t
		p = p.get_parent() as Node3D
	return t


# --- The joints and the suit ----------------------------------------------------------------

## Rest positions by joint name (model space).
static var BONES_REST: Dictionary = _rest_table()


static func _rest_table() -> Dictionary:
	var out := {}
	for b: Array in BONES:
		out[b[0]] = b[2]
	return out


func _build_joints() -> void:
	var root := Node3D.new()
	root.name = "Joints"
	add_child(root)
	for b: Array in BONES:
		var j := Node3D.new()
		j.name = String(b[0])
		var parent: Node3D = root if b[1] == "" else joints[b[1]]
		var parent_rest: Vector3 = Vector3.ZERO if b[1] == "" else BONES_REST[b[1]]
		j.position = (b[2] as Vector3) - parent_rest
		parent.add_child(j)
		joints[b[0]] = j


## The suit, slot by slot on its joints (each part in its joint's space: the joint at the
## origin), from `look`. Variants change meshes, never the joints (AVATAR_PLAN.md 9.12), so
## the poses, the hands on the tools and the soles on the floor hold for every look.
func _build_suit() -> void:
	exo = bool(look["exo"])
	_make_materials()
	_asset_finish = YardSuitAssets.finish(look)
	_asset_finish.set_shader_parameter("accent", accent)
	_build_helmet(String(look["helmet"]))
	var asset_torso := _asset_slot("torso")
	if not asset_torso:
		# Neck ring.
		_into = joints["neck"]
		_cylinder(0.12, 0.07, Vector3(0, 0.0, 0), Vector3.ZERO, _frame)
		_build_torso(String(look["torso"]))
		# Waist bellows: ribbed fabric.
		_into = joints["spine"]
		_ribbed(Vector3(0, 0.03, 0), Vector3(0, -0.13, 0), 0.15, _fabric, 3)
		# Hips: a hip shell and the frame's belt.
		_into = joints["pelvis"]
		_box(Vector3(0.36, 0.14, 0.24), Vector3(0, -0.04, 0.0), _shell)
		_box(Vector3(0.4, 0.05, 0.27), Vector3(0, 0.03, 0.0), _frame)        # hip belt
	_build_pack(String(look["pack"]))
	_build_beacon()
	for side: float in [-1.0, 1.0]:
		var s := "L" if side < 0.0 else "R"
		_build_shoulder(s, side, String(look["shoulders"]))
		_into = joints["forearm_" + s]
		_sphere(0.06, Vector3.ZERO, Vector3.ONE, _fabric)                 # elbow
		_build_gauntlet(s, side, String(look["gauntlets"]))
		if YardSuitAssets.is_design(String(look["gauntlets"])):
			_asset_pieces("hands", "hands", s)
		else:
			# Gloves: palm, a mitten of fingers, a thumb.
			_into = joints["hand_" + s]
			_box(Vector3(0.07, 0.09, 0.035), Vector3(0, -0.045, 0), _rubber)
			_into = joints["fingers_" + s]
			_box(Vector3(0.065, 0.07, 0.03), Vector3(0, -0.035, 0), _rubber)
			_into = joints["thumb_" + s]
			_box(Vector3(0.025, 0.05, 0.025), Vector3(0, -0.02, -0.005), _rubber)
		if not asset_torso:
			# Legs: ribbed thighs with a plate, knee pads.
			_into = joints["thigh_" + s]
			_ribbed(Vector3(0, -0.02, 0), Vector3(0, -0.38, 0), 0.085, _fabric, 4)
			_box(Vector3(0.12, 0.18, 0.04), Vector3(0, -0.18, -0.08), _shell)
			_into = joints["shin_" + s]
			_sphere(0.075, Vector3.ZERO, Vector3.ONE, _fabric)
			_box(Vector3(0.12, 0.11, 0.05), Vector3(0, 0.0, -0.075), _trim)   # knee pad
		_build_boot(s, String(look["boots"]))
	_build_exo()
	for part in _exo_parts:
		part.visible = exo
	_build_plate()
	_build_badge()
	_merge_shadows()
	_into = self


## Each joint's suit pieces (and each group's: the pack, the exo frame's) cast one shadow
## between them, a shadow-only mesh "SuitShadow" on the joint; the pieces cast none. A figure
## was ~83 draws in every shadow pass that saw it (the sun's four cascades, each lamp's faces:
## your own body and each crewmate's, ~500 draws inside a lit wreck), now ~27. The pieces are
## still drawn as they were. Labels cast nothing.
func _merge_shadows() -> void:
	var holders: Dictionary = {}   # Node3D -> [MeshInstance3D]
	for n in _suit_nodes:
		if not is_instance_valid(n):
			continue
		if n is Label3D:
			(n as Label3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue
		var mi := n as MeshInstance3D
		if mi == null or not mi.mesh is PrimitiveMesh \
				or mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			continue   # (an odd mesh keeps its own shadow: reading it back would stall the GPU)
		var holder := mi.get_parent() as Node3D
		if not holders.has(holder):
			holders[holder] = []
		(holders[holder] as Array).append(mi)
	if _shadow_mat == null:
		_shadow_mat = StandardMaterial3D.new()
	for holder: Node3D in holders:
		var pieces: Array = holders[holder]
		var proxy := MeshInstance3D.new()
		proxy.name = "SuitShadow"
		proxy.mesh = _shadow_mesh(pieces)
		proxy.material_override = _shadow_mat
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		holder.add_child(proxy)
		_suit_nodes.append(proxy)
		for mi: MeshInstance3D in pieces:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.set_meta(SHADOW_MERGED, true)


## The pieces' meshes (primitives, made on the CPU) as one surface in their holder's space.
static func _shadow_mesh(pieces: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var index := PackedInt32Array()
	for mi: MeshInstance3D in pieces:
		var arrays: Array = (mi.mesh as PrimitiveMesh).get_mesh_arrays()
		var xf := mi.transform
		var turn := xf.basis.inverse().transposed()
		var base := verts.size()
		var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in vs.size():
			verts.append(xf * vs[i])
			norms.append((turn * ns[i]).normalized() if i < ns.size() else Vector3.UP)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			for i in vs.size():
				index.append(base + i)
		else:
			for i in idx:
				index.append(base + i)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = norms
	out[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return mesh


## The suit's paints for this look: hard plates in the primary, trim in the secondary, all
## on the salvage surface shader with the look's wear (shared between figures, `_paint`);
## the accent and the visor glow, so they stay plain materials.
func _make_materials() -> void:
	var wear: float = YardSuitLook.WEAR_LEVELS[int(look["wear"])]
	_shell = _paint(YardSuitLook.PRIMARY[int(look["primary"])], 0.1, 0.55, wear)
	_trim = _paint(YardSuitLook.SECONDARY[int(look["secondary"])], 0.3, 0.45, wear)
	_fabric = _paint(FABRIC, 0.0, 0.9, wear)
	_rubber = _paint(RUBBER, 0.0, 0.8, wear)
	_frame = _paint(FRAME, 0.75, 0.4, wear)
	_accent = _mat(accent, 0.35, 0.45)
	_accent.emission_enabled = true
	_accent.emission = accent
	_accent.emission_energy_multiplier = 0.45
	_o2 = _mat(accent, 0.35, 0.45)
	_o2.emission_enabled = true
	_o2.emission = accent
	_o2.emission_energy_multiplier = 0.45
	o2_level = Air.FINE
	_o2_lit = true
	match String(look["visor"]):
		"gold":
			# Metal reflects black space, so the tint glows a little of its own to read.
			_visor = _mat(Color(0.85, 0.62, 0.2), 0.7, 0.18)
			_visor.emission = Color(0.55, 0.36, 0.07)
		"mirror":
			_visor = _mat(Color(0.85, 0.88, 0.92), 0.9, 0.05)
			_visor.emission = Color(0.36, 0.41, 0.48)
		"dark":
			_visor = _mat(Color(0.05, 0.07, 0.09), 0.9, 0.06)
			_visor.emission = accent.darkened(0.6)
		_:
			var coat: Dictionary = YardSuitLook.VISORS[String(look["visor"])]
			_visor = _mat(coat["tint"], coat["mirror"], coat["roughness"])
			_visor.emission = (coat["tint"] as Color) * 0.6
	_visor.emission_enabled = true
	_visor.emission_energy_multiplier = 0.4
	_visor_glass = YardSuitAssets.visor(String(look["visor"]), accent)


## Paints already made, by colour, shine and wear: a crew of four in the same livery share
## them, and a palette is small, so this stays a few dozen materials.
static var _paints: Dictionary = {}


## A plain paint on the salvage surface shader (ShipSurface: paint, brushed steel where
## metallic, upholstery where it's cloth), worn `wear` (the shader's condition: grime in
## the recesses, chipped edges).
static func _paint(color: Color, metallic: float, roughness: float, wear: float) -> Material:
	var key := "%s/%.2f/%.2f/%.2f" % [color.to_html(), metallic, roughness, wear]
	if _paints.has(key):
		return _paints[key]
	var surface := ShipSurface.of(_mat(color, metallic, roughness))
	var m: Material = surface
	if surface is ShaderMaterial:
		var sm := SurfaceFinish.copy_surface(surface as ShaderMaterial)   # duplicate() loses the colour
		sm.set_shader_parameter("condition", Vector4(wear, 0.0, 0.0, 0.37))
		sm.set_shader_parameter("albedo", Vector3(color.r, color.g, color.b))
		m = sm
	_paints[key] = m
	return m


## Helmets: the round dome, the squared welder's with a flip-up shade and a chin vent, the
## Belter's low half-dome with a wide visor band and cheek pods. All with the visor rim in
## the accent, inside the capsule's top (0.55 m over the rig's centre).
func _build_helmet(variant: String) -> void:
	if _asset_slot("helmet"):
		return
	_into = joints["head"]
	match variant:
		"welder":
			_box(Vector3(0.31, 0.29, 0.33), Vector3(0, 0.07, 0.0), _shell)
			_box(Vector3(0.33, 0.04, 0.35), Vector3(0, 0.2, 0.0), _trim)              # crown band
			_box(Vector3(0.26, 0.15, 0.012), Vector3(0, 0.07, -0.168), _accent)       # visor rim
			_visor_meshes.append(_box(Vector3(0.23, 0.12, 0.02), Vector3(0, 0.07, -0.172), _visor))
			var shade := _box(Vector3(0.27, 0.06, 0.025), Vector3(0, 0.175, -0.175), _trim)
			shade.rotation = Vector3(-0.45, 0, 0)                                    # flipped up
			_box(Vector3(0.15, 0.06, 0.04), Vector3(0, -0.04, -0.155), _frame)        # chin vent
			for x: float in [-0.04, 0.0, 0.04]:
				_box(Vector3(0.012, 0.045, 0.01), Vector3(x, -0.04, -0.178), _rubber)
			for x: float in [-0.165, 0.165]:
				_cylinder(0.04, 0.03, Vector3(x, 0.06, 0.0), Vector3(0, 0, PI * 0.5), _trim)
		"belter":
			_sphere(0.17, Vector3(0, 0.06, 0.01), Vector3(1.05, 0.82, 1.05), _shell)
			# The visor: a wide band wrapping round the front in three facets, on an accent rim.
			_box(Vector3(0.18, 0.095, 0.012), Vector3(0, 0.05, -0.163), _accent)
			_visor_meshes.append(_box(Vector3(0.16, 0.075, 0.02), Vector3(0, 0.05, -0.17), _visor))
			for x: float in [-1.0, 1.0]:
				var rim := _box(Vector3(0.11, 0.095, 0.012), Vector3(x * 0.118, 0.05, -0.128), _accent)
				rim.rotation = Vector3(0, -x * 0.75, 0)
				var pane := _box(Vector3(0.095, 0.075, 0.02), Vector3(x * 0.123, 0.05, -0.134), _visor)
				pane.rotation = Vector3(0, -x * 0.75, 0)
				_visor_meshes.append(pane)
			_box(Vector3(0.035, 0.03, 0.27), Vector3(0, 0.19, 0.02), _trim)           # crest
			for x: float in [-0.155, 0.155]:
				_box(Vector3(0.06, 0.1, 0.11), Vector3(x, -0.02, -0.04), _trim)        # cheek pods
				_cylinder(0.025, 0.012, Vector3(x * 1.2, -0.02, -0.04), Vector3(0, 0, PI * 0.5), _rubber)
			_box(Vector3(0.18, 0.05, 0.05), Vector3(0, -0.07, -0.1), _frame)          # breather
		_:   # "dome"
			_sphere(0.175, Vector3(0, 0.07, 0.005), Vector3(1.0, 1.0, 1.02), _shell)
			_visor_meshes.append(_sphere(0.16, Vector3(0, 0.06, -0.1), Vector3(0.9, 0.72, 0.55), _visor))
			_torus(0.135, 0.012, Vector3(0, 0.06, -0.13), Vector3(PI * 0.5, 0, 0), Vector3(0.98, 0.8, 1.0), _accent)
			_box(Vector3(0.05, 0.1, 0.06), Vector3(0.17, 0.06, 0.02), _trim)   # ear pods
			_box(Vector3(0.05, 0.1, 0.06), Vector3(-0.17, 0.06, 0.02), _trim)
	if not _own_body:
		# The lamp housing where the rig's lamp really is (the beam and lens hang on that), out
		# ahead of the helmet on a bracket from its brow: clear of the shell, which would shadow it.
		var housing := _box(Vector3(0.08, 0.05, 0.08), lamp_mount, _frame)
		housing.name = "LampHousing"
		housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var back := -0.1   # inside every helmet's shell
		var arm := _box(Vector3(0.025, 0.02, absf(lamp_mount.z - back)), Vector3(lamp_mount.x, lamp_mount.y,
				(lamp_mount.z + back) * 0.5), _frame)
		arm.name = "LampBracket"
		arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Hard upper torsos: the plain shell with a chest panel and a lit strip; one with bolted
## plates and a cross strap; a rigger's with pouches, webbing and a tool loop. The chest
## panel (where the name plate goes) is in the same place on all three.
func _build_torso(variant: String) -> void:
	_into = joints["chest"]
	_box(Vector3(0.42, 0.34, 0.27), Vector3(0, 0.0, 0.0), _shell)
	_box(Vector3(0.44, 0.06, 0.29), Vector3(0, 0.15, 0.0), _trim)        # collar
	match variant:
		"plated":
			var strap := _box(Vector3(0.05, 0.46, 0.02), Vector3(0, -0.01, -0.143), _rubber)
			strap.rotation = Vector3(0, 0, 0.62)                            # the cross strap
			strap = _box(Vector3(0.05, 0.46, 0.02), Vector3(0, -0.01, -0.141), _rubber)
			strap.rotation = Vector3(0, 0, -0.62)
			for x: float in [-1.0, 1.0]:
				_box(Vector3(0.03, 0.27, 0.23), Vector3(x * 0.212, -0.01, 0.0), _shell)   # side plates
				for y: float in [-0.1, 0.08]:
					_cylinder(0.009, 0.012, Vector3(x * 0.229, y, -0.08), Vector3(0, 0, PI * 0.5), _frame)
			_box(Vector3(0.3, 0.07, 0.03), Vector3(0, -0.135, -0.148), _trim)    # belly plate
			_box(Vector3(0.24, 0.14, 0.03), Vector3(0, 0.02, -0.15), _trim)      # chest panel
			_box(Vector3(0.025, 0.12, 0.012), Vector3(-0.1, 0.02, -0.167), _accent)
		"rigger":
			for x: float in [-0.105, 0.105]:
				_box(Vector3(0.035, 0.34, 0.012), Vector3(x, 0.0, -0.141), _rubber)       # webbing
			for x: float in [-0.165, 0.165]:
				for y: float in [-0.08, 0.03]:
					_box(Vector3(0.075, 0.085, 0.05), Vector3(x, y, -0.15), _trim)     # pouches
					_box(Vector3(0.077, 0.025, 0.052), Vector3(x, y + 0.035, -0.15), _rubber)
			_box(Vector3(0.18, 0.13, 0.03), Vector3(0, 0.02, -0.15), _trim)      # chest panel
			_box(Vector3(0.14, 0.02, 0.012), Vector3(0, 0.068, -0.167), _accent)
			_torus(0.03, 0.006, Vector3(0.07, -0.135, -0.155), Vector3(0, 0, 0), Vector3.ONE, _frame)   # tool loop
		_:   # "shell"
			_box(Vector3(0.3, 0.16, 0.03), Vector3(0, 0.02, -0.145), _trim)      # chest panel
			_box(Vector3(0.16, 0.025, 0.012), Vector3(0, 0.07, -0.162), _accent)


## Packs: the jet-rig (four jets at its corners), a slim pack with two, a heavy one with four
## tanks and guarded jets (no deeper than the jet-rig). All carry the O2 and fuel strip.
func _build_pack(variant: String) -> void:
	_pack_parts = Node3D.new()
	_pack_parts.name = "PackParts"
	joints["pack"].add_child(_pack_parts)
	_suit_nodes.append(_pack_parts)
	if _asset_slot("pack"):
		return
	_into = _pack_parts
	var jets: Array[Vector2] = []
	match variant:
		"slim":
			_box(Vector3(0.26, 0.4, 0.11), Vector3(0, -0.02, -0.02), _shell)
			_box(Vector3(0.28, 0.05, 0.13), Vector3(0, 0.155, -0.02), _trim)
			_box(Vector3(0.04, 0.46, 0.05), Vector3(0, -0.04, -0.07), _frame)
			_box(Vector3(0.03, 0.24, 0.012), Vector3(-0.05, -0.03, 0.041), _o2)       # O2 strip
			_box(Vector3(0.03, 0.24, 0.012), Vector3(0.05, -0.03, 0.041), _trim)
			for x: float in [-0.09, 0.09]:
				_cylinder(0.035, 0.07, Vector3(x, -0.2, 0.06), Vector3(PI * 0.5, 0, 0), _frame)
				_cylinder(0.04, 0.015, Vector3(x, -0.2, 0.1), Vector3(PI * 0.5, 0, 0), _rubber)
		"heavy":
			_box(Vector3(0.36, 0.44, 0.1), Vector3(0, -0.02, -0.02), _shell)
			_box(Vector3(0.38, 0.06, 0.13), Vector3(0, 0.18, -0.005), _trim)
			_box(Vector3(0.04, 0.5, 0.05), Vector3(0, -0.04, -0.07), _frame)
			for x: float in [-0.13, -0.045, 0.045, 0.13]:
				_cylinder(0.042, 0.34, Vector3(x, -0.02, 0.07), Vector3.ZERO, _trim if absf(x) > 0.1 else _shell)
				_torus(0.044, 0.005, Vector3(x, 0.08, 0.07), Vector3.ZERO, Vector3.ONE, _frame)
				_torus(0.044, 0.005, Vector3(x, -0.12, 0.07), Vector3.ZERO, Vector3.ONE, _frame)
			_box(Vector3(0.03, 0.26, 0.012), Vector3(-0.0, -0.02, 0.118), _o2)        # O2 strip
			for x: float in [-0.15, 0.15]:
				for y: float in [0.13, -0.22]:
					_cylinder(0.035, 0.06, Vector3(x, y, 0.06), Vector3(PI * 0.5, 0, 0), _frame)
					_torus(0.05, 0.007, Vector3(x, y, 0.1), Vector3(PI * 0.5, 0, 0), Vector3.ONE, _rubber)   # guard
		_:   # "rig"
			_box(Vector3(0.32, 0.44, 0.15), Vector3(0, -0.02, 0.0), _shell)
			_box(Vector3(0.34, 0.06, 0.17), Vector3(0, 0.17, 0.0), _trim)
			_box(Vector3(0.04, 0.5, 0.05), Vector3(0, -0.04, -0.07), _frame)     # spine rail
			_box(Vector3(0.03, 0.26, 0.012), Vector3(-0.06, -0.04, 0.081), _o2)       # O2 strip
			_box(Vector3(0.03, 0.26, 0.012), Vector3(0.06, -0.04, 0.081), _trim)      # fuel strip
			for x: float in [-0.14, 0.14]:
				for y: float in [0.14, -0.2]:
					jets.append(Vector2(x, y))
	for j in jets:
		_cylinder(0.04, 0.08, Vector3(j.x, j.y, 0.09), Vector3(PI * 0.5, 0, 0), _frame)
		_cylinder(0.045, 0.015, Vector3(j.x, j.y, 0.135), Vector3(PI * 0.5, 0, 0), _rubber)


## The beacon (TW13): a small strobe dome on top of the pack in the accent, dark till it's on, and
## its light (no shadow; left out of the suit's merged shadow).
func _build_beacon() -> void:
	_into = _pack_parts if _pack_parts else joints["pack"]   # off with the pack while seated
	_beacon_mat = _mat(accent.lightened(0.2), 0.2, 0.35)
	_beacon_mat.emission_enabled = true
	_beacon_mat.emission = accent.lightened(0.2)
	_beacon_mat.emission_energy_multiplier = 0.0
	var dome := _cylinder(0.026, 0.04, Vector3(0, 0.225, 0.02), Vector3.ZERO, _beacon_mat)
	dome.name = "Beacon"
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon_lamp = OmniLight3D.new()
	_beacon_lamp.name = "BeaconLight"
	_beacon_lamp.position = Vector3(0, 0.27, 0.06)
	_beacon_lamp.light_color = accent.lightened(0.2)
	_beacon_lamp.light_energy = 0.0
	_beacon_lamp.omni_range = 25.0
	_beacon_lamp.shadow_enabled = false
	_beacon_lamp.set_meta("gfx_fixed", true)
	_beacon_lamp.visible = false
	joints["pack"].add_child(_beacon_lamp)
	_suit_nodes.append(_beacon_lamp)
	if _own_body:
		return
	# (VX11) The distress point: a red dot over the beacon, the same size on screen at any range,
	# drawn toward the eye so her own helmet never hides it (shaders/distress_point.gdshader).
	_distress_mat = ShaderMaterial.new()
	_distress_mat.shader = DISTRESS_SHADER
	_distress_mat.set_shader_parameter("colour", DISTRESS_RED)
	_distress_mat.set_shader_parameter("size", distress_point_size)
	var quad := QuadMesh.new()
	_distress_point = MeshInstance3D.new()
	_distress_point.name = "DistressPoint"
	_distress_point.mesh = quad
	_distress_point.material_override = _distress_mat
	_distress_point.position = Vector3(0, 0.27, 0.03)
	_distress_point.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_distress_point.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_distress_point.extra_cull_margin = 1.0   # the shader draws it up to `pull` off its place
	_distress_point.visibility_range_begin = distress_point_from
	_distress_point.visibility_range_end = distress_range
	_distress_point.visible = false
	joints["pack"].add_child(_distress_point)
	_suit_nodes.append(_distress_point)


## (VX11) The downed look's pulse: the accent strip toward red, the far point blinking with the
## beacon; put back to the accent as she comes round.
func _flash_distress() -> void:
	var on := distress_on()
	if not on and not _distress_shown:
		return
	_distress_shown = on
	var t := Time.get_ticks_msec() / 1000.0
	var p := 0.5 + 0.5 * sin(t * TAU * distress_hz) if on else 0.0
	if _accent:
		var c := accent.lerp(DISTRESS_RED, p) if on else accent
		_accent.albedo_color = c
		_accent.emission = c
		_accent.emission_energy_multiplier = lerpf(0.45, 2.6, p) if on else 0.45
	if _distress_point and is_instance_valid(_distress_point):
		_distress_point.visible = on and beacon_flash_lit


## Shoulders and sleeves: round caps in the accent, squared pauldrons, or bare ribbed
## sleeves with an accent band. The ribbed upper arm is there under all three.
func _build_shoulder(s: String, side: float, variant: String) -> void:
	if _asset_slot("shoulders", s):
		return
	_into = joints["upper_arm_" + s]
	match variant:
		"square":
			_box(Vector3(0.15, 0.075, 0.17), Vector3(side * 0.02, 0.015, 0.0), _accent)
			_box(Vector3(0.155, 0.02, 0.175), Vector3(side * 0.02, -0.03, 0.0), _trim)
			_box(Vector3(0.02, 0.07, 0.15), Vector3(side * 0.095, -0.045, 0.0), _shell)
		"none":
			_sphere(0.07, Vector3(side * 0.005, 0.0, 0.0), Vector3(1.0, 0.9, 1.0), _fabric)
			_torus(0.062, 0.01, Vector3(side * 0.008, -0.07, 0.0), Vector3.ZERO, Vector3.ONE, _accent)
		_:   # "caps"
			_sphere(0.09, Vector3(side * 0.01, 0.0, 0.0), Vector3(1.1, 0.8, 1.1), _accent)
	_ribbed(Vector3(side * 0.005, -0.04, 0), Vector3(side * 0.02, -0.26, 0), 0.06, _fabric, 3)


## Gauntlets on the forearms (they show in first person): the standard cylinder with a
## wrist pad and cuff; a heavy one with knuckle plates on the glove; a short one with a wide
## rubber cuff.
func _build_gauntlet(s: String, side: float, variant: String) -> void:
	if _asset_slot("gauntlets", s):
		return
	_into = joints["forearm_" + s]
	match variant:
		"heavy":
			_cylinder(0.07, 0.21, Vector3(side * 0.005, -0.125, 0), Vector3.ZERO, _shell)
			_box(Vector3(0.06, 0.12, 0.025), Vector3(side * 0.012, -0.12, -0.07), _trim)
			_box(Vector3(0.025, 0.14, 0.05), Vector3(side * 0.07, -0.13, 0.0), _trim)
			_cylinder(0.075, 0.035, Vector3(side * 0.008, -0.235, 0), Vector3.ZERO, _rubber)
			_into = joints["hand_" + s]
			_box(Vector3(0.012, 0.045, 0.05), Vector3(side * 0.041, -0.06, 0.0), _frame)   # knuckle plate
		"cuffed":
			_cylinder(0.06, 0.12, Vector3(side * 0.005, -0.1, 0), Vector3.ZERO, _shell)
			_box(Vector3(0.05, 0.07, 0.02), Vector3(side * 0.01, -0.1, -0.06), _trim)
			_cylinder(0.08, 0.075, Vector3(side * 0.008, -0.2, 0), Vector3.ZERO, _rubber)   # the cuff
			_torus(0.079, 0.006, Vector3(side * 0.008, -0.165, 0), Vector3.ZERO, Vector3.ONE, _accent)
		_:   # "std"
			_cylinder(0.062, 0.2, Vector3(side * 0.005, -0.13, 0), Vector3.ZERO, _shell)    # gauntlet
			_box(Vector3(0.05, 0.09, 0.02), Vector3(side * 0.012, -0.12, -0.062), _trim)    # wrist pad
			_cylinder(0.067, 0.03, Vector3(side * 0.008, -0.235, 0), Vector3.ZERO, _rubber) # cuff


## Boots: the chunky mag boot under a shin guard; a heavier one with a toe cap; a tall boot
## with the shin guard part of it. Every sole is the same mag sole on the floor.
func _build_boot(s: String, variant: String) -> void:
	if _asset_slot("boots", s):
		return
	_into = joints["shin_" + s]
	if variant == "tall":
		_cylinder(0.074, 0.29, Vector3(0, -0.15, 0), Vector3.ZERO, _rubber)            # boot shaft
		for y: float in [-0.06, -0.2]:
			_box(Vector3(0.155, 0.025, 0.155), Vector3(0, y, 0), _trim)                 # buckles
	else:
		_cylinder(0.07, 0.24, Vector3(0, -0.16, 0), Vector3.ZERO, _shell)  # shin guard
	_into = joints["foot_" + s]
	if variant == "heavy":
		_box(Vector3(0.13, 0.11, 0.21), Vector3(0, -0.035, -0.025), _rubber)
		_box(Vector3(0.135, 0.03, 0.2), Vector3(0, 0.015, -0.02), _trim)                # ankle band
	else:
		_box(Vector3(0.12, 0.1, 0.2), Vector3(0, -0.04, -0.03), _rubber)    # boot
	_box(Vector3(0.13, 0.025, 0.22), Vector3(0, -0.087, -0.03), _frame) # mag sole
	_box(Vector3(0.1, 0.012, 0.02), Vector3(0, -0.07, -0.133), _accent) # sole light
	_into = joints["toe_" + s]
	if variant == "heavy":
		_box(Vector3(0.13, 0.075, 0.08), Vector3(0, 0.0, -0.01), _frame)               # toe cap
	else:
		_box(Vector3(0.12, 0.07, 0.07), Vector3(0, 0.0, -0.01), _rubber)


## The exo frame (an upgrade, AVATAR_PLAN.md 9.7; shown when the look says and the player
## owns it): a powered frame over the suit, in steel with motor hubs at the hips, knees and
## elbows (capped in the accent, so it reads at a distance), a spine bar from the hip belt
## up to the pack, rails down the outside of the legs and arms with rams behind the thighs
## and calves, strapped on with rubber bands. Every hub sits on its joint's pivot line, so the poses bend the
## frame where the suit bends; the forearm rails show in first person. Each group is one
## node in `_exo_parts` (hidden when it's off, and while seated).
func _build_exo() -> void:
	var chrome := _mat(Color(0.78, 0.8, 0.83), 0.9, 0.2)
	var along_x := Vector3(0, 0, PI * 0.5)
	# The hips: a crossbar behind the belt, a link forward each side to a hip motor.
	_exo_group("pelvis", "ExoHips")
	_box(Vector3(0.38, 0.045, 0.035), Vector3(0, -0.05, 0.17), _frame)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(0.035, 0.045, 0.18), Vector3(side * 0.215, -0.05, 0.08), _frame)
		_cylinder(0.055, 0.05, Vector3(side * 0.225, -0.08, 0.0), along_x, _trim)       # hip motor
		_cylinder(0.03, 0.012, Vector3(side * 0.255, -0.08, 0.0), along_x, _accent)
	# The spine bar up the back to the pack, clamped, with a lit lumbar hub.
	_exo_group("spine", "ExoSpine")
	_box(Vector3(0.045, 0.3, 0.035), Vector3(0, -0.07, 0.185), _frame)
	for y: float in [-0.12, -0.02, 0.06]:
		_box(Vector3(0.075, 0.022, 0.03), Vector3(0, y, 0.185), _trim)
	_cylinder(0.026, 0.012, Vector3(0, -0.17, 0.208), Vector3(PI * 0.5, 0, 0), _accent)
	for side: float in [-1.0, 1.0]:
		var s := "L" if side < 0.0 else "R"
		# Thigh: a rail down the outside from the hip motor, a ram behind it, two straps.
		_exo_group("thigh_" + s, "ExoThigh" + s)
		_box(Vector3(0.035, 0.36, 0.03), Vector3(side * 0.12, -0.2, 0.0), _frame)
		_cylinder(0.017, 0.2, Vector3(side * 0.11, -0.13, 0.05), Vector3.ZERO, _frame)   # ram barrel
		_cylinder(0.009, 0.16, Vector3(side * 0.11, -0.3, 0.05), Vector3.ZERO, chrome)   # ram rod
		for y: float in [-0.1, -0.3]:
			_torus(0.096, 0.011, Vector3(0, y, 0), Vector3.ZERO, Vector3.ONE, _rubber)       # strap
			_box(Vector3(0.03, 0.03, 0.03), Vector3(side * 0.1, y, 0.0), _frame)            # its clip
		# Shin: the knee motor on the pivot, a rail down to the ankle hub, a calf ram, a strap.
		_exo_group("shin_" + s, "ExoShin" + s)
		_cylinder(0.05, 0.045, Vector3(side * 0.12, 0.0, 0.0), along_x, _trim)          # knee motor
		_cylinder(0.028, 0.012, Vector3(side * 0.148, 0.0, 0.0), along_x, _accent)
		_box(Vector3(0.032, 0.26, 0.028), Vector3(side * 0.115, -0.15, 0.0), _frame)
		_cylinder(0.015, 0.14, Vector3(side * 0.1, -0.09, 0.06), Vector3.ZERO, _frame)
		_cylinder(0.008, 0.1, Vector3(side * 0.1, -0.2, 0.06), Vector3.ZERO, chrome)
		_torus(0.08, 0.01, Vector3(0, -0.13, 0), Vector3.ZERO, Vector3.ONE, _rubber)
		_box(Vector3(0.03, 0.03, 0.03), Vector3(side * 0.095, -0.13, 0.0), _frame)
		_cylinder(0.03, 0.03, Vector3(side * 0.1, -0.3, 0.0), along_x, _frame)          # ankle hub
		# Foot: a stirrup from the ankle hub down to the mag sole.
		_exo_group("foot_" + s, "ExoFoot" + s)
		_box(Vector3(0.015, 0.075, 0.07), Vector3(side * 0.085, -0.045, -0.01), _frame)
		# Upper arm: a rail down the outside to the elbow motor, two straps.
		_exo_group("upper_arm_" + s, "ExoArm" + s)
		_rod(Vector3(side * 0.08, -0.05, 0.0), Vector3(side * 0.105, -0.27, 0.0), 0.024, _frame)
		for y: float in [-0.12, -0.22]:
			var arm_x := side * lerpf(0.005, 0.02, (-y - 0.04) / 0.22)                       # the sleeve's line
			_torus(0.07, 0.009, Vector3(arm_x, y, 0), Vector3.ZERO, Vector3.ONE, _rubber)
			_box(Vector3(0.03, 0.022, 0.025), Vector3(side * 0.08, y, 0.0), _frame)
		# Forearm (in first person too): the elbow motor on the pivot, a slim rail to a wrist clamp.
		_exo_group("forearm_" + s, "ExoForearm" + s)
		_cylinder(0.035, 0.035, Vector3(side * 0.095, 0.0, 0.0), along_x, _trim)        # elbow motor
		_cylinder(0.02, 0.01, Vector3(side * 0.117, 0.0, 0.0), along_x, _accent)
		_rod(Vector3(side * 0.09, -0.03, 0.0), Vector3(side * 0.088, -0.2, 0.0), 0.022, _frame)
		_box(Vector3(0.03, 0.03, 0.05), Vector3(side * 0.08, -0.21, 0.0), _frame)       # wrist clamp


## A new group of the exo frame's pieces on `joint` (the next shapes go into it).
func _exo_group(joint: String, group_name: String) -> void:
	var group := Node3D.new()
	group.name = group_name
	joints[joint].add_child(group)
	_suit_nodes.append(group)
	_exo_parts.append(group)
	_into = group


## The name plate: the look's text (or the player's name) in capitals on the chest panel,
## in the trim's colour against a dark plate, readable at a couple of metres.
func _build_plate() -> void:
	_into = joints["chest"]
	var text := String(look["plate"])
	if text == "":
		text = YardSuitLook.clean_plate(plate_default)
	var design := YardSuitAssets.is_design(String(look["torso"]))
	var at := YardSuitAssets.anchor(String(look["torso"]), "plate") if design else Vector3(0, -0.03, -0.163)
	_box(Vector3(0.17 if design else 0.2, 0.04 if design else 0.045, 0.006), at, _mat(Color(0.06, 0.065, 0.07), 0.2, 0.6))
	plate = _label(text, at + Vector3(0, 0, -0.0045), Vector3(0, PI, 0), plate_size)
	plate.name = "NamePlate"


## The company badge on the left shoulder (on the sleeve with bare sleeves): a small plate
## with the crew's company initials (`_refresh_badge`).
func _build_badge() -> void:
	_into = joints["upper_arm_L"]
	var x := -0.1
	match String(look["shoulders"]):
		"square":
			x = -0.108
		"none":
			x = -0.072
	var at := Vector3(x, -0.1 if look["shoulders"] == "none" else -0.015, 0.0)
	if YardSuitAssets.is_design(String(look["shoulders"])):
		at = YardSuitAssets.anchor(String(look["shoulders"]), "badge")
	var back := _box(Vector3(0.008, 0.045, 0.07), at, _trim)
	back.name = "BadgePlate"
	badge = _label(_badge_text, at + Vector3(-0.0045, 0, 0), Vector3(0, -PI * 0.5, 0), plate_size * 0.8)
	badge.name = "Badge"
	badge.modulate = YardSuitLook.PRIMARY[int(look["primary"])].lightened(0.2)


## The crew's company initials on the badge: the first letter of each word of the company's
## name (World.company), or its first three letters if it is one word.
func _refresh_badge() -> void:
	var name_now := company_name
	var text := initials(name_now)
	if text != _badge_text:
		_badge_text = text
		if badge:
			badge.text = text


## A company's initials for its badge ("Ola's Salvage Co" -> "OSC", "Kestrel" -> "KES").
static func initials(company_name: String) -> String:
	var letters := ""
	for ch in company_name.to_upper():
		letters += ch if YardSuitLook.PLATE_CHARS.contains(ch) else " "
	var words := letters.split(" ", false)
	if words.is_empty():
		return ""
	if words.size() == 1:
		return words[0].left(3)
	var out := ""
	for w in words:
		out += w[0]
	return out.left(3)


func _label(text: String, pos: Vector3, rot: Vector3, height: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = ShipKit.mono_font()
	l.font_size = 32
	l.pixel_size = height / 32.0
	l.outline_size = 0
	l.modulate = YardSuitLook.SECONDARY[int(look["secondary"])].lightened(0.3)
	l.position = pos
	l.rotation = rot
	l.double_sided = false
	l.shaded = true
	_into.add_child(l)
	_suit_nodes.append(l)
	return l



# --- Shapes ---------------------------------------------------------------------------

## A fabric tube from a to b with `ribs` raised rings along it (the suit's soft joints).
func _ribbed(a: Vector3, b: Vector3, radius: float, mat: Material, ribs: int) -> void:
	var up := (b - a).normalized()
	var basis := _basis_along(up)
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius * 0.92
	m.height = a.distance_to(b)
	m.radial_segments = 10
	m.rings = 1
	var mi := _add(m, (a + b) * 0.5, Vector3.ZERO, Vector3.ONE, mat)
	mi.basis = basis
	for i in ribs:
		var t := (float(i) + 0.5) / float(ribs)
		var ring := TorusMesh.new()
		ring.inner_radius = radius * 0.86
		ring.outer_radius = radius * 1.12
		ring.rings = 10
		ring.ring_segments = 5
		var ri := _add(ring, a.lerp(b, t), Vector3.ZERO, Vector3.ONE, mat)
		ri.basis = basis


## A square bar `thickness` across from a to b.
func _rod(a: Vector3, b: Vector3, thickness: float, mat: Material) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = Vector3(thickness, a.distance_to(b), thickness)
	var mi := _add(m, (a + b) * 0.5, Vector3.ZERO, Vector3.ONE, mat)
	mi.basis = _basis_along((b - a).normalized())
	return mi


static func _basis_along(up: Vector3) -> Basis:
	var side := up.cross(Vector3.FORWARD)
	if side.length() < 0.01:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	return Basis(side, up, side.cross(up))


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _add(m, pos, Vector3.ZERO, Vector3.ONE, mat)


func _cylinder(radius: float, height: float, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 10
	m.rings = 1
	return _add(m, pos, rot, Vector3.ONE, mat)


func _torus(radius: float, thickness: float, pos: Vector3, rot: Vector3, scale_by: Vector3, mat: Material) -> void:
	var m := TorusMesh.new()
	m.inner_radius = radius - thickness
	m.outer_radius = radius + thickness
	m.rings = 16
	m.ring_segments = 6
	_add(m, pos, rot, scale_by, mat)


func _sphere(radius: float, pos: Vector3, scale_by: Vector3, mat: Material) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 12
	m.rings = 6
	return _add(m, pos, Vector3.ZERO, scale_by, mat)


func _add(mesh: Mesh, pos: Vector3, rot: Vector3, scale_by: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scale_by
	_into.add_child(mi)
	_suit_nodes.append(mi)
	return mi


static func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m


## A single palette material per figure; the meshes are shared across the crew.
var _asset_finish: ShaderMaterial


func _asset_slot(slot: String, side: String = "") -> bool:
	var id := String(look[slot])
	if not YardSuitAssets.is_design(id):
		return false
	_asset_pieces(id, slot, side)
	return true


func _asset_pieces(id: String, slot: String, side: String) -> void:
	var pieces := YardSuitAssets.meshes(id)
	for key: String in pieces:
		var fields := key.split("__")
		if fields[0] != slot or (side != "" and not fields[1].ends_with("_" + side)):
			continue
		var pane := fields.size() > 2 and fields[2] == "visor"
		var mi := YardSuitAssets.piece(pieces[key], _visor_glass if pane else _asset_finish, key)
		if pane:
			mi.set_meta("design_pane", true)
		var parent: Node3D = _pack_parts if slot == "pack" else joints[fields[1]]
		parent.add_child(mi)
		_suit_nodes.append(mi)
		if pane:
			_visor_meshes.append(mi)
