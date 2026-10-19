class_name ModuleTest
extends Node
## Base for headless module tests. Each test is a script that extends ModuleTest, overrides
## run_tests() (it may await) and calls check(); the process exits 1 on any failure.
##   godot --headless --path . res://modules/core/api/testing/test_runner.tscn -- --test=res://modules/<id>/tests/test_<thing>.gd
## tools/run_tests.sh runs every modules/*/tests/test_*.gd that way. Tests run inside a
## normal scene (not `-s`), so the autoloads (Flags, Router, Modules...) are ready and
## scripts that use them compile.

var _failures := 0
var _checks := 0


func _ready() -> void:
	_start.call_deferred()


func _start() -> void:
	if not Modules.ready_done:
		await Modules.modules_ready
	await run_tests()
	print("%s: %d checks, %d failed" % [get_script().resource_path.get_file(), _checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func run_tests() -> void:
	pass


func check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		printerr("FAIL: ", what)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
