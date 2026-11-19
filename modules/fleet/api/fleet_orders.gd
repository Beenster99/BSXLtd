class_name FleetOrders
extends RefCounted
## The orders for TartanCo's bot fleet (beenster, 19 Nov: "create groups of bots and assign them
## a list of work tasks (derived from the build plan) and some priorities"). Pure data: groups
## of bots, each with a priority and an ordered task list. Every change is a command applied in
## the same order on every machine (FleetBus.command), so ids are counted, never random.
##
## Groundwork for the master plan's Wave 6 (bots you direct): the yard's crew does not read these
## orders yet. When auto-building arrives it reads groups() and each group's tasks, top first,
## higher group priority first.
##
## A group: {id, name, colour, priority (1 low .. 5 urgent), bots: [serial], tasks: [task]}.
## A task: {id, line, name, trade, joins, qty, unit, hours, stage, priority (1..5)}: one line of
## the build plan (see plan_tasks), `line` its key there, `trade` the bot role that does it.

const PRIORITY_MIN := 1
const PRIORITY_MAX := 5
const PRIORITY_DEFAULT := 3
const PRIORITY_NAMES := {1: "Low", 2: "Later", 3: "Normal", 4: "High", 5: "Urgent"}
## The group colours, in turn.
const COLOURS: Array[Color] = [Color("e8792b"), Color("6fc8e8"), Color("7fd47a"), Color("e8c25a"),
		Color("c58cf0"), Color("ff7f9e")]
## Build stages, in the order a ship goes up: the default order of a plan's tasks.
const STAGES: PackedStringArray = ["frame", "hull", "inner", "deck", "rooms", "components", "doors", "services"]
const STAGE_NAMES := {"frame": "Frame", "hull": "Hull", "inner": "Inner walls", "deck": "Decks",
		"rooms": "Fit-out", "components": "Components", "doors": "Doors", "services": "Services"}
## Trades: the TartanCo models (YardWorkerLook.ROLES) and what each does.
const TRADES := {"F": "Fitter", "W": "Welder", "R": "Riveter", "B": "Bolter"}

## The commands, as {op, ...}:
##   group_add {name}                      group_remove {group}
##   group_rename {group, name}            group_priority {group, priority}
##   bot_assign {serial, group}            ("" takes it out of every group)
##   task_add {group, task}                task_remove {group, task}
##   task_move {group, task, by}           task_priority {group, task, priority}
##   tasks_clear {group}
const OPS: PackedStringArray = ["group_add", "group_remove", "group_rename", "group_priority", "bot_assign",
		"task_add", "task_remove", "task_move", "task_priority", "tasks_clear"]

var groups: Array[Dictionary] = []
var _next_group := 1
var _next_task := 1


## Applies one command; false (and nothing changes) if it doesn't fit.
func apply(cmd: Dictionary) -> bool:
	var op := str(cmd.get("op", ""))
	match op:
		"group_add":
			var name := str(cmd.get("name", "")).strip_edges()
			if name == "":
				name = "Group %d" % _next_group
			groups.append({"id": "g%d" % _next_group, "name": name.left(32),
					"colour": COLOURS[(_next_group - 1) % COLOURS.size()].to_html(false),
					"priority": PRIORITY_DEFAULT, "bots": [], "tasks": []})
			_next_group += 1
			return true
		"group_remove":
			var i := _group_index(str(cmd.get("group", "")))
			if i < 0:
				return false
			groups.remove_at(i)
			return true
		"group_rename":
			var g := group(str(cmd.get("group", "")))
			var name := str(cmd.get("name", "")).strip_edges()
			if g.is_empty() or name == "":
				return false
			g.name = name.left(32)
			return true
		"group_priority":
			var g := group(str(cmd.get("group", "")))
			if g.is_empty():
				return false
			g.priority = clampi(int(cmd.get("priority", PRIORITY_DEFAULT)), PRIORITY_MIN, PRIORITY_MAX)
			return true
		"bot_assign":
			var serial := str(cmd.get("serial", ""))
			var to := str(cmd.get("group", ""))
			if serial == "" or (to != "" and group(to).is_empty()):
				return false
			for g: Dictionary in groups:
				(g.bots as Array).erase(serial)
			if to != "":
				(group(to).bots as Array).append(serial)
			return true
		"task_add":
			var g := group(str(cmd.get("group", "")))
			var t: Variant = cmd.get("task")
			if g.is_empty() or not t is Dictionary:
				return false
			var task := (t as Dictionary).duplicate(true)
			task.id = "t%d" % _next_task
			_next_task += 1
			task.priority = clampi(int(task.get("priority", PRIORITY_DEFAULT)), PRIORITY_MIN, PRIORITY_MAX)
			(g.tasks as Array).append(task)
			return true
		"task_remove":
			var g := group(str(cmd.get("group", "")))
			var i := _task_index(g, str(cmd.get("task", "")))
			if i < 0:
				return false
			(g.tasks as Array).remove_at(i)
			return true
		"task_move":
			var g := group(str(cmd.get("group", "")))
			var i := _task_index(g, str(cmd.get("task", "")))
			var to := i + int(cmd.get("by", 0))
			if i < 0 or to < 0 or to >= (g.tasks as Array).size() or to == i:
				return false
			var tasks: Array = g.tasks
			var t: Variant = tasks[i]
			tasks.remove_at(i)
			tasks.insert(to, t)
			return true
		"task_priority":
			var g := group(str(cmd.get("group", "")))
			var i := _task_index(g, str(cmd.get("task", "")))
			if i < 0:
				return false
			(g.tasks as Array)[i].priority = clampi(int(cmd.get("priority", PRIORITY_DEFAULT)), PRIORITY_MIN, PRIORITY_MAX)
			return true
		"tasks_clear":
			var g := group(str(cmd.get("group", "")))
			if g.is_empty():
				return false
			(g.tasks as Array).clear()
			return true
	return false


func group(id: String) -> Dictionary:
	var i := _group_index(id)
	return groups[i] if i >= 0 else {}


## The group a bot is in, or {}.
func group_of(serial: String) -> Dictionary:
	for g: Dictionary in groups:
		if (g.bots as Array).has(serial):
			return g
	return {}


## The groups in the order the crew would serve them: priority, then the order they were made.
func by_priority() -> Array[Dictionary]:
	var out: Array[Dictionary] = groups.duplicate()
	var at := {}
	for i in groups.size():
		at[groups[i].id] = i
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.priority) > int(b.priority) if int(a.priority) != int(b.priority) else int(at[a.id]) < int(at[b.id]))
	return out


## A group's tasks for its bots to take, best first: priority, then their place in the list.
static func queue(g: Dictionary) -> Array:
	var tasks: Array = (g.get("tasks", []) as Array).duplicate()
	var at := {}
	for i in tasks.size():
		at[tasks[i].id] = i
	tasks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.priority) > int(b.priority) if int(a.priority) != int(b.priority) else int(at[a.id]) < int(at[b.id]))
	return tasks


func _group_index(id: String) -> int:
	for i in groups.size():
		if groups[i].id == id:
			return i
	return -1


func _task_index(g: Dictionary, id: String) -> int:
	if g.is_empty():
		return -1
	var tasks: Array = g.tasks
	for i in tasks.size():
		if tasks[i].id == id:
			return i
	return -1


# --- The build plan as tasks ----------------------------------------------------------------

## The work tasks for a design's build plan (DesignTotals.lines), in build order, joined by
## TartanCo's rule (beenster, 19 Nov): beams welded; inner walls riveted at the plate corners;
## hull plates riveted at the corners and a short weld along one side; components bolted down;
## pipes bolted; wires riveted. The joint-count lines (welds, rivets, bolts) are not tasks.
static func plan_tasks(lines: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for line: Dictionary in lines:
		var t := _task_for(line)
		if not t.is_empty():
			out.append(t)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return STAGES.find(a.stage) < STAGES.find(b.stage))
	return out


static func _task_for(line: Dictionary) -> Dictionary:
	var kind := str(line.get("kind", ""))
	var id := str(line.get("id", ""))
	var name := str(line.get("name", id))
	var t := {"line": "%s:%s" % [kind, id], "qty": float(line.get("qty", 0.0)), "unit": str(line.get("unit", "")),
			"hours": float(line.get("hours", 0.0)), "priority": PRIORITY_DEFAULT}
	match kind:
		"hull":
			match id:
				"frame":
					t.merge({"stage": "frame", "name": "Weld the frame (%s)" % name, "trade": "W", "joins": "Beams welded"})
				"hull":
					t.merge({"stage": "hull", "name": "Plate the hull (%s)" % name, "trade": "R",
							"joins": "Riveted at the corners, short weld along one side"})
				"inner":
					t.merge({"stage": "inner", "name": "Line the inner walls (%s)" % name, "trade": "R",
							"joins": "Riveted at the plate corners"})
				"deck":
					t.merge({"stage": "deck", "name": "Lay the decks (%s)" % name, "trade": "B", "joins": "Bolted"})
				_:
					return {}
		"room":
			t.merge({"stage": "rooms", "name": "Fit out the %s" % name.to_lower(), "trade": "F", "joins": "Bolted"})
		"component":
			var big := float(line.get("mass", 0.0)) / maxf(float(line.get("qty", 1.0)), 1.0) >= 2000.0
			t.merge({"stage": "components", "name": "Install %s" % name, "trade": "F",
					"joins": "Bolted down, several bolts" if big else "Bolted down"})
		"door":
			t.merge({"stage": "doors", "name": "Hang %s" % name.to_lower(), "trade": "F", "joins": "Bolted"})
		"service":
			var wire := id == "wire"
			t.merge({"stage": "services", "name": "Run the %s" % name.to_lower(), "trade": "R" if wire else "B",
					"joins": "Riveted" if wire else "Bolted"})
		_:
			return {}
	return t


# --- Saving and sharing -----------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"groups": groups.duplicate(true), "next_group": _next_group, "next_task": _next_task}


func from_dict(d: Dictionary) -> void:
	groups.clear()
	for g: Variant in d.get("groups", []):
		if g is Dictionary:
			groups.append((g as Dictionary).duplicate(true))
	_next_group = maxi(1, int(d.get("next_group", groups.size() + 1)))
	_next_task = maxi(1, int(d.get("next_task", 1)))
