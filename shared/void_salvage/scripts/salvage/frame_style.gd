class_name FrameStyle
extends RefCounted
## How a frame-first hull is framed (docs/SHIP_FRAME_PLAN.md 4.2): its members' sections,
## how they meet at the corners, where the stringers run, what the welds look like and how
## the skin is fastened. FrameHull reads a style by id. Static data, append only: BSX keeps
## the ids it knows.
##
## Sizes in metres. `member` is (width along the ship, height out of the hull); `node` the
## block a node-cornered frame's members are welded to; `bead` a weld's head style
## (ConnectionData.head: YARD, MACHINE, GROUND); `rivet_pitch`/`bolt_pitch` the spacing of the
## fasteners in a row where a plate or panel crosses a member (decisions 2 and 3 of the plan:
## wide first, tightened only if plates look under-held).

## Weld beads (ConnectionData.head on a WELD): the wrecks' rippled bead, a low even bead
## with tight ripples (the neat seam), a bead ground flush (a hairline).
const YARD: int = 0
const MACHINE: int = 2
const GROUND: int = 3

## id -> style. `corners`: "node" (members end on node blocks, welded all round their ends)
## or "mitre" (members mitred to each other, welded at the cut). `stringers`: "corners" (one
## along every profile corner, the nodes' lines) or "spacing" (one per `stringer_spacing`
## of side). FrameHull builds "kestrel" (the frame Kestrel) and "mitred" (every wreck, as
## SalvageHull); "channel" and "lattice" wait for the Manta and the XL ships.
## `lining_inset`/`lining_thickness`: where inner panels stand off the frame and how thick.
const STYLES: Dictionary = {
	"kestrel": {"member": Vector2(0.14, 0.18), "skin": 0.08, "node": 0.26, "corners": "node",
			"stringers": "corners", "stringer": Vector2(0.14, 0.18), "bead": MACHINE,
			"rivet_pitch": 1.0, "bolt_pitch": 1.0, "lining_inset": 0.12, "lining_thickness": 0.03},
	"mitred": {"member": Vector2(0.16, 0.22), "skin": 0.04, "node": 0.0, "corners": "mitre",
			"stringers": "spacing", "stringer": Vector2(0.14, 0.14), "stringer_spacing": 2.6, "bead": YARD,
			"rivet_pitch": 1.0, "bolt_pitch": 1.0, "lining_inset": 0.08, "lining_thickness": 0.03},
	"channel": {"member": Vector2(0.16, 0.22), "skin": 0.08, "node": 0.26, "corners": "node",
			"stringers": "corners", "stringer": Vector2(0.16, 0.22), "bead": MACHINE,
			"rivet_pitch": 1.0, "bolt_pitch": 1.0, "lining_inset": 0.12, "lining_thickness": 0.03},
	"lattice": {"member": Vector2(0.2, 0.3), "skin": 0.06, "node": 0.34, "corners": "node",
			"stringers": "corners", "stringer": Vector2(0.2, 0.3), "bead": YARD,
			"rivet_pitch": 1.0, "bolt_pitch": 1.0, "lining_inset": 0.12, "lining_thickness": 0.03},
}


## The style `id` (the kestrel style if there is none by that name).
static func of(id: String) -> Dictionary:
	return STYLES.get(id, STYLES["kestrel"])
