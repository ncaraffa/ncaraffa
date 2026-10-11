class_name MysteryEvent
extends Node
## Base class for a world event driven by the EventDirector.
##
## To add a new event: create a script extending MysteryEvent in
## scripts/events/, set its id/resources in _init, implement _start() (and
## optionally can_start()), call finish() when it no longer drives anything,
## and add the script path to EventDirector.EVENT_SCRIPTS. Nothing else changes.

var id := ""
var title := ""
## Objects this event drives. The director never runs two events that share one.
var resources: PackedStringArray = []
## Persistent / temporary / reactive — informative, shown in the debug panel.
var kinds: PackedStringArray = []
var repeatable := true
var weight := 1.0
## 0 everyday, 1 strange, 2 disturbing, 3 intense terror
var intensity := 1
## first night this event may happen on
var min_night := 1
## "main" = the ten original events (2-3 min, then 4-6 min); "side" = apparitions
## and other night-dependent happenings on their own, irregular schedule.
var track := "main"
var max_per_night := 1
var running := false
var director: Node
var rng := RandomNumberGenerator.new()


func can_start() -> bool:
	return true


func begin() -> bool:
	for r in resources:
		if WorldState.is_locked(r):
			return false
	if not can_start():
		return false
	for r in resources:
		WorldState.try_lock(r, id)
	running = true
	_start()
	return true


func _start() -> void:
	finish()


func finish() -> void:
	if not running:
		return
	running = false
	for r in resources:
		WorldState.unlock(r, id)
	if director and director.has_method("on_event_finished"):
		director.on_event_finished(self)


func record(variant: String, data: Dictionary = {}) -> void:
	var d := data.duplicate()
	d["intensity"] = intensity
	WorldState.log_event(id, variant, d)


func night() -> int:
	return int(WorldState.get_state("night", 1))


func figure() -> ShadowFigure:
	var pool = WorldState.get_obj("figures")
	return pool.borrow() if pool else null


func house() -> House:
	return WorldState.get_obj("house") as House


## Delay on the director's (scalable) simulation clock.
func after(seconds: float, fn: Callable) -> void:
	director.after(seconds, fn)


## Short real-time delay (for things that must keep a natural rhythm).
func wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds, false).timeout


func pick_weighted(options: Dictionary) -> String:
	var total := 0.0
	for k in options:
		total += float(options[k])
	var r := rng.randf() * total
	for k in options:
		r -= float(options[k])
		if r <= 0.0:
			return k
	return options.keys()[0]
