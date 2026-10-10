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

var phase := ""
var overlay: EndingOverlay
var fig: ShadowFigure
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
	await _wait(3.3)
	# it is there
	_set_phase("scare")
	if hud:
		hud.clear_subtitle()
	_scare(cam)
	await _wait(0.6)
	# BLACKOUT. Silence.
	_set_phase("blackout")
	overlay.blackout()
	AudioManager.stop_all()
	if fig:
		fig.vanish("instant")
	await _wait(3.2)
	_set_phase("title")
	await overlay.show_title(3.5)
	await _wait(4.0)
	await overlay.hide_title(2.0)
	await _wait(1.0)
	_set_phase("done")
	GameManager.finish_ending()


func _scare(cam: Camera3D) -> void:
	var envm = WorldState.get_obj("environment")
	fig = ShadowFigure.new()
	fig.name = "LastFigure"
	add_child(fig)
	# bigger than a person
	fig.scale = Vector3.ONE * 1.25
	var fwd := -cam.global_basis.z
	var flat := Vector3(fwd.x, 0, fwd.z).normalized()
	# the head lands right in front of the eyes
	var head_off := Vector3(0, 2.0 * 1.25, 0)
	# (not closer than ~0.4 m: inside the head the camera would see nothing)
	var start := cam.global_position + fwd * 1.5 - head_off
	var end := cam.global_position + fwd * 0.42 - head_off
	fig.appear(start, -flat)
	fig.look_target = cam
	fig.set_rim(3.2)
	var light := B.omni(self, Vector3.ZERO, Color(0.72, 0.78, 1.0), 1.8, 2.6)
	light.light_specular = 0.0
	light.global_position = cam.global_position + Vector3(0, 0.35, 0) + fwd * 0.25
	# the view punches in
	var fov0 := cam.fov
	var ft := create_tween()
	ft.tween_property(cam, "fov", fov0 * 0.78, 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if envm:
		envm.fade_to(0.0, 0.03)
	AudioManager.play_flat("final_scare", 0.0, "Ending")
	fig.lunge(end, 0.1)
	fig._lean = 0.05
	fig._arm_raise = 0.55
	fig.twitch()
	# the view jolts
	var base := cam.global_transform
	for k in 6:
		await get_tree().process_frame
		cam.global_transform = base.rotated_local(Vector3(1, 0, 0), rng.randf_range(-0.03, 0.03)).rotated_local(Vector3(0, 1, 0), rng.randf_range(-0.03, 0.03))
		fig.twitch()
	cam.global_transform = base
	await get_tree().create_timer(0.5, false).timeout
	cam.fov = fov0
