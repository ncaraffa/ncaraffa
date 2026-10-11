class_name WindowSash
extends Interactable
## Lower sash of a double-hung window that slides up and down.

var sash: Node3D
var is_open := false
var travel := 0.45


func setup(id: String, width: float, height: float) -> void:
	register(id)
	sash = B.node(self, "Sash", Vector3.ZERO)
	var trim := Mats.m("trim")
	var h := height / 2.0
	B.box(sash, Vector3(width, 0.04, 0.04), Vector3(0, -h + 0.02, 0.05), trim)
	B.box(sash, Vector3(width, 0.04, 0.04), Vector3(0, -0.02, 0.05), trim)
	B.box(sash, Vector3(0.04, h, 0.04), Vector3(-width / 2 + 0.02, -h / 2, 0.05), trim)
	B.box(sash, Vector3(0.04, h, 0.04), Vector3(width / 2 - 0.02, -h / 2, 0.05), trim)
	B.box(sash, Vector3(width - 0.06, h - 0.06, 0.004), Vector3(0, -h / 2, 0.05), Mats.glass())
	B.box(sash, Vector3(0.1, 0.02, 0.03), Vector3(0, -h + 0.05, 0.08), Mats.m("chrome"))
	travel = h * 0.85
	B.interact_area(self, Vector3(width, height * 0.5, 0.2), Vector3(0, -h / 2, 0.08))
	_store()


func get_prompt() -> String:
	return "Close the window" if is_open else "Open the window"


func interact(_player: Node) -> void:
	set_open(not is_open)
	WorldState.set_state("task/last_action_time", WorldState.sim_time)
	WorldState.log_interaction("window", obj_id)


func set_open(v: bool, silent := false) -> void:
	is_open = v
	if not silent:
		AudioManager.play_3d("window_slide", global_position)
	var tw := create_tween()
	tw.tween_property(sash, "position:y", travel if v else 0.0, 0.0 if silent else 0.7).set_trans(Tween.TRANS_SINE)
	_store()


func _store() -> void:
	WorldState.set_state("window/" + obj_id + "/open", is_open)
