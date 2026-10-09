extends SceneTree
## Headless integration test.
##   godot --headless --path . -s tests/run_tests.gd
## Builds the world, walks the player, uses doors/switches/phone/computer,
## then runs the EventDirector at high speed until every event has fired and
## checks persistence, independence from the player, and the PRESS ENTER puzzle.

var failures := 0
var checks := 0
var world: Node


func ok(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  PASS  ", what)
	else:
		failures += 1
		print("  FAIL  ", what)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func seconds(s: float) -> void:
	await create_timer(s).timeout


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	var GM = root.get_node("GameManager")
	var WS = root.get_node("WorldState")
	GM.in_game = false
	world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(5)
	print("world built in %d ms, nodes: %d" % [Time.get_ticks_msec() - t0, _count(world)])

	print("[registry]")
	for id in ["house", "neighborhood", "phone", "tv", "computer", "clock_kitchen", "clock_bedroom", "clock_living",
			"kitchen_chair_a", "kitchen_chair_b", "photo_hall", "photo_living", "door_front", "door_b1", "fridge_letter",
			"hud", "director", "garage_door", "b1_lamp", "hall_ceiling"]:
		ok(WS.get_obj(id) != null, "object '%s' registered" % id)
	var nb = WS.get_obj("neighborhood")
	ok(nb.houses.size() == 8, "8 neighbour houses (got %d)" % nb.houses.size())
	ok(WS.warnings.is_empty(), "no build warnings " + str(WS.warnings))

	print("[player]")
	var p = WS.player
	var house = WS.get_obj("house")
	await frames(30)
	ok(p.is_on_floor(), "player stands on the bedroom floor")
	ok(WS.player_inside, "player starts inside the house")
	ok(absf(p.global_position.y - house.to_global(Vector3.ZERO).y) < 0.1, "player at floor height (y=%.2f)" % p.global_position.y)
	# walk forward for a second
	var start: Vector3 = p.global_position
	Input.action_press("move_forward")
	await seconds(1.0)
	Input.action_release("move_forward")
	ok(p.global_position.distance_to(start) > 0.5, "WASD moves the player (%.2f m)" % p.global_position.distance_to(start))

	# step up onto the porch / into the house from the lawn
	p.global_position = house.to_global(Vector3(5.9, -0.3, 14.0))
	p.set_look(0.0)   # face -Z (towards the house front door)
	WS.get_obj("door_front").set_open(true, true)
	await frames(10)
	Input.action_press("move_forward")
	await seconds(3.5)
	Input.action_release("move_forward")
	var lp: Vector3 = house.to_local(p.global_position)
	ok(lp.z < 10.8 and lp.y > -0.05, "climbs porch step and enters through the front door (local %s)" % str(lp.snapped(Vector3.ONE * 0.01)))
	ok(WS.player_inside, "inside flag after entering")

	# walk out to the street through the open front door
	p.global_position = house.to_global(Vector3(5.9, 0.05, 10.0))
	p.set_look(180.0)
	await frames(5)
	Input.action_press("move_forward")
	Input.action_press("run")
	await seconds(4.0)
	Input.action_release("run")
	Input.action_release("move_forward")
	ok(not WS.player_inside, "player can leave the house (pos %s)" % str(p.global_position.snapped(Vector3.ONE * 0.1)))
	ok(p.global_position.z > -24.0, "player reached the front yard / street")

	print("[interactions]")
	var door = WS.get_obj("door_b1")
	door.interact(p)
	await seconds(1.2)
	ok(WS.get_state("door/door_b1") == true, "bedroom door opens")
	door.interact(p)
	await seconds(1.2)
	ok(WS.get_state("door/door_b1") == false, "bedroom door closes")
	var sw = WS.get_obj("sw_living")
	var before = WS.get_state("light/living_ceiling")
	sw.interact(p)
	ok(WS.get_state("light/living_ceiling") != before, "living room switch toggles the ceiling light")
	var lamp = WS.get_obj("b1_lamp")
	lamp.interact(p)
	ok(WS.get_state("light/b1_lamp") == false, "bedside lamp turns off")
	lamp.interact(p)
	var tv = WS.get_obj("tv")
	tv.interact(p)
	ok(tv.power, "TV turns on")
	tv.interact(p)
	ok(not tv.power, "TV turns off")
	var photo = WS.get_obj("photo_hall")
	photo.set_tilt(8.0)
	photo.interact(p)
	await seconds(0.5)
	ok(absf(photo.tilt) < 0.01, "crooked photo can be straightened")
	var chair = WS.get_obj("kitchen_chair_a")
	chair.interact(p)
	await seconds(0.8)
	ok(chair.displaced, "chair can be pulled out")
	chair.interact(p)
	await seconds(0.8)
	ok(not chair.displaced, "chair can be pushed back")
	var hud = WS.get_obj("hud")
	WS.get_obj("fridge_letter").interact(p)
	ok(hud.is_reading() and hud.note_text.text.contains("S-T-A-R-T"), "fridge letter is readable and holds the spelling clue")
	hud.close_note()
	var phone = WS.get_obj("phone")
	p.global_position = phone.global_position + Vector3(0.6, -0.7, 0)
	phone.interact(p)
	ok(phone.in_call, "phone can be picked up (dial tone)")
	phone.interact(p)
	ok(not phone.in_call, "phone can be hung up")
	var gd = WS.get_obj("garage_door")
	gd.interact(p)
	await seconds(4.0)
	ok(WS.get_state("door/garage_door") == true, "garage door opens")

	print("[computer]")
	var comp = WS.get_obj("computer")
	_type(comp, "DIR\n")
	ok(comp.terminal.lines.any(func(l): return String(l).contains("JOURNAL.TXT")), "terminal DIR lists files")
	_type(comp, "TYPE JOURNAL.TXT\n")
	ok(comp.terminal.lines.any(func(l): return String(l).contains("front room")), "terminal TYPE shows a file")

	print("[event director]")
	# player stays out in the street the whole time: events must not care
	p.global_position = Vector3(0, 0.2, 60)
	await frames(5)
	var dir = WS.get_obj("director")
	ok(dir.next_at >= 120.0 and dir.next_at <= 180.0, "first event scheduled at 2-3 min (%.0fs)" % dir.next_at)
	var orders = dir.simulate_orders(3)
	ok(orders[0] != orders[1] or orders[1] != orders[2], "simulated orders differ between runs")
	Engine.time_scale = 6.0
	dir.time_scale = 40.0
	var waited := 0.0
	while dir.fired.size() < dir.events.size() and waited < 240.0:
		await seconds(1.0)
		waited += 1.0
		# answer the phone if it rings, to exercise that path too
		if phone.ringing and randf() < 0.3:
			p.global_position = phone.global_position + Vector3(0.6, -0.7, 0)
			phone.interact(p)
	print("  order: ", " > ".join(dir.order), "   (%.0f s of test time)" % waited)
	ok(dir.fired.size() == dir.events.size(), "all %d events fired (%d)" % [dir.events.size(), dir.fired.size()])
	var gaps := []
	var prev := -1.0
	for e in WS.event_log:
		if e.variant in ["returned", "spelled"] or e.id == "press_enter" and e.variant != "shown":
			continue
	ok(WS.event_log.size() >= 10, "events logged (%d entries)" % WS.event_log.size())
	# let running events finish (normal speed: no new events in the meantime)
	dir.time_scale = 1.0
	await seconds(60.0)
	Engine.time_scale = 1.0
	var running := []
	for ev in dir.events:
		if ev.running:
			running.append(ev.id)
	running.erase("car")
	running.erase("neighbor_lights")
	ok(running.is_empty(), "short events wind down on their own (still running: %s)" % str(running))
	print("[persistence]")
	ok(WS.get_state("clock/clock_kitchen/offset", 0.0) != 0.0, "kitchen clock keeps its offset (%s min)" % str(WS.get_state("clock/clock_kitchen/offset")))
	var any_photo: bool = absf(WS.get_obj("photo_hall").tilt) > 1.0 or absf(WS.get_obj("photo_living").tilt) > 1.0
	ok(any_photo, "a photo stays crooked")
	var moved := false
	for cid in ["kitchen_chair_a", "kitchen_chair_b"]:
		if WS.get_obj(cid).displaced:
			moved = true
	ok(moved, "a kitchen chair stays where the world left it")
	ok(WS.get_state("computer/press_enter") == true, "PRESS ENTER persists on the computer")

	print("[PRESS ENTER]")
	_type(comp, "\n")
	ok(WS.get_state("computer/enter_spelled") != true, "pressing Enter does nothing")
	_type(comp, "ENTE")
	ok(WS.get_state("computer/enter_spelled") != true, "partial spelling does nothing")
	_type(comp, "R")
	await seconds(3.5)
	ok(WS.get_state("computer/enter_spelled") == true, "typing E-N-T-E-R triggers the response")
	ok(WS.get_state("consequence/enter_light") != null, "a light elsewhere went out (%s)" % str(WS.get_state("consequence/enter_light")))

	print("[after the ten events]")
	ok(dir.main_done(), "director knows the main events are done")
	var nxt: float = dir.time_to_next()
	ok(nxt > 0.0, "director keeps scheduling (next in %.0fs)" % nxt)
	ok(dir.events.any(func(e): return e.repeatable), "repeatable events exist for the after-phase")
	ok(not WS.event_log.any(func(e): return e.id == "victory"), "no ending / victory")
	print("\nwarnings: ", WS.warnings)
	print("\n%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _type(comp, text: String) -> void:
	for ch in text:
		var ev := InputEventKey.new()
		ev.pressed = true
		if ch == "\n":
			ev.keycode = KEY_ENTER
		else:
			ev.keycode = OS.find_keycode_from_string(ch) if ch != " " else KEY_SPACE
			ev.unicode = ch.unicode_at(0)
		comp.handle_key(ev)


func _count(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count(ch)
	return c
