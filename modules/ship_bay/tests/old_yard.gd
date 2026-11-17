extends RefCounted
## The old yard by the sea's parts, switched off for the shipbuilder (Wave 0, beenster 17 Nov):
## tests of those parts turn them back on with `on()` and put them back with `restore(saved)`.

const FLAGS := ["ship_bay.apron", "ship_bay.hulls_on_cradles", "ship_bay.bay_cradle", "ship_bay.sections",
		"ship_bay.debug_named_wreck", "ship_bay.organise_scrap", "ship_bay.organise_batch", "ship_bay.tidy_to_refurb",
		"ship_bay.refurb_runs_intake", "ship_bay.clean_up", "ship_bay.dolly", "ship_bay.emitter_rig",
		"ship_bay.upgrade_hall", "ship_bay.trucks", "ship_bay.teardown", "ship_bay.refurb", "ship_bay.crusher",
		"ship_bay.trolleys", "ship_bay.lifts"]


## Turns every old yard flag on; returns what they were.
static func on() -> Dictionary:
	var saved := {}
	for f: String in FLAGS:
		saved[f] = Flags.is_on(f)
		Flags.set_flag(f, true)
	return saved


static func restore(saved: Dictionary) -> void:
	for f: String in saved:
		Flags.set_flag(f, saved[f])
