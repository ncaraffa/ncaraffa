class_name StoveKnob
extends Interactable
## Front-left burner of the gas stove: a blue ring and a quiet hiss when on.

var flame: MeshInstance3D
var hiss: AudioStreamPlayer3D
var glow: OmniLight3D
var knob: MeshInstance3D
var is_on := false


func setup(id: String, burner_local: Vector3) -> void:
	register(id)
	knob = B.cyl(self, 0.025, 0.025, 0.035, Vector3.ZERO, Mats.m("plastic_black"), false, Vector3(90, 0, 0), 10)
	B.box(knob, Vector3(0.006, 0.03, 0.006), Vector3(0, 0.02, 0.0), Mats.m("plastic_white"))
	var tm := TorusMesh.new()
	tm.inner_radius = 0.045
	tm.outer_radius = 0.06
	flame = MeshInstance3D.new()
	flame.mesh = tm
	flame.material_override = Mats.emissive(Color(0.25, 0.45, 1.0), 4.0, true)
	add_child(flame)
	flame.position = burner_local
	glow = B.omni(self, burner_local + Vector3(0, 0.15, 0), Color(0.4, 0.55, 1.0), 0.6, 2.2, false)
	hiss = AudioManager.make_emitter(self, "gas_hiss", burner_local, 0.0, -1.0, -1.0, false)
	B.interact_area(self, Vector3(0.12, 0.12, 0.12), Vector3.ZERO)
	set_on(false, true)


func get_prompt() -> String:
	return "Turn off the burner" if is_on else "Turn on the burner"


func interact(_player: Node) -> void:
	set_on(not is_on)
	WorldState.set_state("task/last_action_time", WorldState.sim_time)
	WorldState.log_interaction("stove", obj_id)


func set_on(v: bool, silent := false) -> void:
	is_on = v
	flame.visible = v
	glow.visible = v
	knob.rotation_degrees.z = -90.0 if v else 0.0
	if v:
		hiss.bus = AudioManager.resolve_bus("gas_hiss", global_position)
		hiss.play()
	else:
		hiss.stop()
	if not silent:
		AudioManager.play_3d("stove_knob", global_position)
	WorldState.set_state("stove/on", v)
