extends VBoxContainer
## Settings > Debug > Ship (beenster, 24 Oct): stand a Manta on the apron's Dock 2 for a look,
## take the Kestrel out of the bay (or bring it back), and put a random wreck in the bay in
## its place (beenster, 26 Oct). The host applies each press, so every player sees the same
## yard.

var bus: ShipBayBus
var _state: Label
var _manta: Button
var _kestrel: Button
var _wreck: Button


func _init(p_bus: ShipBayBus) -> void:
	bus = p_bus
	add_theme_constant_override("separation", 6)
	_state = BsxTheme.muted("")
	add_child(_state)
	_manta = BsxTheme.button("Spawn a Manta on Dock 2", _toggle_manta)
	_manta.name = "Manta"
	_manta.tooltip_text = "Void Salvage's Manta stands on Dock 2 on the apron, for everyone."
	add_child(_manta)
	_kestrel = BsxTheme.button("Remove the Kestrel", _toggle_kestrel)
	_kestrel.name = "Kestrel"
	_kestrel.tooltip_text = "Takes the Kestrel out of the bay, for everyone."
	add_child(_kestrel)
	_wreck = BsxTheme.button("Random wreck in the bay", func() -> void: bus.debug_ship("random_wreck"))
	_wreck.name = "Wreck"
	_wreck.tooltip_text = "Rolls a new wreck and puts it in the courtyard bay instead of the Kestrel, for everyone."
	add_child(_wreck)
	bus.bay_wreck_changed.connect(_show)
	bus.yard_ships_changed.connect(func(_s: PackedStringArray) -> void: _show())
	bus.ship_loaded.connect(func(_id: String) -> void: _show())
	bus.ship_unloaded.connect(func(_id: String) -> void: _show())
	_show()


func _toggle_manta() -> void:
	bus.debug_ship("remove" if bus.yard_ships.has("manta") else "spawn", "manta")


func _toggle_kestrel() -> void:
	bus.debug_ship("restore_bay" if bus.ship == null else "clear_bay")


func _show() -> void:
	var manta := bus.yard_ships.has("manta")
	_manta.text = "Remove the Manta" if manta else "Spawn a Manta on Dock 2"
	_kestrel.text = "Bring the Kestrel back" if bus.ship == null else "Remove the Kestrel"
	_wreck.text = "Another random wreck" if not bus.bay_wreck.is_empty() else "Random wreck in the bay"
	var in_bay := bus.ship.display_name if bus.ship else (str(bus.bay_wreck.get("name", "a wreck")) if not bus.bay_wreck.is_empty() else "nothing")
	_state.text = "In the bay: %s.  On the apron: %s." % [in_bay,
			"the Manta" if manta else "nothing"]
