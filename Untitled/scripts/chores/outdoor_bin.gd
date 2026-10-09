class_name OutdoorBin
extends Interactable
## Wheelie bin by the garage. Accepts the trash bag.

var lid: Node3D


func setup(id: String, col: Color) -> void:
	register(id)
	B.box(self, Vector3(0.6, 1.0, 0.7), Vector3(0, 0.5, 0), Mats.color(col, 0.6), true)
	lid = B.node(self, "Lid", Vector3(0, 1.02, -0.35))
	B.box(lid, Vector3(0.64, 0.05, 0.74), Vector3(0, 0, 0.37), Mats.color(col.darkened(0.25), 0.6))
	for x: float in [-0.25, 0.25]:
		B.cyl(self, 0.09, 0.09, 0.05, Vector3(x, 0.09, -0.36), Mats.m("rubber"), false, Vector3(0, 0, 90), 10)
	B.interact_area(self, Vector3(0.7, 1.15, 0.8), Vector3(0, 0.55, 0))


func accepts(item) -> bool:
	return item is TrashCan.TrashBag


func get_prompt() -> String:
	var p = WorldState.player
	if p and p.held is TrashCan.TrashBag:
		return "Throw the bag away"
	return ""


func interact(player: Node) -> void:
	var bag = player.held
	if not bag is TrashCan.TrashBag:
		return
	player.drop()
	bag.queue_free()
	var tw := create_tween()
	tw.tween_property(lid, "rotation_degrees:x", -100.0, 0.25)
	tw.tween_interval(0.35)
	tw.tween_property(lid, "rotation_degrees:x", 0.0, 0.18)
	tw.tween_callback(func(): AudioManager.play_3d("bin_lid", global_position + Vector3(0, 1, 0)))
	AudioManager.play_3d("trash_bag", global_position + Vector3(0, 1, 0))
	WorldState.set_state("trash/out", true)
	WorldState.set_state("task/last_action_time", WorldState.sim_time)
	WorldState.log_interaction("trash_out", obj_id)
