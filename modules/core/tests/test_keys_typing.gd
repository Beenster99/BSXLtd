extends ModuleTest
## Typing in a text box never fires a key shortcut (beenster, 21 Nov: an "f" in a name box left
## the screen): Keys takes the letter keys out of every action while a LineEdit or TextEdit has
## the keyboard, and puts them back after.
##   tools/run_tests.sh core


func run_tests() -> void:
	check(InputMap.has_action(Keys.INTERACT) and _has_f(), "F is the use key")
	var box := LineEdit.new()
	add_child(box)
	await frames(1)
	box.grab_focus()
	await frames(1)
	check(Keys.typing() and not _has_f(), "with a name box in use, F does nothing but type")
	check(InputMap.action_get_events(Keys.CANCEL).size() > 0, "Escape still leaves")
	box.release_focus()
	await frames(1)
	check(not Keys.typing() and _has_f(), "out of the box, F is the use key again")
	var note := TextEdit.new()
	add_child(note)
	await frames(1)
	note.grab_focus()
	await frames(1)
	check(not _has_f(), "the same in a text area")
	note.queue_free()
	await frames(2)
	check(not Keys.typing() and _has_f(), "and a box closed while typing gives the keys back")
	box.queue_free()


func _has_f() -> bool:
	for e: InputEvent in InputMap.action_get_events(Keys.INTERACT):
		var k := e as InputEventKey
		if k and (k.physical_keycode == KEY_F or k.keycode == KEY_F):
			return true
	return false
