extends MysteryEvent
## A door you remember closed is open now — wide open, silently, while you were
## somewhere else. Sometimes the light inside is on.


func _init() -> void:
	id = "door_found_open"
	title = "A door that was closed is open"
	track = "side"
	intensity = 1
	min_night = 2
	max_per_night = 2
	kinds = ["persistent"]


const PAIRS := [["door_b2", "b2_ceiling"], ["door_closet", "closet_bulb"], ["door_laundry", "laundry_bulb"],
	["door_bath", "bath_ceiling"], ["door_b1", "b1_ceiling"]]


func _pick() -> Array:
	var opts := PAIRS.duplicate()
	opts.shuffle()
	for pr in opts:
		var d := WorldState.get_obj(pr[0]) as Door
		if d == null or d.is_open or d.locked:
			continue
		var c := d.global_transform * Vector3(d.width / 2.0, 1.1, 0)
		if Perception.dist(c) < 5.0 or Perception.sees(c, 70.0):
			continue
		return [d, pr[1]]
	return []


func can_start() -> bool:
	return not _pick().is_empty()


func _start() -> void:
	var pk := _pick()
	if pk.is_empty():
		finish()
		return
	var d: Door = pk[0]
	d.set_open(true, true, 2.0)
	var lit := rng.randf() < 0.45
	if lit:
		var l = WorldState.get_obj(pk[1])
		if l and not l.is_on:
			l.set_on(true, true)
	record(d.obj_id, {"light": lit})
	await wait(3.0)
	finish()
