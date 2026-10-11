class_name ScareDirector
extends Node
## Decides IF and WHEN something truly frightening may happen.
##
## It never schedules a scare at a fixed time. It keeps a "tension" value fed by
## the world's events, respects the current night, enforces long recovery
## periods after a scare (the world goes back to looking normal), never fires
## while the player is busy with a chore, and never repeats the same scare
## twice in a row. When it decides the moment is right it ARMS one scare that
## fits where the player is; the scare then waits for its own trigger (a look
## down the hallway, a door being opened...) and gives up if it never comes.

signal scare_fired(id: String)

const SCARE_SCRIPTS := [
	"res://scripts/horror/scares/scare_hallway.gd",
	"res://scripts/horror/scares/scare_door.gd",
	"res://scripts/horror/scares/scare_window.gd",
	"res://scripts/horror/scares/scare_behind.gd",
	"res://scripts/horror/scares/scare_tv.gd",
	"res://scripts/horror/scares/scare_runner.gd",
	"res://scripts/horror/scares/scare_contort.gd",
]
## Max intense scares per night (index = night; there are five).
const QUOTA := [0, 0, 0, 1, 2, 3]
## Chance per evaluation (every ~20 s) to arm something, before tension.
const BASE_CHANCE := [0.0, 0.0, 0.0, 0.12, 0.16, 0.22]

var scares: Array = []
var night := 1
var tension := 0.0
var night_started := 0.0
var recover_until := 0.0
var fired_tonight := 0
var used_tonight: Array = []
var last_id := ""
var armed: Scare = null
var enabled := true
var rng := RandomNumberGenerator.new()
var _eval_t := 0.0


func _ready() -> void:
	name = "ScareDirector"
	rng.randomize()
	WorldState.register("scare_director", self)
	for path in SCARE_SCRIPTS:
		var s: Scare = load(path).new()
		s.director = self
		s.rng.seed = rng.randi()
		add_child(s)
		scares.append(s)
	WorldState.event_logged.connect(_on_event)


func new_night(n: int) -> void:
	night = n
	night_started = WorldState.sim_time
	fired_tonight = 0
	used_tonight.clear()
	tension = clamp(tension * 0.5, 0.0, 0.4)
	recover_until = WorldState.sim_time + 240.0     # every night starts calm
	if armed:
		armed.disarm("night change")


func now() -> float:
	return WorldState.sim_time


func is_recovering() -> bool:
	return now() < recover_until or (armed != null and armed.firing)


func quota() -> int:
	return QUOTA[min(night, QUOTA.size() - 1)]


func _on_event(e: Dictionary) -> void:
	var ev_int := int(e.get("data", {}).get("intensity", 1)) if e.get("data", {}) is Dictionary else 1
	tension = clamp(tension + 0.04 + 0.05 * ev_int, 0.0, 1.0)


## The player is doing something ordinary right now: leave them alone.
func player_busy() -> bool:
	var last: float = WorldState.get_state("task/last_action_time", -999.0)
	if now() - last < 20.0:
		return true
	var p = WorldState.player
	return p == null or p.is_busy() or p.get("sleeping") == true


func _process(delta: float) -> void:
	tension = max(0.0, tension - delta * 0.002)
	if not enabled or armed != null:
		return
	if GameManager.ending != "" or WorldState.get_state("scene/active", false):
		return
	_eval_t += delta
	if _eval_t < 20.0:
		return
	_eval_t = rng.randf_range(-6.0, 4.0)    # irregular evaluation rhythm
	if fired_tonight >= quota() or is_recovering() or player_busy():
		return
	if now() - night_started < 240.0:
		return
	# only when the night is building up or peaking (EventDirector pace)
	var dir = WorldState.get_obj("director")
	if dir and not dir.pace in ["build", "peak"]:
		return
	var p: float = BASE_CHANCE[min(night, BASE_CHANCE.size() - 1)] * (0.6 + tension)
	if rng.randf() > p:
		return
	try_arm()


func _eligible() -> Array:
	var out := []
	for s in scares:
		if night < s.min_night or s.id in used_tonight or s.id == last_id:
			continue
		if s.can_arm():
			out.append(s)
	return out


func try_arm(force_id := "") -> String:
	if armed:
		return "already armed: " + armed.id
	var pool := []
	if force_id != "":
		for s in scares:
			if s.id == force_id:
				pool.append(s)
	else:
		pool = _eligible()
	if pool.is_empty():
		return "nothing fits the moment"
	var total := 0.0
	for s in pool:
		total += s.weight
	var r := rng.randf() * total
	var pick: Scare = pool[0]
	for s in pool:
		r -= s.weight
		if r <= 0.0:
			pick = s
			break
	armed = pick
	pick.arm()
	WorldState.set_state("scare/armed", pick.id)
	return "armed " + pick.id


## Debug: fire a scare right now, in front of the player.
func force(scare_id: String) -> String:
	if armed:
		armed.disarm("forced other")
	for s in scares:
		if s.id == scare_id:
			armed = s
			s.armed = true
			s.fire()
			return "fired " + scare_id
	return "unknown scare " + scare_id


func on_scare_done(s: Scare, happened: bool, reason: String) -> void:
	if armed == s:
		armed = null
	WorldState.set_state("scare/armed", "")
	if happened:
		fired_tonight += 1
		used_tonight.append(s.id)
		last_id = s.id
		tension = 0.25
		# a long stretch of normality: the world needs to feel safe again
		recover_until = now() + rng.randf_range(300.0, 540.0)
		WorldState.log_event("scare_" + s.id, "fired", {"intensity": 3, "night": night})
		scare_fired.emit(s.id)
		_aftermath()
	else:
		recover_until = max(recover_until, now() + rng.randf_range(60.0, 140.0))
		WorldState.set_state("scare/last_abort", s.id + ":" + reason)


## Fear does not end when the scare ends: a slow heartbeat, then silence.
func _aftermath() -> void:
	await get_tree().create_timer(1.2, false).timeout
	for i in 6:
		AudioManager.play_flat("heartbeat", -2.0 - i * 2.0, "Horror")
		await get_tree().create_timer(0.95 + i * 0.08, false).timeout
