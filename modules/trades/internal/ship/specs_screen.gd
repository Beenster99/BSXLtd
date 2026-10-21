class_name TradesSpecsScreen
extends VBoxContainer
## The wrist screen's Specs channel (beenster, 0.3.7: "the required torque is provided by
## inspecting the spec, and available on the player's wrist HUD"): the joint you're looking
## at and what its tool should be set to, then every fastener on the ship in the bay with its
## torque window or rivet head height.

const T := preload("res://modules/ui/api/terminal_kit.gd")

var _glass := false


func _init(glass := false) -> void:
	_glass = glass
	name = "TradesSpecs"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)


func _ready() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	var rig := get_tree().current_scene.get_node_or_null(TradesBus.YARD_RIG) as TradesBay if get_tree().current_scene else null
	var station := rig.ship_station() if rig else null
	# The joint under the aim, if any.
	if station and station.aimed >= 0:
		var f := station.points[station.aimed]
		var d := T.docket("Looking at", f.joint_id, _glass)
		add_child(d.panel)
		var col: VBoxContainer = d.body
		col.add_child(T.label("%s %s" % [f.spec, f.kind], "display_bold", 30, T.TEXT if _glass else T.INK))
		col.add_child(T.label(setting_text(f.kind, f.spec), "mono_medium", 22, T.ORANGE))
	# Every fastener on the ship, by spec.
	add_child(T.columns([["FASTENER", 0], ["JOINTS", 110], ["SET THE TOOL TO", 260]]))
	var rows := T.list()
	add_child(rows.get_parent())
	var counts := {}
	if bus and bus.ship:
		for slot in bus.get_slots():
			for f in bus.get_fasteners(slot.slot_id):
				if f.kind == "bolt" or f.kind == "rivet":
					var key := "%s|%s" % [f.kind, f.spec]
					counts[key] = int(counts.get(key, 0)) + 1
	if counts.is_empty():
		rows.add_child(T.label("No ship in the bay.", "body_medium", 19, T.DIM))
		return
	var keys := counts.keys()
	keys.sort()
	var alt := false
	for key: String in keys:
		var kind := key.get_slice("|", 0)
		var spec := key.get_slice("|", 1)
		rows.add_child(T.row([T.cell_text(spec, kind), T.cell(str(counts[key]), 110),
				T.cell(setting_text(kind, spec), 260, T.TEXT)], alt, _glass))
		alt = not alt


## What the tool is set to for a fastener: "80-95 N m" for a bolt, "head 2.0 mm" for a rivet.
static func setting_text(kind: String, spec: String) -> String:
	if kind == "bolt":
		var nm := TradesShipJoints.torque_range(spec)
		return "%d-%d N m" % [roundi(nm.x), roundi(nm.y)]
	if kind == "rivet":
		return "head %.1f mm" % TradesShipJoints.head_target_mm(spec)
	return "-"
