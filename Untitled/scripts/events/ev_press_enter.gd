extends MysteryEvent
## EVENT 10 — PRESS ENTER. The Enter key does nothing. Spelling it does.
## The clue (someone who spells commands out loud) is on the fridge letter,
## available from the start regardless of event order.

var solved := false


func _init() -> void:
	id = "press_enter"
	title = "PRESS ENTER"
	resources = ["computer"]
	kinds = ["persistent", "reactive"]
	repeatable = false


func _start() -> void:
	var comp := WorldState.get_obj("computer") as Computer
	if comp == null:
		finish()
		return
	if not comp.power:
		AudioManager.play_3d("crt_on", comp.global_position + Vector3(0, 0.3, 0))
	comp.terminal.show_press_enter()
	if not comp.terminal.spelled_enter.is_connected(_on_spelled):
		comp.terminal.spelled_enter.connect(_on_spelled)
	WorldState.set_state("computer/press_enter", true)
	record("shown")
	finish()


func _on_spelled() -> void:
	if solved:
		return
	solved = true
	var comp := WorldState.get_obj("computer") as Computer
	WorldState.set_state("computer/press_enter", false)
	WorldState.set_state("computer/enter_spelled", true)
	WorldState.log_event("press_enter", "spelled")
	comp.terminal.play_message(["OK.", "", "the kitchen clock is right."])
	# Somewhere else in the house, a light goes out. A switch clicks.
	var choices := [["hall_ceiling", "sw_hall"], ["living_floorlamp", ""], ["porch_front", "sw_porch"], ["kitchen_sink", ""]]
	for c in choices:
		var l := WorldState.get_obj(c[0]) as LightFixture
		if l and l.is_on:
			await wait(2.2)
			l.set_on(false, true)
			var sw: Node3D = l
			if c[1] != "":
				sw = WorldState.get_obj(c[1]) as Node3D
			if sw:
				AudioManager.play_3d("switch_click", sw.global_position, 0.0, 0.9)
			WorldState.set_state("consequence/enter_light", c[0])
			break
	# And, far away outside, someone spells another word.
	await wait(9.0)
	var nh := WorldState.get_obj("neighbor_whitcomb") as Node3D
	var pos := nh.global_position + Vector3(0, 1.6, 0) if nh else Vector3(20, 1.6, 10)
	AudioManager.play_3d("voice_spell", pos, 0.0, 1.0)
