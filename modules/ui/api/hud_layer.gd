class_name HudLayer
extends CanvasLayer
## The in-game HUD. A game scene adds one (`add_child(HudLayer.new())`); it lays out the HudSlots
## slots and fills them with whatever panels modules registered with Core's HudSlots.

var slots: Dictionary = {}


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = BsxTheme.get_theme()
	add_child(root)
	_add_slot(root, HudSlots.TOP_BAR, HBoxContainer.new(), Control.PRESET_TOP_WIDE)
	_add_slot(root, HudSlots.TOOL_BELT, HBoxContainer.new(), Control.PRESET_CENTER_BOTTOM)
	_add_slot(root, HudSlots.JOB_CARD, VBoxContainer.new(), Control.PRESET_TOP_RIGHT)
	_add_slot(root, HudSlots.NOTICES, VBoxContainer.new(), Control.PRESET_CENTER_TOP)
	HudSlots.panels_changed.connect(_rebuild)
	var ui := Modules.bus("ui") as UiBus
	if ui:
		ui.notice_posted.connect(_on_notice)
	_rebuild()


func _add_slot(root: Control, id: String, box: BoxContainer, preset: int) -> void:
	box.name = id
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	box.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 16)
	slots[id] = box


func _rebuild() -> void:
	for id in slots:
		var box: Control = slots[id]
		for child in box.get_children():
			if child.has_meta("hud_panel"):
				child.queue_free()
		for p in HudSlots.panels_in(id):
			var scene := load(p.scene) as PackedScene
			if scene == null:
				push_error("HudLayer: can't load panel %s (%s)" % [p.id, p.scene])
				continue
			var node := scene.instantiate()
			node.set_meta("hud_panel", p.id)
			box.add_child(node)


func _on_notice(text: String) -> void:
	var l := BsxTheme.muted(text)
	slots[HudSlots.NOTICES].add_child(l)
	get_tree().create_timer(4.0).timeout.connect(l.queue_free)
