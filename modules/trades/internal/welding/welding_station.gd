extends TradesStation
## Welding: two 6 mm plates butted on a slatted table, a MIG welder beside them. Set the
## amps for the plate with the wheel, strike the arc on the seam, then run it end to end with
## the mouse: sideways is travel, up and down is the torch's height (the arc wanders; keep it
## steady). Where you stand sets the torch's lean. All the rules live in WeldSeam.

const BENCH_TOP := TradesBay.BENCH_TOP
const TABLE_Y := BENCH_TOP + 0.03
const PLATE_MM := 6.0
const TOP_Y := TABLE_Y + PLATE_MM / 1000.0
const SEAM_HALF := 0.06
const MACHINE := Vector3(0.33, BENCH_TOP, -0.13)
## The arc only strikes this close to the seam.
const STRIKE_M := 0.015
## Mouse to torch: travel and height per pixel.
const TRAVEL_MM_PER_PX := 0.15
const ARC_MM_PER_PX := 0.02
## The hand's wander in arc length (mm per second, at its peak).
const TREMOR_MM_S := 0.8
## The torch's handle swings this far round to your right of pointing straight at you (radians).
const HOLD_TURN := 0.9

var seam: WeldSeam
var site: JointSite
var torch: TradesWeldTorch

var STEEL := TradesLook.paint(Color(0.36, 0.37, 0.39), 0.75, 0.45, "brushed_steel")
var DARK := TradesLook.paint(TradesLook.DARK, 0.55, 0.5)
var BODY := TradesLook.paint(TradesLook.TRIM, 0.3, 0.45)
var COPPER := TradesLook.paint(Color(0.78, 0.45, 0.28), 0.9, 0.3)

var _beads: Array[MeshInstance3D] = []
var _bead_mats: Array[StandardMaterial3D] = []
var _screen: Label3D
var _arc_light: OmniLight3D
var _sparks: CPUParticles3D
var _along_px := 0.0
var _height_px := 0.0
var _tremor_t := 0.0
var _started := false


func build() -> void:
	title = "Welding"
	half_width = 0.55
	var spec := JointSpec.new()
	spec.trade = &"WELD"
	spec.fastener_id = &"wire_er70s6_0.8"
	spec.torque_target_nm = 0.0
	spec.needs_washer = false
	seam = WeldSeam.new(spec)
	seam.length_mm = SEAM_HALF * 2000.0
	seam.plate_mm = PLATE_MM
	seam.reset()
	seam.completed.connect(_on_seam_completed)
	seam.arc_broke.connect(_on_arc_broke)
	torch = bay.tool_node(&"welder") as TradesWeldTorch
	_build_parts()
	_build_site(spec)
	_build_beads()
	_build_arc()
	reset()


func tools() -> Array[StringName]:
	return [&"hands", &"welder"]


func status_line() -> String:
	return "WELDER  %d A  (%d A FOR %d MM PLATE)" % [roundi(seam.amps), roundi(seam.amps_target), roundi(PLATE_MM)]


func start_hint() -> String:
	return "Welder is 5. Wheel sets the amps. Hold left click on the seam to strike the arc."


func is_busy() -> bool:
	return seam.arc_on


func reset() -> void:
	if seam.is_complete():
		_bus_remove()
	seam.arc_on = false
	seam.reset()
	_started = false
	bay.worker.look_locked = false


func wheel(step: int) -> bool:
	if seam.arc_on:
		return false
	seam.set_amps(seam.amps + 5.0 * step)
	return true


func motion(relative: Vector2) -> bool:
	if not seam.arc_on:
		return false
	_along_px += relative.x
	_height_px -= relative.y
	return true


func press(tool: StringName) -> void:
	if tool != &"welder":
		if tool != &"hands":
			bay.hint("Welding takes the welder (5).")
		return
	var hit: Variant = bay.aim_on(Plane(Vector3.UP, world(Vector3(0, TOP_Y, 0)).y))
	if hit == null:
		return
	var p := to_local(hit)
	if absf(p.z) > STRIKE_M or absf(p.x) > SEAM_HALF + STRIKE_M:
		bay.hint("Aim at the seam between the plates.")
		return
	if not bay.worker.right_hand.can_reach(hit):
		bay.hint("Too far. Step closer.")
		return
	if seam.strike((p.x + SEAM_HALF) * 1000.0):
		_along_px = 0.0
		_height_px = 0.0
		bay.worker.look_locked = true
		_mark_started()
		bay.hint("Run it along the seam: mouse right to travel, up and down for the arc.")
	else:
		bay.hint("This seam is done. Right click grinds it out.")


func release() -> void:
	if seam.arc_on:
		seam.stop()
		_end_arc()


func back_out(tool: StringName) -> void:
	if tool != &"welder" and tool != &"hands":
		return
	if seam.arc_on:
		return
	if seam.grind_out():
		_bus_remove()
		bay.hide_result()
	_started = false
	bay.hint("Bead ground out. Strike again.")


func on_hand_snapped() -> void:
	release()


func update(delta: float) -> void:
	seam.age(delta)
	_update_beads()
	var aim_angle := -1.0
	if seam.arc_on:
		_tremor_t += delta
		var drift := (sin(_tremor_t * 1.3) * 0.6 + sin(_tremor_t * 2.9 + 1.0) * 0.4) * TREMOR_MM_S * delta
		var result := seam.travel(_along_px * TRAVEL_MM_PER_PX, _height_px * ARC_MM_PER_PX + drift,
				_torch_angle(_tip_world()), delta)
		_along_px = 0.0
		_height_px = 0.0
		if result == &"end":
			seam.stop()
			_end_arc()
			if not seam.is_complete():
				bay.hint("End of the seam. Strike again where the bead is missing.")
	if seam.arc_on:
		var tip := _tip_world()
		var angle := _torch_angle(tip)
		# Held from the right, like a right-handed welder, so the arc and bead stay in view.
		var basis := Basis(Vector3.UP, _face_yaw(tip) + HOLD_TURN) * Basis(Vector3.RIGHT, deg_to_rad(angle))
		var xform := Transform3D(basis, tip)
		bay.place_tool(&"welder", xform)
		bay.worker.right_hand.reach_to(xform * TradesWeldTorch.GRIP + Vector3(0, 0.015, 0))
		bay.worker.right_hand.set_grip(1.0)
		torch.lit = true
		_arc_light.global_position = world(_seam_point(seam.pos_mm)) + Vector3(0, 0.01, 0)
		_arc_light.light_energy = 1.0 + randf() * 0.8
		_arc_light.visible = true
		_sparks.global_position = world(_seam_point(seam.pos_mm))
		_sparks.emitting = true
		bay.loop(&"arc", true, 0.9 + randf() * 0.2)
		aim_angle = angle
	else:
		var hit: Variant = bay.aim_on(Plane(Vector3.UP, world(Vector3(0, TOP_Y, 0)).y))
		if hit != null and absf(to_local(hit).x) < SEAM_HALF + 0.1:
			aim_angle = _torch_angle(hit)
	_screen.text = _readout(aim_angle)


func _end_arc() -> void:
	torch.lit = false
	_arc_light.visible = false
	_sparks.emitting = false
	bay.loop(&"arc", false)
	bay.worker.look_locked = false
	bay.worker.right_hand.come_back()


func _readout(angle: float) -> String:
	var lines: PackedStringArray = ["AMPS  %3d  [%d]" % [roundi(seam.amps), roundi(seam.amps_target)]]
	lines.append("ARC   %4.1f mm" % seam.arc_mm if seam.arc_on else "ARC    -- mm")
	lines.append("ANGLE %3d deg [%d]" % [roundi(angle), roundi(seam.angle_target_deg)] if angle >= 0.0 else "ANGLE  -- deg")
	lines.append("SPEED %4.1f [%d]" % [seam.speed_mm_s if seam.arc_on else 0.0, roundi(seam.speed_target_mm_s)])
	return "\n".join(lines)


## The torch's lean from upright: how far back toward your head it tips from the arc.
func _torch_angle(tip: Vector3) -> float:
	var up := bay.worker.head.global_position - tip
	return rad_to_deg(up.angle_to(Vector3.UP))


func _tip_world() -> Vector3:
	return world(_seam_point(seam.pos_mm)) + Vector3(0, seam.arc_mm / 1000.0, 0)


func _seam_point(mm: float) -> Vector3:
	return Vector3(-SEAM_HALF + mm / 1000.0, TOP_Y, 0.0)


func _face_yaw(at: Vector3) -> float:
	var to_worker := bay.worker.global_position - at
	return atan2(to_worker.x, to_worker.z)


func _mark_started() -> void:
	if _started:
		return
	_started = true
	var bus := bay.bus()
	if bus:
		bus.joint_started.emit(site.joint_id, site.spec.trade, 1)


func _on_arc_broke() -> void:
	_end_arc()
	bay.play(&"tick", 0.5)
	bay.hint("The arc went out (torch too high or too low). Strike again where the bead stops.")


func _on_seam_completed() -> void:
	var m := seam.measurements()
	var bus := bay.bus()
	if bus:
		bus.complete_joint(site, m)
	var pens: Array = m.penetration
	var lines: PackedStringArray = ["WELDED SEAM COMPLETE", ""]
	lines.append("Coverage: %d%%" % roundi(m.coverage * 100.0))
	lines.append("Speed: %s mm/s (target %d)" % [_spread(m.travel_speed_mm_s), roundi(m.travel_speed_mm_s_target)])
	lines.append("Angle: %s deg (target %d)" % [_spread(m.torch_angle_deg), roundi(m.torch_angle_deg_target)])
	lines.append("Arc: %s mm (target %.0f)" % [_spread(m.arc_length_mm), m.arc_length_mm_target])
	lines.append("Penetration: %s (1.0 is full)" % _spread(pens))
	lines.append("Amps: %d (target %d), restarts: %d" % [roundi(m.amps), roundi(m.amps_target), m.restarts])
	if m.burn_through:
		lines.append("BURNED THROUGH")
	bay.show_result(lines)
	bay.hint("Done.")


func _spread(values: Array) -> String:
	if values.is_empty():
		return "--"
	var lo: float = values.min()
	var hi: float = values.max()
	return "%.1f to %.1f" % [lo, hi]


## Release screenshot: amps set, the arc lit two thirds of the way down the seam.
func stage_for_screenshot() -> void:
	seam.set_amps(seam.amps_target)
	seam.strike(0.0)
	var dt := 1.0 / 60.0
	while seam.pos_mm < seam.length_mm * 0.62:
		seam.travel(seam.speed_target_mm_s * dt, 0.0, seam.angle_target_deg, dt)
	for b in seam.age_at.size():
		seam.age_at[b] = (seam.pos_mm - b * seam.bin_mm) / seam.speed_target_mm_s
	bay.set_tool(&"welder")
	bay.hint("Run it along the seam: mouse right to travel, up and down for the arc.")


func screenshot_view() -> Array[Vector3]:
	return [Vector3(-0.06, 0.0, 0.42), Vector3(0.03, TOP_Y, 0.0)]


# --- Building --------------------------------------------------------------------------

func _build_parts() -> void:
	# Slatted welding table on the bench.
	paint_box(Vector3(0.3, 0.008, 0.2), Vector3(0, BENCH_TOP + 0.004, 0), DARK)
	for i in 7:
		paint_box(Vector3(0.006, 0.022, 0.19), Vector3(-0.135 + i * 0.045, BENCH_TOP + 0.019, 0), STEEL)
	# The two plates and the gap between them.
	for side: float in [-1.0, 1.0]:
		paint_box(Vector3(SEAM_HALF * 2.0, PLATE_MM / 1000.0, 0.058),
				Vector3(0, TABLE_Y + PLATE_MM / 2000.0, side * 0.0298), STEEL)
	paint_box(Vector3(SEAM_HALF * 2.0, PLATE_MM / 1000.0 - 0.0002, 0.0012),
			Vector3(0, TABLE_Y + PLATE_MM / 2000.0, 0), TradesLook.paint(Color(0.02, 0.02, 0.02), 0.2, 0.9))
	# Earth clamp on the near plate, its lead running off to the machine.
	paint_box(Vector3(0.02, 0.012, 0.03), Vector3(SEAM_HALF + 0.01, TOP_Y + 0.006, 0.04), COPPER)
	paint_box(Vector3(0.012, 0.012, 0.04), Vector3(SEAM_HALF + 0.03, TOP_Y + 0.006, 0.05), DARK)
	# The welder: an orange case, a dark front panel with the screen, the wire spool's door.
	paint_box(Vector3(0.18, 0.22, 0.3), MACHINE + Vector3(0, 0.11, 0), BODY)
	paint_box(Vector3(0.186, 0.012, 0.306), MACHINE + Vector3(0, 0.226, 0), DARK)
	paint_box(Vector3(0.16, 0.18, 0.006), MACHINE + Vector3(0, 0.11, 0.152), DARK)
	paint_box(Vector3(0.004, 0.16, 0.24), MACHINE + Vector3(-0.091, 0.11, 0), DARK)
	for i in 2:
		paint_cylinder(0.012, 0.012, MACHINE + Vector3(-0.04 + i * 0.08, 0.05, 0.16), STEEL).rotation_degrees.x = 90
	paint_cylinder(0.008, 0.02, MACHINE + Vector3(0.05, 0.03, 0.16), COPPER).rotation_degrees.x = 90
	_screen = TradesLook.readout(self, MACHINE + Vector3(0, 0.145, 0.158), Vector2(0.15, 0.1))
	_screen.pixel_size = 0.00028
	bench_label("6 MM  130 A", MACHINE + Vector3(0, 0.0005, 0.2))


func _build_site(spec: JointSpec) -> void:
	site = JointSite.new()
	site.name = "ButtSeam"
	site.joint_id = &"bench_seam"
	site.spec = spec
	add_child(site)
	for x: float in [-SEAM_HALF, SEAM_HALF]:
		var m := Marker3D.new()
		m.position = Vector3(x, TOP_Y, 0)
		site.add_child(m)


func _build_beads() -> void:
	for b in seam.bin_count():
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.19, 0.2)
		mat.metallic = 0.7
		mat.roughness = 0.5
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.45, 0.12)
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.5
		mesh.height = 1.0
		mesh.radial_segments = 8
		mesh.rings = 2
		mesh.material = mat
		var bead := MeshInstance3D.new()
		bead.mesh = mesh
		bead.rotation_degrees.z = 90
		add_child(bead)
		_beads.append(bead)
		_bead_mats.append(mat)


func _build_arc() -> void:
	_arc_light = OmniLight3D.new()
	_arc_light.light_color = Color(0.75, 0.85, 1.0)
	_arc_light.omni_range = 1.5
	_arc_light.visible = false
	add_child(_arc_light)
	_sparks = CPUParticles3D.new()
	_sparks.emitting = false
	_sparks.amount = 40
	_sparks.lifetime = 0.45
	_sparks.direction = Vector3.UP
	_sparks.spread = 70.0
	_sparks.initial_velocity_min = 0.4
	_sparks.initial_velocity_max = 1.2
	_sparks.gravity = Vector3(0, -6.0, 0)
	var dot := SphereMesh.new()
	dot.radius = 0.0012
	dot.height = 0.0024
	dot.radial_segments = 4
	dot.rings = 2
	dot.material = TradesLook.glow(Color(1.0, 0.7, 0.3), 5.0)
	_sparks.mesh = dot
	add_child(_sparks)
	_sparks.top_level = true


## Each bin of bead: wider where it dug deeper, taller where it went slowly, glowing while
## fresh, black where it burned through.
func _update_beads() -> void:
	for b in _beads.size():
		var bead := _beads[b]
		bead.visible = seam.filled[b]
		if not bead.visible:
			continue
		var width := (3.0 + 4.0 * clampf(seam.pen_at[b], 0.2, 1.6)) / 1000.0
		var height := (1.0 + 1.2 * clampf(seam.speed_target_mm_s / maxf(seam.speed_at[b], 1.0), 0.4, 2.0)) / 1000.0
		bead.position = _seam_point((b + 0.5) * seam.bin_mm)
		bead.scale = Vector3(height, seam.bin_mm * 1.6 / 1000.0, width)
		var mat := _bead_mats[b]
		var burnt := seam.pen_at[b] > seam.burn_penetration
		mat.albedo_color = Color(0.05, 0.04, 0.04) if burnt else Color(0.2, 0.19, 0.2)
		mat.emission_energy_multiplier = maxf(0.0, 1.0 - seam.age_at[b] / 3.0) * 4.0


func _bus_remove() -> void:
	var bus := bay.bus()
	if bus:
		bus.remove_joint(site.joint_id)
