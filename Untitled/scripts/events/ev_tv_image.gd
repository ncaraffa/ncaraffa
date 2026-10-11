extends MysteryEvent
## For a few seconds the television shows something that is not a channel.
##   "eye"    — one enormous eye fills the screen, and it follows you
##   "behind" — the living room, seen from behind you... and someone standing
##              right behind you. Turn around: nobody. (The figure exists only
##              for the camera that feeds the TV.)
## Then static, and the set switches itself off.

const FEED_LAYER := 1 << 19

var tv: TV
var _old_mat: Material


func _init() -> void:
	id = "tv_image"
	title = "Something on the TV"
	track = "side"
	intensity = 2
	min_night = 2
	max_per_night = 1
	resources = ["tv"]
	kinds = ["temporary"]


func can_start() -> bool:
	tv = WorldState.get_obj("tv") as TV
	if tv == null:
		return false
	var d := Perception.dist(tv.global_position)
	return d > 1.5 and d < 6.5 and Perception.view_angle(tv.global_position + Vector3(0, 0.3, 0)) < 50.0


func _start() -> void:
	tv = WorldState.get_obj("tv") as TV
	var variant := "eye"
	if night() >= 3 and rng.randf() < 0.5:
		variant = "behind"
	if not tv.power:
		tv.set_power(true, 1)
		await wait(0.8)
	tv.set_mode(5)
	_old_mat = tv.screen.material_override
	record(variant)
	if variant == "eye":
		await _eye()
	else:
		await _behind()
	tv.screen.material_override = _old_mat
	tv.set_mode(1)
	await wait(rng.randf_range(0.8, 1.6))
	tv.set_power(false)
	finish()


func _eye() -> void:
	var eye := WatchingEye.new()
	tv.add_child(eye)
	eye.setup_on(tv.screen)
	AudioManager.play_3d("drone_swell", tv.global_position, 2.0)
	await wait(rng.randf_range(6.0, 9.0))
	eye.close_and_free(0.3)
	await wait(0.4)


func _behind() -> void:
	var p = WorldState.player
	var vp := SubViewport.new()
	vp.size = Vector2i(320, 240)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tv.add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.cull_mask = 0xFFFFF
	vp.add_child(cam)
	# a camera high in the corner behind the player
	var back: Vector3 = p.camera.global_transform.basis.z
	back.y = 0
	back = back.normalized()
	var from: Vector3 = p.global_position + back * 2.6 + Vector3(0, 2.1, 0)
	cam.look_at_from_position(from, p.global_position + Vector3(0, 1.0, 0) - back * 1.5, Vector3.UP)
	cam.current = true
	# the player's own eyes never see this one
	p.camera.cull_mask &= ~FEED_LAYER
	var f := ShadowFigure.new()
	tv.add_child(f)
	f.appear(p.global_position + back * 0.7, -back)
	f.set_layers(FEED_LAYER)
	f.look_target = cam
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = vp.get_texture()
	m.albedo_color = Color(0.85, 0.9, 0.85)
	tv.screen.material_override = m
	AudioManager.play_3d("tv_static", tv.global_position, -10.0, 0.7)
	var t := 0.0
	var turned := false
	while t < 7.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		# it stays exactly behind you while you watch the screen
		var b2: Vector3 = p.camera.global_transform.basis.z
		b2.y = 0
		f.global_position = p.global_position + b2.normalized() * 0.7
		f.face_dir(-b2)
		if Perception.view_angle(tv.global_position + Vector3(0, 0.3, 0)) > 70.0:
			turned = true
			break
	WorldState.set_state("tv_image/turned_around", turned)
	f.queue_free()
	vp.queue_free()
