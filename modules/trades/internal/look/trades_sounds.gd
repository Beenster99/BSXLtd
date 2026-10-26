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


static func clang(heavy: float) -> AudioStreamWAV:
	var key := roundi(clampf(heavy, 0.0, 1.0) * 10.0)
	if _clangs.has(key):
		return _clangs[key]
	var h := key / 10.0
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
		var thud := sin(TAU * thud_hz * t) * exp(-t * 22.0) * (0.4 + h * 0.6)
		var v := (ring * 0.32 + knock + thud) * 0.75
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767))
	var wav := _wav(data, rate, false)
	_clangs[key] = wav
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
