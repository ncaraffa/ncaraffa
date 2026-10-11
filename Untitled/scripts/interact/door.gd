class_name Door
extends Interactable
## Hinged door. The node sits on the hinge at floor level; the panel extends
## along local +X. `swing` (+1/-1) chooses the side it opens to.

signal opened
signal closed
## Emitted when the player (not the world) opens the door. Used by scares.
signal player_opened(player: Node)

var pivot: Node3D
var body: AnimatableBody3D
var is_open := false
var open_angle := 92.0
var swing := 1.0
var duration := 0.9
var sound_open := "door_open"
var sound_close := "door_close"
var volume_db := 0.0
var locked := false
## Local Z sign of the "inside" face (only meaningful for lockable doors).
var inside_sign := 1.0
var lockable := false
var width := 0.9
var _tween: Tween
var _clear_check := 0.0


func setup(id: String, width: float, height: float, thick: float, mat: Material, swing_sign: float,
		start_open := false, knob := true) -> void:
	register(id)
	swing = swing_sign
	self.width = width
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
	# The doorway itself is part of the door: an open door seen edge-on from the
	# other side can still be grabbed and closed (from either side).
	B.interact_area(self, Vector3(width - 0.12, 1.2, 0.1), Vector3(width / 2.0, 1.15, 0))
	is_open = start_open
	pivot.rotation_degrees.y = open_angle * swing if is_open else 0.0
	_sync_state()


func get_prompt() -> String:
	if locked and not is_open:
		return "Unlock" if _player_inside_side() else "Locked"
	return "Close" if is_open else "Open"


## Which face of the door the player is on (works from both sides).
func _player_inside_side() -> bool:
	var p = WorldState.player
	if p == null:
		return true
	return signf(to_local(p.global_position).z) == inside_sign


func interact(player: Node) -> void:
	if locked and not is_open:
		if _player_inside_side():
			set_locked(false)
		else:
			AudioManager.play_3d("door_rattle", global_transform * Vector3(width - 0.1, 1.0, 0), 0.0, randf_range(0.95, 1.05))
		WorldState.log_interaction("door_locked", obj_id)
		return
	set_open(not is_open)
	if is_open:
		player_opened.emit(player)
	WorldState.log_interaction("door", obj_id)


func set_locked(value: bool) -> void:
	if not lockable or value == locked:
		return
	if value and is_open:
		return
	locked = value
	AudioManager.play_3d("lock_click", global_transform * Vector3(width - 0.1, 1.0, 0), 0.0, randf_range(0.95, 1.05))
	WorldState.set_state("lock/" + obj_id, locked)


func set_open(value: bool, silent := false, speed := 1.0) -> void:
	if value == is_open:
		return
	if value and locked:
		return
	is_open = value
	if _tween and _tween.is_valid():
		_tween.kill()
	# The panel never shoves the player into a wall: while it swings it does not
	# collide, and it only becomes solid again once nobody stands in its way.
	body.collision_layer = 0
	_clear_check = 0.0
	_tween = create_tween()
	var target := open_angle * swing if is_open else 0.0
	_tween.tween_property(pivot, "rotation_degrees:y", target, duration / speed) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT if is_open else Tween.EASE_IN)
	if not silent:
		var mid := global_transform * Vector3(0.45, 1.0, 0)
		if is_open:
			AudioManager.play_3d(sound_open, mid, volume_db, randf_range(0.93, 1.05))
		else:
			_tween.tween_callback(func(): AudioManager.play_3d(sound_close, mid, volume_db, randf_range(0.95, 1.05)))
	_tween.tween_callback(_try_solidify)
	_sync_state()
	if is_open:
		opened.emit()
	else:
		closed.emit()


func _try_solidify() -> void:
	if _overlaps_player():
		_clear_check = 0.15
		return
	body.collision_layer = B.LAYER_WORLD


func _overlaps_player() -> bool:
	var p = WorldState.player
	if p == null or not is_instance_valid(p):
		return false
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var cs: CollisionShape3D = body.get_child(0)
	q.shape = cs.shape
	q.transform = cs.global_transform
	q.collision_mask = 0xFFFFFFFF
	q.margin = 0.03
	for hit in space.intersect_shape(q, 8):
		if hit.collider == p:
			return true
	return false


func _physics_process(delta: float) -> void:
	if _clear_check > 0.0:
		_clear_check -= delta
		if _clear_check <= 0.0:
			_try_solidify()


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
