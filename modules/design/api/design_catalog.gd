class_name DesignCatalog
extends RefCounted
## The room types and components the designer offers, read from the module's data folders.

const ROOMS_DIR := "res://modules/design/internal/data/rooms"
const PARTS_DIR := "res://modules/design/internal/data/components"
## Order rooms appear in on the palette.
const ROOM_ORDER: PackedStringArray = ["bridge", "airlock", "corridor", "stairs", "lift", "quarters",
		"mess", "medbay", "cargo", "engineering", "reactor", "fuel", "workshop"]

var rooms: Dictionary = {}  # id -> DesignRoomType
var parts: Dictionary = {}  # id -> DesignPartType


static func load_default() -> DesignCatalog:
	var c := DesignCatalog.new()
	for res in _load_dir(ROOMS_DIR):
		var r := res as DesignRoomType
		if r:
			c.rooms[r.id] = r
	for res in _load_dir(PARTS_DIR):
		var p := res as DesignPartType
		if p:
			# A part built from a Void Salvage part takes its size and mass as built.
			if p.shared_part != "" and VsParts.has(p.shared_part):
				p.size = VsParts.size(p.shared_part)
				p.mass = VsParts.mass(p.shared_part)
				if p.nozzle_down:
					p.size = Vector3(p.size.x, p.size.z, p.size.y)
			c.parts[p.id] = p
	return c


func room(type_id: String) -> DesignRoomType:
	return rooms.get(type_id)


func part(type_id: String) -> DesignPartType:
	return parts.get(type_id)


## Room types in palette order.
func room_list() -> Array[DesignRoomType]:
	var out: Array[DesignRoomType] = []
	for id in ROOM_ORDER:
		if rooms.has(id):
			out.append(rooms[id])
	for id: String in rooms:
		if not id in ROOM_ORDER:
			out.append(rooms[id])
	return out


## Components that may go in a room of this type, by name.
func parts_for(room_type: String) -> Array[DesignPartType]:
	var out: Array[DesignPartType] = []
	for p: DesignPartType in parts.values():
		if p.rooms.is_empty() or room_type in p.rooms:
			out.append(p)
	out.sort_custom(func(a, b): return a.display_name < b.display_name)
	return out


static func _load_dir(dir_path: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var files := ResourceLoader.list_directory(dir_path)
	var names: Array = Array(files)
	names.sort()
	for f: String in names:
		if f.ends_with(".tres") or f.ends_with(".res"):
			var res := load(dir_path.path_join(f))
			if res:
				out.append(res)
	return out
