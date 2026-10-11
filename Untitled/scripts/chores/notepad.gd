class_name Notepad
extends Interactable
## The list of things to do tonight. Once taken, Tab reads it anywhere.


func setup(id: String) -> void:
	register(id)
	B.box(self, Vector3(0.1, 0.012, 0.14), Vector3(0, 0.006, 0), Mats.color(Color(0.95, 0.92, 0.7), 0.9))
	B.box(self, Vector3(0.1, 0.004, 0.012), Vector3(0, 0.013, -0.064), Mats.color(Color(0.6, 0.15, 0.1), 0.6))
	for i in 5:
		B.box(self, Vector3(0.06, 0.0006, 0.003), Vector3(-0.005, 0.0125, -0.04 + i * 0.02), Mats.color(Color(0.2, 0.25, 0.5), 0.9))
	B.interact_area(self, Vector3(0.2, 0.08, 0.22), Vector3(0, 0.02, 0))


func get_prompt() -> String:
	return "Take the list"


func interact(player: Node) -> void:
	WorldState.set_state("player/has_list", true)
	AudioManager.play_ui("paper")
	visible = false
	var tm = WorldState.get_obj("tasks")
	var hud = WorldState.get_obj("hud")
	if tm and hud:
		hud.show_list(tm.list_bbcode())
	process_mode = Node.PROCESS_MODE_DISABLED
	for c in get_children():
		if c is Area3D:
			c.collision_layer = 0
