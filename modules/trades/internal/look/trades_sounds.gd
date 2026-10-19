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


static func _wav(data: PackedByteArray, rate: int, looped: bool) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = data.size() / 2
	return wav
