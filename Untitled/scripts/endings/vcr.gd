class_name VCR
extends Interactable
## The video deck under the living-room television. It takes a tape.

var tv: TV
var slot: MeshInstance3D


func setup(id: String, tv_node: TV) -> void:
	register(id)
	tv = tv_node
	# tape door on the front of the deck
	slot = B.box(self, Vector3(0.2, 0.024, 0.004), Vector3(-0.04, 0.012, 0.151), Mats.color(Color(0.02, 0.02, 0.02), 0.25))
	B.label(self, "PLAY  STOP  EJECT", Vector3(0.1, -0.025, 0.152), 0.00018, Color(0.75, 0.75, 0.72), Vector3.ZERO, 32)
	B.interact_area(self, Vector3(0.46, 0.36, 0.5), Vector3(0, 0.1, 0.12))


func accepts(item) -> bool:
	return item is VHSTape and GameManager.ending == ""


func get_prompt() -> String:
	var p = WorldState.player
	if p and p.held is VHSTape and GameManager.ending == "":
		return "Put the tape in"
	return ""


func interact(player: Node) -> void:
	var tape = player.held
	if not tape is VHSTape or GameManager.ending != "":
		return
	player.drop()
	tape.freeze = true
	tape.collision_layer = 0
	tape.collision_mask = 0
	var into := global_transform * Vector3(-0.04, 0.012, 0.0)
	var tw := create_tween()
	tw.tween_property(tape, "global_position", global_transform * Vector3(-0.04, 0.012, 0.3), 0.25)
	tw.tween_property(tape, "global_rotation", global_rotation, 0.15)
	tw.tween_property(tape, "global_position", into, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): tape.visible = false)
	AudioManager.play_3d("vhs_insert", global_position, 0.0)
	WorldState.log_interaction("vcr", "tape_in")
	var ending := TapeEnding.new()
	get_tree().current_scene.add_child(ending)
	ending.start(tv, self)
