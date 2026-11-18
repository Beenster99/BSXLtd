extends Node3D
## The practice frame in the dock, just outside the airlock (stage 1.4): a backing frame with
## three panels on it, one bolted (the socket), one riveted (the grinder) and one welded (the
## cutter's torch), and a loose bracket to try the grabber on. A terminal beside it builds it
## again. Built from the shared PartModel, as the ships on the berths will be.
##
## Frame space: the panels face +Z; the frame stands upright, its foot at y 0.

## The frame and panels (m).
const FRAME_SIZE := Vector3(2.6, 1.4, 0.1)
const PANEL_SIZE := Vector3(0.72, 1.0, 0.02)
## The gap between a panel and the frame (parts' collision must never overlap).
const GAP := 0.006
## Which joint holds each panel, left to right.
const PANELS := [
	["BoltedPanel", ConnectionData.Kind.BOLT],
	["RivetedPanel", ConnectionData.Kind.RIVET],
	["WeldedPanel", ConnectionData.Kind.WELD],
]

var frame: YardWorkpiece
var bracket: YardWorkpiece
## The fitting frame: its panels tacked on, rivets and welds planned (YardWorkpiece.planned).
var fit: YardWorkpiece
## Where the fitting frame stands (frame space): to the right, past the bracket.
const FIT_AT := Vector3(4.2, 0.0, 0.0)
const FIT_SIZE := Vector3(1.8, 1.4, 0.1)
## A weld seam's length (m): short, so a steady hand runs it in about six seconds (0.4.1).
const WELD_LENGTH := 0.28
var _pieces: Array[Node] = []
var _steel: StandardMaterial3D
var _paint: StandardMaterial3D


func _ready() -> void:
	name = "PracticeFrame"
	_steel = StandardMaterial3D.new()
	_steel.albedo_color = Color(0.55, 0.57, 0.6)
	_steel.metallic = 0.7
	_steel.roughness = 0.45
	_paint = StandardMaterial3D.new()
	_paint.albedo_color = Color(0.86, 0.5, 0.12)
	_paint.metallic = 0.2
	_paint.roughness = 0.6
	_build_terminal()
	rebuild()


## Builds the frame and its panels again, as new (pieces cut off before are cleared away).
func rebuild() -> void:
	for n in _pieces:
		if is_instance_valid(n):
			n.queue_free()
	_pieces.clear()
	frame = YardWorkpiece.new()
	frame.name = "Frame"
	frame.freeze = true
	add_child(frame)
	_pieces.append(frame)
	frame.piece_freed.connect(func(p: YardWorkpiece) -> void: _pieces.append(p))
	var m := frame.model
	var back_shape := PartShapes.box(FRAME_SIZE)
	var back := m.add_part("PracticeFrame", PartData.Kind.FRAME, 300.0, 0.0,
			Transform3D(Basis(), Vector3(0, FRAME_SIZE.y * 0.5 + 0.6, 0)), back_shape.mesh, back_shape.collision, _steel)
	frame.anchor_part = back.id
	var panel_shape := PartShapes.box(PANEL_SIZE)
	var face := FRAME_SIZE.z * 0.5
	for i in PANELS.size():
		var x := (float(i) - 1.0) * (PANEL_SIZE.x + 0.12)
		var centre := Vector3(x, back.local_transform.origin.y, face + GAP + PANEL_SIZE.z * 0.5)
		var panel := m.add_part(String(PANELS[i][0]), PartData.Kind.HULL, 12.0, 0.0,
				Transform3D(Basis(), centre), panel_shape.mesh, panel_shape.collision, _paint)
		var kind: ConnectionData.Kind = PANELS[i][1]
		var front := centre.z + PANEL_SIZE.z * 0.5
		if kind == ConnectionData.Kind.WELD:
			# Two short beads down the panel's sides.
			for sx: float in [-1.0, 1.0]:
				m.connect_parts(panel, back, kind, Vector3(x + sx * PANEL_SIZE.x * 0.5, centre.y, front - 0.01),
						Vector3(sx, 0, 0), Vector3.UP, Vector2(PANEL_SIZE.y * 0.3, 0.012))
			continue
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var at := Vector3(x + corner.x * (PANEL_SIZE.x * 0.5 - 0.06), centre.y + corner.y * (PANEL_SIZE.y * 0.5 - 0.06), front)
			m.connect_parts(panel, back, kind, at, Vector3.BACK)
	# A loose bracket floating by the frame, for the grabber.
	bracket = YardWorkpiece.new()
	bracket.name = "Bracket"
	add_child(bracket)
	_pieces.append(bracket)
	var arm := PartShapes.box(Vector3(0.5, 0.12, 0.12))
	bracket.model.add_part("Bracket", PartData.Kind.FRAME, 8.0, 0.0, Transform3D(), arm.mesh, arm.collision, _steel)
	bracket.position = Vector3(FRAME_SIZE.x * 0.5 + 0.9, 1.4, 0.6)
	bracket._weigh()
	_build_fit()


## The fitting frame: a backing with two primer-grey panels on it, each held by one tack weld,
## the left's six rivets ringed and the right's two side welds chalked.
func _build_fit() -> void:
	fit = YardWorkpiece.new()
	fit.name = "FitFrame"
	fit.freeze = true
	fit.position = FIT_AT
	add_child(fit)
	_pieces.append(fit)
	var m := fit.model
	var back_shape := PartShapes.box(FIT_SIZE)
	var back := m.add_part("FitFrame", PartData.Kind.FRAME, 200.0, 0.0,
			Transform3D(Basis(), Vector3(0, FIT_SIZE.y * 0.5 + 0.6, 0)), back_shape.mesh, back_shape.collision, _steel)
	fit.anchor_part = back.id
	var primer := StandardMaterial3D.new()
	primer.albedo_color = Color(0.5, 0.53, 0.55)
	primer.metallic = 0.3
	primer.roughness = 0.65
	var panel_shape := PartShapes.box(PANEL_SIZE)
	var face := FIT_SIZE.z * 0.5
	for i in 2:
		var x := (float(i) - 0.5) * (PANEL_SIZE.x + 0.14)
		var centre := Vector3(x, back.local_transform.origin.y, face + GAP + PANEL_SIZE.z * 0.5)
		var panel := m.add_part("RivetFitPanel" if i == 0 else "WeldFitPanel", PartData.Kind.HULL, 12.0, 0.0,
				Transform3D(Basis(), centre), panel_shape.mesh, panel_shape.collision, primer)
		var front := centre.z + PANEL_SIZE.z * 0.5
		# One tack at the top holds it while it is fixed.
		m.connect_parts(panel, back, ConnectionData.Kind.SPOT, Vector3(x, centre.y + PANEL_SIZE.y * 0.5 - 0.05, front), Vector3.BACK)
		if i == 0:
			for row in 3:
				for col: float in [-1.0, 1.0]:
					var at := Vector3(x + col * (PANEL_SIZE.x * 0.5 - 0.07), centre.y + (float(row) - 1.0) * 0.38, front)
					fit.plan(ConnectionData.Kind.RIVET, panel, back, at, Vector3.BACK)
		else:
			for sx: float in [-1.0, 1.0]:
				fit.plan(ConnectionData.Kind.WELD, panel, back, Vector3(x + sx * PANEL_SIZE.x * 0.5, centre.y, front - 0.008),
						Vector3.BACK, Vector3.UP, Vector2(WELD_LENGTH, 0.012))


## How many joints still hold panels to the frame.
func joints_left() -> int:
	return frame.model.connections.size() if is_instance_valid(frame) else 0


func _build_terminal() -> void:
	var post := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.25, 1.2, 0.25)
	post.mesh = mesh
	post.material_override = _steel
	post.position = Vector3(-FRAME_SIZE.x * 0.5 - 0.7, 0.6, 0.3)
	add_child(post)
	var screen := Label3D.new()
	screen.text = "PRACTICE FRAME\nF: build it again"
	screen.font_size = 40
	screen.pixel_size = 0.0025
	screen.modulate = Color(0.55, 0.95, 1.0)
	screen.position = post.position + Vector3(0, 0.75, 0.14)
	add_child(screen)
	var area := Area3D.new()
	area.name = "RebuildTerminal"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 1.6, 0.6)
	shape.shape = box
	area.add_child(shape)
	area.position = post.position + Vector3(0, 0.2, 0)
	area.set_meta("yard_use", rebuild)
	area.set_meta("yard_hint", "F  Build the practice frame again")
	add_child(area)
