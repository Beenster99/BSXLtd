extends VBoxContainer
## Settings > Character > Skills: the local player's level with each tool, XP towards the
## next level, and (with those features on) perks earned and certifications held. Built
## with UI's TerminalKit.

const T := preload("res://modules/ui/api/terminal_kit.gd")

var bus: ProgressionBus
var glass := false
## Whose profile to show; empty means the local player.
var player_id: StringName = &""

var _dirty := false


func _init(p_bus: ProgressionBus, p_glass := false) -> void:
	bus = p_bus
	glass = p_glass
	add_theme_constant_override("separation", 10)
	bus.profile_changed.connect(_mark_dirty)
	refresh()


func _mark_dirty() -> void:
	_dirty = true


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		refresh()


func refresh() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var me := player_id if player_id != &"" else bus.my_player_id()
	var certs_on := Flags.is_on(ProgressionBus.CERTS)
	var perks_on := Flags.is_on(ProgressionBus.PERKS)
	var held := bus.player_certs(me)

	var figs := HBoxContainer.new()
	figs.add_theme_constant_override("separation", 10)
	figs.add_child(T.figure("Total level", str(bus.total_level(me)), T.ORANGE, glass))
	if certs_on:
		figs.add_child(T.figure("Certifications", str(held.size()), T.TEXT, glass))
	add_child(figs)

	add_child(T.columns([["TOOL", 0], ["LEVEL", 70], ["XP", 90], ["NEXT LEVEL", 150]]))
	var n := 0
	for s: ProgressionSkill in bus.skills():
		var xp := bus.skill_xp(me, s.id)
		var lvl := s.level_for(xp)
		var next := "MAX"
		if lvl < s.xp_per_level.size():
			next = "%d XP to go" % (s.xp_per_level[lvl] - xp)
		add_child(T.row([T.cell_text(s.display_name, _perk_line(s, lvl) if perks_on else "Level %d of %d" % [lvl, s.xp_per_level.size()]),
				T.cell(str(lvl), 70, T.TEXT, "mono_bold"), T.cell(str(xp), 90),
				T.cell(next, 150, T.GOOD if next == "MAX" else T.DIM)], n % 2 == 1, glass))
		n += 1

	if not certs_on:
		return
	if held.is_empty():
		add_child(T.label("No certifications yet: pass a certification test job to earn one.",
				"body", 16, T.DIM))
		return
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 8)
	for c: ProgressionCert in bus.certs():
		if c.id in held:
			tags.add_child(T.tag(c.display_name, T.CYAN))
	add_child(tags)


## The perks earned so far, as a short line under the trade's name.
static func _perk_line(s: ProgressionSkill, lvl: int) -> String:
	var parts := PackedStringArray()
	for p in s.perks:
		if p.level <= lvl:
			parts.append("+%d%% %s" % [roundi(p.value * 100), String(p.effect_key).replace("_", " ")])
	return ", ".join(parts) if not parts.is_empty() else "No perks yet"
