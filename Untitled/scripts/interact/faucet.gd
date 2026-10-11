class_name Faucet
extends Interactable
## Tap with running water.

var running := false
var stream_mesh: MeshInstance3D
var snd: AudioStreamPlayer3D


func setup(id: String, height := 0.18) -> void:
	register(id)
	B.cyl(self, 0.015, 0.02, 0.14, Vector3(0, 0.07, 0), Mats.m("chrome"), false, Vector3.ZERO, 10)
	B.cyl(self, 0.012, 0.012, 0.16, Vector3(0, 0.14, 0.07), Mats.m("chrome"), false, Vector3(90, 0, 0), 10)
	B.box(self, Vector3(0.04, 0.02, 0.06), Vector3(0, 0.16, -0.03), Mats.m("chrome"))
	var wm := Mats.color(Color(0.7, 0.8, 0.85), 0.05)
	stream_mesh = B.cyl(self, 0.005, 0.008, height, Vector3(0, 0.14 - height / 2, 0.14), wm, false, Vector3.ZERO, 6)
	stream_mesh.visible = false
	snd = AudioManager.make_emitter(self, "water", Vector3(0, 0, 0.1), 0.0, -1.0, -1.0, false)
	B.interact_area(self, Vector3(0.2, 0.25, 0.3), Vector3(0, 0.12, 0.05))


func get_prompt() -> String:
	return "Turn off" if running else "Turn on"


func interact(_player: Node) -> void:
	running = not running
	stream_mesh.visible = running
	if running:
		snd.bus = AudioManager.bus_for(global_position)
		snd.play()
	else:
		snd.stop()
	WorldState.set_state("faucet/" + obj_id, running)
	WorldState.log_interaction("faucet", obj_id)
