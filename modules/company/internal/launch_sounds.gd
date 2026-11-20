extends RefCounted
## Launch day's sounds, made in code (no recordings): the yard's horn, long and low, and a bottle
## breaking on the bow.

const RATE := 22050

static var _cache: Dictionary = {}


static func stream(sound: String) -> AudioStreamWAV:
	if _cache.has(sound):
		return _cache[sound]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sound)
	var seconds := 3.2 if sound == "horn" else 0.7
	var n := int(RATE * seconds)
	var s := PackedFloat32Array()
	s.resize(n)
	match sound:
		"horn":
			for i in n:
				var t := float(i) / RATE
				var env := smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(seconds - 0.6, seconds, t))
				var f := 98.0 + sin(TAU * 0.7 * t) * 0.8
				s[i] = (sin(TAU * f * t) * 0.5 + sin(TAU * f * 2.0 * t) * 0.25 + sin(TAU * f * 3.01 * t) * 0.12
						+ sin(TAU * f * 1.5 * t) * 0.1) * env
		_:
			for i in n:
				var t := float(i) / RATE
				var crack := rng.randf_range(-1.0, 1.0) * exp(-t * 18.0)
				var tinkle := sin(TAU * (3200.0 + rng.randf_range(-400.0, 400.0)) * t) * exp(-t * 6.0) * (0.3 if rng.randf() < 0.3 else 0.0)
				var fizz := rng.randf_range(-1.0, 1.0) * 0.15 * exp(-t * 2.5)
				s[i] = crack * 0.9 + tinkle + fizz
	var peak := 0.001
	for v in s:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i] / peak * 0.8, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	_cache[sound] = w
	return w
