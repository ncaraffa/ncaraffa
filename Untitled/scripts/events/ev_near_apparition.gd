extends MysteryEvent
## In the corner of your eye, close — two, three metres away — a dark shape
## standing where nothing should be. Look at it and it isn't there.

var f: ShadowFigure


func _init() -> void:
	id = "near_apparition"
	title = "Something close, at the edge of sight"
	track = "side"
	intensity = 2
	min_night = 3
	max_per_night = 1
	resources = ["figure_inside"]
	kinds = ["temporary"]


func _clear(a: Vector3, b: Vector3) -> bool:
	var p = WorldState.player
	var q := PhysicsRayQueryParameters3D.create(a, b, B.LAYER_WORLD | B.LAYER_PROPS)
	q.exclude = [p.get_rid()]
	return p.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _spot() -> Vector3:
	var p = WorldState.player
	var cam: Vector3 = p.camera.global_position
	var fwd: Vector3 = -p.camera.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	for k in 10:
		var ang := deg_to_rad(rng.randf_range(42.0, 62.0)) * (1.0 if rng.randf() < 0.5 else -1.0)
		var dir := fwd.rotated(Vector3.UP, ang)
		var d := rng.randf_range(2.2, 3.4)
		var g: Vector3 = p.global_position + dir * d
		if not house().contains_point(g + Vector3(0, 1.0, 0)):
			continue
		if not _clear(cam, g + Vector3(0, 1.5, 0)) or not _clear(g + Vector3(0, 0.3, 0), g + Vector3(0, 1.8, 0)):
			continue
		return g
	return Vector3.INF


func can_start() -> bool:
	return WorldState.player_inside and _spot() != Vector3.INF


func _start() -> void:
	var g := _spot()
	f = figure()
	if f == null or g == Vector3.INF:
		finish()
		return
	f.appear(g, Perception.player_pos() - g)
	f.look_target = WorldState.player.camera
	f.head_tilt = rng.randf_range(-25.0, 25.0)
	record("near")
	var t := 0.0
	while t < 1.8:
		await get_tree().process_frame
		t += get_process_delta_time()
		if Perception.view_angle(g + Vector3(0, 1.5, 0)) < 22.0:
			AudioManager.play_3d("whoosh", g + Vector3(0, 1.3, 0), -6.0, 0.8)
			break
	f.vanish("flicker")
	await wait(0.5)
	finish()
