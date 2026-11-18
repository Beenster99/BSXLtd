class_name YardSocketSound
extends AudioStreamPlayer3D
## The socket's impact gun as everyone hears it: a made air motor (YardToolSounds; Void
## Salvage's own is sampled and stays there) that spins up, runs
## and winds down, with the hammer's rattle over it while the socket bites a joint. It sits
## on the socket's head, so you hear other players' sockets where they are working, and
## goes through the "Tools" bus (AudioMix: a low-pass inside World, heard through the suit).
##
## No two bolts sound the same: each pull of the trigger picks one of three motors and one
## of its spin-ups (never the last one again), a pitch and a level, and the rattle starts at
## a random point in its loop at its own pitch. Biting loads the motor (its pitch dips); a
## seized bolt bogs it down (motor and hammer both slow, the rattle gets louder) and the rusted
## metal groans under the load (the bank's tool.socket_groan, AU2; ToolSounds' made creak until
## a recording fills its folder), for everyone.
##
## Clips are in assets/sounds/socket: run_<motor><n> is a spin-up followed by the motor's
## loop (the loop points are in the file), stop_<motor><n> a wind-down, rattle the hammer's
## loop. Presentation only: ToolController feeds it on every machine from the rig's tool
## state (`feed`), nothing is sent.

## The bus every tool emitter plays through: a low-pass, the suit (AudioMix.TOOLS, in World).
const MUFFLE_BUS := &"Master"
## Each motor's spin-ups (with its loop) and wind-downs.
const MOTORS := {
	"a": {"runs": ["run_a1", "run_a2"], "stops": ["stop_a1", "stop_a2"]},
	"b": {"runs": ["run_b1"], "stops": ["stop_b1"]},
	"c": {"runs": ["run_c1", "run_c2"], "stops": ["stop_c1", "stop_c2"]},
}

## The motor's level, in dB.
@export var motor_db: float = -2.0
## The rattle's level over the motor while biting, in dB.
@export var rattle_db: float = 1.0
## The rattle's level on a seized bolt, in dB.
@export var strain_rattle_db: float = 4.0
## The seized bolt's groan under the motor, in dB.
@export var groan_db: float = -4.0
## How far each pull's pitch may land from the clip's own, as a share (0.08 = +/- 8%).
@export var pitch_spread: float = 0.08
## How far the rattle's pitch may land from the motor's, as a share.
@export var rattle_spread: float = 0.05
## How far each pull's level may land from the set level, in dB (+/-).
@export var level_spread_db: float = 1.5
## The motor's pitch while it bites, as a share of its free-running pitch (it loads up).
@export var bite_pitch: float = 0.95
## Motor and hammer pitch on a seized bolt, as a share: lower and slower blows.
@export var strain_pitch: float = 0.82
## Seconds for the rattle to come in or go when the socket gets on or off a joint.
@export var bite_fade: float = 0.12
## Seconds for the motor to bog down on a seized bolt (and pick up again).
@export var strain_time: float = 0.3
## Seconds the running motor fades under its wind-down when the trigger is let go.
@export var stop_fade: float = 0.06
## The suit's low-pass on tool sounds, in Hz (20000 = none). Shared by the bus.
@export var muffle_hz: float = 1800.0:
	set(value):
		muffle_hz = value
		if is_inside_tree():
			muffle_bus(value)

## Is the trigger held (as last fed)? Read by tests.
var held := false
## Smoothed 0..1: how far the rattle is in, how far the motor is bogged down.
var bite_level: float = 0.0
var strain_level: float = 0.0
## This pull's picks: the motor, its spin-up clip, pitch and level.
var motor := ""
var run_clip := ""
var pull_pitch: float = 1.0
var rattle_pitch: float = 1.0
var pull_db: float = 0.0
## How many times the trigger has been pulled (tests).
var pulls: int = 0

var _biting := false
var _straining := false
var _fed_frame: int = -100
var _playback: AudioStreamPlaybackPolyphonic
var _run_id: int = AudioStreamPlaybackPolyphonic.INVALID_ID
var _rattle_id: int = AudioStreamPlaybackPolyphonic.INVALID_ID
var _groan_id: int = AudioStreamPlaybackPolyphonic.INVALID_ID
## Voices fading out: [id, seconds left, dB at the start of the fade].
var _fading: Array = []
## Wind-downs still playing.
var _stop_ids: Array[int] = []
var _rng := RandomNumberGenerator.new()

static var _clips := {}


func _ready() -> void:
	name = "YardSocketSound"
	var poly := AudioStreamPolyphonic.new()
	poly.polyphony = 8
	stream = poly
	bus = muffle_bus(muffle_hz)
	unit_size = 2.0          # m: full level within 2 m (your own tool), quieter beyond
	max_distance = 60.0      # m: other players' sockets are heard within this (as every ToolVoice)
	doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	_rng.randomize()


## The tool bus (AudioMix builds it, a 12 dB/octave low-pass sent to World), its low-pass set
## to `cutoff_hz`.
static func muffle_bus(cutoff_hz: float) -> StringName:
	return Sfx.bus()


static func clip(clip_name: String) -> AudioStream:
	if not _clips.has(clip_name):
		# Made sounds stand in for Void Salvage's recordings, which never come to BSX.
		var made := "socket.run" if clip_name.begins_with("run_") else ("socket.stop" if clip_name.begins_with("stop_") else "socket.rattle")
		_clips[clip_name] = YardToolSounds.stream(made)
	return _clips[clip_name]


## Called every physics step the socket is in hand: the trigger, whether it is on a joint,
## and whether that joint is a seized bolt it can't turn. Not fed (another tool, holstered)
## counts as the trigger let go.
func feed(trigger: bool, biting: bool, straining: bool) -> void:
	_fed_frame = Engine.get_physics_frames()
	_set_held(trigger)
	_biting = trigger and biting
	_straining = _biting and straining


func _physics_process(delta: float) -> void:
	if Engine.get_physics_frames() - _fed_frame > 2:
		_set_held(false)
		_biting = false
		_straining = false
	bite_level = move_toward(bite_level, 1.0 if _biting else 0.0, delta / maxf(bite_fade, 0.001))
	strain_level = move_toward(strain_level, 1.0 if _straining else 0.0, delta / maxf(strain_time, 0.001))
	_update_voices(delta)


func _set_held(on: bool) -> void:
	if on == held:
		return
	held = on
	if on:
		_start()
	else:
		_stop()


## A new pull: pick a motor and a spin-up (not the last one), a pitch and a level.
func _start() -> void:
	pulls += 1
	var runs: Array = []
	for m: String in MOTORS:
		for r: String in MOTORS[m]["runs"]:
			if r != run_clip:
				runs.append([m, r])
	var pick: Array = runs[_rng.randi() % runs.size()]
	motor = pick[0]
	run_clip = pick[1]
	pull_pitch = 1.0 + _rng.randf_range(-pitch_spread, pitch_spread)
	rattle_pitch = pull_pitch * (1.0 + _rng.randf_range(-rattle_spread, rattle_spread))
	pull_db = motor_db + _rng.randf_range(-level_spread_db, level_spread_db)
	if not _ensure_playing():
		return
	_fade_out(_run_id)
	_run_id = _playback.play_stream(clip(run_clip), 0.0, pull_db, _motor_pitch(), 0, bus)


## Trigger let go: the wind-down plays over the running motor, which fades under it.
func _stop() -> void:
	if not _playback or not is_playing():
		return
	var stops: Array = MOTORS[motor]["stops"] if MOTORS.has(motor) else []
	if not stops.is_empty():
		var stop_clip: String = stops[_rng.randi() % stops.size()]
		_stop_ids.append(_playback.play_stream(clip(stop_clip), 0.0, pull_db, _motor_pitch(), 0, bus))
	_fade_out(_run_id)
	_run_id = AudioStreamPlaybackPolyphonic.INVALID_ID


func _motor_pitch() -> float:
	return pull_pitch * lerpf(1.0, bite_pitch, bite_level) * lerpf(1.0, strain_pitch, strain_level)


func _ensure_playing() -> bool:
	if not is_inside_tree():
		return false
	if not is_playing() or _playback == null:
		play()
		_playback = get_stream_playback() as AudioStreamPlaybackPolyphonic
		_run_id = AudioStreamPlaybackPolyphonic.INVALID_ID
		_rattle_id = AudioStreamPlaybackPolyphonic.INVALID_ID
		_groan_id = AudioStreamPlaybackPolyphonic.INVALID_ID
		_fading.clear()
		_stop_ids.clear()
	return _playback != null


func _fade_out(id: int) -> void:
	if id != AudioStreamPlaybackPolyphonic.INVALID_ID:
		_fading.append([id, stop_fade, pull_db])


func _update_voices(delta: float) -> void:
	if _playback == null or not is_playing():
		return
	if _run_id != AudioStreamPlaybackPolyphonic.INVALID_ID:
		_playback.set_stream_pitch_scale(_run_id, _motor_pitch())
	# The rattle comes in at a random point of its loop and goes again when it's off a joint.
	if bite_level > 0.0:
		if _rattle_id == AudioStreamPlaybackPolyphonic.INVALID_ID or not _playback.is_stream_playing(_rattle_id):
			var loop := clip("rattle")
			_rattle_id = _playback.play_stream(loop, _rng.randf() * loop.get_length(), -80.0,
					rattle_pitch, 0, bus)
		var level := pull_db + lerpf(rattle_db, strain_rattle_db, strain_level) + linear_to_db(bite_level)
		_playback.set_stream_volume(_rattle_id, maxf(level, -80.0))
		_playback.set_stream_pitch_scale(_rattle_id, rattle_pitch * lerpf(1.0, strain_pitch, strain_level))
	elif _rattle_id != AudioStreamPlaybackPolyphonic.INVALID_ID:
		_playback.stop_stream(_rattle_id)
		_rattle_id = AudioStreamPlaybackPolyphonic.INVALID_ID
	# The seized bolt's groan swells with the strain and goes with it.
	if strain_level > 0.0:
		if _groan_id == AudioStreamPlaybackPolyphonic.INVALID_ID or not _playback.is_stream_playing(_groan_id):
			var groan := YardToolSounds.stream("tool.socket_groan")
			if groan:
				_groan_id = _playback.play_stream(groan, _rng.randf() * groan.get_length(), -80.0,
						pull_pitch, 0, bus)
		if _groan_id != AudioStreamPlaybackPolyphonic.INVALID_ID:
			_playback.set_stream_volume(_groan_id, maxf(pull_db + groan_db + linear_to_db(strain_level), -80.0))
	elif _groan_id != AudioStreamPlaybackPolyphonic.INVALID_ID:
		_playback.stop_stream(_groan_id)
		_groan_id = AudioStreamPlaybackPolyphonic.INVALID_ID
	for i in range(_fading.size() - 1, -1, -1):
		var f: Array = _fading[i]
		f[1] -= delta
		if f[1] <= 0.0:
			_playback.stop_stream(f[0])
			_fading.remove_at(i)
		else:
			_playback.set_stream_volume(f[0], f[2] + linear_to_db(f[1] / maxf(stop_fade, 0.001)))
	# Idle and quiet: stop the player (it costs nothing until the next pull).
	if not held and bite_level <= 0.0 and _fading.is_empty() and not _any_voice():
		stop()
		_playback = null


func _any_voice() -> bool:
	_stop_ids.assign(_stop_ids.filter(func(id: int) -> bool: return _playback.is_stream_playing(id)))
	return not _stop_ids.is_empty() or _playback.is_stream_playing(_run_id) \
			or _playback.is_stream_playing(_rattle_id) or _playback.is_stream_playing(_groan_id)
