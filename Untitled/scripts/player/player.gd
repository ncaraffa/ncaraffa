class_name Player
extends CharacterBody3D
## PlayerController + InteractionSystem.
## WASD / mouse / Shift run / Ctrl crouch / E interact / Esc pause.

const WALK_SPEED := 1.85
const RUN_SPEED := 3.5
const CROUCH_SPEED := 0.95
const ACCEL := 8.0
const DECEL := 10.0
const EYE_HEIGHT := 1.62
const CROUCH_EYE := 1.05
const STEP_HEIGHT := 0.36
const REACH := 2.1

var head: Node3D
var camera: Camera3D
var steps: AudioStreamPlayer
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var _yaw := 0.0
var _pitch := 0.0
var _bob_t := 0.0
var _stride := 0.0
var _eye := EYE_HEIGHT
var _was_on_floor := true
var _air_time := 0.0

var looked_at: Node = null       # current interactable under the crosshair
var held: Pickup = null
var focus_target: Node = null    # e.g. the computer
var _focus_tween: Tween
var _cam_home := Transform3D()
var controls_enabled := true


func _ready() -> void:
	collision_layer = 0
	collision_mask = B.LAYER_WORLD
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.3
	safe_margin = 0.02
	var cs := CollisionShape3D.new()
	# a cylinder (flat bottom) makes stepping onto curbs/porches reliable
	var cap := CylinderShape3D.new()
	cap.radius = 0.28
	cap.height = 1.72
	cs.shape = cap
	cs.position.y = 0.86
	add_child(cs)
	head = Node3D.new()
	head.name = "Head"
	head.position.y = EYE_HEIGHT
	add_child(head)
	camera = Camera3D.new()
	camera.near = 0.04
	camera.far = 450.0
	camera.fov = GameManager.settings.fov
	camera.current = true
	head.add_child(camera)
	_cam_home = camera.transform
	steps = AudioStreamPlayer.new()
	steps.bus = "World"
	steps.volume_db = -13.0
	add_child(steps)
	_yaw = rotation.y
	rotation = Vector3.ZERO
	WorldState.player = self
	GameManager.settings_changed.connect(func(): camera.fov = GameManager.settings.fov)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func set_look(yaw_deg: float, pitch_deg := 0.0) -> void:
	_yaw = deg_to_rad(yaw_deg)
	_pitch = deg_to_rad(pitch_deg)


func _hud() -> Node:
	return WorldState.get_obj("hud")


func is_busy() -> bool:
	var hud = _hud()
	return focus_target != null or (hud != null and hud.is_reading())


# ------------------------------------------------------------------ input
func _input(event: InputEvent) -> void:
	if focus_target == null:
		return
	if event is InputEventKey:
		if event.pressed and event.physical_keycode == KEY_ESCAPE:
			end_focus()
		elif focus_target.has_method("handle_key"):
			focus_target.handle_key(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		end_focus()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	var hud = _hud()
	if hud and hud.is_reading():
		if event.is_action_pressed("interact") or event.is_action_pressed("pause"):
			hud.close_note()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and focus_target == null:
		var sens: float = GameManager.settings.mouse_sensitivity
		_yaw -= event.relative.x * sens
		var inv := -1.0 if GameManager.settings.invert_y else 1.0
		_pitch = clamp(_pitch - event.relative.y * sens * inv, deg_to_rad(-86), deg_to_rad(86))
	elif event.is_action_pressed("interact") and focus_target == null:
		_do_interact()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _do_interact() -> void:
	if held:
		drop()
		return
	if looked_at and is_instance_valid(looked_at):
		looked_at.interact(self)


# ------------------------------------------------------------------ movement
func _physics_process(delta: float) -> void:
	head.rotation = Vector3(_pitch, _yaw, 0)
	var busy := is_busy() or not controls_enabled
	var input_dir := Vector2.ZERO
	if not busy:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var crouch := not busy and Input.is_action_pressed("crouch")
	var running := not crouch and Input.is_action_pressed("run") and input_dir.y < 0.2
	var speed := CROUCH_SPEED if crouch else (RUN_SPEED if running else WALK_SPEED)
	var basis_y := Basis(Vector3.UP, _yaw)
	var wish := (basis_y * Vector3(input_dir.x, 0, input_dir.y))
	if wish.length() > 1.0:
		wish = wish.normalized()
	var target := wish * speed
	var hv := Vector3(velocity.x, 0, velocity.z)
	var rate := ACCEL if target.length() > hv.length() else DECEL
	hv = hv.move_toward(target, rate * speed * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if is_on_floor():
		velocity.y = -0.5
		_air_time = 0.0
	else:
		velocity.y -= gravity * delta
		_air_time += delta
	var pre_vel := velocity
	move_and_slide()
	if hv.length() > 0.1 and (is_on_wall() or get_slide_collision_count() > 0) and _air_time < 0.2:
		_try_step(pre_vel, delta)
	# landing sound
	if is_on_floor() and not _was_on_floor and _air_time > 0.25:
		_footstep(1.3)
	_was_on_floor = is_on_floor()
	_head_motion(delta, hv.length(), running, crouch)
	_update_interaction()
	_update_held(delta)
	# world bookkeeping
	var house = WorldState.get_obj("house")
	if house:
		WorldState.player_inside = house.contains_point(global_position + Vector3(0, 1.0, 0))
	if global_position.y < -20.0:
		global_position = Vector3(0, 2, 0)  # safety net, should never happen


## Climbs curbs, porch steps and door thresholds.
func _try_step(vel: Vector3, delta: float) -> void:
	var horiz := Vector3(vel.x, 0, vel.z) * delta
	if horiz.length() < 0.0005:
		return
	horiz = horiz.normalized() * max(horiz.length(), 0.06)
	var start := global_transform
	var up := Vector3(0, STEP_HEIGHT, 0)
	if test_move(start, up):
		return
	var raised := start.translated(up)
	if test_move(raised, horiz):
		return
	var moved := raised.translated(horiz)
	var col := KinematicCollision3D.new()
	if test_move(moved, -up, col):
		var landed := moved.translated(col.get_travel())
		if col.get_normal().y > 0.7 and landed.origin.y - start.origin.y > 0.02:
			global_transform = landed
			velocity.y = 0.0


func _head_motion(delta: float, speed: float, running: bool, crouch: bool) -> void:
	_eye = move_toward(_eye, CROUCH_EYE if crouch else EYE_HEIGHT, delta * 2.5)
	var on_floor := is_on_floor()
	if on_floor and speed > 0.3:
		var freq := 1.9 if running else 1.45
		_bob_t += delta * freq * TAU * (speed / (RUN_SPEED if running else WALK_SPEED))
		_stride += speed * delta
		var stride_len := 0.95 if running else 0.72
		if _stride >= stride_len:
			_stride = 0.0
			_footstep(1.0 if not crouch else 0.5)
	else:
		_bob_t = lerp(_bob_t, round(_bob_t / PI) * PI, delta * 4.0)
	var amp := 0.032 if running else 0.018
	if crouch:
		amp = 0.01
	var bob_y: float = sin(_bob_t * 2.0) * amp * clampf(speed, 0.0, 1.0)
	var bob_x: float = cos(_bob_t) * amp * 0.6 * clampf(speed, 0.0, 1.0)
	head.position = Vector3(bob_x, _eye + bob_y, 0)


func _surface() -> String:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.3, 0), global_position + Vector3(0, -0.4, 0), B.LAYER_WORLD)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return "grass"
	var c: Object = hit.collider
	if c and c.has_meta("surface"):
		var surf := String(c.get_meta("surface"))
		if surf == "ground":
			var nb = WorldState.get_obj("neighborhood")
			return nb.surface_at(global_position) if nb else "grass"
		return surf
	return "wood" if WorldState.player_inside else "grass"


func _footstep(intensity: float) -> void:
	var s := _surface()
	var prefix := "step_wood"
	var vol := -13.0
	match s:
		"tile":
			prefix = "step_tile"
			vol = -15.0
		"grass":
			prefix = "step_grass"
			vol = -11.0
		"concrete", "asphalt":
			prefix = "step_concrete"
			vol = -14.0
		"carpet":
			prefix = "step_grass"
			vol = -20.0
	steps.stream = AudioManager.variant(prefix, 4)
	steps.volume_db = vol + linear_to_db(intensity)
	steps.pitch_scale = randf_range(0.92, 1.08)
	steps.play()


# ------------------------------------------------------------------ interaction
func _update_interaction() -> void:
	var hud = _hud()
	if is_busy():
		looked_at = null
		if hud:
			hud.set_prompt("")
		return
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, B.LAYER_WORLD | B.LAYER_INTERACT | B.LAYER_PROPS)
	q.collide_with_areas = true
	q.exclude = [get_rid()]
	if held:
		q.exclude = [get_rid(), held.get_rid()]
	var hit := space.intersect_ray(q)
	var found: Node = null
	if not hit.is_empty():
		var n: Node = hit.collider
		var depth := 0
		while n and depth < 6:
			if n.has_method("interact") and n.has_method("get_prompt"):
				found = n
				break
			n = n.get_parent()
			depth += 1
	looked_at = found
	if hud:
		if held:
			hud.set_prompt("Put down")
		elif found:
			hud.set_prompt(found.get_prompt())
		else:
			hud.set_prompt("")


func hold(p: Pickup) -> void:
	if held:
		drop()
	held = p
	p.on_held(true)
	p.sleeping = false


func drop() -> void:
	if held and is_instance_valid(held):
		held.on_held(false)
		held.linear_velocity = held.linear_velocity.limit_length(1.0)
	held = null


func _update_held(_delta: float) -> void:
	if held == null:
		return
	if not is_instance_valid(held):
		held = null
		return
	var target := camera.global_transform * Vector3(0, -0.12, -0.62)
	var diff := target - held.global_position
	if diff.length() > 1.6:
		drop()
		return
	held.linear_velocity = diff * 14.0
	held.angular_velocity = held.angular_velocity.lerp(Vector3.ZERO, 0.2)


# ------------------------------------------------------------------ focus (computer)
func begin_focus(target: Node, cam_xform: Transform3D) -> void:
	if held:
		drop()
	focus_target = target
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()
	var start := camera.global_transform
	camera.top_level = true
	camera.global_transform = start
	_focus_tween = create_tween()
	_focus_tween.tween_property(camera, "global_transform", cam_xform, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var hud = _hud()
	if hud:
		hud.set_crosshair_visible(false)


func end_focus() -> void:
	if focus_target == null:
		return
	focus_target = null
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()
	var dest := head.global_transform * _cam_home
	_focus_tween = create_tween()
	_focus_tween.tween_property(camera, "global_transform", dest, 0.5).set_trans(Tween.TRANS_SINE)
	_focus_tween.tween_callback(func():
		camera.top_level = false
		camera.transform = _cam_home)
	var hud = _hud()
	if hud:
		hud.set_crosshair_visible(true)
