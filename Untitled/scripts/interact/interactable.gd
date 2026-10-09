class_name Interactable
extends Node3D
## Base for anything the player can use with E. The interaction ray hits a
## collider inside this node and walks up the tree until it finds `interact`.

var obj_id := ""
var prompt := "Use"
var enabled := true


func register(id: String) -> void:
	obj_id = id
	if id != "":
		WorldState.register(id, self)


func get_prompt() -> String:
	return prompt if enabled else ""


func interact(_player: Node) -> void:
	pass
