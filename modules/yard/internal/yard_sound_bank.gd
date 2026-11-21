class_name YardSoundBank
extends RefCounted
## The orbital yard's own made sounds (first sound pass, 19 Nov: "please add some sounds to the
## game - we can improve over time"). Everything here is synthesised in code, once, into an
## AudioStreamWAV, like Sfx and YardToolSounds: no sound files, so nothing recorded comes in
## (Void Salvage's recordings are on Dan's licence and never come to BSX). Licence: our own code,
## the project's. YardSounds plays them; tools keep their own (YardToolVoice), and the UI and
## footsteps theirs (Sfx).
##
##   Loops (whole cycles, the seam cross-faded, so they run without a click):
##   station_hum   life support inside the station: mains hum and air through the ducts
##   dock_hum      the dock heard through your suit: a low rumble of the station's frame
##   jet           your jet-rig's thrusters, a hiss
##   bot_hover     a stores or mover bot's lift fans
##   worker_jets   a heavy worker android's manoeuvring jets
##   ship_engine   a delivery or service ship's engines, a deep rumble
##   airlock_pump  the airlock pumping, a hiss with the pump's throb
##   weld_arc      a worker's welding arc, crackle and buzz
##   One-shots:
##   door_motor    a heavy door sliding (motor whir, ends in a clunk)
##   door_seal     a door sealing shut: a thunk and a short hiss
##   lock_beep     the airlock's two-tone beep as it starts a cycle
##   creak         the station's frame groaning as it warms and cools
##   vent_puff     a vent breathing out
##   rivet_punch   a worker's rivet gun firing
##   bolt_run      a worker's nut runner spinning a bolt home

const RATE := 22050
## What each sound is for (tests and the sound list read it).
const SOUNDS := {
	"station_hum": "life support inside the station (loops)",
	"dock_hum": "the dock heard through your suit (loops)",
	"jet": "your jet-rig's thrusters (loops)",
	"bot_hover": "a stores or mover bot's lift fans (loops)",
	"worker_jets": "a worker android's manoeuvring jets (loops)",
	"ship_engine": "a delivery or service ship's engines (loops)",
	"airlock_pump": "the airlock pumping (loops)",
	"weld_arc": "a worker's welding arc (loops)",
	"door_motor": "a heavy door sliding",
	"door_seal": "a door sealing shut",
	"lock_beep": "the airlock starting a cycle",
	"creak": "the station's frame groaning",
	"vent_puff": "a vent breathing out",
	"rivet_punch": "a worker's rivet gun firing",
	"bolt_run": "a worker's nut runner spinning a bolt home",
	"warp_jump": "a delivery ship spooling up and jumping out to warp",
}
const LOOPS := ["station_hum", "dock_hum", "jet", "bot_hover", "worker_jets", "ship_engine", "airlock_pump", "weld_arc"]
## A loop's length (s) and the cross-fade over its seam (s).
const LOOP_SECONDS := 3.0
const SEAM := 0.25

static var _cache: Dictionary = {}


static func names() -> PackedStringArray:
	return PackedStringArray(SOUNDS.keys())


static func stream(sound: String) -> AudioStreamWAV:
	if _cache.has(sound):
		return _cache[sound]
	if not SOUNDS.has(sound):
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("yard." + sound)
	var samples: PackedFloat32Array
	if sound in LOOPS:
		samples = _to_loop(_make(sound, rng, LOOP_SECONDS + SEAM))
	else:
		samples = _make(sound, rng, 0.0)
	_normalise(samples, 0.7)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	wav.data = bytes
	if sound in LOOPS:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	_cache[sound] = wav
	return wav


# --- The sounds ----------------------------------------------------------------------------

static func _make(sound: String, rng: RandomNumberGenerator, length: float) -> PackedFloat32Array:
	match sound:
		"station_hum":
			var hum := _tones(length, [50.0, 100.0, 150.0, 200.0], [0.5, 0.35, 0.12, 0.06])
			var air := _band(rng, length, 120.0, 600.0, 0.35)
			_tremolo(air, 0.17, 0.3)
			return _sum([hum, air])
		"dock_hum":
			var rumble := _band(rng, length, 20.0, 140.0, 0.9)
			_tremolo(rumble, 0.31, 0.25)
			return _sum([rumble, _tones(length, [38.0, 76.0], [0.25, 0.08])])
		"jet":
			var hiss := _band(rng, length, 500.0, 4500.0, 0.8)
			_tremolo(hiss, 13.0, 0.08)
			return _sum([hiss, _band(rng, length, 60.0, 300.0, 0.35)])
		"bot_hover":
			var fan := _tones(length, [118.0, 236.0, 354.0, 472.0], [0.4, 0.25, 0.14, 0.08])
			_tremolo(fan, 7.0, 0.25)
			return _sum([fan, _band(rng, length, 600.0, 2500.0, 0.25)])
		"worker_jets":
			var jets := _band(rng, length, 250.0, 2200.0, 0.7)
			_tremolo(jets, 4.0, 0.2)
			return _sum([jets, _tones(length, [86.0, 172.0], [0.25, 0.1])])
		"ship_engine":
			var deep := _band(rng, length, 25.0, 220.0, 1.0)
			_tremolo(deep, 2.33, 0.2)
			var roar := _band(rng, length, 300.0, 1400.0, 0.2)
			return _sum([deep, roar, _tones(length, [41.0, 82.0, 123.0], [0.4, 0.2, 0.08])])
		"airlock_pump":
			var air := _band(rng, length, 400.0, 3500.0, 0.6)
			_tremolo(air, 6.0, 0.35)
			var pump := _tones(length, [60.0, 120.0], [0.4, 0.2])
			_tremolo(pump, 6.0, 0.6)
			return _sum([air, pump])
		"weld_arc":
			var n := int(length * RATE)
			var out := _tones(length, [100.0, 200.0, 300.0], [0.12, 0.08, 0.04])
			var k := 0
			while k < n:
				var burst := _hit(rng, rng.randf_range(0.004, 0.02), 6000.0, rng.randf_range(0.25, 0.9))
				_add(out, burst, k)
				k += int(rng.randf_range(0.004, 0.035) * RATE)
			return _sum([out, _band(rng, length, 1500.0, 6000.0, 0.25)])
		"door_motor":
			var whir := _sweep(0.85, 180.0, 260.0, [1.0, 0.5, 0.25], 0.35)
			var clunk := _sum([_tone(0.35, 70.0, 12.0, 0.9), _tone(0.35, 410.0, 18.0, 0.25),
					_hit(rng, 0.06, 1800.0, 0.6)])
			return _sum([whir, _delay(clunk, 0.8)])
		"door_seal":
			var thunk := _sum([_tone(0.5, 58.0, 9.0, 1.0), _tone(0.5, 290.0, 14.0, 0.2), _hit(rng, 0.05, 1200.0, 0.6)])
			var hiss := _band(rng, 0.45, 1500.0, 6000.0, 0.35)
			_fade(hiss, 0.02, 0.4)
			return _sum([thunk, _delay(hiss, 0.05)])
		"lock_beep":
			return _sum([_beep(0.13, 880.0, 0.4), _delay(_beep(0.13, 660.0, 0.4), 0.17)])
		"creak":
			return _creak(rng)
		"vent_puff":
			var puff := _band(rng, 1.2, 200.0, 2000.0, 0.8)
			_fade(puff, 0.35, 0.8)
			return puff
		"rivet_punch":
			return _sum([_hit(rng, 0.05, 5000.0, 0.8), _tone(0.3, 880.0, 16.0, 0.4), _tone(0.3, 1960.0, 24.0, 0.18),
					_tone(0.25, 110.0, 20.0, 0.6)])
		"warp_jump":
			# The spool: a whine climbing over 1.4 s on a rising rush, then the jump: a deep
			# thump, a crack and a whoosh that falls away (beenster, 21 Nov).
			var whine := _sweep(1.5, 140.0, 1100.0, [1.0, 0.45, 0.2, 0.1], 0.3)
			var rush := _band(rng, 1.5, 300.0, 3000.0, 0.5)
			_fade(rush, 1.3, 0.05)
			var thump := _sum([_tone(1.6, 42.0, 2.2, 1.0), _tone(1.2, 84.0, 3.5, 0.45), _hit(rng, 0.08, 7000.0, 0.9)])
			var fall := _sweep(1.4, 900.0, 60.0, [1.0, 0.5, 0.25], 0.35)
			var whoosh := _band(rng, 1.8, 150.0, 5000.0, 0.8)
			_fade(whoosh, 0.01, 1.7)
			return _sum([whine, rush, _delay(_sum([thump, fall, whoosh]), 1.4)])
		"bolt_run":
			var spin := _sweep(0.9, 300.0, 180.0, [1.0, 0.6, 0.3, 0.2], 0.25)
			var out := spin
			for i in 12:
				_add(out, _hit(rng, 0.012, 4000.0, 0.35), int((0.05 + i * 0.07) * RATE))
			_add(out, _tone(0.25, 520.0, 20.0, 0.4), int(0.88 * RATE))
			return out
	return PackedFloat32Array()


## Metal groaning: a low note that drifts and catches, with ringing overtones.
static func _creak(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var length := 1.6
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var base := rng.randf_range(70.0, 110.0)
	var drift := rng.randf_range(-25.0, 25.0)
	var jitter := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := t / length
		jitter += (rng.randf_range(-1.0, 1.0) - jitter) * 0.002
		phase += TAU * (base + drift * u + jitter * 40.0) / RATE
		# Stick and slip: the note catches in pulses.
		var catch := 0.5 + 0.5 * sin(TAU * 11.0 * t + sin(TAU * 3.0 * t) * 2.0)
		var env := sin(u * PI) * (0.4 + 0.6 * catch)
		out[i] = (sin(phase) * 0.6 + sin(phase * 2.7) * 0.25 + sin(phase * 4.1) * 0.12) * env
	return out


# --- Building blocks ----------------------------------------------------------------------

## Steady tones at `freqs` (Hz, each rounded to whole cycles over the loop) with `amps`.
static func _tones(length: float, freqs: Array, amps: Array) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for j in freqs.size():
		var f := roundf(float(freqs[j]) * LOOP_SECONDS) / LOOP_SECONDS
		var a := float(amps[j])
		for i in n:
			out[i] += sin(TAU * f * float(i) / RATE) * a
	return out


## A sine at `freq`, decaying at `decay` per second.
static func _tone(length: float, freq: float, decay: float, amp: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = sin(TAU * freq * t) * amp * minf(1.0, t * 600.0) * exp(-decay * t)
	return out


## A beep with soft edges.
static func _beep(length: float, freq: float, amp: float) -> PackedFloat32Array:
	var out := _tones(length, [freq, freq * 2.0], [amp, amp * 0.2])
	_fade(out, 0.01, 0.03)
	return out


## A note gliding from `from` to `to` Hz with harmonics `amps`, swelling in and out.
static func _sweep(length: float, from: float, to: float, amps: Array, amp: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var u := float(i) / n
		phase += TAU * lerpf(from, to, u) / RATE
		var v := 0.0
		for h in amps.size():
			v += sin(phase * (h + 1)) * float(amps[h])
		out[i] = v * amp * minf(1.0, u * 12.0) * minf(1.0, (1.0 - u) * 8.0)
	return out


## Noise between `low` and `high` Hz (two one-pole filters), steady.
static func _band(rng: RandomNumberGenerator, length: float, low: float, high: float, amp: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var kh := clampf(TAU * high / RATE, 0.0, 1.0)
	var kl := clampf(TAU * low / RATE, 0.0, 1.0)
	var y := 0.0
	var floor_ := 0.0
	for i in n:
		y += kh * (rng.randf_range(-1.0, 1.0) - y)
		floor_ += kl * (y - floor_)
		out[i] = (y - floor_) * amp * 3.0
	return out


## A short click of filtered noise that dies away fast.
static func _hit(rng: RandomNumberGenerator, length: float, cutoff: float, amp: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var k := clampf(TAU * cutoff / RATE, 0.0, 1.0)
	var y := 0.0
	for i in n:
		y += k * (rng.randf_range(-1.0, 1.0) - y)
		out[i] = y * amp * 2.5 * (1.0 - float(i) / n)
	return out


## Swells `samples` up and down at `hz` (rounded to whole cycles over the loop) by `depth`.
static func _tremolo(samples: PackedFloat32Array, hz: float, depth: float) -> void:
	var f := maxf(1.0, roundf(hz * LOOP_SECONDS)) / LOOP_SECONDS
	for i in samples.size():
		samples[i] *= 1.0 - depth * (0.5 + 0.5 * sin(TAU * f * float(i) / RATE))


static func _fade(samples: PackedFloat32Array, fade_in: float, fade_out: float) -> void:
	var n := samples.size()
	var a := maxi(1, int(fade_in * RATE))
	var b := maxi(1, int(fade_out * RATE))
	for i in n:
		samples[i] *= minf(1.0, float(i) / a) * minf(1.0, float(n - i) / b)


## Cuts LOOP_SECONDS off a run that is SEAM longer, cross-fading the extra into the start.
static func _to_loop(samples: PackedFloat32Array) -> PackedFloat32Array:
	var n := int(LOOP_SECONDS * RATE)
	var seam := int(SEAM * RATE)
	var out := samples.slice(0, n)
	for i in seam:
		if n + i >= samples.size():
			break
		var w := float(i) / seam
		out[i] = out[i] * w + samples[n + i] * (1.0 - w)
	return out


static func _normalise(samples: PackedFloat32Array, peak: float) -> void:
	var top := 0.0
	for v in samples:
		top = maxf(top, absf(v))
	if top <= 0.0001:
		return
	var k := peak / top
	for i in samples.size():
		samples[i] *= k


static func _delay(src: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE) + src.size())
	_add(out, src, int(seconds * RATE))
	return out


static func _sum(parts: Array) -> PackedFloat32Array:
	var n := 0
	for p: PackedFloat32Array in parts:
		n = maxi(n, p.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for p: PackedFloat32Array in parts:
		_add(out, p, 0)
	return out


static func _add(into: PackedFloat32Array, src: PackedFloat32Array, at: int) -> void:
	for i in src.size():
		if at + i >= into.size():
			return
		into[at + i] += src[i]
