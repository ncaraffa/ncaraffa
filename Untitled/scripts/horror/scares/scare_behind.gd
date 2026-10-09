extends Scare
## D — BEHIND YOU. Breathing, right behind your head. If you turn around...

var spot := Vector3.ZERO
var floor_y := 0.0
var breath: AudioStreamPlayer3D


func _init() -> void:
	id = "behind"
	min_night = 4
	weight = 0.8
	timeout = 11.0


func can_arm() -> bool:
	var p = player()
	if p == null:
		return false
	if Vector2(p.velocity.x, p.velocity.z).length() > 2.0:
		return false
	return _clear_behind(p)


func _clear_behind(p) -> bool:
	var back: Vector3 = p.camera.global_transform.basis.z
	back.y = 0
	back = back.normalized()
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var from: Vector3 = p.global_position + Vector3(0, 1.2, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + back * 1.2, B.LAYER_WORLD)
	q.exclude = [p.get_rid()]
	return space.intersect_ray(q).is_empty()


func _on_arm() -> void:
	var p = player()
	var back: Vector3 = p.camera.global_transform.basis.z
	back.y = 0
	spot = p.global_position + back.normalized() * 0.75
	floor_y = p.global_position.y
	breath = AudioManager.play_3d("breath_close", spot + Vector3(0, 1.6, 0), 0.0, rng.randf_range(0.9, 1.0))


func _on_disarm() -> void:
	if is_instance_valid(breath):
		var tw := breath.create_tween()
		tw.tween_property(breath, "volume_db", -60.0, 1.5)
		tw.tween_callback(breath.queue_free)


func _watch(_d: float) -> void:
	if _armed_t < 1.2:
		return
	if Perception.view_angle(spot + Vector3(0, 1.4, 0)) < 45.0:
		firing = true
		_turn_around()


func fire() -> void:
	var p = player()
	var fwd: Vector3 = -p.camera.global_transform.basis.z
	fwd.y = 0
	spot = p.global_position + fwd.normalized() * 0.75
	floor_y = p.global_position.y
	firing = true
	_turn_around()


func _turn_around() -> void:
	if is_instance_valid(breath):
		breath.stop()
		breath.queue_free()
	var f := figure()
	if f == null:
		done(false)
		return
	var p = player()
	var at := Vector3(spot.x, floor_y, spot.z)
	f.appear(at, p.global_position - at)
	f.head_tilt = rng.randf_range(-30, 30)
	f._lean = 0.3
	AudioManager.play_3d("shriek", at + Vector3(0, 1.6, 0), -2.0)
	stinger(at + Vector3(0, 1.6, 0), 1.0)
	shake(0.08, 0.4)
	await wait(0.38)
	f.vanish("instant")
	done(true)
