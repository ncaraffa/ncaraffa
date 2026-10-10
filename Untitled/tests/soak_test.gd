extends SceneTree
## Soak test: advance to night 5, accelerate both directors and let the player
## wander inside and outside for a long time. Any script error fails the run
## (check the log); the summary lists what happened.
##   godot --headless --path . -s tests/soak_test.gd
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.get_node("GameManager").in_game = false
	var world: Node = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await create_timer(0.5).timeout
	var WS = root.get_node("WorldState")
	var p = WS.player
	var h = WS.get_obj("house")
	var tm = WS.get_obj("tasks")
	var nm = WS.get_obj("night_manager")
	var dir = WS.get_obj("director")
	var sd = WS.get_obj("scare_director")
	for n in 4:
		tm.debug_complete()
		await create_timer(1.0).timeout
		nm.sleep()
		await create_timer(9.0).timeout
		if nm.interrupted:
			nm.request_sleep()
			await create_timer(9.0).timeout
	print("night ", WS.get_state("night"))
	Engine.time_scale = 4.0
	dir.time_scale = 12.0
	var spots := [Vector3(4.9, 0.05, 7.0), Vector3(12.0, 0.05, 2.0), Vector3(10.0, 0.05, 8.5), Vector3(2.4, 0.05, 2.0), Vector3(13.6, 0.05, -2.0)]
	var t := 0.0
	var k := 0
	while t < 240.0:
		# wander: teleport between rooms and the street, turn around, walk a bit
		if k % 3 == 2:
			p.global_position = Vector3(randf_range(-10, 10), 0.2, randf_range(-14, 30))
		else:
			p.global_position = h.to_global(spots[randi() % spots.size()])
		p.set_look(randf_range(-180, 180), randf_range(-10, 5))
		Input.action_press("move_forward")
		await create_timer(1.0).timeout
		Input.action_release("move_forward")
		# give scares a chance: end recovery sometimes and arm
		sd.recover_until = min(sd.recover_until, WS.sim_time + 20.0)
		if randf() < 0.3 and sd.armed == null:
			sd.fired_tonight = 0
			sd.try_arm()
		await create_timer(1.5).timeout
		t += 2.5 * Engine.time_scale
		if k % 4 == 0:
			print("t=%d clock=%.0f next=%.0f side=%.0f fired=%s locks=%s running=%s" % [t, dir.clock, dir.next_at, dir.side_next_at, dir.fired.keys(), WS.locks.keys(), dir.events.filter(func(e): return e.running).map(func(e): return e.id)])
		k += 1
	Engine.time_scale = 1.0
	var counts := {}
	for e in WS.event_log:
		counts[e.id] = int(counts.get(e.id, 0)) + 1
	print("events: ", counts)
	print("warnings: ", WS.warnings)
	print("SOAK DONE")
	quit()
