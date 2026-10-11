class_name WatchingEye
extends Node3D
## An eye (or a pair of eyes) in the dark that follows you. The iris tracks the
## player's camera; the whole thing turns slowly, like a head would; it blinks.
## It closes and is gone when you come too close, or when it is told to.

signal closed

var mat: ShaderMaterial
var quads: Array = []
var target: Node3D = null
var size := 0.12
var turn_speed := 1.5
var dilate_base := 1.0
var blinks := true
var _blink_t := 3.0
var _open := 0.0
var _open_target := 1.0
var _closing := false


## pair: two eyes `spacing` apart; otherwise one big eye.
func setup(eye_size: float, pair := true, spacing := 0.16) -> void:
	size = eye_size
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/eye.gdshader")
	mat.set_shader_parameter("open", 0.0)
	var offsets := [Vector3(-spacing / 2.0, 0, 0), Vector3(spacing / 2.0, 0, 0)] if pair else [Vector3.ZERO]
	for o: Vector3 in offsets:
		var q := QuadMesh.new()
		q.size = Vector2(eye_size * 2.0, eye_size * 2.0)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.position = o
		quads.append(mi)
	target = WorldState.player.camera if WorldState.player else null
	_blink_t = randf_range(2.0, 5.0)


## Use an existing surface (the TV screen) instead of floating quads.
func setup_on(mesh: MeshInstance3D) -> void:
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/eye.gdshader")
	mat.set_shader_parameter("surround", 1.0)
	mat.set_shader_parameter("open", 0.0)
	mesh.material_override = mat
	quads.append(mesh)
	target = WorldState.player.camera if WorldState.player else null


func close_and_free(dur := 0.25) -> void:
	if _closing:
		return
	_closing = true
	_open_target = 0.0
	await get_tree().create_timer(dur + 0.1, false).timeout
	closed.emit()
	queue_free()


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var cam := target.global_position
	# the head turns, slowly, to keep you in front of it
	if quads.size() > 1 or quads[0].get_parent() == self:
		var to := cam - global_position
		to.y = 0.0
		if to.length() > 0.05:
			var want := atan2(to.x, to.z)
			rotation.y = lerp_angle(rotation.y, want, clampf(delta * turn_speed, 0.0, 1.0))
	# the eyes follow you exactly
	var ref: Node3D = quads[0]
	var lp: Vector3 = ref.global_transform.affine_inverse() * cam
	var depth := maxf(absf(lp.z), 0.4)
	var look := Vector2(clampf(lp.x / depth * 1.3, -1.0, 1.0), clampf(lp.y / depth * 1.6, -1.0, 1.0))
	mat.set_shader_parameter("look", look)
	mat.set_shader_parameter("dilate", dilate_base + 0.08 * sin(Time.get_ticks_msec() * 0.0013))
	# blinking
	if not _closing and blinks:
		_blink_t -= delta
		if _blink_t <= 0.0:
			_blink_t = randf_range(2.5, 6.5)
			_open_target = 0.0
		elif _open <= 0.02 and _open_target == 0.0:
			_open_target = 1.0
	_open = move_toward(_open, _open_target, delta * (9.0 if _open_target == 0.0 else 4.0))
	mat.set_shader_parameter("open", _open)
