extends Node
## Key bindings (autoload `Keys`). Every key the game reads is an input action registered
## here with a label and a default key; the player can rebind any of them in Settings > Key
## binds, saved in Settings section "keys" (action -> physical keycode). Modules register
## their own from register_module() and read them as plain input actions:
##   Keys.register("ship_bay.call_trolley", "Call a trolley", KEY_T, "Trolleys")
##   if event.is_action_pressed("ship_bay.call_trolley"): ...
##   label.text = "%s  Order parts" % Keys.prompt(Keys.INTERACT)     # "[F]  Order parts"
## Core's own actions below are shared by every scene: F is the one doing key (use, pick
## up, open, press), whatever the thing is.

signal changed(action: String)

const SECTION := "keys"

const FORWARD := "move_forward"
const BACK := "move_back"
const LEFT := "move_left"
const RIGHT := "move_right"
const RUN := "run"
const JUMP := "jump"
const CROUCH := "crouch"
## The doing key: use, open, pick up, press, sit, talk to a terminal.
const INTERACT := "interact"
## The wrist screen.
const HOLO := "holo"
const CANCEL := "cancel"

const MOVEMENT := "Movement"
const ACTIONS := "Actions"

## action -> {action, label, group, default (physical keycode), order}
var _actions: Dictionary = {}
var _order := 0


func _ready() -> void:
	Settings.register(SECTION, {})
	register(FORWARD, "Walk forward", KEY_W, MOVEMENT)
	register(BACK, "Walk back", KEY_S, MOVEMENT)
	register(LEFT, "Step left", KEY_A, MOVEMENT)
	register(RIGHT, "Step right", KEY_D, MOVEMENT)
	register(RUN, "Run (hold)", KEY_SHIFT, MOVEMENT)
	register(JUMP, "Jump", KEY_SPACE, MOVEMENT)
	register(CROUCH, "Crouch", KEY_C, MOVEMENT)
	register(INTERACT, "Use / do", KEY_F, ACTIONS)
	register(HOLO, "Wrist screen", KEY_F1, ACTIONS)
	register(CANCEL, "Back / close", KEY_ESCAPE, ACTIONS)


## Adds (or replaces) an action with its default key; a saved rebind wins over the default.
func register(action: String, label: String, default_key: Key, group: String = ACTIONS) -> void:
	_order += 1
	var order: int = _actions[action].order if _actions.has(action) else _order
	_actions[action] = {"action": action, "label": label, "group": group,
			"default": int(default_key), "order": order}
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	_apply(action)


func unregister(action: String) -> void:
	_actions.erase(action)
	if InputMap.has_action(action):
		InputMap.erase_action(action)


func has(action: String) -> bool:
	return _actions.has(action)


## Every registered action, Core's first, then in the order modules registered them.
func actions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a: Dictionary in _actions.values():
		out.append(a.duplicate())
	out.sort_custom(func(x, y): return x.order < y.order)
	return out


## The physical keycode an action is on now.
func key_of(action: String) -> Key:
	if not _actions.has(action):
		return KEY_NONE
	var saved: Variant = Settings.get_value(SECTION, action)
	return int(saved) as Key if saved != null else _actions[action].default as Key


func default_of(action: String) -> Key:
	return _actions[action].default as Key if _actions.has(action) else KEY_NONE


## "F", "Shift", "F1" for the key an action is on.
func key_name(action: String) -> String:
	var k := key_of(action)
	return "-" if k == KEY_NONE else OS.get_keycode_string(k)


## "[F]": for prompts on screens and labels.
func prompt(action: String) -> String:
	return "[%s]" % key_name(action)


## Puts an action on another key and saves it. KEY_NONE leaves it unbound.
func rebind(action: String, key: Key) -> void:
	if not _actions.has(action):
		return
	if key == default_of(action):
		Settings.set_value(SECTION, action, null)
	else:
		Settings.set_value(SECTION, action, int(key))
	Settings.save()
	_apply(action)


func reset(action: String) -> void:
	rebind(action, default_of(action))


func reset_all() -> void:
	for action: String in _actions:
		reset(action)


## Other actions on the same key as `action` (the Key binds screen flags them).
func clashes(action: String) -> PackedStringArray:
	var out := PackedStringArray()
	var k := key_of(action)
	if k == KEY_NONE:
		return out
	for other: String in _actions:
		if other != action and key_of(other) == k:
			out.append(other)
	return out


func label_of(action: String) -> String:
	return _actions[action].label if _actions.has(action) else action


func _apply(action: String) -> void:
	InputMap.action_erase_events(action)
	var k := key_of(action)
	if k != KEY_NONE:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	changed.emit(action)
