class_name ShadowFigure
extends Node3D
## A dark, roughly human figure. Built from simple parts (head, neck, torso,
## pelvis, two-segment arms and legs, long hands) and animated procedurally.
## Nobody explains what it is.
##
## States: HIDDEN, APPEARING, WATCHING, MOVING, RETREATING, VANISHING, SCARE.

signal finished_path
signal vanished

enum State { HIDDEN, APPEARING, WATCHING, MOVING, RETREATING, VANISHING, SCARE }

const HIP_Y := 0.98

var state := State.HIDDEN
var mat: ShaderMaterial
var shroud: ShaderMaterial
var parts: Dictionary = {}      # name -> Node3D pivot
var look_target: Node3D = null  # usually the player's camera
var head_tilt := 0.0
var stiff := false              # walk without swinging the arms (wrong)
var _t := 0.0
var _walk_phase := 0.0
var _path: PackedVector3Array = PackedVector3Array()
var _path_i := 0
var _speed := 1.2
var _dissolve := 1.0
var _dissolve_target := 1.0
var _dissolve_speed := 2.0
var _twitch_t := 0.0
var _lean := 0.0
var _arm_raise := 0.0
var _moving := false
## Head driven from outside (degrees, relative to the neck) instead of looking at a target.
var head_manual := false
var head_rot := Vector3.ZERO
## An ordinary person (coloured clothes, no smoke, no twitches). Used on the tape
## and for the neighbours coming home.
var is_person := false
var _sprint := false


func _ready() -> void:
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/shadow_figure.gdshader")
	shroud = ShaderMaterial.new()
	shroud.shader = load("res://shaders/shadow_shroud.gdshader")
	_build()
	visible = false
	_apply_dissolve()


# ------------------------------------------------------------------ model
func _capsule(parent: Node3D, r: float, h: float, pos: Vector3, scale := Vector3.ONE) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = max(h, r * 2.0 + 0.01)
	m.radial_segments = 12
	m.rings = 4
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = pos
	mi.scale = scale
	# smoky shell slightly larger than the body
	var sh := MeshInstance3D.new()
	sh.mesh = m
	sh.material_override = shroud
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(sh)
	sh.scale = Vector3.ONE * 1.09
	return mi


## A round joint that fills the gap between two segments, so elbows, knees and
## shoulders don't show as separate parts (no "wooden mannequin" look).
func _joint(parent: Node3D, r: float, pos := Vector3.ZERO) -> void:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 12
	m.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = pos
	var sh := MeshInstance3D.new()
	sh.mesh = m
	sh.material_override = shroud
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(sh)
	sh.scale = Vector3.ONE * 1.12


func _pivot(parent: Node3D, n: String, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.name = n
	parent.add_child(p)
	p.position = pos
	parts[n] = p
	return p


func _build() -> void:
	var hips := _pivot(self, "hips", Vector3(0, HIP_Y, 0))
	_capsule(hips, 0.14, 0.32, Vector3(0, 0.02, 0), Vector3(1.15, 0.8, 0.72))
	var spine := _pivot(hips, "spine", Vector3(0, 0.08, 0))
	_capsule(spine, 0.13, 0.42, Vector3(0, 0.2, 0), Vector3(1.0, 1.0, 0.72))      # waist
	_capsule(spine, 0.165, 0.42, Vector3(0, 0.44, 0), Vector3(1.2, 1.0, 0.7))     # chest
	_capsule(spine, 0.1, 0.46, Vector3(0, 0.56, -0.01), Vector3(1.8, 0.55, 0.65)) # shoulders
	# sloping shoulders (neck to shoulder), so the outline is a body, not a robot
	for sd: float in [-1.0, 1.0]:
		var trap := _capsule(spine, 0.065, 0.3, Vector3(sd * 0.11, 0.6, -0.01), Vector3(1.0, 1.0, 0.8))
		trap.rotation_degrees.z = sd * 68.0
	var neck := _pivot(spine, "neck", Vector3(0, 0.66, 0.02))
	_capsule(neck, 0.058, 0.22, Vector3(0, 0.08, 0))
	_capsule(spine, 0.15, 0.5, Vector3(0, 0.3, 0), Vector3(1.1, 1.0, 0.7))       # fills waist-to-chest
	var head := _pivot(neck, "head", Vector3(0, 0.17, 0.01))
	_capsule(head, 0.106, 0.27, Vector3(0, 0.1, 0.0), Vector3(0.92, 1.0, 1.04))
	for side: float in [-1.0, 1.0]:
		var sname := "l" if side < 0 else "r"
		var sh := _pivot(spine, sname + "_shoulder", Vector3(side * 0.235, 0.55, 0))
		_capsule(sh, 0.057, 0.4, Vector3(0, -0.2, 0))
		var el := _pivot(sh, sname + "_elbow", Vector3(0, -0.36, 0))
		_joint(el, 0.047)
		_capsule(el, 0.045, 0.42, Vector3(0, -0.19, 0))
		var hand := _pivot(el, sname + "_hand", Vector3(0, -0.38, 0))
		_joint(hand, 0.042)
		# long, narrow hands: the one detail that is slightly wrong
		_capsule(hand, 0.034, 0.28, Vector3(0, -0.12, 0.0), Vector3(1.25, 1.0, 0.55))
		var hip := _pivot(hips, sname + "_hip", Vector3(side * 0.1, -0.04, 0))
		_joint(hip, 0.085, Vector3(0, -0.02, 0))
		_capsule(hip, 0.082, 0.52, Vector3(0, -0.22, 0))
		var knee := _pivot(hip, sname + "_knee", Vector3(0, -0.46, 0))
		_joint(knee, 0.066)
		_capsule(knee, 0.064, 0.5, Vector3(0, -0.22, 0))
		var foot := _pivot(knee, sname + "_foot", Vector3(0, -0.46, 0))
		_capsule(foot, 0.045, 0.24, Vector3(0, -0.02, 0.06)).rotation_degrees.x = 90


# ------------------------------------------------------------------ control
func appear(pos: Vector3, facing: Vector3, fade := 0.0) -> void:
	global_position = pos
	face_dir(facing)
	visible = true
	state = State.APPEARING if fade > 0.0 else State.WATCHING
	_moving = false
	_path = PackedVector3Array()
	if fade > 0.0:
		_dissolve = 1.0
		_dissolve_target = 0.0
		_dissolve_speed = 1.0 / fade
	else:
		_dissolve = 0.0
		_dissolve_target = 0.0
	_apply_dissolve()
	WorldState.set_state("figure/" + name, "visible")


func vanish(mode := "instant", dur := 0.6) -> void:
	if state == State.HIDDEN:
		return
	match mode:
		"fade":
			state = State.VANISHING
			_dissolve_target = 1.0
			_dissolve_speed = 1.0 / max(0.05, dur)
		"flicker":
			state = State.VANISHING
			for i in 4:
				visible = not visible
				await get_tree().create_timer(randf_range(0.03, 0.09), false).timeout
			_hide()
		_:
			_hide()


func _hide() -> void:
	visible = false
	state = State.HIDDEN
	_dissolve = 1.0
	_dissolve_target = 1.0
	_moving = false
	_sprint = false
	head_manual = false
	_lean = 0.0
	_arm_raise = 0.0
	head_tilt = 0.0
	stiff = false
	set_rim(0.35)
	_apply_dissolve()
	WorldState.set_state("figure/" + name, "hidden")
	vanished.emit()


func face_dir(dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length() > 0.01:
		rotation.y = atan2(dir.x, dir.z)


func face_point(p: Vector3) -> void:
	face_dir(p - global_position)


func walk_path(points: PackedVector3Array, speed := 1.2, retreat := false) -> void:
	_path = points
	_path_i = 0
	_speed = speed
	_moving = true
	state = State.RETREATING if retreat else State.MOVING


## Sudden lunge towards a point (used by scares). Not a walk: a jerk.
func lunge(to: Vector3, dur := 0.22) -> void:
	state = State.SCARE
	_lean = 0.3
	_arm_raise = 0.35
	head_tilt = randf_range(22.0, 40.0) * (1.0 if randf() < 0.5 else -1.0)
	var tw := create_tween()
	tw.tween_property(self, "global_position", to, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func twitch() -> void:
	_twitch_t = 0.12


func is_visible_figure() -> bool:
	return state != State.HIDDEN and visible


func _apply_dissolve() -> void:
	mat.set_shader_parameter("dissolve", _dissolve)
	shroud.set_shader_parameter("dissolve", _dissolve)


## Brighter outline for moments that must read clearly (windows, darkness).
func set_rim(strength: float) -> void:
	mat.set_shader_parameter("rim_strength", strength)


## Turn this body into an ordinary person: shirt, trousers, skin, hair.
func make_person(shirt: Color, pants: Color, skin := Color(0.78, 0.6, 0.5), hair := Color(0.16, 0.11, 0.08)) -> void:
	is_person = true
	var m_shirt := Mats.color(shirt, 0.85)
	var m_pants := Mats.color(pants, 0.9)
	var m_skin := Mats.color(skin, 0.7)
	var m_hair := Mats.color(hair, 0.95)
	var m_shoe := Mats.color(Color(0.08, 0.07, 0.06), 0.6)
	for key in parts:
		var piv: Node3D = parts[key]
		var mat_for: Material = m_shirt
		if key in ["hips", "l_hip", "r_hip", "l_knee", "r_knee"]:
			mat_for = m_pants
		elif key in ["l_foot", "r_foot"]:
			mat_for = m_shoe
		elif key in ["neck", "head", "l_hand", "r_hand"]:
			mat_for = m_skin
		for c in piv.get_children():
			if c is MeshInstance3D:
				c.material_override = mat_for
				for sh in c.get_children():
					if sh is MeshInstance3D:
						sh.visible = false
	# hair: a cap over the back and top of the head
	var hm := SphereMesh.new()
	hm.radius = 0.11
	hm.height = 0.2
	var hair_mi := MeshInstance3D.new()
	hair_mi.mesh = hm
	hair_mi.material_override = m_hair
	parts.head.add_child(hair_mi)
	hair_mi.position = Vector3(0, 0.17, -0.025)
	hair_mi.scale = Vector3(1.0, 0.85, 1.08)
	# a loose shirt over the chest and waist, so the body reads as one piece
	var tm := CapsuleMesh.new()
	tm.radius = 0.18
	tm.height = 0.7
	var torso := MeshInstance3D.new()
	torso.mesh = tm
	torso.material_override = m_shirt
	parts.spine.add_child(torso)
	torso.position = Vector3(0, 0.33, 0.0)
	torso.scale = Vector3(1.12, 1.0, 0.74)
	for side in ["l", "r"]:
		var sm := CapsuleMesh.new()
		sm.radius = 0.062
		sm.height = 0.34
		var sleeve := MeshInstance3D.new()
		sleeve.mesh = sm
		sleeve.material_override = m_shirt
		parts[side + "_shoulder"].add_child(sleeve)
		sleeve.position = Vector3(0, -0.14, 0)


## Render layers of every mesh (e.g. visible only to a secondary camera).
func set_layers(mask: int) -> void:
	var stack: Array = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is VisualInstance3D:
			n.layers = mask
		stack.append_array(n.get_children())


## From complete stillness to right there. Not a walk: a violent rush.
func sprint(to: Vector3, dur := 0.28) -> Tween:
	state = State.SCARE
	_sprint = true
	_moving = false
	_lean = 0.55
	_arm_raise = 0.15
	head_manual = false
	var tw := create_tween()
	tw.tween_property(self, "global_position", to, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return tw


# ------------------------------------------------------------------ animation
func _process(delta: float) -> void:
	if state == State.HIDDEN:
		return
	_t += delta
	if _dissolve != _dissolve_target:
		_dissolve = move_toward(_dissolve, _dissolve_target, delta * _dissolve_speed)
		_apply_dissolve()
		if _dissolve >= 1.0 and state == State.VANISHING:
			_hide()
			return
		if _dissolve <= 0.0 and state == State.APPEARING:
			state = State.WATCHING
	if _moving:
		_step_path(delta)
	_animate(delta)


func _step_path(delta: float) -> void:
	if _path_i >= _path.size():
		_moving = false
		if state != State.SCARE:
			state = State.WATCHING
		finished_path.emit()
		return
	var target := _path[_path_i]
	var to := target - global_position
	to.y = 0.0
	var d := to.length()
	if d < 0.05:
		global_position = Vector3(target.x, target.y, target.z)
		_path_i += 1
		return
	var step: float = min(d, _speed * delta)
	global_position += to.normalized() * step
	global_position.y = lerp(global_position.y, target.y, 0.2)
	var want := atan2(to.x, to.z)
	rotation.y = lerp_angle(rotation.y, want, clamp(delta * 6.0, 0.0, 1.0))
	_walk_phase += delta * _speed * 4.6


func _animate(delta: float) -> void:
	var breath := sin(_t * 1.7) * 0.012
	parts.spine.scale = Vector3(1.0, 1.0 + breath, 1.0 + breath * 0.5)
	var sway := sin(_t * 0.6) * 0.8
	var walking := _moving or _sprint
	if _sprint:
		_walk_phase += delta * 38.0
	var sw := sin(_walk_phase) if walking else 0.0
	var amp := (52.0 if _sprint else 26.0) if walking else 0.0
	parts.l_hip.rotation_degrees.x = sw * amp
	parts.r_hip.rotation_degrees.x = -sw * amp
	parts.l_knee.rotation_degrees.x = max(0.0, -sw) * amp * 1.3 if walking else 2.0
	parts.r_knee.rotation_degrees.x = max(0.0, sw) * amp * 1.3 if walking else 2.0
	var arm_amp := 0.0 if stiff else amp * 0.7
	var raise := -_arm_raise * 70.0
	parts.l_shoulder.rotation_degrees = Vector3(-sw * arm_amp + raise - 6.0, 0, -3.0)
	parts.r_shoulder.rotation_degrees = Vector3(sw * arm_amp + raise - 4.0, 0, 5.0)
	parts.l_shoulder.position.y = 0.55
	parts.neck.rotation_degrees.x = 16.0 + _lean * 10.0
	parts.l_elbow.rotation_degrees.x = -8.0 - _arm_raise * 25.0
	parts.r_elbow.rotation_degrees.x = -8.0 - _arm_raise * 25.0
	parts.hips.position.y = HIP_Y + (absf(sw) * 0.03 if walking else 0.0)
	parts.spine.rotation_degrees = Vector3(7.0 + _lean * 40.0 + (4.0 if walking else 0.0), 0, sway * 0.6 - 1.5)
	# the head: slow look towards the target, optional tilt, rare twitches
	var head: Node3D = parts.head
	var neck: Node3D = parts.neck
	var yaw := 0.0
	var pitch := 0.0
	if look_target and is_instance_valid(look_target):
		var lp := neck.global_transform.affine_inverse() * look_target.global_position
		yaw = clamp(rad_to_deg(atan2(lp.x, lp.z)), -70.0, 70.0)
		pitch = clamp(rad_to_deg(atan2(-lp.y, Vector2(lp.x, lp.z).length())), -30.0, 30.0)
	if head_manual:
		head.rotation_degrees = head_rot
		return
	var cur := head.rotation_degrees
	var target := Vector3(pitch - 14.0, yaw, head_tilt + 5.0)
	head.rotation_degrees = cur.lerp(target, clamp(delta * 2.5, 0.0, 1.0))
	if is_person:
		return
	if _twitch_t > 0.0:
		_twitch_t -= delta
		head.rotation_degrees += Vector3(randf_range(-9, 9), randf_range(-14, 14), randf_range(-12, 12))
	elif randf() < delta * 0.08 and state == State.WATCHING:
		twitch()
