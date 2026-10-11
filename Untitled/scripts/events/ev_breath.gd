extends MysteryEvent
## Low breathing close by, to one side. Nothing there. It stops when you turn.


func _init() -> void:
	id = "breath"
	title = "Breathing nearby"
	track = "side"
	intensity = 1
	min_night = 2
	max_per_night = 1
	kinds = ["temporary"]


func can_start() -> bool:
	return WorldState.player_inside


func _start() -> void:
	var p = WorldState.player
	var right: Vector3 = p.camera.global_transform.basis.x
	right.y = 0
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var at: Vector3 = p.global_position + right.normalized() * side * rng.randf_range(1.0, 1.6) + Vector3(0, 1.5, 0)
	var b := AudioManager.play_3d("breath_close", at, -9.0, rng.randf_range(0.82, 0.95))
	record("left" if side < 0 else "right")
	var t := 0.0
	while t < 6.0 and is_instance_valid(b):
		await wait(0.1)
		t += 0.1
		# looking towards it makes it stop
		if Perception.view_angle(at) < 35.0:
			b.stop()
			break
	finish()
