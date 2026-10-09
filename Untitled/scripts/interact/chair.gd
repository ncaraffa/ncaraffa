class_name MovableChair
extends Interactable
## A chair that can be pulled out / pushed in. Its placement is world state:
## events can leave it somewhere else and it will stay there.

var body: AnimatableBody3D
var home: Transform3D
var displaced := false


func setup(id: String) -> void:
	register(id)
	prompt = "Move"
	home = transform
	_store()


func interact(_player: Node) -> void:
	var target: Transform3D
	if displaced or not _is_home(transform):
		target = home
	else:
		target = home.translated_local(Vector3(0, 0, 0.38))
	slide_to(target, 0.5, true)
	WorldState.log_interaction("chair", obj_id)


func slide_to(target: Transform3D, dur := 0.5, scrape := true) -> void:
	var tw := create_tween()
	tw.tween_property(self, "transform", target, dur).set_trans(Tween.TRANS_SINE)
	if scrape:
		AudioManager.play_3d("door_creak", global_position + Vector3(0, 0.2, 0), -6.0, randf_range(1.9, 2.4))
	displaced = not _is_home(target)
	await tw.finished
	_store()


func _is_home(t: Transform3D) -> bool:
	return t.origin.distance_to(home.origin) < 0.05 and home.basis.get_rotation_quaternion().angle_to(t.basis.get_rotation_quaternion()) < 0.05


func _store() -> void:
	WorldState.set_state("obj/" + obj_id, {"pos": position.snapped(Vector3.ONE * 0.01), "rot_y": snappedf(rotation_degrees.y, 0.5)})
