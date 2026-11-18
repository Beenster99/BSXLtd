class_name PowerGrid
extends RefCounted
## Works out which parts of a structure have power. Pure data, no nodes.
##
## Power starts at SOURCE parts (and at parts a battery tool is clipped to), and spreads
## through CONNECTOR joints only: the plugs between loom spans and the plugs on device
## leads. CONDUCTOR parts pass it on; a SWITCH passes it on only while closed; CONSUMER
## parts take it and pass nothing on. Cut a plug and everything past it goes dark.
##
## Every machine runs this on the same joints and switch states, so all players agree on
## what is live without sending power over the network.


## Returns {part id: level} for every powered part: the level (0..1, never 0: an unpowered
## part is left out) is the highest source level reaching it (`PartData.source_level`: a
## LOW wreck's reactor runs everything at 0.15, a dead one at nothing). `battery_fed` =
## {part id: anything} for parts a battery tool powers right now, at full level. `structure` is
## anything holding `parts` and `connections`: a SalvageStructure, or a ship's PartModel (its
## grid is a description, docs/SHIP_FRAME_PLAN.md decision 4, but it reads the same way).
static func compute(structure: Object, battery_fed: Dictionary = {}) -> Dictionary:
	var links: Dictionary = {}
	for c in structure.connections:
		if c.is_broken() or c.kind != ConnectionData.Kind.CONNECTOR:
			continue
		if not structure.parts.has(c.part_a) or not structure.parts.has(c.part_b):
			continue
		(links.get_or_add(c.part_a, []) as Array).append(c.part_b)
		(links.get_or_add(c.part_b, []) as Array).append(c.part_a)

	var powered: Dictionary = {}
	var sources: Array = []
	for id: int in structure.parts:
		var part: PartData = structure.parts[id]
		if part.power == PartData.Power.SOURCE:
			var level := part.source_level()
			if level > 0.0:
				sources.append([level, id])
		if battery_fed.has(id):
			# A battery on a device powers that device only (devices don't back-feed).
			powered[id] = 1.0
	# Brightest first: level doesn't fall along a loom, so the first source to reach a part
	# is the highest one that does.
	sources.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	var reached: Dictionary = {}
	for src: Array in sources:
		var level: float = src[0]
		var start: int = src[1]
		if reached.has(start):
			continue
		reached[start] = true
		powered[start] = maxf(level, powered.get(start, 0.0))
		var queue: Array[int] = [start]
		while not queue.is_empty():
			var id: int = queue.pop_back()
			for n: int in links.get(id, []):
				if reached.has(n):
					continue
				var part: PartData = structure.parts[n]
				if part.power == PartData.Power.NONE:
					continue
				reached[n] = true
				powered[n] = maxf(level, powered.get(n, 0.0))
				if part.power == PartData.Power.CONDUCTOR \
						or (part.power == PartData.Power.SWITCH and part.switch_closed):
					queue.append(n)
	return powered
