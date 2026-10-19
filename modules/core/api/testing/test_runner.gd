extends Node
## Loads the test named by `-- --test=res://...gd` and runs it (see ModuleTest).

func _ready() -> void:
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test="):
			path = arg.trim_prefix("--test=")
	var script := load(path) as Script if path != "" else null
	if script == null:
		printerr("test_runner: pass -- --test=res://path/to/test.gd (got '%s')" % path)
		get_tree().quit(2)
		return
	var test: Node = script.new()
	test.name = path.get_file().get_basename()
	add_child(test)
