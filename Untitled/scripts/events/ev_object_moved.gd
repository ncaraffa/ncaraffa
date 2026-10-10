extends MysteryEvent
## Something you put down is somewhere else now. The remote on the stairs of
## the porch. A mug on the floor of the hall, upright, full of nothing.


func _init() -> void:
	id = "object_moved"
	title = "An object moved"
	track = "side"
	intensity = 1
	min_night = 1
	max_per_night = 1
	kinds = ["persistent"]


const SPOTS := [Vector3(4.9, 0.0, 6.7), Vector3(2.2, 0.0, 2.6), Vector3(13.4, 0.0, 9.6), Vector3(9.3, 0.78, 3.4),
	Vector3(5.9, 0.0, 9.9), Vector3(0.45, 0.56, 2.25)]


func _pick() -> Array:
	var items := ["remote", "mug_living", "mug_kitchen", "mug_b1"]
	items.shuffle()
	var h := house()
	var spots := SPOTS.duplicate()
	spots.shuffle()
	for id_ in items:
		var o = WorldState.get_obj(id_)
		if o == null or o.held or Perception.sees(o.global_position, 70.0) or Perception.dist(o.global_position) < 3.0:
			continue
		for s: Vector3 in spots:
			var g := h.to_global(s)
			if not Perception.sees(g, 70.0) and Perception.dist(g) > 3.0 and g.distance_to(o.global_position) > 2.0:
				return [o, g]
	return []


func can_start() -> bool:
	return not _pick().is_empty()


func _start() -> void:
	var pk := _pick()
	if pk.is_empty():
		finish()
		return
	var o: Pickup = pk[0]
	o.global_position = pk[1] + Vector3(0, 0.01, 0)
	o.rotation = Vector3(0, rng.randf() * TAU, 0)
	o.linear_velocity = Vector3.ZERO
	o.sleeping = false
	record(o.obj_id, {"to": pk[1]})
	finish()
