extends SceneTree
## Lists the size of every array and dictionary stored in the project's resources and
## scenes, so release.sh can check that a packaged build carries the same data as the
## source tree. Run it on both and compare:
##   godot --headless --path . -s tools/build/pack_probe.gd -- --out=src.json
##   godot --headless --main-pack BSXLtd.exe -s <abs path>/pack_probe.gd -- --out=pack.json

const SKIP: Array[String] = ["res://.godot", "res://addons", "res://release"]

var _out: Dictionary = {}


func _initialize() -> void:
	await process_frame # autoloads first, so scripts naming them compile
	var path: String = "user://pack_probe.json"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			path = a.substr(6)
	_walk("res://")
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(_out, "\t", true))
	f.close()
	print("pack_probe: %d entries -> %s" % [_out.size(), path])
	quit()


func _walk(dir: String) -> void:
	if dir in SKIP or dir.ends_with("/tests"):
		return
	for d: String in DirAccess.get_directories_at(dir):
		_walk(dir.path_join(d))
	for f: String in DirAccess.get_files_at(dir):
		var p: String = dir.path_join(f.trim_suffix(".remap"))
		if p.ends_with(".tres") or p.ends_with(".res"):
			_resource(p)
		elif p.ends_with(".tscn"):
			_scene(p)


func _size(v: Variant) -> int:
	match typeof(v):
		TYPE_ARRAY, TYPE_DICTIONARY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, \
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, \
		TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, \
		TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			return v.size()
	return -1


func _resource(p: String) -> void:
	var r: Resource = ResourceLoader.load(p)
	if r == null:
		_out[p] = -1
		return
	for prop: Dictionary in r.get_property_list():
		if prop.usage & PROPERTY_USAGE_STORAGE:
			var n: int = _size(r.get(prop.name))
			if n >= 0:
				_out["%s:%s" % [p, prop.name]] = n


func _scene(p: String) -> void:
	var ps: PackedScene = ResourceLoader.load(p) as PackedScene
	if ps == null:
		_out[p] = -1
		return
	var st: SceneState = ps.get_state()
	for i: int in st.get_node_count():
		for j: int in st.get_node_property_count(i):
			var n: int = _size(st.get_node_property_value(i, j))
			if n >= 0:
				_out["%s/%s:%s" % [p, st.get_node_path(i), st.get_node_property_name(i, j)]] = n
