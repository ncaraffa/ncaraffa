class_name Pickup
extends RigidBody3D
## Small loose object the player can carry, look at closely and put down.
## Where it ends up is remembered by the WorldStateManager.

var obj_id := ""
var held := false
var _settle_t := 0.0


func setup(id: String, mass_kg := 0.4) -> void:
	obj_id = id
	if id != "":
		WorldState.register(id, self)
	mass = mass_kg
	collision_layer = B.LAYER_PROPS
	collision_mask = B.LAYER_WORLD | B.LAYER_PROPS
	continuous_cd = true
	can_sleep = true
	angular_damp = 2.0
	linear_damp = 0.4
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.9
	physics_material_override.bounce = 0.05
	sleeping = true


func get_prompt() -> String:
	return "" if held else "Pick up"


func interact(player: Node) -> void:
	if player.has_method("hold"):
		player.hold(self)
		WorldState.log_interaction("pickup", obj_id)


func on_held(v: bool) -> void:
	held = v
	gravity_scale = 0.0 if v else 1.0
	angular_damp = 8.0 if v else 2.0
	if not v:
		_settle_t = 3.0


func _physics_process(delta: float) -> void:
	if _settle_t > 0.0:
		_settle_t -= delta
		if _settle_t <= 0.0 and obj_id != "":
			WorldState.set_state("obj/" + obj_id, global_position.snapped(Vector3.ONE * 0.01))
