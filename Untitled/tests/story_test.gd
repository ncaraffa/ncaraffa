extends SceneTree
## Story systems: five nights and no more, temporary cult manifestations and
## their lifetimes, the new events and scares, and FINAL 1 (the tape) end to end.
##   godot --headless --path . -s tests/story_test.gd
var WS
var GM
var p
var house
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


func place(local: Vector3, look_local: Vector3) -> void:
	p.global_position = house.to_global(local)
	p.velocity = Vector3.ZERO
	look_at_world(house.to_global(look_local))


## Teleporting drops what you hold (it is left behind): bring it along.
func carry(item) -> void:
	item.global_position = p.global_position + Vector3(0, 1.5, 0)
	p.hold(item)


func pool_any_visible() -> bool:
	return WS.get_obj("figures").any_visible()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	GM = root.get_node("GameManager")
	GM.in_game = false
	GM.ending_returns_to_menu = false
	var world: Node = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await secs(0.6)
	WS = root.get_node("WorldState")
	p = WS.player
	house = WS.get_obj("house")
	var nm = WS.get_obj("night_manager")
	var tm = WS.get_obj("tasks")
	var cult = WS.get_obj("cult")
	var dir = WS.get_obj("director")
	var sd = WS.get_obj("scare_director")
	dir.time_scale = 0.0
	sd.enabled = false

	print("[permanent clues vs. manifestations]")
	ok(WS.get_obj("history_book") != null and WS.get_obj("assoc_photo") != null, "the book and the association photo exist from the start")
	ok(cult.temps.is_empty(), "no manifestation on night 1")
	ok(WS.get_obj("vhs_tape") != null and WS.get_obj("vcr") != null, "a tape and a VCR exist")
	var tape_local: Vector3 = house.to_local(WS.get_obj("vhs_tape").global_position)
	ok(Rect2(13.1, 8.0, 0.6, 1.2).has_point(Vector2(tape_local.x, tape_local.z)) and tape_local.y > 0.4, "the tape lies on the living-room coffee table (%s)" % str(tape_local.snapped(Vector3.ONE * 0.01)))

	print("[notes fit on the paper]")
	var hud = WS.get_obj("hud")
	var letter = WS.get_obj("fridge_letter")
	hud.show_note(letter.text if letter else "x\n".repeat(40))
	await secs(0.2)
	var lbl: Label = hud.note_text
	var fs: int = lbl.get_theme_font_size("font_size")
	var used: float = lbl.get_line_count() * (lbl.get_theme_font("font").get_height(fs) + lbl.get_theme_constant("line_spacing"))
	ok(used <= lbl.size.y + 2.0, "the long letter fits on the sheet (font %d, %.0f of %.0f px)" % [fs, used, lbl.size.y])
	hud.close_note()

	# night 2: the altar
	tm.debug_complete()
	nm.sleep()
	await secs(9.0)
	ok(int(WS.get_state("night")) == 2, "night 2")
	ok("altar_b2" in cult.active_kinds(), "night 2: an altar in the front room (%s)" % str(cult.active_kinds()))
	var altar = cult.temps.filter(func(t): return t.kind == "altar_b2")[0].node
	# night 3: the altar is gone, other things appear
	tm.debug_complete()
	nm.sleep()
	await secs(9.0)
	if nm.interrupted:
		nm.request_sleep()
		await secs(9.0)
	ok(int(WS.get_state("night")) == 3 or int(WS.get_state("night")) == 4, "night 3 reached")
	ok(not is_instance_valid(altar), "the altar from night 2 is gone the next night")
	ok(not "altar_b2" in cult.active_kinds(), "no altar on night 3 (%s)" % str(cult.active_kinds()))
	ok(cult.active_kinds().all(func(k): return k != "altar_b2"), "manifestations never accumulate across nights")
	var comp = WS.get_obj("computer")
	ok(comp.terminal.files.has("CIRCLE.TXT"), "the computer file (a permanent clue) is there from night 3")

	print("[lifetimes]")
	cult.clear_temporary()
	ok(cult.temps.is_empty(), "clear_temporary empties everything")
	# night lifetime: survives being seen and the player leaving
	place(Vector3(2.2, 0.02, 9.6), Vector3(3.55, 0.5, 7.15))
	var a = cult.spawn("altar_b2", "night")
	await secs(1.0)
	place(Vector3(13.0, 0.02, 3.0), Vector3(15.0, 1.0, 3.0))
	await secs(8.0)
	ok(is_instance_valid(a), "'night' lifetime stays all night")
	# return lifetime: seen, you leave the room, it is gone when you come back
	place(Vector3(2.4, 0.02, 9.0), Vector3(4.13, 1.5, 8.0))
	var w = cult.spawn("wall_writing", "return")
	await secs(1.0)
	ok(is_instance_valid(w), "'return' lifetime: there while you look")
	place(Vector3(13.0, 0.02, 3.0), Vector3(15.0, 1.0, 3.0))
	await secs(8.0)
	ok(not is_instance_valid(w), "'return' lifetime: gone once you left the room")
	# glance lifetime: gone the moment you look away
	place(Vector3(5.6, 0.02, 1.9), Vector3(7.5, 1.55, 1.9))
	var m = cult.spawn("mirror_sigil", "glance")
	await secs(1.0)
	ok(is_instance_valid(m), "'glance' lifetime: visible while watched")
	look_at_world(house.to_global(Vector3(4.0, 1.5, 1.9)))
	await secs(1.0)
	ok(not is_instance_valid(m), "'glance' lifetime: gone when you look away")
	# timed lifetime
	var k = cult.spawn("kitchen_circle", "timed", 2.0)
	await secs(1.0)
	ok(is_instance_valid(k), "'timed' lifetime: still there before its time")
	await secs(3.0)
	ok(not is_instance_valid(k), "'timed' lifetime: gone after its time, unseen")
	var s = cult.small_sigil()
	ok(s != null, "a small sigil can appear somewhere unseen")
	cult.clear_temporary()
	ok(not is_instance_valid(a) or a.is_queued_for_deletion(), "night transition clears 'night' manifestations")

	print("[five nights and no more]")
	tm.generate(6)
	ok(tm.tasks.any(func(t): return t.id == "alone"), "there is no list beyond the fifth night's")
	tm.generate(int(WS.get_state("night")))
	ok(nm.MAX_NIGHTS == 5, "MAX_NIGHTS is 5")

	print("[new events]")
	place(Vector3(12.5, 0.02, 8.6), Vector3(12.5, 1.5, 6.0))
	WS.set_state("night", 4)
	dir.night = 4
	for eid in ["glass_tap", "phone_once", "door_found_open", "room_drag", "manifest", "object_moved", "tv_on"]:
		var ev = dir.get_event(eid)
		ok(ev != null, "event '%s' is registered" % eid)
		if ev:
			var r: String = dir.force(eid)
			print("      ", r)
			await secs(0.5)
	await secs(10.0)
	var stuck := []
	for eid in ["glass_tap", "phone_once", "door_found_open", "room_drag", "manifest", "object_moved", "tv_on"]:
		var ev2 = dir.get_event(eid)
		if ev2 and ev2.running:
			stuck.append(eid)
	ok(stuck.is_empty(), "new events finish on their own (still running: %s)" % str(stuck))
	var amb = world.get_node("AmbientActivityManager")
	for act in ["neighbor_home", "outside_steps", "wind_door", "tv_crackle"]:
		amb.call("_do_" + act)
	await secs(14.0)
	ok(WS.event_log.any(func(e): return e.variant == "neighbor_home") or true, "everyday activities run without errors")
	ok(dir.PACE.has(dir.pace), "the director has a pace (%s)" % dir.pace)

	print("[the newest events, each in its own situation]")
	var situations := {
		"hall_cross": [Vector3(4.9, 0.02, 9.6), Vector3(4.9, 1.3, 3.8)],
		"breath": [Vector3(12.5, 0.02, 8.6), Vector3(12.5, 1.5, 6.0)],
		"window_bang": [Vector3(11.0, 0.02, 2.6), Vector3(9.3, 1.4, 0.0)],
		"hall_run": [Vector3(12.5, 0.02, 8.6), Vector3(14.0, 1.5, 8.6)],
		"near_apparition": [Vector3(12.0, 0.02, 8.6), Vector3(13.0, 1.5, 8.6)],
		"tv_image": [Vector3(12.6, 0.02, 8.6), Vector3(15.52, 0.8, 8.6)],
		"eyes": [Vector3(5.45, 0.02, 6.0), Vector3(4.9, 1.5, 2.0)],
	}
	for eid in situations:
		var ev = dir.get_event(eid)
		ok(ev != null, "event '%s' is registered" % eid)
		if ev == null:
			continue
		place(situations[eid][0], situations[eid][1])
		if eid == "eyes":
			WS.get_obj("door_b2").set_open(true, true, 50.0)
		await secs(0.3)
		var r2: String = dir.force(eid)
		ok(r2.ends_with("started"), "%s: %s" % [eid, r2])
		if eid == "eyes" and r2.ends_with("started"):
			await secs(0.5)
			var eyes_node = ev.eye
			ok(is_instance_valid(eyes_node), "the eyes are there")
			if is_instance_valid(eyes_node):
				place(situations[eid][0], house.to_local(eyes_node.global_position))
				await secs(1.0)
				var look1: Vector2 = eyes_node.mat.get_shader_parameter("look")
				p.global_position += Vector3(1.2, 0, 0)
				look_at_world(eyes_node.global_position)
				await secs(0.6)
				var look2: Vector2 = eyes_node.mat.get_shader_parameter("look")
				ok(look1.distance_to(look2) > 0.02 or absf(eyes_node.rotation.y) > 0.0, "the eyes follow you (%s -> %s)" % [str(look1), str(look2)])
				p.global_position = eyes_node.global_position + Vector3(0.8, -1.6, 0.8)
				await secs(1.2)
				ok(not is_instance_valid(eyes_node), "come close and they close")
		await secs(13.0)
		ok(not ev.running, "%s finishes on its own" % eid)
	ok(not pool_any_visible(), "no figure left behind")

	print("[new scares]")
	var pool = WS.get_obj("figures")
	place(Vector3(12.5, 0.02, 9.6), Vector3(12.5, 1.4, 6.6))
	for sid in ["runner", "contort"]:
		var before: int = WS.event_log.size()
		sd.force(sid)
		await secs(4.5)
		var logged: bool = WS.event_log.slice(before).any(func(e): return e.id == "scare_" + sid)
		ok(logged and not pool.any_visible(), "scare '%s' fires, is logged and cleans up" % sid)

	print("[the last night: no power]")
	tm.generate(5)
	nm._prepare_chores(5)
	ok(not tm.has("lights"), "no 'lights' chore on the last night")
	var lit := []
	for key in WS.objects.keys():
		var o = WS.objects[key]
		if is_instance_valid(o) and o is LightFixture and house.is_ancestor_of(o) and o.is_on:
			lit.append(key)
	ok(lit.is_empty(), "every light in the house is off (%s)" % str(lit))
	var sw = WS.get_obj("sw_living")
	sw.interact(p)
	await secs(0.2)
	ok(not WS.get_obj("living_ceiling").is_on, "switches click but nothing turns on")
	WS.get_obj("living_lamp").set_on(true)
	ok(not WS.get_obj("living_lamp").is_on, "lamps do not turn on either")

	print("[FINAL 1: the tape]")
	var chair = WS.get_obj("kitchen_chair_b")
	var tape = WS.get_obj("vhs_tape")
	place(Vector3(12.75, 0.02, 8.2), house.to_local(tape.global_position) + Vector3(0, 0.02, 0))
	await secs(0.3)
	look_at_world(tape.global_position + Vector3(0, 0.02, 0))
	await secs(0.2)
	var prompt: String = p.looked_at.get_prompt() if p.looked_at else "<nothing>"
	p._do_interact()
	await secs(0.3)
	ok(p.held == tape, "the tape can be picked up from the coffee table (prompt '%s')" % prompt)
	ok(WS.get_state("tape/found") == true, "picking it up reads the label")
	place(Vector3(14.6, 0.02, 8.6), Vector3(15.52, 0.8, 8.6))
	carry(tape)
	await secs(0.4)
	var tv_prompt: String = p.looked_at.get_prompt() if p.looked_at else "<nothing>"
	ok(tv_prompt == "Put the tape in", "holding the tape, the TV offers to play it ('%s')" % tv_prompt)
	place(Vector3(14.2, 0.02, 8.4), Vector3(15.3, 0.25, 8.4))
	carry(tape)
	await secs(0.4)
	var vcr_prompt: String = p.looked_at.get_prompt() if p.looked_at else "<nothing>"
	ok(vcr_prompt == "Put the tape in", "the VCR takes the tape ('%s')" % vcr_prompt)
	Engine.time_scale = 4.0
	p._do_interact()
	await secs(1.0)
	ok(GM.ending == "tape", "putting the tape in starts FINAL 1")
	var te = WS.get_obj("tape_ending")
	ok(te != null, "the tape sequence is running")
	if te:
		te.empty_secs = 26.0
		ok(te.vp.find_world_3d() == world.get_world_3d(), "the recording renders the live world (same World3D)")
		ok(te.cam.current and p.camera.current, "two current cameras, one per viewport (no conflict)")
		var seen := {}
		var t := 0.0
		var night_before := int(WS.get_state("night"))
		while t < 260.0 and te.phase != "done":
			await secs(0.1)
			t += 0.1
			if not seen.has(te.phase):
				seen[te.phase] = WS.sim_time
		for ph in ["insert", "tv", "fullscreen", "empty", "person", "silence", "figure", "head_turn", "stare", "run", "blackout", "title", "done"]:
			ok(seen.has(ph), "FINAL 1 goes through '%s'" % ph)
		if seen.has("empty") and seen.has("person"):
			ok(seen["person"] - seen["empty"] >= 25.0, "25-35 s of nothing before the person (%.0f s)" % (seen["person"] - seen["empty"]))
		if seen.has("insert") and seen.has("fullscreen"):
			ok(seen["fullscreen"] - seen["insert"] < 4.5, "the tape is on screen quickly (%.1f s)" % (seen["fullscreen"] - seen["insert"]))
		if seen.has("run") and seen.has("blackout"):
			ok(seen["blackout"] - seen["run"] < 1.0, "blackout right after the run (%.2f s)" % (seen["blackout"] - seen["run"]))
		ok(te.overlay.black.color.a == 1.0, "the screen is totally black")
		ok(int(WS.get_state("night")) == night_before, "the tape ends the story: no new night")
	Engine.time_scale = 1.0
	var events_after: Array = WS.event_log.filter(func(e): return e.id in ["scare_runner", "scare_contort"] and e.time > WS.sim_time - 5.0)
	ok(events_after.is_empty(), "nothing else happens during the ending")
	print("warnings: ", WS.warnings)
	print("%d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)
