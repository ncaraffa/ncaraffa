extends MysteryEvent
## In a room nobody is in, something heavy is dragged across the floor, then a
## thump. If you go and look, everything is where it was. Almost.


func _init() -> void:
	id = "room_drag"
	title = "Dragging in an empty room"
	track = "side"
	intensity = 2
	min_night = 2
	max_per_night = 1
	kinds = ["temporary"]


const ROOMS := [Vector3(2.2, 0.4, 8.0), Vector3(2.1, 0.4, 2.4), Vector3(9.3, 0.4, 3.1), Vector3(6.6, 0.4, 4.2), Vector3(19.0, 0.1, 6.5)]


func _spot() -> Vector3:
	var h := house()
	var opts := ROOMS.duplicate()
	opts.shuffle()
	for r: Vector3 in opts:
		var g := h.to_global(r)
		var d := Perception.dist(g)
		if d > 4.0 and d < 12.0 and not Perception.sees(g, 80.0):
			return g
	return Vector3.ZERO


func can_start() -> bool:
	return WorldState.player_inside and _spot() != Vector3.ZERO


func _start() -> void:
	var g := _spot()
	AudioManager.play_3d("furniture_drag", g, 3.0, rng.randf_range(0.85, 1.0))
	await wait(2.3)
	AudioManager.play_3d("thud", g, 2.0, 0.8)
	record("drag", {"at": g})
	# a chair nearby really did move
	if g.distance_to(house().to_global(Vector3(9.3, 0.4, 3.1))) < 1.0:
		var ch = WorldState.get_obj("kitchen_chair_b")
		if ch and ch.has_method("_store"):
			ch.transform = ch.home.translated_local(Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(0.3, 0.5))).rotated_local(Vector3.UP, rng.randf_range(-0.6, 0.6))
			ch.displaced = true
			ch._store()
	await wait(3.0)
	finish()
