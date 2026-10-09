class_name Curtain
extends Interactable
## A pair of curtain panels in front of a window.

var left: Node3D
var right: Node3D
var is_open := true
var width := 1.2


func setup(id: String, w: float, h: float, mat: Material, start_open := true) -> void:
	register(id)
	width = w
	B.cyl(self, 0.012, 0.012, w + 0.3, Vector3(0, h, 0), Mats.m("metal_dark"), false, Vector3(0, 0, 90), 8)
	left = B.node(self, "L", Vector3(-w / 2 - 0.12, 0, 0))
	right = B.node(self, "R", Vector3(w / 2 + 0.12, 0, 0))
	for side: Node3D in [left, right]:
		var dir := 1.0 if side == left else -1.0
		var panel := B.node(side, "Panel")
		var folds := 6
		for i in folds:
			var fw := (w / 2.0 + 0.1) / folds
			B.box(panel, Vector3(fw * 1.08, h - 0.02, 0.025), Vector3(dir * (fw * i + fw / 2), h / 2, (0.012 if i % 2 == 0 else -0.012)), mat)
	B.interact_area(self, Vector3(w + 0.3, h, 0.15), Vector3(0, h / 2, 0))
	set_open(start_open, true)


func get_prompt() -> String:
	return "Close curtains" if is_open else "Open curtains"


func interact(_player: Node) -> void:
	set_open(not is_open)
	WorldState.log_interaction("curtain", obj_id)


func set_open(value: bool, instant := false) -> void:
	is_open = value
	var s := 0.28 if value else 1.0
	for side: Node3D in [left, right]:
		var p: Node3D = side.get_child(0)
		if instant:
			p.scale.x = s
		else:
			create_tween().tween_property(p, "scale:x", s, 0.8).set_trans(Tween.TRANS_SINE)
	if not instant:
		AudioManager.play_3d("paper", global_position + Vector3(0, 1.5, 0), -6.0, 0.6, -1.0, -1.0, "sfx")
	WorldState.set_state("curtain/" + obj_id, value)
