extends RefCounted
## Puts the highlight over every mesh of a thing, on top of its own materials
## (material_overlay), and takes it off again. Two looks: BOLD (a pulsing rim, a faint fill and
## a solid outline: pings, which must catch the eye) and SUBTLE (only a thin, soft outline:
## hover, which shouldn't startle). Several reasons can hold one thing lit at once (the
## pointer over it, a ping on it); the newest reason's colour and look show, and it goes
## dark when the last reason lets go.

const RIM := preload("res://modules/graphics/internal/highlight.gdshader")
const OUTLINE := preload("res://modules/graphics/internal/highlight_outline.gdshader")
## Marks a mesh's own overlay, kept to put back (meta).
const SAVED := "gfx_overlay_saved"

## The two looks: the rim and fill's share, the outline's width (share of the distance) and
## its opacity.
const BOLD := {"glow": 1.0, "width": 0.0035, "opacity": 1.0}
const SUBTLE := {"glow": 0.0, "width": 0.0025, "opacity": 0.9}

## instance id -> {node, reasons: {reason: Color}, looks: {reason: Dictionary}, order: Array[reason], mat}
var _lit: Dictionary = {}


func is_lit(target: Node, reason: String = "") -> bool:
	var e: Dictionary = _lit.get(target.get_instance_id(), {})
	return not e.is_empty() and (reason == "" or e.reasons.has(reason))


func colour_of(target: Node) -> Color:
	var e: Dictionary = _lit.get(target.get_instance_id(), {})
	return e.reasons[e.order.back()] if not e.is_empty() else Color.TRANSPARENT


## The look a thing shows now (BOLD or SUBTLE), or {} when it isn't lit.
func look_of(target: Node) -> Dictionary:
	var e: Dictionary = _lit.get(target.get_instance_id(), {})
	return e.looks[e.order.back()] if not e.is_empty() else {}


func light(target: Node, reason: String, colour: Color, look: Dictionary = BOLD) -> void:
	if not is_instance_valid(target):
		return
	var key := target.get_instance_id()
	if not _lit.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = RIM
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE
		mat.next_pass = outline
		_lit[key] = {"node": target, "reasons": {}, "looks": {}, "order": [], "mat": mat}
		_cover(target, mat)
	var e: Dictionary = _lit[key]
	e.reasons[reason] = colour
	e.looks[reason] = look
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
	e.looks.erase(reason)
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
	var look: Dictionary = e.looks[e.order.back()]
	var mat: ShaderMaterial = e.mat
	var outline := mat.next_pass as ShaderMaterial
	mat.set_shader_parameter("colour", c)
	mat.set_shader_parameter("glow", float(look.glow))
	outline.set_shader_parameter("colour", c)
	outline.set_shader_parameter("width", float(look.width))
	outline.set_shader_parameter("opacity", float(look.opacity))


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
