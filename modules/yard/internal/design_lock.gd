extends "res://modules/yard/internal/airlock.gd"
## The design room's own way out to the dock (0.4.0 playtest: "direct access from the design
## room to the yard"): a small lock in the window wall's left corner, its inner door in the
## window wall and its outer door facing the build berth. It cycles as the main airlock does
## (never both doors open); its doors slide up into the wall.


func build(kit) -> void:
	_kit = kit
	var k = kit
	var wall: Material = k.paint(Color(0.7, 0.72, 0.75), 0.1, 0.7)
	var hazard: Material = k.paint(Color(1.0, 0.78, 0.1), 0.1, 0.6, "hazard_stripes")
	var x0 := YardLayout.DESIGN_LOCK_DOOR_X.x
	var x1 := YardLayout.DESIGN_LOCK_DOOR_X.y
	var h := YardLayout.DESIGN_LOCK_DOOR_H
	var zi := YardLayout.DESIGN_LOCK_INNER_Z
	var zo := YardLayout.DESIGN_LOCK_OUTER_Z
	var box: AABB = YardLayout.ROOMS["design_lock"].box
	var top := box.size.y
	# Side walls and the outer wall (the inner door is in the design room's window wall).
	k.wall(false, box.position.x - 0.1, zo + 0.1, zi - 0.1, 0.0, top, wall)
	k.wall(false, box.end.x + 0.1, zo + 0.1, zi - 0.1, 0.0, top, wall)
	k.wall(true, zo, box.position.x - 0.2, box.end.x + 0.2, 0.0, top, wall, [[x0, x1, h]], 0.2)
	for z: float in [zi, zo]:
		k.box(Vector3(x1 - x0 + 0.24, 0.12, 0.24), Vector3((x0 + x1) * 0.5, h + 0.06, z), hazard, false)
	k.span(Vector3(box.position.x + 0.05, 0.002, zo + 0.1), Vector3(box.end.x - 0.05, 0.012, zi - 0.1),
			k.paint(Color(0.25, 0.26, 0.28), 0.6, 0.5, "tread_diamond_steel"), false)
	k.ceiling_lamp(Vector3(box.get_center().x, top, (zi + zo) * 0.5), Vector2(0.8, 0.8), 0.8, 7.0)
	inner_door = _door(zi, "InnerDoor")
	outer_door = _door(zo, "OuterDoor")
	_panel(Vector3(box.position.x + 0.02, 1.3, zi + 0.6), Vector3.RIGHT, "corridor")
	_panel(Vector3(box.end.x - 0.02, 1.3, (zi + zo) * 0.5), Vector3.LEFT, "inside")
	_panel(Vector3(box.end.x + 0.1, 1.3, zo - 0.12), Vector3.FORWARD, "outside")
	# State lamps over each door, both faces.
	for z: float in [zi + 0.2, zi - 0.2, zo + 0.2, zo - 0.2]:
		var lamp: MeshInstance3D = k.box(Vector3(0.5, 0.12, 0.06), Vector3((x0 + x1) * 0.5, h + 0.3, z), _lamp_mat(Color.GREEN), false)
		_lamps.append(lamp)
	_apply_doors()


## Its doors lie across z (in the window wall and the outer wall) and lift to open.
func _apply_doors() -> void:
	if inner_door == null:
		return
	var o := openness()
	var h := YardLayout.DESIGN_LOCK_DOOR_H
	inner_door.position.y = h * 0.5 + o.x * (h + 0.05)
	outer_door.position.y = h * 0.5 + o.y * (h + 0.05)
	var c := Color(0.2, 1.0, 0.35)
	if state == State.PUMPING:
		c = Color(1.0, 0.6, 0.1)
	elif is_busy():
		c = Color(1.0, 0.2, 0.15)
	for l in _lamps:
		l.material_override = _lamp_mat(c)


## A door in the plane z = `x` (the base's name for the one coordinate a door sits at).
func _door(x: float, node_name: String) -> AnimatableBody3D:
	var d: AnimatableBody3D = super._door(0.0, node_name)
	var w := YardLayout.DESIGN_LOCK_DOOR_X.y - YardLayout.DESIGN_LOCK_DOOR_X.x
	var size := Vector3(w + 0.04, YardLayout.DESIGN_LOCK_DOOR_H, 0.12)
	for c in d.get_children():
		if c is CollisionShape3D:
			((c as CollisionShape3D).shape as BoxShape3D).size = size
		elif c is MeshInstance3D:
			var mi := c as MeshInstance3D
			if mi.position.y > 0.0:
				(mi.mesh as BoxMesh).size = Vector3(w, 0.2, 0.14)   # the stripe
			else:
				(mi.mesh as BoxMesh).size = size
	d.position = Vector3((YardLayout.DESIGN_LOCK_DOOR_X.x + YardLayout.DESIGN_LOCK_DOOR_X.y) * 0.5,
			YardLayout.DESIGN_LOCK_DOOR_H * 0.5, x)
	return d


func _panel(at: Vector3, facing: Vector3, where: String) -> void:
	super._panel(at, facing, where)
	var area := get_child(get_child_count() - 1)
	area.set_meta("gfx_id", "design_lock:" + where)
