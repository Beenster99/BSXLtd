extends RefCounted
## Puts the highlight (rim, fill and outline) over every mesh of a thing, on top of its own
## materials (material_overlay), and takes it off again. Several reasons can hold one thing
## lit at once (the pointer over it, a ping on it); the newest reason's colour shows, and it
## goes dark when the last reason lets go.

const RIM := preload("res://modules/graphics/internal/highlight.gdshader")
const OUTLINE := preload("res://modules/graphics/internal/highlight_outline.gdshader")
## Marks a mesh's own overlay, kept to put back (meta).
const SAVED := "gfx_overlay_saved"

## instance id -> {node, reasons: {reason: Color}, order: Array[reason], mat}
var _lit: Dictionary = {}


func is_lit(target: Node, reason: String = "") -> bool:
	var e: Dictionary = _lit.get(target.get_instance_id(), {})
	return not e.is_empty() and (reason == "" or e.reasons.has(reason))


func colour_of(target: Node) -> Color:
	var e: Dictionary = _lit.get(target.get_instance_id(), {})
	return e.reasons[e.order.back()] if not e.is_empty() else Color.TRANSPARENT


func light(target: Node, reason: String, colour: Color) -> void:
	if not is_instance_valid(target):
		return
	var key := target.get_instance_id()
	if not _lit.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = RIM
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE
		mat.next_pass = outline
		_lit[key] = {"node": target, "reasons": {}, "order": [], "mat": mat}
		_cover(target, mat)
	var e: Dictionary = _lit[key]
	e.reasons[reason] = colour
	e.order.erase(reason)
	e.order.append(reason)
	_tint(e)


func unlight(target: Node, reason: String) -> void:
	if target == null:
		return
	var key := target.get_instance_id()
	var e: Dictionary = _lit.get(key, {})
	if e.is_empty() or not e.reasons.has(reason):
		return
	e.reasons.erase(reason)
	e.order.erase(reason)
	if e.order.is_empty():
		_lit.erase(key)
		if is_instance_valid(target):
			_uncover(target, e.mat)
	else:
		_tint(e)


## Fades a reason's colour (pings fading out), 0..1.
func set_strength(target: Node, strength: float) -> void:
	var e: Dictionary = _lit.get(target.get_instance_id(), {}) if is_instance_valid(target) else {}
	if not e.is_empty():
		var mat: ShaderMaterial = e.mat
		mat.set_shader_parameter("strength", strength)
		(mat.next_pass as ShaderMaterial).set_shader_parameter("strength", strength)


func clear() -> void:
	for e: Dictionary in _lit.values():
		if is_instance_valid(e.node):
			_uncover(e.node, e.mat)
	_lit.clear()


## Drops things that left the tree.
func prune() -> void:
	for key: int in _lit.keys():
		if not is_instance_valid(_lit[key].node):
			_lit.erase(key)


func _tint(e: Dictionary) -> void:
	var c: Color = e.reasons[e.order.back()]
	var mat: ShaderMaterial = e.mat
	mat.set_shader_parameter("colour", c)
	(mat.next_pass as ShaderMaterial).set_shader_parameter("colour", c)


static func _cover(n: Node, mat: Material) -> void:
	if n is GeometryInstance3D and not (n is Label3D) and not (n is SpriteBase3D):
		var g := n as GeometryInstance3D
		if not g.has_meta(SAVED):
			g.set_meta(SAVED, g.material_overlay)
		g.material_overlay = mat
	for c in n.get_children():
		if not (c is SubViewport):
			_cover(c, mat)


static func _uncover(n: Node, mat: Material) -> void:
	if n is GeometryInstance3D and n.has_meta(SAVED):
		var g := n as GeometryInstance3D
		if g.material_overlay == mat:
			g.material_overlay = g.get_meta(SAVED)
		g.remove_meta(SAVED)
	for c in n.get_children():
		_uncover(c, mat)
