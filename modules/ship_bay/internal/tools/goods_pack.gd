extends SceneTree
## Packs Void Salvage's own look for every catalogue item the stores would otherwise draw as a
## stand-in box (beenster, 0.3.27: "these should be rendered as their actual parts"): for each,
## one part of that name from Void Salvage's wrecks (the middling one by mass), its recipe or
## its triangles, and its paint, into GOODS_FILE, read by ItemLook. Re-run after the wrecks
## are re-packed (tools/vs_wrecks.sh):
##   godot --headless --path . -s res://modules/ship_bay/internal/tools/goods_pack.gd

const ItemLook := preload("res://modules/ship_bay/internal/yard/item_look.gd")
const StorageLayout := preload("res://modules/ship_bay/internal/storage/storage_layout.gd")


func _init() -> void:
	# Every part name on the wrecks (the market sells any of them) and every stores item.
	var want := {}
	var names := {}
	for item: String in StorageLayout.items():
		names[item] = true
	for design: String in VsWreckLibrary.index():
		for p: Dictionary in VsWreckLibrary.file_of(design).get("parts", []):
			names[str(p.get("name", ""))] = true
	for item: String in names:
		if item != "" and ItemLook.needs_vs_look(item):
			want[item] = []
	# Every part of a wanted name across the wrecks: [design, part, mass].
	for design: String in VsWreckLibrary.index():
		var f := VsWreckLibrary.file_of(design)
		for p: Dictionary in f.get("parts", []):
			var n := str(p.get("name", ""))
			if want.has(n):
				(want[n] as Array).append([design, p, float(p.get("mass", 0.0))])
	var out := {"parts": {}, "meshes": [], "materials": {}}
	var missing := PackedStringArray()
	for item: String in want:
		var found: Array = want[item]
		if found.is_empty():
			missing.append(item)
			continue
		found.sort_custom(func(a: Array, b: Array) -> bool: return a[2] < b[2])
		var pick: Array = found[found.size() / 2]
		var f := VsWreckLibrary.file_of(pick[0])
		var p: Dictionary = (pick[1] as Dictionary).duplicate(true)
		var shape: Dictionary = p.get("shape", {})
		if str(shape.get("shape", "")) == "vs_mesh":
			var i := int((shape.get("args", [0]) as Array)[0])
			(out["meshes"] as Array).append(f["meshes"][i])
			shape["args"] = [(out["meshes"] as Array).size() - 1]
		out["parts"][item] = p
		out["materials"][item] = f.get("materials", {}).get(str(p.get("mat", "")), {})
	var bytes := var_to_bytes(out)
	var packed := bytes.compress(FileAccess.COMPRESSION_ZSTD)
	# A plain resource (it exports with the game, unlike a loose data file): the size and the
	# zstd bytes as metadata.
	var r := Resource.new()
	r.set_meta("size", bytes.size())
	r.set_meta("zstd", packed)
	ResourceSaver.save(r, ItemLook.GOODS_FILE)
	print("goods_pack: %d items from Void Salvage's wrecks, %d with none (%s), %d bytes" % [
			(out["parts"] as Dictionary).size(), missing.size(), ", ".join(missing), packed.size()])
	quit()
