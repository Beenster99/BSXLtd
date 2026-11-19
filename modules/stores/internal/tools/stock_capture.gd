extends Node
## Screenshots for the warehouse stock thread's page (run under a display):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##       res://modules/stores/internal/tools/stock_capture.tscn -- --out=/abs/dir [--station]
## Saves stock_wall.png (the screen alone, as a wall shows it), and with --station the wrist
## screen opened in the orbital yard on every channel (wrist_<channel>.png).

func _ready() -> void:
	# Lives on the root, as the station replaces this scene.
	var runner := Node.new()
	runner.name = "StockCaptureRunner"
	runner.set_script(Runner)
	get_tree().root.add_child.call_deferred(runner)


const Runner := preload("res://modules/stores/internal/tools/stock_capture_runner.gd")


