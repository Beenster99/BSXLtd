extends Node
## Screenshots of the ACCOUNTS wall panel for the screenshots page (run under a display):
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . \
##       res://modules/business/internal/tools/accounts_capture.tscn -- --out=/abs/dir [--room]
## Plays a fortnight of sample business into fresh books, then saves accounts_week.png,
## accounts_month.png, accounts_wrist.png (the wrist pane's size) and, with --room where the
## design room takes wall panels, room.png and the wall's own image.

const SIZE := Vector2i(1110, 780)


func _ready() -> void:
	# The scene is swapped for the design room on the way, so the work runs on a node of the root.
	var runner := Node.new()
	runner.name = "AccountsCaptureRunner"
	runner.set_script(load("res://modules/business/internal/tools/accounts_capture_runner.gd"))
	get_tree().root.add_child.call_deferred(runner)
