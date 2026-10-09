class_name TrashCan
extends Interactable
## Kitchen trash can. When full, the bag can be pulled out and carried.

var lid: Node3D
var bag_mesh: MeshInstance3D


func setup(id: String) -> void:
	register(id)
	B.cyl(self, 0.18, 0.16, 0.6, Vector3(0, 0.3, 0), Mats.color(Color(0.8, 0.8, 0.77), 0.5), true, Vector3.ZERO, 16)
	lid = B.node(self, "Lid", Vector3(0, 0.61, 0))
	B.cyl(lid, 0.185, 0.185, 0.03, Vector3.ZERO, Mats.color(Color(0.7, 0.7, 0.68), 0.4), false, Vector3.ZERO, 16)
	bag_mesh = B.sphere(self, 0.17, Vector3(0, 0.62, 0), Mats.color(Color(0.05, 0.05, 0.06), 0.3), Vector3(1.0, 0.4, 1.0))
	B.interact_area(self, Vector3(0.45, 0.8, 0.45), Vector3(0, 0.4, 0))
	WorldState.state_changed.connect(func(k, _v):
		if k == "trash/full":
			_refresh())
	_refresh.call_deferred()


func _refresh() -> void:
	var full: bool = WorldState.get_state("trash/full", false)
	bag_mesh.visible = full
	lid.position.y = 0.66 if full else 0.61


func get_prompt() -> String:
	return "Take out the bag" if WorldState.get_state("trash/full", false) else ""


func interact(player: Node) -> void:
	if not WorldState.get_state("trash/full", false):
		return
	WorldState.set_state("trash/full", false)
	WorldState.set_state("task/last_action_time", WorldState.sim_time)
	AudioManager.play_3d("trash_bag", global_position + Vector3(0, 0.6, 0))
	var bag := TrashBag.new()
	bag.name = "TrashBag"
	get_tree().current_scene.add_child(bag)
	bag.global_position = global_position + Vector3(0, 0.8, 0)
	bag.build()
	if player.has_method("hold"):
		player.hold(bag)
	WorldState.log_interaction("trash_take", obj_id)


class TrashBag extends Pickup:
	func build() -> void:
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.2
		cs.shape = sh
		cs.position.y = 0.2
		add_child(cs)
		B.sphere(self, 0.21, Vector3(0, 0.2, 0), Mats.color(Color(0.04, 0.04, 0.05), 0.25), Vector3(1.0, 1.15, 0.9))
		B.cyl(self, 0.03, 0.06, 0.12, Vector3(0, 0.45, 0), Mats.color(Color(0.04, 0.04, 0.05), 0.25))
		setup("trash_bag_%d" % Time.get_ticks_usec(), 2.0)


	func get_prompt() -> String:
		return "" if held else "Pick up the bag"
