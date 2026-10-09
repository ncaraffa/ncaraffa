extends MysteryEvent
## EVENT 9 — A photograph on the wall hangs crooked. Straightening it works.


func _init() -> void:
	intensity = 1
	id = "photo"
	title = "The photograph"
	resources = ["photo"]
	kinds = ["persistent", "reactive"]


func _start() -> void:
	var pid := "photo_hall" if rng.randf() < 0.75 else "photo_living"
	var p := WorldState.get_obj(pid) as PictureFrame
	if p == null:
		finish()
		return
	var ang := rng.randf_range(6.0, 11.0) * (1.0 if rng.randf() < 0.5 else -1.0)
	var slow := rng.randf() < 0.3
	p.set_tilt(ang, slow)
	record(pid, {"tilt": snappedf(ang, 0.1), "slow": slow})
	finish()
