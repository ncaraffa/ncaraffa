class_name GarageDoor
extends Interactable
## Tilt-up garage door hinged at the top of the opening.

var pivot: Node3D
var is_open := false
var _busy := false
var _height := 2.3


func setup(id: String, width: float, height: float, mat: Material) -> void:
	register(id)
	_height = height
	pivot = B.node(self, "Pivot", Vector3(0, height, 0))
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	body.collision_layer = B.LAYER_WORLD
	pivot.add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(width, height, 0.06)
	cs.shape = sh
	cs.position = Vector3(0, -height / 2, 0)
	body.add_child(cs)
	B.box(body, Vector3(width, height, 0.05), Vector3(0, -height / 2, 0), mat)
	for i in 4:
		B.box(body, Vector3(width, 0.02, 0.06), Vector3(0, -height * (i + 1) / 5.0, 0), Mats.color(Color(0.7, 0.7, 0.68), 0.6))
	B.box(body, Vector3(0.3, 0.04, 0.05), Vector3(0, -height + 0.2, 0.05), Mats.m("metal_dark"))
	# the opening itself can be used to pull it down again when it is up
	B.interact_area(self, Vector3(width - 0.2, height - 0.3, 0.15), Vector3(0, height / 2.0, -0.1))
	WorldState.set_state("door/" + id, false)


func get_prompt() -> String:
	return "" if _busy else ("Close" if is_open else "Open")


func interact(_player: Node) -> void:
	if _busy:
		return
	_busy = true
	is_open = not is_open
	var snd := AudioManager.play_3d("garage_door", global_position + Vector3(0, 1.5, 0))
	var tw := create_tween()
	tw.tween_property(pivot, "rotation_degrees:x", -88.0 if is_open else 0.0, 3.5).set_trans(Tween.TRANS_SINE)
	await tw.finished
	if is_instance_valid(snd):
		snd.stop()
		snd.queue_free()
	AudioManager.play_3d("thud", global_position + Vector3(0, 1.0, 0), -2.0, 0.7)
	_busy = false
	WorldState.set_state("door/" + obj_id, is_open)
	WorldState.log_interaction("garage_door", obj_id)


## Instant state change (used when a new night begins).
func set_open_instant(v: bool) -> void:
	is_open = v
	pivot.rotation_degrees.x = -88.0 if v else 0.0
	WorldState.set_state("door/" + obj_id, is_open)


class OpenerButton extends Interactable:
	## Wall button by the kitchen door: opens/closes the garage door.
	var door: GarageDoor

	func setup_button(target: GarageDoor) -> void:
		door = target
		B.box(self, Vector3(0.08, 0.12, 0.02), Vector3(0, 0, 0.01), Mats.m("plastic_white"))
		B.box(self, Vector3(0.035, 0.035, 0.015), Vector3(0, 0.015, 0.025), Mats.emissive(Color(0.9, 0.5, 0.2), 1.5))
		B.interact_area(self, Vector3(0.16, 0.2, 0.1), Vector3(0, 0, 0.04))

	func get_prompt() -> String:
		var p := door.get_prompt()
		return "" if p == "" else p + " the garage"

	func interact(player: Node) -> void:
		AudioManager.play_3d("switch_click", global_position)
		door.interact(player)
