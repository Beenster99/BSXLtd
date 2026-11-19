extends ModuleTest
## Every component in the design catalogue has a real model in walk-inside, never a box: Void
## Salvage's own part (VsParts) or BSX's own model (PartModels) at the catalogue's size, and the
## walk-inside look draws it (turned to its front, scaled for its size class).
##   tools/run_tests.sh design

const WalkBuild := preload("res://modules/design/internal/walk/walk_build.gd")


func run_tests() -> void:
	Flags.set_flag("design.part_models", true)
	var catalog := DesignCatalog.load_default()
	var boxes: Array[String] = []
	for id: String in catalog.parts:
		var pt: DesignPartType = catalog.parts[id]
		if pt.shared_part != "":
			check(VsParts.has(pt.shared_part), "%s: its Void Salvage part %s exists" % [id, pt.shared_part])
			check(not PartModels.has(id), "%s: one model, not two (it is Void Salvage's)" % id)
			continue
		if not PartModels.has(id):
			boxes.append(id)
			continue
		var got := PartModels.size(id)
		check(got.is_equal_approx(pt.size) or (got - pt.size).length() < 0.01,
				"%s: its model is the catalogue size %s (%s)" % [id, pt.size, got])
	check(boxes.is_empty(), "every component has a model, none drawn as a box: %s" % [boxes])
	# The walk-inside look: the model, turned to the front and scaled for a bigger size class.
	var kit := WalkBuild.new(catalog)
	var holder := Node3D.new()
	var fridge := catalog.part("fridge")
	WalkBuild.component_look(holder, fridge, fridge.size, 1, kit)
	check(holder.get_child_count() == 1 and holder.get_child(0).has_meta("part_model"), "walk-inside draws the fridge's model")
	if holder.get_child_count() == 1:
		check(is_equal_approx((holder.get_child(0) as Node3D).rotation.y, PI * 0.5), "turned to its front")
	holder.free()
	var big := catalog.part("jump_drive:5S")
	if big != null and big.model_scale != 1.0:
		holder = Node3D.new()
		WalkBuild.component_look(holder, big, big.size, 0, kit)
		check(holder.get_child(0).has_meta("part_model") and is_equal_approx((holder.get_child(0) as Node3D).scale.x, big.model_scale),
				"a bigger size class draws its base model scaled up (%.2f)" % big.model_scale)
		holder.free()
	# The tug's tow hook (contracts ask for one): a hull hardpoint rated in tonnes, x2 a size up.
	var hook := catalog.part("tow_hook")
	check(hook != null and hook.hull_mount and hook.tow_t == 300.0 and PartModels.has("tow_hook"),
			"the tow hook is a hull fitting rated 300 t, with a model")
	var hook4 := catalog.part("tow_hook:4S")
	check(hook4 != null and is_equal_approx(hook4.tow_t, 600.0), "a size 4 tow hook tows twice as much")
	Flags.set_flag("design.part_models", false)
	holder = Node3D.new()
	WalkBuild.component_look(holder, fridge, fridge.size, 0, kit)
	check(holder.get_child_count() > 0 and not holder.get_child(0).has_meta("part_model"), "with the flag off it is the fitted box again")
	holder.free()
	Flags.set_flag("design.part_models", true)
