extends SceneTree
## Renders reference screenshots (needs a real renderer, e.g. under Xvfb):
##   godot --path . -s tests/screenshots.gd -- out_dir
var shots := [
	["bedroom", "h", Vector3(1.35, 0.05, 1.3), -133.0, -6.0],
	["bedroom_desk", "h", Vector3(1.6, 0.05, 2.2), -150.0, -10.0],
	["hall", "h", Vector3(4.9, 0.05, 8.0), 0.0, -5.0],
	["living", "h", Vector3(8.6, 0.05, 10.2), -125.0, -8.0],
	["kitchen", "h", Vector3(11.6, 0.05, 5.6), -37.0, -12.0],
	["dining", "h", Vector3(10.6, 0.05, 5.8), 45.0, -12.0],
	["bath", "h", Vector3(4.9, 0.05, 2.5), -30.0, -15.0],
	["front_yard", "w", Vector3(-3.0, 0.1, -12.0), 10.0, 2.0],
	["court", "w", Vector3(4.0, 0.1, 10.0), 160.0, 4.0],
	["road", "w", Vector3(-4.8, 0.1, 30.0), 0.0, 2.0],
	["road_out", "w", Vector3(0.0, 0.1, 60.0), 180.0, 0.0],
	["backyard", "w", Vector3(-6.0, 0.1, -48.0), -30.0, 2.0],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "res://shots"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.get_node("GameManager").in_game = false
	var world: Node = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 10:
		await process_frame
	var ws = root.get_node("WorldState")
	var envm = world.get_node("EnvironmentManager")
	envm._fade = 0.0
	envm.post_mat.set_shader_parameter("fade", 0.0)
	var p = ws.player
	var house = ws.get_obj("house")
	var only := args.slice(1)
	for s in shots:
		if not only.is_empty() and not s[0] in only:
			continue
		p.global_position = house.to_global(s[2]) if s[1] == "h" else s[2]
		p.set_look(s[3], s[4])
		for i in 25:
			await process_frame
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(out + "/" + s[0] + ".png")
		print("shot ", s[0])
	quit()
