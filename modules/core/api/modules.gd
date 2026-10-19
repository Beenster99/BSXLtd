extends Node
## Module loader (autoload `Modules`). At boot it reads every modules/<id>/module.tres, and
## for each module whose flag is on and whose dependencies loaded, adds the module's bus node
## here (in dependency order) and calls its register_module(). Modules talk through those
## buses: `Modules.bus("trades") as TradesBus`.

signal modules_ready

const ROOT := "res://modules"
## Core is the autoloads themselves, so it has no bus and is always loaded.
const BUILT_IN: PackedStringArray = ["core"]

var ready_done := false
var _manifests: Dictionary = {}
var _loaded: PackedStringArray = []
var _skipped: Dictionary = {}


func _ready() -> void:
	load_all.call_deferred()


func load_all() -> void:
	unload_all()
	_manifests = read_manifests(ROOT)
	for id in load_order(_manifests):
		var m: ModuleManifest = _manifests[id]
		var why := _reason_to_skip(m)
		if why != "":
			_skipped[id] = why
			continue
		if m.bus:
			var node: Node = m.bus.new()
			node.name = id
			add_child(node)
			if node.has_method("register_module"):
				node.register_module()
		_loaded.append(id)
	ready_done = true
	modules_ready.emit()


func unload_all() -> void:
	for child in get_children():
		if child.has_method("unregister_module"):
			child.unregister_module()
		remove_child(child)
		child.queue_free()
	_loaded = []
	_skipped = {}
	ready_done = false


func is_loaded(id: String) -> bool:
	return id in BUILT_IN or id in _loaded


func loaded() -> PackedStringArray:
	return _loaded.duplicate()


## Why a module was not loaded ("flag off", "needs ship_bay"), or "" if it was.
func skipped_reason(id: String) -> String:
	return _skipped.get(id, "")


func bus(id: String) -> Node:
	return get_node_or_null(NodePath(id))


func manifest(id: String) -> ModuleManifest:
	return _manifests.get(id)


func _reason_to_skip(m: ModuleManifest) -> String:
	if not Flags.is_on(m.flag if m.flag != "" else m.id):
		return "flag off"
	for dep in m.depends_on:
		if not is_loaded(dep):
			return "needs %s" % dep
	return ""


static func read_manifests(root: String) -> Dictionary:
	var out := {}
	for entry in ResourceLoader.list_directory(root):
		if not entry.ends_with("/"):
			continue
		var id := entry.trim_suffix("/")
		var path := "%s/%s/module.tres" % [root, id]
		if id in BUILT_IN or not ResourceLoader.exists(path):
			continue
		var m := load(path) as ModuleManifest
		if m == null or m.id != id:
			push_error("Modules: %s is not a ModuleManifest for '%s'" % [path, id])
			continue
		out[id] = m
	return out


## Dependencies first; ties broken by id so the order is stable. Cycles are reported and
## the modules in them left out.
static func load_order(manifests: Dictionary) -> PackedStringArray:
	var order: PackedStringArray = []
	var state := {}
	var ids := manifests.keys()
	ids.sort()
	for id in ids:
		_visit(id, manifests, state, order)
	return order


static func _visit(id: String, manifests: Dictionary, state: Dictionary, order: PackedStringArray) -> bool:
	if state.get(id) == 2:
		return true
	if state.get(id) == 1:
		push_error("Modules: dependency cycle through '%s'" % id)
		return false
	if not manifests.has(id):
		return id in BUILT_IN
	state[id] = 1
	var ok := true
	for dep in manifests[id].depends_on:
		ok = _visit(dep, manifests, state, order) and ok
	state[id] = 2
	if ok:
		order.append(id)
	return ok
