extends RefCounted
## The build bots' own sounds, made in code (no recordings: Void Salvage's are on Dan's licence and
## never come to BSX). Each is synthesised once into an AudioStreamWAV.
##   hover_<family>  a bot's lift fans and jets, pitched by its size (loops)
##   weld            a welding arc's crackle and buzz (loops)
##   bolt            a nut runner spinning (loops)
##   scan            an inspector's scanning warble (loops)
##   rivet           a rivet set home (one shot)
##   charge          docking on the charger: a clunk and a rising tone (one shot)

const RATE := 22050
const LOOP_SECONDS := 2.0
## Lift fan pitch by family (Hz): the big ones lower.
const HOVER_HZ := {"general": 140.0, "welder": 165.0, "riveter": 130.0, "plater": 105.0, "wirer": 190.0,
		"pipe_fitter": 140.0, "hauler": 85.0, "inspector": 230.0, "refurbisher": 140.0, "frame_tech": 120.0,
		"fitout_tech": 125.0}

static var _cache: Dictionary = {}


static func stream(sound: String) -> AudioStreamWAV:
	if _cache.has(sound):
		return _cache[sound]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sound)
	var loop := not (sound in ["rivet", "charge"])
	var n := int(RATE * (LOOP_SECONDS if loop else 0.6))
	var s := PackedFloat32Array()
	s.resize(n)
	if sound.begins_with("hover_"):
		var hz := float(HOVER_HZ.get(sound.substr(6), 140.0))
		var lp := 0.0
		for i in n:
			var t := float(i) / RATE
			lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.12)
			s[i] = sin(TAU * hz * t) * 0.18 + sin(TAU * hz * 2.0 * t) * 0.08 + lp * 0.35
	else:
		match sound:
			"weld":
				var lp := 0.0
				for i in n:
					var t := float(i) / RATE
					lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.6)
					var crackle := (rng.randf_range(-1.0, 1.0) if rng.randf() < 0.04 else 0.0)
					s[i] = lp * 0.25 + crackle * 0.9 + sin(TAU * 100.0 * t) * 0.12
			"bolt":
				for i in n:
					var t := float(i) / RATE
					var whirr := sin(TAU * (520.0 + sin(TAU * 3.0 * t) * 40.0) * t)
					s[i] = whirr * 0.25 + rng.randf_range(-1.0, 1.0) * 0.08 * (0.5 + 0.5 * sin(TAU * 18.0 * t))
			"scan":
				for i in n:
					var t := float(i) / RATE
					s[i] = sin(TAU * (900.0 + sin(TAU * 1.5 * t) * 300.0) * t) * 0.12
			"rivet":
				for i in n:
					var t := float(i) / RATE
					var env := exp(-t * 28.0)
					s[i] = (rng.randf_range(-1.0, 1.0) * 0.7 + sin(TAU * 180.0 * t) * 0.6) * env
			"charge":
				for i in n:
					var t := float(i) / RATE
					var clunk := exp(-t * 30.0) * rng.randf_range(-1.0, 1.0) * 0.8
					var tone := sin(TAU * (300.0 + t * 900.0) * t) * 0.18 * smoothstep(0.05, 0.15, t) * (1.0 - t / 0.6)
					s[i] = clunk + tone
	if loop:
		# Cross-fade the seam so the loop has no click.
		var seam := int(RATE * 0.15)
		for i in seam:
			var a := float(i) / seam
			s[i] = s[i] * a + s[n - seam + i] * (1.0 - a)
		s.resize(n - seam)
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
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = s.size()
	_cache[sound] = w
	return w
