class_name HallScene
extends Node
## NIGHT 4 — THE SILHOUETTE THAT GOES INTO YOUR ROOM.
##
## When tonight's chores are done and you are away from the bedrooms, a black
## figure is standing in the hallway, between the two bedroom doors, facing the
## way you will come. No music. No scare. The house sounds like the house.
## It looks at you. It lets you come closer. After a while it turns and walks,
## slowly, into YOUR bedroom. Follow it and the room is empty: the bed, the
## desk, the lamp. On the pillow there is a small piece of paper:
##     "Don't wake him up."
## Nobody says who "him" is. The paper is gone the next night.
##
## The scene is not optional: if you try to sleep before it happened, something
## downstairs (the television, by itself) keeps you up until you go and look.
## The camera is never forced; a player who does not look may miss half of it.

enum S { WAITING, PLACED, SEEN, WALKING, INSIDE, DONE }

const NIGHT := 4
const STAND := Vector3(4.88, 0.0, 5.05)        # hall, between the bedroom doors
const WALK := [Vector3(4.86, 0, 4.45), Vector3(4.4, 0, 4.22), Vector3(3.7, 0, 4.12), Vector3(3.0, 0, 3.95), Vector3(2.45, 0, 3.7)]
const NOTE_AT := Vector3(0.47, 0.715, 3.8)     # on the pillow by the door side (bedroom 1)
const NOTE_TEXT := "Don't wake him up."

var state := S.WAITING
var f: ShadowFigure
var note: Readable
var rng := RandomNumberGenerator.new()
var _t := 0.0
var _seen_t := 0.0
var _lure_count := 0
var _hold := 5.0


func _ready() -> void:
	name = "HallScene"
	rng.randomize()
	WorldState.register("hall_scene", self)


func _house() -> House:
	return WorldState.get_obj("house") as House


func _night() -> int:
	return int(WorldState.get_state("night", 1))


func _local_player() -> Vector3:
	var h := _house()
	var p = WorldState.player
	if h == null or p == null:
		return Vector3(99, 0, 99)
	return h.to_local(p.global_position)


## The bedroom wing: both bedrooms, the hallway, the bathroom, laundry, closet.
func player_in_wing() -> bool:
	var lp := _local_player()
	if not _house().contains_point(WorldState.player.global_position):
		return false
	if lp.x < 4.2:
		return true
	return lp.x < 7.6 and lp.z < 8.2


func is_active() -> bool:
	return state in [S.PLACED, S.SEEN, S.WALKING, S.INSIDE]


func done() -> bool:
	return state == S.DONE or WorldState.get_state("scene/hall_done", false)


## Asked by the NightManager before sleeping. True = not now.
func blocks_sleep() -> bool:
	if _night() != NIGHT or done():
		return false
	if is_active():
		return true
	# something downstairs won't let you sleep
	var tv = WorldState.get_obj("tv")
	var hud = WorldState.get_obj("hud")
	_lure_count += 1
	if tv and not tv.power:
		tv.set_power(true, 1)
		WorldState.log_event("hall_scene", "tv_lure", {"intensity": 1})
	if hud:
		hud.thought("...the TV?" if _lure_count == 1 else "I can hear the TV downstairs.")
	return true


func _process(delta: float) -> void:
	if GameManager.ending != "" or WorldState.player == null or _house() == null:
		return
	if _night() != NIGHT or done():
		return
	_t += delta
	match state:
		S.WAITING:
			_try_place()
		S.PLACED:
			if Perception.sees_figure(f) and Perception.dist(f.global_position) < 9.0:
				state = S.SEEN
				_seen_t = 0.0
				_hold = rng.randf_range(4.5, 7.0)
				WorldState.set_state("scene/active", true)
				WorldState.log_event("hall_scene", "seen", {"intensity": 2})
			elif _t > 150.0 and WorldState.get_state("scene/active", false):
				# never noticed: it keeps waiting there, but the rest of the night goes on
				WorldState.set_state("scene/active", false)
		S.SEEN:
			_seen_t += delta
			# it doesn't react to you coming closer, at first
			var close := Perception.dist(f.global_position) < 1.6
			if _seen_t > _hold or (close and _seen_t > 2.0):
				_start_walk()
		S.WALKING:
			var lp := _house().to_local(f.global_position)
			if lp.x < 3.95 and not Perception.sees_figure(f):
				_gone()


func _try_place() -> void:
	var tm = WorldState.get_obj("tasks")
	if tm == null or not tm.essentials_done():
		return
	if player_in_wing() or WorldState.is_locked("figure_inside"):
		return
	var h := _house()
	var spot := h.to_global(STAND)
	if Perception.sees(spot + Vector3(0, 1.4, 0), 70.0) or Perception.dist(spot) < 4.0:
		return
	var pool = WorldState.get_obj("figures")
	if pool == null:
		return
	f = pool.borrow()
	if f == null:
		return
	var sd = WorldState.get_obj("scare_director")
	if sd:
		if sd.armed:
			sd.armed.disarm("hall scene")
		sd.recover_until = maxf(sd.recover_until, WorldState.sim_time + 400.0)
	# the bedroom door stands open, the bedside lamp is on: it is a shape against that light
	var d = WorldState.get_obj("door_b1")
	if d and not d.is_open:
		d.set_open(true, true, 50.0)
	var lamp = WorldState.get_obj("b1_lamp")
	if lamp and not lamp.is_on:
		lamp.set_on(true, true)
	# no other apparition indoors while it is there
	WorldState.try_lock("figure_inside", "hall_scene")
	f.appear(spot, h.global_basis * Vector3(0, 0, 1))
	f.look_target = WorldState.player.camera
	f.set_rim(0.9)
	f.head_tilt = 6.0
	state = S.PLACED
	_t = 0.0
	WorldState.set_state("scene/active", true)
	WorldState.log_event("hall_scene", "placed", {"intensity": 2})


func _start_walk() -> void:
	var h := _house()
	state = S.WALKING
	f.stiff = true
	f.look_target = null
	var pts := PackedVector3Array()
	for w: Vector3 in WALK:
		pts.append(h.to_global(w))
	f.walk_path(pts, 0.55)
	f.finished_path.connect(_arrived, CONNECT_ONE_SHOT)
	# its feet on the floorboards, barely
	_steps()
	WorldState.log_event("hall_scene", "walks_in", {"intensity": 2})


func _steps() -> void:
	while state == S.WALKING and f and f.is_visible_figure():
		AudioManager.play_3d("step_wood_%d" % rng.randi_range(0, 3), f.global_position + Vector3(0, 0.1, 0), -6.0, 0.85)
		await get_tree().create_timer(1.05, false).timeout


## It reached the middle of the room and you are still watching: the lamp dies
## for a moment, and when it comes back there is nobody.
func _arrived() -> void:
	if state != S.WALKING:
		return
	state = S.INSIDE
	var lamp = WorldState.get_obj("b1_lamp")
	if lamp and lamp.is_on:
		lamp.set_on(false, true)
		AudioManager.play_3d("elec_buzz", lamp.global_position, -6.0)
		await get_tree().create_timer(0.9, false).timeout
		_gone()
		await get_tree().create_timer(0.5, false).timeout
		lamp.set_on(true, true)
	else:
		_gone()


func _gone() -> void:
	if state == S.DONE:
		return
	if f and f.is_visible_figure():
		f.vanish("instant")
	state = S.DONE
	if WorldState.locks.get("figure_inside") == "hall_scene":
		WorldState.unlock("figure_inside", "hall_scene")
	WorldState.set_state("scene/active", false)
	WorldState.set_state("scene/hall_done", true)
	_leave_note()
	WorldState.log_event("hall_scene", "gone", {"intensity": 2})


func _leave_note() -> void:
	var h := _house()
	note = Readable.new()
	note.name = "PillowNote"
	h.add_child(note)
	note.position = NOTE_AT
	note.rotation_degrees = Vector3(0, 76, -10)
	note.setup("pillow_note", NOTE_TEXT, Vector2(0.13, 0.1))
	# a temporary thing: gone by tomorrow night
	var cult = WorldState.get_obj("cult")
	if cult:
		cult.add_temp(note, "night")


## Debug: run the scene now (puts the player in the foyer, chores done).
func debug_force() -> void:
	var tm = WorldState.get_obj("tasks")
	if tm:
		tm.debug_complete()
	WorldState.set_state("night", NIGHT)
	var p = WorldState.player
	var h := _house()
	p.global_position = h.to_global(Vector3(6.6, 0.05, 10.2))
	p.set_look(90.0, -4.0)
	state = S.WAITING
	WorldState.set_state("scene/hall_done", false)
