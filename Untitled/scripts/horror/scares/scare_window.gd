extends Scare
## C — THE WINDOW. You look out. The street is quiet. Then it is at the glass.

# local centre of each window, outward normal, curtain id ("" = none)
const WINDOWS := [
	[Vector3(0.0, 1.5, 1.4), Vector3(-1, 0, 0), "b1_west"],
	[Vector3(2.1, 1.5, 0.0), Vector3(0, 0, -1), "b1_back"],
	[Vector3(2.1, 1.5, 11.0), Vector3(0, 0, 1), "b2_front"],
	[Vector3(0.0, 1.5, 8.6), Vector3(-1, 0, 0), "b2_west"],
	[Vector3(9.3, 1.5, 0.0), Vector3(0, 0, -1), "dining_back"],
	[Vector3(12.0, 1.55, 0.0), Vector3(0, 0, -1), ""],
	[Vector3(9.9, 1.5, 11.0), Vector3(0, 0, 1), "living_w1"],
	[Vector3(13.6, 1.5, 11.0), Vector3(0, 0, 1), "living_w2"],
]

var _gaze := 0.0
var _need := 1.4


func _init() -> void:
	id = "window"
	min_night = 3
	weight = 1.0


func can_arm() -> bool:
	return WorldState.player_inside


func _on_arm() -> void:
	_gaze = 0.0
	_need = rng.randf_range(1.0, 2.2)


func _watch(delta: float) -> void:
	var w := _looked_window()
	if w.is_empty():
		_gaze = 0.0
		return
	_gaze += delta
	if _gaze >= _need:
		firing = true
		_at_window(w)


func _looked_window() -> Array:
	var h := house()
	for w in WINDOWS:
		var c: Vector3 = h.to_global(w[0])
		if Perception.dist(c) > 2.8 or Perception.view_angle(c) > 22.0:
			continue
		if w[2] != "" and WorldState.get_state("curtain/" + w[2], true) == false:
			continue
		return w
	return []


func fire() -> void:
	var h := house()
	var best: Array = WINDOWS[0]
	var bd := INF
	for w in WINDOWS:
		var d := Perception.dist(h.to_global(w[0]))
		if d < bd:
			bd = d
			best = w
	firing = true
	_at_window(best)


func _at_window(w: Array) -> void:
	var h := house()
	var f := figure()
	if f == null:
		done(false)
		return
	var n: Vector3 = h.global_basis * w[1]
	var glass: Vector3 = h.to_global(w[0])
	var side := h.global_basis * Vector3(w[1].z, 0, -w[1].x) * rng.randf_range(-0.2, 0.2)
	var feet := Vector3(glass.x, h.to_global(Vector3(0, -0.3, 0)).y, glass.z) + n * 0.62 + side
	f.appear(feet, -n)
	f._arm_raise = 0.62
	f._lean = 0.42
	f.set_rim(1.6)
	f.head_tilt = rng.randf_range(-12, 12)
	AudioManager.play_3d("window_bang", glass, 2.0, rng.randf_range(0.95, 1.05))
	stinger(glass, -3.0)
	shake(0.05, 0.35)
	await wait(rng.randf_range(0.55, 0.85))
	f.vanish("flicker" if rng.randf() < 0.5 else "instant")
	done(true)
