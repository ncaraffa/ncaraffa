class_name VHSTape
extends Pickup
## An old VHS cassette. Hand-written label: UNTITLED — 1986. Nothing else.

const LABEL := "UNTITLED — 1986"

var _seen_label := false


func build() -> void:
	var size := Vector3(0.188, 0.026, 0.104)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position.y = size.y / 2.0
	add_child(cs)
	var shell := Mats.color(Color(0.045, 0.045, 0.05), 0.35)
	B.box(self, size, Vector3(0, size.y / 2.0, 0), shell)
	var paper := Mats.color(Color(0.86, 0.82, 0.71), 0.95)
	var ink := Color(0.13, 0.12, 0.24)
	# label on the face
	B.box(self, Vector3(0.13, 0.0012, 0.064), Vector3(-0.012, size.y + 0.0006, -0.004), paper)
	B.label(self, LABEL, Vector3(-0.012, size.y + 0.0014, -0.004), 0.00027, ink, Vector3(-90, 0, 0), 48)
	# label on the spine (the side that faces you on a shelf)
	B.box(self, Vector3(0.15, 0.016, 0.0012), Vector3(0, 0.013, size.z / 2.0 + 0.0006), paper)
	B.label(self, LABEL, Vector3(0, 0.013, size.z / 2.0 + 0.0014), 0.0002, ink, Vector3.ZERO, 48)
	# the two little reel windows
	for x: float in [-0.042, 0.042]:
		B.cyl(self, 0.016, 0.016, 0.001, Vector3(x, size.y + 0.0004, 0.03), Mats.color(Color(0.12, 0.1, 0.09), 0.2), false, Vector3.ZERO, 14)
	setup("vhs_tape", 0.22)


func get_prompt() -> String:
	return "" if held else "Pick up"


func interact(player: Node) -> void:
	super.interact(player)
	if not _seen_label:
		_seen_label = true
		WorldState.set_state("tape/found", true)
		var hud = WorldState.get_obj("hud")
		if hud:
			hud.thought("\"%s\"" % LABEL, 3.5)
