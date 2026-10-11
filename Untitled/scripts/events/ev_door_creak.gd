extends MysteryEvent
## A closed door somewhere you can see, or almost see, slowly swings open by
## itself with a long creak. Old houses do that. Probably.


func _init() -> void:
	id = "door_creak"
	title = "A door opens by itself"
	track = "side"
	intensity = 1
	min_night = 1
	max_per_night = 2
	kinds = ["persistent"]


func _pick() -> Door:
	var ids := ["door_b2", "door_closet", "door_laundry", "door_bath", "door_b1", "door_garage"]
	ids.shuffle()
	var best: Door = null
	for did in ids:
		var d := WorldState.get_obj(did) as Door
		if d == null or d.is_open:
			continue
		var c := d.global_transform * Vector3(d.width / 2.0, 1.1, 0)
		var dist := Perception.dist(c)
		if dist < 1.8 or dist > 14.0:
			continue
		# prefer one the player is looking at
		if Perception.sees(c, 50.0):
			return d
		if best == null:
			best = d
	return best


func can_start() -> bool:
	return WorldState.player_inside and _pick() != null


func _start() -> void:
	var d := _pick()
	if d == null:
		finish()
		return
	var mid := d.global_transform * Vector3(d.width / 2.0, 1.1, 0)
	AudioManager.play_3d("door_creak", mid, 6.0, rng.randf_range(0.75, 0.9))
	d.drift(rng.randf_range(35.0, 70.0))
	record(d.obj_id, {"seen": Perception.sees(mid, 50.0)})
	await wait(3.0)
	finish()
