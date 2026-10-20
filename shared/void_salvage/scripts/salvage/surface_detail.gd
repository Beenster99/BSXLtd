class_name SurfaceDetail
extends RefCounted
## The detail maps of the salvage surface (docs/ECONOMY_PLAN.md section 7, A1 revised): a
## few tiling procedural textures baked once, the first time a surface needs them, and
## shared by every salvage and ship surface. The shader projects them onto each part in its
## own space (triplanar: the meshes have no UVs) at each finish's own scale, so the grain
## stays put on the part as it moves and a leather seat's pebbling is finer than a cast
## iron housing's lumps.
##   detail_map    R soft grain (two octaves, features about a tenth of the tile: paint
##                 orange peel, brushed lines when stretched, cast lumps when strong)
##                 G cells (a Worley tile: 1 inside a cell, 0 on the walls; chalk, pores,
##                 leather pebbles, galvanised spangles)
##                 B blotches (one broad octave: roughness and tone patches)
##                 A one random value per cell (spangle tone, tile tone)
##   detail_normal RG the grain's normal, BA the cells' normal (x, y; z rebuilt in the shader)
## The maps are band-limited on purpose: nothing in them is a speck. Specks were the A1 look
## everyone called stippled. Presentation only: nothing here is game state or sent.

## Texture size (px, square). Each tile covers a finish's `scale` metres.
const SIZE: int = 256
## Fixed seeds, so every machine and every run gets the same look.
const SEED: int = 7311
## Cells across a tile.
const CELLS: int = 6
## How steep the baked normals are, per height unit per pixel (the shader scales them by a
## finish's bump).
const GRAIN_SLOPE: float = 1.2
const CELL_SLOPE: float = 1.6

static var _map: ImageTexture
static var _normal: ImageTexture
## How long the last bake took (ms), for the perf notes.
static var bake_ms: float = 0.0


## Puts the detail maps and the finish table (SurfaceFinish) on a salvage surface material,
## and turns its detail layer on.
static func apply(m: ShaderMaterial) -> void:
	_bake()
	m.set_shader_parameter("detail_map", _map)
	m.set_shader_parameter("detail_normal", _normal)
	m.set_shader_parameter("detail_on", 1.0)
	SurfaceZones.apply(m)


static func detail_map() -> ImageTexture:
	_bake()
	return _map


static func detail_normal() -> ImageTexture:
	_bake()
	return _normal


static func _bake() -> void:
	if _map != null:
		return
	var started := Time.get_ticks_usec()
	var grain := _heights(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 1.0 / 26.0, 2, SEED))
	var blotch := _heights(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 1.0 / 90.0, 1, SEED + 2))
	var cells := PackedFloat32Array()
	var rand := PackedFloat32Array()
	_cells(cells, rand)
	var n := SIZE * SIZE
	var map := PackedByteArray()
	map.resize(n * 4)
	var normal := PackedByteArray()
	normal.resize(n * 4)
	for y in SIZE:
		var up := ((y + SIZE - 1) % SIZE) * SIZE
		var down := ((y + 1) % SIZE) * SIZE
		var row := y * SIZE
		for x in SIZE:
			var i := row + x
			var left := row + (x + SIZE - 1) % SIZE
			var right := row + (x + 1) % SIZE
			map[i * 4] = int(grain[i] * 255.0)
			map[i * 4 + 1] = int(cells[i] * 255.0)
			map[i * 4 + 2] = int(blotch[i] * 255.0)
			map[i * 4 + 3] = int(rand[i] * 255.0)
			# Slopes by central differences (wrapping, so the tile stays seamless).
			normal[i * 4] = _slope(grain[left] - grain[right], GRAIN_SLOPE)
			normal[i * 4 + 1] = _slope(grain[up + x] - grain[down + x], GRAIN_SLOPE)
			normal[i * 4 + 2] = _slope(cells[left] - cells[right], CELL_SLOPE)
			normal[i * 4 + 3] = _slope(cells[up + x] - cells[down + x], CELL_SLOPE)
	_map = _texture(map)
	_normal = _texture(normal)
	bake_ms = float(Time.get_ticks_usec() - started) / 1000.0


static func _noise(type: FastNoiseLite.NoiseType, frequency: float, octaves: int, seed: int) -> FastNoiseLite:
	var f := FastNoiseLite.new()
	f.noise_type = type
	f.frequency = frequency
	f.seed = seed
	f.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	f.fractal_octaves = octaves
	f.fractal_gain = 0.4
	return f


## Cells that tile (a jittered point per square of a CELLS x CELLS grid, wrapping): `walls`
## gets a rounded dome per cell (0 on a wall, 1 at its middle, eased so the slopes are soft:
## pebbles, not pits), `rand` one random value per cell. FastNoiseLite's seamless images
## blend their edges, which cuts cells in half down the middle of the tile.
static func _cells(walls: PackedFloat32Array, rand: PackedFloat32Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 1
	var pts := PackedVector2Array()
	var vals := PackedFloat32Array()
	for i in CELLS * CELLS:
		pts.append(Vector2(0.2 + rng.randf() * 0.6, 0.2 + rng.randf() * 0.6))
		vals.append(rng.randf())
	var step := float(SIZE) / float(CELLS)
	walls.resize(SIZE * SIZE)
	rand.resize(SIZE * SIZE)
	for y in SIZE:
		var gy := int(float(y) / step)
		for x in SIZE:
			var gx := int(float(x) / step)
			var p := Vector2(float(x) + 0.5, float(y) + 0.5) / step
			var d1 := 9.0
			var d2 := 9.0
			var v := 0.0
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var cx := gx + ox
					var cy := gy + oy
					var k := posmod(cy, CELLS) * CELLS + posmod(cx, CELLS)
					var d := p.distance_to(Vector2(cx, cy) + pts[k])
					if d < d1:
						d2 = d1
						d1 = d
						v = vals[k]
					elif d < d2:
						d2 = d
			var w := clampf((d2 - d1) * 1.4, 0.0, 1.0)
			walls[y * SIZE + x] = w * w * (3.0 - 2.0 * w)
			rand[y * SIZE + x] = v


## A seamless tile of `noise` as heights 0..1, row by row, stretched to use the whole range.
static func _heights(noise: FastNoiseLite) -> PackedFloat32Array:
	var img := noise.get_seamless_image(SIZE, SIZE, false, false, 0.1, true)
	img.convert(Image.FORMAT_L8)
	var bytes := img.get_data()
	var out := PackedFloat32Array()
	out.resize(bytes.size())
	var lo := 255
	var hi := 0
	for b in bytes:
		lo = mini(lo, b)
		hi = maxi(hi, b)
	var span := float(maxi(hi - lo, 1))
	for i in bytes.size():
		out[i] = float(bytes[i] - lo) / span
	return out


static func _slope(dh: float, k: float) -> int:
	return clampi(int((clampf(dh * k, -1.0, 1.0) * 0.5 + 0.5) * 255.0), 0, 255)


static func _texture(bytes: PackedByteArray) -> ImageTexture:
	var img := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, bytes)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
