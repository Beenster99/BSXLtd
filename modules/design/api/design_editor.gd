class_name DesignEditor
extends RefCounted
## Edits to the open design, with an undo history per person (plan 3.1: everyone has their
## own undo). Every view edits through do(); the record tells all views what changed.
##   editor.do({op = "add_room", room = {type = "bridge", deck = 0, x = 0, z = -6, w = 5, d = 4}})
##   editor.undo()        # the local player's last edit
## An undo that no longer applies (someone else removed the room since) is skipped.

const MAX_STEPS := 200
const LOCAL := "local"

var library: DesignLibrary
var _undo: Dictionary = {}  # author -> Array of [undo_op, redo_op]
var _redo: Dictionary = {}


func _init(lib: DesignLibrary) -> void:
	library = lib
	library.opened.connect(func(_r: DesignRecord) -> void:
		_undo = {}
		_redo = {})


## Applies an op to the open design. Returns the undo op, {} if nothing changed.
func do(op: Dictionary, author: String = LOCAL) -> Dictionary:
	var rec := library.current
	if rec == null:
		return {}
	var undo_op := rec.apply(op)
	if undo_op.is_empty():
		return {}
	var stack: Array = _undo.get(author, [])
	stack.append([undo_op, op])
	if stack.size() > MAX_STEPS:
		stack.pop_front()
	_undo[author] = stack
	_redo[author] = []
	return undo_op


func can_undo(author: String = LOCAL) -> bool:
	return not (_undo.get(author, []) as Array).is_empty()


func can_redo(author: String = LOCAL) -> bool:
	return not (_redo.get(author, []) as Array).is_empty()


func undo(author: String = LOCAL) -> bool:
	var stack: Array = _undo.get(author, [])
	while not stack.is_empty():
		var step: Array = stack.pop_back()
		var redo_op := library.current.apply(step[0]) if library.current else {}
		if not redo_op.is_empty():
			var r: Array = _redo.get(author, [])
			r.append([step[0], redo_op])
			_redo[author] = r
			return true
	return false


func redo(author: String = LOCAL) -> bool:
	var stack: Array = _redo.get(author, [])
	while not stack.is_empty():
		var step: Array = stack.pop_back()
		var undo_op := library.current.apply(step[1]) if library.current else {}
		if not undo_op.is_empty():
			(_undo.get(author, []) as Array).append([undo_op, step[1]])
			if not _undo.has(author):
				_undo[author] = [[undo_op, step[1]]]
			return true
	return false
