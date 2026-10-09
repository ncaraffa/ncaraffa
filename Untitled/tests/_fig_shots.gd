extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _shot(n: String) -> void:
	for i in 8:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/" + n + ".png")
func _run() -> void:
	root.get_node("GameManager").in_game = false
	var world: Node = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 10:
		await process_frame
	var ws = root.get_node("WorldState")
	world.get_node("EnvironmentManager")._fade = 0.0
	world.get_node("EnvironmentManager")._fade_target = 0.0
	world.get_node("EnvironmentManager").post_mat.set_shader_parameter("fade", 0.0)
	ws.get_obj("director").time_scale = 0.0
	ws.get_obj("scare_director").enabled = false
	var p = ws.player
	var h = ws.get_obj("house")
	var pool = ws.get_obj("figures")
	# 1 hallway figure, hall light on, from the foyer end
	var f = pool.borrow()
	f.appear(h.to_global(Vector3(4.9, 0, 4.0)), Vector3(0, 0, 1))
	p.global_position = h.to_global(Vector3(4.9, 0.02, 8.6))
	p.set_look(0.0, -2.0)
	await _shot("fig_hall")
	# 2 same, hall dark
	ws.get_obj("hall_ceiling").set_on(false, true)
	await _shot("fig_hall_dark")
	ws.get_obj("hall_ceiling").set_on(true, true)
	f.vanish()
	# 3 close-up scare pose
	f = pool.borrow()
	f.appear(h.to_global(Vector3(10.6, 0, 8.0)), Vector3(-1, 0, 0))
	f.lunge(h.to_global(Vector3(10.2, 0, 8.0)), 0.01)
	f.head_tilt = 22.0
	p.global_position = h.to_global(Vector3(8.8, 0.02, 8.0))
	p.set_look(-90.0, 4.0)
	await _shot("fig_close")
	f.vanish()
	# 4 at the kitchen window, outside
	f = pool.borrow()
	f.appear(h.to_global(Vector3(12.0, -0.3, -0.45)), Vector3(0, 0, 1))
	f._arm_raise = 0.85
	f._lean = 0.22
	p.global_position = h.to_global(Vector3(12.0, 0.02, 1.6))
	p.set_look(0.0, 3.0)
	await _shot("fig_window")
	f.vanish()
	# 5 across the street, seen from the porch
	f = pool.borrow()
	f.appear(Vector3(7.6, 0.08, 13.4), Vector3(0, 0, -1))
	f.set_rim(0.9)
	p.global_position = h.to_global(Vector3(5.9, 0.02, 12.4))
	p.set_look(rad_to_deg(atan2(-(7.6 - p.global_position.x), -(13.4 - p.global_position.z))), -2.0)
	await _shot("fig_street")
	f.vanish()
	# 6 back fence from the patio
	f = pool.borrow()
	f.appear(Vector3(2.0, 0.0, -51.2), Vector3(0, 0, 1))
	f.set_rim(0.9)
	p.global_position = h.to_global(Vector3(13.6, 0.02, -1.5))
	p.set_look(0.0, 0.0)
	await _shot("fig_fence")
	f.vanish()
	# 7 kitchen chores (stove on, dishes) and 8 a door frame
	ws.get_obj("stove_knob").set_on(true, true)
	p.global_position = h.to_global(Vector3(13.0, 0.02, 2.4))
	p.set_look(-60.0, -25.0)
	await _shot("kitchen_chores")
	p.global_position = h.to_global(Vector3(4.9, 0.02, 6.8))
	p.set_look(90.0, -6.0)
	await _shot("door_frames")
	quit()
