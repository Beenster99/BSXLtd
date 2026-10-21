class_name TradesStation
extends Node3D
## One trade's stretch of the bay's bench: its parts, its joint rules and what the tools do
## there. The bay (TradesBay) owns the worker, the tools, the HUD and the input, and hands
## each mouse and key event to the station you are working at. Positions in a station are
## in its own space: its origin is on the floor under the middle of its stretch of bench,
## +X along the bench, -Z toward the wall.

## The bay this station sits in (set before build()).
var bay: TradesBay
## Its id ("bolting"...), the name on its sign, and which trade its joints are.
var id: StringName
var title := ""
## Half the length of bench it takes up, in metres.
var half_width := 0.5


## Make the station's parts. Called once, after the station is in the tree.
func build() -> void:
	pass


## The tools that do something here (the hotbar dims the others while you work here).
func tools() -> Array[StringName]:
	return [&"hands"]


## The HUD's second line while you work here (the part you hold, the welder's setting...).
func status_line() -> String:
	return ""


## What to do first, shown when you walk up to the station.
func start_hint() -> String:
	return ""


## Left click pressed and released with the bay's current tool.
func press(_tool: StringName) -> void:
	pass


func release() -> void:
	pass


## Right click: take something back off (a bolt out, a rivet drilled out, a weld ground off).
func back_out(_tool: StringName) -> void:
	pass


## E (+1) or Q (-1): set the machine (the welder's amps). True when the station used it.
func adjust(_step: int) -> bool:
	return false


## The mouse wheel while left click holds something in your hands: turn it by one notch
## (+1 or -1), a few degrees, or a quarter turn when `snap` is on. True when the station
## turned something.
func turn_held(_step: int, _snap: bool) -> bool:
	return false


## Mouse movement while you work. True when the station used it (the view stays put).
func motion(_relative: Vector2) -> bool:
	return false


## Key data about what the aim is on (a part, a joint), for the inspect panel (hold Tab).
## Empty when the aim is on nothing this station knows.
func inspect_lines() -> PackedStringArray:
	return PackedStringArray()


## What the aim is on, for the tips' heading ("" lets the bay name the station).
func aim_title(_tool: StringName) -> String:
	return ""


## What you can do now with `tool` on what the aim is on, for the tips in the HUD's
## right-hand panel: [[input, what it does], ...]; input is a Keys action (shown with its
## bound key) or a label (TradesBay.CLICK...).
## Empty while the aim is on nothing this station knows.
func actions(_tool: StringName) -> Array:
	if inspect_lines().is_empty():
		return []
	return [[TradesBay.HOLD_CLICK, "use it"], [TradesBay.RIGHT_CLICK, "take it off"]]


## A key action the bay doesn't use itself (TradesBus.KEY_*, Keys.*). True when the station used it.
func key(_action: String) -> bool:
	return false


## True mid-action (a hand or tool out on something): the station keeps the input.
func is_busy() -> bool:
	return false


func update(_delta: float) -> void:
	pass


## Back to the start: parts off, joint reset, result removed from the bus.
func reset() -> void:
	pass


## A hand over-stretched and let go.
func on_hand_snapped() -> void:
	release()


## The station mid-job for the release screenshots (a coroutine; the bay places the worker).
func stage_for_screenshot() -> void:
	pass


## Where the worker stands for a screenshot, and what they look at (station space).
func screenshot_view() -> Array[Vector3]:
	return [Vector3(0.05, 0.0, 0.56), Vector3(0.0, TradesBay.BENCH_TOP, 0.0)]


# --- Helpers for stations ----------------------------------------------------------------

## A point in station space as a world point.
func world(p: Vector3) -> Vector3:
	return to_global(p)


func paint_box(size: Vector3, at: Vector3, mat: Material, parent: Node = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(mesh, at, mat, parent)


func paint_cylinder(radius: float, height: float, at: Vector3, mat: Material, parent: Node = self,
		radial: int = 24) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = radial
	return _add(mesh, at, mat, parent)


## A number label lying on the bench (the order of work), in the Void Salvage mono font.
func bench_label(text: String, at: Vector3, parent: Node = self) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = TradesLook.mono_font()
	l.font_size = 48
	l.pixel_size = 0.0004
	l.modulate = TradesLook.TRIM
	l.rotation_degrees.x = -90
	l.position = at
	parent.add_child(l)
	return l


func _add(mesh: PrimitiveMesh, at: Vector3, mat: Material, parent: Node) -> MeshInstance3D:
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	parent.add_child(mi)
	return mi
