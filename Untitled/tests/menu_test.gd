extends SceneTree
## Menu -> PLAY -> world flow, then pause -> leave back to the menu.
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/main_menu.tscn")
	for i in 10:
		await process_frame
	var menu = current_scene
	print("menu loaded: ", menu.name, " children: ", menu.get_child_count())
	menu._on_play()
	await create_timer(2.5).timeout
	for i in 10:
		await process_frame
	print("scene after PLAY: ", current_scene.name)
	var ok1: bool = current_scene.name == "World"
	await create_timer(2.0).timeout
	root.get_node("GameManager").return_to_menu()
	for i in 10:
		await process_frame
	print("scene after leave: ", current_scene.name)
	var ok2: bool = current_scene.name == "MainMenu"
	# play again: the world must rebuild cleanly from a fresh state
	current_scene._on_play()
	await create_timer(2.5).timeout
	for i in 10:
		await process_frame
	var ws = root.get_node("WorldState")
	var ok3: bool = current_scene.name == "World" and ws.get_obj("house") != null and ws.event_log.is_empty()
	print("second run ok: ", ok3, "  warnings: ", ws.warnings)
	print("MENU FLOW ", "PASS" if ok1 and ok2 and ok3 else "FAIL")
	quit(0 if ok1 and ok2 and ok3 else 1)
