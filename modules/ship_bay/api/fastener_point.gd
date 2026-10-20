class_name FastenerPoint
extends Resource
## One joint that holds a part in its mount slot: where it is and what makes it. Trades
## makes and breaks these and tells Ship and Bay by joint_id (ShipBayBus.note_joint_made /
## note_joint_removed).

## "<slot_id>/<n>", for example "eng_aft_port_1/b3". The part before "/" names the slot.
@export var joint_id := ""
## "bolt", "rivet", "weld" or "connector" (Void Salvage's ConnectionData kinds, lower case).
@export var kind := "bolt"
## A Shared Components FastenerSpec id ("M12", "RIVET_4"); for connectors what it carries
## ("power", "data", "coolant", "fuel").
@export var spec := ""
## Ship space, metres: the head (bolts, rivets), the seam's middle (welds) or the plug.
@export var position := Vector3.ZERO
## Out of the surface the joint sits on, ship space.
@export var normal := Vector3.UP
## Welds only: one direction along the seam (ship space), and the bead's length along it (x)
## and width across (y), metres. As Shared Components' PartJointSpec and Void Salvage's
## ConnectionData have them.
@export var seam_up := Vector3.ZERO
@export var seam_size := Vector2.ZERO


static func slot_of(id: String) -> String:
	return id.get_slice("/", 0)
