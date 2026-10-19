class_name PartJointSpec
extends Resource
## One joint BSX makes to fit a part: where it sits and what it takes. It mirrors Void
## Salvage's ConnectionData, so a joint fitted here is one its tools can take apart.
## Positions are in the part's own space (as its shape builder makes it), metres.

## ConnectionData.Kind: WELD, RIVET, BOLT or CONNECTOR.
@export var kind := ConnectionData.Kind.BOLT
## The exposed head (bolts, rivets), the seam's middle (welds) or the plug (connectors).
@export var at := Vector3.ZERO
## Out of the surface for bolts and rivets, across the seam for welds.
@export var normal := Vector3.UP
## Welds only: one direction along the seam, and its size along it (x) and across (y), metres.
@export var seam_up := Vector3.ZERO
@export var seam_size := Vector2.ZERO
## Bolts and rivets: a FastenerSpec id.
@export var fastener := ""
## Connectors: what it carries ("power", "data", "coolant", "fuel").
@export var port := ""


## A Void Salvage joint built from this spec, for the two part ids it holds together.
## `to_structure` takes the spec from part space into the owning structure's space.
func to_connection(id: int, part_a: int, part_b: int,
		to_structure := Transform3D.IDENTITY) -> ConnectionData:
	var c := ConnectionData.new(id, kind, part_a, part_b, to_structure * at,
			to_structure.basis * normal)
	c.seam_up = (to_structure.basis * seam_up).normalized()
	c.seam_size = seam_size
	return c
