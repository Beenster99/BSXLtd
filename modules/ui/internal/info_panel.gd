class_name InfoPanel
extends CanvasLayer
## The see-through panel on the right of the view that holds every info card modules put up
## with HudSlots.set_info (what you're driving and its keys, tool state, hints), stacked in
## order so nothing overlaps. Shown only in a game, and not while the wrist screen is up.
## The UI bus owns one for the whole game.

const T := preload("res://modules/ui/api/terminal_kit.gd")
## Width of the panel (pixels at 1080 high; scales with the window).
const WIDTH := 400.0

var box: VBoxContainer
var _cards: Dictionary = {}  # id -> PanelContainer


func _ready() -> void:
	name = "InfoPanel"
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	box = VBoxContainer.new()
	box.name = "Cards"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	box.anchor_left = 1.0
	box.anchor_right = 1.0
	box.offset_left = -WIDTH - 24.0
	box.offset_right = -24.0
	box.offset_top = 96.0
	root.add_child(box)
	HudSlots.info_changed.connect(refresh)
	refresh()


func _process(_delta: float) -> void:
	box.visible = shown()


## True while the cards should show: in a game, the wrist screen down.
func shown() -> bool:
	if box.get_child_count() == 0:
		return false
	var id := str(Router.current_id)
	if id in ["main_menu", "settings", "boot", ""]:
		return false
	var ui := Modules.bus("ui") as UiBus
	return not (ui and ui.holo and ui.holo.is_open)


## Rebuilds the cards from HudSlots.infos(), reusing the ones that are still up.
func refresh() -> void:
	var keep := {}
	var i := 0
	for info: Dictionary in HudSlots.infos():
		keep[info.id] = true
		var card: PanelContainer = _cards.get(info.id)
		if card == null:
			card = _card()
			card.name = "Info_" + str(info.id).validate_node_name()
			box.add_child(card)
			_cards[info.id] = card
		box.move_child(card, i)
		i += 1
		var title := card.get_node("Col/Title") as Label
		var text := card.get_node("Col/Text") as Label
		title.text = str(info.title).to_upper()
		text.text = str(info.text)
		text.visible = text.text != ""
	for id in _cards.keys():
		if not keep.has(id):
			(_cards[id] as Node).queue_free()
			_cards.erase(id)


func _card() -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := T.box(T.tone(T.KIOSK, true, 0.5), Color(T.STEEL, 0.4), 1, 12.0)
	st.border_width_left = 4
	st.border_color = Color(T.ORANGE, 0.85)
	card.add_theme_stylebox_override("panel", st)
	var col := VBoxContainer.new()
	col.name = "Col"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)
	card.add_child(col)
	var title := T.label("", "display_bold", 20, T.ORANGE)
	title.name = "Title"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	var text := T.label("", "body_medium", 16, T.TEXT)
	text.name = "Text"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(text)
	return card
