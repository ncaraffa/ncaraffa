extends SceneTree
## Plays all five nights doing every chore through the player's real interaction
## ray (look + E), checks that no chore starts already done, that each one
## ticks off, and that the bed works: the night-3 awakening, the night-4
## silhouette in the hallway (it has to happen before you can sleep), and the
## end of night 5, which is not a sixth night but FINAL 2 (the last task).
##   godot --headless --path . -s tests/tasks_test.gd
var WS
var p
var house
var tm
var nm
var fails := 0
var checks := 0


func ok(c: bool, what: String) -> void:
	checks += 1
	print("  %s  %s" % ["PASS" if c else "FAIL", what])
	if not c:
		fails += 1


func secs(s: float) -> void:
	await create_timer(s).timeout


func look_at_world(pt: Vector3) -> void:
	var cam: Vector3 = p.global_position + Vector3(0, 1.62, 0)
	var d := pt - cam
	p.set_look(rad_to_deg(atan2(-d.x, -d.z)), rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length())))


## Stand at `stand` (house-local), aim at `target` (house-local), press E.
func use(stand: Vector3, target: Vector3, expect_prompt := "") -> String:
	p.global_position = house.to_global(stand)
	p.velocity = Vector3.ZERO
	await secs(0.15)
	look_at_world(house.to_global(target))
	await secs(0.25)
	var prompt: String = p.looked_at.get_prompt() if p.looked_at else "<nothing>"
	if expect_prompt != "" and prompt != expect_prompt:
		print("      aimed at %s, prompt '%s' (wanted '%s')" % [p.looked_at, prompt, expect_prompt])
	p._do_interact()
	await secs(0.4)
	return prompt


func done(id: String) -> bool:
	for t in tm.tasks:
		if t.id == id:
			return t.done
	return false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.get_node("GameManager").in_game = false
	root.get_node("GameManager").ending_returns_to_menu = false
	var world: Node = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await secs(0.6)
	WS = root.get_node("WorldState")
	p = WS.player
	house = WS.get_obj("house")
	tm = WS.get_obj("tasks")
	nm = WS.get_obj("night_manager")
	WS.get_obj("director").time_scale = 0.0
	WS.get_obj("scare_director").enabled = false
	await use(Vector3(1.5, 0.02, 2.3), Vector3(0.36, 0.56, 2.33))
	WS.get_obj("hud").close_note()
	for n in range(1, 6):
		print("[night %d] %s" % [n, str(tm.tasks.map(func(t): return t.id))])
		await secs(0.7)
		var pre_done: Array = tm.tasks.filter(func(t): return t.essential and t.done).map(func(t): return t.id)
		ok(pre_done.is_empty(), "no chore starts already done %s" % str(pre_done))
		ok(not WS.warnings.any(func(w): return w.contains("already done")), "no 'already done' warnings")
		for t in tm.tasks.duplicate():
			await _do(t.id)
		await secs(1.0)
		for t in tm.tasks:
			if t.essential or t.id in ["hall_light", "look_kitchen_window"]:
				ok(t.done, "night %d: '%s' ticks off" % [n, t.text])
		ok(tm.essentials_done(), "night %d: essentials done" % n)
		if n == 4:
			await _hall_scene()
		if n == 5:
			var alone: Array = tm.tasks.filter(func(t): return t.id == "alone")
			ok(alone.size() == 1 and alone[0].text == "Make sure you're alone." and not alone[0].essential,
				"night 5: 'Make sure you're alone.' is on the list and never blocks bed")
			await _last_task()
			break
		var prompt: String = await use(Vector3(2.4, 0.02, 3.4), Vector3(1.15, 0.5, 3.5), "Sleep")
		await secs(9.0)
		if n == 3:
			ok(nm.interrupted, "night 3: woken up at 3 am instead of a new night")
			var pool = WS.get_obj("figures")
			ok(pool.any_visible(), "night 3: something is at the bedroom window")
			await secs(1.5)
			p.global_position = house.to_global(Vector3(2.1, 0.02, 1.2))
			look_at_world(house.to_global(Vector3(2.1, 1.5, 0.0)))
			await secs(1.0)
			ok(not pool.any_visible(), "night 3: walking up to the window, it is gone")
			await use(Vector3(2.4, 0.02, 3.4), Vector3(1.15, 0.5, 3.5), "Sleep")
			await secs(9.0)
		ok(int(WS.get_state("night")) == n + 1, "after sleeping: night %d (bed prompt '%s')" % [n + 1, prompt])
	print("warnings: ", WS.warnings)
	print("%d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## Night 4: the bed refuses until the silhouette has walked into the bedroom.
func _hall_scene() -> void:
	var hs = WS.get_obj("hall_scene")
	var tv = WS.get_obj("tv")
	if tv.power:
		tv.set_power(false, 0, true)
	await use(Vector3(2.4, 0.02, 3.4), Vector3(1.15, 0.5, 3.5), "Sleep")
	await secs(4.0)
	ok(int(WS.get_state("night")) == 4 and not nm.sleeping, "night 4: can't sleep before the hallway scene")
	ok(tv.power, "night 4: the TV downstairs turned itself on")
	await use(Vector3(14.3, 0.02, 8.6), Vector3(15.52, 0.8, 8.6), "Turn off")
	ok(not tv.power, "night 4: TV turned off")
	# coming back through the foyer: it is standing in the hall
	p.global_position = house.to_global(Vector3(6.9, 0.02, 10.2))
	p.set_look(-90.0, 0.0)
	await secs(1.0)
	ok(hs.state == hs.S.PLACED, "night 4: a figure is waiting in the hallway (state %d)" % hs.state)
	p.global_position = house.to_global(Vector3(4.9, 0.02, 9.3))
	look_at_world(house.to_global(Vector3(4.88, 1.5, 5.05)))
	await secs(1.0)
	ok(hs.state == hs.S.SEEN, "night 4: it is seen, and it doesn't move")
	await secs(2.0)
	ok(hs.f.global_position.distance_to(house.to_global(hs.STAND)) < 0.05, "night 4: still standing there")
	await secs(16.0)
	ok(hs.done(), "night 4: it walked into the bedroom and is gone")
	var note = WS.get_obj("pillow_note")
	ok(note != null and note.text == "Don't wake him up.", "night 4: a note on the pillow")
	var pr: String = await use(Vector3(1.0, 0.02, 2.45), hs.NOTE_AT, "Read")
	ok(pr == "Read" and WS.get_obj("hud").is_reading(), "night 4: the note can be read")
	WS.get_obj("hud").close_note()


## Night 5: lying down does not lead to a sixth night.
func _last_task() -> void:
	var gm = root.get_node("GameManager")
	await use(Vector3(2.4, 0.02, 3.4), Vector3(1.15, 0.5, 3.5), "Sleep")
	await secs(4.0)
	ok(gm.ending == "last_task", "night 5: sleeping starts FINAL 2 (ending '%s')" % gm.ending)
	var e = WS.get_obj("last_task_ending")
	var seen := {}
	var whisper_sub := ""
	var t := 0.0
	while t < 75.0 and e and e.phase != "done":
		await secs(0.1)
		t += 0.1
		seen[e.phase] = true
		var sub: String = WS.get_obj("hud").subtitle.text
		if sub != "":
			whisper_sub = sub
	for ph in ["steps", "door", "stopped", "mattress", "whisper", "scare", "blackout", "title", "done"]:
		ok(seen.has(ph), "FINAL 2 goes through '%s'" % ph)
	ok(whisper_sub == "You forgot to check the tape.", "the whisper says exactly 'You forgot to check the tape.' ('%s')" % whisper_sub)
	ok(int(WS.get_state("night")) == 5, "there is no night 6")


func _do(id: String) -> void:
	match id:
		"trash":
			await use(Vector3(11.3, 0.02, 2.2), Vector3(11.3, 0.6, 1.2), "Take out the bag")
			var bag = p.held
			p.global_position = Vector3(12.0, 0.1, -24.8)
			if bag:
				bag.global_position = p.global_position + Vector3(0, 1.2, 0)
			await secs(0.3)
			await use(house.to_local(Vector3(12.0, 0.1, -24.8)), house.to_local(Vector3(11.6, 0.6, -26.2)), "Throw the bag away")
			await secs(0.8)
		"dishes":
			await use(Vector3(12.0, 0.02, 1.0), Vector3(12.0, 1.1, 0.25), "Turn on")
			for i in 3:
				await use(Vector3(12.0, 0.02, 1.0), Vector3(11.95, 0.8, 0.45), "Wash a dish")
				await secs(1.3)
			await use(Vector3(12.0, 0.02, 1.0), Vector3(12.0, 1.1, 0.25), "Turn off")
		"mail":
			await use(house.to_local(Vector3(-7.2, 0.1, -18.6)), house.to_local(Vector3(-7.2, 1.15, -17.4)), "Check the mail")
			WS.get_obj("hud").close_note()
		"windows":
			await use(Vector3(12.0, 0.02, 1.2), Vector3(12.0, 1.3, 0.05), "Close the window")
			await use(Vector3(9.9, 0.02, 9.6), Vector3(9.9, 1.2, 10.95), "Close the window")
			await use(Vector3(2.1, 0.02, 9.7), Vector3(2.1, 1.2, 10.95), "Close the window")
		"stove":
			await use(Vector3(14.3, 0.02, 1.8), Vector3(15.3, 0.75, 1.8), "Turn off the stove")
		"lock_back":
			var d = WS.get_obj("door_back")
			if d.is_open:
				await use(Vector3(13.6, 0.02, 1.4), Vector3(13.6, 1.1, 0.0), "Close")
				await secs(1.0)
			await use(Vector3(13.4, 0.02, 0.9), Vector3(13.24, 1.15, 0.0), "Lock")
		"lock_front":
			var d2 = WS.get_obj("door_front")
			if d2.is_open:
				await use(Vector3(5.9, 0.02, 9.8), Vector3(5.9, 1.1, 11.0), "Close")
				await secs(1.0)
			await use(Vector3(6.1, 0.02, 10.1), Vector3(6.27, 1.15, 11.0), "Lock")
		"garage":
			await use(Vector3(19.25, -0.28, 8.5), Vector3(19.25, 1.0, 10.95), "Close")
			await secs(4.0)
		"mugs":
			for m in ["mug_b1", "mug_living", "mug_kitchen"]:
				var mug = WS.get_obj(m)
				var mp: Vector3 = house.to_local(mug.global_position)
				var stand := Vector3(mp.x, 0.02, mp.z)
				var best := stand
				for off in [Vector3(0, 0, -0.75), Vector3(0, 0, 0.75), Vector3(-0.75, 0, 0), Vector3(0.75, 0, 0)]:
					var c: Vector3 = stand + off
					p.global_position = house.to_global(c)
					await secs(0.1)
					look_at_world(mug.global_position + Vector3(0, 0.05, 0))
					await secs(0.15)
					if p.looked_at == mug:
						best = c
						break
				await use(best, mp + Vector3(0, 0.05, 0), "Pick up")
				p.global_position = house.to_global(Vector3(12.0, 0.02, 1.15))
				mug.global_position = p.global_position + Vector3(0, 1.3, -0.4)
				await secs(0.3)
				look_at_world(house.to_global(Vector3(11.95, 0.8, 0.45)))
				await secs(0.3)
				ok(p.looked_at and p.looked_at.get_prompt() == "Put in the sink", "holding a mug at the sink offers 'Put in the sink'")
				p._do_interact()
				await secs(1.2)
				print("      %s -> local %s held=%s" % [m, str(house.to_local(mug.global_position).snapped(Vector3.ONE * 0.01)), str(p.held)])
		"lights":
			for sw in ["sw_living", "sw_kitchen", "sw_dining", "sw_foyer", "sw_garage"]:
				var s = WS.get_obj(sw)
				var any_on := false
				for t in s.targets:
					if WS.get_state("light/" + t, false):
						any_on = true
				if any_on:
					s.interact(p)
			for l in ["living_floorlamp", "living_lamp"]:
				var f = WS.get_obj(l)
				if f.is_on:
					f.interact(p)
		"hall_light":
			var hs = WS.get_obj("sw_hall")
			if WS.get_state("light/hall_ceiling", false):
				hs.interact(p)
		"look_kitchen_window":
			p.global_position = house.to_global(Vector3(12.0, 0.02, 1.4))
			look_at_world(house.to_global(Vector3(12.0, 1.55, 0.0)))
			await secs(1.6)
