class_name Readable
extends Interactable
## Paper, letter or note. Shows its text on a sheet in front of the camera.

var title := ""
var text := ""


func setup(id: String, note_text: String, size := Vector2(0.21, 0.28), paper_mat: Material = null, flat := true) -> void:
	register(id)
	text = note_text
	prompt = "Read"
	var m: Material = paper_mat if paper_mat else Mats.m("paper")
	if flat:
		B.box(self, Vector3(size.x, 0.002, size.y), Vector3(0, 0.001, 0), m)
		B.interact_area(self, Vector3(size.x + 0.08, 0.06, size.y + 0.08), Vector3(0, 0.02, 0))
	else:
		B.box(self, Vector3(size.x, size.y, 0.002), Vector3.ZERO, m)
		B.interact_area(self, Vector3(size.x + 0.08, size.y + 0.08, 0.06))
	# faint handwriting lines
	var ink := Mats.color(Color(0.25, 0.25, 0.32), 0.9)
	var rows := int(size.y / 0.022) - 2
	for i in rows:
		var w := size.x * randf_range(0.45, 0.8)
		if flat:
			B.box(self, Vector3(w, 0.0005, 0.003), Vector3(-size.x / 2 + 0.02 + w / 2, 0.0023, -size.y / 2 + 0.03 + i * 0.022), ink)
		else:
			B.box(self, Vector3(w, 0.003, 0.0005), Vector3(-size.x / 2 + 0.02 + w / 2, size.y / 2 - 0.03 - i * 0.022, 0.0013), ink)


func interact(_player: Node) -> void:
	var hud = WorldState.get_obj("hud")
	if hud:
		AudioManager.play_ui("paper")
		hud.show_note(text)
	WorldState.log_interaction("read", obj_id)
