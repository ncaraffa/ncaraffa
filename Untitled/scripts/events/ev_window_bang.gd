extends MysteryEvent
## A violent blow on a window in the room you are in, or the next one. The
## glass holds. Outside: the yard, the street. Sometimes a smear on the glass
## that is gone the next time you look.

const WINDOWS := [
	[Vector3(2.1, 1.5, -0.03), Vector3(0, 0, 0)], [Vector3(1.4, 1.5, -0.03), Vector3(0, 90, 0)],
	[Vector3(12.0, 1.55, -0.03), Vector3(0, 0, 0)], [Vector3(9.3, 1.4, -0.03), Vector3(0, 0, 0)],
	[Vector3(9.9, 1.4, 11.03), Vector3(0, 180, 0)], [Vector3(13.6, 1.4, 11.03), Vector3(0, 180, 0)],
	[Vector3(2.1, 1.4, 11.03), Vector3(0, 180, 0)], [Vector3(-0.03, 1.4, 8.6), Vector3(0, 90, 0)],
]


func _init() -> void:
	id = "window_bang"
	title = "A blow on the window"
	track = "side"
	intensity = 2
	min_night = 2
	max_per_night = 1
	kinds = ["temporary"]


func _pick() -> Array:
	var h := house()
	var best: Array = []
	var best_d := 99.0
	for w in WINDOWS:
		var g := h.to_global(w[0])
		var d := Perception.dist(g)
		if d > 2.5 and d < best_d:
			best_d = d
			best = w
	return best if best_d < 8.0 else []


func can_start() -> bool:
	return WorldState.player_inside and not _pick().is_empty()


func _start() -> void:
	var w := _pick()
	var h := house()
	var g := h.to_global(w[0])
	AudioManager.play_3d("window_bang", g, 6.0, rng.randf_range(0.85, 1.0))
	var p = WorldState.player
	if Perception.dist(g) < 5.0:
		p.shake(0.02, 0.25)
	# a palm-shaped smear on the outside of the glass, now and then
	if rng.randf() < 0.45:
		var cult = WorldState.get_obj("cult")
		var n := B.node(h, "Smear", w[0])
		n.rotation_degrees = w[1]
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.75, 0.75, 0.72, 0.18)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.2
		for i in 5:
			B.quad(n, Vector2(0.03, 0.12 - abs(i - 2) * 0.02), Vector3(-0.06 + i * 0.03, 0.12 - abs(i - 2) * 0.015, 0.0), m)
		B.quad(n, Vector2(0.14, 0.13), Vector3(0, 0.0, 0.0), m)
		if cult:
			cult.add_temp(n, "glance", 120.0)
			cult.temps[-1].kind = "window_smear"
	record("bang", {"at": g})
	await wait(3.0)
	finish()
