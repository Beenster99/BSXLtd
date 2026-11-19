extends ModuleTest
## The yard's first sound pass (YardSounds, YardSoundBank): every made sound is there and not
## silent, loops loop, the station gets its sounds under yard.sounds, the ambience runs, the
## airlock's cycle beeps, runs its doors and pumps, and the bots and ships carry hums.
##   tools/run_tests.sh yard

const Bank := preload("res://modules/yard/internal/yard_sound_bank.gd")


func run_tests() -> void:
	_bank()
	for f: String in [YardBus.FLAG, YardBus.STATION, YardBus.DOCK, YardBus.RACKING, YardSounds.FLAG]:
		Flags.set_flag(f, true)
	var bus := Modules.bus("yard") as YardBus
	if bus == null:
		bus = YardBus.new()
		bus.name = "yard"
		Modules.add_child(bus)
		bus.register_module()
	var station := (load(YardBus.SCENE_PATH) as PackedScene).instantiate() as Node3D
	add_child(station)
	await frames(3)
	var sounds := station.get_node_or_null("YardSounds") as YardSounds
	check(sounds != null, "the station has its sounds under yard.sounds")
	if sounds == null:
		station.queue_free()
		return
	check(sounds.station_hum.playing and sounds.station_hum.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,
			"life support hums inside")
	_airlock(station, sounds)
	# Busy stores: the bots and haulers get hums.
	station.call("start_demo_contract")
	for i in 12:
		await frames(5)
	sounds.call("_scan")
	check(sounds.hums.size() > 0, "bots and ships carry hums (%d)" % sounds.hums.size())
	var kinds := {}
	for h: Dictionary in sounds.hums:
		kinds[h.kind] = true
	check(kinds.has("bot_hover"), "a stores bot hums")
	station.queue_free()
	await frames(2)

	Flags.set_flag(YardSounds.FLAG, false)
	var quiet := (load(YardBus.SCENE_PATH) as PackedScene).instantiate() as Node3D
	add_child(quiet)
	await frames(2)
	check(quiet.get_node_or_null("YardSounds") == null, "no station sounds with the flag off")
	quiet.queue_free()
	await frames(2)
	Flags.set_flag(YardSounds.FLAG, true)


func _bank() -> void:
	for sound: String in Bank.names():
		var wav := Bank.stream(sound)
		var ok := wav != null and wav.data.size() > 2000
		var peak := 0
		if ok:
			for i in range(0, wav.data.size() - 1, 2):
				peak = maxi(peak, absi(wav.data.decode_s16(i)))
		check(ok and peak > 8000, "%s is made and not silent" % sound)
		if sound in Bank.LOOPS:
			check(wav.loop_mode == AudioStreamWAV.LOOP_FORWARD and wav.loop_end == wav.data.size() / 2,
					"%s loops" % sound)
			# The seam: the last sample runs on into the first no harder than any step inside.
			var biggest := 0
			for i in range(2, wav.data.size() - 1, 2):
				biggest = maxi(biggest, absi(wav.data.decode_s16(i) - wav.data.decode_s16(i - 2)))
			var seam := absi(wav.data.decode_s16(wav.data.size() - 2) - wav.data.decode_s16(0))
			check(seam <= biggest, "%s loops without a click (%d, inside up to %d)" % [sound, seam, biggest])
	check(Bank.stream("door_motor") == Bank.stream("door_motor"), "made once")


func _airlock(station: Node3D, sounds: YardSounds) -> void:
	var lock: Node = station.get("airlock")
	lock.call("cycle", true)
	sounds.call("_airlock", lock)
	check(int(sounds.played.get("lock_beep", 0)) == 1 and int(sounds.played.get("door_motor", 0)) == 1,
			"a cycle beeps and runs the door")
	var pumped := false
	for i in 200:
		lock.call("advance", 0.05)
		sounds.call("_airlock", lock)
		var rec: Dictionary = sounds.get("_locks")[lock.get_instance_id()]
		if (rec.pump as AudioStreamPlayer3D).playing:
			pumped = true
		if not bool(lock.call("is_busy")):
			break
	check(pumped, "the pump runs while it pumps")
	check(int(sounds.played.get("door_motor", 0)) == 2 and int(sounds.played.get("door_seal", 0)) >= 2,
			"the other door opens and both seal")
