class_name GfxBus
extends Node
## Graphics module bus (Modules.bus("graphics")). The game's look: lighting, bounce light,
## reflections, materials, shaders, post-processing and the in-world screen style. The plan
## and its stages G1..G8 are in the "BSX Graphics plan" doc.
##
## Other modules don't call Graphics to get a look; they say what a thing is and Graphics
## restyles it while a stage's flag is on (off, everything keeps the look its owner gave it):
##   - every WorldEnvironment under an AlienSky (group "alien_sky"), or in group "gfx_world",
##     gets the outdoor lighting baseline (G1, flag "graphics.light");
##   - a node in group "gfx_interactable" is something the player can use: it highlights
##     while the pointer is over it within reach ("graphics.hover") and lights up in the
##     pinger's colour when pinged ("graphics.ping", middle mouse). Give it meta "gfx_id"
##     (the same stable data id on every machine, e.g. "trolley:2") so a crewmate's ping
##     finds it; without one a ping lights the usable thing it lands on or beside;
##   - a Node3D in group "gfx_room" with meta "gfx_box" (an AABB, the room's inside in the
##     node's own space) gets a reflection probe and baked bounce light ("graphics.gi").
##     Tag it before adding it to the tree; its meshes bake BAKE_DELAY after it arrives
##     (or call queue_bake again after rebuilding it);
##   - more groups (gfx_lamp, gfx_screen...) arrive with later stages.
##   Example:  unit.add_to_group("gfx_interactable"); unit.set_meta("gfx_id", "unit:3")
## Group names are plain strings, so tagging a node needs no dependency on this module.
##
## Core's Graphics autoload still applies the player's quality options (shadows, GI, AO...)
## first; this module tunes on top of what it set, and again whenever it re-applies them.

signal look_applied(node: Node)
## The usable thing under the pointer changed (null: nothing). Contextual hints can follow it.
signal hovered(target: Node)

## Feature flag of each stage.
const LIGHT := "graphics.light"
const HOVER := "graphics.hover"
const PING := "graphics.ping"
const PROFILER := "graphics.profiler"
const GI := "graphics.gi"
## Group of rooms (halls, the bay) that get their own bounce light and reflections.
const ROOM := "gfx_room"
## Meta on a room: its inside as an AABB in the room node's space.
const BOX_META := "gfx_box"
## Group of things the player can use (highlight on hover, ping targets).
const INTERACTABLE := "gfx_interactable"
## Meta on an interactable: its stable id, the same on every machine.
const ID_META := "gfx_id"
## Group that opts a WorldEnvironment outside an AlienSky into the outdoor baseline.
const WORLD_GROUP := "gfx_world"

const LightBaseline := preload("res://modules/graphics/internal/light_baseline.gd")
const PointerLook := preload("res://modules/graphics/internal/pointer_look.gd")
const Profiler := preload("res://modules/graphics/internal/profiler.gd")
const RoomLight := preload("res://modules/graphics/internal/room_light.gd")
## Seconds after a room appears before its bounce light bakes (its owner may still be
## building it).
const BAKE_DELAY := 0.5

## Hover highlight and pings.
var pointer: Node
## The profiler overlay (null while its flag is off).
var profiler: CanvasLayer
## VoxelGIs waiting to bake, one per frame after BAKE_DELAY: [{gi, at}].
var _bakes: Array[Dictionary] = []
var _sky_hour := -100.0


func register_module() -> void:
	var tree := get_tree()
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)
	var core_gfx := tree.root.get_node_or_null("Graphics")
	if core_gfx and core_gfx.has_signal("changed") and not core_gfx.changed.is_connected(apply_all):
		core_gfx.changed.connect(apply_all)
	apply_all.call_deferred()
	pointer = PointerLook.new()
	pointer.name = "Pointer"
	add_child(pointer)
	pointer.hovered.connect(func(t: Node) -> void: hovered.emit(t))
	pointer.attach_net(Modules.bus("multiplayer"))
	if not Flags.changed.is_connected(_on_flags):
		Flags.changed.connect(_on_flags)
	_on_flags()


func unregister_module() -> void:
	if Keys.has(Profiler.ACTION):
		Keys.unregister(Profiler.ACTION)
	if pointer:
		pointer.detach()
	if Flags.changed.is_connected(_on_flags):
		Flags.changed.disconnect(_on_flags)
	var tree := get_tree()
	if tree == null:
		return
	if tree.node_added.is_connected(_on_node_added):
		tree.node_added.disconnect(_on_node_added)
	var core_gfx := tree.root.get_node_or_null("Graphics")
	if core_gfx and core_gfx.has_signal("changed") and core_gfx.changed.is_connected(apply_all):
		core_gfx.changed.disconnect(apply_all)


## Restyles everything already in the scene (after a settings change, or on load).
func apply_all() -> void:
	if is_inside_tree():
		_walk(get_tree().root)


## Applies the stages that are on to one node, if it is something Graphics styles.
func restyle(n: Node) -> void:
	if not is_instance_valid(n) or not n.is_inside_tree():
		return
	if Flags.is_on(LIGHT):
		if n is WorldEnvironment and is_outdoor(n):
			LightBaseline.apply_environment(n as WorldEnvironment)
			look_applied.emit(n)
		elif n is DirectionalLight3D:
			LightBaseline.apply_sun(n as DirectionalLight3D)
			look_applied.emit(n)
	if n.is_in_group(ROOM) and n is Node3D:
		if Flags.is_on(GI):
			var gi := RoomLight.apply(n as Node3D)
			if gi:
				queue_bake(gi)
			look_applied.emit(n)
	if n.is_in_group("alien_sky") and not n.is_connected("time_changed", _on_sky_time):
		n.connect("time_changed", _on_sky_time)


## The usable thing under the pointer now, or null.
func hover_target() -> Node:
	return pointer.target if pointer else null


## Pings a point (and the usable thing there), as the middle mouse does.
func ping(at: Vector3, thing: Node = null, normal := Vector3.UP) -> void:
	if pointer and Flags.is_on(PING):
		pointer.ping(at, thing, normal)


## True for the yard's environment: one under an AlienSky, or tagged "gfx_world".
static func is_outdoor(n: Node) -> bool:
	var p := n
	while p:
		if p.is_in_group("alien_sky") or p.is_in_group(WORLD_GROUP):
			return true
		p = p.get_parent()
	return false


func _walk(n: Node) -> void:
	restyle(n)
	for c in n.get_children():
		_walk(c)


## Bakes a room's bounce light soon (after BAKE_DELAY, one room per frame).
func queue_bake(gi: VoxelGI) -> void:
	for b in _bakes:
		if b.gi == gi:
			return
	_bakes.append({"gi": gi, "at": Time.get_ticks_msec() / 1000.0 + BAKE_DELAY})


## Rooms whose bounce light is still waiting to bake.
func pending_bakes() -> int:
	return _bakes.size()


func _process(_delta: float) -> void:
	if _bakes.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	for b in _bakes:
		if now >= float(b.at):
			_bakes.erase(b)
			RoomLight.bake(b.gi)
			return


func _on_sky_time(hour: float, _daylight: float) -> void:
	if absf(hour - _sky_hour) < RoomLight.REPROBE_HOURS or not Flags.is_on(GI):
		return
	_sky_hour = hour
	for room in get_tree().get_nodes_in_group(ROOM):
		if room is Node3D:
			RoomLight.reprobe(room as Node3D)


func _on_node_added(n: Node) -> void:
	if n.is_in_group(ROOM) or n.is_in_group("alien_sky"):
		restyle.call_deferred(n)
		return
	if n is WorldEnvironment or n is DirectionalLight3D:
		# Core's Graphics tunes these deferred too; queued after it, so this lands on top.
		restyle.call_deferred(n)


func _on_flags() -> void:
	if pointer:
		pointer.hover_on = Flags.is_on(HOVER)
		pointer.ping_on = Flags.is_on(PING)
		pointer.set_process(pointer.hover_on or pointer.ping_on)
	var want := Flags.is_on(PROFILER)
	if want and profiler == null:
		Keys.register(Profiler.ACTION, "Profiler (frame rate, GPU time)", KEY_F3)
		profiler = Profiler.new()
		add_child(profiler)
	elif not want and profiler:
		profiler.queue_free()
		profiler = null
		Keys.unregister(Profiler.ACTION)
