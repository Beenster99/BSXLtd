class_name ShipBayBus
extends Node
## Ship and Bay module bus (Modules.bus("ship_bay")). Loads a ship into a bay, knows where
## every part attaches (mount slots and their fasteners), and tracks each slot from fitted
## to stripped to installed.
##
## Methods are requests and the signals are the results; Multiplayer will run the requests
## on the host and replay the signals. Trades sits above this module, so it reports its work
## here (note_joint_made / note_joint_removed) rather than this module listening to it.
## Doc: https://claude.ai/code/artifact/90dd6ae6-1824-4c96-b030-11772e90cd28

enum SlotState { FITTED, LOOSENED, EMPTY, POSITIONED, INSTALLED }

signal ship_loaded(ship_id: String)
signal ship_unloaded(ship_id: String)
signal slot_state_changed(slot_id: String, old_state: SlotState, new_state: SlotState)
signal component_removed(slot_id: String, component: String)
signal component_positioned(slot_id: String, component: String)
signal component_installed(slot_id: String, component: String)

## Router scene id of the bay (registered while the "ship_bay.bay_view" flag is on).
const BAY_SCENE := "ship_bay.bay"
const SAVE_VERSION := 1
## Ship id -> its folder (layout, fasteners, model).
const SHIPS := {"vs_kestrel": "res://modules/ship_bay/internal/ships/kestrel"}

const LayoutLoader := preload("res://modules/ship_bay/internal/layout_loader.gd")
const SlotTracker := preload("res://modules/ship_bay/internal/slot_tracker.gd")

## The ship in the bay, or null.
var ship: ShipDefinition
var _tracker: SlotTracker
var _definitions: Dictionary = {}


func register_module() -> void:
	Saves.register_section("ship_bay", self)
	if Flags.is_on("ship_bay.bay_view"):
		Router.register_scene(BAY_SCENE, "res://modules/ship_bay/internal/bay/bay.tscn")
		Shots.register("kestrel_in_bay", BAY_SCENE)


func unregister_module() -> void:
	Saves.unregister_section("ship_bay")


## Ships BSX can take into a bay.
func ship_ids() -> PackedStringArray:
	return PackedStringArray(SHIPS.keys())


## The definition of a known ship (read once, then cached), or null.
func definition(ship_id: String) -> ShipDefinition:
	if not _definitions.has(ship_id) and SHIPS.has(ship_id):
		_definitions[ship_id] = LayoutLoader.load_ship(SHIPS[ship_id])
	return _definitions.get(ship_id)


func load_ship(ship_id: String) -> bool:
	var def := definition(ship_id)
	if def == null:
		return false
	if ship:
		unload_ship()
	ship = def
	_tracker = SlotTracker.new(def, _emit)
	ship_loaded.emit(ship_id)
	return true


func unload_ship() -> void:
	if ship == null:
		return
	var id := ship.ship_id
	ship = null
	_tracker = null
	ship_unloaded.emit(id)


func get_slots() -> Array[MountSlot]:
	return ship.slots if ship else ([] as Array[MountSlot])


func get_slot(slot_id: String) -> MountSlot:
	return ship.slot(slot_id) if ship else null


## The slot's state, or -1 when no ship is loaded or it has no such slot.
func get_slot_state(slot_id: String) -> int:
	return _tracker.state(slot_id) if _tracker else -1


## What sits in the slot now ("" when empty).
func get_component(slot_id: String) -> String:
	return _tracker.component(slot_id) if _tracker else ""


func get_fasteners(slot_id: String) -> Array[FastenerPoint]:
	var s := get_slot(slot_id)
	return s.fasteners if s else ([] as Array[FastenerPoint])


func is_joint_tight(joint_id: String) -> bool:
	return _tracker != null and _tracker.is_tight(joint_id)


## 0..1 as Trades reported it; 0 when the joint isn't made.
func joint_quality(joint_id: String) -> float:
	return _tracker.joint_quality(joint_id) if _tracker else 0.0


## Holds `component` in an empty slot that takes it, ready to fasten.
func try_position(slot_id: String, component: String) -> bool:
	return _tracker != null and _tracker.try_position(slot_id, component)


## Lifts a positioned part back out before any joint holds it.
func try_remove(slot_id: String) -> bool:
	return _tracker != null and _tracker.try_remove(slot_id)


## Trades: a joint was made (bolt torqued, rivet set, seam welded, plug seated).
func note_joint_made(joint_id: String, quality: float) -> bool:
	return _tracker != null and _tracker.joint_made(joint_id, quality)


## Trades: a joint was undone.
func note_joint_removed(joint_id: String) -> bool:
	return _tracker != null and _tracker.joint_removed(joint_id)


## Everything needed to put the bay back as it is: saves and late-joining players.
func snapshot() -> Dictionary:
	if ship == null:
		return {}
	return {"ship_id": ship.ship_id, "slots": _tracker.snapshot()}


func restore(state: Dictionary) -> void:
	var id: String = state.get("ship_id", "")
	if id == "":
		unload_ship()
		return
	if (ship == null or ship.ship_id != id) and not load_ship(id):
		return
	_tracker.restore(state.get("slots", {}))


func save_version() -> int:
	return SAVE_VERSION


func save_data() -> Dictionary:
	return snapshot()


func load_data(data: Dictionary, _from_version: int) -> void:
	restore(data)


func _emit(signal_name: String, args: Array) -> void:
	emit_signal.callv([signal_name] + args)
