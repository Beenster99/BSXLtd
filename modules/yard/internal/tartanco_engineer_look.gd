extends RefCounted
## A TartanCo field engineer: a person in the firm's white work suit with a tartan sash band,
## yellow shoulders and a gold visor, a jet pack, and a diagnostic wand in the right hand.
## 1.8 m tall, built in code. Origin at the hips, facing -Z; arms hang from "ShoulderL/R".

const Kit := preload("res://modules/yard/internal/tartanco_mesh.gd")

static var _meshes: Dictionary = {}


## "body" (torso, head, pack, legs), "arm" (one arm from its shoulder at the origin, hanging
## down -Y) and "wand" (the diagnostic wand, held at the origin, its tip to -Z).
static func meshes() -> Dictionary:
	if _meshes.is_empty():
		_meshes = _build()
	return _meshes


static func _build() -> Dictionary:
	var m := Kit.new()
	var k := "body"
	# Legs, boots.
	for s: float in [-1.0, 1.0]:
		m.box(k, "suit", Vector3(s * 0.11, -0.42, 0.02), Vector3(0.17, 0.78, 0.2), 0.05)
		m.box(k, "grey", Vector3(s * 0.11, -0.22, -0.11), Vector3(0.15, 0.14, 0.04), 0.02)
		m.box(k, "rubber", Vector3(s * 0.11, -0.86, -0.03), Vector3(0.18, 0.12, 0.3), 0.03)
	# Hips, torso, the tartan band and a yellow collar.
	m.box(k, "grey", Vector3(0, 0.0, 0), Vector3(0.38, 0.16, 0.24), 0.05)
	m.box(k, "suit", Vector3(0, 0.33, 0), Vector3(0.44, 0.52, 0.27), 0.08)
	m.box(k, "tartan", Vector3(0, 0.36, -0.137), Vector3(0.4, 0.12, 0.01), 0.0)
	m.box(k, "yellow", Vector3(0, 0.6, 0), Vector3(0.36, 0.06, 0.24), 0.02)
	m.box(k, "screen", Vector3(0.12, 0.47, -0.14), Vector3(0.08, 0.05, 0.01), 0.0)
	# The helmet and its visor.
	m.ball(k, "suit", Vector3(0, 0.82, 0), Vector3(0.16, 0.17, 0.17), 8, 12)
	m.ball(k, "visor", Vector3(0, 0.82, -0.05), Vector3(0.13, 0.11, 0.13), 6, 12)
	m.box(k, "lamp", Vector3(0.12, 0.93, -0.08), Vector3(0.04, 0.03, 0.04), 0.0)
	# The jet pack.
	m.box(k, "grey", Vector3(0, 0.36, 0.22), Vector3(0.38, 0.5, 0.18), 0.05)
	m.box(k, "yellow", Vector3(0, 0.62, 0.22), Vector3(0.3, 0.08, 0.16), 0.02)
	for s: float in [-1.0, 1.0]:
		m.cylinder(k, "dark", Vector3(s * 0.12, 0.08, 0.24), 0.12, 0.05, 0.07, 8, Basis(Vector3.RIGHT, PI * 0.5))
	# An arm: upper arm and forearm hanging from the shoulder, a yellow pad, a glove.
	m.box("arm", "yellow", Vector3(0, -0.04, 0), Vector3(0.14, 0.12, 0.14), 0.03)
	m.box("arm", "suit", Vector3(0, -0.28, 0), Vector3(0.11, 0.42, 0.12), 0.04)
	m.box("arm", "suit", Vector3(0, -0.56, -0.06), Vector3(0.1, 0.16, 0.2), 0.04)
	m.box("arm", "grey", Vector3(0, -0.6, -0.2), Vector3(0.09, 0.1, 0.1), 0.03)
	# The wand: a grip, a body and a lit tip.
	m.box("wand", "dark", Vector3(0, 0, 0), Vector3(0.05, 0.12, 0.05), 0.01)
	m.box("wand", "yellow", Vector3(0, 0.07, -0.08), Vector3(0.07, 0.06, 0.22), 0.015)
	m.cylinder("wand", "screen", Vector3(0, 0.07, -0.21), 0.03, 0.025, 0.025, 8)
	return m.meshes()


## A whole engineer: "Body", arms under "ShoulderL"/"ShoulderR" (raise them by turning about X),
## the wand under the right hand ("Wand"), and a helmet lamp ("Lamp", off till they work).
static func make(number: String) -> Node3D:
	var n := Node3D.new()
	n.name = "Engineer" + number
	var m := meshes()
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = m.body
	n.add_child(body)
	for s: float in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.name = "ShoulderL" if s < 0.0 else "ShoulderR"
		sh.position = Vector3(s * 0.28, 0.54, 0)
		n.add_child(sh)
		var arm := MeshInstance3D.new()
		arm.mesh = m.arm
		sh.add_child(arm)
		if s > 0.0:
			var wand := MeshInstance3D.new()
			wand.name = "Wand"
			wand.mesh = m.wand
			wand.position = Vector3(0, -0.62, -0.22)
			sh.add_child(wand)
	var lamp := SpotLight3D.new()
	lamp.name = "Lamp"
	lamp.position = Vector3(0.12, 0.93, -0.12)
	lamp.spot_range = 6.0
	lamp.spot_angle = 28.0
	lamp.light_energy = 0.0
	n.add_child(lamp)
	return n
