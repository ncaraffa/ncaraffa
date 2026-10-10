class_name EventDirector
extends Node
## Schedules the world's happenings on invisible clocks. Two tracks:
##
## MAIN — the ten original events. Each night: the first one 2-3 min after
##   waking, then every 4-6 min (random each time), random order, never two on
##   the same object (locks). They carry over between nights until all ten
##   have happened; afterwards rarer repeats keep the world alive.
## SIDE — apparitions and other night-dependent happenings (figures, chanting,
##   banging...). Gated by the current night, on their own irregular rhythm.
##   "Disturbing" ones wait while the ScareDirector is in a recovery period and
##   never overlap another disturbing event.
##
## Nothing here depends on tasks or on where the player is. No timers are shown.

signal event_started(id: String)
signal event_finished(id: String)

const EVENT_SCRIPTS := [
	"res://scripts/events/ev_chair.gd",
	"res://scripts/events/ev_neighbor_lights.gd",
	"res://scripts/events/ev_knock.gd",
	"res://scripts/events/ev_phone.gd",
	"res://scripts/events/ev_car.gd",
	"res://scripts/events/ev_tv.gd",
	"res://scripts/events/ev_footsteps.gd",
	"res://scripts/events/ev_clock.gd",
	"res://scripts/events/ev_photo.gd",
	"res://scripts/events/ev_press_enter.gd",
	# side track
	"res://scripts/events/ap_street.gd",
	"res://scripts/events/ap_window.gd",
	"res://scripts/events/ap_backyard.gd",
	"res://scripts/events/ap_hall.gd",
	"res://scripts/events/ap_glimpse.gd",
	"res://scripts/events/ev_chant.gd",
	"res://scripts/events/ev_object_fall.gd",
	"res://scripts/events/ev_lights_out.gd",
	"res://scripts/events/ev_bang.gd",
	"res://scripts/events/ev_whisper.gd",
	"res://scripts/events/ev_door_creak.gd",
	"res://scripts/events/ev_flicker.gd",
]

const FIRST_DELAY := Vector2(120.0, 180.0)
const INTERVAL := Vector2(240.0, 360.0)
const AFTER_INTERVAL := Vector2(300.0, 600.0)
## side-track spacing per night (index = night, last value reused)
const SIDE_INTERVAL := [Vector2(0, 0), Vector2(200, 340), Vector2(150, 260), Vector2(120, 220), Vector2(100, 190), Vector2(90, 170)]
const RETRY := 20.0

var events: Array = []
var clock := 0.0             # seconds, scaled by time_scale
var time_scale := 1.0
var next_at := 0.0
var side_next_at := 0.0
var night := 1
var fired: Dictionary = {}   # id -> total count
var tonight: Dictionary = {} # id -> count this night
var order: Array = []        # ids in the order they fired
var seed_used := 0
var rng := RandomNumberGenerator.new()
var last_main_start := -999.0
var _timers: Array = []      # [{at, fn}]


func _ready() -> void:
	name = "EventDirector"
	rng.randomize()
	seed_used = rng.seed
	for path in EVENT_SCRIPTS:
		var scr: Script = load(path)
		if scr == null:
			WorldState.warn("Could not load event " + path)
			continue
		var ev: MysteryEvent = scr.new()
		ev.director = self
		ev.rng.seed = rng.randi()
		add_child(ev)
		events.append(ev)
	next_at = rng.randf_range(FIRST_DELAY.x, FIRST_DELAY.y)
	side_next_at = _side_gap()
	WorldState.register("director", self)


func new_night(n: int) -> void:
	night = n
	tonight.clear()
	next_at = clock + rng.randf_range(FIRST_DELAY.x, FIRST_DELAY.y)
	side_next_at = clock + _side_gap() * rng.randf_range(0.6, 1.0)


func _side_gap() -> float:
	var span: Vector2 = SIDE_INTERVAL[min(night, SIDE_INTERVAL.size() - 1)]
	return rng.randf_range(span.x, span.y)


func _process(delta: float) -> void:
	clock += delta * time_scale
	if not _timers.is_empty():
		var due := []
		for t in _timers:
			if t.at <= clock:
				due.append(t)
		for t in due:
			_timers.erase(t)
			if t.fn.is_valid():
				t.fn.call()
	var p = WorldState.player
	if p and p.get("sleeping") == true:
		return
	if WorldState.get_state("night/interrupted", false):
		return
	if clock >= next_at:
		_fire_main()
	if clock >= side_next_at:
		_fire_side()


func after(seconds: float, fn: Callable) -> void:
	_timers.append({"at": clock + seconds, "fn": fn})


func main_events() -> Array:
	return events.filter(func(e): return e.track == "main")


func main_done() -> bool:
	for ev in main_events():
		if not fired.has(ev.id):
			return false
	return true


func _scares() -> Node:
	return WorldState.get_obj("scare_director")


func _intense_running() -> bool:
	for ev in events:
		if ev.running and ev.intensity >= 2:
			return true
	var sd := _scares()
	return sd != null and sd.armed != null and sd.armed.firing


func _available(ev: MysteryEvent) -> bool:
	if ev.running:
		return false
	for r in ev.resources:
		if WorldState.is_locked(r):
			return false
	if ev.intensity >= 2 and _intense_running():
		return false
	return ev.can_start()


func _fire_main() -> void:
	var done := main_done()
	var pool := []
	for ev in main_events():
		if not _available(ev):
			continue
		if done:
			if ev.repeatable:
				pool.append(ev)
		elif not fired.has(ev.id):
			pool.append(ev)
	if pool.is_empty():
		next_at = clock + RETRY
		return
	var chosen := _pick(pool, done)
	if _start_event(chosen):
		last_main_start = clock
		var span := AFTER_INTERVAL if main_done() else INTERVAL
		next_at = clock + rng.randf_range(span.x, span.y)
	else:
		next_at = clock + RETRY


func _fire_side() -> void:
	var sd := _scares()
	var pool := []
	for ev in events:
		if ev.track != "side" or night < ev.min_night:
			continue
		if int(tonight.get(ev.id, 0)) >= ev.max_per_night:
			continue
		if ev.intensity >= 2 and sd and sd.is_recovering():
			continue
		if _available(ev):
			pool.append(ev)
	# keep a little air between a main event and an apparition
	if pool.is_empty() or clock - last_main_start < 45.0:
		side_next_at = clock + 30.0
		return
	if _start_event(_pick(pool, false)):
		side_next_at = clock + _side_gap()
	else:
		side_next_at = clock + 30.0


func _pick(pool: Array, after_phase: bool) -> MysteryEvent:
	var total := 0.0
	for ev in pool:
		total += _weight(ev, after_phase)
	var r := rng.randf() * total
	for ev in pool:
		r -= _weight(ev, after_phase)
		if r <= 0.0:
			return ev
	return pool[0]


func _weight(ev: MysteryEvent, after_phase: bool) -> float:
	if not after_phase:
		return ev.weight
	return ev.weight / (1.0 + float(fired.get(ev.id, 0)))


func _start_event(ev: MysteryEvent) -> bool:
	if not ev.begin():
		WorldState.warn("Event '%s' could not start (locked or unavailable)" % ev.id)
		return false
	fired[ev.id] = int(fired.get(ev.id, 0)) + 1
	tonight[ev.id] = int(tonight.get(ev.id, 0)) + 1
	order.append(ev.id)
	event_started.emit(ev.id)
	return true


func on_event_finished(ev: MysteryEvent) -> void:
	event_finished.emit(ev.id)


func time_to_next() -> float:
	return max(0.0, next_at - clock)


func get_event(event_id: String) -> MysteryEvent:
	for ev in events:
		if ev.id == event_id:
			return ev
	return null


# ------------------------------------------------------------------ debug API
func force(event_id: String) -> String:
	var ev := get_event(event_id)
	if ev == null:
		return "unknown event " + event_id
	if ev.running:
		return ev.id + " is already running"
	for r in ev.resources:
		if WorldState.is_locked(r):
			return "%s blocked: '%s' locked by %s" % [ev.id, r, WorldState.locks[r]]
	if not ev.can_start():
		return ev.id + " cannot start right now (context)"
	return ev.id + " started" if _start_event(ev) else ev.id + " failed"


func skip_to_next() -> void:
	next_at = clock


## Dry run of the main-track selection logic (no locks, no side effects).
func simulate_orders(count: int) -> Array:
	var out := []
	var sim := RandomNumberGenerator.new()
	sim.randomize()
	for i in count:
		var ids := []
		for ev in main_events():
			ids.append(ev.id)
		var seq := []
		var t := sim.randf_range(FIRST_DELAY.x, FIRST_DELAY.y)
		while not ids.is_empty():
			var k := sim.randi_range(0, ids.size() - 1)
			seq.append("%s@%dm%02ds" % [ids[k], int(t / 60), int(t) % 60])
			ids.remove_at(k)
			t += sim.randf_range(INTERVAL.x, INTERVAL.y)
		out.append(seq)
	return out
