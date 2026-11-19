extends Node3D
## The worker bots building in the build berth (0.4.1 playtest: "they also deliver to the
## worker bots who actually make the ship in the yard"): a crew of four round a keel frame of
## Void Salvage's box beams and girders. When the frame needs more they ask the stores for a
## frame kit; mover bots bring it out to their foreman; they weld it on, ring by ring, sparks
## at the joints, and ask for the next. Presentation only: it stands in for Wave 5's real
## building in the berths.

const BotLook := preload("res://modules/yard/internal/yard_bot_look.gd")
const Look := preload("res://modules/yard/internal/yard_stock_look.gd")

## The keel's first ring, the way it grows (m), the rings' pitch and how many it has room for.
const KEEL_START := Vector3(-16.0, -3.0, -85.0)
const KEEL_STEP := 3.2
const RINGS := 11
## The ring's side (m): a BoxBeam's length.
const RING := 6.0

## Seconds to weld a ring on once its kit is here.
@export var weld_seconds := 9.0
## Rings standing when the yard opens.
@export var start_rings := 3

var traffic: Node
var workers: Array[Dictionary] = []
var rings: Array[Node3D] = []
## The kit order on its way (its id) or -1; then welding (seconds left) once it's here.
var _order := -1
var _weld := 0.0
var _arrived: Array = []
var _time := 0.0


func build(stores_traffic: Node) -> void:
	name = "YardWorkers"
	traffic = stores_traffic
	for i in start_rings:
		_add_ring()
	for i in 4:
		var bot := BotLook.make(BotLook.BSX_YARD, "W%d" % (i + 1))
		bot.name = "Worker%d" % (i + 1)
		add_child(bot)
		var spark := MeshInstance3D.new()
		spark.name = "Spark"
		var sm := SphereMesh.new()
		sm.radius = 0.12
		sm.height = 0.24
		spark.mesh = sm
		spark.material_override = Look.glow_material(Color(0.6, 0.85, 1.0))
		add_child(spark)
		var light := OmniLight3D.new()
		light.name = "WeldLight%d" % (i + 1)
		light.light_color = Color(0.6, 0.8, 1.0)
		light.omni_range = 6.0
		light.light_energy = 0.0
		spark.add_child(light)
		workers.append({"node": bot, "spark": spark, "light": light, "index": i})
	_place_workers(1.0)
	if traffic and traffic.has_signal("kit_delivered"):
		traffic.connect("kit_delivered", _on_kit)


## The worker the movers bring kits to.
func foreman() -> Node3D:
	return workers[0].node if not workers.is_empty() else null


func rings_built() -> int:
	return rings.size()


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	_time += delta
	if _order < 0 and _weld <= 0.0 and rings.size() < RINGS and traffic:
		_order = int(traffic.call("deliver_kit", "frame", foreman()))
	if _weld > 0.0:
		_weld -= delta
		# The kit's loads drift in to the new ring as it goes on.
		for l: Dictionary in _arrived:
			if is_instance_valid(l.node):
				var n := l.node as Node3D
				n.global_position = n.global_position.lerp(_front() + Vector3(0, RING * 0.5, 0), minf(1.0, delta * 0.4))
				n.scale = n.scale.lerp(Vector3.ONE * 0.2, minf(1.0, delta * 0.2))
		if _weld <= 0.0:
			for l: Dictionary in _arrived:
				traffic.call("consume", l)
			_arrived.clear()
			_add_ring()
	_place_workers(delta)


func _on_kit(order_id: int, _kit: String) -> void:
	if order_id != _order:
		return
	_order = -1
	var o: Dictionary = traffic.call("kit_order", order_id)
	_arrived = (o.get("loads", []) as Array).duplicate()
	for l: Dictionary in _arrived:
		l.kept = true   # the workers fit these: they don't go back
	_weld = weld_seconds


## The face the next ring goes on (station space).
func _front() -> Vector3:
	return KEEL_START + Vector3(KEEL_STEP * rings.size(), 0, 0)


## Workers at the front ring's corners: hovering, turning to it, sparks while welding.
func _place_workers(delta: float) -> void:
	var front := _front() - Vector3(KEEL_STEP * 0.5, 0, 0)
	var corners := [Vector3(0, 0, -RING * 0.5), Vector3(0, RING, -RING * 0.5), Vector3(0, RING, RING * 0.5), Vector3(0, 0, RING * 0.5)]
	for w: Dictionary in workers:
		var i := int(w.index)
		var c: Vector3 = front + corners[i]
		var bob := sin(_time * 1.3 + i) * 0.25
		var at := c + Vector3(1.6, bob, signf(c.z - front.z) * 1.4)
		var node := w.node as Node3D
		node.position = node.position.lerp(at, minf(1.0, delta * 1.5))
		if node.position.distance_to(c) > 0.5:
			node.look_at(c, Vector3.UP)
		var welding := _weld > 0.0 or (i % 2 == 0 and fmod(_time + i, 6.0) < 1.5)
		BotLook.animate(node, delta, welding)
		var spark := w.spark as MeshInstance3D
		spark.position = c + Vector3(0.3, 0, 0)
		var flick := 0.5 + 0.5 * sin(_time * 47.0 + i * 3.0) * sin(_time * 31.0)
		spark.visible = welding and flick > 0.2
		(w.light as OmniLight3D).light_energy = (1.2 + flick * 1.6) if spark.visible else 0.0


## One ring of the keel frame: four box beams round a square, girders back to the last ring.
func _add_ring() -> void:
	var at := _front()
	var ring := Node3D.new()
	ring.name = "Ring%d" % rings.size()
	ring.position = at
	add_child(ring)
	var beam: Array = Look.layers("BoxBeam")
	var girder: Array = Look.layers("Girder")
	var h := RING * 0.5
	# BoxBeam is built along x: turn it for the uprights and the cross members.
	var sides := [
		Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0, 0)),
		Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, RING, 0)),
		Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, h, -h)),
		Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, h, h)),
	]
	for t: Transform3D in sides:
		_draw(ring, beam, t)
	if rings.size() > 0:
		for c: Vector3 in [Vector3(0, 0, -h), Vector3(0, 0, h), Vector3(0, RING, -h), Vector3(0, RING, h)]:
			# Girder is built along x, 4 m: scaled to the pitch, from this ring back to the last.
			_draw(ring, girder, Transform3D(Basis().scaled(Vector3(KEEL_STEP / 4.0, 1, 1)), c - Vector3(KEEL_STEP * 0.5, 0, 0)))
	rings.append(ring)


func _draw(parent: Node3D, layers: Array, t: Transform3D) -> void:
	for l: Dictionary in layers:
		var mi := MeshInstance3D.new()
		mi.mesh = l.mesh
		mi.material_override = l.material
		mi.transform = t
		parent.add_child(mi)
