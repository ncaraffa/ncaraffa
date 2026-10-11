extends MysteryEvent
## Quick, heavy steps run across the hallway or the room next to you. Nobody.


func _init() -> void:
	id = "hall_run"
	title = "Running steps"
	track = "side"
	intensity = 2
	min_night = 3
	max_per_night = 1
	kinds = ["temporary"]


const RUNS := [
	[Vector3(4.9, 0.1, 3.0), Vector3(4.9, 0.1, 8.0)], [Vector3(4.9, 0.1, 8.0), Vector3(4.9, 0.1, 3.0)],
	[Vector3(8.4, 0.1, 9.6), Vector3(15.0, 0.1, 7.0)], [Vector3(10.0, 0.1, 1.5), Vector3(15.0, 0.1, 3.5)],
]


func _pick() -> Array:
	var h := house()
	var opts := RUNS.duplicate()
	opts.shuffle()
	for r in opts:
		var mid: Vector3 = h.to_global((r[0] + r[1]) / 2.0)
		var d := Perception.dist(mid)
		if d > 3.0 and d < 10.0 and not Perception.sees(mid + Vector3(0, 1.0, 0), 50.0):
			return r
	return []


func can_start() -> bool:
	return WorldState.player_inside and not _pick().is_empty()


func _start() -> void:
	var r := _pick()
	var h := house()
	var a: Vector3 = h.to_global(r[0])
	var b: Vector3 = h.to_global(r[1])
	var n := 7
	record("run")
	for i in n:
		var at := a.lerp(b, float(i) / float(n - 1))
		AudioManager.play_3d("step_heavy_%d" % rng.randi_range(0, 3), at, 3.0, rng.randf_range(1.05, 1.2))
		await wait(0.17)
	await wait(0.6)
	if rng.randf() < 0.4:
		AudioManager.play_3d("door_close", b + Vector3(0, 1.0, 0), -6.0)
	finish()
