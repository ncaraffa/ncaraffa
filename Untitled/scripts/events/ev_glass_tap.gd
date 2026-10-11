extends MysteryEvent
## Three slow taps on the glass of a window near you. Fingernails, maybe.
## Nobody outside when you look. Usually.


func _init() -> void:
	id = "glass_tap"
	title = "Tapping on the glass"
	track = "side"
	intensity = 1
	min_night = 2
	max_per_night = 2
	kinds = ["temporary"]


const WINDOWS := [Vector3(2.1, 1.5, -0.05), Vector3(1.4, 1.5, 0.0), Vector3(12.0, 1.55, -0.05), Vector3(9.3, 1.4, -0.05),
	Vector3(9.9, 1.4, 11.05), Vector3(13.6, 1.4, 11.05), Vector3(2.1, 1.4, 11.05), Vector3(0.0, 1.4, 8.6)]


func _spot() -> Vector3:
	var h := house()
	var best := Vector3.ZERO
	var best_d := 99.0
	for w: Vector3 in WINDOWS:
		var g := h.to_global(w)
		var d := Perception.dist(g)
		if d > 2.0 and d < best_d:
			best_d = d
			best = g
	return best if best_d < 7.0 else Vector3.ZERO


func can_start() -> bool:
	return WorldState.player_inside and _spot() != Vector3.ZERO


func _start() -> void:
	var g := _spot()
	AudioManager.play_3d("glass_tap", g, 2.0, rng.randf_range(0.9, 1.05))
	record("tap", {"at": g})
	await wait(5.0)
	finish()
