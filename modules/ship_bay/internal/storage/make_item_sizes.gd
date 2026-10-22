extends SceneTree
## Writes item_sizes.json: the box (x across, y up, z along; metres) each catalogue item
## takes, as ItemLook draws it. StorageLayout shelves parts by it without building their
## meshes. Run it again when the catalogue or a part's look changes (test_storage checks):
##
##     godot --headless --path . -s modules/ship_bay/internal/storage/make_item_sizes.gd

const OUT := "res://modules/ship_bay/internal/storage/item_sizes.json"


func _init() -> void:
	var layout: GDScript = load("res://modules/ship_bay/internal/storage/storage_layout.gd")
	var look: GDScript = load("res://modules/ship_bay/internal/yard/item_look.gd")
	var items: Dictionary = layout.call("items")
	var ids: Array = items.keys()
	ids.sort()
	var sizes := {}
	for id: String in ids:
		var s: Vector3 = look.call("size_of", id)
		sizes[id] = [snappedf(s.x, 0.001), snappedf(s.y, 0.001), snappedf(s.z, 0.001)]
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"sizes": sizes}, "\t") + "\n")
	f.close()
	print("wrote %d sizes" % sizes.size())
	quit()
