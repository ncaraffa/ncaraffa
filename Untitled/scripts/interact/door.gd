class_name Door
extends Interactable
## Hinged door. The node sits on the hinge at floor level; the panel extends
## along local +X. `swing` (+1/-1) chooses the side it opens to.

signal opened
signal closed

var pivot: Node3D
var body: AnimatableBody3D
var is_open := false
var open_angle := 92.0
var swing := 1.0
var duration := 0.9
var sound_open := "door_open"
var sound_close := "door_close"
var volume_db := -4.0
var _tween: Tween


func setup(id: String, width: float, height: float, thick: float, mat: Material, swing_sign: float,
		start_open := false, knob := true) -> void:
	register(id)
	swing = swing_sign
	pivot = Node3D.new()
	pivot.name = "Pivot"
	add_child(pivot)
	body = AnimatableBody3D.new()
	body.sync_to_physics = false
	body.collision_layer = B.LAYER_WORLD
	body.collision_mask = 0
	body.set_meta("surface", "wood")
	pivot.add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(width - 0.02, height - 0.02, thick)
	cs.shape = sh
	cs.position = Vector3(width / 2.0, height / 2.0, 0)
	body.add_child(cs)
	B.box(body, Vector3(width - 0.02, height - 0.02, thick), Vector3(width / 2.0, height / 2.0, 0), mat)
	# raised panels for a less flat look
	if height > 1.5:
		for i in 2:
			var py := height * (0.28 if i == 0 else 0.7)
			var ph := height * (0.36 if i == 0 else 0.42)
			for s: float in [-1.0, 1.0]:
				B.box(body, Vector3(width * 0.62, ph * 0.8, 0.012), Vector3(width / 2.0, py, s * (thick / 2.0 + 0.004)), mat)
	if knob:
		for s: float in [-1.0, 1.0]:
			B.sphere(body, 0.03, Vector3(width - 0.08, 0.98, s * (thick / 2.0 + 0.04)), Mats.m("chrome"))
			B.cyl(body, 0.012, 0.012, 0.05, Vector3(width - 0.08, 0.98, s * (thick / 2.0 + 0.02)), Mats.m("chrome"), false, Vector3(90, 0, 0), 8)
	is_open = start_open
	pivot.rotation_degrees.y = open_angle * swing if is_open else 0.0
	_sync_state()


func get_prompt() -> String:
	return "Close" if is_open else "Open"


func interact(_player: Node) -> void:
	set_open(not is_open)
	WorldState.log_interaction("door", obj_id)


func set_open(value: bool, silent := false, speed := 1.0) -> void:
	if value == is_open:
		return
	is_open = value
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	var target := open_angle * swing if is_open else 0.0
	_tween.tween_property(pivot, "rotation_degrees:y", target, duration / speed) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT if is_open else Tween.EASE_IN)
	if not silent:
		var mid := global_transform * Vector3(0.45, 1.0, 0)
		if is_open:
			AudioManager.play_3d(sound_open, mid, volume_db, randf_range(0.93, 1.05), 4.0)
		else:
			_tween.tween_callback(func(): AudioManager.play_3d(sound_close, mid, volume_db, randf_range(0.95, 1.05), 4.0))
	_sync_state()
	if is_open:
		opened.emit()
	else:
		closed.emit()


## Small unexplained movement (used by ambience/events): the door drifts a little.
func drift(angle: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(pivot, "rotation_degrees:y", angle * swing, 2.5).set_trans(Tween.TRANS_SINE)
	is_open = absf(angle) > 4.0
	_sync_state()


func _sync_state() -> void:
	if obj_id != "":
		WorldState.set_state("door/" + obj_id, is_open)
