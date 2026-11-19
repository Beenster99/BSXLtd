extends Node
## Screenshots of the parts market wall panel for the screenshots page (run under a display):
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . \
##       res://modules/supply/internal/tools/market_capture.tscn -- --out=/abs/dir
## Saves market_design.png (the whole design's history), market_line.png (one line's vendors
## over 180 days, the most reliable plan marked) and room.png (the market on the design room's wall).

func _ready() -> void:
	# The scene is swapped for the design room on the way, so the work runs on a node of the root.
	var runner := Node.new()
	runner.name = "MarketCaptureRunner"
	runner.set_script(load("res://modules/supply/internal/tools/market_capture_runner.gd"))
	get_tree().root.add_child.call_deferred(runner)
