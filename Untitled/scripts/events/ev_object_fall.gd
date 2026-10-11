extends MysteryEvent
## Something falls over in another room. It was probably just balanced badly.


func _init() -> void:
	id = "object_fall"
	title = "Something falls"
	track = "side"
	intensity = 1
	min_night = 2
	max_per_night = 1
	kinds = ["persistent"]


func _start() -> void:
	var items := ["mug_living", "mug_kitchen", "mug_b1", "can_kitchen", "remote"]
	items.shuffle()
	for it in items:
		var o := WorldState.get_obj(it) as Pickup
		if o == null or o.held:
			continue
		if Perception.dist(o.global_position) < 3.0 or Perception.sees(o.global_position, 60.0):
			continue
		o.sleeping = false
		o.apply_central_impulse(Vector3(rng.randf_range(-0.6, 0.6), 0.6, rng.randf_range(-0.6, 0.6)) * o.mass)
		AudioManager.play_3d("object_fall", o.global_position, -2.0)
		record(it)
		break
	finish()
