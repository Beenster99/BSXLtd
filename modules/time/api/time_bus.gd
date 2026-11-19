class_name TimeBus
extends Node
## Game time (Modules.bus("time")): how fast the company's calendar runs, and skipping ahead
## to a later date (beenster, 19 Nov: "if we have time in the game, like delivery dates,
## schedule demands from the customer then we may need a way of speeding up and slowing down
## time, or selecting a future date if we're moving quickly").
##
## The calendar itself is Business's clock (game minutes, a day closing each midnight: rent,
## wages, the market, payments falling due, the contracts board). This module sets its pace
## and moves it on; everything dated follows from Business's day. The yard's own clock (bots,
## haulers, delivery ships, TartanCo's visits) runs at the same pace, so work and the calendar
## keep step: at x2 the bots work twice as fast and a day passes twice as fast.
##
## The host sets the pace for everyone (a guest's controls show it read-only):
##   var time := Modules.bus("time") as TimeBus
##   time.rate                      # 0 (paused), 0.5, 1, 2 or 4
##   time.set_rate(2.0)             # host: asks for it; every player gets it
##   time.skip_to(time.minute_of(9, 8 * 60))   # host: jump to day 10, 08:00 (days count from 0)
##   time.now_minute()              # game minutes since the company started (guests too)
##   time.day_seconds()             # real seconds a game day takes at the current pace
##
## Skipping moves the calendar only: every day in between closes as it would have (rent,
## wages, a new market, parts arriving, staged payments due), but work the bots have under
## way does not jump ahead with it. Use a faster pace while they work.
##
## Features (Flags): "time" (the module: the Gameplay settings section), "time.hud" (an info
## card on the right saying so while the pace is not x1).

signal rate_changed(rate: float)
## The calendar jumped from one game minute to another (every player gets it).
signal skipped(from_minute: int, to_minute: int)

const FLAG := "time"
const HUD_FLAG := "time.hud"
const SAVE_SECTION := "time"
const SAVE_VERSION := 1
const RATE_EVENT := "time.rate"
const SKIP_EVENT := "time.skip"
const BEAT_EVENT := "time.beat"
const SECTION_ID := "time.controls"
const INFO_ID := "time.pace"

## The paces on offer: paused, half, normal, double, four times.
const RATES: Array[float] = [0.0, 0.5, 1.0, 2.0, 4.0]
const MINUTES_PER_DAY := 1440
## Business's own pace when it is not loaded (game minutes a real second at x1).
const DEFAULT_MINUTES_PER_SECOND := 2.0
## The furthest a skip may go, in days.
const MAX_SKIP_DAYS := 60
## Where a "next morning" skip lands: 08:00.
const MORNING := 8 * 60
## How often the host tells the crew the time (real seconds), so their clocks keep step.
const BEAT_SECONDS := 5.0

var rate := 1.0
## The last skip: {from, to} in game minutes, {} for none.
var last_skip: Dictionary = {}

## A guest's last word from the host: game minute and the server time it was true at.
var _beat_minute := -1
var _beat_at := 0.0
var _beat_left := 0.0
var _net: Object


func register_module() -> void:
	Saves.register_section(SAVE_SECTION, self)
	Menu.register_settings_section(Menu.GAMEPLAY, SECTION_ID, "Game time", make_panel, 5)
	if Modules.ready_done:
		_hook_up()
	else:
		Modules.modules_ready.connect(_hook_up, CONNECT_ONE_SHOT)
	set_process(true)


func unregister_module() -> void:
	Saves.unregister_section(SAVE_SECTION)
	Menu.unregister_settings_section(Menu.GAMEPLAY, SECTION_ID)
	HudSlots.clear_info(INFO_ID)
	if _net:
		for e: String in [RATE_EVENT, SKIP_EVENT, BEAT_EVENT]:
			_net.call("unregister_event", e)
		_net.call("unregister_snapshot_provider", SAVE_SECTION)


func _hook_up() -> void:
	var net := Modules.bus("multiplayer")
	if net and net.has_method("register_event"):
		use_net(net)
	_push_rate()


## Plays through this Multiplayer bus (tests run two players in one process).
func use_net(net: Object) -> void:
	_net = net
	_net.call("register_event", RATE_EVENT, _apply_rate, _validate_rate)
	_net.call("register_event", SKIP_EVENT, _apply_skip, _validate_skip)
	_net.call("register_event", BEAT_EVENT, _apply_beat)
	_net.call("register_snapshot_provider", SAVE_SECTION, self)


# --- Asking (any player; only the host's asks go through) ---------------------------------

## Asks for a new pace (one of RATES). Only the host's ask is taken.
func set_rate(new_rate: float) -> void:
	_request(RATE_EVENT, {"rate": new_rate})


## Asks to skip the calendar ahead to `to_minute` (game minutes since the start). Only the
## host's ask is taken, and only up to MAX_SKIP_DAYS ahead.
func skip_to(to_minute: int) -> void:
	_request(SKIP_EVENT, {"to": to_minute})


## To the next morning: tomorrow 08:00 (today's, if it is still before 08:00).
func skip_to_morning() -> void:
	skip_to(next_morning())


func _request(event_name: String, payload: Dictionary) -> void:
	if _net:
		_net.call("request", event_name, payload)
		return
	var out: Variant = (_validate_rate if event_name == RATE_EVENT else _validate_skip).call(1, payload)
	if out is Dictionary:
		(_apply_rate if event_name == RATE_EVENT else _apply_skip).call(out)


# --- Reads ------------------------------------------------------------------------------------

## True where the pace can be set: solo, or the host of an online game.
func can_control() -> bool:
	return _net == null or not bool(_net.call("is_online")) or bool(_net.call("is_host"))


## Game minutes since the company started. A guest's runs on from the host's last word.
func now_minute() -> int:
	var own := _business_minute()
	if can_control() or _beat_minute < 0:
		return own
	var since := maxf(0.0, _server_now() - _beat_at)
	return maxi(own, _beat_minute + floori(since * minutes_per_second() * rate))


## The day number (0 = the company's first day), and the game minute a day and time is.
func day() -> int:
	return now_minute() / MINUTES_PER_DAY


static func minute_of(day_number: int, minute_in_day: int) -> int:
	return day_number * MINUTES_PER_DAY + clampi(minute_in_day, 0, MINUTES_PER_DAY - 1)


func next_morning() -> int:
	var now := now_minute()
	var today := now / MINUTES_PER_DAY
	var at := minute_of(today, MORNING)
	return at if at > now else minute_of(today + 1, MORNING)


## The latest minute a skip may go to.
func max_skip_minute() -> int:
	return now_minute() + MAX_SKIP_DAYS * MINUTES_PER_DAY


## "Day 4  14:20" (days counted from 1, as Business shows them).
static func date_text(minute: int) -> String:
	var m := minute % MINUTES_PER_DAY
	return "Day %d  %02d:%02d" % [minute / MINUTES_PER_DAY + 1, m / 60, m % 60]


static func rate_text(r: float) -> String:
	if r <= 0.0:
		return "Paused"
	if is_equal_approx(r, 0.5):
		return "x½"
	return "x%s" % (str(int(r)) if is_equal_approx(r, roundf(r)) else String.num(r, 2))


## Game minutes a real second at x1 (Business's rule, 2 by default: a day is 12 real minutes).
func minutes_per_second() -> float:
	var business := Modules.bus("business")
	if business and business.has_method("get_rules"):
		var rules: Variant = business.call("get_rules")
		if rules is Object and (rules as Object).get("game_minutes_per_second") != null:
			return float((rules as Object).get("game_minutes_per_second"))
	return DEFAULT_MINUTES_PER_SECOND


## Real seconds a game day takes at `at_rate` (the current pace by default); 0 while paused.
func day_seconds(at_rate := -1.0) -> float:
	var r := rate if at_rate < 0.0 else at_rate
	if r <= 0.0:
		return 0.0
	return MINUTES_PER_DAY / (minutes_per_second() * r)


## "12 min", "1 h 30 min", "45 s".
static func span_text(seconds: float) -> String:
	if seconds <= 0.0:
		return "stopped"
	if seconds < 60.0:
		return "%d s" % roundi(seconds)
	var minutes := roundi(seconds / 60.0)
	if minutes < 60:
		return "%d min" % minutes
	return "%d h %02d min" % [minutes / 60, minutes % 60] if minutes % 60 else "%d h" % (minutes / 60)


## What is dated ahead, soonest first, for picking a skip: [{minute, what}] from Business
## (parts on their way, payments expected, contracts due). Only what is after now.
func coming_up(limit := 8) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var now := now_minute()
	var business := Modules.bus("business")
	if business == null:
		return out
	if business.has_method("get_orders"):
		for o: Variant in business.call("get_orders", 0):
			if o is Object and int((o as Object).get("eta_minute")) > now:
				out.append({"minute": int((o as Object).get("eta_minute")), "what": "Parts order %s arrives" % str((o as Object).get("id"))})
	if business.has_method("payment_profiles"):
		for p: Variant in business.call("payment_profiles"):
			if not p is Dictionary:
				continue
			var prof: Dictionary = p
			var title := str(prof.get("title", prof.get("contract_id", "Contract")))
			for st: Variant in prof.get("stages", []):
				if st is Dictionary and not bool((st as Dictionary).get("paid", false)):
					var d := int((st as Dictionary).get("expected_day", -1))
					if d >= 0 and minute_of(d, MORNING) > now:
						out.append({"minute": minute_of(d, MORNING), "what": "%s: %s payment expected" % [title, str((st as Dictionary).get("name", "stage"))]})
			var due := int(prof.get("due_day", -1))
			if due >= 0 and minute_of(due, MORNING) > now:
				out.append({"minute": minute_of(due, MORNING), "what": "%s due" % title})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.minute) < int(b.minute))
	return out.slice(0, limit)


# --- The events ---------------------------------------------------------------------------

func _is_host_sender(sender: int) -> bool:
	if _net == null or not bool(_net.call("is_online")):
		return true
	return sender == int(_net.call("local_peer_id"))


func _validate_rate(sender: int, p: Dictionary) -> Variant:
	if not _is_host_sender(sender):
		return "only the host sets the pace of time"
	var r := float(p.get("rate", 1.0))
	for allowed: float in RATES:
		if is_equal_approx(allowed, r):
			return {"rate": allowed}
	return "no such pace"


func _apply_rate(p: Dictionary) -> void:
	var r := float(p.get("rate", 1.0))
	if is_equal_approx(r, rate):
		return
	rate = r
	_note_beat()
	_push_rate()
	_show_card()
	rate_changed.emit(rate)


## While the pace is not x1, a card on the right says so (everyone sees it).
func _show_card() -> void:
	if not Flags.is_on(HUD_FLAG):
		return
	if is_equal_approx(rate, 1.0):
		HudSlots.clear_info(INFO_ID)
		return
	var title := "Time paused" if rate <= 0.0 else "Time %s" % rate_text(rate)
	var text := "The calendar and the yard's work are stopped." if rate <= 0.0 \
			else "A game day takes %s." % span_text(day_seconds())
	HudSlots.set_info(INFO_ID, title, text + "\nEsc > Settings > Gameplay", 90)


func _validate_skip(sender: int, p: Dictionary) -> Variant:
	if not _is_host_sender(sender):
		return "only the host skips time ahead"
	var now := now_minute()
	var to := int(p.get("to", -1))
	if to <= now:
		return "that time has already passed"
	if to > max_skip_minute():
		return "at most %d days ahead" % MAX_SKIP_DAYS
	return {"from": now, "to": to}


func _apply_skip(p: Dictionary) -> void:
	var from := int(p.get("from", 0))
	var to := int(p.get("to", 0))
	if can_control():
		var business := Modules.bus("business")
		if business and business.has_method("skip_to_minute"):
			business.call("skip_to_minute", to)
		elif business and business.has_method("advance_minutes"):
			business.call("advance_minutes", to - _business_minute())
	_beat_minute = to
	_beat_at = _server_now()
	last_skip = {"from": from, "to": to}
	skipped.emit(from, to)


func _apply_beat(p: Dictionary) -> void:
	if can_control():
		return
	_beat_minute = int(p.get("minute", -1))
	_beat_at = float(p.get("at", _server_now()))
	var r := float(p.get("rate", rate))
	if not is_equal_approx(r, rate):
		rate = r
		_show_card()
		rate_changed.emit(rate)


## The host tells everyone the time every few seconds (a guest's own copy of the books only
## moves when they change), and straight away when the pace changes.
func _process(delta: float) -> void:
	if _net == null or not can_control() or not bool(_net.call("is_online")):
		return
	_beat_left -= delta
	if _beat_left <= 0.0:
		_note_beat()


func _note_beat() -> void:
	_beat_left = BEAT_SECONDS
	if _net and bool(_net.call("is_online")) and bool(_net.call("is_host")):
		_net.call("host_emit", BEAT_EVENT, {"minute": _business_minute(), "at": _server_now(), "rate": rate})


## The host hands the yard's clock the pace (stamped into the yard's shared log, so every
## player's bots change pace at the same tick), and Business reads `rate` itself.
func _push_rate() -> void:
	if not can_control():
		return
	var yard := Modules.bus("yard")
	if yard and yard.has_method("set_sim_rate"):
		yard.call("set_sim_rate", rate)


func _business_minute() -> int:
	var business := Modules.bus("business")
	if business and business.has_method("get_minute"):
		return int(business.call("get_minute"))
	return 0


func _server_now() -> float:
	if _net:
		return float(_net.call("server_time"))
	return Time.get_ticks_usec() / 1_000_000.0


# --- The settings section -----------------------------------------------------------------

func make_panel() -> Control:
	var panel: Control = preload("res://modules/time/internal/time_panel.gd").new()
	panel.call("setup", self)
	return panel


# --- Saves and joining ----------------------------------------------------------------------

func save_version() -> int:
	return SAVE_VERSION


func save_data() -> Dictionary:
	return {"rate": rate}


func load_data(data: Dictionary, _from_version: int) -> void:
	var r := float(data.get("rate", 1.0))
	if not RATES.any(func(x: float) -> bool: return is_equal_approx(x, r)):
		r = 1.0
	last_skip = {}
	var changed := not is_equal_approx(r, rate)
	rate = r
	_push_rate()
	_show_card()
	if changed:
		rate_changed.emit(rate)


func reset_data() -> void:
	load_data({}, SAVE_VERSION)


func get_net_snapshot() -> Dictionary:
	return {"rate": rate, "minute": _business_minute(), "at": _server_now()}


func apply_net_snapshot(data: Dictionary) -> void:
	_apply_beat(data)
