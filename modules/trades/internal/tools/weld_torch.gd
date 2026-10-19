class_name TradesWeldTorch
extends TradesTool
## MIG torch on its hose: a copper nozzle, a bent swan neck and an orange handle with the
## trigger. The welder's settings show on the machine on the bench.
##
## Its own space: the nozzle's tip at the origin pointing down -Y, the neck straight up +Y,
## then the handle rising back at 45 degrees toward +Z.

const GRIP := Vector3(0, 0.1245, 0.0495)

## The arc is lit (the wire tip glows).
var lit := false

var _tip: MeshInstance3D
var _wire: Material
var _hot: Material


func _ready() -> void:
	name = "WeldTorch"
	grip = GRIP
	hold = Transform3D(Basis(Vector3.RIGHT, -PI * 0.25), Vector3(0, -0.02, 0))
	var copper := TradesLook.metal(Color(0.78, 0.45, 0.28), 0.9, 0.3)
	var dark := dark()
	var body := body()
	_wire = steel()
	_hot = TradesLook.glow(Color(1.0, 0.85, 0.6), 6.0)
	_tip = cylinder(0.0008, 0.008, Vector3(0, 0.002, 0), Vector3.ZERO, _wire, 6)        # wire stick-out
	var up45 := Vector3(PI * 0.25, 0, 0)
	var bend := Vector3(0, 0.075, 0)
	var along := Vector3(0, 0.7071, 0.7071)
	cylinder(0.007, 0.035, Vector3(0, 0.022, 0), Vector3.ZERO, copper, 14, self, 0.01)    # nozzle
	cylinder(0.009, 0.04, Vector3(0, 0.058, 0), Vector3.ZERO, dark, 12)                   # swan neck
	cylinder(0.0085, 0.03, bend + along * 0.012, up45, dark, 12)
	cylinder(0.016, 0.11, bend + along * 0.07, up45, body, 14)                            # handle
	box(Vector3(0.008, 0.02, 0.014), bend + along * 0.06 + Vector3(0, -0.012, 0.012), dark, up45)  # trigger
	cylinder(0.012, 0.03, bend + along * 0.14, up45, dark, 12)                            # hose collar
	cylinder(0.009, 0.1, bend + along * 0.2, up45, dark, 10)                              # hose


func _process(delta: float) -> void:
	_tip.material_override = _hot if lit else _wire
	super(delta)
