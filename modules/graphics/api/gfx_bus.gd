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
##   - more groups (gfx_lamp, gfx_room, gfx_screen...) arrive with later stages.
## Group names are plain strings, so tagging a node needs no dependency on this module.
##
## Core's Graphics autoload still applies the player's quality options (shadows, GI, AO...)
## first; this module tunes on top of what it set, and again whenever it re-applies them.

signal look_applied(node: Node)

## Feature flag of each stage.
const LIGHT := "graphics.light"
## Group that opts a WorldEnvironment outside an AlienSky into the outdoor baseline.
const WORLD_GROUP := "gfx_world"

const LightBaseline := preload("res://modules/graphics/internal/light_baseline.gd")


func register_module() -> void:
	var tree := get_tree()
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)
	var core_gfx := tree.root.get_node_or_null("Graphics")
	if core_gfx and core_gfx.has_signal("changed") and not core_gfx.changed.is_connected(apply_all):
		core_gfx.changed.connect(apply_all)
	apply_all.call_deferred()


func unregister_module() -> void:
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


func _on_node_added(n: Node) -> void:
	if n is WorldEnvironment or n is DirectionalLight3D:
		# Core's Graphics tunes these deferred too; queued after it, so this lands on top.
		restyle.call_deferred(n)
