extends MysteryEvent
## Eyes in the dark. In an unlit doorway, a window, the back of a room: two
## pale eyes at the height of a face, and they follow you wherever you go.
## Come too close, or bring light, and they close.

const SPOTS := [
	# house-local, facing (local), room light that must be off
	[Vector3(2.3, 1.62, 6.0), Vector3(1, 0, 0), "b2_ceiling"],        # bedroom 2, facing its door
	[Vector3(6.4, 1.6, 1.0), Vector3(-0.3, 0, 1), "bath_ceiling"],    # bathroom
	[Vector3(6.6, 1.65, 4.0), Vector3(-1, 0, 0), "laundry_bulb"],     # laundry
	[Vector3(6.6, 1.62, 7.6), Vector3(-1, 0, -0.2), "closet_bulb"],   # hall closet
	[Vector3(17.2, 1.55, 6.0), Vector3(-1, 0, 0), "garage_tube"],     # garage, by the door
	[Vector3(9.3, 1.6, -0.6), Vector3(0, 0, 1), ""],                  # outside the dining window
	[Vector3(1.4, 1.6, -0.6), Vector3(0, 0, 1), ""],                  # outside the bedroom window
]

var eye: WatchingEye


func _init() -> void:
	id = "eyes"
	title = "Eyes in the dark"
	track = "side"
	intensity = 2
	min_night = 3
	max_per_night = 1
	kinds = ["temporary"]


func _pick() -> Array:
	var h := house()
	var opts := SPOTS.duplicate()
	opts.shuffle()
	for s in opts:
		var g: Vector3 = h.to_global(s[0])
		var d := Perception.dist(g)
		if d < 3.0 or d > 9.0:
			continue
		if s[2] != "" and WorldState.get_state("light/" + s[2], false):
			continue
		# appear out of sight; you will turn and find them
		if Perception.view_angle(g) < 50.0:
			continue
		var p = WorldState.player
		var q := PhysicsRayQueryParameters3D.create(p.camera.global_position, g, B.LAYER_WORLD)
		q.exclude = [p.get_rid()]
		if not p.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			continue
		return s
	return []


func can_start() -> bool:
	return WorldState.player_inside and not _pick().is_empty()


func _start() -> void:
	var s := _pick()
	if s.is_empty():
		finish()
		return
	var h := house()
	eye = WatchingEye.new()
	h.add_child(eye)
	eye.position = s[0]
	eye.rotation.y = atan2(s[1].x, s[1].z)
	eye.setup(0.05, true, 0.13)
	record(String(s[2]) if s[2] != "" else "window")
	var t := 0.0
	var seen := 0.0
	while t < 60.0 and is_instance_valid(eye):
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		if Perception.sees(eye.global_position, 40.0, 14.0):
			seen += dt
		var lit: bool = s[2] != "" and WorldState.get_state("light/" + s[2], false)
		if Perception.dist(eye.global_position) < 2.2 or lit or seen > 14.0:
			break
		if seen == 0.0 and t > 40.0:
			break
	if is_instance_valid(eye):
		WorldState.set_state("eyes/seen", seen > 0.5)
		eye.close_and_free(0.2)
	await wait(0.5)
	finish()
