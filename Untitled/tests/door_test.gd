extends SceneTree
## Walks through every exterior door, both directions, several times, using the
## real interaction ray (look at the door + E) and real movement input.
##   godot --headless --path . -s tests/door_test.gd
var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _walk(p, secs: float) -> void:
	Input.action_press("move_forward")
	await create_timer(secs).timeout
	Input.action_release("move_forward")
	await create_timer(0.2).timeout


func _use(p, door, want_open: bool) -> bool:
	await create_timer(0.25).timeout
	if p.looked_at != door:
		print("    ray does not hit ", door.obj_id, " (hit: ", p.looked_at, ")")
		return false
	p._do_interact()
	await create_timer(1.3).timeout
	return door.is_open == want_open


## inside/outside: local positions; yaw_out = facing when going out.
func _cycle(ws, house, door_id: String, inside: Vector3, outside: Vector3, yaw_out: float, rounds := 3) -> void:
	var p = ws.player
	var door = ws.get_obj(door_id)
	if door.is_open:
		door.set_open(false, true)
		await create_timer(1.2).timeout
	p.global_position = house.to_global(inside)
	p.velocity = Vector3.ZERO
	for r in rounds:
		# inside -> outside
		p.set_look(yaw_out, -10.0)
		var ok1: bool = await _use(p, door, true)
		await _walk(p, 1.7)
		var lo: Vector3 = house.to_local(p.global_position)
		var out_ok: bool = lo.distance_to(outside) < 1.3
		# close from outside, open again from outside, walk back in
		p.set_look(yaw_out + 180.0, -10.0)
		var ok2: bool = await _use(p, door, false)
		var ok3: bool = await _use(p, door, true)
		await _walk(p, 1.7)
		var li: Vector3 = house.to_local(p.global_position)
		var in_ok: bool = li.distance_to(inside) < 1.3
		p.set_look(yaw_out + 180.0, -10.0)
		var good := ok1 and out_ok and ok2 and ok3 and in_ok
		print("  %s round %d: open-in %s | out %s %s | close-out %s | open-out %s | back in %s %s  -> %s" % [door_id, r, ok1, out_ok, lo.snapped(Vector3.ONE * 0.01), ok2, ok3, in_ok, li.snapped(Vector3.ONE * 0.01), "PASS" if good else "FAIL"])
		if not good:
			fails += 1
		p.set_look(yaw_out + 180.0)
		# turn round to face out again for the next round
		p.global_position = house.to_global(inside)
		await create_timer(0.2).timeout
		if door.is_open:
			door.set_open(false, true)
			await create_timer(1.2).timeout


func _run() -> void:
	root.get_node("GameManager").in_game = false
	var world: Node = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 10:
		await process_frame
	var ws = root.get_node("WorldState")
	var house = ws.get_obj("house")
	ws.get_obj("director").time_scale = 0.0
	print("[back door]")
	await _cycle(ws, house, "door_back", Vector3(13.6, 0.0, 1.5), Vector3(13.6, 0.0, -1.5), 0.0)
	print("[front door]")
	await _cycle(ws, house, "door_front", Vector3(5.9, 0.0, 9.6), Vector3(5.9, 0.0, 12.4), 180.0)
	print("[kitchen <-> garage door]")
	await _cycle(ws, house, "door_garage", Vector3(14.6, 0.0, 4.8), Vector3(17.6, -0.3, 4.8), -90.0)
	print("[lock]")
	var d = ws.get_obj("door_back")
	d.set_open(false, true)
	await create_timer(1.2).timeout
	d.set_locked(true)
	var p = ws.player
	p.global_position = house.to_global(Vector3(13.6, 0.0, -1.3))
	p.set_look(180.0, -10.0)
	await create_timer(0.3).timeout
	p._do_interact()
	await create_timer(0.5).timeout
	var stays: bool = not d.is_open
	p.global_position = house.to_global(Vector3(13.6, 0.0, 1.3))
	p.set_look(0.0, -10.0)
	await create_timer(0.3).timeout
	print("    inside prompt: ", p.looked_at.get_prompt() if p.looked_at else "-")
	p._do_interact()
	await create_timer(0.3).timeout
	p._do_interact()
	await create_timer(1.3).timeout
	var lock_ok: bool = stays and d.is_open and not d.locked
	print("  locked from outside stays shut, inside unlocks + opens: ", "PASS" if lock_ok else "FAIL")
	if not lock_ok:
		fails += 1
	print("DOOR TEST ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)
