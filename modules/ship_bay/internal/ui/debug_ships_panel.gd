extends VBoxContainer
## Settings > Debug > Ship (beenster, 24 Oct): stand a Manta on the apron's Dock 2 for a look,
## take the Kestrel out of the bay (or bring it back), and put a random wreck in the bay in
## its place, small, medium or large (beenster, 26 Oct), or one picked by name (0.3.32). The host applies each press, so every player sees the same
## yard.

var bus: ShipBayBus
var _state: Label
var _manta: Button
var _kestrel: Button
## The random wreck buttons by size (ShipBayBus.WRECK_SIZES): "Wreck" (small), "WreckM", "WreckL".
var _wrecks: Dictionary = {}
## A particular wreck by name (beenster, 0.3.31: "how do i spawn the patience"; flag
## ship_bay.debug_named_wreck): every design the library packs, training hulks included.
var _pick: OptionButton
var _pick_ids: PackedStringArray = PackedStringArray()


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
	for size: String in ShipBayBus.WRECK_SIZES:
		var b := BsxTheme.button("", func() -> void: bus.debug_ship("random_wreck", size))
		b.name = "Wreck" if size == "S" else "Wreck" + size
		b.tooltip_text = "Rolls a new %s wreck and puts it on the courtyard bay's cradle instead of the Kestrel, for everyone." \
				% str(ShipBayBus.WRECK_SIZES[size]).to_lower()
		add_child(b)
		_wrecks[size] = b
	if Flags.is_on("ship_bay.debug_named_wreck"):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_pick = OptionButton.new()
		_pick.name = "WreckPick"
		_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_pick.tooltip_text = "Any of Void Salvage's wreck designs, the Patience training hulk too."
		for c: Array in ShipBayBus.wreck_choices():
			_pick_ids.append(str(c[0]))
			_pick.add_item(str(c[1]))
		var at := _pick_ids.find("vsw:patience")
		if at >= 0:
			_pick.select(at)
		row.add_child(_pick)
		var put := BsxTheme.button("Put it in the bay", _put_named)
		put.name = "WreckNamed"
		put.tooltip_text = "Puts the wreck picked on the left on the courtyard bay's cradle instead of the Kestrel, for everyone."
		row.add_child(put)
		add_child(row)
	bus.bay_wreck_changed.connect(_show)
	bus.yard_ships_changed.connect(func(_s: PackedStringArray) -> void: _show())
	bus.ship_loaded.connect(func(_id: String) -> void: _show())
	bus.ship_unloaded.connect(func(_id: String) -> void: _show())
	_show()


func _put_named() -> void:
	if _pick and _pick.selected >= 0 and _pick.selected < _pick_ids.size():
		bus.debug_ship("named_wreck", _pick_ids[_pick.selected])


func _toggle_manta() -> void:
	bus.debug_ship("remove" if bus.yard_ships.has("manta") else "spawn", "manta")


func _toggle_kestrel() -> void:
	bus.debug_ship("restore_bay" if bus.ship == null or bus.ship.ship_id == ShipBayBus.WRECK_ID else "clear_bay")


func _show() -> void:
	var manta := bus.yard_ships.has("manta")
	_manta.text = "Remove the Manta" if manta else "Spawn a Manta on Dock 2"
	var kestrel := bus.ship != null and bus.ship.ship_id != ShipBayBus.WRECK_ID
	_kestrel.text = "Remove the Kestrel" if kestrel else "Bring the Kestrel back"
	for size: String in _wrecks:
		var word := str(ShipBayBus.WRECK_SIZES[size]).to_lower()
		(_wrecks[size] as Button).text = ("Another %s wreck" if str(bus.bay_wreck.get("size", "S")) == size and not bus.bay_wreck.is_empty() \
				else "Random %s wreck in the bay") % word
	var in_bay := bus.ship.display_name if bus.ship else "nothing"
	_state.text = "In the bay: %s.  On the apron: %s." % [in_bay,
			"the Manta" if manta else "nothing"]
