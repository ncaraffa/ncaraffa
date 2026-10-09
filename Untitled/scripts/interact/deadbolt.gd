class_name Deadbolt
extends Interactable
## Thumb-turn lock on the inside face of an exterior door.

var door: Door
var knob: MeshInstance3D


func setup(target: Door, thick: float) -> void:
	door = target
	door.lockable = true
	var z := door.inside_sign * (thick / 2.0 + 0.02)
	B.box(self, Vector3(0.07, 0.07, 0.012), Vector3(0, 0, z), Mats.m("chrome"))
	knob = B.box(self, Vector3(0.016, 0.045, 0.02), Vector3(0, 0, z + door.inside_sign * 0.015), Mats.m("chrome"))
	B.interact_area(self, Vector3(0.12, 0.12, 0.08), Vector3(0, 0, z + door.inside_sign * 0.03))
	_update()


func get_prompt() -> String:
	if door.is_open:
		return ""
	return "Unlock" if door.locked else "Lock"


func interact(_player: Node) -> void:
	if door.is_open:
		return
	door.set_locked(not door.locked)
	WorldState.log_interaction("deadbolt", door.obj_id)
	_update()


func _update() -> void:
	knob.rotation_degrees.z = 90.0 if door.locked else 0.0


func _process(_delta: float) -> void:
	_update()
