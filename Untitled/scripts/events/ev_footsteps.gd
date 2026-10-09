extends MysteryEvent
## EVENT 7 — Footsteps somewhere else in the house (or just outside). They have
## a real position, move along a real path, and stop.

var emitter: AudioStreamPlayer3D
var path: PackedVector3Array
var seg := 0
var along := 0.0
var step_t := 0.0
var interval := 0.65
var steps_left := 0
var surface := "wood"


func _init() -> void:
	intensity = 2
	id = "footsteps"
	title = "Footsteps"
	resources = ["footsteps"]
	kinds = ["temporary"]


func _start() -> void:
	var h := house()
	var names := ["hall", "living", "patio", "to_bedroom", "garage", "kitchen"]
	names.shuffle()
	var chosen := ""
	var ppos: Vector3 = WorldState.player.global_position if WorldState.player else Vector3(9999, 0, 0)
	for n in names:
		var ok := true
		for p in h.global_path(n):
			if p.distance_to(ppos) < 3.0:
				ok = false
				break
		if ok:
			chosen = n
			break
	if chosen == "":
		chosen = names[0]
	path = h.global_path(chosen)
	if rng.randf() < 0.3:
		path.reverse()
	surface = h.get_meta("path_surfaces", {}).get(chosen, "wood")
	emitter = AudioStreamPlayer3D.new()
	emitter.unit_size = 5.0
	emitter.max_distance = 40.0
	emitter.area_mask = B.LAYER_AUDIO
	emitter.attenuation_filter_cutoff_hz = 5000
	get_tree().current_scene.add_child(emitter)
	emitter.global_position = path[0] + Vector3(0, 0.1, 0)
	emitter.bus = AudioManager.bus_for(path[0] + Vector3(0, 0.5, 0))
	seg = 0
	along = 0.0
	step_t = 0.0
	interval = rng.randf_range(0.58, 0.74)
	var total := 0.0
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	steps_left = int(total / 0.72)
	record(chosen, {"steps": steps_left})


func _process(delta: float) -> void:
	if not running or emitter == null:
		return
	step_t += delta
	if step_t < interval:
		return
	step_t = 0.0
	if steps_left <= 0 or seg >= path.size() - 1:
		emitter.queue_free()
		emitter = null
		finish()
		return
	# advance one stride along the polyline
	var stride := 0.72
	while stride > 0.0 and seg < path.size() - 1:
		var a := path[seg]
		var b := path[seg + 1]
		var rem := a.distance_to(b) - along
		if stride < rem:
			along += stride
			stride = 0.0
		else:
			stride -= rem
			seg += 1
			along = 0.0
	if seg < path.size() - 1:
		var a2 := path[seg]
		var b2 := path[seg + 1]
		emitter.global_position = a2.lerp(b2, along / max(0.01, a2.distance_to(b2))) + Vector3(0, 0.1, 0)
	steps_left -= 1
	var prefix := "step_heavy"
	match surface:
		"concrete": prefix = "step_concrete"
		"tile": prefix = "step_tile"
	emitter.stream = AudioManager.variant(prefix, 4)
	emitter.volume_db = AudioManager.db("step_heavy") + (2.0 if steps_left > 3 else 2.0 - (4 - steps_left) * 4.0)
	emitter.pitch_scale = rng.randf_range(0.9, 1.02)
	emitter.play()
	# a slightly irregular gait
	interval = clamp(interval + rng.randf_range(-0.05, 0.05), 0.52, 0.85)
