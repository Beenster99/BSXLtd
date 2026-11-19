extends Node3D
## Where the stores' and the yard's bots go home to charge (0.4.4 playtest: "drones should home
## on charger racks"; flag yard.charger_racks). Before, an idle bot hovered at a spot in the
## air. Now each one has its own pad and settles on it with its fans stopped.
## The pad's strip glows when its bot is home, in the bot's colour.
##   - The stores' ten (orange) sit on a wall rack in goods in's well, up on the back wall over
##     the GOODS IN sign. There are two rows, the upper one further out, so a bot rising from
##     the lower row clears the one above it.
##   - The yard's six (teal) sit on an apron that juts out from the hall floor's edge, just
##     outside the open face, beside the build berth.
## Presentation and places only: StoresTraffic reads `home(i, yard)` for each bot's home.

const Kit := preload("res://modules/yard/internal/yard_kit.gd")

## The stores' rack: back wall z, the two rows' pad tops (m), each row's x and how far out
## its pads stand (the pad's middle, from the wall).
const WALL_Z := -4.0
const ROWS_Y := [18.0, 22.0]
const ROWS_OUT := [1.3, 3.7]
const LOWER_X := [65.4, 69.0, 72.6, 76.2, 79.8]
const UPPER_X := [67.2, 70.8, 74.4, 78.0, 81.6]
## Each pad's two arms (and rails) either side of its middle (m). The rows are 1.8 m apart in
## x, so a bot (2.1 m across its fans) rising from the lower row passes between the arms above.
const ARM_X := 0.6
## The yard's apron: from the hall floor's edge (z) out by APRON_DEPTH, and its top.
const FACE_Z := -64.0
const APRON_DEPTH := 4.4
const APRON_TOP := -0.3
const APRON_X := Vector2(15.0, 51.0)
## A pad (m), and how far a bot's middle sits over a pad's top (its skids reach 0.2 under).
const PAD := Vector3(2.1, 0.08, 2.2)
const SIT := 0.2
## A bot this close to its home (m) is on its pad: charging.
const HOME_NEAR := 0.05

var _strips: Array[StandardMaterial3D] = []   # by bot index, stores then yard
var _stores := 0


## Where bot `i` (counted over the stores' then the yard's, as StoresTraffic does) lives.
static func home(i: int, yard: bool) -> Vector3:
	if yard:
		var k := i % 6
		return Vector3(18.0 + float(k) * 6.0, APRON_TOP + PAD.y + SIT, FACE_Z - APRON_DEPTH * 0.5)
	var row := i % 2
	var col := (i / 2) % 5
	var x: float = LOWER_X[col] if row == 0 else UPPER_X[col]
	return Vector3(x, float(ROWS_Y[row]) + SIT, WALL_Z - float(ROWS_OUT[row]))


## Builds both racks for `stores` stores bots and `yard` yard bots, in their colours.
func build(stores: int, yard: int, stores_colour: Color, yard_colour: Color) -> void:
	name = "ChargerRacks"
	_stores = stores
	var k := Kit.new(self, "RackBody")
	var steel := k.paint(Kit.STEEL, 0.8, 0.4)
	var dark := k.paint(Kit.DARK, 0.3, 0.6)
	var deck := k.paint(Kit.DECK, 0.5, 0.55, "tread_diamond_steel")
	# The stores' wall rack: a pair of rails up the wall for each pad, the pad on a bracket.
	for i in stores:
		var at := home(i, false)
		var top := at.y - SIT
		var out := WALL_Z - at.z
		for side: float in [-1.0, 1.0]:
			k.box(Vector3(0.14, 3.2, 0.12), Vector3(at.x + side * ARM_X, top - 1.1, WALL_Z - 0.06), steel, false)
			# Arm out to the pad's far edge, braced down to the rail.
			k.box(Vector3(0.12, 0.14, out + PAD.z * 0.5), Vector3(at.x + side * ARM_X, top - PAD.y - 0.07, WALL_Z - (out + PAD.z * 0.5) * 0.5), steel, false)
			k.span(Vector3(at.x + side * ARM_X, top - 2.5, WALL_Z - 0.1), Vector3(at.x + side * ARM_X, top - 0.2, at.z - PAD.z * 0.3), steel, false)
		_pad(k, at, dark, stores_colour, "StoresPad%d" % i)
		# The charge lead: a dark box on the wall behind the pad.
		k.box(Vector3(0.6, 0.4, 0.16), Vector3(at.x, top + 0.35, WALL_Z - 0.08), dark, false)
	k.sign("CHARGING", Vector3((LOWER_X[0] + UPPER_X[4]) * 0.5, float(ROWS_Y[1]) + 3.4, WALL_Z - 0.12), Vector3.FORWARD, 0.02, Kit.ORANGE, 96)
	# The yard's apron off the hall floor: a tread deck, an edge rail, its pads.
	var mid := Vector3((APRON_X.x + APRON_X.y) * 0.5, APRON_TOP - 0.2, FACE_Z - APRON_DEPTH * 0.5)
	k.box(Vector3(APRON_X.y - APRON_X.x, 0.4, APRON_DEPTH), mid, deck)
	k.box(Vector3(APRON_X.y - APRON_X.x, 0.12, 0.12), Vector3(mid.x, APRON_TOP + 0.06, FACE_Z - APRON_DEPTH + 0.06), dark, false)
	for x in range(int(APRON_X.x) + 2, int(APRON_X.y), 6):
		k.span(Vector3(float(x), APRON_TOP - 0.4, FACE_Z - APRON_DEPTH + 0.3), Vector3(float(x), APRON_TOP - 2.6, FACE_Z - 0.2), steel, false)
	for i in yard:
		_pad(k, home(stores + i, true), dark, yard_colour, "YardPad%d" % i)


## A pad under a bot's home: a dark plate, a contact block and a strip along its front.
func _pad(k: Kit, at: Vector3, dark: Material, colour: Color, pad_name: String) -> void:
	var top := at.y - SIT
	k.box(PAD, Vector3(at.x, top - PAD.y * 0.5, at.z), dark, false, null, pad_name)
	k.box(Vector3(0.36, 0.05, 0.36), Vector3(at.x, top + 0.025, at.z), k.paint(Kit.STEEL, 0.9, 0.3), false)
	var strip := StandardMaterial3D.new()
	strip.albedo_color = colour.darkened(0.6)
	strip.emission_enabled = true
	strip.emission = colour
	strip.emission_energy_multiplier = 0.3
	k.box(Vector3(PAD.x - 0.2, 0.04, 0.08), Vector3(at.x, top + 0.02, at.z - PAD.z * 0.5 + 0.1), strip, false)
	_strips.append(strip)


## Lights each pad's strip while its bot sits on it (`bots`: StoresTraffic's bot entries).
func show_charging(bots: Array) -> void:
	for b: Dictionary in bots:
		if b.has("hauler"):
			continue
		var i := int(b.index)
		if i < 0 or i >= _strips.size():
			continue
		var home_at: Vector3 = b.home
		var on := (b.node as Node3D).position.distance_to(home_at) < HOME_NEAR and (b.job as Array).is_empty()
		_strips[i].emission_energy_multiplier = 2.5 if on else 0.3


## True when this bot is home on its pad (its fans idle down).
static func docked(b: Dictionary) -> bool:
	return not b.has("hauler") and (b.node as Node3D).position.distance_to(b.home) < HOME_NEAR and (b.job as Array).is_empty()
