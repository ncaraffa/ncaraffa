class_name Computer
extends Interactable
## Beige desktop PC with a CRT. The screen shows a SubViewport running Terminal.
## Using it moves the camera to the screen and routes the keyboard to it.

var viewport: SubViewport
var terminal: Terminal
var screen: MeshInstance3D
var screen_mat: ShaderMaterial
var glow: OmniLight3D
var hum: AudioStreamPlayer3D
var focus_point: Node3D
var power := true


func setup(id: String) -> void:
	register(id)
	var beige := Mats.m("plastic_beige")
	# monitor (faces local +Z)
	B.box(self, Vector3(0.42, 0.36, 0.08), Vector3(0, 0.33, 0.04), beige)
	B.box(self, Vector3(0.34, 0.3, 0.3), Vector3(0, 0.33, -0.15), beige)
	B.box(self, Vector3(0.22, 0.04, 0.2), Vector3(0, 0.13, -0.05), beige)
	B.box(self, Vector3(0.1, 0.06, 0.1), Vector3(0, 0.17, -0.05), beige)
	B.box(self, Vector3(0.02, 0.02, 0.005), Vector3(0.17, 0.17, 0.082), Mats.emissive(Color(0.3, 1.0, 0.4), 2.0))
	# keyboard
	B.box(self, Vector3(0.44, 0.025, 0.15), Vector3(0, 0.0125, 0.28), beige)
	for r in 4:
		B.box(self, Vector3(0.4, 0.012, 0.025), Vector3(0, 0.03, 0.225 + r * 0.032), Mats.color(Color(0.72, 0.68, 0.6), 0.6))
	# tower beside
	B.box(self, Vector3(0.18, 0.4, 0.42), Vector3(0.38, 0.2, -0.08), beige)
	B.box(self, Vector3(0.12, 0.02, 0.01), Vector3(0.38, 0.33, 0.135), Mats.m("plastic_black"))
	# mouse
	B.box(self, Vector3(0.06, 0.03, 0.1), Vector3(0.3, 0.015, 0.28), beige)

	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 480)
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	terminal = Terminal.new()
	terminal.size = Vector2(640, 480)
	viewport.add_child(terminal)
	terminal.power_changed.connect(_on_power)

	var q := QuadMesh.new()
	q.size = Vector2(0.33, 0.25)
	screen = MeshInstance3D.new()
	screen.mesh = q
	screen_mat = ShaderMaterial.new()
	screen_mat.shader = load("res://shaders/crt.gdshader")
	screen_mat.set_shader_parameter("screen_tex", viewport.get_texture())
	screen.material_override = screen_mat
	add_child(screen)
	screen.position = Vector3(-0.01, 0.335, 0.081)
	glow = B.omni(self, Vector3(0, 0.35, 0.45), Color(0.7, 0.85, 0.8), 0.12, 2.5, false)
	hum = AudioManager.make_emitter(self, "computer_hum", Vector3(0.38, 0.2, 0))
	focus_point = B.node(self, "Focus", Vector3(-0.01, 0.335, 0.6))
	B.interact_area(self, Vector3(0.6, 0.45, 0.6), Vector3(0.1, 0.25, 0.1))


func get_prompt() -> String:
	return "Use computer" if power else "Turn on"


func interact(player: Node) -> void:
	if not power:
		AudioManager.play_3d("crt_on", global_position + Vector3(0, 0.3, 0))
		terminal.power_on(false)
		return
	WorldState.log_interaction("computer", obj_id)
	if player.has_method("begin_focus"):
		player.begin_focus(self, focus_point.global_transform)


func handle_key(ev: InputEventKey) -> void:
	terminal.handle_key(ev)


func _on_power(on: bool) -> void:
	if not on and power:
		AudioManager.play_3d("crt_off", global_position + Vector3(0, 0.3, 0))
	power = on
	glow.visible = on
	screen_mat.set_shader_parameter("power", 1.0 if on else 0.0)
	WorldState.set_state("computer/" + obj_id + "/power", on)
	if not on:
		var p = WorldState.player
		if p and p.has_method("end_focus") and p.get("focus_target") == self:
			p.end_focus()


func _process(_delta: float) -> void:
	if power:
		glow.light_energy = 0.11 + randf() * 0.01
