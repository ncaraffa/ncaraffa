extends SceneTree
## Nights, chores, scares, apparitions, figures and the audio bus layout.
##   godot --headless --path . -s tests/horror_test.gd
var failures := 0
var checks := 0
var WS
var p
var house


func ok(cond: bool, what: String) -> void:
	checks += 1
	print("  %s  %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		failures += 1


func secs(s: float) -> void:
	await create_timer(s).timeout


func look_at_point(pt: Vector3) -> void:
	var cam: Vector3 = p.global_position + Vector3(0, 1.62, 0)
	var d := pt - cam
	p.set_look(rad_to_deg(atan2(-d.x, -d.z)), rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length())))


func place(local: Vector3) -> void:
	p.global_position = house.to_global(local)
	p.velocity = Vector3.ZERO


func use_target(local_target: Vector3) -> String:
	look_at_point(house.to_global(local_target))
	await secs(0.25)
	var t = p.looked_at
	var prompt: String = t.get_prompt() if t else "<nothing>"
	p._do_interact()
	await secs(0.3)
	return prompt


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.get_node("GameManager").in_game = false
	var world: Node = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await secs(0.5)
	WS = root.get_node("WorldState")
	p = WS.player
	house = WS.get_obj("house")
	var dir = WS.get_obj("director")
	var sd = WS.get_obj("scare_director")
	var tm = WS.get_obj("tasks")
	var nm = WS.get_obj("night_manager")
	dir.time_scale = 0.0
	sd.enabled = false

	print("[audio buses]")
	for b in ["Ambience", "SFX", "Horror", "Music", "UI", "AmbIn", "AmbOut", "SFXIn", "SFXOut", "Phone", "Room"]:
		ok(AudioServer.get_bus_index(b) != -1, "bus " + b)
	ok(AudioServer.get_bus_effect(0, 1) is AudioEffectHardLimiter, "master hard limiter")
	ok(WS.warnings.is_empty(), "no missing sounds / warnings " + str(WS.warnings))

	print("[night 1 chores]")
	ok(int(WS.get_state("night")) == 1, "starts on night 1")
	ok(tm.tasks.size() >= 3, "tonight's list has %d tasks" % tm.tasks.size())
	var prompt: String = await use_target(Vector3(0.36, 0.56, 2.33))   # notepad on the nightstand
	ok(prompt == "Take the list" and WS.get_state("player/has_list") == true, "takes the list from the nightstand")
	root.get_node("WorldState").get_obj("hud").close_note()
	# trash: kitchen can -> carry -> outdoor bin
	place(Vector3(11.3, 0.02, 2.2))
	prompt = await use_target(Vector3(11.3, 0.6, 1.2))
	ok(prompt == "Take out the bag" and p.held is TrashCan.TrashBag, "takes the trash bag out of the can")
	var bag = p.held
	p.global_position = Vector3(12.0, 0.1, -24.8)
	bag.global_position = p.global_position + Vector3(0, 1.2, 0)
	await secs(0.4)
	ok(p.held == bag, "still carrying the bag outside")
	prompt = await use_target(house.to_local(Vector3(11.6, 0.6, -26.2)))
	await secs(0.8)
	ok(WS.get_state("trash/out") == true, "throws it into the outdoor bin (%s)" % prompt)
	# dishes: water off -> nothing; water on -> three washes
	place(Vector3(12.0, 0.02, 1.0))
	await use_target(Vector3(11.95, 0.8, 0.45))
	ok(int(WS.get_state("dishes/dirty")) == 3, "dishes don't wash with the water off")
	await use_target(Vector3(12.0, 1.1, 0.25))
	ok(WS.get_obj("faucet_kitchen").running, "turns the faucet on")
	for i in 3:
		await use_target(Vector3(11.95, 0.8, 0.45))
		await secs(1.3)
	ok(int(WS.get_state("dishes/dirty")) == 0, "washes all three dishes")
	await use_target(Vector3(12.0, 1.1, 0.25))
	# mail
	p.global_position = Vector3(-7.2, 0.1, -18.6)
	await secs(0.3)
	prompt = await use_target(house.to_local(Vector3(-7.2, 1.15, -17.4)))
	ok(WS.get_state("mail/collected_n1") == true, "reads the mail (%s)" % prompt)
	WS.get_obj("hud").close_note()
	# lights
	ok(not tm.essentials_done(), "not done while lights are still on downstairs")
	for l in TaskManager.LIGHTS_DOWNSTAIRS:
		var f = WS.get_obj(l)
		if f:
			f.set_on(false, true)
	await secs(1.0)
	ok(tm.essentials_done(), "essential chores done -> can sleep")
	ok(tm.list_bbcode().contains("[s]"), "the list strikes through finished chores")

	print("[sleep -> night 2]")
	var chair = WS.get_obj("kitchen_chair_a")
	chair.transform = chair.home.translated_local(Vector3(0, 0, 0.4))
	chair.displaced = true
	place(Vector3(2.4, 0.02, 3.4))
	prompt = await use_target(Vector3(1.15, 0.5, 3.5))
	ok(prompt == "Sleep", "the bed offers to sleep")
	await secs(9.0)
	ok(int(WS.get_state("night")) == 2 and not nm.sleeping, "wakes up on night 2")
	ok(chair.displaced, "a moved chair is still moved the next night")
	ok(WS.get_state("trash/full") == true and int(WS.get_state("dishes/dirty")) == 3, "chores come back the next night")
	ok(WS.get_state("mail/text", "").contains("ASSOCIATION"), "night 2 mail is waiting")
	ok(WS.get_obj("hud").title_label.text == "Night 2", "shows 'Night 2' during the transition")

	print("[nights 3-6]")
	for n in [3, 4, 5, 6]:
		tm.debug_complete()
		await secs(1.0)
		var can: bool = tm.essentials_done()
		nm.sleep()
		await secs(9.0)
		if nm.interrupted:
			# night 3 is broken by the 3 am awakening: go back to bed
			nm.request_sleep()
			await secs(9.0)
		ok(can and int(WS.get_state("night")) == n, "reaches night %d (%d tasks, strange: %s)" % [n, tm.tasks.size(), str(tm.tasks.filter(func(t): return t.strange).map(func(t): return t.text))])
	ok(int(WS.get_state("cult/stage")) >= 5, "cult traces advanced to stage %d" % int(WS.get_state("cult/stage")))
	ok(sd.quota() >= 2, "scares allowed on later nights (quota %d)" % sd.quota())

	print("[figures]")
	var pool = WS.get_obj("figures")
	var f: ShadowFigure = pool.borrow()
	f.appear(p.global_position + Vector3(0, 0, -3), Vector3(0, 0, 1), 0.5)
	await secs(0.8)
	ok(f.state == ShadowFigure.State.WATCHING and f.visible, "figure appears and watches")
	f.walk_path(PackedVector3Array([f.global_position + Vector3(2, 0, 0)]), 2.0)
	await secs(1.5)
	ok(f.state == ShadowFigure.State.WATCHING and absf(f.global_position.x - (p.global_position.x + 2.0)) < 0.2, "figure walks a path")
	f.vanish("fade", 0.3)
	await secs(0.6)
	ok(f.state == ShadowFigure.State.HIDDEN and not f.visible and not f.get_meta("busy"), "figure vanishes and returns to the pool")

	print("[scares: forced]")
	place(Vector3(10.0, 0.02, 8.0))
	p.set_look(-90.0)
	for sid in ["hallway", "door", "window", "behind", "tv"]:
		var before: int = WS.event_log.size()
		sd.force(sid)
		await secs(0.1)
		var shown: bool = pool.any_visible() or sid == "tv"
		await secs(3.5)
		var logged: bool = WS.event_log.slice(before).any(func(e): return e.id == "scare_" + sid)
		ok(shown and logged and not pool.any_visible(), "scare '%s' fires, is logged and cleans up" % sid)

	print("[scares: real triggers]")
	sd.recover_until = 0.0
	sd.armed = null
	# hallway: walk into the hall and look along it
	place(Vector3(6.0, 0.02, 9.8))
	p.set_look(90.0)
	await secs(0.2)
	ok(sd.try_arm("hallway").begins_with("armed"), "hallway scare arms")
	place(Vector3(4.9, 0.02, 8.0))
	p.set_look(0.0, -3.0)
	await secs(1.0)
	ok(sd.armed == null and WS.event_log.back().id == "scare_hallway", "looking down the hall triggers it")
	await secs(1.5)
	# door: the scare picks a closed door; open it with E from the other side
	for d in ["door_b2", "door_closet", "door_laundry", "door_bath", "door_b1"]:
		WS.get_obj(d).set_open(false, true)
	WS.set_state("scare/doors_used", [])
	await secs(1.2)
	place(Vector3(10.0, 0.02, 8.0))
	ok(sd.try_arm("door").begins_with("armed"), "door scare arms")
	var door: Door = sd.armed.door
	var spots: Array = sd.armed.SPOTS[door.obj_id]
	place(spots[1])
	look_at_point(door.global_transform * Vector3(door.width / 2.0, 1.1, 0))
	await secs(0.3)
	ok(p.looked_at == door, "player looks at the armed door")
	p._do_interact()
	await secs(1.6)
	ok(WS.event_log.any(func(e): return e.id == "scare_door"), "opening the armed door (%s) triggers it" % door.obj_id)
	await secs(1.0)
	# window: stand at the kitchen window and look out
	sd.armed = null
	ok(sd.try_arm("window").begins_with("armed"), "window scare arms")
	place(Vector3(12.0, 0.02, 1.4))
	look_at_point(house.to_global(Vector3(12.0, 1.55, 0.0)))
	await secs(3.0)
	ok(WS.event_log.back().id == "scare_window", "looking out of a window triggers it")
	await secs(1.0)
	# behind: breathing, then turning around
	place(Vector3(10.0, 0.02, 8.0))
	p.set_look(0.0)
	await secs(0.3)
	ok(sd.try_arm("behind").begins_with("armed"), "behind-you scare arms")
	await secs(1.6)
	p.set_look(180.0)
	await secs(0.5)
	ok(WS.event_log.back().id == "scare_behind", "turning round towards the breathing triggers it")
	await secs(1.0)
	# behind, but the player never turns: nothing happens
	var behind_before: int = WS.event_log.filter(func(e): return e.id == "scare_behind").size()
	ok(sd.try_arm("behind").begins_with("armed"), "behind-you arms again")
	await secs(12.5)
	ok(WS.event_log.filter(func(e): return e.id == "scare_behind").size() == behind_before and sd.armed == null, "ignoring the breathing lets it fade with nothing")

	print("[apparitions & side events]")
	for eid in ["ap_street", "ap_window", "ap_backyard", "chant", "object_fall", "bang", "whisper"]:
		if eid == "ap_backyard":
			dir.get_event("ap_street").finish()
			pool.hide_all()
			await secs(0.2)
		var r: String = dir.force(eid)
		ok(r.ends_with("started"), "%s: %s" % [eid, r])
		await secs(0.3)
	place(Vector3(10.0, 0.02, 8.0))
	p.set_look(-90.0)
	await secs(0.2)
	var rh: String = dir.force("ap_hall")
	ok(rh.ends_with("started"), "ap_hall: " + rh)
	await secs(1.0)
	var rl: String = dir.force("lights_out")
	ok(rl.ends_with("started") or rl.contains("context"), "lights_out: " + rl)

	print("\nwarnings: ", WS.warnings)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
