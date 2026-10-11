extends Scare
## B — THE DOOR. One rare time, the room behind a door you open is not empty.

# door id -> [spot on side A (local), spot on side B (local)]; the figure takes
# the side opposite to the player.
const SPOTS := {
	"door_b2": [Vector3(3.35, 0, 6.05), Vector3(4.9, 0, 6.05)],
	"door_closet": [Vector3(6.45, 0, 7.0), Vector3(4.9, 0, 7.0)],
	"door_laundry": [Vector3(6.35, 0, 4.25), Vector3(4.9, 0, 4.2)],
	"door_bath": [Vector3(5.05, 0, 1.95), Vector3(4.9, 0, 3.6)],
	"door_b1": [Vector3(3.35, 0, 4.2), Vector3(4.9, 0, 4.2)],
	"door_garage": [Vector3(17.3, -0.3, 4.8), Vector3(15.3, 0, 4.8)],
}

var door: Door


func _init() -> void:
	id = "door"
	min_night = 3
	weight = 1.0
	timeout = 300.0


func _candidates() -> Array:
	var out := []
	var used: Array = (WorldState.get_state("scare/doors_used", []) as Array).duplicate()
	for did in SPOTS:
		var d := WorldState.get_obj(did) as Door
		if d and not d.is_open and not did in used:
			if Perception.dist(d.global_position) > 2.0:
				out.append(d)
	return out


func can_arm() -> bool:
	return WorldState.player_inside and not _candidates().is_empty()


func _on_arm() -> void:
	var c := _candidates()
	door = c[rng.randi() % c.size()]
	door.player_opened.connect(_on_opened, CONNECT_ONE_SHOT)


func _on_disarm() -> void:
	if door and door.player_opened.is_connected(_on_opened):
		door.player_opened.disconnect(_on_opened)


func _on_opened(p: Node) -> void:
	if not armed:
		return
	firing = true
	var h := house()
	var spots: Array = SPOTS[door.obj_id]
	var a: Vector3 = h.to_global(spots[0])
	var b: Vector3 = h.to_global(spots[1])
	var spot := a if p.global_position.distance_to(a) > p.global_position.distance_to(b) else b
	var used: Array = WorldState.get_state("scare/doors_used", [])
	used.append(door.obj_id)
	WorldState.set_state("scare/doors_used", used)
	await _ambush(spot)


func fire() -> void:
	var p = player()
	var fwd: Vector3 = -p.camera.global_transform.basis.z
	fwd.y = 0
	firing = true
	await _ambush(p.global_position + fwd.normalized() * 1.6)


func _ambush(spot: Vector3) -> void:
	var f := figure()
	if f == null:
		done(false)
		return
	var p = player()
	f.appear(spot, p.global_position - spot)
	f.head_tilt = rng.randf_range(15, 35) * (1 if rng.randf() < 0.5 else -1)
	await wait(0.18)
	var toward: Vector3 = p.global_position - spot
	toward.y = 0
	stinger(spot + Vector3(0, 1.6, 0), 2.5)
	shake(0.07, 0.45)
	f.lunge(spot + toward.normalized() * min(0.45, max(0.0, toward.length() - 0.8)), 0.16)
	await wait(0.4)
	# it backs away, unnaturally fast, and is gone
	var back := f.global_position - toward.normalized() * 1.3
	var tw := f.create_tween()
	tw.tween_property(f, "global_position", back, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await wait(0.2)
	f.vanish("fade", 0.15)
	if door and rng.randf() < 0.35:
		await wait(1.4)
		door.set_open(false, false, 2.2)
	done(true)
