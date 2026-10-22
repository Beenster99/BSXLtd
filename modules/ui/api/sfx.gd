class_name Sfx
extends RefCounted
## The game's sound effects, made in code like Void Salvage's suit audio (no sound files):
## each name is synthesised once into an AudioStreamWAV and cached. Any module plays them:
##   Sfx.play("clunk", crate)               # 3D, follows a Node3D
##   Sfx.play("ratchet", Vector3(4, 1, 2))  # 3D, at a point in the current scene
##   Sfx.play("click")                      # flat, for screens
##   Sfx.press(button)                      # "tick" on the wrist screen, else "click"
##   var hum := Sfx.loop("beam", beam_node) # a looping 3D player; free it to stop
## Footsteps come from a Footsteps node on the walker. BsxTheme's buttons click on their own.

const RATE := 22050
## name -> what it is for (the Key binds screen and tests list them).
const SOUNDS := {
	"step_concrete": "a footstep on concrete or rock",
	"step_metal": "a footstep on a steel deck or ramp",
	"step_grating": "a footstep on open grating",
	"land": "landing after a jump or a drop",
	"click": "a button press",
	"hover": "the pointer over a button",
	"tick": "anything pressed or typed on the wrist screen",
	"holo_open": "the wrist screen opening",
	"holo_close": "the wrist screen closing",
	"holo_switch": "the wrist screen changing channel",
	"clunk": "a part or crate set down on metal",
	"thud": "something heavy dropped on the ground",
	"ratchet": "a bolt run in or out",
	"rivet": "a rivet set",
	"spark": "a weld or cut crackling",
	"beam": "the tractor beam's hum (loops)",
	"servo": "a lift or trolley motor (loops)",
	"hover_drive": "a hover trolley or truck (loops)",
	"chime": "a delivery in or a job done",
	"error": "something refused",
	"whoosh": "a door or a truck going past",
}
const LOOPS := ["beam", "servo", "hover_drive"]

static var _cache: Dictionary = {}


static func names() -> PackedStringArray:
	return PackedStringArray(SOUNDS.keys())


static func stream(sound: String) -> AudioStreamWAV:
	if _cache.has(sound):
		return _cache[sound]
	assert(SOUNDS.has(sound), "Sfx: no sound '%s'" % sound)
	var samples := _make(sound)
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


## The audio bus game sounds go to (Settings > Sound > Effects), made by the UI bus; Master
## until it exists. Other modules' players can use it too: player.bus = Sfx.bus()
const BUS := &"Effects"


static func bus() -> StringName:
	return BUS if AudioServer.get_bus_index(BUS) >= 0 else &"Master"


## Plays a sound once. `at`: a Node3D to follow, a Vector3 in the current scene, or null
## for a flat (2D) sound. Returns the player (it frees itself when done).
static func play(sound: String, at: Variant = null, volume_db: float = 0.0, pitch: float = 1.0) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or not SOUNDS.has(sound):
		return null
	var player: Node
	if at is Node3D or at is Vector3:
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = stream(sound)
		p3.volume_db = volume_db
		p3.pitch_scale = pitch
		p3.unit_size = 6.0
		p3.max_distance = 60.0
		p3.bus = bus()
		player = p3
		if at is Node3D and (at as Node3D).is_inside_tree():
			(at as Node3D).add_child(p3)
		else:
			var host: Node = tree.current_scene if tree.current_scene else tree.root
			host.add_child(p3)
			if at is Vector3:
				p3.global_position = at
	else:
		var p2 := AudioStreamPlayer.new()
		p2.stream = stream(sound)
		p2.volume_db = volume_db
		p2.pitch_scale = pitch
		p2.bus = bus()
		player = p2
		tree.root.add_child(p2)
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.set_meta("sound", sound)
	player.connect("finished", player.queue_free)
	player.call("play")
	return player


## The sound of pressing `control`: a holo tick on the wrist screen (anything under a node
## with meta "holo"), else a click.
static func press(control: Node, volume_db: float = -10.0) -> Node:
	var n := control
	while n != null:
		if n.has_meta("holo"):
			return play("tick", null, volume_db - 4.0, randf_range(0.97, 1.04))
		n = n.get_parent()
	return play("click", null, volume_db)


## A looping sound on `parent`, playing. Stop it by freeing the returned player.
static func loop(sound: String, parent: Node3D, volume_db: float = -6.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(sound)
	p.volume_db = volume_db
	p.unit_size = 6.0
	p.max_distance = 60.0
	p.bus = bus()
	p.autoplay = true
	parent.add_child(p)
	return p


# --- Synthesis -----------------------------------------------------------------------------

static func _make(sound: String) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sound)
	match sound:
		"step_concrete":
			return _step(rng, 0.09, 900.0, 0.0, 0.0)
		"step_metal":
			return _step(rng, 0.2, 2200.0, 820.0, 1530.0)
		"step_grating":
			return _step(rng, 0.16, 3200.0, 1240.0, 2610.0)
		"land":
			return _mix([_tone(0.28, 70.0, 0.0, 14.0, 0.9), _noise(rng, 0.12, 700.0, 30.0, 0.5)])
		"click":
			return _tone(0.025, 1700.0, 0.0, 180.0, 0.45)
		"tick":
			return _mix([_tone(0.018, 3400.0, 0.0, 260.0, 0.32), _tone(0.03, 1900.0, 0.0, 160.0, 0.16),
					_noise(rng, 0.006, 8000.0, 500.0, 0.18)])
		"hover":
			return _tone(0.012, 2600.0, 0.0, 300.0, 0.12)
		"holo_open":
			return _mix([_sweep(0.28, 420.0, 1500.0, 0.35), _sweep(0.28, 840.0, 3000.0, 0.12)])
		"holo_close":
			return _mix([_sweep(0.22, 1400.0, 380.0, 0.35), _sweep(0.22, 2800.0, 760.0, 0.1)])
		"holo_switch":
			return _mix([_tone(0.06, 1180.0, 0.0, 60.0, 0.3), _delay(_tone(0.08, 1570.0, 0.0, 45.0, 0.3), 0.05)])
		"clunk":
			return _mix([_tone(0.32, 120.0, 0.0, 16.0, 0.8), _tone(0.32, 710.0, 0.0, 11.0, 0.35),
					_tone(0.32, 1130.0, 0.0, 15.0, 0.2), _noise(rng, 0.05, 2500.0, 60.0, 0.4)])
		"thud":
			return _mix([_tone(0.35, 55.0, 0.0, 10.0, 1.0), _noise(rng, 0.2, 400.0, 18.0, 0.6)])
		"ratchet":
			var out := PackedFloat32Array()
			out.resize(int(0.45 * RATE))
			for i in 9:
				var tick := _mix([_noise(rng, 0.03, 4000.0, 140.0, 0.5), _tone(0.03, 2300.0, 0.0, 150.0, 0.3)])
				_add(out, tick, int(i * 0.048 * RATE))
			return out
		"rivet":
			return _mix([_noise(rng, 0.08, 5000.0, 50.0, 0.7), _tone(0.25, 940.0, 0.0, 14.0, 0.45),
					_tone(0.25, 2010.0, 0.0, 20.0, 0.2)])
		"spark":
			var out := PackedFloat32Array()
			out.resize(int(0.5 * RATE))
			for i in 24:
				_add(out, _noise(rng, 0.015, 7000.0, 200.0, rng.randf_range(0.2, 0.7)),
						int(rng.randf() * 0.48 * RATE))
			return out
		"beam":
			return _hum(rng, 1.0, [110.0, 220.0, 331.0], 0.07, 4.0)
		"servo":
			return _hum(rng, 1.0, [180.0, 360.0, 541.0], 0.03, 6.0)
		"hover_drive":
			return _hum(rng, 1.0, [62.0, 124.0, 250.0], 0.12, 2.0)
		"chime":
			return _mix([_tone(0.6, 880.0, 0.0, 5.0, 0.35), _delay(_tone(0.7, 1320.0, 0.0, 5.0, 0.3), 0.14)])
		"error":
			var buzz := _tone(0.22, 150.0, 0.0, 6.0, 0.5)
			for i in buzz.size():
				buzz[i] = signf(buzz[i]) * absf(buzz[i]) * 0.8
			return buzz
		"whoosh":
			var w := _noise(rng, 0.6, 1200.0, 0.0, 0.6)
			for i in w.size():
				var t := float(i) / w.size()
				w[i] *= sin(t * PI)
			return w
	return PackedFloat32Array()


## A footstep: a scuff of filtered noise and, on metal, two short rings.
static func _step(rng: RandomNumberGenerator, length: float, cutoff: float, ring_a: float, ring_b: float) -> PackedFloat32Array:
	var parts: Array[PackedFloat32Array] = [_noise(rng, length, cutoff, 45.0, 0.7),
			_tone(length, 90.0, 0.0, 40.0, 0.5)]
	if ring_a > 0.0:
		parts.append(_tone(length, ring_a, 0.0, 22.0, 0.22))
		parts.append(_tone(length, ring_b, 0.0, 30.0, 0.12))
	return _mix(parts)


## A sine at `freq` (plus `rise` Hz per second), decaying at `decay` per second.
static func _tone(length: float, freq: float, rise: float, decay: float, amp: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * (freq + rise * t) / RATE
		var attack := minf(1.0, t * 800.0)
		out[i] = sin(phase) * amp * attack * exp(-decay * t)
	return out


static func _sweep(length: float, from: float, to: float, amp: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += TAU * lerpf(from, to, t * t * (3.0 - 2.0 * t)) / RATE
		out[i] = sin(phase) * amp * sin(t * PI) * (1.0 + 0.3 * sin(t * 90.0))
	return out


## White noise through a one-pole low-pass at `cutoff`, decaying at `decay` per second.
static func _noise(rng: RandomNumberGenerator, length: float, cutoff: float, decay: float, amp: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var k := clampf(TAU * cutoff / RATE, 0.0, 1.0)
	var y := 0.0
	for i in n:
		y += k * (rng.randf_range(-1.0, 1.0) - y)
		var t := float(i) / RATE
		out[i] = y * amp * 2.0 * exp(-decay * t) * minf(1.0, t * 1000.0)
	return out


## A steady loop: harmonics with a slow wobble and a breath of noise. Whole cycles only, so
## it loops without a click.
static func _hum(rng: RandomNumberGenerator, length: float, freqs: Array, noise_amp: float, wobble: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for j in freqs.size():
			var f := roundf(float(freqs[j]) * length) / length
			v += sin(TAU * f * t) * (0.35 / (j + 1))
		v *= 0.8 + 0.2 * sin(TAU * roundf(wobble * length) / length * t)
		y += 0.1 * (rng.randf_range(-1.0, 1.0) - y)
		out[i] = v + y * noise_amp * 3.0
	# Fade the noise seam: match the loop's ends.
	for i in 200:
		var w := float(i) / 200.0
		out[n - 200 + i] = lerpf(out[n - 200 + i], out[i], w * 0.5)
	return out


static func _delay(src: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE) + src.size())
	_add(out, src, int(seconds * RATE))
	return out


static func _mix(parts: Array) -> PackedFloat32Array:
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
