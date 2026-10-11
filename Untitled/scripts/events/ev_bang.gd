extends MysteryEvent
## Heavy banging on a door. Not knocking. If you open it there is nobody.


func _init() -> void:
	id = "bang"
	title = "Banging"
	track = "side"
	intensity = 2
	min_night = 3
	max_per_night = 1
	resources = ["front_door"]
	kinds = ["temporary"]


func _start() -> void:
	var h := house()
	var which := "back_door_out" if rng.randf() < 0.55 else "front_door_out"
	AudioManager.play_3d("bang_door", h.gp(which), 0.0, rng.randf_range(0.9, 1.0), -1.0, -1.0, "Horror")
	record(which)
	await wait(4.0)
	finish()
