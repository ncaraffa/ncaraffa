class_name PictureFrame
extends Interactable
## Framed photo hanging on a wall. It can be nudged crooked (by the player or
## by something else) and stays exactly as it was left.

var frame: Node3D
var tilt := 0.0


func setup(id: String, photo_tex: String, size := Vector2(0.3, 0.38), frame_mat: Material = null) -> void:
	register(id)
	prompt = "Adjust"
	frame = B.node(self, "Frame", Vector3(0, 0, 0))
	var fm: Material = frame_mat if frame_mat else Mats.m("wood_dark")
	var t := 0.025
	B.box(frame, Vector3(size.x, t, 0.02), Vector3(0, -size.y / 2 + t / 2, 0.01), fm)
	B.box(frame, Vector3(size.x, t, 0.02), Vector3(0, size.y / 2 - t / 2, 0.01), fm)
	B.box(frame, Vector3(t, size.y, 0.02), Vector3(-size.x / 2 + t / 2, 0, 0.01), fm)
	B.box(frame, Vector3(t, size.y, 0.02), Vector3(size.x / 2 - t / 2, 0, 0.01), fm)
	B.quad(frame, size - Vector2(t, t) * 2, Vector3(0, 0, 0.006), Mats.picture(photo_tex))
	B.box(frame, Vector3(size.x, size.y, 0.004), Vector3(0, 0, 0.003), Mats.color(Color(0.2, 0.18, 0.15)))
	var a := B.interact_area(frame, Vector3(size.x, size.y, 0.06), Vector3(0, 0, 0.02))
	a.name = "Area"
	# frame hangs from a nail at the top: offset the pivot
	frame.position = Vector3(0, size.y / 2 - 0.02, 0)
	for c in frame.get_children():
		c.position.y -= size.y / 2 - 0.02
	_store()


func interact(_player: Node) -> void:
	if absf(tilt) > 1.5:
		set_tilt(0.0, true)
	else:
		set_tilt(randf_range(2.0, 4.0) * (1 if randf() < 0.5 else -1), true)
	WorldState.log_interaction("photo_adjust", obj_id)


func set_tilt(deg: float, animate := false) -> void:
	tilt = deg
	if animate:
		var tw := create_tween()
		tw.tween_property(frame, "rotation_degrees:z", deg, 0.35).set_trans(Tween.TRANS_SINE)
	else:
		frame.rotation_degrees.z = deg
	_store()


func _store() -> void:
	WorldState.set_state("photo/" + obj_id + "/tilt", snappedf(tilt, 0.1))
