extends Node
## WorldStateManager — the single source of truth for the simulated world.
##
## Everything that can change (doors, lights, moved objects, events, interactions,
## temporary consequences) is written here. Objects register themselves by id so
## that systems (events, ambience, debug tools) can find them without hard links.
## Resource locks prevent two systems from driving the same object at once.

signal state_changed(key: String, value)
signal event_logged(entry: Dictionary)

var objects: Dictionary = {}        # id -> Node
var state: Dictionary = {}          # "door/front" -> true, "light/hall" -> false ...
var event_log: Array = []           # [{id, variant, time, clock, data}]
var interaction_log: Array = []     # [{what, id, time}]
var locks: Dictionary = {}          # resource -> owner (String)
var warnings: Array = []            # conflicts / errors, shown in the debug panel

## Seconds since the player pressed PLAY (real time, never scaled).
var sim_time := 0.0
## In-world clock, minutes after midnight of the evening the game starts.
var clock_start_minutes := 23.0 * 60.0
var player_inside := true
var player: Node3D = null
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	reset()


func reset() -> void:
	objects.clear()
	state.clear()
	event_log.clear()
	interaction_log.clear()
	locks.clear()
	warnings.clear()
	sim_time = 0.0
	rng.randomize()
	# Somewhere between 22:41 and 23:19 — the world has its own time.
	clock_start_minutes = 22.0 * 60.0 + 41.0 + rng.randi_range(0, 38) + rng.randf()
	player = null
	player_inside = true


func _process(delta: float) -> void:
	if GameManager.in_game:
		sim_time += delta


# ------------------------------------------------------------------ registry
func register(id: String, node: Node) -> void:
	if objects.has(id) and is_instance_valid(objects[id]) and objects[id] != node:
		warn("Duplicate object id '%s'" % id)
	objects[id] = node


func get_obj(id: String) -> Node:
	var n = objects.get(id)
	if n != null and is_instance_valid(n):
		return n
	return null


func get_group(prefix: String) -> Array:
	var out := []
	for k in objects.keys():
		if String(k).begins_with(prefix) and is_instance_valid(objects[k]):
			out.append(objects[k])
	return out


# ------------------------------------------------------------------ state
func set_state(key: String, value) -> void:
	var old = state.get(key)
	state[key] = value
	# an Array/Dictionary changed in place compares equal to itself: always notify
	if old != value or (typeof(value) in [TYPE_ARRAY, TYPE_DICTIONARY] and is_same(old, value)):
		state_changed.emit(key, value)


func get_state(key: String, default = null):
	return state.get(key, default)


func log_event(id: String, variant: String, data: Dictionary = {}) -> void:
	var entry := {
		"id": id, "variant": variant, "time": sim_time,
		"clock": format_clock(clock_minutes()), "data": data,
		"player_pos": player.global_position if player else Vector3.ZERO,
		"player_inside": player_inside,
	}
	event_log.append(entry)
	set_state("event/" + id + "/count", int(get_state("event/" + id + "/count", 0)) + 1)
	event_logged.emit(entry)


func log_interaction(what: String, id: String) -> void:
	interaction_log.append({"what": what, "id": id, "time": sim_time})
	if interaction_log.size() > 500:
		interaction_log.pop_front()
	set_state("interaction/" + what + "/" + id, int(get_state("interaction/" + what + "/" + id, 0)) + 1)


func warn(msg: String) -> void:
	warnings.append("[%.1fs] %s" % [sim_time, msg])
	if GameManager.dev_mode:
		push_warning(msg)


# ------------------------------------------------------------------ locks
func try_lock(resource: String, owner: String) -> bool:
	if locks.has(resource) and locks[resource] != owner:
		return false
	locks[resource] = owner
	return true


func unlock(resource: String, owner: String) -> void:
	if locks.get(resource) == owner:
		locks.erase(resource)
	elif locks.has(resource):
		warn("'%s' tried to release '%s' owned by '%s'" % [owner, resource, locks[resource]])


func is_locked(resource: String) -> bool:
	return locks.has(resource)


# ------------------------------------------------------------------ clock
func clock_minutes(offset_minutes: float = 0.0) -> float:
	return fposmod(clock_start_minutes + sim_time / 60.0 + offset_minutes, 24.0 * 60.0)


static func format_clock(minutes: float, twelve_hour := false) -> String:
	var h := int(minutes / 60.0) % 24
	var m := int(minutes) % 60
	if twelve_hour:
		var h12 := h % 12
		if h12 == 0:
			h12 = 12
		return "%d:%02d" % [h12, m]
	return "%02d:%02d" % [h, m]


func dump() -> String:
	var lines := PackedStringArray()
	lines.append("sim_time %.1f  clock %s  inside=%s" % [sim_time, format_clock(clock_minutes()), player_inside])
	var keys := state.keys()
	keys.sort()
	for k in keys:
		lines.append("%s = %s" % [k, str(state[k])])
	lines.append("-- locks: " + str(locks))
	return "\n".join(lines)
