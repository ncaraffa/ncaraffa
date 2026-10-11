class_name LastTaskEnding
extends Node
## FINAL 2 — THE LAST TASK.
##
## The fifth night ends like every other: you lie down, the picture goes dark.
## But there is no sixth night. The screen stays black. Steps in the hallway.
## The bedroom door. The steps come in, and stop. The mattress gives under
## someone's weight, right beside you. Silence. Then, at your ear:
##     "You forgot to check the tape."
## Then it is in front of you. Blackout. Silence. "Untitled..." Menu.
## Nothing says which tape, or why.

signal phase_changed(phase: String)

const LIE_CAM := Vector3(0.62, 0.86, 3.5)      # head on the pillow (house-local)
const LIE_LOOK := Vector3(2.2, 1.25, 4.15)     # towards the door side of the bed
const STEPS_HALL := [Vector3(4.9, 0, 8.1), Vector3(4.9, 0, 7.35), Vector3(4.9, 0, 6.6), Vector3(4.88, 0, 5.85),
	Vector3(4.86, 0, 5.1), Vector3(4.8, 0, 4.45)]
const STEPS_ROOM := [Vector3(3.75, 0, 4.15), Vector3(3.0, 0, 4.3), Vector3(2.3, 0, 4.45), Vector3(1.75, 0, 4.45)]
const WHISPER := "You forgot to check the tape."
const LAMP_AT := Vector3(0.35, 0.85, 2.5)        # the bedside lamp, behind your head
const LOOK_SIDE := Vector3(1.75, 0.95, 4.55)     # where the mattress gave
## how far its face is from yours, flash by flash (metres)
const FLASHES := [1.05, 0.62, 0.34]

var phase := ""
var overlay: EndingOverlay
var fig: ShadowFigure
var eyes: WatchingEye
var lamp_light: OmniLight3D
var rng := RandomNumberGenerator.new()
## Tests may shorten the waits (1.0 = as designed).
var pace := 1.0


func _ready() -> void:
	name = "LastTaskEnding"
	rng.randomize()


func start() -> void:
	if not GameManager.begin_ending("last_task"):
		queue_free()
		return
	WorldState.register("last_task_ending", self)
	_run()


func _set_phase(p: String) -> void:
	phase = p
	WorldState.set_state("last_task/phase", p)
	phase_changed.emit(p)


func _wait(s: float) -> Signal:
	return get_tree().create_timer(s * pace, false).timeout


func _house() -> House:
	return WorldState.get_obj("house") as House


func _snd(sound_name: String, local_pos: Vector3, offset := 0.0, pitch := 1.0) -> void:
	AudioManager.play_3d(sound_name, _house().to_global(local_pos), offset, pitch, -1.0, -1.0, "Ending")


func _run() -> void:
	var p = WorldState.player
	var h := _house()
	var hud = WorldState.get_obj("hud")
	overlay = EndingOverlay.new()
	add_child(overlay)
	_set_phase("dark")
	var sd = WorldState.get_obj("scare_director")
	if sd and sd.armed:
		sd.armed.disarm("ending")
	var pool = WorldState.get_obj("figures")
	if pool:
		pool.hide_all()
	AudioManager.fade_world(-80.0, 1.5)
	# lying in bed, in the dark; the bedroom door is shut
	p.sleeping = true
	p.camera.top_level = true
	p.camera.global_transform = Transform3D(Basis.IDENTITY, h.to_global(LIE_CAM)).looking_at(h.to_global(LIE_LOOK), Vector3.UP)
	for k in WorldState.objects.keys():
		var o = WorldState.objects[k]
		if is_instance_valid(o) and o is LightFixture and h.contains_point(o.global_position):
			o.set_on(false, true)
	var door = WorldState.get_obj("door_b1")
	if door and door.is_open:
		door.set_open(false, true, 50.0)
	# it looks like the usual night transition. it is not.
	await _wait(5.0)
	# steps, out in the hallway, coming closer
	_set_phase("steps")
	var i := 0
	for s: Vector3 in STEPS_HALL:
		_snd("step_wood_%d" % (i % 4), s + Vector3(0, 0.05, 0), -1.0 + i * 0.6, 0.88)
		i += 1
		await _wait(0.95 + rng.randf_range(-0.08, 0.12))
	await _wait(1.6)
	# the bedroom door
	_set_phase("door")
	if door:
		door.set_open(true, true, 0.3)
		_snd("door_creak", Vector3(4.2, 1.1, 4.2), 4.0, 0.78)
	await _wait(2.4)
	for s: Vector3 in STEPS_ROOM:
		_snd("step_wood_%d" % (i % 4), s + Vector3(0, 0.05, 0), 1.0, 0.86)
		i += 1
		await _wait(1.1 + rng.randf_range(-0.05, 0.15))
	# they stop
	_set_phase("stopped")
	await _wait(2.6)
	# someone sits down on the bed, right next to you
	_set_phase("mattress")
	_snd("mattress_creak", Vector3(1.4, 0.5, 4.0), 2.0, 0.92)
	var tw := create_tween()
	var cam: Camera3D = p.camera
	tw.tween_property(cam, "global_position", cam.global_position + Vector3(0, -0.035, 0), 0.6).set_trans(Tween.TRANS_SINE)
	await _wait(3.4)
	# at your ear
	_set_phase("whisper")
	AudioManager.play_flat("whisper_tape", 0.0, "Ending")
	if hud:
		hud.show_subtitle(WHISPER, 3.6)
	await _wait(3.6)
	if hud:
		hud.clear_subtitle()
	# silence. then the bedside lamp comes on, by itself (there is no power)
	_set_phase("lamp")
	await _wait(1.3)
	var lamp = WorldState.get_obj("b1_lamp")
	lamp_light = B.omni(self, Vector3.ZERO, Color(1.0, 0.82, 0.6), 0.0, 7.0, false, 1.0)
	lamp_light.light_specular = 0.0
	lamp_light.global_position = h.to_global(LAMP_AT)
	_lamp(true, lamp)
	AudioManager.play_3d("switch_click", h.to_global(LAMP_AT), -2.0)
	# you turn your head to where it sat down. nobody there.
	var look_to := Transform3D(Basis.IDENTITY, cam.global_position).looking_at(h.to_global(LOOK_SIDE), Vector3.UP)
	var tl := create_tween()
	tl.tween_property(cam, "global_transform", look_to, 1.5 * pace).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _wait(2.9)
	# the bulb buzzes. it dies.
	AudioManager.play_3d("elec_buzz", h.to_global(LAMP_AT), -3.0)
	for k in 4:
		_lamp(k % 2 == 1, lamp)
		await _wait(rng.randf_range(0.06, 0.16))
	_lamp(false, lamp)
	await _wait(1.25)
	# it is there
	_set_phase("scare")
	await _scare(cam, lamp)
	# BLACKOUT. Silence.
	_set_phase("blackout")
	overlay.blackout()
	AudioManager.stop_all()
	if fig:
		fig.vanish("instant")
	_lamp(false, WorldState.get_obj("b1_lamp"))
	await _wait(3.2)
	_set_phase("title")
	await overlay.show_title(3.5)
	await _wait(4.0)
	await overlay.hide_title(2.0)
	await _wait(1.0)
	_set_phase("done")
	GameManager.finish_ending()


func _lamp(on: bool, lamp) -> void:
	if lamp:
		lamp.set_on(on, true, true)
	if lamp_light:
		lamp_light.light_energy = 0.6 if on else 0.0


## Its face, with its eyes open, a hand's width from yours. The lamp strobes;
## every time it comes back the face is closer. A scream that is not human,
## the view jerks, and then nothing.
func _scare(cam: Camera3D, lamp) -> void:
	fig = ShadowFigure.new()
	fig.name = "LastFigure"
	add_child(fig)
	fig.scale = Vector3.ONE * 1.2
	fig.look_target = null
	fig.head_manual = true
	fig._lean = 0.65
	fig._arm_raise = 0.6
	# pale eyes, wide open, pupils like pinheads
	eyes = WatchingEye.new()
	fig.parts.head.add_child(eyes)
	eyes.setup(0.026, true, 0.072)
	eyes.position = Vector3(0, 0.135, 0.124)
	# not quite level, not quite the same
	eyes.quads[0].rotation_degrees.z = 14.0
	eyes.quads[1].rotation_degrees.z = -6.0
	eyes.quads[1].position.y -= 0.009
	eyes.quads[1].scale = Vector3.ONE * 1.12
	eyes.turn_speed = 0.0
	eyes.blinks = false
	eyes.dilate_base = 0.42
	eyes.mat.set_shader_parameter("surround", 0.0)
	eyes.mat.set_shader_parameter("glow", 0.8)
	eyes.mat.set_shader_parameter("bloodshot", 1.0)
	eyes.mat.set_shader_parameter("iris_pale", 1.0)
	eyes._open = 1.0
	eyes._open_target = 1.0
	# and a mouth hanging open, much too far
	var mq := QuadMesh.new()
	mq.size = Vector2(0.075, 0.2)
	var mouth := MeshInstance3D.new()
	mouth.mesh = mq
	var mm := ShaderMaterial.new()
	mm.shader = load("res://shaders/mouth.gdshader")
	mouth.material_override = mm
	mouth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fig.parts.head.add_child(mouth)
	mouth.position = Vector3(0.006, 0.0, 0.112)
	mouth.rotation_degrees = Vector3(14.0, 0, 4.0)
	fig.visible = false
	var fov0 := cam.fov
	var base := cam.global_transform
	AudioManager.play_flat("final_scare", 0.0, "Ending")
	for i in FLASHES.size():
		var d: float = FLASHES[i]
		# each time, the head at another wrong angle
		fig.head_rot = Vector3(-20.0 - i * 6.0, rng.randf_range(-12, 12), (34.0 if i % 2 == 0 else -28.0) + rng.randf_range(-6, 6))
		_place_face(cam, d)
		if i == 0:
			fig.appear(fig.global_position, Vector3.FORWARD)
			_place_face(cam, d)
		fig.visible = true
		_lamp(true, lamp)
		cam.fov = fov0 * (1.0 - 0.07 * (i + 1))
		cam.global_transform = base.rotated_local(Vector3(1, 0, 0), rng.randf_range(-0.025, 0.025)).rotated_local(Vector3(0, 1, 0), rng.randf_range(-0.03, 0.03))
		await get_tree().create_timer((0.11 if i < FLASHES.size() - 1 else 0.06) * pace, false).timeout
		if i < FLASHES.size() - 1:
			_lamp(false, lamp)
			fig.visible = false
			await get_tree().create_timer(0.055 * pace, false).timeout
	# the last one stays: it shakes, the view shakes with it
	for k in 10:
		await get_tree().process_frame
		fig.head_rot += Vector3(rng.randf_range(-7, 7), rng.randf_range(-10, 10), rng.randf_range(-9, 9))
		_place_face(cam, FLASHES[-1] - k * 0.012)
		cam.global_transform = base.rotated_local(Vector3(1, 0, 0), rng.randf_range(-0.045, 0.045)).rotated_local(Vector3(0, 1, 0), rng.randf_range(-0.045, 0.045))
	await get_tree().create_timer(0.08 * pace, false).timeout
	cam.global_transform = base
	cam.fov = fov0


## Moves the whole figure so that its face is `d` metres in front of the camera,
## looking straight into it.
func _place_face(cam: Camera3D, d: float) -> void:
	var fwd := -cam.global_basis.z
	fig.face_point(cam.global_position)
	fig._animate(0.0)
	var face: Vector3 = eyes.global_position
	var want := cam.global_position + fwd * d + cam.global_basis.y * 0.03
	fig.global_position += want - face
