extends Scare
## E — THE TELEVISION. Static. You watch it. For a moment it is not static.

var _gaze := 0.0
var _phase := 0


func _init() -> void:
	id = "tv"
	min_night = 3
	weight = 0.7


func can_arm() -> bool:
	# not every playthrough has this one
	if WorldState.get_state("scare/tv_enabled", null) == null:
		WorldState.set_state("scare/tv_enabled", rng.randf() < 0.55)
	if not WorldState.get_state("scare/tv_enabled", false):
		return false
	var tv := WorldState.get_obj("tv") as TV
	return tv != null and WorldState.player_inside and not WorldState.is_locked("tv")


func _on_arm() -> void:
	_gaze = 0.0
	_phase = 0


func _watch(delta: float) -> void:
	var tv := WorldState.get_obj("tv") as TV
	var c := tv.global_position + Vector3(0, 0.3, 0)
	var near := Perception.dist(c) < 6.0
	var looking := near and Perception.view_angle(c) < 20.0
	if _phase == 0:
		if near and Perception.view_angle(c) < 60.0:
			if not tv.power:
				tv.set_power(true, 1)
			elif tv.mode != 1:
				tv.set_mode(1)
			_phase = 1
	elif looking:
		_gaze += delta
		if _gaze > rng.randf_range(2.0, 3.5):
			firing = true
			_flash(tv)


func fire() -> void:
	var tv := WorldState.get_obj("tv") as TV
	if not tv.power:
		tv.set_power(true, 1, true)
	firing = true
	_flash(tv)


func _flash(tv: TV) -> void:
	tv.set_mode(5)
	AudioManager.play_3d("tv_scare", tv.global_position + Vector3(0, 0.3, 0), 1.0)
	shake(0.04, 0.3)
	await wait(0.45)
	if rng.randf() < 0.5:
		tv.set_power(false, 0, true)
	else:
		tv.set_mode(1)
		await wait(rng.randf_range(2.0, 4.0))
		if tv.power and tv.mode == 1:
			tv.set_power(false)
	done(true)
