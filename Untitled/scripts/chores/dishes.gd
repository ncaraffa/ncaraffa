class_name DirtyDishes
extends Interactable
## Plates in the kitchen sink. Washed one by one under running water, then
## they go to the drying rack.

var plates: Array = []
var rack_slots: Array = []
var faucet_id := "faucet_kitchen"


func setup(id: String, rack: Node3D) -> void:
	register(id)
	for i in 3:
		var pl := B.cyl(self, 0.12, 0.1, 0.02, Vector3(0, i * 0.022, 0), Mats.m("porcelain"), false, Vector3(rad_to_deg(0.08 * i), 0, 0), 18)
		pl.set_meta("home", pl.transform)
		plates.append(pl)
		var slot := B.node(rack, "Slot%d" % i, Vector3(-0.1 + i * 0.1, 0.13, 0), Vector3(0, 0, 80))
		rack_slots.append(slot)
	B.interact_area(self, Vector3(0.5, 0.25, 0.4), Vector3(0, 0.05, 0))
	WorldState.state_changed.connect(func(k, _v):
		if k == "dishes/dirty":
			_refresh())
	_refresh.call_deferred()


func dirty() -> int:
	return int(WorldState.get_state("dishes/dirty", 0))


func _refresh() -> void:
	var d := dirty()
	for i in plates.size():
		var pl: MeshInstance3D = plates[i]
		var in_sink := i < d
		var parent: Node3D = self if in_sink else rack_slots[i]
		if pl.get_parent() != parent:
			pl.get_parent().remove_child(pl)
			parent.add_child(pl)
		pl.transform = pl.get_meta("home") if in_sink else Transform3D()
		pl.material_override = Mats.color(Color(0.72, 0.66, 0.55), 0.6) if in_sink else Mats.m("porcelain")


func accepts(item) -> bool:
	return item is Pickup and String(item.obj_id).begins_with("mug")


func get_prompt() -> String:
	var p = WorldState.player
	if p and accepts(p.held):
		return "Put in the sink"
	return "Wash a dish" if dirty() > 0 else ""


var _mug_slot := 0


func interact(player: Node) -> void:
	if accepts(player.held):
		var mug: Pickup = player.held
		player.drop()
		mug.global_position = global_transform * Vector3(-0.17 + (_mug_slot % 3) * 0.17, 0.14, -0.06)
		mug.linear_velocity = Vector3.ZERO
		mug.angular_velocity = Vector3.ZERO
		_mug_slot += 1
		AudioManager.play_3d("dish_%d" % (randi() % 3), global_position, -2.0)
		WorldState.set_state("task/last_action_time", WorldState.sim_time)
		return
	if dirty() <= 0:
		return
	var f = WorldState.get_obj(faucet_id)
	if f == null or not f.running:
		AudioManager.play_3d("dish_%d" % (randi() % 3), global_position)
		var hud = WorldState.get_obj("hud")
		if hud:
			hud.thought("The water's off.")
		return
	AudioManager.play_3d("scrub", global_position)
	WorldState.set_state("task/last_action_time", WorldState.sim_time)
	await get_tree().create_timer(1.1, false).timeout
	AudioManager.play_3d("dish_%d" % (randi() % 3), global_position)
	WorldState.set_state("dishes/dirty", max(0, dirty() - 1))
	WorldState.log_interaction("wash", obj_id)
