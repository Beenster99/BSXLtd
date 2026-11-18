class_name YardToolVoice
extends AudioStreamPlayer3D
## A tool as the whole crew hears it (AU2, docs/review/13_SOUND_AND_MUSIC.md 2.4): an emitter on
## the working head of the grinder, cutter, plasma torch and socket, and on the grabber and the
## battery, built like the socket's YardSocketSound. The ToolController feeds it every physics step
## from the rig's tool state, on every machine for every rig (`feed`), so you hear a mate's tool
## where they work it, through the Tools bus (the suit's low-pass, AudioMix), out to
## `hear_range`. Presentation only: nothing is sent.
##
## Its layers are YardToolSounds' made sounds (Void Salvage's recorded clips never come to BSX):
##   grinder  the disc running free (tool.grinder_free). On metal the bite comes in
##            (tool.grinder_bite) and the note drops to `bite_pitch`, climbing back to
##            `through_pitch` as the joint's health runs out: you hear a mate's joint is nearly
##            through. The metal moves the note (its material voice, BreakSounds.material_voice,
##            by `material_share`): titanium screams. On a metal harder than the disc (it works it
##            slower than full, Materials.tool_factor) it skates instead (tool.grinder_skate at
##            `skate_db`) and the note never drops: you hear TOO HARD before you read it. Each pull
##            spins up from `spin_from` and winds down when let go.
##   cutter   the gas torch's roar (tool.cutter), a pop as it lights (tool.cutter_light).
##   plasma   the arc's hiss and buzz (tool.plasma).
##            Both run louder and a shade lower on metal (`bite_db`, `contact_pitch`).
##   grabber  the tractor hum while the claw holds (tool.grabber), a clunk as it takes hold
##            (tool.grabber_grip).
##   battery  the whine while it feeds a device (tool.battery).
##   socket   none of its own: the impact gun is YardSocketSound's. It carries the one-shots.
##   spray    the can's hiss while the trigger is held (tool.spray).
## The one-shots any tool plays at its head: `zap` (tool.zap, live wiring at the bite) and `clack`
## (tool.stretch, the boom letting go at full stretch).

## The layers of each kind: the running loop, the bite and skate loops over it, the one-shot as
## it starts, whether it spins up and down; and its level (dB) and on-metal lift (dB).
const KINDS := {
	"grinder": {"run": "tool.grinder_free", "bite": "tool.grinder_bite", "skate": "tool.grinder_skate",
			"start": "", "spin": true, "db": -4.0, "bite_db": 0.0, "start_db": 0.0},
	"cutter": {"run": "tool.cutter", "bite": "", "skate": "", "start": "tool.cutter_light", "spin": false,
			"db": -6.0, "bite_db": 3.0, "start_db": -4.0},
	"plasma": {"run": "tool.plasma", "bite": "", "skate": "", "start": "", "spin": false,
			"db": -6.0, "bite_db": 4.0, "start_db": 0.0},
	"grabber": {"run": "tool.grabber", "bite": "", "skate": "", "start": "tool.grabber_grip", "spin": false,
			"db": -10.0, "bite_db": 0.0, "start_db": -4.0},
	"battery": {"run": "tool.battery", "bite": "", "skate": "", "start": "", "spin": false,
			"db": -14.0, "bite_db": 0.0, "start_db": 0.0},
	"socket": {"run": "", "bite": "", "skate": "", "start": "", "spin": false,
			"db": 0.0, "bite_db": 0.0, "start_db": 0.0},
	"riveter": {"run": "tool.riveter", "bite": "", "skate": "", "start": "", "spin": false,
			"db": -8.0, "bite_db": 4.0, "start_db": 0.0},
	"welder": {"run": "tool.welder", "bite": "", "skate": "", "start": "tool.zap", "spin": false,
			"db": -9.0, "bite_db": 5.0, "start_db": -8.0},
	"spray": {"run": "tool.spray", "bite": "", "skate": "", "start": "", "spin": false,
			"db": -12.0, "bite_db": 1.0, "start_db": 0.0},
}

## Which tool this is (a KINDS key). Set before it enters the tree.
var kind: String = "grinder"

@export_group("Levels")
## The running sound's level, in dB (set from KINDS when it enters the tree).
@export var level_db: float = -4.0
## On metal: the grinder's bite layer, over `level_db`; the torches' lift, in dB.
@export var bite_db: float = 0.0
## The grinder's free-running layer while it bites, in dB under its own level.
@export var free_under_bite_db: float = -8.0
## The grinder skating on a metal too hard for it, in dB over `level_db`.
@export var skate_db: float = -4.0
## The one-shot as it starts (the torch lighting, the claw taking hold), in dB.
@export var start_db: float = 0.0
## Live wiring cracking at the bite, in dB.
@export var zap_db: float = -2.0
## The boom snapping back at full stretch, in dB.
@export var clack_db: float = -6.0

@export_group("Pitch")
## The grinder's note as it bites, as a share of its free pitch: the disc loads up.
@export var bite_pitch: float = 0.88
## The note as the joint it bites is nearly through (it climbs from `bite_pitch` as the
## joint's health runs out), as a share.
@export var through_pitch: float = 0.98
## How much of the metal's voice goes into the bite's note, 0..1 (titanium's 1.25 at 0.5 is
## 12% higher than steel).
@export var material_share: float = 0.5
## The torches' note on metal, as a share.
@export var contact_pitch: float = 0.95
## Seconds for the note to glide to where it is going.
@export var pitch_time: float = 0.12

@export_group("Feel")
## How far each pull's pitch may land from 1, as a share (0.03 = +/- 3%).
@export var pitch_spread: float = 0.03
## How far each pull's level may land from the set level, in dB (+/-).
@export var level_spread_db: float = 1.0
## The grinder's note at the start of its spin-up and the end of its wind-down, as a share.
@export var spin_from: float = 0.35
## Seconds for the grinder to spin up.
@export var spin_up: float = 0.35
## Seconds for the grinder to wind down when let go.
@export var spin_down: float = 0.7
## Seconds for the other tools to come in, and to go when let go.
@export var attack: float = 0.05
@export var release: float = 0.12
## Seconds for the bite or the skate to come in or go.
@export var bite_fade: float = 0.1

@export_group("Range")
## Full level within this distance (m), quieter beyond (inverse distance).
@export var hear_unit: float = 3.0
## Heard this far off (m): a crewmate's tool over their suit mic (AU9a will route it).
@export var hear_range: float = 60.0

## Is the tool running (as last fed)? Read by tests.
var held := false
## Smoothed 0..1: how far the running sound, the bite and the skate are in.
var run_level: float = 0.0
var bite_level: float = 0.0
var skate_level: float = 0.0
## The note now and where it is going (a share of the free pitch, before the pull's spread).
var pitch: float = 1.0
var target_pitch: float = 1.0
## This pull's spread: its pitch and its level (dB).
var pull_pitch: float = 1.0
var pull_db: float = 0.0
## Counts (tests): pulls, bites (each time it came onto a joint), the one-shots as it started,
## zaps and clacks.
var pulls: int = 0
var bites: int = 0
var starts: int = 0
var zaps: int = 0
var clacks: int = 0

var _contact := false
var _biting := false
var _through: float = 0.0
var _under := false
var _voice: float = 1.0
var _fed_frame: int = -100
var _pick: int = 0
var _playback: AudioStreamPlaybackPolyphonic
var _run_id: int = AudioStreamPlaybackPolyphonic.INVALID_ID
var _bite_id: int = AudioStreamPlaybackPolyphonic.INVALID_ID
var _skate_id: int = AudioStreamPlaybackPolyphonic.INVALID_ID
## One-shots still playing.
var _shot_ids: Array[int] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "YardToolVoice"
	var spec: Dictionary = KINDS.get(kind, KINDS["grinder"])
	level_db = float(spec["db"])
	bite_db = float(spec["bite_db"])
	start_db = float(spec["start_db"])
	var poly := AudioStreamPolyphonic.new()
	poly.polyphony = 8
	stream = poly
	bus = Sfx.bus()
	unit_size = hear_unit
	max_distance = hear_range
	doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	_rng.randomize()
	set_physics_process(false)


## Called every physics step the tool is in hand: is it running (the trigger held; the claw
## holding; the battery feeding), is it on something, is that a joint, how far through the
## joint is (0..1), how fast the tool works it (1 = full; less skates) and the metal's voice
## (BreakSounds.material_voice, 1 = steel). Not fed (another tool, holstered) = let go.
func feed(on: bool, contact: bool, biting: bool, through: float, factor: float, voice: float) -> void:
	_fed_frame = Engine.get_physics_frames()
	set_physics_process(true)
	_set_held(on)
	_contact = on and contact
	if _contact and biting and not _biting:
		bites += 1
	_biting = _contact and biting
	_through = clampf(through, 0.0, 1.0) if _biting else 0.0
	_under = _biting and factor < 0.999
	_voice = voice


## Live wiring cracks at the bite (every rig's, every `ToolController.shock_interval`).
func zap() -> void:
	zaps += 1
	_one_shot("tool.zap", zap_db, 1.0 + _rng.randf_range(-0.05, 0.05))


## The boom let go of its joint at full stretch and snapped back.
func clack() -> void:
	clacks += 1
	_one_shot("tool.stretch", clack_db, 1.0 + _rng.randf_range(-0.04, 0.04))


func _physics_process(delta: float) -> void:
	if Engine.get_physics_frames() - _fed_frame > 2:
		_set_held(false)
		_contact = false
		_biting = false
		_under = false
	var spec: Dictionary = KINDS.get(kind, KINDS["grinder"])
	var spins := bool(spec["spin"])
	var rise := spin_up if spins else attack
	var fall := spin_down if spins else release
	run_level = move_toward(run_level, 1.0 if held else 0.0,
			delta / maxf(rise if held else fall, 0.001))
	var fade := delta / maxf(bite_fade, 0.001)
	bite_level = move_toward(bite_level, 1.0 if _contact and not _under else 0.0, fade)
	skate_level = move_toward(skate_level, 1.0 if _under else 0.0, fade)
	target_pitch = _target()
	pitch = move_toward(pitch, target_pitch, delta * absf(target_pitch - pitch) / maxf(pitch_time, 0.001) + delta * 0.05)
	_update_voices(spec)


## Where the note is going: the grinder's from its bite, the joint's health and the metal; the
## torches' a shade lower on metal.
func _target() -> float:
	if kind == "grinder":
		if not _contact or _under:
			return 1.0
		return lerpf(bite_pitch, through_pitch, _through) * pow(maxf(_voice, 0.01), material_share)
	if kind == "cutter" or kind == "plasma":
		return lerpf(1.0, contact_pitch, 1.0 if _contact else 0.0)
	return 1.0


## The note the layers play at now: the pull's spread, the grinder's spin and where the note is.
func play_pitch() -> float:
	var spin := 1.0
	if bool(KINDS.get(kind, KINDS["grinder"])["spin"]):
		spin = lerpf(spin_from, 1.0, smoothstep(0.0, 1.0, run_level))
	return pull_pitch * spin * pitch


func _set_held(on: bool) -> void:
	if on == held:
		return
	held = on
	if not on:
		return
	# A new pull: its own pitch and level, and (with recordings) its own clip.
	pulls += 1
	pull_pitch = 1.0 + _rng.randf_range(-pitch_spread, pitch_spread)
	pull_db = _rng.randf_range(-level_spread_db, level_spread_db)
	_pick = _rng.randi() % 1000
	var start := String(KINDS.get(kind, KINDS["grinder"])["start"])
	if start != "":
		starts += 1
		_one_shot(start, start_db + pull_db, pull_pitch)


func _update_voices(spec: Dictionary) -> void:
	var p := play_pitch()
	var base := level_db + pull_db
	if kind == "grinder":
		var free_db := base + lerpf(0.0, free_under_bite_db, bite_level) + linear_to_db(run_level)
		_run_id = _layer(_run_id, String(spec["run"]), run_level > 0.0, free_db, p)
		_bite_id = _layer(_bite_id, String(spec["bite"]), bite_level * run_level > 0.0,
				base + bite_db + linear_to_db(bite_level * run_level), p)
		_skate_id = _layer(_skate_id, String(spec["skate"]), skate_level * run_level > 0.0,
				base + skate_db + linear_to_db(skate_level * run_level), pull_pitch)
	else:
		var lift := bite_db * bite_level
		_run_id = _layer(_run_id, String(spec["run"]), run_level > 0.0, base + lift + linear_to_db(run_level), p)
	# Quiet and idle: stop the player and the step (nothing costs until the next feed).
	if not held and run_level <= 0.0 and bite_level <= 0.0 and skate_level <= 0.0 and not _any_shot():
		if _playback and is_playing():
			stop()
		_playback = null
		_run_id = AudioStreamPlaybackPolyphonic.INVALID_ID
		_bite_id = AudioStreamPlaybackPolyphonic.INVALID_ID
		_skate_id = AudioStreamPlaybackPolyphonic.INVALID_ID
		if Engine.get_physics_frames() - _fed_frame > 2:
			set_physics_process(false)


## Keeps one looping layer going while `want`, at `db` and `p`; stops it when not. A clip that
## doesn't loop starts again when it ends. Returns its id.
func _layer(id: int, event: String, want: bool, db: float, p: float) -> int:
	if event == "":
		return AudioStreamPlaybackPolyphonic.INVALID_ID
	if not want:
		if id != AudioStreamPlaybackPolyphonic.INVALID_ID and _playback:
			_playback.stop_stream(id)
		return AudioStreamPlaybackPolyphonic.INVALID_ID
	if not _ensure_playing():
		return AudioStreamPlaybackPolyphonic.INVALID_ID
	db = maxf(db, -80.0)
	if id == AudioStreamPlaybackPolyphonic.INVALID_ID or not _playback.is_stream_playing(id):
		var s := YardToolSounds.stream(event)
		if s == null:
			return AudioStreamPlaybackPolyphonic.INVALID_ID
		# Loops come in at a random point, so two grinders never run in step.
		return _playback.play_stream(s, _rng.randf() * s.get_length(), db, p, 0, bus)
	_playback.set_stream_volume(id, db)
	_playback.set_stream_pitch_scale(id, p)
	return id


func _one_shot(event: String, db: float, p: float) -> void:
	var s := YardToolSounds.stream(event)
	if s == null or not _ensure_playing():
		return
	set_physics_process(true)
	_shot_ids.append(_playback.play_stream(s, 0.0, db, p, 0, bus))


func _ensure_playing() -> bool:
	if not is_inside_tree():
		return false
	if not is_playing() or _playback == null:
		play()
		_playback = get_stream_playback() as AudioStreamPlaybackPolyphonic
		_run_id = AudioStreamPlaybackPolyphonic.INVALID_ID
		_bite_id = AudioStreamPlaybackPolyphonic.INVALID_ID
		_skate_id = AudioStreamPlaybackPolyphonic.INVALID_ID
		_shot_ids.clear()
	return _playback != null


func _any_shot() -> bool:
	if _playback == null:
		return false
	_shot_ids.assign(_shot_ids.filter(func(id: int) -> bool: return _playback.is_stream_playing(id)))
	return not _shot_ids.is_empty()


## The layers playing now (tests): "run", "bite", "skate".
func layers() -> Array[String]:
	var out: Array[String] = []
	if _playback == null:
		return out
	for pair: Array in [["run", _run_id], ["bite", _bite_id], ["skate", _skate_id]]:
		if int(pair[1]) != AudioStreamPlaybackPolyphonic.INVALID_ID and _playback.is_stream_playing(int(pair[1])):
			out.append(String(pair[0]))
	return out
