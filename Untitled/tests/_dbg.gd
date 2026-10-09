extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.get_node("GameManager").in_game = false
	var world: Node = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 10:
		await process_frame
	var ws = root.get_node("WorldState")
	var house = ws.get_obj("house")
	var p = ws.player
	var d = ws.get_obj("door_back")
	p.global_position = house.to_global(Vector3(13.6, 0.0, -1.5))
	p.set_look(180.0, -10.0)
	await create_timer(0.5).timeout
	p._do_interact()
	await create_timer(1.5).timeout
	print("open ", d.is_open, " rot ", d.pivot.rotation_degrees, " layer ", d.body.collision_layer)
	Input.action_press("move_forward")
	for i in 20:
		await create_timer(0.1).timeout
		var lp = house.to_local(p.global_position)
		var cols := []
		for k in p.get_slide_collision_count():
			var c = p.get_slide_collision(k)
			cols.append([c.get_collider().get_parent().name if c.get_collider() else "?", c.get_normal().snapped(Vector3.ONE*0.01)])
		print(lp.snapped(Vector3.ONE*0.01), " floor=", p.is_on_floor(), " ", cols)
	Input.action_release("move_forward")
	quit()
