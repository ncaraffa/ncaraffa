extends MysteryEvent
## Far down the hallway, someone crosses from one door to the other. No sound
## to speak of, no sting. Just a shape going from left to right, gone.

const CROSSINGS := [
	[Vector3(4.35, 0, 3.4), Vector3(5.45, 0, 3.0)],    # bedroom door -> bathroom
	[Vector3(5.45, 0, 4.2), Vector3(4.3, 0, 4.2)],     # laundry -> bedroom 1
	[Vector3(4.3, 0, 6.0), Vector3(5.45, 0, 7.0)],     # bedroom 2 -> closet
]

var f: ShadowFigure


func _init() -> void:
	id = "hall_cross"
	title = "Someone crosses the end of the hall"
	track = "side"
	intensity = 1
	min_night = 3
	max_per_night = 1
	resources = ["figure_inside"]
	kinds = ["temporary"]


func _looking_down_hall() -> bool:
	var h := house()
	var lp := h.to_local(Perception.player_pos())
	if not Rect2(4.2, 6.8, 2.2, 4.0).has_point(Vector2(lp.x, lp.z)):
		return false
	return Perception.view_angle(h.to_global(Vector3(4.9, 1.3, 3.8))) < 30.0


func can_start() -> bool:
	return WorldState.player_inside and _looking_down_hall()


func _start() -> void:
	var h := house()
	f = figure()
	if f == null:
		finish()
		return
	var c: Array = CROSSINGS[rng.randi() % CROSSINGS.size()]
	var a: Vector3 = h.to_global(c[0])
	var b: Vector3 = h.to_global(c[1])
	f.appear(a, b - a)
	f.look_target = null
	f.stiff = rng.randf() < 0.5
	f.walk_path(PackedVector3Array([b]), rng.randf_range(1.6, 2.4))
	AudioManager.play_3d("step_wood_%d" % rng.randi_range(0, 3), (a + b) / 2.0 + Vector3(0, 0.1, 0), -8.0, 0.8)
	record("cross")
	await f.finished_path
	f.vanish("instant")
	await wait(1.0)
	finish()
