extends Scare
## G — THE WRONG SHAPE. It stands at the far end of the room, completely still,
## facing you. You look at it. It does not move. Then its neck keeps growing,
## the head tilting over until it hangs sideways, far too high. The light dies.
## When it comes back, nothing is there.

const SPOTS := [
	# house-local floor point, facing (local dir)
	[Vector3(4.9, 0.0, 3.25), Vector3(0, 0, 1)],      # end of the hallway
	[Vector3(15.3, 0.0, 6.75), Vector3(-1, 0, 0.4)],  # living room corner
	[Vector3(15.3, 0.0, 0.9), Vector3(-1, 0, 0.3)],   # kitchen, by the back wall
	[Vector3(8.2, 0.0, 0.8), Vector3(1, 0, 0.4)],     # dining corner
	[Vector3(4.65, 0.0, 10.6), Vector3(0.3, 0, -1)],  # foyer, by the front door
	[Vector3(3.6, 0.0, 10.5), Vector3(-0.2, 0, -1)],  # bedroom 2, by the window
]

var f: ShadowFigure
var _spot := Vector3.ZERO
var _seen := 0.0
var _placed := false


func _init() -> void:
	id = "contort"
	min_night = 3
	weight = 1.0
	timeout = 160.0


func can_arm() -> bool:
	return WorldState.player_inside and not WorldState.is_locked("figure_inside")


func _on_arm() -> void:
	_placed = false
	_seen = 0.0


func _on_disarm() -> void:
	if f and f.is_visible_figure():
		f.vanish("instant")
	f = null


func _line_clear(a: Vector3, b: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = player().get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(a, b, B.LAYER_WORLD)
	q.exclude = [player().get_rid()]
	return space.intersect_ray(q).is_empty()


func _watch(delta: float) -> void:
	var h := house()
	var p = player()
	if not _placed:
		if Engine.get_process_frames() % 10 != 0:
			return
		var opts := SPOTS.duplicate()
		opts.shuffle()
		for s in opts:
			var g: Vector3 = h.to_global(s[0])
			var head := g + Vector3(0, 1.6, 0)
			var d := Perception.dist(g)
			if d < 3.5 or d > 9.0:
				continue
			# out of sight now, but in the open: it will be seen when you turn
			if Perception.view_angle(head) < 70.0 or not _line_clear(p.camera.global_position, head):
				continue
			f = figure()
			if f == null:
				return
			f.appear(g, h.global_basis * s[1])
			f.look_target = p.camera
			f.set_rim(0.7)
			_spot = g
			_placed = true
			return
		return
	if Perception.sees_figure(f):
		_seen += delta
		if _seen > rng.randf_range(1.1, 1.6):
			firing = true
			_contort()
	elif Perception.dist(_spot) < 1.4:
		disarm("too close unseen")


func fire() -> void:
	var p = player()
	if f == null:
		var fwd: Vector3 = -p.camera.global_transform.basis.z
		fwd.y = 0
		var g: Vector3 = p.global_position + fwd.normalized() * 4.0
		f = figure()
		if f == null:
			done(false)
			return
		f.appear(g, p.global_position - g)
		f.look_target = p.camera
		_spot = g
	firing = true
	_contort()


func _contort() -> void:
	var neck: Node3D = f.parts.neck
	f.head_manual = true
	f.head_rot = Vector3(-10, 0, 0)
	AudioManager.play_3d("house_creak_%d" % rng.randi_range(0, 3), _spot + Vector3(0, 1.8, 0), 6.0, 0.6)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(neck, "scale", Vector3(1.0, 3.4, 1.0), 1.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(f, "head_rot", Vector3(10, 25, 96), 1.3).set_trans(Tween.TRANS_BACK)
	await tw.finished
	await wait(0.5)
	# the light goes out; something drops to the floor
	var lights := []
	for k in WorldState.objects.keys():
		var o = WorldState.objects[k]
		if is_instance_valid(o) and o is LightFixture and o.is_on and o.global_position.distance_to(_spot) < 6.0:
			lights.append(o)
			o.set_on(false, true)
	stinger(_spot + Vector3(0, 1.6, 0), 0.0)
	AudioManager.play_3d("thud", _spot + Vector3(0, 0.3, 0), 4.0, 0.7)
	shake(0.05, 0.4)
	await wait(0.12)
	neck.scale = Vector3.ONE
	f.vanish("instant")
	await wait(1.1)
	for l in lights:
		l.set_on(true, true)
		l.flicker(0.4)
	done(true)
