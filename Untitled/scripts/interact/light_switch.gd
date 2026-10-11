class_name LightSwitch
extends Interactable
## Wall switch controlling one or more LightFixtures by id.

var targets: PackedStringArray = []
var lever: MeshInstance3D


func setup(id: String, target_ids: PackedStringArray) -> void:
	register(id)
	targets = target_ids
	B.box(self, Vector3(0.075, 0.12, 0.01), Vector3.ZERO, Mats.m("plastic_beige"))
	lever = B.box(self, Vector3(0.014, 0.03, 0.014), Vector3(0, 0, 0.01), Mats.m("plastic_white"))
	B.interact_area(self, Vector3(0.16, 0.2, 0.12), Vector3(0, 0, 0.04))
	WorldState.state_changed.connect(_on_state)
	_update_lever.call_deferred()


func _is_on() -> bool:
	for t in targets:
		if WorldState.get_state("light/" + t, false):
			return true
	return false


func get_prompt() -> String:
	return "Switch"


var _dead_flip := false


func interact(_player: Node) -> void:
	if WorldState.get_state("power/out", false):
		# the switch moves. nothing happens.
		_dead_flip = not _dead_flip
		lever.position.y = 0.012 if _dead_flip else -0.012
		AudioManager.play_3d("switch_click", global_position, 0.0, randf_range(0.95, 1.08))
		WorldState.log_interaction("switch_dead", obj_id)
		return
	var new_state := not _is_on()
	for t in targets:
		var l = WorldState.get_obj(t)
		if l:
			l.set_on(new_state, true)
	AudioManager.play_3d("switch_click", global_position, 0.0, randf_range(0.95, 1.08))
	WorldState.log_interaction("switch", obj_id)
	_update_lever()


func _on_state(key: String, _v) -> void:
	if key.begins_with("light/") and key.substr(6) in targets:
		_update_lever()


func _update_lever() -> void:
	if lever:
		lever.position.y = 0.012 if _is_on() else -0.012
