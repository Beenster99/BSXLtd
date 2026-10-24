extends RefCounted
## What the Kestrel's ship file leaves for BSX to draw. Shared Components' VsShipImport builds
## the ship systems (bowsers, hose rack, fuel port, cargo control and door panels, the hold
## monitor, the cockpit's screens) through Void Salvage's own `ShipParts.system`, and the
## leads' wires from `derived.routes`, but the floodlights are only points in the file and
## the screens come blank (Void Salvage fills them from the flying ship). This draws the
## floodlights from `layout.floodlights`, the nav lamps, the hose coiled on its rack, solid
## bowser drums and a parked ship's standby text on each screen (no ship systems in the
## yard), and keeps the door panels' lamps to light green while a door is open. Lit pieces
## glow, so the model's power switch darkens them with the rest.

const SCREEN_TEXT := Color(0.45, 0.95, 1.0)
## A parked ship's standby text per screen system.
const STANDBY := {
	"monitor": "HOLD MONITOR                 KESTREL\n\nHOLD      0 KG OF 2,400\nNETS      STOWED\nBAY DOOR  SHUT\n\nIN DOCK: SHIP SYSTEMS ON SHORE POWER",
	"cockpit_screen": "FLIGHT\nSHORE POWER\nDRIVE  SAFED\nHELM   LOCKED",
	"cockpit_monitor": "HOLD\n0 / 2,400 KG\nNETS  STOWED\nBAY   CLOSED",
	"nav_display": "NAV  DOCKED",
	"map_screen": "SYSTEM MAP",
}
## Font size of the standby text per screen system.
const STANDBY_SIZE := {"monitor": 26, "nav_display": 18, "map_screen": 18}
const DOOR_OPEN := Color(0.3, 1.0, 0.45)
const DOOR_SHUT := Color(0.6, 0.08, 0.05)

var body: Node3D
var file: Dictionary
var hull_dark: Material
## Door key -> the lamp materials on its panels (lit green while the door is open).
var door_lamps: Dictionary = {}
var spots: Array[SpotLight3D] = []
## The standby text put on each built screen.
var screens: Array[Label3D] = []
## Graphics' glowing pages over the screens' glass (led_screen), on with the ship's power.
var leds: Array[Node3D] = []


func _init(target: Node3D, f: Dictionary) -> void:
	body = target
	file = f
	hull_dark = ShipSurface.of(ShipKit.paint(Color(0.2, 0.21, 0.23), 0.6, 0.5))


## `built`: the importer's `systems_built` (system path -> ShipParts' handles).
func build(built: Dictionary) -> void:
	var kinds := {}
	for s: Dictionary in file.get("systems", []):
		kinds[str(s.get("path", "system:" + str(s.get("system", ""))))] = str(s.get("system", ""))
		match str(s.get("system", "")):
			"bowsers": _bowser_drums(VsShipImport.xform(s.get("frame", {})))
			"hose_rack": _hose_coil(VsShipImport.xform(s.get("frame", {})))
	for path: String in built:
		var made: Dictionary = built[path]
		var kind: String = kinds.get(path, "")
		if made.get("lamp") is StandardMaterial3D:
			var key := path.trim_prefix("system:").get_slice("/", 0)
			if not door_lamps.has(key):
				door_lamps[key] = []
			(door_lamps[key] as Array).append(made["lamp"])
		if not STANDBY.has(kind):
			continue
		if made.get("text") is Label3D:
			(made["text"] as Label3D).text = STANDBY[kind]
			screens.append(made["text"])
		elif made.get("glass") is MeshInstance3D:
			var led := _led(made["glass"], kind, STANDBY[kind])
			if led:
				leds.append(led)
			else:
				_standby(made["glass"], STANDBY[kind], int(STANDBY_SIZE.get(kind, 22)))
	_floodlights()
	_nav_lamps()


## Lights a door's panel lamps green while it's open, red while shut.
func show_door(key: String, open: bool) -> void:
	for lamp: StandardMaterial3D in door_lamps.get(key, []):
		lamp.emission = DOOR_OPEN if open else DOOR_SHUT
		lamp.emission_energy_multiplier = 1.0


## The bowsers' two drums are solid, so crew walk round them: ShipParts draws them as looks
## and the file's part is only the manifold block. Where ShipParts.bowsers stands them on
## its frame (X into the hold).
func _bowser_drums(frame: Transform3D) -> void:
	for t: Array in [["fuel", 1.05], ["coolant", 2.25]]:
		var drum := CollisionShape3D.new()
		drum.name = "Bowser_" + str(t[0])
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.5
		cyl.height = 2.45
		drum.shape = cyl
		drum.transform = frame * Transform3D(Basis(), Vector3(0.72, 1.235, float(t[1])))
		body.add_child(drum)


## The fuel hose coiled on its rack's hooks with the nozzle hanging (in Void Salvage the hose
## is a live rope the ship simulates; ShipParts draws only the rack). `frame`: the rack's, X
## out of the wall.
func _hose_coil(frame: Transform3D) -> void:
	var hose := ShipSurface.of(ShipKit.paint(Color(0.08, 0.08, 0.09), 0.1, 0.75))
	var face := Basis(Vector3.BACK, -PI * 0.5)   # a ring's axis (Y) out of the wall (X)
	for i in 5:
		var r := 0.3 - float(i) * 0.012
		_add(PartShapes.ring(r - 0.034, r, 0.034, 28), frame * Transform3D(face, Vector3(0.09 + float(i) * 0.036, 0.06, 0.0)), hose)
	var brass := ShipSurface.of(ShipKit.paint(Color(0.75, 0.55, 0.28), 0.9, 0.3))
	var steel := ShipSurface.of(ShipKit.paint(Color(0.55, 0.57, 0.6), 0.7, 0.4))
	_add(PartShapes.prism(10, 0.017, 0.3), frame * Transform3D(Basis(), Vector3(0.29, -0.12, -0.3)), hose)
	_add(PartShapes.prism(12, 0.035, 0.16), frame * Transform3D(Basis(), Vector3(0.29, -0.34, -0.3)), brass)
	_add(PartShapes.frustum(0.03, 0.018, 0.08, 12), frame * Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0.29, -0.46, -0.3)), steel)


## Graphics' lit page for a screen (its led_screen, "graphics.screens"), or null: then the
## screen keeps the plain standby text.
func _led(glass: MeshInstance3D, kind: String, text: String) -> Node3D:
	var gfx := Modules.bus("graphics")
	if gfx == null or not gfx.has_method("led_screen"):
		return null
	var made: Variant = gfx.call("led_screen", glass, kind, text)
	return made as Node3D


## Screens on or off with the ship's power.
func show_power(on: bool) -> void:
	for led: Node3D in leds:
		if is_instance_valid(led):
			led.call("set_on", on)


## Standby text in the top left of a screen's glass (a quad facing its +Z).
func _standby(glass: MeshInstance3D, text: String, size: int) -> void:
	var quad := (glass.mesh as QuadMesh).size if glass.mesh is QuadMesh else Vector2(0.6, 0.4)
	var label := Label3D.new()
	label.text = text
	label.font = ShipKit.mono_font()
	label.font_size = size
	label.pixel_size = 0.0015
	label.modulate = SCREEN_TEXT
	label.outline_size = 0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.transform = glass.transform * Transform3D(Basis(), Vector3(-quad.x * 0.5 + 0.03, quad.y * 0.5 - 0.025, 0.003))
	body.add_child(label)
	screens.append(label)


## The floodlights from `layout.floodlights`: a housing with a lit lens and a spotlight each.
func _floodlights() -> void:
	for f: Dictionary in file.get("layout", {}).get("floodlights", []):
		var at := VsShipImport.vec3(f.get("at", [0, 0, 0]))
		var dir := VsShipImport.vec3(f.get("aim", [0, 0, -1])).normalized()
		var aim := _toward(dir)
		_add(PartShapes.frustum(0.22, 0.3, 0.32, 12), Transform3D(aim, at - dir * 0.16), hull_dark)
		_add(PartShapes.prism(12, 0.26, 0.03), Transform3D(aim, at + dir * 0.005), ShipKit.glow(Color(1.0, 0.97, 0.9), 4.0))
		var spot := SpotLight3D.new()
		spot.light_color = Color(1.0, 0.96, 0.88)
		spot.light_energy = 4.0
		spot.spot_range = 30.0
		spot.spot_angle = 24.0
		spot.spot_angle_attenuation = 0.9
		spot.shadow_enabled = false
		spot.transform = Transform3D(Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.9 else Vector3.BACK), at + dir * 0.1)
		body.add_child(spot)
		spots.append(spot)


## The navigation lamps where the file's exterior lights are: a small dark base and a lit
## dome in the light's colour.
func _nav_lamps() -> void:
	for l: Dictionary in file.get("lights", []):
		if str(l.get("group", "")) != "exterior":
			continue
		var at := VsShipImport.vec3(l.get("at", [0, 0, 0]))
		var c := VsShipImport.color(l.get("color", [1, 1, 1]))
		var out := Vector3(signf(at.x), 0, 0) if absf(at.x) > 0.5 else Vector3.UP
		var aim := _toward(out)
		_add(PartShapes.prism(10, 0.07, 0.04), Transform3D(aim, at - out * 0.05), hull_dark)
		_add(PartShapes.dome(0.05, 0.05, 12, 3), Transform3D(aim, at - out * 0.03), ShipKit.glow(c, 3.0))


# --- helpers ---------------------------------------------------------------------------------

## A basis whose +Y points along `dir`.
static func _toward(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))


func _add(shape: PartShapes.PartShape, xform: Transform3D, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = shape.mesh
	mi.transform = xform
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	return mi
