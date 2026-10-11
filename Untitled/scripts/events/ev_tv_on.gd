extends MysteryEvent
## The television in the living room turns itself on. Static, loud. Sometimes,
## under the static, a voice — too far to understand.


func _init() -> void:
	id = "tv_on"
	title = "The TV turns itself on"
	track = "side"
	intensity = 1
	min_night = 2
	max_per_night = 1
	resources = ["tv"]
	kinds = ["persistent"]


func can_start() -> bool:
	var tv := WorldState.get_obj("tv") as TV
	if tv == null or tv.power:
		return false
	return Perception.dist(tv.global_position) > 3.5 and Perception.dist(tv.global_position) < 18.0


func _start() -> void:
	var tv := WorldState.get_obj("tv") as TV
	tv.set_power(true, 1 if rng.randf() < 0.6 else 2)
	if rng.randf() < 0.5:
		await wait(1.5)
		AudioManager.play_3d("whisper", tv.global_position + Vector3(0, 0.3, 0), -4.0, 0.7)
	record("on")
	await wait(4.0)
	finish()
