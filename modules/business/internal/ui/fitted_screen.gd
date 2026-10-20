extends Control
## Holds a yard terminal laid out at its full 1280 x 800 and scales it to fit whatever room
## it is given (the wrist holo screen's pane), so nothing is cut off at the edges.

signal close_requested

const LAYOUT := Vector2(1280, 800)

var screen: Control


func _init(p_screen: Control) -> void:
	screen = p_screen
	clip_contents = true
	add_child(screen)
	screen.size = LAYOUT
	screen.connect("close_requested", func() -> void: close_requested.emit())
	resized.connect(_fit)


func _ready() -> void:
	_fit()


func _fit() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	var k := minf(size.x / LAYOUT.x, size.y / LAYOUT.y)
	screen.scale = Vector2(k, k)
	screen.position = (size - LAYOUT * k) * 0.5
