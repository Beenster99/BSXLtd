class_name YardToolSounds
extends RefCounted
## The tools' made sounds (AU2, docs/review/13_SOUND_AND_MUSIC.md 2.4): ToolAudio's synthesis,
## which ran sample by sample on your own rig only, baked once into loops and one-shots that any
## player can play. They stand in for an event's clips while its folder in assets/sounds is empty
## (SoundBank.stream falls back on them), keyed by the same bank event:
##
##   tool.grinder_free   the disc spinning free (loop)
##   tool.grinder_bite   the disc loaded into metal, gritty (loop; YardToolVoice drops its pitch)
##   tool.grinder_skate  the disc skittering on a metal too hard for it (loop)
##   tool.cutter         the gas torch roaring (loop)      tool.cutter_light  its pop as it lights
##   tool.plasma         the arc's hiss and buzz (loop)    tool.plasma_through  the cut running out
##   tool.grabber        the claw's tractor hum (loop)     tool.grabber_grip  its clamp taking hold
##   tool.battery        the jump-starter's whine (loop)
##   tool.zap            a live joint's crack at the bite  tool.stretch  the boom's clack letting go
##   tool.throw          the thunk through your suit as you throw
##   tool.socket_groan   a seized bolt's creak under the impact gun (loop)
##   tool.spray          the spray can's hiss (loop)
##   tool.riveter        the rivet gun's air hammer (loop)   tool.welder  the MIG arc's crackle (loop)
##
## Loops are `LOOP` seconds: every tone in them makes whole cycles over the loop, and the last
## tenth of a second is faded into the first (_to_loop), so they run seamlessly. Loops are
## set to `LOOP_RMS_DB` of full scale, one-shots to `SHOT_PEAK_DB` peak, so a voice's level in dB
## means the same for a made sound as for a recording (the socket's are about -20 dB RMS).

const RATE := 22050
## A made loop's length (s), before its seam is faded.
const LOOP := 2.0
## A made loop's loudness (dB RMS of full scale).
const LOOP_RMS_DB := -20.0
## A made one-shot's loudest point (dB of full scale).
const SHOT_PEAK_DB := -3.0

## Every event a made sound stands in for.
const EVENTS: Array[String] = ["tool.grinder_free", "tool.grinder_bite", "tool.grinder_skate", "tool.cutter",
		"tool.cutter_light", "tool.plasma", "tool.plasma_through", "tool.grabber", "tool.grabber_grip",
		"tool.battery", "tool.zap", "tool.stretch", "tool.throw", "tool.socket_groan", "tool.spray",
		"socket.run", "socket.rattle", "socket.stop", "tool.riveter", "tool.welder", "tool.riveter_charge", "tool.riveter_punch"]

static var _made: Dictionary = {}


## Does a made sound stand in for `event`?
static func makes(event: String) -> bool:
	return EVENTS.has(event)


## The made sound for `event` (made once), or null when there is none.
static func stream(event: String) -> AudioStreamWAV:
	if not _made.has(event):
		_made[event] = _make(event)
	return _made[event]


static func _make(event: String) -> AudioStreamWAV:
	match event:
		"tool.grinder_free":
			return _grinder(false)
		"tool.grinder_bite":
			return _grinder(true)
		"tool.grinder_skate":
			return _skate()
		"tool.cutter":
			return _torch()
		"tool.cutter_light":
			return _light()
		"tool.plasma":
			return _plasma()
		"tool.plasma_through":
			return _through()
		"tool.grabber":
			return _tractor()
		"tool.grabber_grip":
			return _grip()
		"tool.battery":
			return _battery()
		"tool.zap":
			return _zap()
		"tool.stretch":
			return _clack()
		"tool.throw":
			return _thunk()
		"tool.socket_groan":
			return _groan()
		"socket.run":
			return _impact_motor()
		"socket.rattle":
			return _impact_rattle()
		"socket.stop":
			return _impact_stop()
		"tool.spray":
			return _spray()
		"tool.riveter":
			return _riveter()
		"tool.welder":
			return _welder()
		"tool.riveter_charge":
			return _riveter_charge()
		"tool.riveter_punch":
			return _riveter_punch()
	return null


## (BSX) The rivet gun: 14 hard knocks a second (whole cycles over the loop), each a crack of
## noise with a steel ring, over the hiss of its exhaust air.
static func _riveter() -> AudioStreamWAV:
	var rng := _rng(21)
	var n := _loop_samples()
	var s := PackedFloat32Array()
	s.resize(n)
	var hz := _hz(14.0)
	var hiss := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := fmod(t * hz, 1.0) / hz
		var white := rng.randf_range(-1.0, 1.0)
		hiss = lerpf(hiss, white, 0.5)
		var knock := white * exp(-160.0 * u) * 1.6 + sin(TAU * _hz(2300.0) * t) * exp(-45.0 * u) * 0.5 \
				+ sin(TAU * _hz(180.0) * t) * exp(-30.0 * u) * 0.8
		s[i] = knock + hiss * 0.12
	return _as_loop(s)


## (BSX) The riveter charging (0.4.1): air hissing into its cylinder, a soft compressor whine
## under it (the voice raises its pitch as the pressure builds).
static func _riveter_charge() -> AudioStreamWAV:
	var rng := _rng(23)
	var n := _loop_samples()
	var s := PackedFloat32Array()
	s.resize(n)
	var a := 0.0
	var b := 0.0
	var whine := _hz(620.0)
	for i in n:
		var t := float(i) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		a = lerpf(a, white, 0.6)
		b = lerpf(b, a, 0.5)
		var hiss := a - b   # a high band of noise: air through a valve
		s[i] = hiss * 1.2 + sin(TAU * whine * t) * 0.05 + sin(TAU * whine * 2.0 * t) * 0.02
	return _as_loop(s)


## (BSX) The riveter's punch (0.4.1): one heavy blow. A deep thump through the plate, the crack
## of steel on steel, the set ringing, and the spent air blasting out after it.
static func _riveter_punch() -> AudioStreamWAV:
	var rng := _rng(24)
	var s := PackedFloat32Array()
	var air := 0.0
	var low := 0.0
	for i in int(RATE * 0.85):
		var t := float(i) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, white, 0.08)
		var thump := sin(TAU * (48.0 + 40.0 * exp(-30.0 * t)) * t) * exp(-9.0 * t) * 1.3 + low * exp(-14.0 * t) * 2.0
		var crack := white * exp(-90.0 * t) * 1.6
		var ring := (sin(TAU * 1870.0 * t) * 0.35 + sin(TAU * 3120.0 * t) * 0.22 + sin(TAU * 4410.0 * t) * 0.12) * exp(-11.0 * t)
		air = lerpf(air, white, 0.7)
		var blast := air * 0.45 * (smoothstep(0.03, 0.08, t) * exp(-6.0 * maxf(t - 0.08, 0.0)))
		s.append(thump + crack + ring + blast)
	return _as_shot(s)


## (BSX) The MIG arc: a frying crackle (pops of noise, thick and uneven) on a low 100 Hz buzz.
static func _welder() -> AudioStreamWAV:
	var rng := _rng(22)
	var n := _loop_samples()
	var s := PackedFloat32Array()
	s.resize(n)
	var pop := 0.0
	var body := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		if rng.randf() < 0.012:
			pop = rng.randf_range(0.6, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		pop *= 0.93
		body = lerpf(body, white, 0.35)
		var buzz := (1.0 if fmod(_hz(100.0) * t, 1.0) < 0.5 else -1.0) * 0.08
		s[i] = pop * white * 1.8 + body * 0.35 + buzz
	return _as_loop(s)


## A tone's frequency moved to the nearest that makes whole cycles over a loop (Hz).
static func _hz(f: float) -> float:
	return maxf(roundf(f * LOOP), 1.0) / LOOP


## The samples of a loop: `LOOP` seconds plus the tenth faded into its start.
static func _loop_samples() -> int:
	return int(RATE * LOOP) + int(RATE * 0.1)


## The grinder: a sawtooth whine at 620 Hz through the suit's muffle; biting, it grows a crunch
## of grit and a grumble of the disc dragging (`bite`).
static func _grinder(bite: bool) -> AudioStreamWAV:
	var rng := _rng(3 if bite else 2)
	var n := _loop_samples()
	var s := PackedFloat32Array()
	s.resize(n)
	var f := _hz(620.0)
	var drag := _hz(37.0)
	var noise := 0.0
	var filtered := 0.0
	var grit := 0.0
	for i in n:
		var t := float(i) / RATE
		var saw := fmod(f * t, 1.0) * 2.0 - 1.0
		noise = lerpf(noise, rng.randf_range(-1.0, 1.0), 0.5)
		var v := saw * 0.6 + sin(TAU * f * 2.0 * t) * 0.15
		if bite:
			# Bursts of grit as the disc's grain catches, over a slow drag in the motor.
			grit = lerpf(grit, 1.0 if rng.randf() < 0.002 else 0.0, 0.02)
			v = v * (0.75 + 0.25 * sin(TAU * drag * t)) + noise * (0.9 + 1.2 * grit)
		else:
			v += noise * 0.12
		filtered = lerpf(filtered, v, 0.35)
		s[i] = filtered
	return _as_loop(s)


## The grinder on a metal too hard for it: a thin whine that keeps skipping off, with ticks and
## bright scrapes where the disc catches and jumps.
static func _skate() -> AudioStreamWAV:
	var rng := _rng(4)
	var n := _loop_samples()
	var s := PackedFloat32Array()
	s.resize(n)
	var f := _hz(1240.0)
	var hp := 0.0
	var prev := 0.0
	var chatter := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		hp = 0.9 * (hp + white - prev)
		prev = white
		if rng.randf() < 0.0012:
			chatter = 1.0
		chatter *= 0.9985
		var tick := rng.randf_range(-1.0, 1.0) if rng.randf() < 0.004 else 0.0
		s[i] = hp * (0.25 + 0.9 * chatter) + sin(TAU * f * t) * 0.08 * chatter + tick * 0.6
	return _as_loop(s)


## The gas torch: a roar of low noise with a rumble under it and a crackle now and then.
static func _torch() -> AudioStreamWAV:
	var rng := _rng(5)
	var n := _loop_samples()
	var s := PackedFloat32Array()
	s.resize(n)
	var roar := 0.0
	var rumble := 0.0
	for i in n:
		var white := rng.randf_range(-1.0, 1.0)
		roar = lerpf(roar, white, 0.45)
		rumble = lerpf(rumble, white, 0.03)
		var crackle := rng.randf_range(-1.0, 1.0) if rng.randf() < 0.003 else 0.0
		s[i] = roar * 0.7 + rumble * 2.5 + crackle * 0.5
	return _as_loop(s)


## The torch lighting: a soft whump of gas catching, then its hiss rising into the roar.
static func _light() -> AudioStreamWAV:
	var rng := _rng(6)
	var s := PackedFloat32Array()
	var low := 0.0
	for i in int(RATE * 0.45):
		var t := float(i) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, white, 0.06)
		var whump := sin(TAU * (90.0 - 60.0 * t) * t) * exp(-18.0 * t)
		var hiss := white * 0.3 * minf(t * 8.0, 1.0) * exp(-4.0 * t)
		s.append(whump * 0.8 + low * 2.0 * exp(-10.0 * t) + hiss)
	return _as_shot(s)


## The plasma torch: a hard hiss with the arc's 165 Hz buzz under it and spits where it bites.
static func _plasma() -> AudioStreamWAV:
	var rng := _rng(7)
	var n := _loop_samples()
	var s := PackedFloat32Array()
	s.resize(n)
	var f := _hz(165.0)
	var noise := 0.0
	for i in n:
		var t := float(i) / RATE
		noise = lerpf(noise, rng.randf_range(-1.0, 1.0), 0.5)
		var buzz := fmod(f * t, 1.0) * 2.0 - 1.0
		var spit := rng.randf_range(-1.0, 1.0) if rng.randf() < 0.008 else 0.0
		s[i] = noise * 0.8 + buzz * 0.25 + spit * 0.9
	return _as_loop(s)


## The cut running out of the far side: a burst of hiss falling away, crackling.
static func _through() -> AudioStreamWAV:
	var rng := _rng(8)
	var s := PackedFloat32Array()
	var hp := 0.0
	var prev := 0.0
	for i in int(RATE * 0.8):
		var t := float(i) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		hp = 0.9 * (hp + white - prev)
		prev = white
		var crackle := rng.randf_range(-1.0, 1.0) if rng.randf() < 0.01 * exp(-4.0 * t) else 0.0
		s.append(hp * exp(-5.0 * t) * minf(t * 60.0, 1.0) + crackle * 0.7)
	return _as_shot(s)


## The claw holding: a low magnetic hum (88 Hz and its third) with a slow throb.
static func _tractor() -> AudioStreamWAV:
	var n := _loop_samples()
	var s := PackedFloat32Array()
	s.resize(n)
	var f := _hz(88.0)
	var throb := _hz(1.5)
	for i in n:
		var t := float(i) / RATE
		s[i] = (sin(TAU * f * t) + 0.35 * sin(TAU * f * 3.0 * t) + 0.1 * sin(TAU * f * 5.0 * t)) \
				* (0.8 + 0.2 * sin(TAU * throb * t))
	return _as_loop(s)


## The claw taking hold: a clamp's knock with a short metal click on it.
static func _grip() -> AudioStreamWAV:
	var rng := _rng(9)
	var s := PackedFloat32Array()
	for i in int(RATE * 0.35):
		var t := float(i) / RATE
		var knock := sin(TAU * 95.0 * t) * exp(-16.0 * t)
		var click := rng.randf_range(-1.0, 1.0) * exp(-260.0 * t)
		var ring := sin(TAU * 740.0 * t) * exp(-30.0 * t) * 0.2
		s.append(knock + click * 0.8 + ring)
	return _as_shot(s)


## The jump-starter feeding: a charging whine (1,320 and 660 Hz) with a mains buzz under it and
## a little wobble.
static func _battery() -> AudioStreamWAV:
	var n := _loop_samples()
	var s := PackedFloat32Array()
	s.resize(n)
	var hi := _hz(1320.0)
	var mid := _hz(660.0)
	var mains := _hz(120.0)
	var wobble := _hz(3.0)
	for i in n:
		var t := float(i) / RATE
		var w := 0.85 + 0.15 * sin(TAU * wobble * t)
		s[i] = (sin(TAU * hi * t) * 0.35 + sin(TAU * mid * t) * 0.3) * w \
				+ signf(sin(TAU * mains * t)) * 0.08 + sin(TAU * mains * t) * 0.15
	return _as_loop(s)


## The spray can: a bright hiss of gas through the nozzle, the noise high-passed, breathing a
## little as the valve flutters.
static func _spray() -> AudioStreamWAV:
	var rng := _rng(14)
	var n := _loop_samples()
	var s := PackedFloat32Array()
	s.resize(n)
	var flutter := _hz(7.0)
	var hp := 0.0
	var prev := 0.0
	var soft := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		hp = 0.85 * (hp + white - prev)
		prev = white
		soft = lerpf(soft, hp, 0.6)
		s[i] = soft * (0.88 + 0.12 * sin(TAU * flutter * t))
	return _as_loop(s)


## Live wiring at the bite: a square 120 Hz buzz under a burst of electric crack.
static func _zap() -> AudioStreamWAV:
	var rng := _rng(10)
	var s := PackedFloat32Array()
	for i in int(RATE * 0.35):
		var t := float(i) / RATE
		var buzz := 1.0 if fmod(120.0 * t, 1.0) < 0.5 else -1.0
		var crack := rng.randf_range(-1.0, 1.0) * (1.0 if rng.randf() < 0.3 else 0.2)
		s.append((buzz * 0.3 + crack * 0.7) * exp(-9.0 * t))
	return _as_shot(s)


## The boom letting go at full stretch: two quick hard clacks as it snaps back into the tool.
static func _clack() -> AudioStreamWAV:
	var rng := _rng(11)
	var s := PackedFloat32Array()
	for i in int(RATE * 0.22):
		var t := float(i) / RATE
		var v := 0.0
		for start: float in [0.0, 0.055]:
			if t >= start:
				var u := t - start
				v += (rng.randf_range(-1.0, 1.0) * exp(-180.0 * u) + sin(TAU * 1150.0 * u) * exp(-60.0 * u) * 0.5) \
						* (1.0 if start == 0.0 else 0.6)
		s.append(v)
	return _as_shot(s)


## A throw through your suit: a deep knock (62 Hz) with a little noise.
static func _thunk() -> AudioStreamWAV:
	var rng := _rng(12)
	var s := PackedFloat32Array()
	var noise := 0.0
	for i in int(RATE * 0.4):
		var t := float(i) / RATE
		noise = lerpf(noise, rng.randf_range(-1.0, 1.0), 0.5)
		s.append((sin(TAU * 62.0 * t) * 0.7 + noise * 0.25) * exp(-11.0 * t))
	return _as_shot(s)


## A seized bolt under the impact gun: the low, groaning creak of rusted metal under load, a
## triangle wave wandering round 48 Hz, roughened.
static func _groan() -> AudioStreamWAV:
	var rng := _rng(13)
	var n := _loop_samples()
	var s := PackedFloat32Array()
	s.resize(n)
	var f := _hz(48.0)
	var sway := _hz(0.5)
	var phase := 0.0
	var noise := 0.0
	for i in n:
		var t := float(i) / RATE
		# The sway's sine averages out over the loop, so the phase still closes on whole cycles.
		phase += (f + 9.0 * sin(TAU * sway * t)) / RATE
		noise = lerpf(noise, rng.randf_range(-1.0, 1.0), 0.3)
		var tri := absf(fmod(phase, 1.0) * 2.0 - 1.0) * 2.0 - 1.0
		s[i] = tri * (0.7 + noise * 0.3)
	return _as_loop(s)


static func _rng(which: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = which
	return rng


## A loop at `LOOP_RMS_DB`, its seam faded.
static func _as_loop(s: PackedFloat32Array) -> AudioStreamWAV:
	var sum := 0.0
	for v in s:
		sum += v * v
	var rms := sqrt(sum / maxf(s.size(), 1.0))
	var gain := db_to_linear(LOOP_RMS_DB) / maxf(rms, 1e-6)
	for i in s.size():
		s[i] *= gain
	return _to_loop(s)


## A one-shot with its loudest point at `SHOT_PEAK_DB`.
static func _as_shot(s: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.0
	for v in s:
		peak = maxf(peak, absf(v))
	var gain := db_to_linear(SHOT_PEAK_DB) / maxf(peak, 1e-6)
	for i in s.size():
		s[i] *= gain
	return _to_wav(s)


## Void Salvage's ShipAudio._to_loop: the last tenth of a second faded into the first.
static func _to_loop(s: PackedFloat32Array) -> AudioStreamWAV:
	var fade := int(RATE * 0.1)
	var n := s.size() - fade
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = s[i]
	for i in fade:
		var w := float(i) / float(fade)
		out[i] = s[i] * w + s[n + i] * (1.0 - w)
	var wav := _to_wav(out)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav


static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


## (BSX) The impact gun's air motor running free, made in place of Void Salvage's recordings:
## a buzzy whine with a hiss of exhaust air.
static func _impact_motor() -> AudioStreamWAV:
	var rng := _rng(21)
	var n := _loop_samples()
	var s := PackedFloat32Array()
	s.resize(n)
	var f := _hz(310.0)
	var hiss := 0.0
	for i in n:
		var t := float(i) / RATE
		hiss = lerpf(hiss, rng.randf_range(-1.0, 1.0), 0.6)
		var saw := fmod(f * t, 1.0) * 2.0 - 1.0
		s[i] = saw * 0.35 + sin(TAU * f * 3.0 * t) * 0.12 + hiss * 0.3
	return _as_loop(s)


## (BSX) The hammer inside the gun: sharp knocks at about 18 a second.
static func _impact_rattle() -> AudioStreamWAV:
	var rng := _rng(22)
	var n := _loop_samples()
	var s := PackedFloat32Array()
	s.resize(n)
	var hz := _hz(18.0)
	for i in n:
		var t := float(i) / RATE
		var since := fmod(t * hz, 1.0) / hz
		var knock := exp(-since * 160.0)
		s[i] = (rng.randf_range(-1.0, 1.0) * 0.7 + sin(TAU * 1900.0 * since) * 0.5) * knock
	return _as_loop(s)


## (BSX) The motor winding down as the trigger is let go.
static func _impact_stop() -> AudioStreamWAV:
	var rng := _rng(23)
	var n := int(RATE * 0.45)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var u := float(i) / float(n)
		phase += 310.0 * (1.0 - 0.7 * u) / RATE
		var saw := fmod(phase, 1.0) * 2.0 - 1.0
		s[i] = (saw * 0.35 + rng.randf_range(-1.0, 1.0) * 0.2) * (1.0 - u)
	return _as_shot(s)
