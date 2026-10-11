class_name Bed
extends Interactable
## Lie down and sleep: the night ends (only once the essential chores are done).


func setup(id: String, size: Vector3) -> void:
	register(id)
	B.interact_area(self, size, Vector3(0, size.y / 2.0, 0))


func get_prompt() -> String:
	return "Sleep"


func interact(_player: Node) -> void:
	var nm = WorldState.get_obj("night_manager")
	if nm:
		nm.request_sleep()
