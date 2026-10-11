class_name TaskManager
extends Node
## Tonight's chores. Each task is verified against the real state of the world
## (the bag is in the bin, the burner is off, the deadbolt is turned...): there
## are no progress bars and nothing is completed by pressing a button.
##
## Some nights also carry odd instructions. They are written on the same list,
## sometimes in a different hand, sometimes added while you were not looking.
## Some mean something. Some don't.

signal list_changed

const LIGHTS_DOWNSTAIRS := ["living_ceiling", "living_floorlamp", "living_lamp", "kitchen_ceiling", "dining_chandelier", "foyer_ceiling", "garage_tube"]
const SINK := AABB(Vector3(11.55, 0.6, 0.1), Vector3(0.95, 0.5, 0.7))

var tasks: Array = []   # [{id, text, essential, strange, hand, done}]
var night := 1
var rng := RandomNumberGenerator.new()
var _poll := 0.0
var _gaze: Dictionary = {}
var _late_added := false
var _late_at := 0.0


func _ready() -> void:
	name = "TaskManager"
	rng.randomize()
	WorldState.register("tasks", self)


# ------------------------------------------------------------------ catalogue
func _t(id: String, text: String, essential := true, strange := false, hand := 0) -> Dictionary:
	return {"id": id, "text": text, "essential": essential, "strange": strange, "hand": hand, "done": false}


func generate(n: int) -> void:
	night = n
	tasks.clear()
	_gaze.clear()
	_late_added = false
	_late_at = WorldState.sim_time + rng.randf_range(300.0, 600.0)
	match n:
		1:
			tasks = [_t("trash", "Take out the trash"), _t("dishes", "Wash the dishes"), _t("mail", "Check the mailbox"),
				_t("lights", "Lights off downstairs before bed")]
		2:
			tasks = [_t("windows", "Close the windows"), _t("stove", "Check the stove"), _t("mail", "Check the mailbox"),
				_t("lock_back", "Lock the back door"), _t("lights", "Lights off downstairs before bed")]
		3:
			tasks = [_t("trash", "Take out the trash"), _t("dishes", "Wash the dishes"), _t("lock_front", "Lock the front door"),
				_t("mail", "Check the mailbox"), _t("lights", "Lights off downstairs before bed"),
				_t("look_kitchen_window", "Check the kitchen window", false, true)]
		4:
			tasks = [_t("mail", "Check the mailbox"), _t("mugs", "Put the mugs in the kitchen sink"), _t("windows", "Close the windows"),
				_t("lights", "Lights off downstairs before bed"),
				_t("back_door_shut", "Don't leave the back door open", false, true),
				_t("hall_light", "Turn off the hallway light", false, true)]
		_:
			# the fifth night is the last one. "Make sure you're alone." has no
			# way to be ticked off, and it never stops you from going to bed.
			# (no "lights" tonight: there is no power in the house)
			tasks = [_t("trash", "Take out the trash"), _t("stove", "Check the stove"), _t("lock_back", "Lock the back door"),
				_t("lock_front", "Lock the front door"), _t("mail", "Check the mailbox"),
				_t("no_look_6", "Don't look at house number 6", false, true),
				_t("alone", "Make sure you're alone.", false, true)]
	WorldState.set_state("tasks/night", n)
	list_changed.emit()


## Lines that appear on the list during the night, in somebody else's hand.
func _add_late_line() -> void:
	_late_added = true
	var lines := []
	match night:
		4:
			lines = [_t("no_look_6", "don't look at number 6", false, true, 1)]
		5:
			lines = [_t("no_phone", "don't answer the phone", false, true, 1)]
	for l in lines:
		var exists := false
		for t in tasks:
			if t.id == l.id:
				exists = true
		if not exists:
			tasks.append(l)
			WorldState.log_event("task_list", "line_added", {"text": l.text, "intensity": 1})
	list_changed.emit()


# ------------------------------------------------------------------ checks
func _check(t: Dictionary) -> bool:
	match t.id:
		"trash":
			return WorldState.get_state("trash/out", false) == true
		"dishes":
			return int(WorldState.get_state("dishes/dirty", 0)) == 0
		"mail":
			return WorldState.get_state("mail/collected_n%d" % night, false) == true
		"lights":
			for l in LIGHTS_DOWNSTAIRS:
				if WorldState.get_state("light/" + l, false):
					return false
			return true
		"windows":
			for w in ["win_kitchen", "win_living", "win_b2"]:
				if WorldState.get_state("window/" + w + "/open", false):
					return false
			return true
		"stove":
			return WorldState.get_state("stove/on", false) == false
		"lock_back":
			return WorldState.get_state("lock/door_back", false) == true
		"lock_front":
			return WorldState.get_state("lock/door_front", false) == true
		"garage":
			return WorldState.get_state("door/garage_door", false) == false
		"mugs":
			var h = WorldState.get_obj("house")
			for m in ["mug_b1", "mug_living", "mug_kitchen"]:
				var o = WorldState.get_obj(m)
				if o == null or not SINK.has_point(h.to_local(o.global_position)):
					return false
			return true
		"hall_light":
			return WorldState.get_state("light/hall_ceiling", false) == false
		"look_kitchen_window":
			return float(_gaze.get("kitchen_window", 0.0)) > 1.0
	return false   # passive instructions never tick off


func _process(delta: float) -> void:
	_poll -= delta
	_track_gazes(delta)
	if not _late_added and night >= 4 and WorldState.sim_time > _late_at:
		_add_late_line()
	if _poll > 0.0:
		return
	_poll = 0.5
	var changed := false
	for t in tasks:
		var now_done := _check(t)
		if now_done != t.done:
			# chores stay done once done (except the lights, which you can undo)
			if t.done and t.id != "lights" and t.id != "hall_light":
				continue
			t.done = now_done
			changed = true
			WorldState.set_state("task/" + t.id, now_done)
			if now_done:
				WorldState.log_interaction("task_done", t.id)
	if changed:
		list_changed.emit()


func _track_gazes(delta: float) -> void:
	var h = WorldState.get_obj("house")
	if h == null or WorldState.player == null:
		return
	var kw: Vector3 = h.to_global(Vector3(12.0, 1.55, 0.0))
	if Perception.dist(kw) < 2.6 and Perception.view_angle(kw) < 20.0:
		_gaze["kitchen_window"] = float(_gaze.get("kitchen_window", 0.0)) + delta
	var six = WorldState.get_obj("neighbor_leland")
	if six:
		var c: Vector3 = six.global_position + Vector3(0, 2.0, 0) - six.global_basis.z * 4.0
		if Perception.view_angle(c) < 12.0 and Perception.sees(c, 12.0, 90.0):
			_gaze["six"] = float(_gaze.get("six", 0.0)) + delta
			if _gaze["six"] > 2.0 and not WorldState.get_state("tasks/looked_at_6_n%d" % night, false):
				WorldState.set_state("tasks/looked_at_6_n%d" % night, true)
				WorldState.log_interaction("looked", "house_6")


func essentials_done() -> bool:
	for t in tasks:
		if t.essential and not t.done:
			return false
	return true


func has(task_id: String) -> bool:
	for t in tasks:
		if t.id == task_id:
			return true
	return false


func list_bbcode() -> String:
	var lines := PackedStringArray()
	lines.append("[font_size=26]tonight[/font_size]\n")
	for t in tasks:
		var text: String = t.text
		if t.hand == 1:
			lines.append("[color=#3a3330][i]   %s[/i][/color]" % text)
		elif t.done:
			lines.append("[color=#2a3a7a][s]- %s[/s][/color]" % text)
		else:
			lines.append("[color=#2a3a7a]- %s[/color]" % text)
	return "\n".join(lines)


## Debug: finish every essential chore by setting the world state it checks.
func debug_complete() -> void:
	WorldState.set_state("trash/out", true)
	WorldState.set_state("dishes/dirty", 0)
	WorldState.set_state("mail/collected_n%d" % night, true)
	for l in LIGHTS_DOWNSTAIRS:
		var f = WorldState.get_obj(l)
		if f:
			f.set_on(false, true)
	for w in ["win_kitchen", "win_living", "win_b2"]:
		var s = WorldState.get_obj(w)
		if s:
			s.set_open(false, true)
	var st = WorldState.get_obj("stove_knob")
	if st:
		st.set_on(false, true)
	for d in ["door_back", "door_front"]:
		var door = WorldState.get_obj(d)
		if door:
			door.set_open(false, true)
			door.set_locked(true)
	var g = WorldState.get_obj("garage_door")
	if g and g.is_open:
		g.interact(null)
	var h = WorldState.get_obj("house")
	for m in ["mug_b1", "mug_living", "mug_kitchen"]:
		var o = WorldState.get_obj(m)
		if o:
			o.global_position = h.to_global(Vector3(12.0 + randf_range(-0.2, 0.2), 0.8, 0.42))
			o.sleeping = false
