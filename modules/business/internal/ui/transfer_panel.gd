extends VBoxContainer
## The wrist screen's money docket under the crew list: pick a crew member, type an amount,
## send it from your wallet or the company account. The host checks and applies it.

const T := preload("res://modules/ui/api/terminal_kit.gd")

var bus: BusinessBus
var glass := true
## Peer id of the crew member picked, 0 for none.
var to_peer := 0
var from_company := false

var _people: Control
var _from: Control
var _amount: LineEdit
var _send: Button
var _wallet: Label
var _message: Label


func _init(p_bus: BusinessBus, p_glass := true) -> void:
	bus = p_bus
	glass = p_glass
	add_theme_constant_override("separation", 6)
	_wallet = T.label("", "mono_medium", 16, T.DIM)
	add_child(_wallet)
	_people = HBoxContainer.new()
	add_child(_people)
	_from = HBoxContainer.new()
	add_child(_from)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_amount = T.search("Amount", func(t: String) -> void:
		var digits := ""
		for ch in t:
			if ch >= "0" and ch <= "9":
				digits += ch
		if digits != t:
			_amount.text = digits
			_amount.caret_column = digits.length()
		_refresh_send(), glass)
	_amount.clear_button_enabled = false
	_amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_amount)
	_send = T.button("SEND CR", true, 17, false, glass)
	_send.name = "Send"
	_send.pressed.connect(send)
	row.add_child(_send)
	add_child(row)
	_message = T.label("", "body_medium", 15, T.DIM)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_message)
	bus.wallet_changed.connect(_on_wallet_changed)
	bus.transfer_refused.connect(_on_refused)
	var net := Modules.bus("multiplayer")
	if net:
		net.connect("peer_joined", _on_peers)
		net.connect("peer_left", _on_peers)
	refresh()


## Everyone else in the session: peer id -> name.
func crew() -> Dictionary:
	var out := bus.crew_names().duplicate()
	out.erase(bus.my_peer())
	return out


func refresh() -> void:
	var people := crew()
	if not people.has(to_peer):
		to_peer = 0 if people.is_empty() else people.keys()[0]
	for c in _people.get_children():
		c.queue_free()
	if people.is_empty():
		_people.add_child(T.label("Nobody else is aboard yet.", "body", 16, T.DIM))
	else:
		var names := PackedStringArray()
		for id: int in people:
			names.append(people[id])
		_people.add_child(T.chips(names, str(people.get(to_peer, "")), func(n: String) -> void:
			for id: int in people:
				if people[id] == n:
					to_peer = id
			refresh(), glass, false))
	for c in _from.get_children():
		c.queue_free()
	_from.add_child(T.chips(PackedStringArray(["My wallet", "Company"]), "Company" if from_company else "My wallet", func(n: String) -> void:
		from_company = n == "Company"
		refresh(), glass, false))
	_wallet.text = "MY WALLET  %s CR     COMPANY  %s CR" % [T.money(bus.get_wallet(bus.my_name())), T.money(bus.get_cash())]
	_refresh_send()


func _refresh_send() -> void:
	_send.disabled = to_peer == 0 or int(_amount.text) <= 0
	_send.text = "SEND %s CR" % T.money(int(_amount.text)) if int(_amount.text) > 0 else "SEND CR"


func _on_peers(_id: int, _why: Variant) -> void:
	refresh()


func send() -> void:
	if _send.disabled:
		return
	_message.text = ""
	bus.request_transfer(to_peer, int(_amount.text), from_company)


func _on_wallet_changed(player: String, _balance: int, delta: int) -> void:
	if delta > 0 and player == bus.player_name(to_peer):
		_message.text = "Sent %s CR to %s." % [T.money(delta), player]
		_message.add_theme_color_override("font_color", T.GOOD)
		_amount.text = ""
	refresh()


func _on_refused(reason: String) -> void:
	_message.text = reason.left(1).to_upper() + reason.substr(1) + "."
	_message.add_theme_color_override("font_color", T.BAD)
	Sfx.play("error")
