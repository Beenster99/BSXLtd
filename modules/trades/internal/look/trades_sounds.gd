class_name TradesSounds
extends RefCounted
## Made sounds, like Void Salvage's procedural suit and tool audio: no sound files.


## A short decaying noise burst, low-passed to taste: the wrench click and thread ticks.
static func burst(seconds: float, volume: float, cutoff_hz: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(seconds * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var a := clampf(TAU * cutoff_hz / rate, 0.0, 1.0)
	var y := 0.0
	for i in n:
		y += a * (rng.randf_range(-1.0, 1.0) - y)
		var env := exp(-6.0 * float(i) / n)
		data.encode_s16(i * 2, int(clampf(y * env * volume * 3.0, -1.0, 1.0) * 32767))
	return _wav(data, rate, false)


## A looping buzz: a tone at `tone_hz` with its harmonics under band-limited noise (a drill
## motor, the welding arc's crackle).
static func hum(seconds: float, volume: float, tone_hz: float, noise_hz: float) -> AudioStreamWAV:
	var rate := 22050
	# Whole tone cycles, so the loop joins without a click.
	var cycles := maxi(1, roundi(seconds * tone_hz))
	var n := int(round(cycles * rate / tone_hz))
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var a := clampf(TAU * noise_hz / rate, 0.0, 1.0)
	var y := 0.0
	for i in n:
		var t := float(i) / rate
		var tone := sin(TAU * tone_hz * t) * 0.5 + sin(TAU * tone_hz * 2.0 * t) * 0.25 + sin(TAU * tone_hz * 3.0 * t) * 0.12
		y += a * (rng.randf_range(-1.0, 1.0) - y)
		data.encode_s16(i * 2, int(clampf((tone * 0.6 + y * 1.6) * volume, -1.0, 1.0) * 32767))
	return _wav(data, rate, true)


## A looping impact-wrench rattle: a motor tone hammered on and off `blows_hz` times a second.
static func rattle(seconds: float, volume: float, tone_hz: float, blows_hz: float) -> AudioStreamWAV:
	var rate := 22050
	var cycles := maxi(1, roundi(seconds * blows_hz))
	var n := int(round(cycles * rate / blows_hz))
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var y := 0.0
	for i in n:
		var t := float(i) / rate
		var phase := fmod(t * blows_hz, 1.0)
		var blow := exp(-phase * 14.0)
		y += 0.35 * (rng.randf_range(-1.0, 1.0) - y)
		var tone := sin(TAU * tone_hz * t) * 0.4 + sin(TAU * tone_hz * 2.0 * t) * 0.2
		data.encode_s16(i * 2, int(clampf((tone * 0.5 + y * blow * 2.2) * volume, -1.0, 1.0) * 32767))
	return _wav(data, rate, true)


## A metal part landing: a sharp knock, then a few inharmonic ringing modes (a struck plate's)
## dying away, with a thud under it. `heavy` 0..1 lengthens the ring and deepens the thud.
## Cached per tenth of `heavy`.
static var _clangs: Dictionary = {}


static func clang(heavy: float, hard := 0.0) -> AudioStreamWAV:
	# trades.metal_sounds: a hard landing bounces, two smaller knocks after the first.
	var bounces := hard >= 0.5 and Flags.is_on("trades.metal_sounds")
	var key := roundi(clampf(heavy, 0.0, 1.0) * 10.0) + (100 if bounces else 0)
	if _clangs.has(key):
		return _clangs[key]
	var h := (key % 100) / 10.0
	var rate := 22050
	var seconds := lerpf(0.45, 1.1, h)
	var n := int(seconds * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 17 + key
	# A plate's modes: far from whole multiples, so it rings rather than hums.
	var base := lerpf(620.0, 240.0, h)
	var modes := [[1.0, 1.0, 9.0], [1.59, 0.7, 11.0], [2.14, 0.55, 14.0], [2.65, 0.4, 18.0], [3.91, 0.3, 24.0]]
	var thud_hz := lerpf(140.0, 60.0, h)
	var y := 0.0
	for i in n:
		var t := float(i) / rate
		var ring := 0.0
		for m: Array in modes:
			ring += sin(TAU * base * float(m[0]) * t + float(m[0])) * float(m[1]) * exp(-t * float(m[2]) / lerpf(1.0, 1.8, h))
		y += 0.5 * (rng.randf_range(-1.0, 1.0) - y)
		var knock := y * exp(-t * 90.0) * 1.4
		if bounces:
			for b: Array in [[0.11, 0.55], [0.19, 0.3]]:
				if t > float(b[0]):
					knock += y * exp(-(t - float(b[0])) * 110.0) * 1.4 * float(b[1])
		var thud := sin(TAU * thud_hz * t) * exp(-t * 22.0) * (0.4 + h * 0.6)
		var v := (ring * 0.32 + knock + thud) * 0.75
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767))
	var wav := _wav(data, rate, false)
	_clangs[key] = wav
	return wav


## trades.metal_sounds (beenster, 0.3.26: "sound effects ... for metal removal and noises when
## the metal hits the floor"; made here, as Void Salvage's recordings are licensed to it only).
## A joint giving way: "bolt" the thread letting go with a ringing tonk, "rivet" a sharp snap
## and ping as the head shears, "weld" a crack and the seam tearing. Cached per kind.
static var _gives: Dictionary = {}


static func give(kind: String) -> AudioStreamWAV:
	if _gives.has(kind):
		return _gives[kind]
	var rate := 22050
	var spec: Dictionary = {
		"bolt": {"s": 0.55, "ring": 1180.0, "ring_k": 9.0, "ring_v": 0.35, "low": 210.0, "low_v": 0.5, "crack": 0.9, "tear": 0.0},
		"rivet": {"s": 0.35, "ring": 2650.0, "ring_k": 16.0, "ring_v": 0.4, "low": 420.0, "low_v": 0.2, "crack": 1.2, "tear": 0.0},
		"weld": {"s": 0.6, "ring": 760.0, "ring_k": 7.0, "ring_v": 0.25, "low": 120.0, "low_v": 0.55, "crack": 1.1, "tear": 0.32},
	}.get(kind, {"s": 0.3, "ring": 900.0, "ring_k": 14.0, "ring_v": 0.2, "low": 300.0, "low_v": 0.3, "crack": 0.8, "tear": 0.0})
	var n := int(float(spec.s) * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var hi := 0.0
	var lo := 0.0
	var ring_hz: float = spec.ring
	var modes := [[1.0, 1.0], [1.47, 0.6], [2.31, 0.4], [3.12, 0.25]]
	var tear_s: float = spec.tear
	for i in n:
		var t := float(i) / rate
		var noise := rng.randf_range(-1.0, 1.0)
		hi += 0.85 * (noise - hi)
		lo += 0.12 * (noise - lo)
		# The crack: bright noise gone in a few milliseconds.
		var crack := (noise - hi * 0.5) * exp(-t * 160.0) * float(spec.crack)
		var ring := 0.0
		for m: Array in modes:
			ring += sin(TAU * ring_hz * float(m[0]) * t + float(m[0]) * 2.0) * float(m[1])
		ring *= exp(-t * float(spec.ring_k)) * float(spec.ring_v)
		var low := sin(TAU * float(spec.low) * t) * exp(-t * 26.0) * float(spec.low_v)
		# A weld's seam tearing: gritty noise in bursts along it.
		var tear := 0.0
		if tear_s > 0.0 and t > 0.02 and t < 0.02 + tear_s:
			var grit := absf(sin(TAU * 37.0 * t + sin(TAU * 11.0 * t) * 3.0))
			tear = lo * 2.2 * grit * (1.0 - (t - 0.02) / tear_s)
		var v := (crack + ring + low + tear) * 0.8
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767))
	var wav := _wav(data, rate, false)
	_gives[kind] = wav
	return wav


## A small metal bit (a bolt, a rivet's head) hitting the floor: a bright tink, a little
## different for each of a few variants.
static var _tinks: Dictionary = {}


static func tink(variant: int) -> AudioStreamWAV:
	var key := posmod(variant, 4)
	if _tinks.has(key):
		return _tinks[key]
	var rate := 22050
	var n := int(0.22 * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31 + key
	var base := 2900.0 + key * 410.0
	var y := 0.0
	for i in n:
		var t := float(i) / rate
		y += 0.9 * (rng.randf_range(-1.0, 1.0) - y)
		var ring := sin(TAU * base * t) * exp(-t * 28.0) + sin(TAU * base * 1.73 * t + 1.0) * 0.5 * exp(-t * 40.0) \
				+ sin(TAU * base * 2.41 * t + 2.0) * 0.3 * exp(-t * 55.0)
		var v := (y * exp(-t * 400.0) * 0.8 + ring * 0.45) * 0.8
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767))
	var wav := _wav(data, rate, false)
	_tinks[key] = wav
	return wav


static func _wav(data: PackedByteArray, rate: int, looped: bool) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = data.size() / 2
	return wav
