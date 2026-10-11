extends MysteryEvent
## The light in the room you are in stutters hard, buzzing, for a few seconds.
## Sometimes it goes out completely for a moment before coming back.


func _init() -> void:
	id = "flicker"
	title = "The light in your room flickers"
	track = "side"
	intensity = 1
	min_night = 1
	max_per_night = 2
	kinds = ["temporary"]


func _nearest_on() -> LightFixture:
	var best: LightFixture = null
	var bd := 7.0
	for k in WorldState.objects.keys():
		var o = WorldState.objects[k]
		if is_instance_valid(o) and o is LightFixture and o.is_on:
			var d := Perception.dist(o.global_position)
			if d < bd:
				bd = d
				best = o
	return best


func can_start() -> bool:
	return WorldState.player_inside and _nearest_on() != null


func _start() -> void:
	var l := _nearest_on()
	if l == null:
		finish()
		return
	var buzz := AudioManager.play_3d("elec_buzz", l.global_position, 4.0)
	var blackout := rng.randf() < 0.35 and night() >= 2
	record(l.obj_id, {"blackout": blackout})
	for i in rng.randi_range(8, 14):
		for li in l.lights:
			li.light_energy = (0.0 if rng.randf() < 0.5 else 0.3) * (1.0 if not blackout else 0.0)
		await wait(rng.randf_range(0.04, 0.16))
		l.set_on(true, true)
		await wait(rng.randf_range(0.05, 0.3))
	if blackout:
		l.set_on(false, true)
		await wait(rng.randf_range(1.5, 3.0))
		l.set_on(true, true)
	l.set_on(true, true)
	if is_instance_valid(buzz):
		buzz.queue_free()
	finish()
