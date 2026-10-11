class_name TapeEnding
extends Node
## FINAL 1 — THE TAPE.
##
## The tape is played on the living-room TV. What it shows is this house, seen
## from a camcorder standing by the front door, looking across the foyer and
## down the hallway (with a slice of the living room through the archway).
##
## It is not a video file: a second camera, inside a SubViewport, renders the
## REAL world as it is the moment the tape starts. Whatever the player moved,
## whatever the nights moved, is in the recording. The recording is "1986".
## Nobody explains that.
##
## Sequence: empty room (25-35 s) -> an ordinary person crosses, goes to the
## kitchen, switches off the living-room light on the way back, leaves ->
## silence -> a black figure in the hallway, still -> its head turns, slowly,
## to the camera -> it stares -> it walks into the bedroom the person went into
## -> a scream, cut short -> silence -> it comes out of the room RUNNING, at the
## camera -> blackout, silence, "Untitled..." -> menu.

signal phase_changed(phase: String)

## house-local: camcorder on the coat shelf by the front door, aimed down the hall
const CAM_POS := Vector3(5.8, 1.55, 10.72)
const CAM_AIM := Vector3(6.5, 1.0, 4.4)
const FIGURE_AT := Vector3(4.82, 0.0, 5.45)
const RUN_TO := Vector3(5.79, 0.0, 10.5)
## into the bedroom, where the person went to sleep
const FIGURE_IN := [Vector3(4.86, 0, 4.75), Vector3(4.45, 0, 4.25), Vector3(3.5, 0, 4.05), Vector3(2.7, 0, 3.8)]
## and out again, out of the doorway and down the hall
const FIGURE_OUT := [Vector3(3.3, 0, 4.0), Vector3(4.4, 0, 4.3), Vector3(4.85, 0, 4.85), Vector3(4.95, 0, 5.6)]
const PERSON_PATH_IN := [Vector3(4.5, 0, 4.25), Vector3(4.9, 0, 4.7), Vector3(4.9, 0, 7.5), Vector3(5.5, 0, 8.8),
	Vector3(7.0, 0, 9.35), Vector3(8.6, 0, 8.9), Vector3(9.6, 0, 6.6), Vector3(9.8, 0, 5.4), Vector3(10.6, 0, 3.4),
	Vector3(11.6, 0, 3.0), Vector3(12.6, 0, 3.2)]
const PERSON_PATH_BACK := [Vector3(11.4, 0, 3.0), Vector3(10.4, 0, 3.6), Vector3(9.8, 0, 5.4), Vector3(9.6, 0, 6.6),
	Vector3(8.6, 0, 8.9), Vector3(7.0, 0, 9.6), Vector3(6.55, 0, 10.45)]
const PERSON_PATH_OUT := [Vector3(6.0, 0, 9.6), Vector3(5.3, 0, 8.8), Vector3(4.9, 0, 7.6), Vector3(4.9, 0, 4.7),
	Vector3(4.45, 0, 4.25), Vector3(3.3, 0, 4.0), Vector3(2.4, 0, 3.6)]

var phase := ""
var vp: SubViewport
var cam: Camera3D
var layer: CanvasLayer
var screen: TextureRect
var vhs_mat: ShaderMaterial
var osd: Label
var stamp: Label
var overlay: EndingOverlay
var hiss: AudioStreamPlayer
var person: ShadowFigure
var fig: ShadowFigure
var tv: TV
var deck: Node3D
## Seconds of empty room before anything happens (25-35).
var empty_secs := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "TapeEnding"
	rng.randomize()
	empty_secs = rng.randf_range(25.0, 35.0)


func start(tv_node: TV, deck_node: Node3D = null) -> void:
	if not GameManager.begin_ending("tape"):
		queue_free()
		return
	tv = tv_node
	deck = deck_node
	WorldState.register("tape_ending", self)
	_run()


func _set_phase(p: String) -> void:
	phase = p
	WorldState.set_state("tape/phase", p)
	phase_changed.emit(p)


func _wait(s: float) -> Signal:
	return get_tree().create_timer(s, false).timeout


func _house() -> House:
	return WorldState.get_obj("house") as House


# ------------------------------------------------------------------ sequence
func _run() -> void:
	var p = WorldState.player
	var hud = WorldState.get_obj("hud")
	_set_phase("insert")
	# the world holds its breath: nothing else may happen from now on
	var sd = WorldState.get_obj("scare_director")
	if sd and sd.armed:
		sd.armed.disarm("ending")
	var pool = WorldState.get_obj("figures")
	if pool:
		pool.hide_all()
	if p:
		if p.held:
			p.drop()
		p.sleeping = true
		if hud:
			hud.set_prompt("")
			hud.set_crosshair_visible(false)
			if hud.is_reading():
				hud.close_note()
	_build_recording()
	await _wait(0.7)
	# the TV wakes up, blue for a moment, then the tape
	if tv:
		tv.set_power(true, 3)
	await _wait(0.6)
	if tv:
		tv.set_mode(5)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = vp.get_texture()
		tv.screen.material_override = m
	_set_phase("tv")
	# lean in towards the screen
	if p:
		var scr: Vector3 = tv.screen.global_position
		var n: Vector3 = tv.screen.global_basis.z.normalized()
		var to := Transform3D(Basis.IDENTITY, scr + n * 0.62).looking_at(scr, Vector3.UP)
		p.camera.top_level = true
		var from: Transform3D = p.camera.global_transform
		p.camera.global_transform = from
		var tw := create_tween()
		tw.tween_property(p.camera, "global_transform", to, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	AudioManager.fade_world(-80.0, 2.0)
	await _wait(1.8)
	# the recording, filling the screen
	_set_phase("fullscreen")
	_set_tape_lights()
	hiss = AudioManager.play_flat("vhs_hiss", 0.0, "Tape")
	var tw2 := create_tween()
	tw2.tween_property(screen, "modulate:a", 1.0, 0.7)
	layer.visible = true
	tw2.tween_callback(_main_view_off)
	vhs_mat.set_shader_parameter("glitch", 0.6)
	await _wait(0.5)
	vhs_mat.set_shader_parameter("glitch", 0.0)
	_hide_osd_later()
	# 1 — NORMALITY. Nothing. The tape hisses.
	_set_phase("empty")
	await _wait(empty_secs)
	# 2 — THE PERSON
	_set_phase("person")
	await _person()
	# silence
	_set_phase("silence")
	await _wait(rng.randf_range(5.5, 7.0))
	# 3 — THE SILHOUETTE
	_set_phase("figure")
	await _figure()
	# 4 — IT GOES INTO THE BEDROOM
	_set_phase("enters")
	await _enter_room()
	_set_phase("scream")
	await _scream()
	# 5 — IT RUNS
	_set_phase("run")
	await _run_at_camera()
	await _end()


## While the recording fills the screen, the player's own view is hidden behind
## it: stop drawing it (the tape keeps its own camera and viewport).
func _main_view_off() -> void:
	get_viewport().disable_3d = true


func _exit_tree() -> void:
	get_viewport().disable_3d = false


func _hide_osd_later() -> void:
	await _wait(3.5)
	osd.visible = false


func _build_recording() -> void:
	var h := _house()
	vp = SubViewport.new()
	vp.name = "TapeRecording"
	vp.size = Vector2i(640, 480)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.positional_shadow_atlas_size = 2048
	add_child(vp)
	cam = Camera3D.new()
	cam.name = "Camcorder"
	cam.fov = 64.0
	cam.near = 0.05
	cam.far = 160.0
	vp.add_child(cam)
	cam.look_at_from_position(h.to_global(CAM_POS), h.to_global(CAM_AIM), Vector3.UP)
	cam.current = true
	var envm = WorldState.get_obj("environment")
	if envm and envm.env:
		var e: Environment = envm.env.duplicate()
		e.tonemap_exposure = 1.75
		e.adjustment_saturation = 0.9
		e.glow_intensity = 0.7
		cam.environment = e
	# the full-screen picture (hidden until the cut)
	layer = CanvasLayer.new()
	layer.layer = 60
	layer.visible = false
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)
	screen = TextureRect.new()
	screen.texture = vp.get_texture()
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.modulate.a = 0.0
	vhs_mat = ShaderMaterial.new()
	vhs_mat.shader = load("res://shaders/vhs.gdshader")
	screen.material = vhs_mat
	layer.add_child(screen)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "Courier New", "DejaVu Sans Mono", "monospace"])
	osd = _osd_label(mono, "PLAY ►", 30)
	stamp = _osd_label(mono, "PM 11:58\nOCT.30 1986", 24)
	get_viewport().size_changed.connect(_layout_osd)
	_layout_osd()
	overlay = EndingOverlay.new()
	add_child(overlay)


func _osd_label(font: Font, text: String, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.92, 0.95, 0.9, 0.85))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(l)
	return l


func _layout_osd() -> void:
	if layer == null:
		return
	var s := get_viewport().get_visible_rect().size
	var w := s.y * 4.0 / 3.0
	var x0 := (s.x - w) / 2.0
	osd.position = Vector2(x0 + w * 0.07, s.y * 0.07)
	stamp.position = Vector2(x0 + w * 0.68, s.y * 0.82)
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stamp.size = Vector2(w * 0.25, 60)


## The recording is lit like a lived-in evening: hall, foyer, living room, kitchen.
func _set_tape_lights() -> void:
	for id in ["hall_ceiling", "hall_ceiling_b", "foyer_ceiling", "living_ceiling", "kitchen_ceiling", "b1_lamp"]:
		var l = WorldState.get_obj(id)
		if l:
			l.set_on(true, true, true)
	for id in ["door_b1", "door_b2"]:
		var d = WorldState.get_obj(id)
		if d and not d.is_open:
			d.set_open(true, true, 50.0)
	var fd = WorldState.get_obj("door_front")
	if fd and fd.is_open:
		fd.set_open(false, true, 50.0)


# ------------------------------------------------------------------ the person
func _path(points: Array) -> PackedVector3Array:
	var h := _house()
	var out := PackedVector3Array()
	for pt: Vector3 in points:
		out.append(h.to_global(pt))
	return out


func _tape_step(pos: Vector3, loud := 0.0) -> void:
	var d := cam.global_position.distance_to(pos)
	var v := -9.0 - clampf(d - 2.0, 0.0, 10.0) * 1.6 + loud
	AudioManager.play_flat("step_wood_%d" % rng.randi_range(0, 3), v, "Tape", rng.randf_range(0.9, 1.05))


func _walk(f: ShadowFigure, points: Array, speed: float) -> void:
	f.walk_path(_path(points), speed)
	var acc := 0.0
	var last := f.global_position
	while f._moving and f.state != ShadowFigure.State.HIDDEN:
		await get_tree().process_frame
		acc += f.global_position.distance_to(last)
		last = f.global_position
		if acc > 0.62:
			acc = 0.0
			_tape_step(f.global_position)


func _person() -> void:
	var h := _house()
	person = ShadowFigure.new()
	person.name = "TapePerson"
	add_child(person)
	person.make_person(Color(0.32, 0.36, 0.5), Color(0.2, 0.2, 0.24), Color(0.8, 0.62, 0.52), Color(0.2, 0.14, 0.09))
	person.look_target = null
	var start: Vector3 = h.to_global(PERSON_PATH_IN[0])
	person.appear(start, h.global_basis * Vector3(1, 0, 0))
	await _walk(person, PERSON_PATH_IN, 1.15)
	# in the kitchen: a cupboard, a glass
	await _wait(1.2)
	AudioManager.play_flat("dish_1", -16.0, "Tape")
	await _wait(rng.randf_range(2.5, 3.5))
	await _walk(person, PERSON_PATH_BACK, 1.15)
	# at the switch by the front door, just beside the camera: the foyer light goes off
	person.face_dir(h.global_basis * Vector3(0.1, 0, 1))
	await _wait(0.7)
	AudioManager.play_flat("switch_click", -4.0, "Tape")
	var fl = WorldState.get_obj("foyer_ceiling")
	if fl:
		fl.set_on(false, true)
	await _wait(0.9)
	await _walk(person, PERSON_PATH_OUT, 1.1)
	AudioManager.play_flat("door_close", -16.0, "Tape")
	person.vanish("instant")


# ------------------------------------------------------------------ the figure
func _figure() -> void:
	var h := _house()
	fig = ShadowFigure.new()
	fig.name = "TapeFigure"
	add_child(fig)
	# it is simply there after a tracking hiccup, facing the wall
	vhs_mat.set_shader_parameter("glitch", 0.8)
	AudioManager.play_flat("tv_static", -14.0, "Tape")
	await _wait(0.25)
	fig.appear(h.to_global(FIGURE_AT), h.global_basis * Vector3(-1, 0, 0))
	fig.look_target = cam
	fig.set_rim(0.25)
	fig.head_manual = true
	fig.head_rot = Vector3(-8, -6, 3)
	await _wait(0.2)
	vhs_mat.set_shader_parameter("glitch", 0.0)
	_clear_static()
	# it stands. nothing.
	await _wait(rng.randf_range(4.5, 6.0))
	# the head turns towards the camera — slowly, in uneven pieces
	_set_phase("head_turn")
	var yaw := -6.0
	var target := 84.0
	var stops := [30.0, 55.0, target]
	for s in stops:
		while yaw < s:
			await get_tree().process_frame
			yaw = minf(s, yaw + get_process_delta_time() * 9.5)
			fig.head_rot = Vector3(-8.0 + (yaw + 6.0) / 90.0 * 12.0, yaw, 3.0 + (yaw + 6.0) / 90.0 * 9.0)
		await _wait(rng.randf_range(0.5, 1.1))
	# it stares. the tape goes quiet.
	_set_phase("stare")
	if hiss:
		var tw := create_tween()
		tw.tween_property(hiss, "volume_db", AudioManager.db("vhs_hiss") - 22.0, 1.5)
	await _wait(rng.randf_range(3.0, 4.0))


## It looks away from the camera, as if it had never seen it, and walks into the
## bedroom — the one the person went into. Not fast. It knows the way.
func _enter_room() -> void:
	fig.head_manual = false
	fig.look_target = null
	fig.stiff = true
	await _wait(0.6)
	await _walk(fig, FIGURE_IN, 0.85)
	fig.vanish("instant")
	# a door, softly; then nothing for a moment
	AudioManager.play_flat("door_creak", -18.0, "Tape", 0.8)
	await _wait(rng.randf_range(2.2, 3.0))


## The scream: loud, raw, cut off. The lamp in there dies. Then the tape just
## hisses, for a few seconds that are far too long.
func _scream() -> void:
	vhs_mat.set_shader_parameter("glitch", 0.35)
	AudioManager.play_flat("scream", 0.0, "Tape")
	if hiss:
		hiss.volume_db = AudioManager.db("vhs_hiss")
	var lamp = WorldState.get_obj("b1_lamp")
	await _wait(0.25)
	vhs_mat.set_shader_parameter("glitch", 0.0)
	for k in 5:
		if lamp:
			lamp.set_on(k % 2 == 1, true, true)
		await _wait(rng.randf_range(0.12, 0.3))
	await _wait(1.0)
	if lamp:
		lamp.set_on(false, true, true)
	vhs_mat.set_shader_parameter("glitch", 0.15)
	await _wait(0.15)
	vhs_mat.set_shader_parameter("glitch", 0.0)
	_set_phase("aftermath")
	await _wait(rng.randf_range(3.0, 4.0))


func _clear_static() -> void:
	for c in AudioManager.get_children():
		if c is AudioStreamPlayer and c.stream == AudioManager.stream("tv_static"):
			c.stop()


func _run_at_camera() -> void:
	var h := _house()
	# out of the bedroom doorway, already running
	fig.appear(h.to_global(FIGURE_OUT[0]), h.global_basis * Vector3(1, 0, 0.2))
	fig.stiff = false
	fig.look_target = cam
	fig._sprint = true
	fig._lean = 0.55
	fig.walk_path(_path(FIGURE_OUT), 8.5)
	for k in 3:
		_tape_step(fig.global_position, 6.0)
		await _wait(0.1)
	while fig._moving:
		await get_tree().process_frame
	fig._sprint = true
	AudioManager.play_flat("tape_scare", 0.0, "Ending")
	# it ends right against the lens, chest and head filling the picture
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	var right := fwd.normalized().cross(Vector3.UP)
	var end := cam.global_position + fwd.normalized() * 0.42 + right * 0.1
	end.y = h.to_global(RUN_TO).y
	var tw := fig.sprint(end, 0.27)
	await tw.finished
	fig.face_point(cam.global_position)
	fig._sprint = false
	fig._lean = 0.12
	fig._arm_raise = 0.3
	# for an instant it fills the whole picture; the tape tears
	vhs_mat.set_shader_parameter("glitch", 0.25)
	await _wait(0.14)
	vhs_mat.set_shader_parameter("glitch", 1.0)
	await _wait(0.07)


func _end() -> void:
	# BLACKOUT. Every sound stops at once.
	_set_phase("blackout")
	overlay.blackout()
	layer.visible = false
	get_viewport().disable_3d = false
	AudioManager.stop_all()
	await _wait(3.5)
	_set_phase("title")
	await overlay.show_title(3.5)
	await _wait(4.0)
	await overlay.hide_title(2.0)
	await _wait(1.0)
	_set_phase("done")
	GameManager.finish_ending()
