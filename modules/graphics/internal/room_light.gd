extends RefCounted
## G2, bounce light indoors (flag "graphics.gi"). A room is a Node3D in group "gfx_room"
## with meta "gfx_box" (an AABB in the node's own space: the room's inside). Graphics gives
## each one:
##   - a ReflectionProbe the size of the room, box-projected, so floors and paint reflect
##     the room rather than the sky, and its ambient light comes from the room;
##   - a VoxelGI over the room, baked once the room is built, so light bounces off its
##     floor, walls and machines (it takes over from SDFGI inside the box).
## Both follow the player's options: the probe while reflections or detail are above Low,
## the VoxelGI while global illumination is on at all.

const GROUP := "gfx_room"
const BOX_META := "gfx_box"
const PROBE := "GfxProbe"
const VOXEL := "GfxVoxelGI"
## VoxelGI resolution per GI quality (Low .. Ultra).
const SUBDIV: Array[VoxelGI.Subdiv] = [VoxelGI.SUBDIV_64, VoxelGI.SUBDIV_128,
		VoxelGI.SUBDIV_256, VoxelGI.SUBDIV_512]
## How strongly bounced light shows, and how far it reaches into corners.
const GI_ENERGY := 1.0
const GI_PROPAGATION := 0.7
## Reflections from the probe blend in over this edge, m.
const PROBE_BLEND := 2.0
## A probe re-renders after the sky's hour moves this far, h.
const REPROBE_HOURS := 0.75


## Adds or updates the probe and the VoxelGI for one room. Returns the VoxelGI that needs a
## bake, or null.
static func apply(room: Node3D) -> VoxelGI:
	var box: AABB = room.get_meta(BOX_META, AABB())
	if box.size == Vector3.ZERO:
		return null
	var centre := box.get_center()
	var probe := room.get_node_or_null(PROBE) as ReflectionProbe
	if wants_probe():
		if probe == null:
			probe = ReflectionProbe.new()
			probe.name = PROBE
			room.add_child(probe)
		probe.position = centre
		probe.size = box.size
		probe.box_projection = true
		probe.interior = true
		probe.enable_shadows = true
		probe.blend_distance = PROBE_BLEND
		probe.ambient_mode = ReflectionProbe.AMBIENT_ENVIRONMENT
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.max_distance = box.size.length()
	elif probe:
		probe.queue_free()

	var gi := room.get_node_or_null(VOXEL) as VoxelGI
	if not wants_gi():
		if gi:
			gi.queue_free()
		return null
	var quality := clampi(int(GraphicsOptions.get_value("gi_quality")), 0, SUBDIV.size() - 1)
	var fresh := gi == null
	if fresh:
		gi = VoxelGI.new()
		gi.name = VOXEL
		room.add_child(gi)
	gi.position = centre
	gi.size = box.size
	var rebake := fresh or gi.subdiv != SUBDIV[quality] or gi.data == null
	gi.subdiv = SUBDIV[quality]
	if gi.data:
		gi.data.energy = GI_ENERGY
		gi.data.propagation = GI_PROPAGATION
		gi.data.interior = true
		gi.data.use_two_bounces = quality >= 2
	return gi if rebake else null


## Bakes a room's VoxelGI from every static mesh in the scene inside its box (the room
## node can be an empty marker; the hall's walls may live anywhere in the scene).
static func bake(gi: VoxelGI) -> void:
	if not is_instance_valid(gi) or not gi.is_inside_tree():
		return
	var path := cache_path(gi)
	var cached: VoxelGIData = null
	if path != "" and ResourceLoader.exists(path):
		cached = ResourceLoader.load(path, "VoxelGIData", ResourceLoader.CACHE_MODE_IGNORE) as VoxelGIData
	if cached:
		gi.data = cached
	else:
		var scene := gi.get_tree().current_scene
		gi.bake(scene if scene and scene.is_ancestor_of(gi) else gi.get_parent())
		if path != "" and gi.data:
			_keep(gi.data, path)
	if gi.data:
		gi.data.energy = GI_ENERGY
		gi.data.propagation = GI_PROPAGATION
		gi.data.interior = true
		gi.data.use_two_bounces = int(GraphicsOptions.get_value("gi_quality")) >= 2


## Baked rooms are kept on disk per build (user://gi_cache/<commit>/), so a yard opened again
## (a second start, back from the menu, a guest joining) loads its bounce light instead of
## baking it: a bake voxelises every mesh in the scene and held the game up for seconds a room,
## the long stall after the yard loaded. A new build bakes afresh, as its halls may differ.
const CACHE_DIR := "user://gi_cache"
## Dev runs (no build_info.cfg) bake every time unless this is set (tests).
static var cache_dev := false


## Where a room's bake is kept, or "" when it isn't (a dev run, a room with no name).
static func cache_path(gi: VoxelGI) -> String:
	var commit := BuildInfo.commit()
	if commit == "dev" and not cache_dev:
		return ""
	var room := gi.get_parent()
	if room == null:
		return ""
	var scene := gi.get_tree().current_scene if gi.is_inside_tree() else null
	var key := "%s|%s|%s|%s|%s|%d" % [scene.name if scene else "", room.name, str(room.get_meta(BOX_META, AABB())),
			str(gi.position), str(gi.size), gi.subdiv]
	return "%s/%s/%s_%x.res" % [CACHE_DIR, commit.validate_filename(), str(room.name).validate_filename(), hash(key)]


static func _keep(data: VoxelGIData, path: String) -> void:
	var dir := path.get_base_dir()
	# Only this build's bakes are worth keeping.
	var root := DirAccess.open(CACHE_DIR) if DirAccess.dir_exists_absolute(CACHE_DIR) else null
	if root:
		for old in root.get_directories():
			if "%s/%s" % [CACHE_DIR, old] != dir:
				_remove_dir("%s/%s" % [CACHE_DIR, old])
	DirAccess.make_dir_recursive_absolute(dir)
	ResourceSaver.save(data, path)


static func _remove_dir(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(path)


## Re-renders a room's probe (the sky's light has changed).
static func reprobe(room: Node3D) -> void:
	var probe := room.get_node_or_null(PROBE) as ReflectionProbe
	if probe:
		# UPDATE_ONCE renders when set; setting it again asks for another render.
		probe.update_mode = ReflectionProbe.UPDATE_ONCE


static func wants_probe() -> bool:
	return int(GraphicsOptions.get_value("reflections")) > 0 or int(GraphicsOptions.get_value("detail")) > 0


static func wants_gi() -> bool:
	return int(GraphicsOptions.get_value("gi")) > 0
