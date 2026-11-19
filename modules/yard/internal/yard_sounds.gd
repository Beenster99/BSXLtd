class_name YardSounds
extends Node3D
## The station's sound (first sound pass, 19 Nov, flag yard.sounds): everything in the yard
## that had no voice, heard from where it is. Presentation only: it reads the station's parts
## and makes noise, it never changes them, and nothing is sent (each machine hears its own).
##
##   ambience  life support humming inside the station (station_hum) and, out in the dock,
##             the frame's low rumble through your suit (dock_hum); now and then a creak of the
##             frame or a vent breathing out somewhere near you.
##   you       footsteps on the decks (Sfx's steps), a thud when you land, your jets hissing
##             while you thrust in the dock (jet).
##   airlocks  both locks: a beep as a cycle starts, each door's motor and its seal, the pump.
##   bots      stores and mover bots' lift fans (bot_hover) and the worker androids' jets
##             (worker_jets), louder and higher the faster they fly; the welders' arcs
##             (weld_arc), rivet guns (rivet_punch) and nut runners (bolt_run).
##   ships     the delivery and service ships' engines (ship_engine) as they come and go.
##   stores    a chime when a kit has all arrived.
## The sounds are YardSoundBank's (made in code; see there for the list). Any `@export` here
## is a level or a timing to tune by ear.

const Bank := preload("res://modules/yard/internal/yard_sound_bank.gd")
const FLAG := "yard.sounds"
const EMITTER := "YardSoundHum"

@export_group("Levels (dB)")
@export var station_hum_db := -26.0
@export var dock_hum_db := -30.0
@export var jet_db := -16.0
@export var step_db := -20.0
@export var bot_db := -16.0
@export var worker_db := -14.0
@export var ship_db := -6.0
@export var airlock_db := -8.0
@export var work_db := -10.0
@export var creak_db := -24.0
@export_group("Timing")
## Seconds between creaks and vent puffs inside, at random within this range.
@export var creak_every := Vector2(18.0, 45.0)
## Metres between footsteps walking and running.
@export var stride := 0.75
@export var run_stride := 1.2
## How often new bots and ships are looked for (s).
@export var scan_every := 0.5

var station: Node3D
## Every moving thing with a hum on it: {node, player, kind, last, speed, base_db, top}.
var hums: Array[Dictionary] = []
var station_hum: AudioStreamPlayer
var dock_hum: AudioStreamPlayer
var jet: AudioStreamPlayer
var steps := 0
var played: Dictionary = {}   # sound -> times played (tests read it)

var _rng := RandomNumberGenerator.new()
var _scan_left := 0.0
var _creak_left := 0.0
var _walked := 0.0
var _was_grounded := true
var _fall := 0.0
var _locks: Dictionary = {}     # airlock node -> {state, pump (player)}
var _workers: Dictionary = {}   # worker node id -> {arc (player), fired, phase}
var _inside := 1.0


static func enabled() -> bool:
	return Flags.is_on(FLAG)


func setup(of_station: Node3D) -> YardSounds:
	station = of_station
	name = "YardSounds"
	return self


func _ready() -> void:
	_rng.randomize()
	_creak_left = _rng.randf_range(creak_every.x * 0.4, creak_every.y * 0.6)
	station_hum = _flat("station_hum", station_hum_db)
	dock_hum = _flat("dock_hum", -80.0)
	jet = _flat("jet", -80.0)
	var traffic := _get_node("traffic")
	if traffic and traffic.has_signal("kit_delivered"):
		traffic.connect("kit_delivered", func(_id: int, _kit: String) -> void: _play("chime", null, -18.0))


func _process(delta: float) -> void:
	if station == null or not is_instance_valid(station) or delta <= 0.0:
		return
	_scan_left -= delta
	if _scan_left <= 0.0:
		_scan_left = scan_every
		_scan()
	_ambience(delta)
	_you(delta)
	for lock: String in ["airlock", "design_lock"]:
		_airlock(_get_node(lock))
	_update_hums(delta)
	_worker_trades()


# --- Ambience ------------------------------------------------------------------------------

func _ambience(delta: float) -> void:
	var rig := _get_node("mover")
	var inside := true
	if rig:
		inside = bool(rig.get("in_gravity"))
	_inside = move_toward(_inside, 1.0 if inside else 0.0, delta * 1.5)
	station_hum.volume_db = lerpf(-60.0, station_hum_db, _inside)
	dock_hum.volume_db = lerpf(dock_hum_db, -60.0, _inside)
	if not inside or rig == null:
		return
	_creak_left -= delta
	if _creak_left <= 0.0:
		_creak_left = _rng.randf_range(creak_every.x, creak_every.y)
		var at: Vector3 = (rig as Node3D).global_position + Vector3(_rng.randf_range(-8, 8), 2.5, _rng.randf_range(-8, 8))
		var sound := "creak" if _rng.randf() < 0.65 else "vent_puff"
		_play(sound, at, creak_db, _rng.randf_range(0.85, 1.15))


# --- You -----------------------------------------------------------------------------------

func _you(delta: float) -> void:
	var rig := _get_node("mover") as RigidBody3D
	if rig == null:
		jet.volume_db = -80.0
		return
	var grounded := bool(rig.call("grounded")) if rig.has_method("grounded") else false
	var vel := rig.linear_velocity
	if rig.has_method("ground_velocity"):
		vel -= rig.call("ground_velocity") as Vector3
	# Jets: only off the deck, as loud as you push.
	var push := 0.0
	if not grounded and not bool(rig.get("in_gravity")):
		var thrust: Vector3 = rig.get("thrust_input")
		push = clampf(thrust.length(), 0.0, 1.0)
	var want := lerpf(-50.0, jet_db, push) if push > 0.02 else -80.0
	jet.volume_db = move_toward(jet.volume_db, want, delta * 120.0)
	jet.pitch_scale = 0.9 + 0.2 * push
	# Footsteps and landings.
	if not grounded:
		_fall = maxf(_fall, -vel.y)
		_was_grounded = false
		return
	if not _was_grounded:
		_was_grounded = true
		if _fall > 2.5:
			_play("land", rig, step_db + 2.0, _rng.randf_range(0.9, 1.05))
		_fall = 0.0
		_walked = stride * 0.5
		return
	var flat := Vector2(vel.x, vel.z).length()
	if flat < 0.4:
		_walked = stride * 0.6
		return
	_walked += flat * delta
	var length := lerpf(stride, run_stride, clampf((flat - 3.0) / 2.5, 0.0, 1.0))
	if _walked >= length:
		_walked -= length
		steps += 1
		var p := _play("step_metal", rig, step_db, _rng.randf_range(0.92, 1.08) * (1.03 if steps % 2 == 0 else 0.97))
		if p is AudioStreamPlayer3D:
			(p as AudioStreamPlayer3D).unit_size = 2.5


# --- Airlocks ------------------------------------------------------------------------------

func _airlock(lock: Node) -> void:
	if lock == null or not ("state" in lock):
		return
	var key := lock.get_instance_id()
	if not _locks.has(key):
		var pump := AudioStreamPlayer3D.new()
		pump.stream = Bank.stream("airlock_pump")
		pump.bus = Sfx.bus()
		pump.unit_size = 4.0
		pump.max_distance = 30.0
		pump.volume_db = airlock_db - 4.0
		lock.add_child(pump)
		pump.position = _lock_middle(lock)
		_locks[key] = {"state": int(lock.get("state")), "pump": pump}
	var rec: Dictionary = _locks[key]
	var state := int(lock.get("state"))
	if state == int(rec.state):
		return
	var was := int(rec.state)
	rec.state = state
	var going_out := bool(lock.get("going_out"))
	var pump: AudioStreamPlayer3D = rec.pump
	# Airlock.State: INNER_OPEN, OUTER_OPEN, CLOSING, PUMPING, OPENING.
	match state:
		2:  # closing the door being left
			_play_bank("lock_beep", pump.global_position, airlock_db - 2.0)
			_play_bank("door_motor", _door(lock, not going_out), airlock_db)
		3:  # pumping
			_play_bank("door_seal", _door(lock, not going_out), airlock_db)
			pump.play()
		4:  # opening the other door
			pump.stop()
			_play_bank("door_motor", _door(lock, going_out), airlock_db, 1.06)
		0, 1:
			if was == 4:
				_play_bank("door_seal", _door(lock, state == 1), airlock_db - 6.0, 1.3)


func _door(lock: Node, outer: bool) -> Variant:
	var d: Variant = lock.get("outer_door" if outer else "inner_door")
	if d is Node3D and is_instance_valid(d):
		return (d as Node3D).global_position
	return (lock as Node3D).global_position if lock is Node3D else null


func _lock_middle(lock: Node) -> Vector3:
	var a: Variant = lock.get("inner_door")
	var b: Variant = lock.get("outer_door")
	if a is Node3D and b is Node3D:
		return ((a as Node3D).position + (b as Node3D).position) * 0.5
	return Vector3.ZERO


# --- Bots and ships ------------------------------------------------------------------------

## Finds bots and ships that have no hum yet and gives them one.
func _scan() -> void:
	var traffic := _get_node("traffic")
	if traffic:
		for b: Dictionary in _list(traffic, "bots"):
			_hum_on(b.get("node"), "bot_hover", bot_db, 6.0)
		for h: Dictionary in _list(traffic, "haulers"):
			_hum_on(h.get("node"), "ship_engine", ship_db, 25.0)
			for c: Variant in h.get("crew", []):
				if c is Dictionary:
					_hum_on((c as Dictionary).get("node"), "bot_hover", bot_db - 4.0, 6.0)
		var ship: Variant = traffic.get("_ship")
		if ship is Dictionary:
			_hum_on((ship as Dictionary).get("node"), "ship_engine", ship_db + 2.0, 25.0)
	var workers := _get_node("workers")
	if workers:
		for w: Dictionary in _list(workers, "workers"):
			_hum_on(w.get("node"), "worker_jets", worker_db, 4.0)
		var service: Variant = workers.get("service")
		if service is Node:
			var ts: Variant = (service as Node).get("ship")
			_hum_on(ts, "ship_engine", ship_db, 25.0)
			for e: Dictionary in _list(service as Node, "team"):
				_hum_on(e.get("node"), "worker_jets", worker_db - 6.0, 4.0)
	hums = hums.filter(func(h: Dictionary) -> bool: return is_instance_valid(h.node) and is_instance_valid(h.player))


func _hum_on(node: Variant, kind: String, base_db: float, top: float) -> void:
	if not (node is Node3D) or not is_instance_valid(node):
		return
	var n := node as Node3D
	if not n.is_inside_tree() or n.has_node(EMITTER):
		return
	var p := AudioStreamPlayer3D.new()
	p.name = EMITTER
	p.stream = Bank.stream(kind)
	p.bus = Sfx.bus()
	var ship := kind == "ship_engine"
	p.unit_size = 30.0 if ship else 3.0
	p.max_distance = 600.0 if ship else 40.0
	p.volume_db = -80.0
	p.autoplay = true
	n.add_child(p)
	hums.append({"node": n, "player": p, "kind": kind, "last": n.global_position, "speed": 0.0,
			"base_db": base_db, "top": top, "pitch": _rng.randf_range(0.93, 1.07)})


## Each hum follows its body's speed: idling quiet and low, flat out loud and high.
func _update_hums(delta: float) -> void:
	for h: Dictionary in hums:
		var n: Node3D = h.node
		if not is_instance_valid(n) or not is_instance_valid(h.player):
			continue
		var at := n.global_position
		var speed := (at - (h.last as Vector3)).length() / delta
		h.last = at
		if speed > 200.0:
			speed = 0.0   # a teleport, not a flight
		h.speed = lerpf(float(h.speed), speed, minf(1.0, delta * 4.0))
		var k := clampf(float(h.speed) / float(h.top), 0.0, 1.0)
		var p: AudioStreamPlayer3D = h.player
		var idle := -14.0 if h.kind == "ship_engine" else -10.0
		p.volume_db = float(h.base_db) + lerpf(idle, 0.0, k) if n.is_visible_in_tree() else -80.0
		p.pitch_scale = float(h.pitch) * lerpf(0.85, 1.15, k)


# --- The worker androids' trades -----------------------------------------------------------

func _worker_trades() -> void:
	var workers := _get_node("workers")
	if workers == null:
		return
	for w: Dictionary in _list(workers, "workers"):
		var node: Variant = w.get("node")
		if not (node is Node3D) or not is_instance_valid(node):
			continue
		var key := (node as Node).get_instance_id()
		if not _workers.has(key):
			var arc := AudioStreamPlayer3D.new()
			arc.stream = Bank.stream("weld_arc")
			arc.bus = Sfx.bus()
			arc.unit_size = 3.0
			arc.max_distance = 40.0
			arc.volume_db = work_db
			(node as Node3D).add_child(arc)
			_workers[key] = {"arc": arc, "fired": false, "phase": ""}
		var rec: Dictionary = _workers[key]
		var arc: AudioStreamPlayer3D = rec.arc
		# Welding: the arc runs while the torch throws sparks.
		var sparks: Variant = w.get("sparks")
		var welding := sparks is CPUParticles3D and (sparks as CPUParticles3D).emitting
		if welding and not arc.playing:
			arc.pitch_scale = _rng.randf_range(0.92, 1.08)
			arc.play()
			played["weld_arc"] = int(played.get("weld_arc", 0)) + 1
		elif not welding and arc.playing:
			arc.stop()
		var task: Variant = w.get("task")
		if not (task is Dictionary) or (task as Dictionary).is_empty():
			rec.fired = false
			rec.phase = ""
			continue
		var t := task as Dictionary
		var kind := String(t.get("kind", ""))
		var phase := String(t.get("phase", ""))
		if kind == "rivet":
			var fired := t.has("fired")
			if fired and not bool(rec.fired):
				_play_bank("rivet_punch", node, work_db, _rng.randf_range(0.94, 1.06))
			rec.fired = fired
		elif kind == "bolt":
			# Each bolt the runner seats: phase "run" with a new bolt or a new joint.
			var bolt_key := "%s:%d:%d" % [phase, int(t.get("bolt", 0)), (t.get("joints", []) as Array).size()]
			if phase == "run" and bolt_key != String(rec.get("bolt", "")):
				_play_bank("bolt_run", node, work_db - 2.0, _rng.randf_range(0.94, 1.06))
			rec.bolt = bolt_key
		rec.phase = phase


# --- Helpers -------------------------------------------------------------------------------

func _flat(sound: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = sound.capitalize().replace(" ", "")
	p.stream = Bank.stream(sound)
	p.bus = Sfx.bus()
	p.volume_db = db
	p.autoplay = true
	add_child(p)
	return p


## A bank sound once, at a node or a point (as Sfx.play).
func _play_bank(sound: String, at: Variant, db: float, pitch: float = 1.0) -> Node:
	if at == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = Bank.stream(sound)
	p.bus = Sfx.bus()
	p.volume_db = db
	p.pitch_scale = pitch
	p.unit_size = 5.0
	p.max_distance = 60.0
	if at is Node3D and (at as Node3D).is_inside_tree():
		(at as Node3D).add_child(p)
	else:
		add_child(p)
		if at is Vector3:
			p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()
	played[sound] = int(played.get(sound, 0)) + 1
	return p


## A bank sound, or else one of Sfx's.
func _play(sound: String, at: Variant, db: float, pitch: float = 1.0) -> Node:
	if Bank.SOUNDS.has(sound):
		return _play_bank(sound, at, db, pitch)
	played[sound] = int(played.get(sound, 0)) + 1
	return Sfx.play(sound, at, db, pitch)


func _get_node(prop: String) -> Node:
	var v: Variant = station.get(prop) if station else null
	return v as Node if v is Node and is_instance_valid(v) else null


func _list(of: Node, prop: String) -> Array:
	var v: Variant = of.get(prop)
	return v if v is Array else []
