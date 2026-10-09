class_name EventDirector
extends Node
## Schedules the world's mysterious events on an invisible clock.
##
## - First event 2–3 min after PLAY, then every 4–6 min (random each time).
## - Order is random per playthrough; events never share an object (locks).
## - Events run whether or not the player is nearby, and can be missed.
## - After the ten main events the world keeps going: rarer repeats of some
##   events, plus all the ambient activity. No ending, no victory.

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
]

const FIRST_DELAY := Vector2(120.0, 180.0)
const INTERVAL := Vector2(240.0, 360.0)
const AFTER_INTERVAL := Vector2(300.0, 600.0)
const RETRY := 20.0

var events: Array = []
var clock := 0.0             # seconds, scaled by time_scale
var time_scale := 1.0
var next_at := 0.0
var fired: Dictionary = {}   # id -> count
var order: Array = []        # ids in the order they fired
var seed_used := 0
var rng := RandomNumberGenerator.new()
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
	WorldState.register("director", self)


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
	if clock >= next_at:
		_fire_next()


func after(seconds: float, fn: Callable) -> void:
	_timers.append({"at": clock + seconds, "fn": fn})


func main_done() -> bool:
	for ev in events:
		if not fired.has(ev.id):
			return false
	return true


func _available(ev: MysteryEvent) -> bool:
	if ev.running:
		return false
	for r in ev.resources:
		if WorldState.is_locked(r):
			return false
	return ev.can_start()


func _fire_next() -> void:
	var done := main_done()
	var pool := []
	for ev in events:
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
	var total := 0.0
	for ev in pool:
		total += _weight(ev, done)
	var r := rng.randf() * total
	var chosen: MysteryEvent = pool[0]
	for ev in pool:
		r -= _weight(ev, done)
		if r <= 0.0:
			chosen = ev
			break
	if _start_event(chosen):
		var span := AFTER_INTERVAL if main_done() else INTERVAL
		next_at = clock + rng.randf_range(span.x, span.y)
	else:
		next_at = clock + RETRY


func _weight(ev: MysteryEvent, after_phase: bool) -> float:
	if not after_phase:
		return ev.weight
	# repeats get rarer the more often they happened
	return ev.weight / (1.0 + float(fired.get(ev.id, 0)))


func _start_event(ev: MysteryEvent) -> bool:
	if not ev.begin():
		WorldState.warn("Event '%s' could not start (locked or unavailable)" % ev.id)
		return false
	fired[ev.id] = int(fired.get(ev.id, 0)) + 1
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
		return ev.id + " cannot start right now"
	return ev.id + " started" if _start_event(ev) else ev.id + " failed"


func skip_to_next() -> void:
	next_at = clock


## Dry run of the selection logic (no locks, no side effects).
func simulate_orders(count: int) -> Array:
	var out := []
	var sim := RandomNumberGenerator.new()
	sim.randomize()
	for i in count:
		var ids := []
		for ev in events:
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
