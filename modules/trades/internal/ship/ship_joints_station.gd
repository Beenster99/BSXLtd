class_name TradesShipJoints
extends TradesStation
## The work on the ship itself, in the shipyard: every joint Ship and Bay lists on the loaded
## ship (FastenerPoint: bolts, rivets, welds, connectors), worked with whichever tool is in
## your hand. Aim at a joint within reach and it lights up; then
##
##   bolt       torque wrench: hold left click and pull the mouse back until it clicks;
##              right click (hold) breaks it loose
##   rivet      squeezer: hold left click to set it; drill: hold left click to drill it out
##   weld       welder: hold left click to lay it; hold right click to cut it out (unweld)
##   connector  hands or crimper: left click plugs it, right click unplugs it
##
## Ship and Bay hears about every joint made or taken off (note_joint_made/removed) and keeps
## the slot's state: take every joint off a part and the part comes off; hands on one of its
## joints puts it back in place, ready to fasten again. The station has no bench: `bay` is
## the yard rig (TradesBay in the yard).

## How close the aim has to pass a joint to pick it (metres).
const PICK_M := 0.09
## Seconds of holding for each job.
const SQUEEZE_S := 0.8
const DRILL_S := 1.2
const WELD_S := 2.0
const BREAK_S := 0.6
## Cutting a weld out takes longer than laying it.
const CUT_S := 2.5
const PLUG_S := 0.3
## Torque per pixel of pulling the mouse back (N m).
const NM_PER_PX := 0.35
## The torch's tilt off the surface's normal while welding (degrees).
const TORCH_TILT_DEG := 20.0
## The torch turned off the line back to the worker, so it isn't in front of the view (radians).
const TORCH_TURN := 0.9
const KIND_TOOLS := {
	"bolt": [&"torque_wrench"],
	"rivet": [&"rivet_squeezer", &"drill"],
	"weld": [&"welder"],
	"connector": [&"hands", &"wire_tool"],
}
const KIND_HELP := {
	"bolt": "torque wrench (2)",
	"rivet": "squeezer (4) to set, drill (3) to drill out",
	"weld": "welder (5): left click welds, right click cuts it",
	"connector": "hands (1) or crimper (6)",
}

## Ship space to this station's world: set from the yard on every ship_loaded.
var ship_xform := Transform3D.IDENTITY
## The loaded ship's joints and where each one is in the world.
var points: Array[FastenerPoint] = []
var points_world: PackedVector3Array = []
## The joint under the aim (index into points), or -1.
var aimed := -1

var _bus: ShipBayBus
var _working := -1
var _undoing := false
var _tool_held: StringName = &""
var _held_s := 0.0
var _pull_px := 0.0
var _clicked := false
## A screenshot holds the job where it is.
var _frozen := false
## slot_id -> the component that came off it (so hands can put it back).
var _removed: Dictionary = {}
var _marker: MeshInstance3D
## The tractor beam (tool 7), for lifting parts that are off the ship.
var tractor: TradesTractor
var _arc: OmniLight3D


func build() -> void:
	title = "Ship"
	_bus = Modules.bus("ship_bay") as ShipBayBus
	if _bus:
		_bus.ship_loaded.connect(func(_id: String) -> void: refresh_points())
		_bus.ship_unloaded.connect(func(_id: String) -> void: refresh_points())
		_bus.component_removed.connect(func(slot_id: String, comp: String) -> void: _removed[slot_id] = comp)
		_bus.component_positioned.connect(func(slot_id: String, _c: String) -> void: _removed.erase(slot_id))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.028
	ring.outer_radius = 0.036
	ring.rings = 24
	ring.ring_segments = 8
	ring.material = TradesLook.glow(TradesLook.HUD, 2.5)
	_marker = MeshInstance3D.new()
	_marker.mesh = ring
	_marker.top_level = true
	_marker.visible = false
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)
	_arc = OmniLight3D.new()
	_arc.light_color = Color(0.7, 0.85, 1.0)
	_arc.omni_range = 3.0
	_arc.top_level = true
	_arc.visible = false
	add_child(_arc)
	tractor = TradesTractor.new()
	tractor.name = "Tractor"
	tractor.station = self
	add_child(tractor)
	refresh_points()


## Read the loaded ship's joints again (after a ship loads, or the ship moved).
func refresh_points() -> void:
	points.clear()
	points_world.clear()
	if _bus == null or _bus.ship == null:
		return
	for slot in _bus.get_slots():
		for f in _bus.get_fasteners(slot.slot_id):
			points.append(f)
			points_world.append(ship_xform * f.position)
	aimed = -1


func tools() -> Array[StringName]:
	if tractor.is_holding():
		return [&"tractor"]
	if aimed < 0:
		return bay.hotbar
	var useful: Array[StringName] = []
	useful.assign(KIND_TOOLS.get(points[aimed].kind, []))
	return useful


func status_line() -> String:
	if bay.tool == &"tractor":
		return tractor.status_line()
	if aimed < 0:
		return "Ship: %d joints, %d tight" % [points.size(), _tight_count()] if not points.is_empty() else ""
	var f := points[aimed]
	var line := "%s  %s %s  %s" % [f.joint_id.to_upper(), f.spec.to_upper(), f.kind.to_upper(), _state_word(f)]
	if f.kind == "bolt":
		var nm := torque_range(f.spec)
		line += "  [%d-%d N m]" % [roundi(nm.x), roundi(nm.y)]
	return line


func start_hint() -> String:
	return "Walk up to the ship and aim at a bolt, rivet, weld or plug. Mouse wheel picks the tool."


func is_busy() -> bool:
	return _working >= 0 or tractor.is_holding()


## The torque range (N m) for a bolt spec from Shared Components' fastener specs, or a
## sensible default. Shared Components is optional here (not in depends_on, so the modules
## that load Tools don't all need it), hence the untyped calls.
static func torque_range(spec_id: String) -> Vector2:
	var shared: Node = Modules.bus("shared_components")
	var spec: Object = shared.call("fastener", spec_id) if shared and shared.has_method("fastener") else null
	var nm: Variant = spec.get("torque_nm") if spec else null
	if nm is Vector2 and (nm as Vector2).y > 0.0:
		return nm
	return Vector2(40.0, 60.0)


# --- Input --------------------------------------------------------------------------------

func press(tool: StringName) -> void:
	if tool == &"tractor":
		tractor.press()
		return
	if aimed < 0:
		return
	var f := points[aimed]
	if _slot_empty(f):
		if tool == &"hands":
			_refit(f)
		else:
			bay.hint("The part is off. Hands (1) on one of its joints puts it back.")
		return
	var tight := _bus.is_joint_tight(f.joint_id)
	if not (KIND_TOOLS[f.kind] as Array).has(tool):
		bay.hint("That's a %s: %s." % [f.kind, KIND_HELP[f.kind]])
		return
	if tool == &"drill":
		if not tight:
			bay.hint("Nothing to drill out: this rivet hole is empty. Squeezer (4) sets a new one.")
			return
		_begin(true, tool)
	elif tight:
		bay.hint("Already %s. Right click takes it off." % _state_word(f).to_lower())
	elif _first_joint(f) and tractor.blocks_first_joint(FastenerPoint.slot_of(f.joint_id)):
		bay.hint("The beam holding this part has it out of line. Its first joint waits until it's in line.")
	else:
		_begin(false, tool)


func release() -> void:
	tractor.release()
	if _working < 0:
		return
	if not _undoing and points[_working].kind == "bolt" and not _clicked:
		bay.hint("Not torqued yet: hold left click and pull back until it clicks.")
	_stop()


func back_out(tool: StringName) -> void:
	if tool == &"tractor":
		if not tractor.park():
			bay.hint("Right click parks a part you're holding in the beam.")
		return
	if aimed < 0 or _working >= 0:
		return
	var f := points[aimed]
	if not _bus.is_joint_tight(f.joint_id):
		bay.hint("Nothing to take off here.")
		return
	match f.kind:
		"bolt":
			if tool != &"torque_wrench":
				bay.hint("Breaking a bolt loose takes the torque wrench (2).")
				return
		"rivet":
			if tool != &"drill":
				bay.hint("Rivets come out with the drill (3).")
				return
		"weld":
			if tool != &"welder":
				bay.hint("Cut a weld out with the welder (5).")
				return
			if not Flags.is_on("trades.unweld"):
				bay.hint("Cutting welds isn't switched on yet.")
				return
		"connector":
			if tool != &"hands" and tool != &"wire_tool":
				bay.hint("Unplug it with your hands (1).")
				return
	_begin(true, tool)


## Wheel while the beam holds a part: pull it in or push it out.
func turn_held(step: int, _snap: bool) -> bool:
	return tractor.push(step)


## Q / E: turn the part in the beam.
func adjust(step: int) -> bool:
	return tractor.turn(step)


func motion(relative: Vector2) -> bool:
	if tractor.is_holding() and InputMap.has_action(TradesBus.KEY_ROTATE) and Input.is_action_pressed(TradesBus.KEY_ROTATE):
		return tractor.rotate_by(relative)
	if _working < 0 or _undoing or points[_working].kind != "bolt":
		return false
	_pull_px = maxf(0.0, _pull_px + relative.y)
	return true


func update(delta: float) -> void:
	tractor.update(delta)
	if _working < 0 and not tractor.is_holding():
		_update_aim()
	_place_marker()
	_arc.visible = false
	if _working < 0:
		return
	var f := points[_working]
	var at := points_world[_working]
	var n := (ship_xform.basis * f.normal).normalized()
	var hand := bay.worker.right_hand
	if not hand.can_reach(at):
		bay.hint("Too far: step closer to the ship.")
		_stop()
		return
	if not _frozen:
		_held_s += delta
	var bus := bay.bus()
	if f.kind == "bolt" and not _undoing:
		_work_bolt(f, at, n)
	else:
		var need := _seconds(f.kind)
		var tool := _place(f.kind, at, n, clampf(_held_s / need, 0.0, 1.0))
		if tool != &"":
			hand.reach_to(_grip_point(tool, at, n), n)
			hand.set_grip(1.0)
		if bus:
			bus.joint_progress.emit(StringName(f.joint_id), clampf(_held_s / need, 0.0, 1.0))
		if _held_s >= need:
			_finish(f)


func _work_bolt(f: FastenerPoint, at: Vector3, n: Vector3) -> void:
	var nm := torque_range(f.spec)
	var target := (nm.x + nm.y) * 0.5
	var wrench := bay.tool_node(&"torque_wrench") as TradesTorqueWrench
	wrench.set_nm = target
	wrench.applied_nm = _pull_px * NM_PER_PX
	var share := clampf(wrench.applied_nm / target, 0.0, 1.6)
	var xform := _on_surface(at, n, deg_to_rad(35.0 - share * 25.0))
	bay.place_tool(&"torque_wrench", xform)
	bay.worker.right_hand.reach_to(xform * TradesTorqueWrench.GRIP + n * 0.02, n)
	bay.worker.right_hand.set_grip(1.0)
	var bus := bay.bus()
	if bus:
		bus.joint_progress.emit(StringName(f.joint_id), clampf(share, 0.0, 1.0))
	if not _clicked and wrench.applied_nm >= target:
		_clicked = true
		wrench.click()
		bay.play(&"click")
		bay.worker.kick(0.01)
		# Pulled on past the click: the further over the range, the worse the joint.
		var over := maxf(0.0, wrench.applied_nm - nm.y) / maxf(1.0, nm.y)
		_made(f, 1.0 - clampf(over * 4.0, 0.0, 0.5))
		bay.hint("Click. %s torqued to %d N m." % [f.spec, roundi(target)])


# --- Doing the work -------------------------------------------------------------------------

func _begin(undo: bool, tool: StringName) -> void:
	_working = aimed
	_undoing = undo
	_tool_held = tool
	_held_s = 0.0
	_pull_px = 0.0
	_clicked = false
	bay.worker.look_locked = points[_working].kind == "bolt" and not undo
	var bus := bay.bus()
	if bus and not undo:
		bus.joint_started.emit(StringName(points[_working].joint_id), StringName(points[_working].kind), 1)
	match points[_working].kind:
		"bolt":
			bay.hint("Breaking it loose..." if undo else "Pull the mouse back until the wrench clicks.")
		"rivet":
			bay.hint("Drilling it out..." if undo else "Squeezing...")
		"weld":
			bay.hint("Cutting the weld out..." if undo else "Laying the bead...")
		"connector":
			bay.hint("Unplugging..." if undo else "Plugging in...")


func _finish(f: FastenerPoint) -> void:
	if _undoing:
		if _bus.note_joint_removed(f.joint_id):
			var bus := bay.bus()
			if bus:
				bus.remove_joint(StringName(f.joint_id))
			bay.play(&"clunk", 1.1)
			bay.hint("%s off.%s" % [f.kind.capitalize(), " The part is free." if _slot_empty(f) else ""])
	else:
		_made(f, 1.0)
		bay.play(&"clunk" if f.kind != "connector" else &"click")
	_stop()


func _made(f: FastenerPoint, quality: float) -> void:
	if _bus.note_joint_made(f.joint_id, quality) and f.kind != "bolt":
		bay.hint("%s done." % f.kind.capitalize())


## Hands put a part that came off back in its slot.
func _refit(f: FastenerPoint) -> void:
	var slot_id := FastenerPoint.slot_of(f.joint_id)
	if not tractor.near_mount(slot_id):
		bay.hint("The part isn't at its mount. Bring it back with the tractor beam (7).")
		return
	var comp: String = _removed.get(slot_id, "")
	if comp == "":
		var slot := _bus.get_slot(slot_id)
		comp = slot.fitted if slot else ""
	if comp != "" and _bus.try_position(slot_id, comp):
		bay.play(&"clunk", 0.8)
		bay.hint("Part back in place. Fasten its joints to install it.")
	else:
		bay.hint("Nothing to put back here.")


func _stop() -> void:
	_frozen = false
	_working = -1
	_undoing = false
	_pull_px = 0.0
	for id: StringName in [&"drill", &"welder"]:
		var t := bay.tool_node(id)
		if t is TradesDrill:
			(t as TradesDrill).spin = 0.0
		elif t is TradesWeldTorch:
			(t as TradesWeldTorch).lit = false
			(t as TradesWeldTorch).cutting = false
	var squeezer := bay.tool_node(&"rivet_squeezer") as TradesRivetSqueezer
	if squeezer:
		squeezer.closed = 0.0
	var wrench := bay.tool_node(&"torque_wrench") as TradesTorqueWrench
	if wrench:
		wrench.applied_nm = 0.0
	bay.loop(&"drill", false)
	bay.loop(&"arc", false)
	if bay.worker:
		bay.worker.look_locked = false
		bay.worker.right_hand.come_back()
		bay.worker.left_hand.come_back()


func _seconds(kind: String) -> float:
	if _undoing:
		return {"bolt": BREAK_S, "rivet": DRILL_S, "weld": CUT_S, "connector": PLUG_S}.get(kind, 1.0)
	return {"rivet": SQUEEZE_S, "weld": WELD_S, "connector": PLUG_S}.get(kind, 1.0)


## Puts the tool in use on the joint (progress 0..1) and returns its id ("" for hands).
func _place(kind: String, at: Vector3, n: Vector3, progress: float) -> StringName:
	match _tool_held:
		&"torque_wrench":
			bay.place_tool(&"torque_wrench", _on_surface(at, n, deg_to_rad(35.0 + progress * 30.0)))
			return &"torque_wrench"
		&"drill":
			var drill := bay.tool_node(&"drill") as TradesDrill
			drill.spin = 1.0
			bay.loop(&"drill", true)
			bay.place_tool(&"drill", _on_surface(at - n * progress * 0.006, n, 0.0))
			return &"drill"
		&"rivet_squeezer":
			(bay.tool_node(&"rivet_squeezer") as TradesRivetSqueezer).closed = progress
			bay.place_tool(&"rivet_squeezer", _on_surface(at, n, 0.0))
			return &"rivet_squeezer"
		&"welder":
			var torch := bay.tool_node(&"welder") as TradesWeldTorch
			torch.lit = true
			torch.arc_mm = 3.0
			torch.cutting = _undoing
			torch.cut = progress if _undoing else 0.0
			var xform := _on_surface(at, n, TORCH_TURN) * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(TORCH_TILT_DEG)))
			bay.place_tool(&"welder", xform)
			bay.loop(&"arc", true, 0.9 + randf() * 0.2)
			_arc.global_position = at + n * 0.05
			_arc.light_energy = 1.0 + randf() * 0.8
			_arc.visible = true
			return &"welder"
		&"wire_tool":
			bay.place_tool(&"wire_tool", _on_surface(at, n, 0.0))
			return &"wire_tool"
	# Hands on the plug.
	bay.worker.right_hand.reach_to(at + n * 0.01, n)
	bay.worker.right_hand.set_grip(0.4 + 0.6 * progress)
	return &""


## Tools sit on the work with +Y out of the surface and their handle (+Z) turned back
## toward the worker, then `turn` radians further round the normal.
func _on_surface(at: Vector3, n: Vector3, turn: float) -> Transform3D:
	var back := bay.worker.global_position + Vector3(0, 1.2, 0) - at
	back -= n * back.dot(n)
	if back.length() < 0.01:
		back = n.cross(Vector3.RIGHT) if absf(n.dot(Vector3.RIGHT)) < 0.9 else n.cross(Vector3.FORWARD)
	var z := back.normalized().rotated(n, turn)
	return Transform3D(Basis(n.cross(z), n, z).orthonormalized(), at)


func _grip_point(tool: StringName, at: Vector3, n: Vector3) -> Vector3:
	var t := bay.tool_node(tool)
	return t.global_transform * t.grip + n * 0.015 if t else at


# --- Inspect (hold Tab) ---------------------------------------------------------------------

const SLOT_STATES := {
	ShipBayBus.SlotState.FITTED: "FITTED", ShipBayBus.SlotState.LOOSENED: "LOOSENED",
	ShipBayBus.SlotState.EMPTY: "OFF THE SHIP", ShipBayBus.SlotState.POSITIONED: "IN PLACE, NOT FASTENED",
	ShipBayBus.SlotState.INSTALLED: "INSTALLED",
}


## The part (and joint) under the aim: a loose part, the part a joint holds on, or a part on
## the ship the aim passes through.
func inspect_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if _bus == null:
		return lines
	var joint: FastenerPoint = points[aimed] if aimed >= 0 else null
	var loose := tractor.held if tractor.held else tractor.aimed_part()
	var slot_id := ""
	if loose:
		slot_id = loose.slot_id
	elif joint:
		slot_id = FastenerPoint.slot_of(joint.joint_id)
	else:
		slot_id = tractor.aimed_slot()
	var slot := _bus.get_slot(slot_id) if slot_id != "" else null
	if slot == null:
		return lines
	var comp := _bus.get_component(slot_id)
	if comp == "":
		comp = loose.component if loose else String(_removed.get(slot_id, slot.fitted))
	var spec := _build_spec(comp)
	var title := slot.display_name if slot.display_name != "" else slot_id
	if spec and str(spec.get("display_name")) != "":
		title = str(spec.get("display_name"))
	lines.append(title.to_upper())
	lines.append("%-9s %s" % ["PART", comp if comp != "" else "-"])
	lines.append("%-9s %s" % ["SLOT", slot_id])
	lines.append("%-9s %s" % ["STATE", SLOT_STATES.get(_bus.get_slot_state(slot_id), "-")])
	var size := slot.box.size
	var mass := float(spec.get("mass")) if spec else 0.0
	if mass > 0.0:
		lines.append("%-9s %s" % ["MASS", _kg(mass)])
	else:
		lines.append("%-9s %s (est.)" % ["MASS", _kg(maxf(5.0, size.x * size.y * size.z * TradesLoosePart.DENSITY))])
	lines.append("%-9s %.2f x %.2f x %.2f m" % ["SIZE", size.x, size.y, size.z])
	if spec and str(spec.get("material")) != "":
		lines.append("%-9s %s" % ["MATERIAL", str(spec.get("material"))])
	# The joints holding it on, by kind and spec, and how many are in.
	var groups := {}
	for f in slot.fasteners:
		var key := "%s %s" % [f.kind, f.spec]
		var g: Array = groups.get_or_add(key, [0, 0, f])
		g[0] += 1
		if _bus.is_joint_tight(f.joint_id):
			g[1] += 1
	var first := true
	for key: String in groups:
		var g: Array = groups[key]
		var f: FastenerPoint = g[2]
		var what := "%d %s%s %s, %d in" % [g[0], f.kind, "" if g[0] == 1 else "s", f.spec, g[1]]
		if f.kind == "bolt":
			var nm := torque_range(f.spec)
			what += " (%d-%d N m)" % [roundi(nm.x), roundi(nm.y)]
		lines.append("%-9s %s" % ["JOINTS" if first else "", what])
		first = false
	if groups.is_empty():
		lines.append("%-9s none" % "JOINTS")
	if loose:
		var where := "in your beam" if loose == tractor.held else "hovering"
		if tractor.to_trolley.has(slot_id):
			where = "waiting for a trolley"
		lines.append("%-9s %s" % ["NOW", where])
	if joint:
		lines.append("")
		lines.append("%-9s %s  %s %s  %s" % ["JOINT", joint.joint_id, joint.spec, joint.kind, _state_word(joint)])
		lines.append("%-9s %s" % ["TOOL", KIND_HELP.get(joint.kind, "-")])
	if not slot.accepts.is_empty():
		lines.append("%-9s %s" % ["TAKES", ", ".join(slot.accepts)])
	return lines


## Shared Components' build spec for a component (mass, material, name), or null. Reached
## untyped: Shared Components is optional here.
static func _build_spec(component: String) -> Object:
	var shared: Node = Modules.bus("shared_components")
	if component == "" or shared == null or not shared.has_method("build_spec"):
		return null
	return shared.call("build_spec", component)


static func _kg(kg: float) -> String:
	return "%d kg" % roundi(kg) if kg < 1000.0 else "%.1f t" % (kg / 1000.0)


# --- Aim and marker ---------------------------------------------------------------------------

func _update_aim() -> void:
	var best := -1
	var best_d := PICK_M
	var hand := bay.worker.right_hand
	for i in points_world.size():
		var d := bay.aim_distance(points_world[i])
		if d < best_d and hand.can_reach(points_world[i]):
			best = i
			best_d = d
	if best != aimed:
		aimed = best
		# What the tool does to it is in the tips (actions); the old hint goes.
		bay.hint("")
		if aimed >= 0:
			# The wrench's screen and panel show the torque the bolt under the aim wants.
			var wrench := bay.tool_node(&"torque_wrench") as TradesTorqueWrench
			if wrench and points[aimed].kind == "bolt":
				var nm := torque_range(points[aimed].spec)
				wrench.set_nm = (nm.x + nm.y) * 0.5
		bay.refresh_hud()


## What the aim is on, for the tips' heading: "M12 bolt, tight", or "" for nothing.
func aim_title(tool: StringName) -> String:
	if tool == &"tractor":
		return tractor.aim_title()
	if aimed < 0:
		return ""
	var f := points[aimed]
	return "%s %s, %s" % [f.spec.to_upper(), f.kind, _state_word(f).to_lower()]


## The tips for the joint under the aim with `tool` in hand: what it does to it now, or
## which tool to take up for it.
func actions(tool: StringName) -> Array:
	if tool == &"tractor":
		return tractor.actions()
	if aimed < 0:
		return []
	var f := points[aimed]
	if _working >= 0:
		return [["Let go", "stop"]]
	if _slot_empty(f):
		return [[TradesBay.CLICK, "put the part back"]] if tool == &"hands" else [[bay.tool_action(&"hands"), "hands, to put the part back"]]
	var tight := _bus.is_joint_tight(f.joint_id)
	var out: Array = []
	match f.kind:
		"bolt":
			if tool == &"torque_wrench":
				out.append([TradesBay.HOLD_RIGHT, "break it loose"] if tight else [TradesBay.HOLD_CLICK + ", pull back", "torque it till it clicks"])
		"rivet":
			if tool == &"drill" and tight:
				out.append([TradesBay.HOLD_CLICK, "drill it out"])
			elif tool == &"rivet_squeezer" and not tight:
				out.append([TradesBay.HOLD_CLICK, "set a rivet"])
		"weld":
			if tool == &"welder":
				if not tight:
					out.append([TradesBay.HOLD_CLICK, "lay the bead"])
				elif Flags.is_on("trades.unweld"):
					out.append([TradesBay.HOLD_RIGHT, "cut the weld out"])
		"connector":
			if tool == &"hands" or tool == &"wire_tool":
				out.append([TradesBay.RIGHT_CLICK, "unplug it"] if tight else [TradesBay.CLICK, "plug it in"])
	if out.is_empty():
		var want: StringName = &""
		match f.kind:
			"bolt":
				want = &"torque_wrench"
			"rivet":
				want = &"drill" if tight else &"rivet_squeezer"
			"weld":
				want = &"welder"
			"connector":
				want = &"hands"
		if want != tool:
			out.append([bay.tool_action(want), "take the %s" % String(TradesBay.TOOL_LABELS.get(want, want)).to_lower()])
	return out


func _place_marker() -> void:
	var i := _working if _working >= 0 else aimed
	_marker.visible = i >= 0
	if i < 0:
		return
	var n := (ship_xform.basis * points[i].normal).normalized()
	var x := n.cross(Vector3.UP) if absf(n.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	_marker.global_transform = Transform3D(Basis(x.normalized(), n, x.normalized().cross(n)), points_world[i] + n * 0.012)


## No joint of its part is in yet.
func _first_joint(f: FastenerPoint) -> bool:
	for g in _bus.get_fasteners(FastenerPoint.slot_of(f.joint_id)):
		if _bus.is_joint_tight(g.joint_id):
			return false
	return true


func _slot_empty(f: FastenerPoint) -> bool:
	return _bus.get_slot_state(FastenerPoint.slot_of(f.joint_id)) == ShipBayBus.SlotState.EMPTY


func _state_word(f: FastenerPoint) -> String:
	if _slot_empty(f):
		return "PART OFF"
	if not _bus.is_joint_tight(f.joint_id):
		return "LOOSE" if f.kind != "connector" else "UNPLUGGED"
	return {"bolt": "TIGHT", "rivet": "SET", "weld": "WELDED", "connector": "PLUGGED"}.get(f.kind, "DONE")


func _tight_count() -> int:
	var n := 0
	for f in points:
		if _bus.is_joint_tight(f.joint_id):
			n += 1
	return n


func reset() -> void:
	tractor.release()
	_stop()


## Release screenshot: a joint of `kind` mid-job (a bolt being torqued, a plug pulled...),
## with the worker standing `back_m` out from it. Returns [feet, look at] in world space, or
## [] when the ship has no joint of that kind.
func stage_joint(kind: String, back_m := 1.6) -> Array[Vector3]:
	# The one easiest to see: on an outside face (standing in front of it is furthest from
	# the ship's middle), and on a side rather than overhead.
	var i := -1
	var feet := Vector3.ZERO
	var best := INF
	var middle := Vector3(ship_xform.origin.x, 0.0, ship_xform.origin.z)
	for j in points.size():
		if points[j].kind != kind:
			continue
		var n := (ship_xform.basis * points[j].normal).normalized()
		var out := Vector3(n.x, 0.0, n.z)
		if out.length() < 0.2:
			out = Vector3(points_world[j].x, 0.0, points_world[j].z) - middle
		var stand := points_world[j] + out.normalized() * back_m
		stand.y = global_position.y
		var score := absf(n.y) * 4.0 - Vector3(stand.x, 0.0, stand.z).distance_to(middle)
		if score < best:
			best = score
			i = j
			feet = stand
	if i < 0:
		return []
	var f := points[i]
	var at := points_world[i]
	aimed = i
	match kind:
		"bolt":
			_bus.note_joint_removed(f.joint_id)
			_begin(false, &"torque_wrench")
			_pull_px = torque_range(f.spec).x * 0.8 / NM_PER_PX
		"rivet":
			_begin(true, &"drill")
		"weld":
			_bus.note_joint_removed(f.joint_id)
			_begin(false, &"welder")
		"connector":
			_bus.note_joint_removed(f.joint_id)
			_begin(false, &"hands")
	_held_s = _seconds(kind) * 0.6
	_frozen = true
	return [feet, at]
