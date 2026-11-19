class_name DesignEditor
extends RefCounted
## Edits to the open design, with an undo history per person (plan 3.1: everyone has their
## own undo). Every view edits through do(); the record tells all views what changed.
##   editor.do({op = "add_room", room = {type = "bridge", deck = 0, x = 0, z = -6, w = 5, d = 4}})
##   editor.undo()        # the local player's last edit
## An undo that no longer applies (someone else removed the room since) is skipped.
##
## Designing together (Wave 3): with `send` set (DesignBus, through the multiplayer module),
## do/undo/redo go to the session's host, which puts every player's edits in one order and
## applies them on every machine (`apply_op`, `apply_undo`, `apply_redo`), each under its
## author's own undo history. Offline, and on the host, that happens at once, so do() still
## returns the undo op there; on a joined player's machine the edit lands a moment later.

const MAX_STEPS := 200
const LOCAL := "local"

var library: DesignLibrary
## send.call(kind, payload): kind "op" {op}, "undo" {}, "redo" {}. Unset: edits apply here.
var send := Callable()
## The local player's author id in the session ("p<peer id>"); LOCAL when unset.
var me := Callable()
var _last_undo: Dictionary = {}
var _last_ok := false
var _undo: Dictionary = {}  # author -> Array of [undo_op, redo_op]
var _redo: Dictionary = {}


func _init(lib: DesignLibrary) -> void:
	library = lib
	library.opened.connect(func(_r: DesignRecord) -> void:
		_undo = {}
		_redo = {})


## Applies an op to the open design. Returns the undo op, {} if nothing changed (or, for a
## joined player, until the host sends it back).
func do(op: Dictionary, author: String = LOCAL) -> Dictionary:
	if send.is_valid() and author == LOCAL:
		_last_undo = {}
		send.call("op", {"op": op})
		return _last_undo
	return apply_op(op, _who(author))


## The local player's author id.
func _who(author: String) -> String:
	if author == LOCAL and me.is_valid():
		return str(me.call())
	return author


## Applies an op from `author` (every machine, in the host's order).
func apply_op(op: Dictionary, author: String) -> Dictionary:
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
	_last_undo = undo_op
	return undo_op


func can_undo(author: String = LOCAL) -> bool:
	return not (_undo.get(_who(author), []) as Array).is_empty()


func can_redo(author: String = LOCAL) -> bool:
	return not (_redo.get(_who(author), []) as Array).is_empty()


func undo(author: String = LOCAL) -> bool:
	if send.is_valid() and author == LOCAL:
		_last_ok = false
		send.call("undo", {})
		return _last_ok
	return apply_undo(_who(author))


func redo(author: String = LOCAL) -> bool:
	if send.is_valid() and author == LOCAL:
		_last_ok = false
		send.call("redo", {})
		return _last_ok
	return apply_redo(_who(author))


## Undoes `author`'s last edit that still applies (every machine).
func apply_undo(author: String) -> bool:
	_last_ok = _undo_step(author)
	return _last_ok


## Redoes `author`'s last undone edit (every machine).
func apply_redo(author: String) -> bool:
	_last_ok = _redo_step(author)
	return _last_ok


func _undo_step(author: String) -> bool:
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


func _redo_step(author: String) -> bool:
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
