extends Scare
## F — THE RUNNER. You look across a room, or down the hall, and something
## crosses your view from one side to the other, absurdly fast: a black shape,
## bent forward, gone before you are sure. A rush of air, bare feet, nothing.

var _from := Vector3.ZERO
var _to := Vector3.ZERO


func _init() -> void:
	id = "runner"
	min_night = 3
	weight = 1.1
	timeout = 150.0


func can_arm() -> bool:
	return WorldState.player_inside


func _floor_at(p: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = player().get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.0, 0), p + Vector3(0, -1.5, 0), B.LAYER_WORLD)
	q.exclude = [player().get_rid()]
	var hit := space.intersect_ray(q)
	return hit.position.y if not hit.is_empty() else INF


func _clear(a: Vector3, b: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = player().get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(a, b, B.LAYER_WORLD | B.LAYER_PROPS)
	q.exclude = [player().get_rid()]
	return space.intersect_ray(q).is_empty()


func _watch(_d: float) -> void:
	if _armed_t < 2.0 or Engine.get_process_frames() % 6 != 0:
		return
	var p = player()
	var h := house()
	if not h.contains_point(p.global_position):
		return
	var fwd: Vector3 = -p.camera.global_transform.basis.z
	fwd.y = 0
	if fwd.length() < 0.5:
		return
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	for d: float in [5.5, 4.5, 6.5, 3.8]:
		var mid: Vector3 = p.global_position + fwd * d
		var fy := _floor_at(mid)
		if fy == INF or absf(fy - p.global_position.y) > 0.4 or not h.contains_point(mid + Vector3(0, 1, 0)):
			continue
		mid.y = fy
		var a := mid - right * 1.7
		var b := mid + right * 1.7
		if not _clear(a + Vector3(0, 1.0, 0), b + Vector3(0, 1.0, 0)):
			continue
		if not Perception.sees(mid + Vector3(0, 1.2, 0), 25.0):
			continue
		if not _clear(p.camera.global_position, mid + Vector3(0, 1.2, 0)):
			continue
		if rng.randf() < 0.5:
			_from = a
			_to = b
		else:
			_from = b
			_to = a
		firing = true
		_cross()
		return


func fire() -> void:
	var p = player()
	var fwd: Vector3 = -p.camera.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var mid: Vector3 = p.global_position + fwd * 4.0
	_from = mid - right * 1.7
	_to = mid + right * 1.7
	firing = true
	_cross()


func _cross() -> void:
	var f := figure()
	if f == null:
		done(false)
		return
	var mid := (_from + _to) / 2.0
	f.appear(_from, _to - _from)
	f.look_target = null
	f.set_rim(0.8)
	AudioManager.play_3d("whoosh", mid + Vector3(0, 1.3, 0), 4.0, rng.randf_range(0.9, 1.1))
	AudioManager.play_3d("run_steps", mid + Vector3(0, 0.2, 0), 2.0, 1.6)
	var tw := f.sprint(_to, 0.32)
	f.face_dir(_to - _from)
	await tw.finished
	f.vanish("instant")
	await wait(0.4)
	stinger(mid + Vector3(0, 1.5, 0), -8.0)
	done(true)
