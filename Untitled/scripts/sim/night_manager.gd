class_name NightManager
extends Node
## Consecutive nights. Night 1 starts when you press PLAY. When the essential
## chores are done you may lie down: the screen fades, the sound of the house
## falls away, a small "Night N" appears, and you wake to the next night.
## The world is never reset: what moved stays moved. A few things change while
## you sleep, and some odd instructions may (or may not) have consequences.

signal night_started(n: int)

var night := 1
var sleeping := false
var rng := RandomNumberGenerator.new()
var _pending: Array = []   # [{at: sim_time, fn}]


func _ready() -> void:
	name = "NightManager"
	rng.randomize()
	WorldState.register("night_manager", self)


func begin() -> void:
	night = 1
	WorldState.set_state("night", 1)
	_prepare_chores(1)
	var tm = WorldState.get_obj("tasks")
	tm.generate(1)
	var cult = WorldState.get_obj("cult")
	cult.setup_initial()
	_broadcast(1)


func _broadcast(n: int) -> void:
	var sd = WorldState.get_obj("scare_director")
	if sd:
		sd.new_night(n)
	var dir = WorldState.get_obj("director")
	if dir and n > 1:
		dir.new_night(n)
	elif dir:
		dir.night = n
	night_started.emit(n)


# ------------------------------------------------------------------ chores state
func _prepare_chores(n: int) -> void:
	var tm = WorldState.get_obj("tasks")
	var cult = WorldState.get_obj("cult")
	# the bin fills up again, dishes pile up, the mail comes
	WorldState.set_state("trash/full", true)
	WorldState.set_state("trash/out", false)
	WorldState.set_state("dishes/dirty", 3)
	WorldState.set_state("mail/text", cult.mail_for(n) if cult else "")
	if n == 2 or n == 4 or n >= 6:
		for w in ["win_kitchen", "win_living", "win_b2"]:
			var s = WorldState.get_obj(w)
			if s and rng.randf() < 0.75:
				s.set_open(true, true)
	if n == 2 or n == 5 or n >= 6:
		var st = WorldState.get_obj("stove_knob")
		if st:
			st.set_on(true, true)
	if n == 4 or n >= 6:
		_scatter_mugs()
	if n >= 6 and rng.randf() < 0.5:
		var g = WorldState.get_obj("garage_door")
		if g and not g.is_open:
			g.interact(null)


func _scatter_mugs() -> void:
	var h = WorldState.get_obj("house")
	var spots := [Vector3(3.2, 0.76, 4.5), Vector3(13.55, 0.425, 8.9), Vector3(15.5, 0.92, 2.9), Vector3(9.0, 0.78, 3.2), Vector3(0.4, 0.56, 2.65)]
	spots.shuffle()
	var i := 0
	for m in ["mug_b1", "mug_living", "mug_kitchen"]:
		var o = WorldState.get_obj(m)
		if o:
			o.global_position = h.to_global(spots[i])
			o.linear_velocity = Vector3.ZERO
			i += 1


# ------------------------------------------------------------------ sleep
func request_sleep() -> void:
	if sleeping:
		return
	var tm = WorldState.get_obj("tasks")
	var hud = WorldState.get_obj("hud")
	if tm and not tm.essentials_done():
		if hud:
			hud.thought("I still have things to do.")
		return
	sleep()


func sleep() -> void:
	if sleeping:
		return
	sleeping = true
	var p = WorldState.player
	var hud = WorldState.get_obj("hud")
	var envm = WorldState.get_obj("environment")
	p.sleeping = true
	if p.held:
		p.drop()
	WorldState.log_event("sleep", "night_%d_end" % night, {"intensity": 0})
	if envm:
		envm.fade_to(1.0, 2.8)
	AudioManager.fade_world(-45.0, 2.8)
	await get_tree().create_timer(3.0, false).timeout
	var pool = WorldState.get_obj("figures")
	if pool:
		pool.hide_all()
	_judge_instructions()
	night += 1
	WorldState.set_state("night", night)
	_overnight(night)
	_prepare_chores(night)
	var cult = WorldState.get_obj("cult")
	if cult:
		cult.advance(night)
	var tm = WorldState.get_obj("tasks")
	tm.generate(night)
	# the clocks start a new evening; their offsets (the kitchen clock) remain
	WorldState.clock_start_minutes = 22.0 * 60.0 + 41.0 + rng.randi_range(0, 38) - WorldState.sim_time / 60.0
	var h = WorldState.get_obj("house")
	p.global_position = h.to_global(Vector3(2.45, 0.05, 2.0))
	p.velocity = Vector3.ZERO
	p.set_look(-125.0, -8.0)
	_broadcast(night)
	if hud:
		hud.title_card("Night %d" % night)
	await get_tree().create_timer(3.2, false).timeout
	AudioManager.fade_world(0.0, 3.0)
	if envm:
		envm.fade_to(0.0, 3.0)
	await get_tree().create_timer(1.0, false).timeout
	p.sleeping = false
	sleeping = false


## Things that are different when you wake. Small, persistent, rarely explained.
func _overnight(n: int) -> void:
	var changes := []
	# one or two ambiguous changes
	var options := ["door_b2_open", "closet_ajar", "photo", "chair", "hall_light", "nothing"]
	options.shuffle()
	for c in options.slice(0, rng.randi_range(1, 2)):
		match c:
			"door_b2_open":
				var d = WorldState.get_obj("door_b2")
				if d and not d.is_open:
					d.set_open(true, true)
					changes.append(c)
			"closet_ajar":
				var d2 = WorldState.get_obj("door_closet")
				if d2 and not d2.is_open:
					d2.drift(rng.randf_range(15.0, 35.0))
					changes.append(c)
			"photo":
				var ph = WorldState.get_obj("photo_hall" if rng.randf() < 0.5 else "photo_living")
				if ph:
					ph.set_tilt(rng.randf_range(4.0, 9.0) * (1 if rng.randf() < 0.5 else -1))
					changes.append(c)
			"chair":
				var ch = WorldState.get_obj("kitchen_chair_b")
				if ch:
					ch.transform = ch.home.translated_local(Vector3(0, 0, rng.randf_range(0.2, 0.4)))
					ch.displaced = true
					ch._store()
					changes.append(c)
			"hall_light":
				var hl = WorldState.get_obj("hall_ceiling")
				if hl and not hl.is_on:
					hl.set_on(true, true)
					changes.append(c)
	# an ignored instruction from the night before, maybe
	if WorldState.get_state("tasks/back_door_left_open_n%d" % (n - 1), false) and rng.randf() < 0.5:
		var bd = WorldState.get_obj("door_back")
		if bd:
			bd.set_locked(false)
			bd.set_open(true, true)
			_footprints()
			changes.append("back_door_open_footprints")
	WorldState.set_state("overnight/n%d" % n, changes)
	WorldState.log_event("overnight", "night_%d" % n, {"changes": changes, "intensity": 1})


func _footprints() -> void:
	var h = WorldState.get_obj("house")
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.09, 0.06, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	var z := 0.3
	var i := 0
	while z < 3.6:
		var x := 13.6 + (0.1 if i % 2 == 0 else -0.1)
		B.quad(h, Vector2(0.1, 0.26), Vector3(x, 0.003, z), m, Vector3(-90, 0, 0))
		z += 0.38
		i += 1


## Odd instructions are judged when you go to bed — or never.
func _judge_instructions() -> void:
	var tm = WorldState.get_obj("tasks")
	if tm.has("back_door_shut") and WorldState.get_state("door/door_back", false):
		WorldState.set_state("tasks/back_door_left_open_n%d" % night, true)


func later(secs: float, fn: Callable) -> void:
	_pending.append({"at": WorldState.sim_time + secs, "fn": fn})


func _process(_delta: float) -> void:
	for i in range(_pending.size() - 1, -1, -1):
		if WorldState.sim_time >= _pending[i].at:
			var fn: Callable = _pending[i].fn
			_pending.remove_at(i)
			if fn.is_valid():
				fn.call()
	_watch_instructions()


var _hall_done_seen := -1
var _six_seen := -1
var _kw_seen := -1


func _watch_instructions() -> void:
	# "Turn off the hallway light." Sometimes, later, it is on again.
	if WorldState.get_state("task/hall_light", false) and _hall_done_seen != night:
		_hall_done_seen = night
		if rng.randf() < 0.35:
			later(rng.randf_range(120.0, 300.0), func():
				var hl = WorldState.get_obj("hall_ceiling")
				if hl and not hl.is_on and Perception.dist(hl.global_position) > 4.0:
					hl.set_on(true, true)
					AudioManager.play_3d("switch_click", WorldState.get_obj("sw_hall").global_position, 2.0)
					WorldState.log_event("instruction", "hall_light_back_on", {"intensity": 1}))
	# "Don't look at house number 6."
	if WorldState.get_state("tasks/looked_at_6_n%d" % night, false) and _six_seen != night:
		_six_seen = night
		if rng.randf() < 0.5:
			later(rng.randf_range(60.0, 180.0), func():
				var six = WorldState.get_obj("neighbor_leland")
				if six:
					for k in six.window_count():
						six.set_window(k, true)
					six.show_silhouette(0, 15.0)
					WorldState.log_event("instruction", "house_6_lit", {"intensity": 2}))
	# "Check the kitchen window." Usually nothing is there.
	if WorldState.get_state("task/look_kitchen_window", false) and _kw_seen != night:
		_kw_seen = night
		var sd = WorldState.get_obj("scare_director")
		if sd and night >= 3 and rng.randf() < 0.3 and not sd.is_recovering() and sd.fired_tonight < sd.quota():
			sd.try_arm("window")
