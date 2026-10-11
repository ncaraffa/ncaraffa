class_name Mailbox
extends Interactable
## The house's mailbox at the curb. A raised flag means something arrived.

var flag: Node3D
var door_pivot: Node3D


func setup(id: String) -> void:
	register(id)
	B.box(self, Vector3(0.08, 1.05, 0.08), Vector3(0, 0.52, 0), Mats.m("wood_dark"), true)
	B.box(self, Vector3(0.24, 0.22, 0.48), Vector3(0, 1.15, 0), Mats.color(Color(0.18, 0.22, 0.2), 0.4, 0.5))
	door_pivot = B.node(self, "Door", Vector3(0, 1.04, 0.245))
	B.box(door_pivot, Vector3(0.23, 0.21, 0.01), Vector3(0, 0.11, 0), Mats.color(Color(0.16, 0.2, 0.18), 0.4, 0.5))
	flag = B.node(self, "Flag", Vector3(0.13, 1.12, -0.08))
	B.box(flag, Vector3(0.015, 0.2, 0.05), Vector3(0, 0.1, 0), Mats.color(Color(0.7, 0.1, 0.08), 0.5))
	B.label(self, "14", Vector3(0.123, 1.15, 0), 0.003, Color(0.9, 0.88, 0.8), Vector3(0, 90, 0), 32)
	B.interact_area(self, Vector3(0.4, 0.4, 0.7), Vector3(0, 1.15, 0))
	WorldState.state_changed.connect(func(k, _v):
		if k == "mail/text":
			_refresh())
	_refresh.call_deferred()


func _refresh() -> void:
	var has_mail: bool = String(WorldState.get_state("mail/text", "")) != ""
	flag.rotation_degrees.x = 0.0 if has_mail else 90.0


func get_prompt() -> String:
	return "Check the mail"


func interact(_player: Node) -> void:
	AudioManager.play_3d("mailbox", global_position + Vector3(0, 1.1, 0))
	var tw := create_tween()
	tw.tween_property(door_pivot, "rotation_degrees:x", 80.0, 0.3)
	tw.tween_interval(1.0)
	tw.tween_property(door_pivot, "rotation_degrees:x", 0.0, 0.3)
	var text := String(WorldState.get_state("mail/text", ""))
	var hud = WorldState.get_obj("hud")
	WorldState.set_state("task/last_action_time", WorldState.sim_time)
	if text == "":
		if hud:
			hud.thought("Empty.")
		return
	WorldState.set_state("mail/text", "")
	WorldState.set_state("mail/collected_n%d" % int(WorldState.get_state("night", 1)), true)
	var archive: Array = (WorldState.get_state("mail/archive", []) as Array).duplicate()
	archive.append(text)
	WorldState.set_state("mail/archive", archive)
	AudioManager.play_ui("paper")
	if hud:
		hud.show_note(text)
	WorldState.log_interaction("mail", obj_id)
