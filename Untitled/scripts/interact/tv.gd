class_name TV
extends Interactable
## CRT television. Modes: 0 off, 1 static, 2 rolling/distorted, 3 blue "no
## signal", 4 an ordinary late-night broadcast (abstract, never readable).

var screen: MeshInstance3D
var mat: ShaderMaterial
var glow: OmniLight3D
var sound: AudioStreamPlayer3D
var channel_label: Label3D
var power := false
var mode := 0
var _t := 0.0


func setup(id: String) -> void:
	register(id)
	var shell := Mats.color(Color(0.16, 0.14, 0.12), 0.5)
	B.box(self, Vector3(0.72, 0.56, 0.5), Vector3(0, 0.28, -0.05), shell)
	B.box(self, Vector3(0.5, 0.4, 0.2), Vector3(0, 0.28, -0.38), shell)
	B.box(self, Vector3(0.1, 0.4, 0.02), Vector3(0.29, 0.28, 0.205), Mats.color(Color(0.1, 0.09, 0.08), 0.6))
	for i in 3:
		B.cyl(self, 0.012, 0.012, 0.02, Vector3(0.29, 0.38 - i * 0.07, 0.21), Mats.m("chrome"), false, Vector3(90, 0, 0), 8)
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.38)
	screen = MeshInstance3D.new()
	screen.mesh = q
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/tv.gdshader")
	screen.material_override = mat
	add_child(screen)
	screen.position = Vector3(-0.06, 0.29, 0.202)
	glow = B.omni(self, Vector3(-0.06, 0.3, 0.7), Color(0.6, 0.7, 1.0), 0.0, 4.5, false)
	sound = AudioManager.make_emitter(self, "tv_static", Vector3(0, 0.3, 0.2), -12.0, 3.0, 25.0, false)
	channel_label = B.label(self, "CH 03", Vector3(-0.2, 0.42, 0.206), 0.0012, Color(0.9, 1.0, 0.9), Vector3.ZERO, 32, true)
	channel_label.visible = false
	B.interact_area(self, Vector3(0.75, 0.6, 0.55), Vector3(0, 0.28, 0))
	_apply()


func get_prompt() -> String:
	return "Turn off" if power else "Turn on"


func interact(_player: Node) -> void:
	if power:
		set_power(false)
	else:
		set_power(true, 4)
	WorldState.log_interaction("tv", obj_id)


func set_power(on: bool, new_mode := 1, silent := false) -> void:
	power = on
	mode = new_mode if on else 0
	if not silent:
		AudioManager.play_3d("crt_on" if on else "crt_off", global_position + Vector3(0, 0.3, 0), -6.0, 1.0, 3.0)
	_apply()


func set_mode(new_mode: int) -> void:
	if not power:
		return
	mode = new_mode
	_apply()


func _apply() -> void:
	mat.set_shader_parameter("mode", mode)
	glow.visible = power
	channel_label.visible = power and mode == 3
	if not sound:
		return
	sound.bus = AudioManager.bus_for(global_position)
	match mode:
		0:
			sound.stop()
		1, 2:
			sound.stream = AudioManager.stream("tv_static")
			sound.volume_db = -14.0 if mode == 1 else -18.0
			sound.play()
		3:
			sound.stream = AudioManager.stream("tv_tone")
			sound.volume_db = -26.0
			sound.play()
		4:
			sound.stream = AudioManager.stream("distant_traffic")
			sound.volume_db = -16.0
			sound.play()
	WorldState.set_state("tv/" + obj_id + "/power", power)
	WorldState.set_state("tv/" + obj_id + "/mode", mode)


func _process(delta: float) -> void:
	if not power:
		return
	_t += delta
	var base := 0.55
	match mode:
		1: base = 0.5 + randf() * 0.25
		2: base = 0.45 + 0.2 * sin(_t * 13.0) + randf() * 0.1
		3: base = 0.5
		4: base = 0.45 + 0.15 * sin(_t * 0.7) + 0.1 * sin(_t * 2.3)
	glow.light_energy = base
	glow.light_color = Color(0.45, 0.55, 1.0) if mode == 3 else Color(0.7, 0.75, 0.9)
