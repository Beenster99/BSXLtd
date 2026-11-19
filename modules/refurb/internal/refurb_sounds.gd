extends RefCounted
## The refurb shop's sounds, all made here in code (never recordings): a loop per tool (the
## scanner's soft warble, the nut runner's whirr, the grit blaster's hiss, the welder's crackle,
## the test probe's hum), the pass chime, the fail buzz and the scrap clang. Built once; the
## noise comes from its own seeded generator (presentation only, never the shop's RNG).

const RATE := 22050

static var _cache: Dictionary = {}


static func stream(id: String) -> AudioStreamWAV:
	if not _cache.has(id):
		_cache[id] = _make(id)
	return _cache[id]


static func _make(id: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = id.hash()
	var secs := 1.0
	var loop := true
	match id:
		"chime":
			secs = 0.9
			loop = false
		"buzz":
			secs = 0.5
			loop = false
		"clang":
			secs = 1.2
			loop = false
	var n := int(RATE * secs)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	var lp2 := 0.0
	var crack := 0.0
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		match id:
			"scanner":
				v = 0.25 * sin(TAU * 880.0 * t + 2.0 * sin(TAU * 6.0 * t)) * (0.6 + 0.4 * sin(TAU * 2.0 * t))
				v += 0.08 * sin(TAU * 1320.0 * t)
			"nut_runner":
				var saw := fmod(t * 150.0, 1.0) * 2.0 - 1.0
				lp += (saw - lp) * 0.2
				v = lp * 0.45 * (0.7 + 0.3 * sin(TAU * 18.0 * t)) + rng.randf_range(-0.05, 0.05)
			"blaster":
				var w := rng.randf_range(-1.0, 1.0)
				lp += (w - lp) * 0.35
				lp2 += (lp - lp2) * 0.5
				v = (w - lp2) * 0.35 + lp * 0.25
			"welder":
				if rng.randf() < 0.004:
					crack = 1.0
				crack *= 0.993
				v = rng.randf_range(-1.0, 1.0) * (0.12 + 0.5 * crack) + 0.1 * sin(TAU * 100.0 * t)
			"probe":
				v = 0.22 * sin(TAU * 60.0 * t) + 0.1 * sin(TAU * 120.0 * t) + 0.06 * sin(TAU * 420.0 * t) * (0.5 + 0.5 * sin(TAU * 3.0 * t))
			"chime":
				var f := 660.0 if t < 0.3 else 990.0
				var tt := t if t < 0.3 else t - 0.3
				v = 0.4 * sin(TAU * f * t) * exp(-tt * 5.0)
			"buzz":
				v = (0.3 if fmod(t * 110.0, 1.0) < 0.5 else -0.3) * (1.0 - t / secs)
			"clang":
				v = (0.35 * sin(TAU * 230.0 * t) + 0.25 * sin(TAU * 587.0 * t) + 0.15 * sin(TAU * 1210.0 * t)) * exp(-t * 4.0)
				v += rng.randf_range(-0.3, 0.3) * exp(-t * 30.0)
		if loop:
			# Fade the loop's ends together so it doesn't click.
			var edge := minf(t, secs - t)
			v *= clampf(edge / 0.02, 0.0, 1.0) * 0.6 + 0.4 if edge < 0.02 else 1.0
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = n
	return s
